# voukoder-ffmpeg-buildscript

Builds static libraries of ffmeg and external libraries (x264 8bit, x265 8,10 and 12bit) to be used in the voukoder project.

## Install msys2
- Get the 64bit version of msys2 from msys2.org
- Install it

## Start msys2
- Open a command prompt
- Run "vcvarsall.bat amd64" in "c:\program files (x86)\microsoft visual studio\2017\community\VC\Auxiliary\Build"
- Run msys2 with "msys2_shell.cmd -mingw64 -full-path"

## Install development tools
- Install CMakeGui in Windows to have the VisualStudio templates ready
- Install "pacman -S base-devel binutils git make pkg-config subversion zip" in msys2
- Install nasm to /usr/bin/nasm.exe
- Install cmake gui
- Add cmake path to path variable

## Starting the build
- Have the build.sh file at i.e. "/home/daniel/ffmpeg/build.sh"
- Start the build by either "./build.sh debug" or "./build.sh release"
