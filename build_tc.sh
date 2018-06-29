#!/bin/bash

SRC=`realpath src`
DATE_ISO=`date +%Y%m%d`
MODE=$1
CPU_CORES=$NUMBER_OF_PROCESSORS
BUILD=`realpath build`

if [ "$MODE" == "debug" ]; then
  MSBUILD_CONFIG=Debug
elif [ "$MODE" == "release" ]; then
  MSBUILD_CONFIG=Release
elif [ "$MODE" == "clean" ]; then
  rm -rf src build
  exit
else
  echo "Please supply build mode [debug|release|clean]!"
  exit 1
fi

# Compile x264 as static lib
function compile_x264 {
  cd $SRC/x264
  make clean
  CC=cl.exe ./configure --prefix=$BUILD --extra-cflags='-DNO_PREFIX' --disable-cli --enable-static --libdir=$BUILD/lib
  make -j $CPU_CORES
  make install-lib-static
}

function compile_fdk-aac {
  cd $SRC/fdk-aac
  ./autogen.sh
  compile fdk-aac "--disable-static --disable-shared"
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

# Install zimg
function compile_zimg { 
  cd $SRC/zimg
  ./autogen.sh
  ./configure --prefix=$BUILD
  cd _msvc/zimg
  MSBuild.exe /maxcpucount:$CPU_CORES /property:Configuration="$MSBUILD_CONFIG" /property:Platform=x64 /property:WholeProgramOptimization=false zimg.vcxproj
  cp x64/$MSBUILD_CONFIG/z.lib $BUILD/lib/zimg.lib
  cd ../..
  cp src/zimg/api/zimg.h  $BUILD/include/zimg.h
  cp zimg.pc $BUILD/lib/pkgconfig/zimg.pc
}

function compile {
  echo "Compiling '$1' ...";
  cd $SRC/$1
  make clean
  CC=cl.exe ./configure --prefix=$BUILD $2
  make -j $CPU_CORES
  make install
}

# Compile ffmpeg as static lib
function compile_ffmpeg { 
  cd $SRC/ffmpeg
  make clean
  if [ "$MODE" == "debug" ]; then
    CFLAGS=-MDd
  elif [ "$MODE" == "release" ]; then
    CFLAGS=-MD
  fi
  PKG_CONFIG_PATH=$BUILD/lib/pkgconfig:$PKG_CONFIG_PATH ./configure --toolchain=msvc --extra-cflags="$CFLAGS -I$BUILD/include" --extra-ldflags="-LIBPATH:$BUILD/lib" --prefix=$BUILD --pkg-config-flags="--static" --disable-doc --disable-shared --enable-static --enable-gpl --enable-runtime-cpudetect --disable-devices --disable-network --enable-w32threads --enable-libmp3lame --enable-libzimg --enable-avisynth --enable-libx264 --enable-libx265 --enable-cuda --enable-cuvid --enable-d3d11va --enable-nvenc --enable-amf --enable-libmfx --enable-libfdk-aac
  make -j $CPU_CORES
  make install
}

# apply various patches
function apply_patches {
  cd $SRC/ffmpeg
  patch -N -p1 --dry-run --silent -i ../../patches/0001-dynamic-loading-of-shared-fdk-aac-library.patch
  if [ $? -eq 0 ];
  then
    patch -N -p1 -i ../../patches/0001-dynamic-loading-of-shared-fdk-aac-library.patch
  fi
  cd -
}

# Clean build
function clean {
  rm -rf $BUILD
  mkdir $BUILD
  mkdir $BUILD/include/
  mkdir $BUILD/lib
  mkdir $BUILD/lib/pkgconfig
}

apply_patches
compile_fdk-aac
compile_zimg
compile_x264
#compile_x265
#compile_ffnvcodec
#compile_amf
#compile lame "--enable-nasm --disable-frontend --disable-shared --enable-static"
#compile_ffmpeg

exit
# Finish
cd $BUILD/lib
for file in *.a; do
  mv "$file" "`basename "$file" .a`.lib"
done

rm -rf $BUILD/lib/pkgconfig $BUILD/lib/fdk-aac.lib $BUILD/lib/libfdk-aac.la

# Build a package
cd $BUILD
mkdir ../dist 2>/dev/null
tar czf ../dist/ffmpeg-win64-static-$MODE-$DATE_ISO.tar.gz *
