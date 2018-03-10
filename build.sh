#!/bin/bash

SRC=`realpath src`
DATE_ISO=`date +%Y%m%d`
MODE=$1
CPU_CORES=10

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
  git checkout master
  git pull
  cd ../..
}

# Clone or update ffnvcodec
function get_source_ffnvcodec {
  if [ ! -d $SRC/ffnvcodec/.git ]; then
    git clone https://github.com/FFmpeg/nv-codec-headers.git $SRC/ffnvcodec
  fi
  cd $SRC/ffnvcodec
  git checkout master
  git pull
  cd ../..
}

# Clone or update amf
function get_source_amf {
  if [ ! -d $SRC/amf/.git ]; then
    git clone https://github.com/GPUOpen-LibrariesAndSDKs/AMF.git $SRC/amf
  fi
  cd $SRC/amf
  git checkout master
  git pull
  cd ../..
}

# Clone or update mfx
function get_source_mfx {
  if [ ! -d $SRC/mfx_dispatch/.git ]; then
    git clone https://github.com/lu-zero/mfx_dispatch.git $SRC/mfx_dispatch
  fi
  cd $SRC/mfx_dispatch
  git checkout master
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
  make -j $CPU_CORES
  make install-lib-static
}

function compile_x265 {
  cd $SRC/x265/build/vc15-x86_64
  rm -rf work*
  mkdir work work10 work12
  # 12bit
  cd work12
  cmake -G "Visual Studio 15 Win64" ../../../source -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DMAIN12=ON
  MSBuild.exe /maxcpucount:$CPU_CORES /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ../work/x265_12bit.lib
  # 10bit
  cd ../work10
  cmake -G "Visual Studio 15 Win64" ../../../source -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF
  MSBuild.exe /maxcpucount:$CPU_CORES /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ../work/x265_10bit.lib
  # 8bit - main
  cd ../work
  cmake -G "Visual Studio 15 Win64" ../../../source -DCMAKE_INSTALL_PREFIX=$BUILD -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DEXTRA_LIB="x265_10bit.lib;x265_12bit.lib" -DLINKED_10BIT=ON -DLINKED_12BIT=ON
  #-DSTATIC_LINK_CRT=ON
  MSBuild.exe /maxcpucount:$CPU_CORES /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ./x265_main.lib
  LIB.EXE /ignore:4006 /ignore:4221 /OUT:x265.lib x265_main.lib x265_10bit.lib x265_12bit.lib
  cp x265.lib $BUILD/lib/x265.lib
  cp x265.pc $BUILD/lib/pkgconfig/x265.pc
  cp x265_config.h $BUILD/include/
  cp ../../../source/x265.h $BUILD/include/
}

# Install nv-codec-headers
function compile_ffnvcodec { 
  cd $SRC/ffnvcodec
  make PREFIX=$BUILD install
}

# Install amf
function compile_amf { 
  cp -a $SRC/amf/amf/public/include $BUILD/include/AMF
}

# Install mfx_dispatch
function compile_mfx { 
  cd $SRC/mfx_dispatch
  cmake -G "Visual Studio 15 Win64" -DCMAKE_INSTALL_PREFIX=$BUILD
  MSBuild.exe /maxcpucount:$CPU_CORES /property:Configuration="$MSBUILD_CONFIG" mfx.vcxproj
  cp $MSBUILD_CONFIG/mfx.lib $BUILD/lib/libmfx.lib
  cp libmfx.pc $BUILD/lib/pkgconfig/libmfx.pc
  sed -i 's/-lsupc++ .*/-llibmfx -ladvapi32/' "$BUILD/lib/pkgconfig/libmfx.pc"
  cp -a $SRC/mfx_dispatch/mfx $BUILD/include/mfx
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
  PKG_CONFIG_PATH=$BUILD/lib/pkgconfig:$PKG_CONFIG_PATH ./configure --toolchain=msvc --extra-cflags="$CCFLAGS" --prefix=$BUILD --pkg-config-flags="--static" --disable-programs --disable-doc --disable-shared --enable-static --enable-gpl --enable-runtime-cpudetect --disable-hwaccels --disable-devices --disable-network --enable-w32threads --enable-avisynth --enable-libx264 --enable-libx265 --enable-cuda --enable-cuvid --enable-d3d11va --enable-nvenc --enable-amf --enable-libmfx
  make -j $CPU_CORES
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
get_source_ffnvcodec
get_source_amf
get_source_mfx
get_source_x264
get_source_x265
compile_x264
compile_x265
compile_ffnvcodec
compile_amf
compile_mfx
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
