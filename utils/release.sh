#!/bin/sh

if test $# -lt 3 ; then
	echo "Usage: release.sh [engine version for teae] [tome version for team] [version for public]"
	exit
fi

if test -f game/modules/tome/data/gfx/ts-shockbolt-npc.lua; then
	echo "***********************************************************"
	echo "***********************************************************"
	echo "**************** TILESET MODE already active! *************"
	echo "***********************************************************"
	echo "***********************************************************"
	echo "Removing tilsets..."
	rm -f game/modules/tome/data/gfx/ts-*lua game/modules/tome/data/gfx/ts-*png
	echo "...done"
	echo
fi

echo "*********** Compute tilesets? (Y/n)"
read ok
if test "$ok" '!=' 'n'; then
	sh utils/tileset-maker.tome.sh 2>/dev/null
fi

echo "*********** Make sure bunbled addons are updated. Ok ? (Y/n)"
read ok
if test "$ok" '=' 'n'; then exit; fi

# Check validity
echo "Validating lua files..."
find game/ bootstrap/ -name '*lua' | xargs -n1 luac -p
if test $? -ne 0 ; then
	echo "Invalid lua files!"
	exit 1
fi
echo "...done"

ever="$1"
tver="$2"
ver="$3"

rm -rf tmp
mkdir tmp
cd tmp
mkdir t-engine4-windows-"$ver"
mkdir t-engine4-src-"$ver"
mkdir t-engine4-linux32-"$ver"
mkdir t-engine4-linux64-"$ver"
mkdir t-engine4-osx-"$ver"

# src
echo "******************** Src"
cd t-engine4-src-"$ver"
cp -a ../../bootstrap/  ../../game/ ../../C* ../../premake4.lua ../../src/ ../../build/ ../../mac/  .
rm -rf mac/base_app/
rm -rf game/modules/angband
rm -rf game/modules/rogue
rm -rf game/modules/gruesome
find . -name '*~' -or -name '.svn' -or -name '.keep' | xargs rm -rf

# create teae/teams
cd game/engines
te4_pack_engine.sh default/ te4-"$ever"
te4_pack_engine.sh default/ te4-"$ever" 1
\cp -f te4-*.teae boot-te4-*.team /foreign/eyal/var/www/te4.org/htdocs/dl/engines
mv boot*team ../modules
rm -rf default
cd ../modules
te4_pack_module_tome.sh tome "$tver"
#te4_pack_module.sh tome "$tver" 1
\cp -f tome*.team /foreign/eyal/var/www/te4.org/htdocs/dl/modules/tome/
rm -f tome*nomusic.team
rm -f boot*nomusic.team
rm -rf tome
cd ../../

cd ..
tar cvjf t-engine4-src-"$ver".tar.bz2 t-engine4-src-"$ver"

