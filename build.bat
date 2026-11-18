@echo off
rem LIB_SFX build. Close LiveCode first. Double-click it, or run it from any command prompt.
rem Copies the sources to a Windows work folder, compiles xtsfx.dll there, compiles xtsfx.lcb
rem to module.lcm, and places both in <work>\extension. Nothing else is needed: the script
rem library (livecode\lib_sfx.livecodescript) loads the extension from there by itself.
rem
rem   XTSFX_SRC      folder holding xtsfx.lcb and c\xtsfx.c, c\rfxgen.h
rem                  (default: this file's folder if they are there, else the WSL project folder)
rem   XTSFX_WORK     work folder             (default C:\xtsfx)
rem   XTSFX_LIVECODE LiveCode's folder       (default C:\Program Files\RunRev\LiveCode Community 9.6.3)
rem   XTSFX_NOPAUSE  set to 1 to skip the closing pause (for scripted builds)
setlocal
if "%XTSFX_WORK%"=="" set "XTSFX_WORK=C:\xtsfx"
if "%XTSFX_LIVECODE%"=="" set "XTSFX_LIVECODE=C:\Program Files\RunRev\LiveCode Community 9.6.3"
if "%XTSFX_SRC%"=="" (
  if exist "%~dp0c\xtsfx.c" (set "XTSFX_SRC=%~dp0") else set "XTSFX_SRC=\\wsl$\Ubuntu\home\igame3d\projects\LIB_SFX\"
)
if not "%XTSFX_SRC:~-1%"=="\" set "XTSFX_SRC=%XTSFX_SRC%\"

rem --- compiler: use cl if already set up, otherwise find Visual Studio and set it up
where cl >nul 2>nul
if not errorlevel 1 goto :havecl
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSDIR="
if exist "%VSWHERE%" for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%i"
if "%VSDIR%"=="" (
  echo ERROR: Visual Studio with "Desktop development with C++" was not found.
  goto :fail
)
echo === Setting up the Visual Studio x64 compiler
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul
where cl >nul 2>nul
if errorlevel 1 (
  echo ERROR: vcvars64.bat ran but cl is still not available.
  goto :fail
)
:havecl

set "LCC=%XTSFX_LIVECODE%\Toolchain\lc-compile.exe"
if not exist "%LCC%" (
  echo ERROR: "%LCC%" not found. Set XTSFX_LIVECODE to LiveCode's folder.
  goto :fail
)

if not exist "%XTSFX_WORK%\extension\code\x86_64-win32" mkdir "%XTSFX_WORK%\extension\code\x86_64-win32"
echo === Copying sources from %XTSFX_SRC%
for %%f in (c\xtsfx.c c\rfxgen.h xtsfx.lcb) do (
  copy /Y "%XTSFX_SRC%%%f" "%XTSFX_WORK%\%%~nxf" >nul
  if errorlevel 1 (
    echo ERROR: could not copy %%f from "%XTSFX_SRC%". Set XTSFX_SRC to the folder that holds it.
    goto :fail
  )
)

cd /d "%XTSFX_WORK%"
echo === Compiling xtsfx.dll
cl /nologo /O2 /MD /LD /TC xtsfx.c /Fe:xtsfx.dll
if errorlevel 1 (
  echo.
  echo ERROR: compile failed. Nothing was installed.
  goto :fail
)
dumpbin /exports xtsfx.dll | findstr /c:"xtsfx_Version" >nul
if errorlevel 1 (
  echo ERROR: xtsfx.dll was built but does not export xtsfx_Version.
  goto :fail
)

echo === Compiling xtsfx.lcb
"%LCC%" --modulepath "%XTSFX_WORK%\extension" --modulepath "%XTSFX_LIVECODE%\Toolchain\modules\lci" --manifest "%XTSFX_WORK%\extension\manifest.xml" --output "%XTSFX_WORK%\extension\module.lcm" xtsfx.lcb
if errorlevel 1 (
  echo.
  echo ERROR: xtsfx.lcb did not compile. Nothing was installed.
  goto :fail
)

echo === Installing into %XTSFX_WORK%\extension
copy /Y xtsfx.lcb "extension\xtsfx.lcb" >nul
copy /Y xtsfx.dll "extension\code\x86_64-win32\xtsfx.dll" >nul
if errorlevel 1 (
  echo ERROR: could not copy xtsfx.dll. Is LiveCode still running?
  goto :fail
)
for /f %%n in ('dumpbin /exports "extension\code\x86_64-win32\xtsfx.dll" ^| findstr /c:"xtsfx_" ^| find /c /v ""') do set COUNT=%%n
echo.
echo OK: %XTSFX_WORK%\extension holds module.lcm and xtsfx.dll (%COUNT% xtsfx functions).
echo Next: open demos\sfx_demo.livecodescript in LiveCode (File - Open Stack). It loads the extension itself.
if not "%XTSFX_NOPAUSE%"=="1" pause
endlocal
exit /b 0

:fail
echo.
echo Build stopped. Nothing after the error above was done.
if not "%XTSFX_NOPAUSE%"=="1" pause
endlocal
exit /b 1
