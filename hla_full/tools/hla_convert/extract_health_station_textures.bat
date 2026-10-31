@echo off
chcp 65001 >nul
rem Pulls ONLY the health station textures out of Half-Life: Alyx (a few MB, not whole archives).
rem Run it from tools\hla_convert (next to vpk.py). Needs Python 3 (python.org, tick "Add to PATH").
rem The result is the folder hs_textures next to this file: zip it and send it.
set "HLA="
for %%G in ("C:\Program Files (x86)\Steam\steamapps\common\Half-Life Alyx\game\hlvr" "D:\SteamLibrary\steamapps\common\Half-Life Alyx\game\hlvr" "E:\SteamLibrary\steamapps\common\Half-Life Alyx\game\hlvr" "D:\Steam\steamapps\common\Half-Life Alyx\game\hlvr" "F:\SteamLibrary\steamapps\common\Half-Life Alyx\game\hlvr") do (
	if not defined HLA if exist "%%~G\pak01_dir.vpk" set "HLA=%%~G"
)
if not defined HLA ( echo Half-Life: Alyx not found: write the game\hlvr folder into HLA at the top of this file. & pause & exit /b 1 )
echo Half-Life: Alyx: %HLA%
set "OUT=%~dp0hs_textures"
cd /d "%~dp0"
python vpk.py "%HLA%\pak01_dir.vpk" extract "materials/models/props_combine/combine_health_charge*.vmat_c" "%OUT%" --deps
python vpk.py "%HLA%\pak01_dir.vpk" extract "materials/models/props_combine/health_charger_insides.vmat_c" "%OUT%" --deps
python vpk.py "%HLA%\pak01_dir.vpk" extract "models/creatures/antlion_larva/material/*.vmat_c" "%OUT%" --deps
python vpk.py "%HLA%\pak01_dir.vpk" extract "materials/models/props_combine/combine_health_charger01_*" "%OUT%"
echo.
echo Done: zip the folder %OUT% and send it.
explorer "%~dp0"
pause