# windows
echo "******************** Windows"
cd t-engine4-windows-"$ver"
cp -a ../../bootstrap/  ../t-engine4-src-"$ver"/game/ ../../C* ../../dlls/* .
find . -name '*~' -or -name '.svn' | xargs rm -rf
cd ..
zip -r -9 t-engine4-windows-"$ver".zip t-engine4-windows-"$ver"

# linux 32
echo "******************** linux32"
cd t-engine4-linux32-"$ver"
cp -a ../../bootstrap/  ../t-engine4-src-"$ver"/game/ ../../C* ../../linux-bin/* .
find . -name '*~' -or -name '.svn' | xargs rm -rf
cd ..
tar -cvjf t-engine4-linux32-"$ver".tar.bz2 t-engine4-linux32-"$ver"

# linux 64
echo "******************** linux64"
cd t-engine4-linux64-"$ver"
cp -a ../../bootstrap/  ../t-engine4-src-"$ver"/game/ ../../C* ../../linux-bin64/* .
find . -name '*~' -or -name '.svn' | xargs rm -rf
cd ..
tar -cvjf t-engine4-linux64-"$ver".tar.bz2 t-engine4-linux64-"$ver"

# OSX
echo "******************** OSX"
cd t-engine4-osx-"$ver"
mkdir T-Engine.app/
cp -a ../../mac/base_app/* T-Engine.app/
cp -a ../../bootstrap/ T-Engine.app/Contents/MacOS/
cp -a ../t-engine4-src-"$ver"/game/ .
cp -a ../../C* .
find . -name '*~' -or -name '.svn' | xargs rm -rf
zip -r -9 ../t-engine4-osx-"$ver".zip *
cd ..

#### Music less

# src
echo "******************** Src n/m"
cd t-engine4-src-"$ver"
IFS=$'\n'; for i in `find game/ -name '*.ogg'`; do
	echo "$i"|grep '/music/' -q
	if test $? -eq 0; then rm "$i"; fi
done
rm game/modules/tome*-music.team
rm game/modules/boot*team
cp /foreign/eyal/var/www/te4.org/htdocs/dl/engines/boot-te4-"$ever"-nomusic.team game/modules/
cd ..
tar cvjf t-engine4-src-"$ver"-nomusic.tar.bz2 t-engine4-src-"$ver"

# windows
echo "******************** Windows n/m"
cd t-engine4-windows-"$ver"
IFS=$'\n'; for i in `find game/ -name '*.ogg'`; do
	echo "$i"|grep '/music/' -q
	if test $? -eq 0; then rm "$i"; fi
done
rm game/modules/tome*-music.team
rm game/modules/boot*team
cp /foreign/eyal/var/www/te4.org/htdocs/dl/engines/boot-te4-"$ever"-nomusic.team game/modules/
cd ..
zip -r -9 t-engine4-windows-"$ver"-nomusic.zip t-engine4-windows-"$ver"

# linux 32
echo "******************** linux32 n/m"
cd t-engine4-linux32-"$ver"
IFS=$'\n'; for i in `find game/ -name '*.ogg'`; do
	echo "$i"|grep '/music/' -q
	if test $? -eq 0; then rm "$i"; fi
done
rm game/modules/tome*-music.team
rm game/modules/boot*team
cp /foreign/eyal/var/www/te4.org/htdocs/dl/engines/boot-te4-"$ever"-nomusic.team game/modules/
cd ..
tar -cvjf t-engine4-linux32-"$ver"-nomusic.tar.bz2 t-engine4-linux32-"$ver"

# linux 64
echo "******************** linux64 n/m"
cd t-engine4-linux64-"$ver"
IFS=$'\n'; for i in `find game/ -name '*.ogg'`; do
	echo "$i"|grep '/music/' -q
	if test $? -eq 0; then rm "$i"; fi
done
rm game/modules/tome*-music.team
rm game/modules/boot*team
cp /foreign/eyal/var/www/te4.org/htdocs/dl/engines/boot-te4-"$ever"-nomusic.team game/modules/
cd ..
tar -cvjf t-engine4-linux64-"$ver"-nomusic.tar.bz2 t-engine4-linux64-"$ver"

cp *zip *bz2 *dmg.gz /foreign/eyal/var/www/te4.org/htdocs/dl/t-engine

########## Announce

echo
echo "Download links:"
echo "http://te4.org/dl/t-engine/t-engine4-windows-$ver.zip"
echo "http://te4.org/dl/t-engine/t-engine4-src-$ver.tar.bz2"
echo "http://te4.org/dl/t-engine/t-engine4-linux32-$ver.tar.bz2"
echo "http://te4.org/dl/t-engine/t-engine4-linux64-$ver.tar.bz2"
echo "http://te4.org/dl/t-engine/t-engine4-windows-$ver-nomusic.zip"
echo "http://te4.org/dl/t-engine/t-engine4-src-$ver-nomusic.tar.bz2"
echo "http://te4.org/dl/t-engine/t-engine4-linux32-$ver-nomusic.tar.bz2"
echo "http://te4.org/dl/t-engine/t-engine4-linux64-$ver-nomusic.tar.bz2"
echo "http://te4.org/dl/t-engine/t-engine4-osx-$ver.zip"

########## MD5
echo "Computing MD5s..."
cd t-engine4-linux64-"$ver"
rm lib64/libopenal.so.1
rm -f all.md5
DISPLAY=:1 ./t-engine -Mtome -n -E'compute_md5_only="all.md5" sleep_on_auth=2' > /dev/null 2>&1
cd ..
echo "..done"
echo

######### SQL
echo "*********** Publish release? (Y/n)"
cd ..
read ok
if test "$ok" '!=' 'n'; then
	sh utils/publish_release.sh "$ver" tmp/t-engine4-linux64-"$ver"/all.md5
fi
