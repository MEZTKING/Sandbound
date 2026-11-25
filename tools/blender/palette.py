"""The shared colour palette every model uses: a grid of colour squares, 8 wide
(32 px each) in textures/models/palette.png.

Each model part is UV-mapped to the MIDDLE of one square, so repainting a
square (in Krita, GIMP...) recolours everything that uses it. Keep each
square one colour near its middle; texture and noise are fine.

The names below are used by make_models.py. The last row is spare:
paint your own colours there and use them in your own models."""

SWATCHES = [
    # row 0: the truck
    ["truck_red", "truck_red_dark", "rubber", "dark_grey", "mid_grey", "light_grey", "white", "yellow"],
    # row 1: lights, wood, metal
    ["glass_dark", "headlight", "taillight", "orange", "wood_light", "wood_dark", "metal", "metal_dark"],
    # row 2: the tiny crew, the beetle
    ["skin", "overalls", "hardhat", "hair", "eye", "boot", "beetle_shell", "beetle_dark"],
    # row 3: ants, hawk, scorpion
    ["ant_red", "ant_dark", "hawk_brown", "hawk_pale", "beak", "scorpion_tan", "scorpion_dark", "sting"],
    # row 4: cargo
    ["barrel_blue", "barrel_rim", "egg_white", "egg_tray", "engine_grey", "engine_dark", "ice", "kit_orange"],
    # row 5: kit, world bits
    ["kit_white", "sand", "bark", "bark_dark", "mast", "red_light", "green_led", "blue_led"],
    # row 6: Glass Desert and build parts
    ["lodestone", "lodestone_vein", "glass_shard", "sandbag", "sandbag_dark", "battery_green", "solar_blue", "black_stripe"],
    # row 7: the Drift
    ["ray_top", "ray_belly", "orb_glow", "hull_metal", "hull_dark", "hull_light", "gyro_blue", "wing_white"],
    # row 8: bases and props
    ["concrete", "concrete_dark", "tent", "tent_dark", "toolbox", "skid_metal", "kerb", "lamp_glow"],
]

COLORS = {
    "truck_red": (0.74, 0.20, 0.12), "truck_red_dark": (0.43, 0.11, 0.08), "rubber": (0.08, 0.08, 0.09),
    "dark_grey": (0.23, 0.22, 0.24), "mid_grey": (0.40, 0.41, 0.44), "light_grey": (0.7, 0.71, 0.72),
    "white": (0.95, 0.95, 0.93), "yellow": (0.90, 0.67, 0.16),
    "glass_dark": (0.12, 0.17, 0.22), "headlight": (1.0, 0.96, 0.8), "taillight": (0.85, 0.08, 0.05),
    "orange": (0.93, 0.45, 0.10), "wood_light": (0.60, 0.43, 0.26), "wood_dark": (0.36, 0.24, 0.14),
    "metal": (0.62, 0.63, 0.66), "metal_dark": (0.32, 0.33, 0.35),
    "skin": (0.95, 0.78, 0.62), "overalls": (1.0, 1.0, 1.0), "hardhat": (0.90, 0.67, 0.16),
    "hair": (0.3, 0.2, 0.12), "eye": (0.05, 0.05, 0.06), "boot": (0.3, 0.2, 0.13),
    "beetle_shell": (0.05, 0.17, 0.15), "beetle_dark": (0.04, 0.04, 0.04),
    "ant_red": (0.5, 0.1, 0.04), "ant_dark": (0.2, 0.05, 0.03), "hawk_brown": (0.42, 0.28, 0.15),
    "hawk_pale": (0.86, 0.8, 0.7), "beak": (0.96, 0.75, 0.2), "scorpion_tan": (0.70, 0.45, 0.19),
    "scorpion_dark": (0.28, 0.16, 0.08), "sting": (0.12, 0.08, 0.05),
    "barrel_blue": (0.16, 0.38, 0.55), "barrel_rim": (0.55, 0.57, 0.6), "egg_white": (0.97, 0.95, 0.88),
    "egg_tray": (0.72, 0.66, 0.55), "engine_grey": (0.38, 0.4, 0.43), "engine_dark": (0.16, 0.16, 0.17),
    "ice": (0.75, 0.9, 1.0), "kit_orange": (0.93, 0.45, 0.10), "kit_white": (0.92, 0.92, 0.9),
    "sand": (0.82, 0.66, 0.44), "bark": (0.38, 0.29, 0.21), "bark_dark": (0.22, 0.16, 0.11),
    "mast": (0.6, 0.62, 0.65), "red_light": (1.0, 0.15, 0.1), "green_led": (0.24, 0.52, 0.32),
    "blue_led": (0.2, 0.5, 1.0), "spare": (0.5, 0.5, 0.5),
    "lodestone": (0.09, 0.08, 0.11), "lodestone_vein": (0.62, 0.32, 0.85), "glass_shard": (0.6, 0.85, 0.8),
    "sandbag": (0.72, 0.62, 0.42), "sandbag_dark": (0.5, 0.42, 0.28), "battery_green": (0.24, 0.52, 0.32),
    "solar_blue": (0.08, 0.12, 0.32), "black_stripe": (0.06, 0.06, 0.06),
    "ray_top": (0.20, 0.25, 0.43), "ray_belly": (0.92, 0.88, 0.95), "orb_glow": (0.55, 0.88, 1.0),
    "hull_metal": (0.43, 0.48, 0.52), "hull_dark": (0.2, 0.21, 0.24), "hull_light": (0.4, 0.9, 1.0),
    "gyro_blue": (0.25, 0.55, 0.9), "wing_white": (0.92, 0.92, 0.94),
    "concrete": (0.52, 0.51, 0.49), "concrete_dark": (0.33, 0.32, 0.31), "tent": (0.78, 0.72, 0.6),
    "tent_dark": (0.5, 0.44, 0.34), "toolbox": (0.74, 0.20, 0.12), "skid_metal": (0.5, 0.51, 0.53),
    "kerb": (0.62, 0.61, 0.58), "lamp_glow": (1.0, 0.85, 0.55),
}

