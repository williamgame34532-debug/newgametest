"""More icons -> content/materials/network2/ (the same look as make_inventory_assets.py):
    items/<id>.png        white item icons, 128 px (game-icons.net, CC BY 3.0: Lorc, Delapouite and
                          contributors, https://game-icons.net)
    ui/icons/<name>.png   white interface icons, 128 px (Tabler Icons, MIT)
The radio, the keys, the factory and the workers, the status icons, the skills, the squads.
    python make_extra_icons.py <@iconify-json/game-icons package dir> <@tabler/icons package dir>
        <content/materials/network2>"""
import io, json, os, sys
import cairosvg
from PIL import Image

GI, TABLER, OUT = sys.argv[1], sys.argv[2], sys.argv[3]

ITEMS = {
    "radio": "walkie-talkie", "key": "key", "scrap": "metal-bar", "parts": "gears", "unit_core": "circuitry",
    "factory_crate": "cargo-crate", "disinfectant": "spray", "toolkit": "toolbox",
    "nvg": "night-vision", "ration_bag": "light-backpack", "contraband": "swap-bag", "lockpick": "lockpicks",
    "license": "contract", "goods": "cardboard-box",
    "grenade": "grenade", "breach_charge": "time-bomb", "stimdose": "syringe", "combine_lock": "padlock",
    "deploy_manhack": "delivery-drone", "deploy_rollermine": "spiked-ball", "deploy_turret": "sentry-gun",
    "splint": "knee-bandage", "tourniquet": "arm-bandage", "antidote": "vial", "export_parcel": "cardboard-box-closed",
}
UI = {
    "radio": "radio", "broadcast": "broadcast", "skills": "chart-bar", "status": "activity-heartbeat",
    "squad": "users-group", "key": "key", "mailbox": "mailbox", "tool": "tool", "kick": "shoe",
    "factory": "building-factory", "biohazard": "biohazard", "alert": "alert-triangle", "lock": "lock",
    # status icons (cl_status.lua)
    "st_bleed": "droplet-half-2", "st_radiation": "radioactive", "st_stun": "bolt", "st_sick": "mood-sick",
    "st_wounded": "heart-broken", "st_tired": "zzz", "st_search": "search", "st_combat": "alert-triangle",
    "st_broadcast": "broadcast", "st_fracture": "bone", "st_pain": "mood-wrrr",
    "treasury": "building-bank", "export": "truck-delivery",
    # skills (cl_skills.lua)
    "sk_strength": "barbell", "sk_endurance": "run", "sk_medicine": "stethoscope", "sk_engineering": "tool",
    "sk_stealth": "eye-off", "sk_persuasion": "message-circle", "trend": "trending-up",
    "camera": "camera", "shop": "building-store", "thermal": "temperature", "nvg": "eye", "tent": "tent",
    "fist": "hand-stop", "flag": "flag",
}

icons = json.load(open(os.path.join(GI, "icons.json")))
size = icons.get("width", 512)
os.makedirs(os.path.join(OUT, "items"), exist_ok=True)
for name, src in ITEMS.items():
    body = icons["icons"][src]["body"].replace("currentColor", "#ffffff")
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}">{body}</svg>'
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=128, output_height=128)
    Image.open(io.BytesIO(png)).convert("RGBA").save(os.path.join(OUT, "items", name + ".png"))

os.makedirs(os.path.join(OUT, "ui", "icons"), exist_ok=True)
for name, src in UI.items():
    svg = open(os.path.join(TABLER, "icons", "outline", src + ".svg")).read()
    svg = svg.replace('stroke="currentColor"', 'stroke="#ffffff"').replace('stroke-width="2"', 'stroke-width="1.6"')
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=128, output_height=128)
    Image.open(io.BytesIO(png)).convert("RGBA").save(os.path.join(OUT, "ui", "icons", name + ".png"))
print("icons:", len(ITEMS), "items,", len(UI), "ui")
