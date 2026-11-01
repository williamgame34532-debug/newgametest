@echo off
rem Compiles the two Half-Life: Alyx force field emitters (combine_fence01a/01b_128) for Garry's Mod
rem and copies them into the content addon. Edit GMOD if Garry's Mod is installed elsewhere.
set "GMOD=D:\SteamLibrary\steamapps\common\GarrysMod"
if not exist "%GMOD%\bin\studiomdl.exe" set "GMOD=C:\Program Files (x86)\Steam\steamapps\common\GarrysMod"
cd /d "%~dp0"
set "OUT=%GMOD%\garrysmod\addons\hla_forcefield_content\models\hla\forcefield"
set "BUILT=%GMOD%\garrysmod\models\hla\forcefield"
for %%Q in (fence_l fence_r) do (
	if not exist "%%Q.smd" (
		echo.
		echo No %%Q.smd next to this file: put fence_l.smd and fence_r.smd here.
		pause
		exit /b 1
	)
	if exist "%BUILT%\%%Q.mdl" del /q "%BUILT%\%%Q.*"
	"%GMOD%\bin\studiomdl.exe" -game "%GMOD%\garrysmod" -nop4 -nox360 %%Q.qc
	if not exist "%BUILT%\%%Q.mdl" (
		echo.
		echo Compile failed: %%Q - see the messages above.
		pause
		exit /b 1
	)
)
if not exist "%OUT%" mkdir "%OUT%"
move /y "%BUILT%\fence_*.*" "%OUT%\" >nul
echo.
echo Done: %OUT%
dir /b "%OUT%"
pause
