#! /usr/bin/env python3
# -*- coding: utf-8 -*-
#
# © 2015, 2021, 2022 Ian Eure
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
import configparser
import inspect
import logging
import os
import shutil
import subprocess
import sys
import zipfile
import xml.etree.ElementTree as ET
from contextlib import closing, contextmanager
from functools import reduce
from glob import glob
from pprint import pprint
from typing import Sequence, Optional

logging.basicConfig(level=logging.DEBUG)
MAME_DIR: str = None
MAME_BIN: str = None
MAME: str = None
LOG = logging.getLogger('ha')
LOG.setLevel(logging.INFO)

class HAException(Exception):
    pass


class Config(object):

    """Python representation of a per-patch ha configuration."""

    _cfg: configparser.ConfigParser = None

    def __init__(self, cfg_file: str):
        self._cfg = configparser.ConfigParser()
        self._cfg.read(cfg_file)

    def assembler(self, cpu: str) -> Optional[str]:
        """Return the name of the configured assembler to use, or None."""
        try:
            return self._cfg['assemblers'][cpu]
        except KeyError:
            return None

    def signature_method(self):
        """Return the signature correction method, or None."""
        try:
            name: str = self._cfg['signature']['method']
            return dict(inspect.getmembers(sys.modules[__name__]))[name]
        except KeyError:
            return None

    @classmethod
    def new(cls, cfg_file: str):
        return cls(cfg_file)


class Signature(object):

    """Signature is a base class for automatically fixing ROM signatures."""

    _cfg: configparser.ConfigParser = None
    _name: str = ""
    original: bytes = None,
    patched: bytearray = None

    def __init__(self, cfg: Config, name: str, orig: bytes, patched: bytearray):
        self._cfg = cfg
        self._name = name
        self.original, self.patched = orig, patched


class AtariXOR(Signature):

    """Patch ROMs using Atari XOR method.

    With this method, the bytes of each ROM are XORed together, and
    must equal the ROMs relative position in memory.  This is a fairly
    naive implementation which uses the XOR of the original to
    determine what that should be.
    """

    def _offset(self) -> Optional[int]:
        """Return the offset to put the signature value."""
        raw: str = self._cfg._cfg['signature'][self._name].lower()
        if raw.startswith("0x"):
            return int(raw[2:], 16)
        if raw.startswith("$"):
            return int(raw[1:], 16)
        return int(raw)

    def patch(self) -> bytearray:
        """Patch the ROM."""
        off: int = self._offset()
        orig_xor: int = xor(self.original)
        patched_xor: int = xor(self.patched)
        ob = self.patched[off]
        self.patched[off] = self.patched[off] ^ patched_xor ^ orig_xor
        nob = self.patched[off]
        assert xor(self.patched) == orig_xor, "Patched ROM should XOR to %02x, but is (%02x->%02x) %02x->%02x" % (orig_xor, ob, nob, patched_xor, xor(self.patched))
        return self.patched


class Game(object):

    """A Python representation of a MAME game XML."""

    def __init__(self, xml: ET):
        self.game: ET = xml.getroot().find('game') or xml.getroot().find('machine')
        self.name: str = self.game.attrib['name']

    def cpus(self):
        """Return a map of CPU -> type."""
        return dict([[chip.attrib['tag'], chip.attrib['name']]
                     for chip in self.game.findall('chip')
                     if chip.attrib['type'] == 'cpu'])

    def regions(self) -> Sequence[str]:
        """Return CPU regions."""
        return self.cpus().keys()

    def roms(self):
        """Return ROMs."""
        return self.game.findall('rom')

    def target_rom(self, patch_start: int, patch_end: int):
        """Return the target ROM for a given start address."""
        for rom in self.roms():
            rom_start: int = int(rom.attrib['offset'], 16)
            rom_end: int = rom_start + int(rom.attrib['size'])
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

    def __init__(self, cpu: str, source: str):
        self.cpu = cpu
        self.source = source
        self.dest = source.rsplit('.', 1)[0] + ".bin"
        LOG.debug("[%s] %s -> %s" % (cpu, source, self.dest))

    @classmethod
    def new(cls, cfg_assembler: str, cpu: str, source: str):
        if cfg_assembler:
            return dict(inspect.getmembers(sys.modules[__name__]))[cfg_assembler](cpu, source)
        elif cpu.lower() == "z80":
            return AssembleZ80asm(cpu, source)
        elif '6502' in cpu:
            return AssembleAsm6(cpu, source)
        else:
            raise Exception("No assembler defined for %s" % cpu)



