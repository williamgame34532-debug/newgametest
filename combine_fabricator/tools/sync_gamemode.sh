#!/bin/sh
# Copy the fabricator code into the Half-Life: Alyx gamemode (single source: combine_fabricator/lua)
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$ROOT/hlalyx/gamemode/fabricator" "$ROOT/hlalyx/entities/entities"
cp "$ROOT"/combine_fabricator/lua/cf_rework/*.lua "$ROOT/hlalyx/gamemode/fabricator/"
rm -rf "$ROOT/hlalyx/entities/entities/sent_combine_fabricator" "$ROOT/hlalyx/entities/entities/sent_cf_resin"
cp -r "$ROOT/combine_fabricator/lua/entities/sent_combine_fabricator" "$ROOT/combine_fabricator/lua/entities/sent_cf_resin" "$ROOT/hlalyx/entities/entities/"
echo synced
