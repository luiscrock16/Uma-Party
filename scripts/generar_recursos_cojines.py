import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

out_dir = r"E:\PROYECTOS GODOT\Umamusume party\uma-party\assets\minijuegos\cojines"
os.makedirs(out_dir, exist_ok=True)

# ------------------------------------------------------------------------------
# 1. FONDO DORMITORIO TRACEN (1152 x 648)
# ------------------------------------------------------------------------------
def crear_fondo_dormitorio():
    W, H = 1152, 648
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # A. PARED SUPERIOR (Y: 0 a 195)
    # Tono cálido beige/crema clásico de los dormitorios de Tracen
    color_pared_top = (238, 230, 212)
    color_pared_bot = (226, 216, 196)
    for y in range(0, 195):
        t = y / 195.0
        r = int(color_pared_top[0] * (1 - t) + color_pared_bot[0] * t)
        g = int(color_pared_top[1] * (1 - t) + color_pared_bot[1] * t)
        b = int(color_pared_top[2] * (1 - t) + color_pared_bot[2] * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b, 255))

    # Moldura superior de techo y zócalo de madera
    draw.rectangle([0, 0, W, 10], fill=(120, 80, 45, 255)) # Cornisa de techo
    draw.rectangle([0, 185, W, 195], fill=(138, 92, 54, 255)) # Zócalo de madera
    draw.line([(0, 185), (W, 185)], fill=(90, 55, 30, 255), width=2)
    draw.line([(0, 195), (W, 195)], fill=(75, 45, 25, 255), width=2)

    # B. SUELO DE PARQUÉ / MADERA (Y: 195 a 648)
    color_madera_base = (196, 154, 112)
    color_madera_linea = (160, 120, 82)
    draw.rectangle([0, 195, W, H], fill=color_madera_base)

    # Listones horizontales de madera
    alto_liston = 28
    for i, y in enumerate(range(195, H, alto_liston)):
        # Variación sutil de color por tabla
        variacion = (i % 3) * 6 - 6
        c_tab = (
            max(0, min(255, color_madera_base[0] + variacion)),
            max(0, min(255, color_madera_base[1] + variacion)),
            max(0, min(255, color_madera_base[2] + variacion)),
            255
        )
        draw.rectangle([0, y, W, min(H, y + alto_liston)], fill=c_tab)
        draw.line([(0, y), (W, y)], fill=color_madera_linea, width=2)
        
        # Juntas verticales escalonadas de listones
        offset_junta = (i * 180) % 240
        for x in range(offset_junta, W, 240):
            draw.line([(x, y), (x, min(H, y + alto_liston))], fill=color_madera_linea, width=1)

    # C. PUERTA DEL DORMITORIO (X: 430 a 550, Y: 20 a 195)
    puerta_x1, puerta_x2 = 440, 545
    draw.rectangle([puerta_x1 - 6, 20, puerta_x2 + 6, 195], fill=(105, 68, 38, 255)) # Marco
    draw.rectangle([puerta_x1, 26, puerta_x2, 195], fill=(168, 114, 68, 255)) # Puerta
    draw.rectangle([puerta_x1 + 10, 36, puerta_x2 - 10, 80], fill=(145, 96, 54, 255)) # Panel superior
    draw.rectangle([puerta_x1 + 10, 95, puerta_x2 - 10, 185], fill=(145, 96, 54, 255)) # Panel inferior
    # Pomo de puerta plateado
    draw.ellipse([puerta_x1 + 14, 118, puerta_x1 + 24, 128], fill=(220, 225, 235, 255))
    draw.ellipse([puerta_x1 + 16, 120, puerta_x1 + 22, 126], fill=(255, 255, 255, 255))

    # D. HILERA DE FAROLILLOS JAPONESES (CHOCHIN) - Estilo habitación Kitasan Black
    # Colgados a lo largo de la pared superior (Y: 25 a 70)
    faroles_xs = [200, 235, 270, 305, 340, 375, 410, 575, 610, 645, 680, 715, 750, 785]
    # Cable guirnalda
    puntos_cable_izq = [(180, 35)] + [(x, 35 + int(math.sin((x-180)/240.0 * math.pi) * 8)) for x in range(190, 420, 10)]
    for k in range(len(puntos_cable_izq)-1):
        draw.line([puntos_cable_izq[k], puntos_cable_izq[k+1]], fill=(60, 40, 30, 255), width=2)
    puntos_cable_der = [(560, 35)] + [(x, 35 + int(math.sin((x-560)/240.0 * math.pi) * 8)) for x in range(570, 800, 10)]
    for k in range(len(puntos_cable_der)-1):
        draw.line([puntos_cable_der[k], puntos_cable_der[k+1]], fill=(60, 40, 30, 255), width=2)

    for i, fx in enumerate(faroles_xs):
        fy = 36 + (i % 2) * 4
        # Farolillo ovalado rojo y dorado
        es_rojo = (i % 2 == 0)
        c_farol = (210, 48, 48, 255) if es_rojo else (235, 175, 45, 255)
        c_banda = (245, 215, 120, 255) if es_rojo else (190, 35, 35, 255)
        # Tapa superior e inferior negra
        draw.rectangle([fx - 8, fy, fx + 8, fy + 4], fill=(40, 35, 35, 255))
        draw.rectangle([fx - 8, fy + 24, fx + 8, fy + 28], fill=(40, 35, 35, 255))
        # Cuerpo
        draw.ellipse([fx - 13, fy + 3, fx + 13, fy + 25], fill=c_farol)
        # Franja central decorativa
        draw.rectangle([fx - 12, fy + 10, fx + 12, fy + 17], fill=c_banda)
        # Fleco dorado
        draw.line([(fx, fy + 28), (fx, fy + 34)], fill=(220, 190, 80, 255), width=2)

    # E. PÓSTER DE TOKAI TEIO CON MARCO DORADO (X: 810 a 890, Y: 40 a 140)
    px1, py1, px2, py2 = 815, 42, 895, 145
    draw.rectangle([px1 - 4, py1 - 4, px2 + 4, py2 + 4], fill=(215, 180, 60, 255)) # Marco dorado
    draw.rectangle([px1, py1, px2, py2], fill=(245, 240, 250, 255)) # Papel póster
    # Silueta chibi Teio en el póster (capa marrón/pelo castaño, mecha blanca, capa morada)
    draw.ellipse([px1 + 25, py1 + 20, px2 - 25, py1 + 65], fill=(120, 75, 45, 255)) # Pelo Teio
    draw.ellipse([px1 + 33, py1 + 22, px1 + 47, py1 + 45], fill=(255, 255, 255, 255)) # Mecha blanca Teio
    draw.ellipse([px1 + 28, py1 + 32, px2 - 28, py1 + 62], fill=(255, 220, 195, 255)) # Cara
    draw.rectangle([px1 + 26, py1 + 62, px2 - 26, py1 + 95], fill=(70, 75, 150, 255)) # Chaqueta Tracen
    # Lazo rojo en la esquina del póster
    draw.polygon([(px1 - 6, py1 - 6), (px1 + 6, py1 - 2), (px1 - 2, py1 + 6)], fill=(225, 45, 45, 255))
    draw.polygon([(px2 + 6, py1 - 6), (px2 - 6, py1 - 2), (px2 + 2, py1 + 6)], fill=(225, 45, 45, 255))

    # F. ABANICO UCHIWA EN LA PARED (X: 915, Y: 70)
    ux, uy = 935, 90
    draw.ellipse([ux - 22, uy - 22, ux + 22, uy + 22], fill=(220, 50, 50, 255))
    draw.ellipse([ux - 17, uy - 17, ux + 17, uy + 17], fill=(245, 235, 220, 255))
    draw.rectangle([ux - 10, uy - 5, ux + 10, uy + 5], fill=(210, 45, 45, 255)) # Letra kanji decorativa
    draw.line([(ux, uy + 20), (ux, uy + 42)], fill=(180, 140, 90, 255), width=3) # Mango de madera

    # G. ARMARIO ALTO DE MADERA A LA IZQUIERDA (X: 10 a 130, Y: 60 a 340)
    draw.rectangle([15, 60, 130, 340], fill=(140, 92, 54, 255))
    draw.rectangle([20, 65, 125, 335], fill=(160, 108, 64, 255))
    draw.line([(72, 65), (72, 335)], fill=(110, 70, 40, 255), width=2) # Puertas dobles
    draw.rectangle([25, 75, 68, 190], fill=(145, 96, 56, 255)) # Panel puerta izq
    draw.rectangle([76, 75, 120, 190], fill=(145, 96, 56, 255)) # Panel puerta der
    draw.rectangle([25, 205, 68, 320], fill=(145, 96, 56, 255))
    draw.rectangle([76, 205, 120, 320], fill=(145, 96, 56, 255))
    # Tiradores
    draw.rectangle([64, 185, 68, 205], fill=(215, 185, 80, 255))
    draw.rectangle([76, 185, 80, 205], fill=(215, 185, 80, 255))

    # H. ESTANTERÍA CON LIBROS Y DARUMAS (X: 140 a 270, Y: 80 a 280)
    draw.rectangle([145, 80, 275, 280], fill=(150, 100, 60, 255))
    # Balda 1 (Y: 135)
    draw.rectangle([148, 85, 272, 135], fill=(175, 122, 75, 255))
    # Muñecos Daruma rojos de la suerte en la balda 1
    for dx in [170, 205, 245]:
        draw.ellipse([dx - 14, 96, dx + 14, 132], fill=(215, 40, 40, 255)) # Cuerpo daruma
        draw.ellipse([dx - 10, 100, dx + 10, 120], fill=(255, 240, 225, 255)) # Cara blanca
        draw.ellipse([dx - 6, 105, dx - 2, 111], fill=(20, 20, 20, 255)) # Ojo izq
        draw.ellipse([dx + 2, 105, dx + 6, 111], fill=(20, 20, 20, 255)) # Ojo der
        draw.line([(dx - 7, 102), (dx - 1, 104)], fill=(20, 20, 20, 255), width=2) # Ceja
        draw.line([(dx + 7, 102), (dx + 1, 104)], fill=(20, 20, 20, 255), width=2)
        draw.rectangle([dx - 5, 124, dx + 5, 130], fill=(235, 195, 60, 255)) # Letra dorada fortuna
    draw.rectangle([145, 135, 275, 143], fill=(125, 80, 46, 255)) # Repisa de madera

    # Balda 2 (Y: 200) - Libros y Archivadores de Tracen
    draw.rectangle([148, 143, 272, 200], fill=(175, 122, 75, 255))
    colores_libros = [
        (65, 105, 225), (220, 60, 80), (60, 160, 90), (230, 180, 40),
        (140, 70, 180), (65, 105, 225), (240, 130, 50), (45, 140, 140)
    ]
    lx = 154
    for c_lib in colores_libros:
        ancho = 13
        draw.rectangle([lx, 150, lx + ancho - 2, 198], fill=c_lib)
        draw.line([(lx + 2, 160), (lx + ancho - 4, 160)], fill=(255, 255, 255, 180), width=1)
        lx += ancho
    draw.rectangle([145, 200, 275, 208], fill=(125, 80, 46, 255))

    # Balda 3 (Y: 270) - Cajoneras
    draw.rectangle([148, 208, 272, 275], fill=(160, 110, 68, 255))
    draw.rectangle([155, 218, 265, 240], fill=(180, 128, 82, 255))
    draw.rectangle([155, 246, 265, 268], fill=(180, 128, 82, 255))
    draw.ellipse([205, 226, 215, 232], fill=(225, 190, 80, 255))
    draw.ellipse([205, 254, 215, 260], fill=(225, 190, 80, 255))

    # I. ESCRITORIO DERECHO Y TELEVISIÓN (X: 990 a 1130, Y: 130 a 300)
    draw.rectangle([1000, 130, 1135, 280], fill=(155, 105, 65, 255))
    # Televisor
    draw.rectangle([1020, 145, 1115, 210], fill=(45, 45, 52, 255)) # Carcasa TV
    draw.rectangle([1025, 150, 1110, 203], fill=(80, 95, 110, 255)) # Pantalla
    # Brillo diagonal pantalla TV
    draw.polygon([(1030, 150), (1055, 150), (1035, 203), (1025, 203)], fill=(120, 140, 165, 200))
    draw.rectangle([1058, 210, 1078, 222], fill=(40, 40, 45, 255)) # Soporte TV
    draw.rectangle([1045, 222, 1090, 228], fill=(30, 30, 35, 255))
    # Hueco estante bajo TV con consola
    draw.rectangle([1015, 235, 1120, 270], fill=(125, 80, 48, 255))
    draw.rectangle([1025, 245, 1085, 262], fill=(35, 38, 44, 255)) # Reproductor consola
    draw.ellipse([1075, 252, 1079, 256], fill=(60, 220, 90, 255)) # Luz verde encendido

    # J. CAMA DE DORMITORIO IZQUIERDA (X: 15 a 160, Y: 360 a 580)
    # Cabecero de barrotes blancos
    draw.rectangle([15, 360, 25, 560], fill=(235, 240, 245, 255)) # Poste vertical izq
    draw.rectangle([150, 360, 160, 560], fill=(235, 240, 245, 255)) # Poste vertical der
    draw.rectangle([15, 360, 160, 372], fill=(235, 240, 245, 255)) # Barra horizontal
    for bx in range(35, 150, 18):
        draw.line([(bx, 372), (bx, 420)], fill=(210, 215, 225, 255), width=3)
    # Colchón y sábana rosa pastel suave (estilo Dober)
    draw.rectangle([25, 410, 150, 550], fill=(255, 228, 238, 255))
    # Edredón doblado rosa
    draw.rectangle([25, 460, 150, 550], fill=(245, 180, 205, 255))
    draw.line([(25, 460), (150, 460)], fill=(225, 150, 180, 255), width=3)
    # Almohada mullida en la cabecera
    draw.ellipse([45, 416, 130, 448], fill=(255, 252, 250, 255))
    draw.ellipse([48, 419, 127, 445], fill=(250, 242, 246, 255))

    # K. CAMA DE DORMITORIO DERECHA (X: 990 a 1135, Y: 360 a 580)
    # Cabecero barrotes blancos
    draw.rectangle([990, 360, 1000, 560], fill=(235, 240, 245, 255))
    draw.rectangle([1125, 360, 1135, 560], fill=(235, 240, 245, 255))
    draw.rectangle([990, 360, 1135, 372], fill=(235, 240, 245, 255))
    for bx in range(1010, 1125, 18):
        draw.line([(bx, 372), (bx, 420)], fill=(210, 215, 225, 255), width=3)
    # Colchón y sábana celeste suave (estilo Satono Diamond)
    draw.rectangle([1000, 410, 1125, 550], fill=(230, 242, 255, 255))
    # Edredón celeste pastel
    draw.rectangle([1000, 460, 1125, 550], fill=(160, 205, 245, 255))
    draw.line([(1000, 460), (1125, 460)], fill=(130, 175, 220, 255), width=3)
    # Almohada mullida
    draw.ellipse([1020, 416, 1105, 448], fill=(255, 252, 250, 255))

    # L. PERCHERO CON CHÁNDAL ROJO DE TRACEN (X: 955, Y: 290 a 430)
    px, py = 965, 300
    draw.line([(px, py), (px, py + 120)], fill=(120, 80, 50, 255), width=5) # Palo perchero
    draw.line([(px - 22, py + 120), (px + 22, py + 120)], fill=(100, 65, 40, 255), width=4) # Base
    # Chaqueta deportiva roja de Tracen colgada
    draw.polygon([(px - 18, py + 20), (px + 18, py + 20), (px + 22, py + 75), (px - 22, py + 75)], fill=(205, 45, 55, 255))
    # Franjas blancas del uniforme Tracen
    draw.line([(px - 14, py + 20), (px - 17, py + 75)], fill=(255, 255, 255, 255), width=3)
    draw.line([(px + 14, py + 20), (px + 17, py + 75)], fill=(255, 255, 255, 255), width=3)
    draw.line([(px, py + 20), (px, py + 75)], fill=(255, 255, 255, 255), width=2) # Cremallera blanca

    # M. SOMBREADO SUAVE PERIMETRAL
    # Viñeta suave en los bordes para centrar el foco en la arena
    vignette = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    vdraw.rectangle([0, 0, W, H], fill=(0, 0, 0, 0))
    # Sombra en los laterales
    for x in range(0, 100):
        alpha = int((1.0 - (x / 100.0)) * 55)
        vdraw.line([(x, 0), (x, H)], fill=(20, 10, 15, alpha))
        vdraw.line([(W - 1 - x, 0), (W - 1 - x, H)], fill=(20, 10, 15, alpha))

    img = Image.alpha_composite(img, vignette)
    img.save(os.path.join(out_dir, "fondo_dormitorio_tracen.png"))
    print("fondo_dormitorio_tracen.png creado con éxito.")

