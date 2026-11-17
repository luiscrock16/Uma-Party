import os
import math
from PIL import Image, ImageDraw, ImageFilter

out_dir = r"E:\PROYECTOS GODOT\Umamusume party\uma-party\assets\minijuegos\martillo"
os.makedirs(out_dir, exist_ok=True)

# ------------------------------------------------------------------------------
# 1. FONDO PUESTO DE FERIA JAPONESA (1152 x 648)
# ------------------------------------------------------------------------------
def crear_fondo_feria():
    W, H = 1152, 648
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # A. CIELO CREPUSCULAR DE FESTIVAL (Y: 0 a 160)
    for y in range(0, 160):
        t = y / 160.0
        r = int(50 * (1 - t) + 120 * t)
        g = int(35 * (1 - t) + 80 * t)
        b = int(75 * (1 - t) + 130 * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b, 255))

    # B. ARBOLEDA DE FONDO DE TRACEN (Y: 80 a 180)
    for x in range(0, W, 45):
        rad = 40 + (x % 3) * 12
        cy = 135 + (x % 2) * 10
        draw.ellipse([x - rad, cy - rad, x + rad, cy + rad], fill=(35, 75, 45, 255))
        draw.ellipse([x - rad + 4, cy - rad + 4, x + rad - 4, cy + rad - 4], fill=(45, 95, 55, 255))

    # C. ESTRUCTURA DEL PUESTO DE FERIA (TOLDO RAYAS ROJAS Y BLANCAS Y: 0 a 105)
    ancho_franja = 48
    num_franjas = int(W / ancho_franja) + 2
    for i in range(num_franjas):
        fx1 = i * ancho_franja
        fx2 = fx1 + ancho_franja
        es_rojo = (i % 2 == 0)
        c_toldo = (215, 45, 45, 255) if es_rojo else (250, 245, 235, 255)
        # Toldo en caída ondeada
        draw.rectangle([fx1, 0, fx2, 90], fill=c_toldo)
        # Festón semicircular en el borde inferior
        draw.pieslice([fx1, 65, fx2, 115], start=0, end=180, fill=c_toldo)
    # Borde dorado del toldo
    draw.line([(0, 90), (W, 90)], fill=(225, 190, 60, 255), width=3)

    # D. FAROLILLOS DE FESTIVAL LATERALES (CHOCHIN)
    faroles = [(90, 75), (145, 95), (1007, 95), (1062, 75)]
    for fx, fy in faroles:
        # Cable
        draw.line([(fx, 0), (fx, fy)], fill=(40, 30, 25, 255), width=2)
        # Farolillo rojo
        draw.rectangle([fx - 12, fy, fx + 12, fy + 4], fill=(30, 30, 30, 255))
        draw.ellipse([fx - 16, fy + 2, fx + 16, fy + 32], fill=(225, 40, 40, 255))
        draw.rectangle([fx - 15, fy + 12, fx + 15, fy + 22], fill=(255, 215, 110, 255))
        draw.rectangle([fx - 12, fy + 30, fx + 12, fy + 34], fill=(30, 30, 30, 255))
        draw.line([(fx, fy + 34), (fx, fy + 42)], fill=(220, 180, 60, 255), width=2)

    # E. SUELO DEL PUESTO DE FESTIVAL (Y: 160 a 648)
    # Madera cálida de festival
    c_suelo_feria = (180, 135, 95)
    draw.rectangle([0, 160, W, H], fill=c_suelo_feria)
    for y in range(160, H, 32):
        draw.line([(0, y), (W, y)], fill=(145, 105, 70, 255), width=2)

    # F. MESA / TABLERO CENTRAL DE GOLPEAR TOPOS (X: 190 a 962, Y: 180 a 610)
    tx1, ty1, tx2, ty2 = 200, 185, 952, 615
    # Sombra del mueble
    draw.rounded_rectangle([tx1 - 8, ty1 + 10, tx2 + 8, ty2 + 16], radius=24, fill=(50, 30, 20, 100))
    # Marco de madera noble de la máquina
    draw.rounded_rectangle([tx1, ty1, tx2, ty2], radius=24, fill=(135, 82, 45, 255))
    # Moldura dorada exterior
    draw.rounded_rectangle([tx1 + 6, ty1 + 6, tx2 - 6, ty2 - 6], radius=20, outline=(225, 185, 65, 255), width=4)
    # Superficie interior de césped/tapete de festival (verde suave)
    draw.rounded_rectangle([tx1 + 16, ty1 + 16, tx2 - 16, ty2 - 16], radius=16, fill=(85, 145, 85, 255))
    # Textura sutil de cuadrícula de césped
    for gy in range(ty1 + 25, ty2 - 20, 28):
        draw.line([(tx1 + 20, gy), (tx2 - 20, gy)], fill=(75, 130, 75, 160), width=1)

    # G. CARTEL DEL JUEGO EN LA PARTE SUPERIOR DEL MUEBLE
    cx1, cy1, cx2, cy2 = 410, 195, 742, 235
    draw.rounded_rectangle([cx1, cy1, cx2, cy2], radius=10, fill=(215, 45, 45, 255))
    draw.rounded_rectangle([cx1 + 3, cy1 + 3, cx2 - 3, cy2 - 3], radius=8, outline=(245, 215, 90, 255), width=2)
    # Detalles festivos en el cartel
    draw.ellipse([cx1 + 12, cy1 + 12, cx1 + 28, cy1 + 28], fill=(255, 220, 100, 255))
    draw.ellipse([cx2 - 28, cy1 + 12, cx2 - 12, cy1 + 28], fill=(255, 220, 100, 255))
    # Herradura dorada decorativa de Tracen en el cartel
    draw.arc([566, cy1 + 8, 586, cy1 + 28], start=45, end=315, fill=(255, 230, 120, 255), width=4)

    img.save(os.path.join(out_dir, "fondo_puesto_feria.png"))
    print("fondo_puesto_feria.png creado con éxito.")

