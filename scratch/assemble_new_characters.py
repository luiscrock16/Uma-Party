import os
from PIL import Image

chars = [
    ('Agnes Tachyon', 'agtc'),
    ('Dantsu Flame', 'dafl'),
    ('Jungle Pocket', 'jupc'),
    ('Samson Big', 'sabg'),
    ('Special Week', 'spwe')
]

frames_to_assemble = [
    # 1. Idle (100)
    "100_00", "100_01", "100_02", "100_03",
    # 2. Caminar (101)
    "101_00", "101_01", "101_02", "101_03", "101_04", "101_05",
    # 3. Correr (102)
    "102_00", "102_01", "102_02", "102_03", "102_04", "102_05",
    # 4. Intro (210)
    "210_00", "210_01", "210_02",
    # 5. Impacto / Aturdido (320)
    "320_00", "320_01", "320_02", "320_03", "320_04", "320_06",
    # 6. Atrapado (340)
    "340_00",
    # 7. Resbalar (330)
    "330_00", "330_01", "330_02",
    # 8. Globo (362)
    "362_00", "362_01",
    # 9. Acierto / Victoria (730)
    "730_00", "730_01", "730_02", "730_03",
    # 10. Saltar (830)
    "830_00", "830_01", "830_02"
]

base_sprites_dir = r"e:/PROYECTOS GODOT/Umamusume party/uma-party/assets/Sprites"

for char_name, prefix in chars:
    src_dir = os.path.join(base_sprites_dir, char_name)
    out_dir = os.path.join(src_dir, "assembled")
    os.makedirs(out_dir, exist_ok=True)
    count = 0
    for frame in frames_to_assemble:
        base = f"{prefix}{frame}"
        b_path = os.path.join(src_dir, f"{base}.png.png")
        r_path = os.path.join(src_dir, f"{base}r.png.png")
        l_path = os.path.join(src_dir, f"{base}l.png.png")

        if not os.path.exists(b_path):
            # Check if 320_06 doesn't exist, try 320_05
            if frame == "320_06":
                base_alt = f"{prefix}320_05"
                b_path = os.path.join(src_dir, f"{base_alt}.png.png")
                r_path = os.path.join(src_dir, f"{base_alt}r.png.png")
                l_path = os.path.join(src_dir, f"{base_alt}l.png.png")
            if not os.path.exists(b_path):
                print(f"Warning: {char_name} missing {b_path}")
                continue

        b_img = Image.open(b_path).convert("RGBA")

        # 1. Composite with R (facing right)
        if os.path.exists(r_path):
            r_img = Image.open(r_path).convert("RGBA")
            comp_r = Image.alpha_composite(b_img, r_img)
        else:
            comp_r = b_img

        out_r = os.path.join(out_dir, f"{base}.png")
        comp_r.save(out_r)

        # 2. Composite with L (facing left)
        if os.path.exists(l_path):
            l_img = Image.open(l_path).convert("RGBA")
            comp_l = Image.alpha_composite(b_img, l_img)
            out_l = os.path.join(out_dir, f"{base}_l.png")
            comp_l.save(out_l)

        count += 1
    print(f"[{char_name}] Assembled {count} frames in {out_dir}")
