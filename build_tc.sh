#!/bin/bash

STEP=$1
MODE=$2
CPU_CORES=$3
ENABLED_TOOLS=$4
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

if [ ! -d "$BUILD" ]; then
  mkdir $BUILD $BUILD/include $BUILD/lib
fi

function compile {
  cd $SRC/$1
  if [ -f autogen.sh ]; then
    ./autogen.sh
  fi
  CC=cl ./configure --prefix=$BUILD $2
  make -j $CPU_CORES
  make install
}

if [ "$STEP" == "libmfx" ]; then
  cd $SRC/libmfx
  if [[ ! -f "configure" ]]; then
      autoreconf -fiv || exit 1
  fi
  if [ "$MODE" == "debug" ]; then
    compile libmfx "--enable-debug"
  else
    compile libmfx ""
  fi
  sed -i 's/-lstdc++/-ladvapi32/g' $BUILD/lib/pkgconfig/libmfx.pc
elif [ "$STEP" == "opus" ]; then
  cd $SRC/opus/win32/VS2015
  echo \nConverting project file ...
  sed -i 's/v140/v141/g' opus.vcxproj
  echo Building project 'opus' ...
  MSBuild.exe /maxcpucount:$CPU_CORES /property:Configuration="$MSBUILD_CONFIG" /property:Platform=x64 opus.vcxproj
  echo Done.
  cp x64/$MSBUILD_CONFIG/opus.lib $BUILD/lib/opus.lib
  cp -r $SRC/opus/include $BUILD/include/opus
  cp $SRC/opus/opus.pc.in $BUILD/lib/pkgconfig/opus.pc
  sed -i "s#@prefix@#$BUILD#g" $BUILD/lib/pkgconfig/opus.pc
  sed -i "s/@exec_prefix@/\$\{prefix\}/g" $BUILD/lib/pkgconfig/opus.pc
  sed -i "s/@libdir@/\$\{prefix\}\/lib/g" $BUILD/lib/pkgconfig/opus.pc
  sed -i "s/@includedir@/\$\{prefix\}\/include/g" $BUILD/lib/pkgconfig/opus.pc
  sed -i "s/@LIBM@//g" $BUILD/lib/pkgconfig/opus.pc
  sed -i "s/@VERSION@/2.0.0/g" $BUILD/lib/pkgconfig/opus.pc
elif [ "$STEP" == "libfdk-aac" ]; then
  compile fdk-aac "--disable-static --disable-shared"
elif [ "$STEP" == "lame" ]; then
  compile lame "--enable-nasm --disable-frontend --disable-shared --enable-static"
elif [ "$STEP" == "zimg" ]; then
  cd $SRC/zimg
  ./autogen.sh
  ./configure --prefix=$BUILD
  cd _msvc/zimg
  MSBuild.exe /maxcpucount:$CPU_CORES /property:Configuration="$MSBUILD_CONFIG" /property:WindowsTargetPlatformVersion=10.0.17134.0 /property:PlatformToolset=v141 /property:Platform=x64 /property:WholeProgramOptimization=false zimg.vcxproj
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
    git clone https://github.com/videolan/x265.git --branch stable $SRC/x265
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
  sed -i '/^Libs\.private.*/d' $BUILD/lib/pkgconfig/vorbis.pc  # don't need m.lib on windows
elif [ "$STEP" == "libvpx" ]; then
  cd $SRC/libvpx
  ./configure --prefix=$BUILD --target=x86_64-win64-vs15 --enable-vp9-highbitdepth --disable-shared --disable-examples --disable-tools --disable-docs --disable-libyuv --disable-unit_tests --disable-postproc
  make -j $CPU_CORES
  make install
  mv $BUILD/lib/x64/vpxmd.lib $BUILD/lib/vpx.lib
  rm -rf $BUILD/lib/x64
elif [ "$STEP" == "snappy" ]; then
  cd $SRC/snappy
  rm -rf work
  mkdir work
  cd work
  cmake -G "Visual Studio 15 Win64" .. -DCMAKE_INSTALL_PREFIX=$BUILD -DBUILD_SHARED_LIBS=OFF -DSNAPPY_BUILD_TESTS=OFF
  MSBuild.exe /maxcpucount:$CPU_CORES /property:Configuration="$MSBUILD_CONFIG" Snappy.sln
  cp $MSBUILD_CONFIG/snappy.lib $BUILD/lib/snappy.lib
  cp ../snappy.h ../snappy-c.h $BUILD/include/
elif [ "$STEP" == "libaom" ]; then
  cd $SRC/libaom
  rm -rf work
  mkdir work
  cd work
  cmake -G "Visual Studio 15 Win64" .. -DENABLE_{DOCS,TOOLS,TESTS}=off -DAOM_TARGET_CPU=x86_64 -DCMAKE_INSTALL_PREFIX=$BUILD
  MSBuild.exe /maxcpucount:$CPU_CORES /property:Configuration="$MSBUILD_CONFIG" AOM.sln
  cp $MSBUILD_CONFIG/aom.lib $BUILD/lib/aom.lib
  cp -r ../aom $BUILD/include/aom
  cmake -DAOM_CONFIG_DIR=. -DAOM_ROOT=.. -DCMAKE_INSTALL_PREFIX=@prefix@ -DCMAKE_PROJECT_NAME=aom -DCONFIG_MULTITHREAD=true -DHAVE_PTHREAD_H=false -P "../build/cmake/pkg_config.cmake"
  sed -i "s#@prefix@#$BUILD#g" aom.pc
  sed -i '/^Libs\.private.*/d' aom.pc
  sed -i 's/-lm//' aom.pc
  cp aom.pc $BUILD/lib/pkgconfig/aom.pc
  
elif [ "$STEP" == "ffmpeg" ]; then
  echo "### Copying NVENC headers ..."
  cd $SRC/ffnvcodec
  make PREFIX=$BUILD install
  
  echo "### Copying AMF headers ..."
  cp -a $SRC/amf/amf/public/include $BUILD/include/AMF
  
  echo "### Applying patches ..."
  cd $SRC/ffmpeg
  
  ffbranch=$(git rev-parse --abbrev-ref HEAD)
  echo "FFMpeg branch: $ffbranch ..."
  if [ "$ffbranch" == "release/4.0" ]; then
    patch -N -p1 -i ../../patches/0001-dynamic-loading-of-shared-fdk-aac-library-4.0.patch
    patch -N -p0 -i ../../patches/0002-patch-ffmpeg-to-new-fdk-api.patch
  else  
    patch -N -p1 -i ../../patches/0001-dynamic-loading-of-shared-fdk-aac-library.patch
  fi
  
  echo "### Compiling FFMpeg ..."
  cd $SRC/ffmpeg
  if [ "$MODE" == "debug" ]; then
    CFLAGS=-MDd
  elif [ "$MODE" == "release" ]; then
    CFLAGS=-MD
  fi
  PKG_CONFIG_PATH=$BUILD/lib/pkgconfig:$PKG_CONFIG_PATH ./configure --toolchain=msvc --extra-cflags="$CFLAGS -I$BUILD/include" --extra-ldflags="-LIBPATH:$BUILD/lib" --prefix=$BUILD --pkg-config-flags="--static" --disable-doc --disable-shared --enable-static --enable-runtime-cpudetect --disable-devices --disable-network --enable-w32threads $ENABLED_TOOLS
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