class AssembleZ80asm(Assembler):

    """Z80 Assembler."""

    def assemble(self):
        cmd: Sequence[str] = ["z80asm", "-I", os.path.dirname(self.source),
                              "-o", self.dest, self.source]
        LOG.debug("[%s] %s" % (self.__class__.__name__, " ".join(cmd)))
        subprocess.check_call(cmd)


class AssembleAsm6(Assembler):

    """6502 Assembler."""

    def assemble(self):
        cmd: Sequence[str] = ["asm6", self.source, self.dest]
        LOG.debug("[%s] %s" % (self.__class__.__name__, " ".join(cmd)))
        subprocess.check_call(cmd)


class AssembleCRASM(Assembler):

    """CRASM Assembler.

    CRASM supports 65xx and Z80.
    """

    def assemble(self):
        with current_pwd(os.path.dirname(self.source)):
            sf: str = os.path.basename(self.source)
            dest: str = os.path.basename(self.dest)
            srec: str = dest + ".srec"
            cmd: Sequence[str] = ["crasm", sf, "-lx", "-o", srec]
            LOG.debug("[%s] %s" % (self.__class__.__name__, " ".join(cmd)))
            subprocess.check_call(cmd)
            subprocess.check_call(["srec_cat", srec, "-offset", "-", "-minimum-addr", srec, "-o", dest, "-Binary"])
            os.unlink(srec)


def chain(*cmds):
    """Chain commands together.

       If any command returns a non-zero exit status, abort the chain.
    """
    return lambda: reduce(lambda ret, f: f() if ret == 0 else ret,
                          cmds, 0)


def assemble_patch():
    """Assemble the patch."""
    game: Game = Game.new('game.xml')

    cfg: Config = Config.new('ha.ini')

    for (region, cpu) in game.cpus().items():
        pdir: str = 'patch/' + region
        if not os.path.isdir(pdir):
            LOG.debug("No patch in %s" % pdir)

        for patch in glob('%s/*-*.s' % pdir):
            LOG.debug("Assembling %s" % patch)
            Assembler.new(cfg.assembler(region), cpu, patch).assemble()

    return 0


def patch_roms():
    """Apply patches to ROMs"""
    game: Game = Game.new('game.xml')
    cfg: Config = Config.new('ha.ini')

    orig_roms: Dict[str, bytes] = {}
    patched_roms: Dict[str, bytearray] = {}
    for region in game.regions():
        rdir: str = 'patch/' + region
        if not os.path.isdir(rdir):
            continue

        for patch in glob(rdir + "/*.bin"):
            # Base address of patch
            patch_start: int = int(os.path.basename(patch).split('-', 1)[0], 16)

            # Load patch data
            with open(patch, 'rb') as pfd:
                data: bytes = pfd.read()
            patch_end: int = patch_start + len(data)
            os.unlink(patch)    # Remove patch so it doesn't get reapplied unnecessarily.

            # What ROM?
            (rom_offset, target) = game.target_rom(patch_start, patch_end)
            if rom_offset is None or target is None:
                LOG.error("Can't find ROM to patch for %s" % patch)
                continue

            # Patch
            rom_patch_start: int = patch_start - rom_offset
            LOG.info("Patching %s <- %s" % (target, os.path.basename(patch)))
            if target not in patched_roms:
                with open('roms/original/%s/%s' % (game.name, target), 'rb') as fd:
                    orig_roms[target] = fd.read()
                    patched_roms[target] = bytearray(orig_roms[target])

            patched_roms[target][rom_patch_start:rom_patch_start+len(data)] = data

    # Fixup signatures and write data.
    LOG.debug("Writing patched ROMs")
    sm: Optional[Signature] = cfg.signature_method()
    if sm:
        LOG.debug("Correcting sigs using method %s" % sm.__name__)

    for (name, data) in patched_roms.items():
        if sm:
            data: bytearray = sm(cfg, name, orig_roms[name], data).patch()

        with open('roms/patched/%s/%s' % (game.name, name), 'wb') as fd:
            fd.write(data)

    return 0


