#! /usr/bin/env python3
# -*- coding: utf-8 -*-
#
# © 2015, 2021 Ian Eure
# Author: Ian Eure <ian.eure@gmail.com>
#

"""Hack assembler

Hack Assembler (ha) is a tool for patching arcade ROMs
programmatically, from source code. This allows patches to be written
in assembler, and preseves the source, which allows for greater
understanding and quick development.

To use all the features of ha, you will need MAME.

## Features

 - Maintain patches as assembler source, rather than binary patches.
 - Assembles the patch and patches the ROM in one step.
 - Discovers the ROM files to patch, based on filename - fully
   automatic.
 - Dev mode assembles, patches, and runs the patched ROM in MAME, all
   in one command.

## Layout

Patches must have a specific layout. `ha init <romname>` will create
it for you.

```
+ <root>
 \
  + game.xml   - This is the MAME XML info dump for the game.
  + roms
  |\
  | + original - Original ROMs for the game being patched.
  | + patched  - Patched ROMs. ha will create these.
  |
  + patch      - Patch source directory
   \
    + maincpu  - Patches for the CPU region.
    |\
    | + 0000-desc.s  - This patch applies at 0x0000
    | + 4000-other.s - This patch applies at 0x4000
    + soundcpu - You can patch ROMs in other regions, too.
```

Based on the region and prefix in the source file name, ha will
determine the correct ROM to patch using `game.xml`.
"""

import argparse
import sys
import os
import zipfile
import shutil
import subprocess
import xml.etree.ElementTree as ET
from contextlib import closing, contextmanager
from functools import reduce
from glob import glob
from pprint import pprint
import logging

logging.basicConfig(level=logging.DEBUG)
MAME_DIR = None
MAME_BIN = None
MAME = None
LOG = logging.getLogger('ha')

class HAException(Exception):
    pass

class Game(object):

    """A Python representation of a MAME game XML."""

    def __init__(self, xml):
        self.game = xml.getroot().find('game') or xml.getroot().find('machine')
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


class Assembler(object):

    """An interface to assemblers for different CPUs."""

    def __init__(self, cpu, source):
        self.cpu = cpu
        self.source = source
        self.dest = source.rsplit('.', 1)[0] + ".bin"

    @classmethod
    def new(cls, cpu, source):
        if cpu.lower() == "z80":
            return AssembleZ80(cpu, source)
        elif cpu == "M6502":
            return Assemble6502(cpu, source)
        else:
            raise Exception("No assembler defined for %s" % cpu)


class AssembleZ80(Assembler):

    """Z80 Assembler."""

    def assemble(self):
        subprocess.call(["z80asm", "-I", os.path.dirname(self.source),
                         "-o", self.dest, self.source])


class Assemble6502(Assembler):

    """6502 Assembler."""

    def assemble(self):
        subprocess.call(["asm6", self.source, self.dest])


def chain(*cmds):
    """Chain commands together.

       If any command returns a non-zero exit status, abort the chain.
    """
    return lambda: reduce(lambda ret, f: f() if ret == 0 else ret,
                          cmds, 0)


def assemble_patch():
    """Assemble the patch."""
    game = Game.new('game.xml')

    for (region, cpu) in game.cpus().items():
        pdir = 'patch/' + region
        if not os.path.isdir(pdir):
            LOG.debug("No patch in %s" % pdir)

        for patch in glob('%s/*-*.s' % pdir):
            LOG.debug("Assembling %s" % patch)
            Assembler.new(cpu, patch).assemble()

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

    for fd in fds.values():
        fd.close()

    return 0


def run():
    """Run the current version of the patch."""
    require_mame()
    game = Game.new('game.xml')
    subprocess.call([MAME, "-debug", "-window",
                     "-rompath", "roms/patched",
                     game.name])


def play():
    """Run the current version of the patch."""
    require_mame()
    game = Game.new('game.xml')
    subprocess.call([MAME, "-rompath", "roms/patched",
                     game.name])


def run_orig():
    """Run the original game."""
    require_mame()
    game = Game.new('game.xml')
    subprocess.call([MAME, "-debug", "-window",
                     "-rompath", "roms/original",
                     game.name])

@contextmanager
def ignore_exists():
    try:
        yield
    except OSError as e:
        pass


def require_mame():
    if MAME is None:
        raise HAException("You must set MAME_DIR.")
    if not os.path.exists(MAME):
        raise HAException("MAME path %s doesn't exist" % MAME)


def init(game, *dir):
    """Initialize a patch."""
    base = dir and dir[0] or game

    require_mame()

    with ignore_exists():
        os.makedirs(base)

    with open('%s/game.xml' % base, 'w') as fd:
        res = subprocess.call([MAME, "-listxml", game], stdout=fd)
        if res != 0:
            return res

    gm = Game.new('%s/game.xml' % base)

    # Add regions
    dirs = []
    for region in gm.regions():
        dirs.append("patch/%s" % region)

    dirs.append("roms/original/%s" % game)
    dirs.append("roms/patched/%s" % game)

    # Build the directory tree
    for dir in dirs:
        with ignore_exists():
            os.makedirs("%s/%s" % (base, dir))

    # ZIPs to look for
    for rom in gm.related_roms():
        zip = '%s/roms/%s.zip' % (MAME_DIR, rom)
        if os.path.isfile(zip):
            with closing(zipfile.ZipFile(zip, 'r')) as zf:
                zf.extractall('%s/roms/original/%s' % (base, game))

    return 0


COMMANDS = {'init': init,
            'dev': chain(assemble_patch, patch_roms, run),
            'asm': assemble_patch,
            'patch': patch_roms,
            'ap': chain(assemble_patch, patch_roms),
            'run': run,
            'orig': run_orig,
            'play': play
}

def main():
    global MAME_DIR
    global MAME_BIN
    global MAME
    parser = argparse.ArgumentParser(description="Hack Assembler")
    parser.add_argument('--mame-dir', dest='mame_dir',
                        default=os.getenv('MAME_DIR', '.'),
                        help='MAME root directory')
    parser.add_argument('--mame-bin',
                        default=os.getenv('MAME_BIN', 'mame64'),
                        help='MAME binary')

    parser.add_argument('cmd', choices=COMMANDS.keys(),
                        help="Command.")
    parser.add_argument('rest', nargs=argparse.REMAINDER)

    args = parser.parse_args()

    MAME_DIR = os.path.expanduser(args.mame_dir)
    MAME = args.mame_bin

    try:
        return COMMANDS[args.cmd](*args.rest)
    except HAException as e:
        print(e)
        return -2


if __name__ == '__main__':
    sys.exit(main())
