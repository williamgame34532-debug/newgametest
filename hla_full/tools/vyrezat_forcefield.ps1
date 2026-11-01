# Вырезает файлы силового поля Half-Life: Alyx (модель рамки, материалы поля, звуки) прямо из pak01_*.vpk.
# Положите этот файл в папку ...\steamapps\common\Half-Life Alyx\game\hlvr\ (там, где лежат pak01_XXX.vpk)
# и запустите: правый клик -> "Выполнить с помощью PowerShell".
# Результат: hla_forcefield.zip (~35 МБ) рядом со скриптом — его и пришлите.
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
# путь, номер архива, смещение, размер
$files = @(
	@('materials/effects/combine_shield_01a.vmat_c', 178, 81559008, 6101),
	@('materials/effects/combine_shield_02a.vmat_c', 178, 81566800, 6108),
	@('materials/effects/combine_shield_bc.vmat_c', 178, 81574592, 5566),
	@('models/props_combine/combine_fence/materials/combine_doorway_fence_on.vmat_c', 316, 58977120, 8096),
	@('models/props_combine/combine_fence/materials/combine_fence_hlvr.vmat_c', 316, 75330896, 8284),
	@('models/props_combine/combine_fence/materials/combine_fence_hlvr_off.vmat_c', 316, 82197040, 8127),
	@('models/props_combine/combine_fence/combine_doorway_fence.vmdl_c', 316, 30959808, 204025),
	@('particles/combine_tech/combine_fence_interact.vpcf_c', 138, 80419232, 2295),
	@('particles/combine_tech/combine_shield_interact.vpcf_c', 138, 80503872, 2899),
	@('sounds/world/forcefields/combine_fence_shutdown_lg_station_01.vsnd_c', 419, 41558864, 57763),
	@('sounds/world/forcefields/combine_fence_shutdown_lg_zoo_01.vsnd_c', 419, 41616640, 145572),
	@('sounds/world/forcefields/combine_fence_startup_lg_lp_01.vsnd_c', 419, 41762224, 89526),
	@('sounds/world/forcefields/combine_prison_forcefield_deep_lp_01.vsnd_c', 419, 41851760, 171691),
	@('sounds/world/forcefields/combine_prison_forcefield_energy_lp_01.vsnd_c', 419, 42023456, 188071),
	@('sounds/world/forcefields/combine_prison_forcefield_ping_lp_01.vsnd_c', 419, 42211536, 177259),
	@('sounds/world/forcefields/forcefield_citizen_lp_01.vsnd_c', 419, 42514992, 233569),
	@('sounds/world/forcefields/forcefield_citizen_start_01.vsnd_c', 419, 42748576, 27360),
	@('sounds/world/forcefields/forcefield_citizen_stop_01.vsnd_c', 419, 42775936, 28716),
	@('sounds/world/forcefields/quarantine_forcefield_impact_effect_01.vsnd_c', 419, 42804656, 51287),
	@('sounds/world/forcefields/quarantine_forcefield_impact_effect_02.vsnd_c', 419, 42855952, 43678),
	@('sounds/world/forcefields/quarantine_forcefield_impact_effect_03.vsnd_c', 419, 42899632, 52123),
	@('sounds/world/forcefields/quarantine_forcefield_lp_01.vsnd_c', 419, 42951760, 273496),
	@('sounds/world/forcefields/quarantine_forcefield_start_01.vsnd_c', 419, 43225264, 25396),
	@('sounds/world/forcefields/quarantine_forcefield_stop_01.vsnd_c', 419, 43250672, 25710),
	@('materials/effects/combine_shield_01a_vmat_g_tcolor_f1061c36.vtex_c', 178, 81565120, 1668),
	@('materials/effects/combine_shield_02a_vmat_g_tcolor_f1061c36.vtex_c', 178, 81572912, 1668),
	@('materials/effects/combine_shield_bc_vmat_g_tcolor_a7ef3d46.vtex_c', 178, 81580160, 1908),
	@('materials/effects/combine_shield_mask_01_psd_ab6ca380.vtex_c', 178, 81589904, 6487987),
	@('materials/effects/combine_shield_mask_01b_psd_e27e8d65.vtex_c', 178, 88077904, 4187774),
	@('materials/effects/combine_shield_wave2_psd_70e27c9a.vtex_c', 178, 92265680, 3948),
	@('materials/effects/combine_shield_wave_psd_e8dc961a.vtex_c', 178, 92269632, 2415),
	@('materials/effects/combine_shield_wave_psd_fece5a78.vtex_c', 178, 92272048, 3948),
	@('models/props_combine/combine_fence/materials/combine_doorway_fence_color_tga_bcdb4b85.vtex_c', 316, 36183664, 20038403),
	@('models/props_combine/combine_fence/materials/combine_doorway_fence_lit_tga_ec057ec8.vtex_c', 316, 56222080, 2755039),
	@('models/props_combine/combine_fence/materials/combine_fence_hlvr_color_tga_1c59db1.vtex_c', 316, 77492400, 3831601),
	@('models/props_combine/combine_fence/materials/combine_fence_hlvr_lit_off_tga_fcda61cb.vtex_c', 316, 81324016, 110376),
	@('models/props_combine/combine_fence/materials/combine_fence_hlvr_lit_on_tga_21209b7e.vtex_c', 316, 81434400, 762637)
)
$out = Join-Path $PSScriptRoot 'hla_forcefield'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$ok = 0
foreach ($f in $files) {
	$pak = Join-Path $PSScriptRoot ('pak01_{0:D3}.vpk' -f $f[1])
	if (-not (Test-Path -LiteralPath $pak)) { Write-Host ('НЕТ ' + $pak); continue }
	$src = [System.IO.File]::OpenRead($pak)
	try {
		$buf = New-Object byte[] $f[3]
		[void]$src.Seek([int64]$f[2], 'Begin')
		$read = 0
		while ($read -lt $f[3]) { $n = $src.Read($buf, $read, $f[3] - $read); if ($n -le 0) { throw ('Файл короче ожидаемого: ' + $f[0]) }; $read += $n }
	} finally { $src.Close() }
	$dst = Join-Path $out ($f[0] -replace '/', '\')
	New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
	[System.IO.File]::WriteAllBytes($dst, $buf)
	$ok++
	Write-Host ('OK  ' + $f[0])
}
$zip = Join-Path $PSScriptRoot 'hla_forcefield.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip
Write-Host ''
Write-Host ("Готово: $zip  (файлов: $ok из " + $files.Count + ')')
Read-Host 'Нажмите Enter'
