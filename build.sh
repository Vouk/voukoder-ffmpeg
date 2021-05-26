#!/bin/bash

COMPONENTS=""

if [ "$MODE" == "debug" ]; then
  MSBUILD_CONFIG=Debug
  CFLAGS=-MDd
elif [ "$MODE" == "release" ]; then
  MSBUILD_CONFIG=Release
  CFLAGS=-MD
else
  echo "Please supply build mode [debug|release]!"
  exit 1
fi

function build {
  cd $SRC/$1
  if [ -f autogen.sh ]; then
    ./autogen.sh
  fi
  CC=cl CXXFLAGS=$CFLAGS ./configure --prefix=$BUILD $2
  make -j $NUMBER_OF_PROCESSORS
  make install
}

function build_nvenc {
  git clone -b sdk/9.1 git://github.com/FFmpeg/nv-codec-headers.git $SRC/ffnvcodec
  cd $SRC/ffnvcodec
  make PREFIX=$BUILD install
  add_comp nvenc
}

function build_amf {
  git clone git://github.com/GPUOpen-LibrariesAndSDKs/AMF.git $SRC/amf
  cp -a $SRC/amf/amf/public/include $BUILD/include/AMF
  add_comp amf
}

function build_mfx {
  git clone https://github.com/lu-zero/mfx_dispatch.git $SRC/libmfx
  cd $SRC/libmfx
  #git checkout c200d833e25a91e3e49d69890dac1ffa3486cbe9
  if [[ ! -f "configure" ]]; then
      autoreconf -fiv || exit 1
  fi
  build libmfx
  sed -i 's/-lstdc++/-ladvapi32/g' $BUILD/lib/pkgconfig/libmfx.pc
  add_comp libmfx
}

function build_aom {
  git clone https://aomedia.googlesource.com/aom $SRC/libaom
  cd $SRC/libaom
  rm -rf work
  mkdir work
  cd work
  cmake -G "Visual Studio 15 2017" .. -A x64 -DENABLE_{DOCS,TOOLS,TESTS}=off -DAOM_TARGET_CPU=x86_64 -DCMAKE_INSTALL_PREFIX=$BUILD
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" AOM.sln
  cp $MSBUILD_CONFIG/aom.lib $BUILD/lib/aom.lib
  cp -r ../aom $BUILD/include/aom
  cmake -DAOM_CONFIG_DIR=. -DAOM_ROOT=.. -DCMAKE_INSTALL_PREFIX=@prefix@ -DCMAKE_PROJECT_NAME=aom -DCONFIG_MULTITHREAD=true -DHAVE_PTHREAD_H=false -P "../build/cmake/pkg_config.cmake"
  sed -i "s#@prefix@#$BUILD#g" aom.pc
  sed -i '/^Libs\.private.*/d' aom.pc
  sed -i 's/-lm//' aom.pc
  cp aom.pc $BUILD/lib/pkgconfig/aom.pc
  add_comp libaom
}

