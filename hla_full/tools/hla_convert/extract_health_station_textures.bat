@echo off
rem Pulls ONLY the health station textures out of Half-Life: Alyx (a few MB, not whole archives).
rem Put this file next to vpk.py; set HLA to your game\hlvr folder if it differs.
chcp 65001 >nul
if "%HLA%"=="" set HLA=C:\Program Files (x86)\Steam\steamapps\common\Half-Life Alyx\game\hlvr
set OUT=%~dp0hs_textures
python "%~dp0vpk.py" "%HLA%\pak01_dir.vpk" extract "materials/models/props_combine/combine_health_charge*.vmat_c" "%OUT%" --deps
python "%~dp0vpk.py" "%HLA%\pak01_dir.vpk" extract "materials/models/props_combine/health_charger_insides.vmat_c" "%OUT%" --deps
python "%~dp0vpk.py" "%HLA%\pak01_dir.vpk" extract "models/creatures/antlion_larva/material/*.vmat_c" "%OUT%" --deps
python "%~dp0vpk.py" "%HLA%\pak01_dir.vpk" extract "materials/models/props_combine/combine_health_charger01_*" "%OUT%"
echo.
echo Done: zip the hs_textures folder and send it.
pause
