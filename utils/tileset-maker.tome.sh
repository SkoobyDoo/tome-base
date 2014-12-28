#!/bin/bash

cd game/modules/tome/data/gfx/
rm -f ts-shockbolt*
lua ../../../../../utils/tileset-maker.lua ts-shockbolt-terrain /data/gfx/ `find shockbolt/terrain/ -name '*png'`
lua ../../../../../utils/tileset-maker.lua ts-shockbolt-npc /data/gfx/ `find shockbolt/npc/ -name '*png'`
lua ../../../../../utils/tileset-maker.lua ts-shockbolt-object /data/gfx/ `find shockbolt/object/ -name '*png'`
lua ../../../../../utils/tileset-maker.lua ts-shockbolt-trap /data/gfx/ `find shockbolt/trap/ -name '*png'`
lua ../../../../../utils/tileset-maker.lua ts-talents /data/gfx/ `find talents/ -name '*png'`
lua ../../../../../utils/tileset-maker.lua ts-effects /data/gfx/ `find effects/ stats/ -name '*png'`
