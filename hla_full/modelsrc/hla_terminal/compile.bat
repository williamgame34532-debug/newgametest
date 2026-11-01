@echo off
rem Compiles the HL:A Combine terminal models (monitors large / medium / small, console) for Garry's Mod
rem and copies them into the content addon. Edit GMOD if Garry's Mod is installed elsewhere.
set "GMOD=D:\SteamLibrary\steamapps\common\GarrysMod"
if not exist "%GMOD%\bin\studiomdl.exe" set "GMOD=C:\Program Files (x86)\Steam\steamapps\common\GarrysMod"
cd /d "%~dp0"
set "BUILT=%GMOD%\garrysmod\models\hla\terminal"
set "OUT=%GMOD%\garrysmod\addons\hla_terminal_content\models\hla\terminal"
for %%Q in (combine_monitor_large combine_monitor_medium combine_monitor_small vr_combine_interface_01) do (
	pushd %%Q
	"%GMOD%\bin\studiomdl.exe" -game "%GMOD%\garrysmod" -nop4 -nox360 %%Q.qc
	popd
	if not exist "%BUILT%\%%Q.mdl" (
		echo.
		echo Compile failed: %%Q - see the messages above.
		pause
		exit /b 1
	)
)
if not exist "%OUT%" mkdir "%OUT%"
move /y "%BUILT%\*.*" "%OUT%\" >nul
echo.
echo Done: %OUT%
dir /b "%OUT%"
pause
