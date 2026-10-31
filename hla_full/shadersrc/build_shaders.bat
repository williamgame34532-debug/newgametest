@echo off
rem The compiled shader is already included: garrysmod\addons\hla_fabricator_content\shaders\fxc\hla_monitor_ps30.vcs
rem It was built on Linux: Wine's d3dcompiler_47 (vkd3d-shader) -> ps_3_0 bytecode (hlslc.c),
rem then wrapped into the Source .vcs format by pack_vcs.py:
rem   x86_64-w64-mingw32-gcc -O2 -o hlslc.exe hlslc.c -ld3dcompiler_47
rem   wine hlslc.exe hla_monitor_ps30.hlsl main ps_3_0 hla_monitor_ps30.bin
rem   python pack_vcs.py hla_monitor_ps30.bin hla_monitor_ps30.hlsl hla_monitor_ps30.vcs
rem On Windows the same works with the system d3dcompiler_47.dll:
setlocal
cd /d "%~dp0"
if not exist hlslc.exe ( echo Build hlslc.exe from hlslc.c first ^(any mingw/MSVC^). & pause & exit /b 1 )
copy /y hla_monitor_ps30.hlsl _src.hlsl >nul
hlslc.exe _src.hlsl main ps_3_0 hla_monitor_ps30.bin || ( pause & exit /b 1 )
python pack_vcs.py hla_monitor_ps30.bin hla_monitor_ps30.hlsl ..\garrysmod\addons\hla_fabricator_content\shaders\fxc\hla_monitor_ps30.vcs
del _src.hlsl
pause