## How each square's material behaves (written to palette_material.png:
## red = roughness, green = metalness, blue = glow). 0 = smooth / not metal /
## no glow, 1 = rough / metal / bright. Anything not listed is (0.7, 0, 0).
MATERIALS = {
    "truck_red": (0.32, 0.0, 0.0), "truck_red_dark": (0.4, 0.0, 0.0), "rubber": (0.92, 0.0, 0.0),
    "dark_grey": (0.62, 0.1, 0.0), "mid_grey": (0.55, 0.2, 0.0), "light_grey": (0.5, 0.2, 0.0),
    "white": (0.45, 0.0, 0.0), "yellow": (0.38, 0.0, 0.0),
    "glass_dark": (0.08, 0.0, 0.0), "headlight": (0.12, 0.0, 0.25), "taillight": (0.2, 0.0, 0.35),
    "orange": (0.45, 0.0, 0.0), "wood_light": (0.85, 0.0, 0.0), "wood_dark": (0.88, 0.0, 0.0),
    "metal": (0.3, 1.0, 0.0), "metal_dark": (0.45, 0.9, 0.0),
    "skin": (0.6, 0.0, 0.0), "overalls": (0.8, 0.0, 0.0), "hardhat": (0.35, 0.0, 0.0),
    "eye": (0.15, 0.0, 0.0), "boot": (0.8, 0.0, 0.0),
    "beetle_shell": (0.18, 0.6, 0.0), "beetle_dark": (0.4, 0.2, 0.0),
    "ant_red": (0.3, 0.1, 0.0), "ant_dark": (0.35, 0.1, 0.0), "hawk_brown": (0.85, 0.0, 0.0),
    "hawk_pale": (0.85, 0.0, 0.0), "beak": (0.45, 0.0, 0.0), "scorpion_tan": (0.45, 0.0, 0.0),
    "scorpion_dark": (0.4, 0.0, 0.0), "sting": (0.25, 0.1, 0.0),
    "barrel_blue": (0.4, 0.0, 0.0), "barrel_rim": (0.32, 0.95, 0.0), "egg_white": (0.6, 0.0, 0.0),
    "egg_tray": (0.9, 0.0, 0.0), "engine_grey": (0.5, 0.85, 0.0), "engine_dark": (0.6, 0.7, 0.0),
    "ice": (0.08, 0.0, 0.0), "kit_orange": (0.5, 0.0, 0.0), "kit_white": (0.5, 0.0, 0.0),
    "sand": (0.95, 0.0, 0.0), "bark": (0.92, 0.0, 0.0), "bark_dark": (0.95, 0.0, 0.0),
    "mast": (0.4, 0.9, 0.0), "red_light": (0.2, 0.0, 1.0), "green_led": (0.2, 0.0, 0.9), "blue_led": (0.2, 0.0, 0.9),
    "lodestone": (0.5, 0.6, 0.0), "lodestone_vein": (0.3, 0.2, 0.9), "glass_shard": (0.05, 0.0, 0.0),
    "sandbag": (0.95, 0.0, 0.0), "sandbag_dark": (0.95, 0.0, 0.0), "battery_green": (0.4, 0.0, 0.0),
    "solar_blue": (0.12, 0.3, 0.0), "black_stripe": (0.5, 0.0, 0.0),
    "ray_top": (0.4, 0.0, 0.0), "ray_belly": (0.5, 0.0, 0.0), "orb_glow": (0.08, 0.0, 0.9),
    "hull_metal": (0.35, 0.9, 0.0), "hull_dark": (0.5, 0.7, 0.0), "hull_light": (0.2, 0.0, 1.0),
    "gyro_blue": (0.3, 0.5, 0.0), "wing_white": (0.35, 0.0, 0.0),
    "concrete": (0.85, 0.0, 0.0), "concrete_dark": (0.9, 0.0, 0.0), "tent": (0.9, 0.0, 0.0),
    "tent_dark": (0.9, 0.0, 0.0), "toolbox": (0.35, 0.0, 0.0), "skid_metal": (0.35, 0.85, 0.0),
    "kerb": (0.8, 0.0, 0.0), "lamp_glow": (0.2, 0.0, 1.0),
}

