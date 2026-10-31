#!/bin/sh
# Copy the fabricator code into the Half-Life: Alyx gamemode (single source: combine_fabricator/lua).
# In the gamemode the entities get their own class names (hla_fabricator, hla_resin).
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GM="$ROOT/hlalyx"
mkdir -p "$GM/gamemode/fabricator" "$GM/entities/entities"
cp "$ROOT"/combine_fabricator/lua/cf_rework/*.lua "$GM/gamemode/fabricator/"
rm -rf "$GM/entities/entities/"*
cp -r "$ROOT/combine_fabricator/lua/entities/sent_combine_fabricator" "$GM/entities/entities/hla_fabricator"
cp -r "$ROOT/combine_fabricator/lua/entities/sent_cf_resin" "$GM/entities/entities/hla_resin"
echo synced