# ------------------------------------------------------------------------------
# 2. HOYO DE TOPO ACTIVO (130 x 110)
# ------------------------------------------------------------------------------
def crear_hoyo_activo():
    W, H = 130, 110
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 65, 55
    rx, ry = 58, 42

    # Sombra exterior en el césped
    draw.ellipse([cx - rx - 4, cy - ry + 4, cx + rx + 4, cy + ry + 12], fill=(0, 0, 0, 60))

    # Borde de goma/madera del orificio
    c_reborde = (165, 110, 65, 255)
    c_reborde_luz = (195, 135, 85, 255)
    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=c_reborde)
    draw.ellipse([cx - rx + 3, cy - ry + 2, cx + rx - 3, cy + ry - 4], fill=c_reborde_luz)

    # Interior profundo del hoyo (Sombreado 2.5D hacia abajo)
    draw.ellipse([cx - rx + 8, cy - ry + 6, cx + rx - 8, cy + ry - 6], fill=(35, 22, 16, 255))
    draw.ellipse([cx - rx + 14, cy - ry + 12, cx + rx - 14, cy + ry - 8], fill=(18, 10, 8, 255))

    # Pequeños remaches dorados alrededor del orificio
    for deg in range(0, 360, 45):
        rad = math.radians(deg)
        mx = cx + math.cos(rad) * (rx - 4)
        my = cy + math.sin(rad) * (ry - 4)
        draw.ellipse([mx - 2, my - 2, mx + 2, my + 2], fill=(235, 195, 75, 255))

    img.save(os.path.join(out_dir, "hoyo_topo_activo.png"))
    print("hoyo_topo_activo.png creado con éxito.")

