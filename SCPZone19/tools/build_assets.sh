#!/usr/bin/env bash
# Regenerates every binary asset of SCP: Zone-19 from the SCP - Containment Breach
# source release (CC BY-SA 3.0): https://github.com/Regalis11/scpcb
#
#   tools/build_assets.sh /path/to/scpcb
set -euo pipefail

SCPCB="$(cd "$1" && pwd)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/mod/src/main/resources/assets/scpzone19"
RP="$ROOT/resourcepack"
TOOLS="$ROOT/tools"

python3 "$TOOLS/gen_skins.py" "$MOD" "$ROOT/skins"
python3 -I "$TOOLS/gen_textures.py" "$SCPCB/GFX" "$MOD" "$RP"
mkdir -p "$MOD/textures/gui/panorama" "$RP/assets/minecraft/textures/gui/title/background"
python3 -I "$TOOLS/gen_panorama.py" "$SCPCB/GFX" "$MOD/textures/gui/panorama" 512
cp "$MOD"/textures/gui/panorama/panorama_*.png "$RP/assets/minecraft/textures/gui/title/background/"

python3 -I "$TOOLS/gen_models.py" "$MOD"

# ---- sounds: positional effects must be mono, music stays stereo
sfx() { # <src relative to SFX> <dest relative to sounds/> [mono]
  mkdir -p "$(dirname "$MOD/sounds/$2.ogg")"
  local ch=()
  [[ "${3:-mono}" == mono ]] && ch=(-ac 1)
  ffmpeg -loglevel error -y -i "$SCPCB/SFX/$1" "${ch[@]}" -c:a libvorbis -q:a 4 "$MOD/sounds/$2.ogg"
}
sfx Ambient/Zone1/Ambient1.ogg ambient/ambient1
sfx Ambient/Zone1/Ambient2.ogg ambient/ambient2
sfx Ambient/Zone1/Ambient3.ogg ambient/ambient3
sfx Alarm/Alarm2_1.ogg alarm/alarm
sfx Alarm/Alarm3.ogg alarm/alarm_long
sfx Door/DoorOpen1.ogg door/open
sfx Door/DoorClose1.ogg door/close
sfx Door/BigDoorOpen1.ogg door/big_open
sfx Door/DoorError.ogg door/error
sfx Interact/KeycardUse1.ogg interact/keycard
sfx Interact/Button.ogg interact/button
sfx Interact/PickItem1.ogg interact/pickup
sfx General/Gunshot.ogg gun/shot_pistol
sfx General/Gunshot2.ogg gun/shot_rifle
sfx SCP/173/NeckSnap1.ogg scp173/snap1
sfx SCP/173/NeckSnap2.ogg scp173/snap2
sfx SCP/173/StoneDrag.ogg scp173/drag
sfx SCP/173/Rattle1.ogg scp173/rattle
sfx SCP/096/Scream.ogg scp096/scream
sfx SCP/096/Triggered.ogg scp096/triggered
sfx SCP/106/Laugh.ogg scp106/laugh
sfx SCP/106/Breathing.ogg scp106/breathing
sfx SCP/106/Decay1.ogg scp106/decay
sfx Radio/Chatter1.ogg radio/chatter1
sfx Radio/Chatter2.ogg radio/chatter2
sfx Character/MTF/Beep.ogg radio/beep
sfx Character/MTF/Announc.ogg radio/announcement
sfx Music/Intro.ogg music/intro stereo
sfx Music/HeavyContainment.ogg music/hcz stereo
sfx Music/096Chase.ogg music/chase096 stereo
sfx Music/106.ogg music/scp106 stereo
sfx Music/GateB1.ogg music/gateb stereo
sfx Music/Menu.ogg music/menu stereo

mkdir -p "$RP/assets/minecraft/sounds/zone19"
cp "$MOD/sounds/music/menu.ogg" "$RP/assets/minecraft/sounds/zone19/menu.ogg"
cp "$MOD/sounds/interact/button.ogg" "$RP/assets/minecraft/sounds/zone19/button.ogg"
echo "assets rebuilt"