# ------------------------------------------------------------------------------
# 2. ALMOHADA DE TRACEN (64 x 64)
# ------------------------------------------------------------------------------
def crear_almohada_tracen():
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 32, 32
    w, h = 24, 18

    # Sombra suave exterior
    draw.ellipse([cx - w - 2, cy - h - 1, cx + w + 2, cy + h + 3], fill=(0, 0, 0, 45))

    # Borde de ribete pastel (costura)
    c_ribete = (240, 165, 185, 255) # Rosa pastel Tracen
    draw.rounded_rectangle([cx - w, cy - h, cx + w, cy + h], radius=10, fill=c_ribete)

    # Cuerpo esponjoso de la almohada
    c_base = (255, 250, 245, 255)
    draw.rounded_rectangle([cx - w + 2, cy - h + 2, cx + w - 2, cy + h - 2], radius=8, fill=c_base)

    # Pliegues de volumen esponjoso (sombreado)
    c_sombra = (235, 225, 230, 255)
    draw.arc([cx - w + 4, cy - h + 4, cx + w - 4, cy + h - 4], start=0, end=180, fill=c_sombra, width=3)
    
    # Pliegues y botón/hendidura central
    draw.ellipse([cx - 4, cy - 3, cx + 4, cy + 3], fill=(225, 210, 218, 255))
    draw.line([(cx - 9, cy), (cx + 9, cy)], fill=(225, 210, 218, 255), width=2)
    draw.line([(cx, cy - 7), (cx, cy + 7)], fill=(225, 210, 218, 255), width=2)

    # Borlas / puntas en las 4 esquinas
    esquinas = [
        (cx - w + 2, cy - h + 2), (cx + w - 2, cy - h + 2),
        (cx - w + 2, cy + h - 2), (cx + w - 2, cy + h - 2)
    ]
    for ex, ey in esquinas:
        draw.ellipse([ex - 3, ey - 3, ex + 3, ey + 3], fill=(255, 200, 215, 255))
        draw.ellipse([ex - 1, ey - 1, ex + 1, ey + 1], fill=(255, 255, 255, 255))

    # Brillo suave superior
    draw.ellipse([cx - 14, cy - 11, cx + 14, cy - 5], fill=(255, 255, 255, 160))

    img.save(os.path.join(out_dir, "almohada_tracen.png"))
    print("almohada_tracen.png creado con éxito.")

