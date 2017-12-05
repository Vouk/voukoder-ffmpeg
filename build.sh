#!/bin/bash

SRC=`realpath src`
DATE_ISO=`date +%Y%m%d`
MODE=$1

if [ "$MODE" == "debug" ]; then
  BUILD=`realpath build_debug`
  MSBUILD_CONFIG=Debug
elif [ "$MODE" == "release" ]; then
  BUILD=`realpath build_release`
  MSBUILD_CONFIG=Release
else
  echo "Please supply build mode [debug|release]!"
  exit 1
fi

# Clone or update ffmpeg
function get_source_ffmpeg {
  if [ ! -d $SRC/ffmpeg/.git ]; then
    git clone https://git.ffmpeg.org/ffmpeg.git $SRC/ffmpeg
  fi
  cd $SRC/ffmpeg
  git checkout release/3.4
  git pull
  cd ../..
}

# Clone or update x264
function get_source_x264 {
  if [ ! -d $SRC/x264/.git ]; then
    git clone git://git.videolan.org/x264.git $SRC/x264
  fi
  cd $SRC/x264
  git checkout master
  git pull
  cd ../..
}

# Clone or update x265
function get_source_x265 {
  if [ ! -d $SRC/x265/.git ]; then
    git clone git://github.com/videolan/x265.git $SRC/x265
  fi
  cd $SRC/x265
  git checkout master
  git pull
  cd ../..
}

# Clone or update fdk-aac
function get_source_fdk_aac {
  if [ ! -d $SRC/fdk-aac/.git ]; then
    git clone git://github.com/mstorsjo/fdk-aac.git $SRC/fdk-aac
  fi
  cd $SRC/fdk-aac
  git checkout master
  git pull
  cd ../..
}

# Compile x264 as static lib
function compile_x264 {
  cd $SRC/x264
  make clean
  CC=cl ./configure --prefix=$BUILD --extra-cflags='-DNO_PREFIX' --disable-cli --enable-static --libdir=$BUILD/lib
  make
  make install-lib-static
}

function compile_x265 {
  cd $SRC/x265/build/vc15-x86_64
  rm -rf work*
  mkdir work work10 work12
  # 12bit
  cd work12
  cmake -G "Visual Studio 15 Win64" ../../../source -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DMAIN12=ON
  MSBuild.exe /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ../work/x265_12bit.lib
  # 10bit
  cd ../work10
  cmake -G "Visual Studio 15 Win64" ../../../source -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF
  MSBuild.exe /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ../work/x265_10bit.lib
  # 8bit - main
  cd ../work
  cmake -G "Visual Studio 15 Win64" ../../../source -DCMAKE_INSTALL_PREFIX=$BUILD -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DEXTRA_LIB="x265_10bit.lib;x265_12bit.lib" -DLINKED_10BIT=ON -DLINKED_12BIT=ON
  #-DSTATIC_LINK_CRT=ON
  MSBuild.exe /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ./x265_main.lib
  LIB.EXE /ignore:4006 /ignore:4221 /OUT:x265.lib x265_main.lib x265_10bit.lib x265_12bit.lib
  cp x265.lib $BUILD/lib/x265.lib
  cp x265.pc $BUILD/lib/pkgconfig/x265.pc
  cp x265_config.h $BUILD/include/
  cp ../../../source/x265.h $BUILD/include/
}

# Compile ffmpeg as static lib
function compile_ffmpeg { 
  cd $SRC/ffmpeg
  make clean
  if [ "$MODE" == "debug" ]; then
    CCFLAGS=-MDd
  elif [ "$MODE" == "release" ]; then
    CCFLAGS=-MD
  fi
  PKG_CONFIG_PATH=$BUILD/lib/pkgconfig:$PKG_CONFIG_PATH ./configure --toolchain=msvc --extra-cflags="$CCFLAGS" --prefix=$BUILD --pkg-config-flags="--static" --disable-programs --disable-shared --enable-static --enable-gpl --enable-runtime-cpudetect --disable-hwaccels --disable-devices --disable-network --enable-avisynth --enable-libx264 --enable-libx265
  make
  make install
}

# Clean build
function clean {
  rm -rf $BUILD
  mkdir $BUILD
  mkdir $BUILD/include/
  mkdir $BUILD/lib
  mkdir $BUILD/lib/pkgconfig
}

clean
get_source_ffmpeg
get_source_x264
get_source_x265
compile_x264
compile_x265
compile_ffmpeg

# Finish
cd $BUILD/lib
for file in *.a; do
  mv "$file" "`basename "$file" .a`.lib"
done

rm -rf $BUILD/lib/pkgconfig

# Build a package
cd $BUILD
mkdir ../dist 2>/dev/null
tar czf ../dist/ffmpeg-win64-static-$MODE-$DATE_ISO.tar.gz *
