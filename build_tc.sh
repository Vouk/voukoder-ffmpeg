#!/bin/bash

STEP=$1
MODE=$2
CPU_CORES=$3
SRC=`realpath src`
BUILD=`realpath build`

if [ "$MODE" == "debug" ]; then
  MSBUILD_CONFIG=Debug
elif [ "$MODE" == "release" ]; then
  MSBUILD_CONFIG=Release
else
  echo "Please supply build mode [debug|release]!"
  exit 1
fi

function compile {
  cd $SRC/$1
  CC=cl ./configure --prefix=$BUILD $2
  make -j $CPU_CORES
  make install
}

if [ "$STEP" == "libfdk-aac" ]; then
  cd $SRC/fdk-aac
  ./autogen.sh
  compile fdk-aac "--disable-static --disable-shared"
elif [ "$STEP" == "lame" ]; then
  compile lame "--enable-nasm --disable-frontend --disable-shared --enable-static"
elif [ "$STEP" == "zimg" ]; then
  cd $SRC/zimg
  ./autogen.sh
  ./configure --prefix=$BUILD
  cd _msvc/zimg
  MSBuild.exe /maxcpucount:$CPU_CORES /property:Configuration="$MSBUILD_CONFIG" /property:Platform=x64 /property:WholeProgramOptimization=false zimg.vcxproj
  cp x64/$MSBUILD_CONFIG/z.lib $BUILD/lib/zimg.lib
  cd ../..
  cp src/zimg/api/zimg.h  $BUILD/include/zimg.h
  cp zimg.pc $BUILD/lib/pkgconfig/zimg.pc
elif [ "$STEP" == "x264" ]; then
  cd $SRC/x264
  CC=cl ./configure --prefix=$BUILD --extra-cflags='-DNO_PREFIX' --disable-cli --enable-static --libdir=$BUILD/lib
  make -j $CPU_CORES
  make install-lib-static
elif [ "$STEP" == "x265" ]; then
  # checkout manually (cmake is getting values from git)
  cd $src/..
  if [ ! -d $SRC/x265/.git ]; then
    git clone https://github.com/videolan/x265.git $SRC/x265
  fi
  git reset --hard
  git pull
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
elif [ "$STEP" == "libogg" ]; then
  compile libogg "--disable-shared"
elif [ "$STEP" == "libvorbis" ]; then
  compile libvorbis "--disable-shared"
elif [ "$STEP" == "libvpx" ]; then
  compile libvpx "--disable-shared"
elif [ "$STEP" == "ffmpeg" ]; then
  echo "### Copying NVENC headers ..."
  cd $SRC/ffnvcodec
  make PREFIX=$BUILD install
  
  echo "### Copying AMF headers ..."
  cp -a $SRC/amf/amf/public/include $BUILD/include/AMF
  
  echo "### Applying patches ..."
  cd $SRC/ffmpeg
  patch -N -p1 --dry-run --silent -i ../../patches/0001-dynamic-loading-of-shared-fdk-aac-library.patch
  if [ $? -eq 0 ];
  then
    patch -N -p1 -i ../../patches/0001-dynamic-loading-of-shared-fdk-aac-library.patch
  fi
  
  echo "### Compiling FFMpeg ..."
  cd $SRC/ffmpeg
  if [ "$MODE" == "debug" ]; then
    CFLAGS=-MDd
  elif [ "$MODE" == "release" ]; then
    CFLAGS=-MD
  fi
  PKG_CONFIG_PATH=$BUILD/lib/pkgconfig:$PKG_CONFIG_PATH ./configure --toolchain=msvc --extra-cflags="$CFLAGS -I$BUILD/include" --extra-ldflags="-LIBPATH:$BUILD/lib" --prefix=$BUILD --pkg-config-flags="--static" --disable-doc --disable-shared --enable-static --enable-gpl --enable-runtime-cpudetect --disable-devices --disable-network --enable-w32threads --enable-libmp3lame --enable-libzimg --enable-avisynth --enable-libx264 --enable-libx265 --enable-cuda --enable-cuvid --enable-d3d11va --enable-nvenc --enable-amf --enable-libfdk-aac
  make -j $CPU_CORES
  make install
  
  # rename *.a to *.lib
  cd $BUILD/lib
  for file in *.a; do
    mv "$file" "`basename "$file" .a`.lib"
  done

  # clean up
  rm -rf $BUILD/lib/pkgconfig $BUILD/lib/fdk-aac.lib $BUILD/lib/*.la
  
  # Create archives
  cd $BUILD
  mkdir ../dist 2>/dev/null
  tar czf ../dist/ffmpeg-win64-static-$MODE.tar.gz *
  cd $SRC/ffmpeg
  tar czf ../../dist/ffmpeg-win64-static-src-$MODE.tar.gz *
else
  echo "Unknown build step!"
  exit 1
fi