GRID = 8                    # columns
ROWS = len(SWATCHES)        # rows (add a row any time: the image grows)


def uv_of(name):
    """UV coordinate of the middle of a swatch (u right, v up, Blender style)."""
    for row, names in enumerate(SWATCHES):
        if name in names:
            col = names.index(name)
            return ((col + 0.5) / GRID, 1.0 - (row + 0.5) / ROWS)
    raise KeyError(name)


if __name__ == "__main__":
    # Run with plain Python to (re)make palette.png:  python3 palette.py out.png
    import sys
    import numpy as np
    from PIL import Image
    px = 32
    rng = np.random.default_rng(9)
    img = np.zeros((ROWS * px, GRID * px, 3))
    for row, names in enumerate(SWATCHES):
        for col, name in enumerate(names):
            c = np.array(COLORS[name])
            if name == "spare":
                c = np.array([0.35 + 0.08 * col, 0.35 + 0.05 * row, 0.4])
            cell = np.ones((px, px, 3)) * c
            cell *= (1 + rng.standard_normal((px, px, 1)) * 0.025)   # a little painted texture
            img[row * px:(row + 1) * px, col * px:(col + 1) * px] = cell
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(sys.argv[1])
    print("palette ok")
    if len(sys.argv) > 2:
        # The material palette: same grid, red = roughness, green = metal, blue = glow.
        mat = np.zeros((ROWS * px, GRID * px, 3))
        for row, names in enumerate(SWATCHES):
            for col, name in enumerate(names):
                mat[row * px:(row + 1) * px, col * px:(col + 1) * px] = MATERIALS.get(name, (0.7, 0.0, 0.0))
        Image.fromarray((mat * 255 + 0.5).astype(np.uint8), "RGB").save(sys.argv[2])
        print("material palette ok")
    if len(sys.argv) > 3:
        # Grime: tileable cloudy noise (several sizes of blur on random dots,
        # done with an FFT so it wraps round seamlessly).
        n = 256
        out = np.zeros((n, n))
        for size, weight in ((40, 0.5), (14, 0.3), (4, 0.2)):
            f = np.fft.fft2(rng.standard_normal((n, n)))
            k = np.fft.fftfreq(n)[:, None] ** 2 + np.fft.fftfreq(n)[None, :] ** 2
            layer = np.real(np.fft.ifft2(f * np.exp(-k * (size ** 2) * 2.0)))
            out += (layer - layer.mean()) / (layer.std() + 1e-9) * weight
        out = np.clip(0.5 + out * 0.22, 0, 1)
        Image.fromarray((out * 255 + 0.5).astype(np.uint8), "L").save(sys.argv[3])
        print("grime ok")