function build_svt {
  # HEVC
  #git clone https://github.com/OpenVisualCloud/SVT-HEVC.git $SRC/svt-hevc
  #cd $SRC/svt-hevc/Build
  #cmake .. -G"Visual Studio 15 2017" -A x64 -DCMAKE_INSTALL_PREFIX=$BUILD -DCMAKE_CONFIGURATION_TYPES=$MSBUILD_CONFIG
  #MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration=$MSBUILD_CONFIG /property:ConfigurationType=StaticLibrary /property:TargetExt=.lib svt-hevc.sln  
  #cp -r ../Source/API $BUILD/include/svt-hevc ; cp ../Bin/$MSBUILD_CONFIG/SvtHevcEnc.lib $BUILD/lib/ ; cp SvtHevcEnc.pc $BUILD/lib/pkgconfig/
  #add_comp libsvthevc
  #
  # AV1 (patch needed for FFmpeg 4.3)
  git clone --depth 1  https://github.com/AOMediaCodec/SVT-AV1 $SRC/svt-av1
  cd $SRC/svt-av1/Build/windows
  ./build.bat 2017 $MODE static
  # cmake .. -G"Visual Studio 15 2017" -A x64 -DCMAKE_INSTALL_PREFIX=$BUILD -DCMAKE_CONFIGURATION_TYPES=$MSBUILD_CONFIG
  # MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration=$MSBUILD_CONFIG /property:ConfigurationType=StaticLibrary /p:EB_DLL /property:TargetExt=.lib Source/Lib/Encoder/SvtAv1Enc.vcxproj
  # sed -i 's/C:/\/c/g' SvtAv1Enc.pc
  cp -r ../../Source/API $BUILD/include/svt-av1 ; cp ../../Bin/$MSBUILD_CONFIG/SvtAv1Enc.lib $BUILD/lib/ ; cp SvtAv1Enc.pc $BUILD/lib/pkgconfig/
  add_comp libsvtav1
  #
  # VP9
  #git clone https://github.com/OpenVisualCloud/SVT-VP9.git $SRC/svt-vp9
  #cd $SRC/svt-vp9/Build
  #cmake .. -G"Visual Studio 15 2017" -A x64 -DCMAKE_INSTALL_PREFIX=$BUILD -DCMAKE_CONFIGURATION_TYPES=$MSBUILD_CONFIG
  #MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration=$MSBUILD_CONFIG /property:ConfigurationType=StaticLibrary /property:TargetExt=".lib" svt-vp9.sln
  #cp -r ../Source/API $BUILD/include/svt-vp9 ; cp ../Bin/$MSBUILD_CONFIG/SvtVp9Enc.lib $BUILD/lib/ ; cp SvtVp9Enc.pc $BUILD/lib/pkgconfig/
  #sed -i 's/ -lpthread//g' $BUILD/lib/pkgconfig/SvtVp9Enc.pc
  #sed -i 's/ -lm//g' $BUILD/lib/pkgconfig/SvtVp9Enc.pc
  #add_comp libsvtvp9
  cd $SRC/ffmpeg
  #git apply $SRC/svt-hevc/ffmpeg_plugin/0001-lavc-svt_hevc-add-libsvt-hevc-encoder-wrapper.patch
  #git apply $SRC/svt-av1/ffmpeg_plugin/0001-Add-ability-for-ffmpeg-to-run-svt-av1-with-svt-hevc.patch
  #git apply $SRC/svt-vp9/ffmpeg_plugin/0001-Add-ability-for-ffmpeg-to-run-svt-vp9-with-hevc-av1.patch
  #git am $SRC/svt-hevc/ffmpeg_plugin/0001*.patch
  #git apply $SRC/svt-av1/ffmpeg_plugin/0001-Add-ability-for-ffmpeg-to-run-svt-av1.patch
}

function build_ogg {
  git clone https://github.com/xiph/ogg.git $SRC/libogg
  cd $SRC/libogg
  build libogg "--disable-shared"
}

function build_libass {
  git clone https://github.com/libass/libass.git $SRC/libass
  cd $SRC/libass
  build libass "--disable-shared"  
  add_comp libass
}

function build_vorbis {
  git clone https://github.com/xiph/vorbis.git $SRC/libvorbis
  cd $SRC/libvorbis
  build libvorbis "--disable-shared"  
  sed -i '/^Libs\.private.*/d' $BUILD/lib/pkgconfig/vorbis.pc  # don't need m.lib on windows
  add_comp libvorbis
}

function build_snappy {
  git clone -b 1.1.8 https://github.com/google/snappy.git $SRC/snappy
  cd $SRC/snappy
  rm -rf work
  mkdir work
  cd work
  cmake -G "Visual Studio 15 Win64" .. -DCMAKE_INSTALL_PREFIX=$BUILD -DBUILD_SHARED_LIBS=OFF -DSNAPPY_BUILD_TESTS=OFF
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" Snappy.sln
  cp $MSBUILD_CONFIG/snappy.lib $BUILD/lib/snappy.lib
  cp ../snappy.h ../snappy-c.h $BUILD/include/
  add_comp libsnappy
}

function build_libvpx {
  git clone https://github.com/webmproject/libvpx.git $SRC/libvpx
  cd $SRC/libvpx
  ./configure --prefix=$BUILD --target=x86_64-win64-vs15 --enable-vp9-highbitdepth --disable-shared --disable-examples --disable-tools --disable-docs --disable-libyuv --disable-unit_tests --disable-postproc
  make -j $NUMBER_OF_PROCESSORS
  make install
  mv $BUILD/lib/x64/vpxmd.lib $BUILD/lib/vpx.lib
  rm -rf $BUILD/lib/x64
  add_comp libvpx
}

function build_libfdkaac {
  git clone git://github.com/mstorsjo/fdk-aac.git $SRC/fdk-aac
  cd $SRC/fdk-aac
  build fdk-aac "--disable-static --disable-shared"
  add_comp libfdk-aac
  cd $SRC/ffmpeg
  patch -N -p1 -i ../../patches/0003-dynamic-loading-of-shared-fdk-aac-library.patch
}

