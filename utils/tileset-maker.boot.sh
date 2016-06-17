#!/bin/bash

base=`pwd -P`
cd game/engines/default/modules/boot/data/gfx/
rm -f ts-gfx-*
lua "$base"/utils/tileset-maker.lua 1024 1024 ts-gfx-terrain /data/gfx/ invis.png `find terrain/ -name '*png'`
lua "$base"/utils/tileset-maker.lua 512 256 ts-gfx-npc /data/gfx/ `find npc/ -name '*png'`
