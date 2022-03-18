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
  cd $repos/$1
  #if [ -f autogen.sh ]; then
  #  ./autogen.sh
  #fi
  autoreconf -i
  CC=cl CXX=cl CXXFLAGS=$CFLAGS ./configure --prefix=$BUILD $2
  make -j $NUMBER_OF_PROCESSORS
  make install
}

function build_nvenc {
  echo "################################################################################"
  echo "## NVENC                                                                      ##"
  echo "################################################################################"
  cd $repos/ffnvcodec
  make PREFIX=$BUILD install
  add_comp nvenc
}

function build_amf {
  echo "################################################################################"
  echo "## AMF                                                                        ##"
  echo "################################################################################"
  cp -a $repos/amf/amf/public/include $BUILD/include/AMF
  add_comp amf
}

function build_mfx {
  echo "################################################################################"
  echo "## LIBMFX                                                                     ##"
  echo "################################################################################"
  cp -r "C:\Program Files (x86)\IntelSWTools\Intel(R) Media SDK 2021 R1\Software Development Kit\include" $BUILD/include/mfx
  cp "C:\Program Files (x86)\IntelSWTools\Intel(R) Media SDK 2021 R1\Software Development Kit\lib\x64\libmfx_vs2015.lib" $BUILD/lib/libmfx.lib
  printf "prefix=$BUILD\nexec_prefix=\${prefix}\nincludedir=\${prefix}/include\nlibdir=\${exec_prefix}/lib\nName: libmfx\nDescription: Intel Media SDK Dispatched static library\nVersion: 1.34\nLibs: -L\${libdir} -llibmfx -ladvapi32 -lole32 -luuid\nCflags: -I\${includedir}\n" > $BUILD/lib/pkgconfig/libmfx.pc
  
  #git clone -q https://github.com/lu-zero/mfx_dispatch.git $SRC/libmfx
  #cd $SRC/libmfx
  #if [[ ! -f "configure" ]]; then
  #    autoreconf -fiv || exit 1
  #fi
  #build libmfx
  #sed -i 's/-lstdc++/-ladvapi32/g' $BUILD/lib/pkgconfig/libmfx.pc
  add_comp libmfx
}

function build_svt {
  echo "################################################################################"
  echo "## LIBSVTAV1                                                                  ##"
  echo "################################################################################"
  # HEVC
  #git clone -q https://github.com/OpenVisualCloud/SVT-HEVC.git $SRC/svt-hevc
  #cd $SRC/svt-hevc/Build/windows
  #cmake .. -G"Visual Studio 15 2017" -A x64 -DCMAKE_INSTALL_PREFIX=$BUILD -DCMAKE_CONFIGURATION_TYPES=$MSBUILD_CONFIG
  #MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration=$MSBUILD_CONFIG /property:ConfigurationType=StaticLibrary /property:TargetExt=.lib svt-hevc.sln  
  #cp -r ../Source/API $BUILD/include/svt-hevc ; cp ../Bin/$MSBUILD_CONFIG/SvtHevcEnc.lib $BUILD/lib/ ; cp SvtHevcEnc.pc $BUILD/lib/pkgconfig/
  #add_comp libsvthevc
  #
  # AV1
  #git clone -q --depth 1  https://github.com/AOMediaCodec/SVT-AV1 $SRC/svt-av1
  cd $repos/svt-av1/Build/windows
  ./build.bat 2017 $MODE static
  cp -r ../../Source/API $BUILD/include/svt-av1 ; cp ../../Bin/$MSBUILD_CONFIG/SvtAv1Enc.lib $BUILD/lib/ ; cp SvtAv1Enc.pc $BUILD/lib/pkgconfig/
  add_comp libsvtav1
  cd ../../../..
  #
  # VP9
  #git clone -q https://github.com/OpenVisualCloud/SVT-VP9.git $SRC/svt-vp9
  #cd $SRC/svt-vp9/Build/windows
  #cmake .. -G"Visual Studio 15 2017" -A x64 -DCMAKE_INSTALL_PREFIX=$BUILD -DCMAKE_CONFIGURATION_TYPES=$MSBUILD_CONFIG
  #MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration=$MSBUILD_CONFIG /property:ConfigurationType=StaticLibrary /property:TargetExt=".lib" svt-vp9.sln
  #cp -r ../Source/API $BUILD/include/svt-vp9 ; cp ../Bin/$MSBUILD_CONFIG/SvtVp9Enc.lib $BUILD/lib/ ; cp SvtVp9Enc.pc $BUILD/lib/pkgconfig/
  #sed -i 's/ -lpthread//g' $BUILD/lib/pkgconfig/SvtVp9Enc.pc
  #sed -i 's/ -lm//g' $BUILD/lib/pkgconfig/SvtVp9Enc.pc
  #add_comp libsvtvp9
}

