@echo off
rem Compiles the Half-Life: Alyx fabricator for Garry's Mod and copies it into the content addon.
rem Edit GMOD if Garry's Mod is installed elsewhere.
set "GMOD=C:\Program Files (x86)\Steam\steamapps\common\GarrysMod"
cd /d "%~dp0"
"%GMOD%\bin\studiomdl.exe" -game "%GMOD%\garrysmod" -nop4 -nox360 hla_station.qc
if errorlevel 1 (
	echo.
	echo Compile failed. Check the GMOD path at the top of this file.
	pause
	exit /b 1
)
set "OUT=%GMOD%\garrysmod\addons\hla_fabricator_content\models\cf_rework"
if not exist "%OUT%" mkdir "%OUT%"
move /y "%GMOD%\garrysmod\models\cf_rework\hla_station.*" "%OUT%\" >nul
echo.
echo Done: %OUT%\hla_station.mdl
pause
