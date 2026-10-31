@echo off
rem Compiles the Half-Life: Alyx health station parts and the larva vial for Garry's Mod and
rem moves them into addons\hla_health_station_content\models\hla\health_station.
rem Edit GMOD if Garry's Mod is installed elsewhere.
set "GMOD=C:\Program Files (x86)\Steam\steamapps\common\GarrysMod"
cd /d "%~dp0"
for %%M in (charger charger_internals charger_gauge charger_pad health_vial vial_hologram) do (
	pushd %%M
	"%GMOD%\bin\studiomdl.exe" -game "%GMOD%\garrysmod" -nop4 -nox360 %%M.qc
	if errorlevel 1 ( echo Compile of %%M failed. & popd & pause & exit /b 1 )
	popd
)
set "OUT=%GMOD%\garrysmod\addons\hla_health_station_content\models\hla\health_station"
if not exist "%OUT%" mkdir "%OUT%"
move /y "%GMOD%\garrysmod\models\hla\health_station\*.*" "%OUT%\" >nul
echo.
echo Done: %OUT%
pause
