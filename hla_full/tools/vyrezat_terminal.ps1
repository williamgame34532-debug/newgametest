# Вырезает из Half-Life: Alyx модели терминала Альянса ВМЕСТЕ со всеми их материалами и текстурами
# (скрипт сам находит, какие материалы нужны модели и какие текстуры нужны материалам).
# Положите файл в ...\steamapps\common\Half-Life Alyx\game\hlvr\ (там, где pak01_dir.vpk) и запустите:
# правый клик -> "Выполнить с помощью PowerShell".
# Результат рядом: hla_terminal.zip — его и пришлите.
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$dirPath = Join-Path $PSScriptRoot 'pak01_dir.vpk'
if (-not (Test-Path -LiteralPath $dirPath)) { Write-Host "Нет pak01_dir.vpk рядом со скриптом: $PSScriptRoot"; Read-Host 'Enter'; exit 1 }

# ---------- список файлов VPK
Write-Host 'Читаю список файлов...'
$dir = [System.IO.File]::ReadAllBytes($dirPath)
$treeSize = [BitConverter]::ToUInt32($dir, 8)
$hdr = 28
$entries = @{}
$p = $hdr
$end = $hdr + $treeSize
function ReadStr { $s = $script:p; $z = [Array]::IndexOf($script:dir, [byte]0, $s); $r = [Text.Encoding]::UTF8.GetString($script:dir, $s, $z - $s); $script:p = $z + 1; return $r }
while ($p -lt $end) {
	$ext = ReadStr; if ($ext -eq '') { break }
	while ($true) {
		$path = ReadStr; if ($path -eq '') { break }
		while ($true) {
			$name = ReadStr; if ($name -eq '') { break }
			$pre = [BitConverter]::ToUInt16($dir, $p + 4); $arc = [BitConverter]::ToUInt16($dir, $p + 6)
			$off = [BitConverter]::ToUInt32($dir, $p + 8); $len = [BitConverter]::ToUInt32($dir, $p + 12)
			$preStart = $p + 18
			$full = $(if ($path -eq ' ') { "$name.$ext" } else { "$path/$name.$ext" })
			$entries[$full] = @($arc, $off, $len, $preStart, $pre)
			$p = $p + 18 + $pre
		}
	}
}
Write-Host ('Файлов в игре: ' + $entries.Count)

$streams = @{}
function ReadEntry($e) {
	$arc, $off, $len, $preStart, $pre = $e
	$buf = New-Object byte[] ($pre + $len)
	if ($pre -gt 0) { [Array]::Copy($script:dir, $preStart, $buf, 0, $pre) }
	if ($len -gt 0) {
		if ($arc -eq 0x7FFF) { [Array]::Copy($script:dir, $script:hdr + $script:treeSize + $off, $buf, $pre, $len) }
		else {
			if (-not $script:streams.ContainsKey($arc)) {
				$f = Join-Path $PSScriptRoot ('pak01_{0:D3}.vpk' -f $arc)
				if (-not (Test-Path -LiteralPath $f)) { return $null }
				$script:streams[$arc] = [System.IO.File]::OpenRead($f)
			}
			$s = $script:streams[$arc]; [void]$s.Seek([int64]$off, 'Begin')
			$read = 0; while ($read -lt $len) { $n = $s.Read($buf, $pre + $read, $len - $read); if ($n -le 0) { break }; $read += $n }
		}
	}
	return ,$buf
}
function Ascii($b) { return [Text.Encoding]::ASCII.GetString($b) }

$models = @(
	'models/props_combine/combine_consoles/vr_combine_interface_01.vmdl_c',
	'models/props_combine/combine_consoles/combine_monitor_large.vmdl_c',
	'models/props_combine/combine_consoles/combine_monitor_medium.vmdl_c',
	'models/props_combine/combine_consoles/combine_monitor_small.vmdl_c'
)
$out = Join-Path $PSScriptRoot 'hla_terminal'
if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Recurse -Force }
New-Item -ItemType Directory -Force -Path $out | Out-Null
$saved = @{}
function Save($path) {
	if ($script:saved.ContainsKey($path) -or -not $script:entries.ContainsKey($path)) { return $null }
	$b = ReadEntry $script:entries[$path]; if ($null -eq $b) { return $null }
	$dst = Join-Path $script:out ($path -replace '/', '\')
	New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
	[System.IO.File]::WriteAllBytes($dst, $b); $script:saved[$path] = $b.Length
	Write-Host ('OK  ' + $path)
	return ,$b
}
foreach ($m in $models) {
	$b = Save $m
	if ($null -eq $b) { Write-Host ('НЕТ ' + $m); continue }
	$t = (Ascii $b).ToLower()
	foreach ($mm in [regex]::Matches($t, '[a-z0-9_/\.\-]+\.vmat')) {
		$mat = $mm.Value + '_c'
		$mb = Save $mat
		if ($null -eq $mb) { continue }
		$mt = (Ascii $mb).ToLower()
		foreach ($tx in [regex]::Matches($mt, '[a-z0-9_/\.\-]+\.vtex')) {
			$tex = $tx.Value + '_c'
			if ($tex -match '_ao_' -or $tex -match 'default/') { continue }   # затенение и заглушки не нужны
			[void](Save $tex)
		}
	}
}
foreach ($s in $streams.Values) { $s.Close() }
$zip = Join-Path $PSScriptRoot 'hla_terminal.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip
$mb = [math]::Round((Get-Item -LiteralPath $zip).Length / 1MB, 1)
Write-Host ''
Write-Host ("Готово: $zip  ($mb МБ, файлов: " + $saved.Count + '). Пришлите этот архив.')
Read-Host 'Нажмите Enter'
