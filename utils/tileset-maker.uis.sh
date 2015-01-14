#!/bin/bash

cd game/engines/default/data/gfx
rm -f ts-*
lua ../../../../../utils/tileset-maker-precise.lua ts-metal-ui /data/gfx/ `find metal-ui/ -name '*png'`