function build_ogg {
  echo "################################################################################"
  echo "## LIBOGG                                                                     ##"
  echo "################################################################################"
  cd $repos/libogg
  build libogg "--disable-shared"
}

function build_vorbis {
  echo "################################################################################"
  echo "## LIBVORBIS                                                                  ##"
  echo "################################################################################"
  cd $repos/libvorbis
  build libvorbis "--disable-shared"  
  sed -i '/^Libs\.private.*/d' $BUILD/lib/pkgconfig/vorbis.pc  # don't need m.lib on windows
  add_comp libvorbis
}

function build_snappy {
  echo "################################################################################"
  echo "## LIBSNAPPY                                                                  ##"
  echo "################################################################################"
  #git clone -q -b 1.1.8 https://github.com/google/snappy.git $SRC/snappy
  cd $repos/snappy
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
  echo "################################################################################"
  echo "## LIBVPX                                                                     ##"
  echo "################################################################################"
  cd $repos/libvpx
  ./configure --prefix=$BUILD --target=x86_64-win64-vs15 --enable-vp9-highbitdepth --disable-shared --disable-examples --disable-tools --disable-docs --disable-libyuv --disable-unit_tests --disable-postproc
  make -j $NUMBER_OF_PROCESSORS
  make install
  mv $BUILD/lib/x64/vpxmd.lib $BUILD/lib/vpx.lib
  rm -rf $BUILD/lib/x64
  add_comp libvpx
}

function build_libfdkaac {
  echo "################################################################################"
  echo "## LIBFDK_AAC                                                                 ##"
  echo "################################################################################"
  cd $repos/fdk-aac
  build fdk-aac "--disable-static --disable-shared"
  add_comp libfdk-aac
  cd $repos/ffmpeg
  patch -N -p1 -i ../../patches/0003-dynamic-loading-of-shared-fdk-aac-library-5.0.patch
}

function build_lame {
  echo "################################################################################"
  echo "## LIBLAME                                                                    ##"
  echo "################################################################################"
  svn co svn://svn.code.sf.net/p/lame/svn/trunk/lame@6474 $repos/lame
  cd $repos/lame
  build lame "--enable-nasm --disable-frontend --disable-shared --enable-static"
  add_comp libmp3lame
}

function build_zimg {
  echo "################################################################################"
  echo "## ZIMG                                                                       ##"
  echo "################################################################################"
  cd $repos/zimg
  ./autogen.sh
  ./configure --prefix=$BUILD
  cd _msvc/zimg
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" /property:ConfigurationType=StaticLibrary /property:WindowsTargetPlatformVersion=10.0.17134.0 /property:PlatformToolset=v141 /property:Platform=x64 /property:WholeProgramOptimization=false zimg.vcxproj
  cp x64/$MSBUILD_CONFIG/z.lib $BUILD/lib/zimg.lib
  cd ../..
  cp $repos/zimg/src/zimg/api/zimg.h  $BUILD/include/zimg.h
  cp zimg.pc $BUILD/lib/pkgconfig/zimg.pc
  add_comp libzimg
}

function build_x264 {
  echo "################################################################################"
  echo "## LIBX264                                                                    ##"
  echo "################################################################################"
  cd $repos/x264
  sed -i 's/#define X264_API_IMPORTS 1/\/\/#define X264_API_IMPORTS 1/g' ../ffmpeg/libavcodec/libx264.c
  #git checkout b5bc5d69c580429ff716bafcd43655e855c31b02
  #f9af2a0f71d0fca7c1cafa7657f03a302da0ca1c
  CC=cl ./configure --prefix=$BUILD --disable-cli --enable-static --enable-pic --libdir=$BUILD/lib
  make -j $NUMBER_OF_PROCESSORS
  make install-lib-static
  add_comp libx264
}

