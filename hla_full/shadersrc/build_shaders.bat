@echo off
rem Compiles hla_monitor_ps30.hlsl into shaders\fxc\hla_monitor_ps30.vcs for Garry's Mod.
rem Uses the toolchain of the GMod shader guide (github.com/meetric1/gmod_shader_guide):
rem   put this folder's .hlsl next to that repo's build scripts, or set SHADERCOMPILE / INCLUDES below
rem   to its ShaderCompile folder and its "include" folder (Source SDK headers: common_ps_fxc.h ...).
setlocal
set "SHADERCOMPILE=%~dp0ShaderCompile\ShaderCompile.exe"
set "INCLUDES=%~dp0include"
if not exist "%SHADERCOMPILE%" (
	echo ShaderCompile not found: %SHADERCOMPILE%
	echo Download the GMod shader guide toolchain and copy ShaderCompile\ and include\ here.
	pause & exit /b 1
)
copy /y "%INCLUDES%\*.h" "%~dp0" >nul 2>nul
"%SHADERCOMPILE%" /O 3 -ver 30 -shaderpath "%~dp0" hla_monitor_ps30.hlsl
if errorlevel 1 ( echo Compile failed & pause & exit /b 1 )
set "OUT=%~dp0..\garrysmod\addons\hla_fabricator_content\shaders\fxc"
if not exist "%OUT%" mkdir "%OUT%"
copy /y "%~dp0shaders\fxc\hla_monitor_ps30.vcs" "%OUT%\" >nul
echo Done: %OUT%\hla_monitor_ps30.vcs
pause
