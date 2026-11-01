@echo off
chcp 65001 >nul
rem Pulls the Combine symbol and the heart icon of the HL:A interface (two small files) for the visor.
rem Run it from tools\hla_convert (next to vpk.py). Needs Python 3. Result: the folder hla_icons next to this file —
rem zip it and send it.
set "HLA="
for %%G in ("C:\Program Files (x86)\Steam\steamapps\common\Half-Life Alyx\game\hlvr" "D:\SteamLibrary\steamapps\common\Half-Life Alyx\game\hlvr" "E:\SteamLibrary\steamapps\common\Half-Life Alyx\game\hlvr" "D:\Steam\steamapps\common\Half-Life Alyx\game\hlvr" "F:\SteamLibrary\steamapps\common\Half-Life Alyx\game\hlvr") do (
	if not defined HLA if exist "%%~G\pak01_dir.vpk" set "HLA=%%~G"
)
if not defined HLA ( echo Half-Life: Alyx not found: write the game\hlvr folder into HLA at the top of this file. & pause & exit /b 1 )
set "OUT=%~dp0hla_icons"
cd /d "%~dp0"
python vpk.py "%HLA%\pak01_dir.vpk" extract "panorama/images/upgrade_station_ui/combine_logo_psd.vtex_c" "%OUT%"
python vpk.py "%HLA%\pak01_dir.vpk" extract "panorama/images/hud/hud_icon_health_heart_sheet_png.vtex_c" "%OUT%"
echo.
echo Done: zip the folder %OUT% and send it.
explorer "%~dp0"
pause
