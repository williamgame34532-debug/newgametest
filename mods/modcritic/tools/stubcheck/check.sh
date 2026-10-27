#!/usr/bin/env bash
# Offline type-check of this mod: generates Java stubs for every Minecraft/Forge class the
# sources use (exact signatures from mods/_apiprobe/api-index, the javap dump of the real jar),
# adds hand-written stubs for FML/brigadier/gson/etc. (hand/), and runs javac.
# Only errors inside src/ are printed; errors inside the generated stubs are expected noise.
# Not a replacement for the CI build (hand stubs are approximations), but it catches wrong
# signatures, missing abstract methods, lambda/generic mistakes, typos.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
MOD="$(cd "$HERE/../.." && pwd)"
CACHE=/tmp/forge-1.21.1-javap.txt
[ -s "$CACHE" ] || zcat "$MOD/../_apiprobe/api-index/javap-protected.txt.gz" > "$CACHE"
WORK="$(mktemp -d)"
{ grep -rhoE '^import (net\.minecraft|com\.mojang\.blaze3d)[^;]*' "$MOD/src/main/java" | sed 's/import //'; cat "$HERE/extra_seeds.txt"; } | sort -u > "$WORK/seeds.txt"
(cd "$HERE/hand" && find . -name '*.java' | sed 's|^\./||; s|\.java$||; s|/|.|g') > "$WORK/handstub_types.txt"
python3 "$HERE/stubgen.py" "$CACHE" "$WORK/gen" "$WORK/seeds.txt" 2>/dev/null
mkdir -p "$WORK/out"
javac -XDshould-stop.ifError=FLOW -Xmaxerrs 5000 -proc:none -d "$WORK/out" \
  $(find "$MOD/src/main/java" -name '*.java') $(find "$WORK/gen" "$HERE/hand" -name '*.java') > "$WORK/err.txt" 2>&1 || true
if grep -A4 'error:' "$WORK/err.txt" | grep -v "$WORK" | grep -v "$HERE/hand" | grep -q 'error:'; then
  awk -v w="$WORK" -v h="$HERE/hand" '/error:/{show = (index($0, w) == 0 && index($0, h) == 0)} show' "$WORK/err.txt"
  echo "stubcheck: errors found"; rm -rf "$WORK"; exit 1
fi
echo "stubcheck: OK (no errors in mod sources)"
rm -rf "$WORK"