# ------------------------------------------------------------------------------
# 3. HOYO DE TOPO CLAUSURADO / BLOQUEADO (130 x 110)
# ------------------------------------------------------------------------------
def crear_hoyo_bloqueado():
    W, H = 130, 110
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 65, 55
    rx, ry = 58, 42

    # Sombra exterior
    draw.ellipse([cx - rx - 4, cy - ry + 4, cx + rx + 4, cy + ry + 10], fill=(0, 0, 0, 75))

    # Tapa de madera sellada con tablones
    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(120, 80, 50, 255))
    draw.ellipse([cx - rx + 4, cy - ry + 3, cx + rx - 4, cy + ry - 3], fill=(145, 98, 62, 255))

    # Líneas de tablones de madera
    draw.line([(cx - rx + 10, cy - 14), (cx + rx - 10, cy - 14)], fill=(95, 60, 35, 255), width=3)
    draw.line([(cx - rx + 6, cy + 12), (cx + rx - 6, cy + 12)], fill=(95, 60, 35, 255), width=3)

    # Gran 'X' roja de peligro / clausura
    c_cruz = (225, 35, 35, 255)
    c_cruz_borde = (140, 15, 15, 255)
    draw.line([(cx - 28, cy - 20), (cx + 28, cy + 20)], fill=c_cruz_borde, width=12)
    draw.line([(cx + 28, cy - 20), (cx - 28, cy + 20)], fill=c_cruz_borde, width=12)
    draw.line([(cx - 28, cy - 20), (cx + 28, cy + 20)], fill=c_cruz, width=8)
    draw.line([(cx + 28, cy - 20), (cx - 28, cy + 20)], fill=c_cruz, width=8)

    # Remaches metálicos en las 4 esquinas de la cruz
    for px, py in [(cx - 30, cy - 22), (cx + 30, cy - 22), (cx - 30, cy + 22), (cx + 30, cy + 22)]:
        draw.ellipse([px - 3, py - 3, px + 3, py + 3], fill=(70, 70, 75, 255))
        draw.ellipse([px - 1, py - 1, px + 1, py + 1], fill=(190, 190, 200, 255))

    img.save(os.path.join(out_dir, "hoyo_topo_bloqueado.png"))
    print("hoyo_topo_bloqueado.png creado con éxito.")

