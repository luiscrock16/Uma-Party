import os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

output_dir = r"e:\PROYECTOS GODOT\Umamusume party\uma-party\assets\minijuego_plataformas"
os.makedirs(output_dir, exist_ok=True)
preview_dir = r"e:\PROYECTOS GODOT\Umamusume party\uma-party\assets\previews"
os.makedirs(preview_dir, exist_ok=True)

def get_font(name="arialbd.ttf", size=24):
    font_path = os.path.join(r"C:\Windows\Fonts", name)
    if os.path.exists(font_path):
        return ImageFont.truetype(font_path, size)
    return ImageFont.load_default()

def draw_rounded_rect(draw, bbox, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline, width=width)

# =========================================================================
# 1. BG_ESTADIO_PLATAFORMAS (1152 x 648)
# =========================================================================
def generate_bg_estadio():
    scale = 2
    w, h = 1152 * scale, 648 * scale
    im = Image.new("RGBA", (w, h), (20, 15, 38, 255))
    draw = ImageDraw.Draw(im)

    # Gradiente de cielo nocturno de estadio
    for y in range(h):
        pct = y / float(h)
        # De azul noche profundo arriba a morado/turquesa de estadio abajo
        r = int(18 * (1 - pct) + 35 * pct)
        g = int(22 * (1 - pct) + 55 * pct)
        b = int(45 * (1 - pct) + 90 * pct)
        draw.line([0, y, w, y], fill=(r, g, b, 255))

    # Nubes iluminadas por focos en el fondo
    import random
    random.seed(123)
    for _ in range(12):
        cx = random.randint(0, w)
        cy = random.randint(int(h * 0.45), h)
        rad_x = random.randint(140 * scale, 300 * scale)
        rad_y = random.randint(60 * scale, 120 * scale)
        draw.ellipse([cx - rad_x, cy - rad_y, cx + rad_x, cy + rad_y], fill=(60, 95, 145, 45))

    # Haces de luz de estadio (focos dirigidos al cielo)
    spotlights = [(180 * scale, w * 0.35), (320 * scale, w * 0.45), (850 * scale, w * 0.65), (1000 * scale, w * 0.75)]
    for base_x, top_x in spotlights:
        poly = [
            (base_x - 30 * scale, h),
            (base_x + 30 * scale, h),
            (top_x + 120 * scale, 0),
            (top_x - 120 * scale, 0)
        ]
        draw.polygon(poly, fill=(180, 225, 255, 25))

    # Silueta de tribunas y estadio en el horizonte
    arena_y = int(h * 0.65)
    draw.polygon([(0, arena_y), (w, arena_y), (w, h), (0, h)], fill=(12, 10, 22, 160))
    # Pequeñas luces de público/pantallas
    for _ in range(250):
        lx = random.randint(0, w)
        ly = random.randint(arena_y + 10 * scale, h - 20 * scale)
        col = random.choice([(255, 230, 120), (100, 220, 255), (255, 120, 180), (140, 255, 160)])
        draw.ellipse([lx, ly, lx + 3 * scale, ly + 3 * scale], fill=(*col, 180))

    # Vigas de acero en perspectiva bajo el vacío
    for bx in range(100 * scale, w, 220 * scale):
        draw.line([bx, h, w // 2, int(h * 0.45)], fill=(45, 60, 90, 80), width=3 * scale)

    im_final = im.resize((1152, 648), Image.Resampling.LANCZOS)
    im_final.save(os.path.join(output_dir, "bg_estadio_plataformas.png"))
    print("Saved bg_estadio_plataformas.png")

# =========================================================================
# 2. PANTALLA_JUMBOTRON (360 x 170)
# =========================================================================
def generate_pantalla_jumbotron():
    scale = 3
    w, h = 360 * scale, 170 * scale
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Cables y soportes de suspensión arriba
    draw.rectangle([45 * scale, 0, 52 * scale, 25 * scale], fill=(120, 130, 150, 255))
    draw.rectangle([w - 52 * scale, 0, w - 45 * scale, 25 * scale], fill=(120, 130, 150, 255))
    draw.line([48 * scale, 0, 48 * scale, 25 * scale], fill=(210, 220, 240, 255), width=2 * scale)
    draw.line([w - 48 * scale, 0, w - 48 * scale, 25 * scale], fill=(210, 220, 240, 255), width=2 * scale)

    # Chasis exterior metálico curvo
    y_body = 22 * scale
    draw_rounded_rect(draw, [10 * scale, y_body, w - 10 * scale, h - 8 * scale], 22 * scale, fill=(35, 40, 55, 255), outline=(75, 90, 120, 255), width=5 * scale)

    # Bisel interior de neón
    draw_rounded_rect(draw, [18 * scale, y_body + 8 * scale, w - 18 * scale, h - 16 * scale], 16 * scale, fill=(15, 18, 28, 255), outline=(0, 210, 255, 255), width=3 * scale)

    # Pantalla LED principal
    screen_rect = [26 * scale, y_body + 16 * scale, w - 26 * scale, h - 24 * scale]
    draw_rounded_rect(draw, screen_rect, 10 * scale, fill=(8, 12, 20, 255))

    # Matriz sutil de píxeles LED en la pantalla
    for ly in range(int(screen_rect[1]), int(screen_rect[3]), 3 * scale):
        draw.line([screen_rect[0], ly, screen_rect[2], ly], fill=(20, 30, 45, 90), width=1 * scale)

    # Letrero superior: "★ TARGET SYMBOL ★"
    font_sub = get_font("comicbd.ttf", 11 * scale)
    draw.text((w // 2, y_body + 27 * scale), "★ TARGET FIGURE ★", font=font_sub, fill=(0, 225, 255, 240), anchor="mm")

    im_final = im.resize((360, 170), Image.Resampling.LANCZOS)
    im_final.save(os.path.join(output_dir, "pantalla_jumbotron.png"))
    print("Saved pantalla_jumbotron.png")

# =========================================================================
# 3. SYMBOLS (Zanahoria, Herradura, Trébol, Estrella, Corona) - 80 x 80 px
# =========================================================================
def generate_symbols():
    dim = 80
    scale = 3
    s_dim = dim * scale
    cx, cy = s_dim // 2, s_dim // 2

    # 0. Zanahoria 🥕
    im0 = Image.new("RGBA", (s_dim, s_dim), (0, 0, 0, 0))
    d0 = ImageDraw.Draw(im0)
    # Hojas verdes
    d0.ellipse([cx - 20 * scale, cy - 35 * scale, cx - 4 * scale, cy - 14 * scale], fill=(60, 215, 80, 255), outline=(30, 140, 50, 255), width=2 * scale)
    d0.ellipse([cx - 8 * scale, cy - 38 * scale, cx + 8 * scale, cy - 15 * scale], fill=(80, 235, 100, 255), outline=(30, 140, 50, 255), width=2 * scale)
    d0.ellipse([cx + 4 * scale, cy - 35 * scale, cx + 20 * scale, cy - 14 * scale], fill=(60, 215, 80, 255), outline=(30, 140, 50, 255), width=2 * scale)
    # Cuerpo naranja
    c_pts = [
        (cx - 22 * scale, cy - 15 * scale),
        (cx + 22 * scale, cy - 15 * scale),
        (cx + 18 * scale, cy + 12 * scale),
        (cx + 4 * scale, cy + 34 * scale),
        (cx - 4 * scale, cy + 34 * scale),
        (cx - 18 * scale, cy + 12 * scale)
    ]
    d0.polygon(c_pts, fill=(255, 125, 20, 255), outline=(210, 80, 0, 255))
    for gy in [cy - 6 * scale, cy + 4 * scale, cy + 16 * scale]:
        d0.line([cx - 12 * scale, gy, cx + 6 * scale, gy], fill=(220, 90, 10, 255), width=2 * scale)
    im0.resize((dim, dim), Image.Resampling.LANCZOS).save(os.path.join(output_dir, "simbolo_0_zanahoria.png"))

    # 1. Herradura 🧲 (Azul Cyan metálico brillante)
    im1 = Image.new("RGBA", (s_dim, s_dim), (0, 0, 0, 0))
    d1 = ImageDraw.Draw(im1)
    hr = 28 * scale
    thick = 12 * scale
    # Herradura exterior
    d1.arc([cx - hr, cy - hr, cx + hr, cy + hr], 0, 180, fill=(0, 215, 255, 255), width=thick)
    d1.rectangle([cx - hr, cy - 18 * scale, cx - hr + thick, cy], fill=(0, 215, 255, 255))
    d1.rectangle([cx + hr - thick, cy - 18 * scale, cx + hr, cy], fill=(0, 215, 255, 255))
    # Puntas plateadas
    d1.rectangle([cx - hr - 2 * scale, cy - 24 * scale, cx - hr + thick + 2 * scale, cy - 16 * scale], fill=(240, 250, 255, 255))
    d1.rectangle([cx + hr - thick - 2 * scale, cy - 24 * scale, cx + hr + 2 * scale, cy - 16 * scale], fill=(240, 250, 255, 255))
    # Clavos dorados
    for nang in [35, 75, 105, 145]:
        rad = nang * math.pi / 180.0
        nx = cx + (hr - thick // 2) * math.cos(rad)
        ny = cy + (hr - thick // 2) * math.sin(rad)
        d1.ellipse([nx - 2.5 * scale, ny - 2.5 * scale, nx + 2.5 * scale, ny + 2.5 * scale], fill=(255, 230, 80, 255))
    im1.resize((dim, dim), Image.Resampling.LANCZOS).save(os.path.join(output_dir, "simbolo_1_herradura.png"))

    # 2. Trébol de 4 hojas 🍀 (Verde Esmeralda)
    im2 = Image.new("RGBA", (s_dim, s_dim), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(im2)
    lr = 13 * scale
    offsets = [(0, -14 * scale), (14 * scale, 0), (0, 14 * scale), (-14 * scale, 0)]
    for ox, oy in offsets:
        d2.ellipse([cx + ox - lr, cy + oy - lr, cx + ox + lr, cy + oy + lr], fill=(30, 210, 90, 255), outline=(15, 140, 50, 255), width=2 * scale)
        d2.ellipse([cx + ox - lr + 3 * scale, cy + oy - lr + 3 * scale, cx + ox + lr - 3 * scale, cy + oy + lr - 3 * scale], fill=(70, 235, 125, 255))
    # Tallo
    d2.arc([cx - 4 * scale, cy + 8 * scale, cx + 22 * scale, cy + 32 * scale], 90, 210, fill=(20, 150, 55, 255), width=4 * scale)
    im2.resize((dim, dim), Image.Resampling.LANCZOS).save(os.path.join(output_dir, "simbolo_2_trebol.png"))

    # 3. Estrella ⭐ (Amarillo Oro)
    im3 = Image.new("RGBA", (s_dim, s_dim), (0, 0, 0, 0))
    d3 = ImageDraw.Draw(im3)
    pts = []
    r_out, r_in = 32 * scale, 14 * scale
    for i in range(10):
        r = r_out if i % 2 == 0 else r_in
        ang = i * (math.pi / 5.0) - math.pi / 2.0
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    d3.polygon(pts, fill=(255, 215, 20, 255), outline=(220, 160, 0, 255))
    # Resplandor interior
    inner_pts = [(cx + (x - cx) * 0.75, cy + (y - cy) * 0.75) for x, y in pts]
    d3.polygon(inner_pts, fill=(255, 245, 120, 255))
    im3.resize((dim, dim), Image.Resampling.LANCZOS).save(os.path.join(output_dir, "simbolo_3_estrella.png"))

    # 4. Corona 👑 (Rosa / Fucsia de princesa / Queen)
    im4 = Image.new("RGBA", (s_dim, s_dim), (0, 0, 0, 0))
    d4 = ImageDraw.Draw(im4)
    crown_pts = [
        (cx - 26 * scale, cy + 18 * scale),
        (cx - 28 * scale, cy - 8 * scale),
        (cx - 14 * scale, cy + 4 * scale),
        (cx, cy - 18 * scale),
        (cx + 14 * scale, cy + 4 * scale),
        (cx + 28 * scale, cy - 8 * scale),
        (cx + 26 * scale, cy + 18 * scale)
    ]
    d4.polygon(crown_pts, fill=(255, 60, 140, 255), outline=(200, 20, 95, 255))
    # Joyas en las puntas
    for jx, jy in [(cx - 28 * scale, cy - 8 * scale), (cx, cy - 18 * scale), (cx + 28 * scale, cy - 8 * scale)]:
        d4.ellipse([jx - 4 * scale, jy - 4 * scale, jx + 4 * scale, jy + 4 * scale], fill=(255, 240, 100, 255), outline=(255, 255, 255, 255), width=1 * scale)
    # Banda dorada inferior
    d4.rectangle([cx - 24 * scale, cy + 12 * scale, cx + 24 * scale, cy + 18 * scale], fill=(255, 215, 40, 255))
    im4.resize((dim, dim), Image.Resampling.LANCZOS).save(os.path.join(output_dir, "simbolo_4_corona.png"))

    print("Saved all 5 symbols!")

# =========================================================================
# 4. PLATFORM TILES (64 x 64 px)
# =========================================================================
def generate_platform_tiles():
    dim = 64
    scale = 3
    s_dim = dim * scale

    # A) Tile Neutral (Futurista azul metálico)
    im_n = Image.new("RGBA", (s_dim, s_dim), (0, 0, 0, 0))
    dn = ImageDraw.Draw(im_n)
    # Borde 3D bisel inferior
    draw_rounded_rect(dn, [3 * scale, 3 * scale, s_dim - 3 * scale, s_dim - 3 * scale], 10 * scale, fill=(25, 32, 50, 255), outline=(60, 80, 120, 255), width=3 * scale)
    # Superficie superior
    draw_rounded_rect(dn, [6 * scale, 6 * scale, s_dim - 6 * scale, s_dim - 12 * scale], 8 * scale, fill=(45, 55, 85, 255), outline=(100, 140, 200, 255), width=2 * scale)
    # Rejilla suave
    for i in range(16 * scale, s_dim - 16 * scale, 12 * scale):
        dn.line([i, 8 * scale, i, s_dim - 14 * scale], fill=(60, 75, 115, 140), width=1 * scale)
    im_n.resize((dim, dim), Image.Resampling.LANCZOS).save(os.path.join(output_dir, "tile_neutral.png"))

    # B) Tile Safe (Halo verde neón brillante de salvación)
    im_s = Image.new("RGBA", (s_dim, s_dim), (0, 0, 0, 0))
    ds = ImageDraw.Draw(im_s)
    draw_rounded_rect(ds, [2 * scale, 2 * scale, s_dim - 2 * scale, s_dim - 2 * scale], 10 * scale, fill=(20, 65, 40, 255), outline=(50, 255, 110, 255), width=4 * scale)
    draw_rounded_rect(ds, [6 * scale, 6 * scale, s_dim - 6 * scale, s_dim - 12 * scale], 8 * scale, fill=(35, 115, 65, 255), outline=(140, 255, 180, 255), width=2 * scale)
    im_s.resize((dim, dim), Image.Resampling.LANCZOS).save(os.path.join(output_dir, "tile_safe.png"))

    # C) Tile Hazard (Alerta roja parpadeante)
    im_h = Image.new("RGBA", (s_dim, s_dim), (0, 0, 0, 0))
    dh = ImageDraw.Draw(im_h)
    draw_rounded_rect(dh, [2 * scale, 2 * scale, s_dim - 2 * scale, s_dim - 2 * scale], 10 * scale, fill=(75, 20, 25, 255), outline=(255, 45, 65, 255), width=4 * scale)
    draw_rounded_rect(dh, [6 * scale, 6 * scale, s_dim - 6 * scale, s_dim - 12 * scale], 8 * scale, fill=(125, 30, 40, 255), outline=(255, 120, 135, 255), width=2 * scale)
    im_h.resize((dim, dim), Image.Resampling.LANCZOS).save(os.path.join(output_dir, "tile_hazard.png"))

    print("Saved platform tiles!")

# =========================================================================
# 5. PREVIEW CARD FOR LOBBY (preview_plataformas.png)
# =========================================================================
def generate_preview_card():
    w, h = 180, 110
    im = Image.new("RGBA", (w, h), (25, 20, 45, 255))
    draw = ImageDraw.Draw(im)
    
    # Mini jumbotron arriba
    draw_rounded_rect(draw, [45, 8, 135, 38], 6, fill=(10, 15, 25), outline=(0, 210, 255), width=2)
    draw.text((90, 23), "⭐", font=get_font("arialbd.ttf", 16), fill=(255, 220, 50), anchor="mm")
    
    # Mini cuadrícula de plataformas con iconos
    symbols = ["🥕", "⭐", "🍀", "🧲", "👑", "⭐"]
    font_ico = get_font("arialbd.ttf", 10)
    for row in range(2):
        for col in range(4):
            x = 35 + col * 28
            y = 52 + row * 26
            is_safe = (col == 1 or col == 3)
            bg_col = (30, 95, 55) if is_safe else (40, 48, 75)
            out_col = (60, 240, 120) if is_safe else (70, 90, 140)
            draw_rounded_rect(draw, [x, y, x + 24, y + 22], 4, fill=bg_col, outline=out_col, width=1)
            sym = symbols[(row * 4 + col) % len(symbols)]
            draw.text((x + 12, y + 11), sym, font=font_ico, fill=(255, 255, 255), anchor="mm")
            
    im.save(os.path.join(preview_dir, "preview_plataformas.png"))
    print("Saved preview_plataformas.png")

if __name__ == "__main__":
    generate_bg_estadio()
    generate_pantalla_jumbotron()
    generate_symbols()
    generate_platform_tiles()
    generate_preview_card()
    print("ALL PLATAFORMAS ASSETS GENERATED!")
