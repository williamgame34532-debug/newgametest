@echo off
chcp 65001 >nul
rem Compiles the Half-Life: Alyx health station parts and the larva vial for Garry's Mod and
rem puts them into garrysmod\addons\hla_health_station_content\models\hla\health_station.
rem This folder must hold the subfolders charger, charger_gauge, ... each with its .qc, ref_00.smd, phys.smd and anims\.
set "GMOD="
rem Finds Garry's Mod in the usual Steam libraries. If it is elsewhere, put its folder here instead: set "GMOD=X:\...\GarrysMod"
for %%G in ("C:\Program Files (x86)\Steam\steamapps\common\GarrysMod" "D:\SteamLibrary\steamapps\common\GarrysMod" "E:\SteamLibrary\steamapps\common\GarrysMod" "D:\Steam\steamapps\common\GarrysMod" "F:\SteamLibrary\steamapps\common\GarrysMod") do (
	if not defined GMOD if exist "%%~G\bin\studiomdl.exe" set "GMOD=%%~G"
)
if not defined GMOD ( echo Garry's Mod not found: write its folder into GMOD at the top of this file. & pause & exit /b 1 )
echo Garry's Mod: %GMOD%
cd /d "%~dp0"
for %%M in (charger charger_internals charger_gauge charger_pad health_vial vial_hologram) do (
	if not exist "%%M\ref_00.smd" ( echo %%M\ref_00.smd is missing: unpack the full modelsrc\health_station archive here. & pause & exit /b 1 )
)
set FAIL=
for %%M in (charger charger_internals charger_gauge charger_pad health_vial vial_hologram) do (
	pushd %%M
	"%GMOD%\bin\studiomdl.exe" -game "%GMOD%\garrysmod" -nop4 -nox360 %%M.qc > "..\%%M_log.txt" 2>&1
	findstr /c:"ERROR" "..\%%M_log.txt" >nul && ( echo FAILED: %%M ^(see %%M_log.txt^) & set FAIL=1 ) || echo ok: %%M
	popd
)
set "OUT=%GMOD%\garrysmod\addons\hla_health_station_content\models\hla\health_station"
if not exist "%OUT%" mkdir "%OUT%"
if exist "%GMOD%\garrysmod\models\hla\health_station\*.mdl" move /y "%GMOD%\garrysmod\models\hla\health_station\*" "%OUT%" >nul
echo.
if defined FAIL ( echo Some models failed, send me the *_log.txt files. ) else ( echo Done: %OUT% )
pause