# ------------------------------------------------------------------------------
# 3. SWOOSH DE BARRIDO DE ESPADA / GOLPE DE COJÍN (128 x 128)
# ------------------------------------------------------------------------------
def crear_swoosh_golpe():
    size = 128
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 64, 64
    r_ext = 56
    r_int = 40

    # Arco semicircular dinámico con estela de viento
    # Dibuja segmentos de arco decrecientes simulando el barrido de una espada
    for a in range(-60, 75, 2):
        rad = math.radians(a)
        prog = (a + 60) / 135.0 # 0.0 al inicio, 1.0 en la punta del corte
        ancho = 3 + prog * 11
        alpha = int(prog * 240)
        
        x1 = cx + math.cos(rad) * (r_ext - ancho)
        y1 = cy + math.sin(rad) * (r_ext - ancho)
        x2 = cx + math.cos(rad) * r_ext
        y2 = cy + math.sin(rad) * r_ext
        
        draw.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, alpha), width=3)
        # Borde exterior con brillo celeste suave
        draw.point((x2, y2), fill=(180, 225, 255, alpha))

    # Punta afilada del corte
    rad_end = math.radians(75)
    px = cx + math.cos(rad_end) * r_ext
    py = cy + math.sin(rad_end) * r_ext
    draw.polygon([(px - 4, py - 4), (px + 6, py + 6), (px - 2, py + 4)], fill=(255, 255, 255, 255))

    # Plumas sueltas desprendidas en el corte
    plumas = [
        (cx + 25, cy - 35, 12), (cx + 45, cy - 15, 14), (cx + 50, cy + 20, 10),
        (cx + 30, cy + 45, 8)
    ]
    for plx, ply, pl_len in plumas:
        draw.ellipse([plx - 3, ply - 6, plx + 3, ply + 6], fill=(255, 255, 255, 220))
        draw.line([(plx, ply - 7), (plx, ply + 7)], fill=(240, 240, 250, 255), width=1)

    img.save(os.path.join(out_dir, "swoosh_golpe_cojin.png"))
    print("swoosh_golpe_cojin.png creado con éxito.")