# ------------------------------------------------------------------------------
# 4. MARTILLO GIGANTE DE FERIA (180 x 220)
# ------------------------------------------------------------------------------
def crear_martillo_gigante():
    W, H = 180, 220
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 90, 140

    # MANGO LARGO DE MADERA (X: 82 a 98, Y: 10 a 140)
    draw.rectangle([82, 10, 98, 140], fill=(155, 105, 65, 255))
    draw.rectangle([85, 10, 95, 140], fill=(185, 130, 85, 255))
    # Envoltura de cinta roja en el agarre del mango
    for y in range(25, 95, 14):
        draw.polygon([(82, y), (98, y + 8), (98, y + 14), (82, y + 6)], fill=(215, 45, 45, 255))
    # Pomo superior dorado del mango
    draw.ellipse([80, 6, 100, 18], fill=(235, 195, 65, 255))

    # CABEZA GIGANTE CILÍNDRICA DEL MARTILLO (X: 20 a 160, Y: 125 a 210)
    x1, y1, x2, y2 = 25, 125, 155, 210
    # Sombra del martillo
    draw.rounded_rectangle([x1, y1 + 4, x2, y2 + 6], radius=16, fill=(110, 70, 40, 255))
    # Cuerpo de madera noble
    draw.rounded_rectangle([x1, y1, x2, y2], radius=16, fill=(150, 95, 55, 255))
    draw.rounded_rectangle([x1 + 6, y1 + 6, x2 - 6, y2 - 6], radius=12, fill=(175, 115, 70, 255))

    # Bandas metálicas doradas reforzadas en los extremos
    draw.rectangle([x1 + 8, y1, x1 + 24, y2], fill=(235, 190, 60, 255))
    draw.rectangle([x2 - 24, y1, x2 - 8, y2], fill=(235, 190, 60, 255))
    # Remaches en las bandas metálicas
    for ry in [y1 + 12, (y1 + y2) // 2, y2 - 12]:
        draw.ellipse([x1 + 13, ry - 3, x1 + 19, ry + 3], fill=(70, 50, 25, 255))
        draw.ellipse([x2 - 19, ry - 3, x2 - 13, ry + 3], fill=(70, 50, 25, 255))

    # Estrella cómica de feria en el centro del martillo (marca de impacto)
    esx, esy = cx, (y1 + y2) // 2
    draw.ellipse([esx - 16, esy - 16, esx + 16, esy + 16], fill=(245, 225, 95, 255))
    draw.ellipse([esx - 10, esy - 10, esx + 10, esy + 10], fill=(255, 245, 175, 255))

    # Brillo suave en la parte superior del cilindro
    draw.line([(x1 + 28, y1 + 10), (x2 - 28, y1 + 10)], fill=(255, 255, 255, 160), width=3)

    img.save(os.path.join(out_dir, "martillo_gigante_feria.png"))
    print("martillo_gigante_feria.png creado con éxito.")

# ------------------------------------------------------------------------------
# 5. RETÍCULA / MIRA DE MARTILLO (140 x 140)
# ------------------------------------------------------------------------------
def crear_mira_martillo():
    W, H = 140, 140
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 70, 70
    R = 60

    # Sombra oscura proyectada
    draw.ellipse([cx - R, cy - R + 6, cx + R, cy + R + 6], fill=(0, 0, 0, 80))

    # Anillo rojo/amarillo de mira
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(235, 45, 45, 240), width=4)
    draw.ellipse([cx - R + 8, cy - R + 8, cx + R - 8, cy + R - 8], outline=(255, 215, 60, 220), width=2)

    # Puntas de cruceta
    draw.line([(cx - R - 6, cy), (cx - R + 14, cy)], fill=(235, 45, 45, 255), width=4)
    draw.line([(cx + R - 14, cy), (cx + R + 6, cy)], fill=(235, 45, 45, 255), width=4)
    draw.line([(cx, cy - R - 6), (cx, cy - R + 14)], fill=(235, 45, 45, 255), width=4)
    draw.line([(cx, cy + R - 14), (cx, cy + R + 6)], fill=(235, 45, 45, 255), width=4)

    # Pequeño círculo central
    draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(235, 45, 45, 255))

    img.save(os.path.join(out_dir, "mira_martillo_reticula.png"))
    print("mira_martillo_reticula.png creado con éxito.")

# ------------------------------------------------------------------------------
# 6. SELECTOR VISUAL DE JUGADOR TOPO (64 x 64)
# ------------------------------------------------------------------------------
def crear_selector_topo():
    W, H = 64, 64
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 32, 28

    # Flecha indicadora flotante apuntando hacia abajo
    draw.polygon([(cx - 16, cy - 14), (cx + 16, cy - 14), (cx + 16, cy - 2), (cx + 24, cy - 2), (cx, cy + 18), (cx - 24, cy - 2), (cx - 16, cy - 2)], fill=(255, 215, 40, 255))
    draw.polygon([(cx - 12, cy - 11), (cx + 12, cy - 11), (cx + 12, cy - 3), (cx + 18, cy - 3), (cx, cy + 13), (cx - 18, cy - 3), (cx - 12, cy - 3)], fill=(255, 250, 175, 255))

    img.save(os.path.join(out_dir, "selector_jugador.png"))
    print("selector_jugador.png creado con éxito.")

if __name__ == "__main__":
    crear_fondo_feria()
    crear_hoyo_activo()
    crear_hoyo_bloqueado()
    crear_martillo_gigante()
    crear_mira_martillo()
    crear_selector_topo()
    print("--- RECURSOS DE MARTILLO DE FERIA GENERADOS CON ÉXITO ---")
