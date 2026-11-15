# Palette v2 for characters built with art/tools/char_kit.py (visual prototype, phase 2).
# 256 x 128 px, cells 8 x 8: 32 columns (material cells) x 16 rows (roles; the shader shifts the UV by rows).
# Run anywhere with Pillow: python art/chars/make_palette.py  -> T_Char_Palette_D.png (colour, sRGB)
# and T_Char_Palette_ORM.png (R = unused 1, G = roughness, B = metal; linear).
# Columns must match the constants in art/tools/char_kit.py.
from PIL import Image
import os

CELLS = [  # name, colour, roughness, metal
    ("STEEL", "#A3ACBA", 0.36, 1.0), ("STEEL_DARK", "#6C7481", 0.44, 1.0), ("STEEL_LIGHT", "#C6CDD8", 0.30, 1.0),
    ("GOLD", "#D4A23F", 0.34, 1.0), ("GOLD_DARK", "#9C7426", 0.40, 1.0),
    ("ROLE", None, 0.95, 0.0), ("ROLE_DARK", None, 0.95, 0.0), ("ROLE_LIGHT", None, 0.95, 0.0), ("ROLE_PAINT", None, 0.48, 0.0),
    ("LEATHER", "#7A5236", 0.70, 0.0), ("LEATHER_DARK", "#4E3524", 0.74, 0.0), ("WOOD", "#8A6238", 0.82, 0.0),
    ("MAIL", "#5C636E", 0.55, 0.6), ("VOID", "#1E1F26", 0.95, 0.0), ("LINEN", "#D9CFB4", 0.95, 0.0),
    ("SKIN", "#D2A07E", 0.80, 0.0), ("CRIMSON", "#A72D27", 0.92, 0.0), ("NAVY", "#2C3A5E", 0.92, 0.0),
    ("IVORY", "#EFE6CC", 0.95, 0.0), ("HAIR", "#5A3D28", 0.85, 0.0),
]
# role rows: main cloth, dark, light, painted armour (same order of rows as the old palette: 0 house, 1 tank, ...)
ROLES = {
    0: ("#3F64B8", "#283F7C", "#7D9BE0", "#3A5DB0"),   # House of the Wolf (default = tank blue)
    1: ("#3F64B8", "#283F7C", "#7D9BE0", "#3A5DB0"),   # tank: royal blue
    2: ("#3C8A4C", "#245A33", "#7DBF7E", "#35804A"),   # archer: forest green
    3: ("#EDE3C6", "#C7B994", "#FBF6E4", "#E4D9B8"),   # priest: ivory
    4: ("#D9A02C", "#98691A", "#F0C766", "#CC9426"),   # cavalier: ochre gold
    5: ("#7257A6", "#463470", "#A58FD2", "#694F9C"),   # assassin: muted violet
    6: ("#8A4A30", "#5B3022", "#AE7A57", "#7A4430"),   # brigands: rust and mud (no hero colour is near)
    7: ("#962620", "#561512", "#C2554A", "#84201B"),   # brigand commanders: blood red with blackened iron
}
# Enemy rows (brigands are not of the order): they override whole cells, not only the role columns
# (dull iron instead of polished steel, brass instead of gold, dirty wool instead of linen). Name -> colour.
OVERRIDES = {
    6: {"STEEL": "#85847E", "STEEL_DARK": "#585852", "STEEL_LIGHT": "#A3A198", "GOLD": "#9E8649", "GOLD_DARK": "#6C5B31",
        "LEATHER": "#6B4A31", "LEATHER_DARK": "#3F2C1F", "MAIL": "#5A5852", "LINEN": "#B3A584", "IVORY": "#C4B794",
        "CRIMSON": "#7E2E22", "NAVY": "#4B4A3A", "HAIR": "#4A3424"},
    7: {"STEEL": "#6E727A", "STEEL_DARK": "#41444B", "STEEL_LIGHT": "#8E939C", "GOLD": "#B08B3E", "GOLD_DARK": "#77602C",
        "LEATHER": "#4A3427", "LEATHER_DARK": "#2C211B", "MAIL": "#4C4F56", "LINEN": "#8F8574", "IVORY": "#A99E88",
        "CRIMSON": "#6E1A16", "NAVY": "#26262B", "HAIR": "#2E2420"},
}
COLS, ROWS, PX = 32, 16, 8


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


d = Image.new("RGB", (COLS * PX, ROWS * PX), (0, 0, 0))
o = Image.new("RGB", (COLS * PX, ROWS * PX), (255, 255, 0))
for row in range(ROWS):
    role = ROLES.get(row, ROLES[0])
    k = 0
    for col, (name, colour, rough, metal) in enumerate(CELLS):
        if colour is None:
            colour = role[k]
            k += 1
        colour = OVERRIDES.get(row, {}).get(name, colour)
        d.paste(rgb(colour), (col * PX, row * PX, col * PX + PX, row * PX + PX))
        o.paste((255, int(round(rough * 255)), int(round(metal * 255))), (col * PX, row * PX, col * PX + PX, row * PX + PX))
here = os.path.dirname(os.path.abspath(__file__))
d.save(os.path.join(here, "T_Char_Palette_D.png"))
o.save(os.path.join(here, "T_Char_Palette_ORM.png"))
print("palette", d.size)