# ------------------------------------------------------------------------------
# 4. TATAMI RING BASE (Gran Alfombra Acolchada Central 600 x 600)
# ------------------------------------------------------------------------------
def crear_tatami_ring():
    size = 600
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 300, 300
    R = 275

    # Sombra proyectada en el parqué
    draw.ellipse([cx - R - 6, cy - R + 8, cx + R + 6, cy + R + 18], fill=(0, 0, 0, 55))

    # Borde exterior acolchado grueso (Cojín perimetral / Ribete verde oscuro y dorado)
    c_borde_ext = (45, 85, 55, 255) # Verde tradicional tatami
    c_borde_dorado = (215, 180, 75, 255) # Hilos dorados
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], fill=c_borde_ext)
    draw.ellipse([cx - R + 6, cy - R + 6, cx + R - 6, cy + R - 6], fill=c_borde_dorado)
    draw.ellipse([cx - R + 14, cy - R + 14, cx + R - 14, cy + R - 14], fill=c_borde_ext)

    # Patrón de pequeños rombos o motivos florales dorados en el borde
    for deg in range(0, 360, 10):
        rad = math.radians(deg)
        bx = cx + math.cos(rad) * (R - 10)
        by = cy + math.sin(rad) * (R - 10)
        draw.rectangle([bx - 2, by - 2, bx + 2, by + 2], fill=(245, 225, 130, 255))

    # Superficie acolchada central (Paja de tatami tejida cálida)
    c_tatami_base = (236, 224, 188, 255) # Tono pajizo suave
    c_linea_tejido = (220, 206, 168, 255)
    draw.ellipse([cx - R + 22, cy - R + 22, cx + R - 22, cy + R - 22], fill=c_tatami_base)

    # Tejido de estera de tatami (Líneas horizontales finas con textura)
    tatami_inner = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    tdraw = ImageDraw.Draw(tatami_inner)
    for y in range(cy - R + 22, cy + R - 22, 6):
        tdraw.line([(cx - R + 22, y), (cx + R - 22, y)], fill=c_linea_tejido, width=2)
    # Cosido en cruz suave en el centro
    tdraw.line([(cx - 120, cy), (cx + 120, cy)], fill=(185, 168, 132, 160), width=3)
    tdraw.line([(cx, cy - 120), (cx, cy + 120)], fill=(185, 168, 132, 160), width=3)

    # Máscara circular para el tejido interior
    mask = Image.new("L", (size, size), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.ellipse([cx - R + 22, cy - R + 22, cx + R - 22, cy + R - 22], fill=255)
    img.paste(tatami_inner, (0, 0), mask)

    # Círculo central decorativo de Tracen (Flor de cerezo / Herradura)
    draw.ellipse([cx - 48, cy - 48, cx + 48, cy + 48], fill=(225, 212, 175, 255))
    draw.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], fill=c_tatami_base)
    # Herradura dorada estilizada de Tracen en el centro
    draw.arc([cx - 24, cy - 24, cx + 24, cy + 24], start=40, end=320, fill=(195, 155, 60, 255), width=6)

    img.save(os.path.join(out_dir, "tatami_ring_base.png"))
    print("tatami_ring_base.png creado con éxito.")

