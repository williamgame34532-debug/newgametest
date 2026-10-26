#!/usr/bin/env bash
# Look up exact Forge 1.21.1 / Minecraft 1.21.1 (official mappings) signatures.
#   tools/api.sh class <FullyQualifiedName>   -> javap of the class (e.g. net.minecraft.world.item.SwordItem)
#   tools/api.sh find <regex>                 -> class names matching regex
#   tools/api.sh grep <regex>                 -> signature lines matching regex (with owning class)
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)/_apiprobe/api-index"
CACHE=/tmp/forge-1.21.1-javap.txt
[ -s "$CACHE" ] || zcat "$DIR/javap-protected.txt.gz" > "$CACHE"
case "$1" in
  class) awk -v c="$2" 'index($0, " " c " ")>0 && /(class|interface|enum|record) / {p=1} p {print} p && /^}/ {exit}' "$CACHE"
         awk -v c="$2" 'index($0, " " c "<")>0 && /(class|interface|enum|record) / {p=1} p {print} p && /^}/ {exit}' "$CACHE" ;;
  find)  grep -E "$2" "$DIR/classes.txt" ;;
  grep)  awk -v r="$2" '/^(public|protected|abstract|final|class|interface).*(class|interface|enum) / {cls=$0} $0 ~ r {print cls "\n    " $0}' "$CACHE" | head -n 200 ;;
  *) echo "usage: $0 class|find|grep <arg>"; exit 1 ;;
esac