function build_lame {
  svn co svn://svn.code.sf.net/p/lame/svn/trunk/lame@6474 $SRC/lame
  cd $SRC/lame
  build lame "--enable-nasm --disable-frontend --disable-shared --enable-static"
  add_comp libmp3lame
}

function build_zimg {
  git clone https://github.com/sekrit-twc/zimg.git $SRC/zimg
  cd $SRC/zimg
  git checkout release-2.9.2
  ./autogen.sh
  ./configure --prefix=$BUILD
  cd _msvc/zimg
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" /property:ConfigurationType=StaticLibrary /property:WindowsTargetPlatformVersion=10.0.17134.0 /property:PlatformToolset=v141 /property:Platform=x64 /property:WholeProgramOptimization=false zimg.vcxproj
  cp x64/$MSBUILD_CONFIG/z.lib $BUILD/lib/zimg.lib
  cd ../..
  cp $SRC/zimg/src/zimg/api/zimg.h  $BUILD/include/zimg.h
  cp zimg.pc $BUILD/lib/pkgconfig/zimg.pc
  add_comp libzimg
}

function build_x264 {
  git clone https://code.videolan.org/videolan/x264.git $SRC/x264
  cd $SRC/x264
  git checkout b5bc5d69c580429ff716bafcd43655e855c31b02
  #f9af2a0f71d0fca7c1cafa7657f03a302da0ca1c
  CC=cl ./configure --prefix=$BUILD --disable-cli --enable-static --enable-pic --libdir=$BUILD/lib
  make -j $NUMBER_OF_PROCESSORS
  make install-lib-static
  add_comp libx264
}

function build_opus {
  git clone https://github.com/xiph/opus.git $SRC/opus
  cd $SRC/opus/win32/VS2015
  echo \nConverting project file ...
  sed -i 's/v140/v141/g' opus.vcxproj
  echo Building project 'opus' ...
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" /property:Platform=x64 opus.vcxproj
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
  add_comp libopus
}

function build_x265 {
  git clone https://github.com/videolan/x265.git --branch stable $SRC/x265
  cd $SRC/x265/build/vc15-x86_64
  rm -rf work*
  mkdir work work10 work12
  # 12bit
  cd work12
  cmake -G "Visual Studio 15 Win64" ../../../source -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DMAIN12=ON
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ../work/x265_12bit.lib
  # 10bit
  cd ../work10
  cmake -G "Visual Studio 15 Win64" ../../../source -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ../work/x265_10bit.lib
  # 8bit - main
  cd ../work
  cmake -G "Visual Studio 15 Win64" ../../../source -DCMAKE_INSTALL_PREFIX=$BUILD -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DEXTRA_LIB="x265_10bit.lib;x265_12bit.lib" -DLINKED_10BIT=ON -DLINKED_12BIT=ON
  #-DSTATIC_LINK_CRT=ON
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ./x265_main.lib
  LIB.EXE /ignore:4006 /ignore:4221 /OUT:x265.lib x265_main.lib x265_10bit.lib x265_12bit.lib
  cp x265.lib $BUILD/lib/x265.lib
  cp x265.pc $BUILD/lib/pkgconfig/x265.pc
  cp x265_config.h $BUILD/include/
  cp ../../../source/x265.h $BUILD/include/
  add_comp libx265
}

function add_comp {
  COMPONENTS="$COMPONENTS --enable-$1"
}

rm -rf src build
mkdir src build build/include build/lib build/lib/pkgconfig

BUILD=`realpath build`
SRC=`realpath src`

#git clone -b release/4.3 git://source.ffmpeg.org/ffmpeg.git $SRC/ffmpeg
git clone git://source.ffmpeg.org/ffmpeg.git $SRC/ffmpeg

#build_nvenc
#build_amf
#build_mfx
build_svt
#build_ogg
#build_vorbis
#build_snappy
#build_libvpx
#build_libfdkaac
#build_lame
#build_zimg
#build_x264
#build_opus
#build_x265
#build_aom
#build_libass

cd $SRC/ffmpeg
PKG_CONFIG_PATH=$BUILD/lib/pkgconfig:$PKG_CONFIG_PATH ./configure --toolchain=msvc --extra-cflags="$CFLAGS -I$BUILD/include" --extra-ldflags="-LIBPATH:$BUILD/lib" --prefix=$BUILD --pkg-config-flags="--static" --disable-doc --disable-shared --enable-static --enable-runtime-cpudetect --disable-devices --disable-demuxers --disable-decoders --disable-network --enable-w32threads --enable-gpl $COMPONENTS
sed -i 's/\x81/ue/g' config.h
make -j $NUMBER_OF_PROCESSORS
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