# ------------------------------------------------------------------------------
# 5. RETÍCULA DE ADVERTENCIA DE REDUCCIÓN DE ESPACIO (600 x 600)
# ------------------------------------------------------------------------------
def crear_ring_alerta():
    size = 600
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 300, 300
    R = 275

    # Franjas diagonales de peligro amarillo/negro/rojo animadas en el perímetro
    c_amarillo = (255, 210, 0, 220)
    c_rojo = (235, 40, 40, 240)
    
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], outline=c_rojo, width=8)
    draw.ellipse([cx - R + 14, cy - R + 14, cx + R - 14, cy + R - 14], outline=c_amarillo, width=4)

    # Dientes/marcas de peligro apuntando hacia adentro
    for deg in range(0, 360, 15):
        rad = math.radians(deg)
        x_out = cx + math.cos(rad) * R
        y_out = cy + math.sin(rad) * R
        x_in = cx + math.cos(rad) * (R - 22)
        y_in = cy + math.sin(rad) * (R - 22)
        draw.line([(x_out, y_out), (x_in, y_in)], fill=c_rojo, width=4)

    img.save(os.path.join(out_dir, "tatami_ring_alerta.png"))
    print("tatami_ring_alerta.png creado con éxito.")

if __name__ == "__main__":
    crear_fondo_dormitorio()
    crear_almohada_tracen()
    crear_swoosh_golpe()
    crear_tatami_ring()
    crear_ring_alerta()
    print("--- RECURSOS DE COJINES GENERADOS CORRECTAMENTE ---")
