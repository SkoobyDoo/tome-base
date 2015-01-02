#!/bin/bash

make clean
NDK=/huge/android/android-ndk-r10d/
if test $1 = x86; then
	NDKABI=12
	NDKVER=$NDK/toolchains/x86-4.6
	NDKP=$NDKVER/prebuilt/linux-x86_64/bin/i686-linux-android-
	NDKF="--sysroot $NDK/platforms/android-$NDKABI/arch-x86"
	make HOST_CC="gcc -m32" CROSS=$NDKP TARGET_FLAGS="$NDKF"
	cp src/libluajit.a `pwd -L | sed 's@src/t-engine4/luajit2@luajit2/x86/@'`
elif test $1 = armeabi; then
	# Android/ARM, armeabi (ARMv5TE soft-float), Android 2.2+ (Froyo)
	NDKABI=12
	NDKVER=$NDK/toolchains/arm-linux-androideabi-4.6
	NDKP=$NDKVER/prebuilt/linux-x86_64/bin/arm-linux-androideabi-
	NDKF="--sysroot $NDK/platforms/android-$NDKABI/arch-arm"
	make HOST_CC="gcc -m32" CROSS=$NDKP TARGET_FLAGS="$NDKF"
	cp src/libluajit.a `pwd -L | sed 's@src/t-engine4/luajit2@luajit2/armeabi/@'`
elif test $1 = armeabi-v7a; then
	NDKABI=12
	NDKVER=$NDK/toolchains/arm-linux-androideabi-4.6
	NDKP=$NDKVER/prebuilt/linux-x86_64/bin/arm-linux-androideabi-
	NDKF="--sysroot $NDK/platforms/android-$NDKABI/arch-arm"
	NDKARCH="-march=armv7-a -mfloat-abi=softfp -Wl,--fix-cortex-a8"
	make HOST_CC="gcc -m32" CROSS=$NDKP TARGET_FLAGS="$NDKF $NDKARCH"
	cp src/libluajit.a `pwd -L | sed 's@src/t-engine4/luajit2@luajit2/armeabi-v7a/@'`
fi
