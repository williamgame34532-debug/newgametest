"""Inventory assets -> content/materials/network2/
    items/<id>.png        white item icons, 128 px (game-icons.net, CC BY 3.0: Lorc, Delapouite and
                          contributors, https://game-icons.net)
    ui/icons/<name>.png   white interface icons, 128 px (Tabler Icons, MIT)
    ui/inv_slot.png       9-slice slot (64 px, corner 10): dark, translucent, faint rim, light top
    ui/inv_tip.png        9-slice tooltip / small panels (64 px, corner 8)
    ui/inv_cell.png       9-slice item cell (64 px, corner 6): grey-dark, lighter top
    ui/inv_shade.png      256 px vignette over the grey backdrop of the inventory
    python make_inventory_assets.py <game-icons package dir> <tabler package dir> <content/materials/network2>"""
import io, json, os, sys
import cairosvg
import numpy as np
from PIL import Image, ImageDraw

GI, TABLER, OUT = sys.argv[1], sys.argv[2], sys.argv[3]

ITEMS = {
    "ration": "cardboard-box-closed", "canned": "canned-fish", "water": "water-bottle", "soda": "soda-can",
    "bread": "sliced-bread", "medkit": "first-aid-kit", "bandage": "bandage-roll", "pills": "medicine-pills",
    "pistol": "pistol-gun", "smg": "uzi", "shotgun": "sawed-off-shotgun", "crowbar": "crowbar", "stunstick": "baton",
    "cap": "billed-cap", "gasmask": "gas-mask", "jacket": "moncler-jacket", "gloves": "gloves",
    "trousers": "trousers", "boots": "leather-boot", "rifle": "ak47", "bag": "knapsack",
    "cid": "id-card", "flashlight": "flashlight", "vest": "kevlar-vest", "helmet": "brodie-helmet",
}
UI = {
    "inventory": "backpack", "settings": "settings", "authors": "users", "config": "adjustments",
    "health": "heart", "hunger": "meat", "thirst": "droplet", "stamina": "run", "take": "hand-grab",
    "interact": "hand-finger", "drop": "arrow-bar-to-down", "close": "x",
    # the G wheel
    "mic": "microphone", "voice_whisper": "volume-3", "voice_normal": "volume-2", "voice_yell": "volume",
    "acts": "walk", "back": "arrow-back-up", "act_sit": "armchair", "act_ground": "yoga", "act_wall": "wall",
    "act_lie": "bed", "act_injured": "bandage", "act_handsup": "hand-stop", "act_arrest": "user-x",
    "act_lean": "stretching-2", "act_stand": "man", "act_check": "eye-search", "act_foldarms": "accessible",
    "act_kneel": "stretching", "act_shiver": "mood-nervous",
    # interaction marks
    "door": "door",
    # the interaction wheel over players
    "meet": "user-plus", "tokens": "coins", "cid": "id", "examine": "eye-search",
    # bodies, searching, storages, NPCs
    "pulse": "heartbeat", "helpup": "user-up", "heal": "first-aid-kit", "search": "search", "swap": "arrows-exchange",
    "storage": "box", "trade": "building-store", "quest": "list-check", "talk": "message-circle", "edit": "pencil",
    "skull": "skull", "shield": "shield",
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

SS = 4


def plate(s, r, fill, rim, top=0):
    big = Image.new("RGBA", (s * SS, s * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle([0, 0, s * SS - 1, s * SS - 1], r * SS, fill=fill)
    d.rounded_rectangle([SS / 2, SS / 2, s * SS - 1 - SS / 2, s * SS - 1 - SS / 2], r * SS, outline=rim, width=SS)
    im = np.asarray(big.resize((s, s), Image.LANCZOS)).astype(np.float32)
    if top:
        # a faint light at the top edge
        y = np.linspace(1, 0, s)[:, None]
        glow = np.clip(y * 3 - 2, 0, 1) * top
        im[..., :3] = im[..., :3] + glow[..., None] * 255 * (im[..., 3:4] > 0)
    return Image.fromarray(np.clip(im, 0, 255).astype(np.uint8), "RGBA")


plate(64, 10, (10, 12, 15, 170), (255, 255, 255, 24), 0.05).save(os.path.join(OUT, "ui", "inv_slot.png"))
plate(64, 8, (11, 13, 16, 238), (255, 255, 255, 30), 0.04).save(os.path.join(OUT, "ui", "inv_tip.png"))
# item cell: grey-dark, a lighter top, faint rim (corner 6) - the models stand on it
plate(64, 6, (34, 36, 39, 236), (255, 255, 255, 16), 0.06).save(os.path.join(OUT, "ui", "inv_cell.png"))

# shade: a soft vignette over the grey backdrop (darker corners and edges)
S = 256
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32) / (S - 1) * 2 - 1
r = np.sqrt((xx * 0.85) ** 2 + yy ** 2)
a = np.clip((r - 0.45) / 0.9, 0, 1) ** 1.6 * 190
shade = np.zeros((S, S, 4), np.float32)
shade[..., :3] = (0, 0, 0)
shade[..., 3] = a
Image.fromarray(shade.astype(np.uint8), "RGBA").save(os.path.join(OUT, "ui", "inv_shade.png"))
print("items", len(ITEMS), "ui", len(UI))
