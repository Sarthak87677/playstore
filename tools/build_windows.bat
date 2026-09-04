@echo off
REM Build the Windows release of VEILFORGE and package the distributable ZIP.
REM Requires Godot 4.3 stable on PATH (or set GODOT) with export templates.
setlocal
if "%GODOT%"=="" set GODOT=godot
set ROOT=%~dp0..
set OUT=%ROOT%\release\VEILFORGE

echo ==^> Importing project
"%GODOT%" --headless --path "%ROOT%\project" --editor --quit >nul 2>&1

echo ==^> Running the automated playtest before packaging
"%GODOT%" --headless --path "%ROOT%\project" -- --autotest --chapters=1,2,3,4,5,6,7,8
if errorlevel 1 (
  echo error: automated playtest failed, not packaging
  exit /b 1
)

echo ==^> Exporting Windows x86-64
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
"%GODOT%" --headless --path "%ROOT%\project" --export-release "Windows Desktop" "..\release\VEILFORGE\VEILFORGE.exe"
if not exist "%OUT%\VEILFORGE.exe" (
  echo error: export produced no executable
  exit /b 1
)

copy /y "%ROOT%\README.md" "%OUT%" >nul
copy /y "%ROOT%\CONTROLS.md" "%OUT%" >nul
copy /y "%ROOT%\THIRD_PARTY_LICENSES.md" "%OUT%" >nul
copy /y "%ROOT%\KNOWN_LIMITATIONS.md" "%OUT%" >nul

echo ==^> Packaging
powershell -NoProfile -Command "Compress-Archive -Force -Path '%OUT%' -DestinationPath '%ROOT%\release\VEILFORGE-Windows-x86_64.zip'"

echo.
echo Executable : %OUT%\VEILFORGE.exe
echo Archive    : %ROOT%\release\VEILFORGE-Windows-x86_64.zip
endlocal
