#! /usr/bin/env python
# -*- coding: utf-8 -*-
#
# © 2015 Ian Eure
# Author: Ian Eure <ian.eure@gmail.com>
#

"""Hack assembler

HA is a tool for injecting assembler source into arcade game ROMs.

# Layout

Patches have a specific layout.

 + sample
  \
   + game.xml
   + roms
   |\
   | + original/sample
   | + patched/sample
   |
   + patch
    \
     + maincpu
      \
       + 0000-name.s
"""

import argparse
import sys
import os
import zipfile
import shutil
import subprocess
import xml.etree.ElementTree as ET
from contextlib import closing
from glob import glob
from pprint import pprint
import logging

logging.basicConfig(level=logging.DEBUG)
MAMEDIR = "/Users/ieure/Dropbox/arcade/mame0152-64bit"
MAME = MAMEDIR + "/mame64"
LOG = logging.getLogger('ha')

class Game(object):

    def __init__(self, xml):
        self.game = xml.getroot().find('game')
        self.name = self.game.attrib['name']

    def cpus(self):
        """Return a map of CPU -> type."""
        return dict([[chip.attrib['tag'], chip.attrib['name']]
                     for chip in self.game.findall('chip')
                     if chip.attrib['type'] == 'cpu'])

    def regions(self):
        """Return CPU regions."""
        return self.cpus().keys()

    def roms(self):
        """Return ROMs."""
        return self.game.findall('rom')

    def target_rom(self, patch_start, patch_end):
        """Return the target ROM for a given start address."""
        for rom in self.roms():
            rom_start = int(rom.attrib['offset'], 16)
            rom_end = rom_start + int(rom.attrib['size'])
            if patch_start >= rom_start and patch_end <= rom_end:
                return (rom_start, rom.attrib['name'])
        return (None, None)


    def related_roms(self):
        return [rom for rom in [self.game.attrib.get('romof'),
                                self.game.attrib.get('cloneof'),
                                self.game.attrib.get('name')] if rom]

    @classmethod
    def new(cls, file_):
        return cls(ET.parse(file_))


def assemble_file(cpu, file_):
    if cpu == 'Z80':
        return assemble_z80(file_)

    raise Exception("No assembler defined for `%s'" % cpu)


def assemble_z80(file_):
    out = file_.rsplit('.', 1)[0] + ".bin"
    subprocess.call(["z80asm", "-I", os.path.dirname(file_),
                     "-o", out, file_])


def assemble_patch():
    """Assemble the patch."""
    game = Game.new('game.xml')

    for (region, cpu) in game.cpus().iteritems():
        pdir = 'patch/' + region
        if not os.path.isdir(pdir):
            LOG.debug("No patch in %s" % pdir)

        for patch in glob('%s/*-*.s' % pdir):
            LOG.debug("Assembling %s" % patch)
            assemble_file(cpu, patch)

    return 0


def patch_roms():
    """Apply patches to ROMs"""
    game = Game.new('game.xml')

    # Copy original ROMs over.
    for rom in game.roms():
        name = rom.attrib['name']
        shutil.copyfile('roms/original/%s/%s' % (game.name, name),
                        'roms/patched/%s/%s' % (game.name, name))

    fds = {}
    for region in game.regions():
        rdir = 'patch/' + region
        if not os.path.isdir(rdir):
            continue

        for patch in glob(rdir + "/*.bin"):
            # Base address of patch
            patch_start = int(os.path.basename(patch).split('-', 1)[0], 16)

            # Load patch data
            with open(patch, 'rb') as pfd:
                bytes = pfd.read()
            patch_end = patch_start + len(bytes)

            # What ROM?
            (rom_offset, target) = game.target_rom(patch_start, patch_end)
            if rom_offset is None or target is None:
                LOG.error("Can't find ROM to patch for %s" % patch)
                continue

            # Patch
            rom_patch_start = patch_start - rom_offset
            LOG.info("Patching %s <- %s" % (target, os.path.basename(patch)))
            if target not in fds:
                fds[target] = open('roms/patched/%s/%s' % (
                    game.name, target), 'r+b')

            fd = fds[target]
            fd.seek(rom_patch_start)
            fd.write(bytes)

    for fd in fds.itervalues():
        fd.close()


def run():
    """Run the current version of the patch."""
    game = Game.new('game.xml')
    subprocess.call([MAME, "-debug", "-window",
                     "-rompath", "roms/patched",
                     game.name])


def run_orig():
    """Run the original game."""
    game = Game.new('game.xml')
    subprocess.call([MAME, "-debug", "-window",
                     "-rompath", "roms/original",
                     game.name])


def init(game):
    """Initialize a patch."""
    dir = "%s/patch" % game
    os.makedirs(dir)

    with open('%s/game.xml' % game, 'w') as fd:
        res = subprocess.call([MAME, "-listxml", game], stdout=fd)
        if res != 0:
            return res

    gm = Game.new('%s/game.xml' % game)

    # Add regions
    for region in gm.regions():
        os.mkdir("%s/patch/%s" % (game, region))

    # Extract ROMs
    os.makedirs("%s/roms/original/%s" % (game, game))
    os.makedirs("%s/roms/patched/%s" % (game, game))


    # ZIPs to look for
    for rom in gm.related_roms():
        zip = '%s/roms/%s.zip' % (MAMEDIR, rom)
        if os.path.isfile(zip):
            with closing(zipfile.ZipFile(zip, 'r')) as zf:
                zf.extractall('%s/roms/original/%s' % (game, game))

    return 0


def main(cmd, *args):
    if cmd == 'init':
        return init(*args)
    elif cmd == 'dev':
        assemble_patch()
        patch_roms()
        run()
    elif cmd == 'run':
        return run()
    elif cmd == 'orig':
        return run_orig()
    elif cmd == 'asm':
        return assemble_patch()
    elif cmd == 'patch':
        return patch_roms()
    elif cmd == 'ap':
        assemble_patch()
        return patch_roms()
    return -1

if __name__ == '__main__':
    sys.exit(main(*sys.argv[1:]))
