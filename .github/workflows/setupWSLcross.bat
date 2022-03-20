@echo off
rem Setup MCL and echo the environment
rem Usage: cmd.exe /c c:/tools/SetupWSLcross.bat $ARCH | dos2unix > /tmp/WSLcross.sh && source /tmp/WSLcross.sh
rem   or add to .bashrc
rem function setupWSL()
rem {
rem    echo setupWSL $1
rem    cmd.exe /c c:/tools/SetupWSLcross.bat $1 | dos2unix > /tmp/WSLcross.sh && source /tmp/WSLcross.sh
rem }
rem 

call "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\vcvarsall.bat" %~1

rem FOR /F "delims==" %%G IN ('SET') DO @Echo %%G

FOR /F "delims==" %%G IN ('where cl.exe') DO SET _cl_path=%%G

echo CL_EXEC="%_cl_path%"
echo WSL_CL_EXEC=`wslpath -u "$CL_EXEC"`
echo WSL_CL_PATH=`dirname "$WSL_CL_EXEC"`
echo export PATH=$PATH:$WSL_CL_PATH
echo export DevEnvDir="%DevEnvDir% "
rem ExtensionSdkDir
rem FSHARPINSTALLDIR
rem Framework40Version
rem FrameworkDIR32
rem FrameworkDir
rem FrameworkVersion
rem FrameworkVersion32
echo export INCLUDE="%INCLUDE% "
echo export LIB="%LIB% "
echo export LIBPATH="%LIBPATH% "
echo export VCINSTALLDIR="%VCINSTALLDIR% "
echo export VSINSTALLDIR="%VSINSTALLDIR% "
echo export VisualStudioVersion="%VisualStudioVersion% "
rem echo export WindowsSDK_ExecutablePath_x64=%WindowsSDK_ExecutablePath_x64%
rem echo export WindowsSDK_ExecutablePath_x86=%WindowsSDK_ExecutablePath_x86%
rem echo export WindowsSdkDir=%WindowsSdkDir%
echo export WSLcross=true
echo export WSLENV=$WSLENV:INCLUDE/w:LIB/w:LIBPATH/w