def run():
    """Run the current version of the patch."""
    require_mame()
    game: Game = Game.new('game.xml')
    subprocess.call([MAME, "-debug", "-window",
                     "-rompath", "roms/patched;roms/original",
                     game.name])


def play(*args):
    """Run the current version of the patch."""
    require_mame()
    game: Game = Game.new('game.xml')
    cmd = (MAME, "-skip_gameinfo", "-rompath", "roms/patched;roms/original") + args + (game.name,)
    subprocess.call(cmd)


def run_orig():
    """Run the original game."""
    require_mame()
    game: Game = Game.new('game.xml')
    subprocess.call([MAME, "-debug", "-window",
                     "-rompath", "roms/original",
                     game.name])


@contextmanager
def ignore_exists():
    """Swallow OSErrors."""
    try:
        yield
    except OSError as e:
        pass


@contextmanager
def current_pwd(dir: str):
    """Run body in with PWD set to dir."""
    old: str = os.getcwd()
    try:
        os.chdir(dir)
        yield
    finally:
        os.chdir(old)


def require_mame():
    """Verify that MAME is available."""
    if MAME is None:
        raise HAException("You must set MAME_DIR.")
    if not os.path.exists(MAME):
        raise HAException("MAME path %s doesn't exist" % MAME)


def init(game, *dir):
    """Initialize a patch."""
    base: str = dir and dir[0] or game

    require_mame()

    with ignore_exists():
        os.makedirs(base)

    with open('%s/game.xml' % base, 'w') as fd:
        res: int = subprocess.call([MAME, "-listxml", game], stdout=fd)
        if res != 0:
            return res

    gm: Game = Game.new('%s/game.xml' % base)

    # Add regions
    dirs: Sequence[string] = []
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
        zip: str = '%s/roms/%s.zip' % (MAME_DIR, rom)
        if os.path.isfile(zip):
            with closing(zipfile.ZipFile(zip, 'r')) as zf:
                zf.extractall('%s/roms/original/%s' % (base, game))

    return 0


def xor(data) -> int:
    """Return XOR over data."""
    return reduce(lambda a, b: a ^ b, data, 0)


COMMANDS = {'init': init,
            'dev': chain(assemble_patch, patch_roms, run),
            'asm': assemble_patch,
            'patch': patch_roms,
            'ap': chain(assemble_patch, patch_roms),
            'run': run,
            'orig': run_orig,
            'play': play,
}


def main():
    global MAME_DIR
    global MAME_BIN
    global MAME
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description="Hack Assembler")
    parser.add_argument('-v', '--verbose', dest='verbose', default=False,
                        action='store_true',
                        help='Enable debug output')
    parser.add_argument('--mame-dir', dest='mame_dir',
                        default=os.getenv('MAME_DIR', '.'),
                        help='MAME root directory')
    parser.add_argument('--mame-bin',
                        default=os.getenv('MAME_BIN', 'mame'),
                        help='MAME binary')

    parser.add_argument('cmd', choices=COMMANDS.keys(),
                        help="Command.")
    parser.add_argument('rest', nargs=argparse.REMAINDER)

    args: Sequence[string] = parser.parse_args()

    MAME_DIR = os.path.expanduser(args.mame_dir)
    MAME = args.mame_bin
    if args.verbose:
        LOG.setLevel(logging.DEBUG)

    try:
        return COMMANDS[args.cmd](*args.rest)
    except HAException as e:
        print(e)
        return -2


if __name__ == '__main__':
    sys.exit(main())