function build_opus {
  echo "################################################################################"
  echo "## LIBOPUS                                                                    ##"
  echo "################################################################################"
  cd $repos/opus/win32/VS2015
  echo \nConverting project file ...
  sed -i 's/v140/v141/g' opus.vcxproj
  echo Building project 'opus' ...
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" /property:Platform=x64 opus.vcxproj
  echo Done.
  cp x64/$MSBUILD_CONFIG/opus.lib $BUILD/lib/opus.lib
  cp -r $repos/opus/include $BUILD/include/opus
  cp $repos/opus/opus.pc.in $BUILD/lib/pkgconfig/opus.pc
  sed -i "s#@prefix@#$BUILD#g" $BUILD/lib/pkgconfig/opus.pc
  sed -i "s/@exec_prefix@/\$\{prefix\}/g" $BUILD/lib/pkgconfig/opus.pc
  sed -i "s/@libdir@/\$\{prefix\}\/lib/g" $BUILD/lib/pkgconfig/opus.pc
  sed -i "s/@includedir@/\$\{prefix\}\/include/g" $BUILD/lib/pkgconfig/opus.pc
  sed -i "s/@LIBM@//g" $BUILD/lib/pkgconfig/opus.pc
  sed -i "s/@VERSION@/2.0.0/g" $BUILD/lib/pkgconfig/opus.pc
  add_comp libopus
}

function build_x265 {
  echo "################################################################################"
  echo "## LIBX265                                                                    ##"
  echo "################################################################################"
  cd $repos/x265/build/vc15-x86_64
  rm -rf work*
  mkdir work work10 work12
  # 12bit
  cd work12
  echo "## 12 BIT"
  cmake -G "Visual Studio 15 Win64" ../../../source -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DMAIN12=ON
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ../work/x265_12bit.lib
  # 10bit
  echo "## 10 BIT"
  cd ../work10
  cmake -G "Visual Studio 15 Win64" ../../../source -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF -DENABLE_CLI=OFF
  MSBuild.exe /maxcpucount:$NUMBER_OF_PROCESSORS /property:Configuration="$MSBUILD_CONFIG" x265-static.vcxproj
  cp $MSBUILD_CONFIG/x265-static.lib ../work/x265_10bit.lib
  # 8bit - main
  echo "## 8 BIT"
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

export -f build_nvenc && export -f build_amf && export -f build_mfx && export -f build_svt && export -f build_ogg && export -f build_vorbis && export -f build_snappy && export -f build_libvpx && export -f build_libfdkaac && export -f build_lame && export -f build_zimg && export -f build_x264 && export -f build_x265

function add_comp {
  COMPONENTS="$COMPONENTS --enable-$1"
}

rm -rf src build
mkdir src build build/include build/lib build/lib/pkgconfig

BUILD=`realpath build`
SRC=`realpath src`
repos=$(realpath repos)

parallel -j3 ::: build_nvenc build_amf build_svt build_ogg

#build_nvenc
#build_amf
#build_mfx
#build_svt
#build_ogg
#build_opus
#build_vorbis
#build_snappy
#build_libvpx
#build_libfdkaac
#build_lame
#build_zimg
#build_x264
#build_x265

echo "################################################################################"
echo "## FFMPEG                                                                     ##"
echo "################################################################################"
cd $repos/ffmpeg
PKG_CONFIG_PATH=$BUILD/lib/pkgconfig:$PKG_CONFIG_PATH ./configure --toolchain=msvc --extra-cflags="$CFLAGS -I$BUILD/include" --extra-ldflags="-LIBPATH:$BUILD/lib" --prefix=$BUILD --pkg-config-flags="--static" --disable-doc --disable-shared --enable-static --enable-runtime-cpudetect --disable-devices --disable-demuxers --disable-decoders --disable-network --enable-w32threads --enable-gpl $COMPONENTS
sed -i 's/\x81/ue/g' config.h
make -j $NUMBER_OF_PROCESSORS
make install
cd -

# rename *.a to *.lib
cd $BUILD/lib
for file in *.a; do
  mv "$file" "`basename "$file" .a`.lib"
done

# clean up
rm -rf $BUILD/lib/fdk-aac.lib $BUILD/lib/*.la
  
# Create archives
cd - ; cd $BUILD
mkdir ../dist 2>/dev/null
tar czf ../dist/ffmpeg-win64-static-$MODE.tar.gz *
cd - ; cd repos/ffmpeg
tar czf ../../dist/ffmpeg-win64-static-src-$MODE.tar.gz *

