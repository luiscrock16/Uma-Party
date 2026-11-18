extends BaseMinijuego

# ==============================================================================
# MINIJUEGO: EL GRAN FESTIVAL DE TRACEN - EL LABERINTO DE LAS LLAVES
# ==============================================================================

@onready var contenedor_setos = $ContenedorSetos # Muros del festival
@onready var contenedor_sombras = $ContenedorSombras
@onready var contenedor_bosque = $ContenedorBosquePerimetro
@onready var contenedor_puestos = $ContenedorPuestosFestival
@onready var contenedor_puertas = $ContenedorPuertas
@onready var contenedor_llaves = $ContenedorLlaves
@onready var contenedor_npcs = $ContenedorNPCsCentro
@onready var campana_dorada = $CampanaDorada
@onready var visual_campana = $CampanaDorada/VisualCampana
@onready var particulas_brillo = $CampanaDorada/ParticulasBrillo
@onready var hud = $HUD
@onready var label_reloj = $HUD/PanelInfo/LabelReloj
@onready var banner_intro = $HUD/BannerIntro
@onready var camera = $Camera2D

var tex_muro_festival = preload("res://assets/minijuegos/laberinto/muro_festival_panel.png")
var tex_arbol = preload("res://assets/minijuegos/laberinto/arbol_canopia.png")
var tex_farol = preload("res://assets/minijuegos/laberinto/farol_jardin.png")
var tex_akikawa = preload("res://assets/Sprites/NPCS/Yayoi Akikawa/akyy_ST01_00.png")
var tex_tazuna = preload("res://assets/Sprites/NPCS/Tazuna Hayakawa/hatz_ST01_00.png")
var tex_puesto_rojo = preload("res://assets/minijuegos/laberinto/puesto_festival_rojo.png")
var tex_puesto_azul = preload("res://assets/minijuegos/laberinto/puesto_festival_azul.png")
var tex_puesto_amarillo = preload("res://assets/minijuegos/laberinto/puesto_festival_amarillo.png")
var tex_banderines = preload("res://assets/minijuegos/laberinto/banderines_fiesta.png")
var tex_linterna = preload("res://assets/minijuegos/laberinto/linterna_festiva.png")

var tex_llaves: Dictionary = {
	"roja": preload("res://assets/minijuegos/laberinto/llave_roja.png"),
	"azul": preload("res://assets/minijuegos/laberinto/llave_azul.png"),
	"amarilla": preload("res://assets/minijuegos/laberinto/llave_amarilla.png"),
	"verde": preload("res://assets/minijuegos/laberinto/llave_verde.png")
}

var tex_puertas: Dictionary = {
	"roja": preload("res://assets/minijuegos/laberinto/puerta_bloqueada_roja.png"),
	"azul": preload("res://assets/minijuegos/laberinto/puerta_bloqueada_azul.png"),
	"amarilla": preload("res://assets/minijuegos/laberinto/puerta_bloqueada_amarilla.png"),
	"verde": preload("res://assets/minijuegos/laberinto/puerta_bloqueada_verde.png")
}

var escena_personaje = preload("res://escenas/personaje_jugable.tscn")

const GRID_W: int = 55
const GRID_H: int = 55
const CELL_SIZE: float = 54.0
const ORIGEN_LABERINTO: Vector2 = Vector2(200.0, 200.0)
const CENTRO_MUNDO: Vector2 = Vector2(1685.0, 1685.0)

var partida_iniciada: bool = false
var partida_terminada: bool = false
var tiempo_restante: float = 120.0
var laberinto_construido: bool = false

var avatares_jugadores: Dictionary = {}
var id_jugador_local: int = 1
var seed_laberinto: int = 1337
var arquetipo_actual: int = 0

# Estado de llaves y puertas
var llaves_jugadores: Dictionary = {}       # {id_jugador: "color"}
var nodos_puertas: Dictionary = {}          # {color: Node2D}
var nodos_llaves: Dictionary = {}           # {color: Node2D}
var iconos_llaves_avatares: Dictionary = {} # {id_jugador: Sprite2D}
var puertas_abiertas: Dictionary = {}       # {color: bool}

# Spawns en las 4 esquinas del gran festival (Celdas 1,1 - 53,1 - 1,53 - 53,53)
var spawns_esquinas: Array = [
	Vector2(281.0, 281.0),   # P1: Top-Left
	Vector2(3089.0, 281.0),  # P2: Top-Right
	Vector2(281.0, 3089.0),  # P3: Bot-Left
	Vector2(3089.0, 3089.0)  # P4: Bot-Right
]

var colores_esquinas: Array = [
	Color(0.95, 0.25, 0.25), # P1: Rojo
	Color(0.25, 0.65, 0.95), # P2: Azul
	Color(0.3, 0.85, 0.4),   # P3: Verde
	Color(0.95, 0.8, 0.2)    # P4: Amarillo
]

# Las 4 Puertas ubicadas en el centro aproximado de cada uno de los 4 CUADRANTES
var pos_puertas_grid = {
	"roja": Vector2i(17, 17),     # Cuadrante NW (Noroeste)
	"azul": Vector2i(37, 17),     # Cuadrante NE (Noreste)
	"verde": Vector2i(17, 37),    # Cuadrante SW (Suroeste)
	"amarilla": Vector2i(37, 37)  # Cuadrante SE (Sureste)
}

# Llaves ubicadas en cuadrantes DIAMETRALMENTE OPUESTOS a sus respectivas puertas
var pos_llaves_grid = {
	"roja": Vector2i(45, 45),     # Cuadrante SE (Para la Puerta Roja en NW)
	"amarilla": Vector2i(9, 9),   # Cuadrante NW (Para la Puerta Amarilla en SE)
	"azul": Vector2i(9, 45),      # Cuadrante SW (Para la Puerta Azul en NE)
	"verde": Vector2i(45, 9)      # Cuadrante NE (Para la Puerta Verde en SW)
}

# Plazas intermedias del festival donde se ubican las llaves y puestos
var plazas_festival: Array = [
	Vector2i(9, 9),   # Plaza NW (Llave Amarilla)
	Vector2i(45, 9),  # Plaza NE (Llave Verde)
	Vector2i(9, 45),  # Plaza SW (Llave Azul)
	Vector2i(45, 45), # Plaza SE (Llave Roja)
	Vector2i(27, 7),  # Glorieta Norte
	Vector2i(27, 47), # Glorieta Sur
	Vector2i(7, 27),  # Glorieta Oeste
	Vector2i(47, 27)  # Glorieta Este
]

func _ready():
	modo_actual = Modo.FFA
	var g = get_node_or_null("/root/Global")
	if g and g.has_method("establecer_texto_accion_tactil"):
		g.establecer_texto_accion_tactil("SPRINT")
	partida_iniciada = false
	partida_terminada = false
	tiempo_restante = 120.0
	laberinto_construido = false
	llaves_jugadores.clear()
	nodos_puertas.clear()
	nodos_llaves.clear()
	iconos_llaves_avatares.clear()
	puertas_abiertas.clear()
	
	if campana_dorada:
		campana_dorada.body_entered.connect(_on_campana_tocada)
		
	if banner_intro:
		banner_intro.visible = false
		
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 3370
	camera.limit_bottom = 3370
	camera.position_smoothing_enabled = true
	
	# La cámara empieza enfocando de cerca la plaza central (el laberinto NO se ve al inicio)
	camera.global_position = CENTRO_MUNDO
	camera.zoom = Vector2(1.35, 1.35)
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	jugadores_info.clear()
	for i in range(4):
		var id = i + 1
		jugadores_info[id] = {"equipo": i, "spawn": i, "personaje_idx": i, "es_jefe": false}
		if not has_node(str(id)):
			var av = escena_personaje.instantiate()
			av.name = str(id)
			add_child(av)
			av.configurar_visual(i, "P" + str(i + 1))
	aplicar_roles_locales()

func aplicar_roles_locales():
	id_jugador_local = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	avatares_jugadores.clear()
	
	var i = 0
	for id in jugadores_info.keys():
		var av = get_node_or_null(str(id))
		if not av and get_tree().root:
			av = get_tree().root.find_child(str(id), true, false)
			
		if av:
			avatares_jugadores[id] = av
			av.global_position = spawns_esquinas[i % spawns_esquinas.size()]
			av.bloquear_controles(true)
			av.modulate = Color.WHITE
			av.scale = Vector2.ONE
			av.visible = true
			if "set_movimiento_actual" in av:
				av.set_movimiento_actual = PersonajeJugable.TipoMovimiento.CON_SPRINT
		i += 1
		
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad:
		var rng_seed = randi()
		var rng_arch = randi() % 3
		if multiplayer.has_multiplayer_peer():
			sincronizar_laberinto_rpc.rpc(rng_seed, rng_arch)
		else:
			sincronizar_laberinto_rpc(rng_seed, rng_arch)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_laberinto_rpc(p_seed: int, p_arch: int):
	seed_laberinto = p_seed
	arquetipo_actual = p_arch
	construir_mundo_laberinto(seed_laberinto, arquetipo_actual)
	configurar_personajes_centrales()
	
	camera.global_position = CENTRO_MUNDO
	camera.zoom = Vector2(1.35, 1.35)
	
	# Mostrar pantalla modal de confirmación ("¡LISTO!")
	iniciar_secuencia_cuenta_atras()

# ==============================================================================
# CONFIGURACIÓN DE PERSONAJES EN LA PLAZA CENTRAL (DIRECTORA, TAZUNA Y ESPECTADORAS)
# ==============================================================================

func configurar_personajes_centrales():
	if not contenedor_npcs: return
	for c in contenedor_npcs.get_children():
		c.queue_free()
		
	# 1. Directora Yayoi Akikawa
	var spr_akikawa = Sprite2D.new()
	spr_akikawa.texture = tex_akikawa
	spr_akikawa.position = CENTRO_MUNDO + Vector2(-60, -15)
	spr_akikawa.scale = Vector2(0.40, 0.40)
	contenedor_npcs.add_child(spr_akikawa)
	
	var tw_ak = spr_akikawa.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw_ak.tween_property(spr_akikawa, "scale", Vector2(0.42, 0.38), 0.5)
	tw_ak.tween_property(spr_akikawa, "scale", Vector2(0.38, 0.42), 0.5)
	
	# 2. Hayakawa Tazuna
	var spr_tazuna = Sprite2D.new()
	spr_tazuna.texture = tex_tazuna
	spr_tazuna.position = CENTRO_MUNDO + Vector2(60, -15)
	spr_tazuna.scale = Vector2(0.40, 0.40)
	contenedor_npcs.add_child(spr_tazuna)
	
	var tw_tz = spr_tazuna.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw_tz.tween_property(spr_tazuna, "position:y", CENTRO_MUNDO.y - 18, 0.6)
	tw_tz.tween_property(spr_tazuna, "position:y", CENTRO_MUNDO.y - 12, 0.6)
	
	# 3. Uma Musumes espectadoras no seleccionadas por los jugadores
	var indices_usados = []
	for p_info in jugadores_info.values():
		var idx = p_info["personaje_idx"] if (p_info is Dictionary and "personaje_idx" in p_info) else -1
		if idx >= 0:
			indices_usados.append(idx)
			
	var todos_indices = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	var indices_libres = []
	for i in todos_indices:
		if not indices_usados.has(i):
			indices_libres.append(i)
	indices_libres.shuffle()
	
	var offsets_espectadoras = [
		Vector2(-80, 50),
		Vector2(-30, 70),
		Vector2(30, 70),
		Vector2(80, 50)
	]
	
	for k in range(min(4, indices_libres.size())):
		var av_esp = escena_personaje.instantiate()
		contenedor_npcs.add_child(av_esp)
		av_esp.position = CENTRO_MUNDO + offsets_espectadoras[k]
		av_esp.configurar_visual(indices_libres[k], "")
		av_esp.bloquear_controles(true)
		av_esp.collision_layer = 0
		av_esp.collision_mask = 0
		if "sprite" in av_esp and av_esp.sprite:
			var prefijo = av_esp.get("prefijo_personaje") if "prefijo_personaje" in av_esp else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if av_esp.sprite.sprite_frames.has_animation(prefijo + "_idle"):
				av_esp.sprite.play(prefijo + "_idle")

# ==============================================================================
# CONSTRUCCIÓN PROCEDURAL DEL LABERINTO DEL FESTIVAL (55x55)
# ==============================================================================

func construir_mundo_laberinto(p_seed: int, p_arch: int):
	if laberinto_construido: return
	laberinto_construido = true
	
	for h in contenedor_setos.get_children(): h.queue_free()
	for h in contenedor_sombras.get_children(): h.queue_free()
	for h in contenedor_bosque.get_children(): h.queue_free()
	for h in contenedor_puestos.get_children(): h.queue_free()
	for h in contenedor_puertas.get_children(): h.queue_free()
	for h in contenedor_llaves.get_children(): h.queue_free()
	
	var grid = []
	for y in range(GRID_H):
		var fila = []
		for x in range(GRID_W):
			fila.append(1) # 1 = Muro de festival
		grid.append(fila)
		
	var rng = RandomNumberGenerator.new()
	rng.seed = p_seed
	
	# 1. Definición del Santuario Central y Corredores Protegidos de Cuadrante
	var zona_protegida = {}
	
	# Plaza Central 7x7 (Celdas 24..30)
	for y in range(24, 31):
		for x in range(24, 31):
			grid[y][x] = 0
			
	# Muro grueso de contención alrededor de la Plaza Central (21..33)
	for y in range(21, 34):
		for x in range(21, 34):
			zona_protegida[Vector2i(x, y)] = true
			
	# Definición de los 4 corredores dedicados desde cada compuerta de cuadrante al centro
	var corredores_cuadrantes = {
		# Cuadrante NW: Puerta Roja (17, 17) -> Este hacia (27, 17) -> Sur hacia (27, 24) [Entrada Norte plaza]
		"roja": {
			"puerta": Vector2i(17, 17),
			"entradas_ext": [Vector2i(16, 17), Vector2i(17, 16)],
			"camino": []
		},
		# Cuadrante NE: Puerta Azul (37, 17) -> Sur hacia (37, 27) -> Oeste hacia (30, 27) [Entrada Este plaza]
		"azul": {
			"puerta": Vector2i(37, 17),
			"entradas_ext": [Vector2i(38, 17), Vector2i(37, 16)],
			"camino": []
		},
		# Cuadrante SW: Puerta Verde (17, 37) -> Norte hacia (17, 27) -> Este hacia (24, 27) [Entrada Oeste plaza]
		"verde": {
			"puerta": Vector2i(17, 37),
			"entradas_ext": [Vector2i(16, 37), Vector2i(17, 38)],
			"camino": []
		},
		# Cuadrante SE: Puerta Amarilla (37, 37) -> Oeste hacia (27, 37) -> Norte hacia (27, 30) [Entrada Sur plaza]
		"amarilla": {
			"puerta": Vector2i(37, 37),
			"entradas_ext": [Vector2i(38, 37), Vector2i(37, 38)],
			"camino": []
		}
	}
	
	# Construir caminos de los corredores
	for x in range(17, 28): corredores_cuadrantes["roja"]["camino"].append(Vector2i(x, 17))
	for y in range(17, 25): corredores_cuadrantes["roja"]["camino"].append(Vector2i(27, y))
	
	for y in range(17, 28): corredores_cuadrantes["azul"]["camino"].append(Vector2i(37, y))
	for x in range(30, 38): corredores_cuadrantes["azul"]["camino"].append(Vector2i(x, 27))
	
	for y in range(27, 38): corredores_cuadrantes["verde"]["camino"].append(Vector2i(17, y))
	for x in range(17, 25): corredores_cuadrantes["verde"]["camino"].append(Vector2i(x, 27))
	
	for x in range(27, 38): corredores_cuadrantes["amarilla"]["camino"].append(Vector2i(x, 37))
	for y in range(30, 38): corredores_cuadrantes["amarilla"]["camino"].append(Vector2i(27, y))
	
	# Marcar caminos como suelo (0) y buffer circundante como zona_protegida
	for c_info in corredores_cuadrantes.values():
		var p_gate = c_info["puerta"]
		grid[p_gate.y][p_gate.x] = 0
		zona_protegida[p_gate] = true
		
		for pt in c_info["camino"]:
			grid[pt.y][pt.x] = 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					zona_protegida[Vector2i(pt.x + dx, pt.y + dy)] = true
					
		# Habilitar los accesos exteriores frente a la puerta (NO protegidos para que el laberinto conecte a ellos)
		for ext in c_info["entradas_ext"]:
			grid[ext.y][ext.x] = 0
			if zona_protegida.has(ext):
				zona_protegida.erase(ext)

	# 2. Plazas intermedias del festival (fuera de zona_protegida)
	for p in plazas_festival:
		for y in range(p.y - 2, p.y + 3):
			for x in range(p.x - 2, p.x + 3):
				if x > 0 and x < GRID_W - 1 and y > 0 and y < GRID_H - 1:
					if not zona_protegida.has(Vector2i(x, y)):
						grid[y][x] = 0

	# 3. Tallado de caminos orgánicos en el laberinto exterior
	var visitados = {}
	for pt in zona_protegida.keys():
		visitados[pt] = true
		
	# Iniciar DFS desde los spawns de las 4 esquinas
	var stack = [Vector2i(1, 1), Vector2i(53, 1), Vector2i(1, 53), Vector2i(53, 53)]
	for s in stack:
		grid[s.y][s.x] = 0
		visitados[s] = true
		
	while stack.size() > 0:
		var curr = stack[stack.size() - 1]
		var vecinos = []
		var dirs = [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]
		for d in dirs:
			var nx = curr.x + d.x
			var ny = curr.y + d.y
			var n_pos = Vector2i(nx, ny)
			var w_pos = Vector2i(curr.x + d.x / 2, curr.y + d.y / 2)
			if nx >= 1 and nx < GRID_W - 1 and ny >= 1 and ny < GRID_H - 1:
				if not visitados.has(n_pos) and not zona_protegida.has(n_pos) and not zona_protegida.has(w_pos):
					vecinos.append({"n": n_pos, "w": w_pos})
					
		if vecinos.size() > 0:
			var elegido = vecinos[rng.randi() % vecinos.size()]
			visitados[elegido["n"]] = true
			grid[elegido["w"].y][elegido["w"].x] = 0
			grid[elegido["n"].y][elegido["n"].x] = 0
			stack.append(elegido["n"])
		else:
			stack.pop_back()

	# Arquetipo 1: Talla adicional de curvas concéntricas si corresponde
	if p_arch == 1:
		for y in range(1, GRID_H - 1):
			for x in range(1, GRID_W - 1):
				var pt = Vector2i(x, y)
				if zona_protegida.has(pt): continue
				var r = Vector2(x - 27, y - 27).length()
				if abs(r - 16.0) < 0.8 or abs(r - 22.0) < 0.8:
					grid[y][x] = 0

	# 4. Conexiones múltiples de plazas, accesos y esquinas al laberinto exterior
	var puntos_clave_exterior = []
	for p in plazas_festival: puntos_clave_exterior.append(p)
	puntos_clave_exterior.append_array([Vector2i(1, 1), Vector2i(53, 1), Vector2i(1, 53), Vector2i(53, 53)])
	for c_info in corredores_cuadrantes.values():
		puntos_clave_exterior.append_array(c_info["entradas_ext"])
		
	for p in puntos_clave_exterior:
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var gx = p.x + d.x
			var gy = p.y + d.y
			var pt = Vector2i(gx, gy)
			if gx > 0 and gx < GRID_W - 1 and gy > 0 and gy < GRID_H - 1 and not zona_protegida.has(pt):
				grid[gy][gx] = 0

	# 5. Braiding exterior masivo (160 atajos e interconexiones para que las jugadoras se crucen)
	for _b in range(160):
		var rx = rng.randi_range(2, GRID_W - 3)
		var ry = rng.randi_range(2, GRID_H - 3)
		var pt = Vector2i(rx, ry)
		if zona_protegida.has(pt):
			continue
		if grid[ry][rx] == 1:
			var h_open = (grid[ry][rx - 1] == 0 and grid[ry][rx + 1] == 0)
			var v_open = (grid[ry - 1][rx] == 0 and grid[ry + 1][rx] == 0)
			if h_open or v_open:
				grid[ry][rx] = 0

	# 6. Asegurar que las posiciones de las 4 llaves son suelos libres
	for color in pos_llaves_grid:
		var pos_k = pos_llaves_grid[color]
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				grid[pos_k.y + dy][pos_k.x + dx] = 0

	# 8. Instanciar bloques de MUROS DE FESTIVAL SEAMLESS (con paneles tradicionales)
	for y in range(GRID_H):
		for x in range(GRID_W):
			if grid[y][x] == 1:
				var pos_celda = ORIGEN_LABERINTO + Vector2(x * CELL_SIZE, y * CELL_SIZE)
				var exp_norte = (y == 0 or grid[y - 1][x] == 0)
				var exp_sur = (y == GRID_H - 1 or grid[y + 1][x] == 0)
				var exp_oeste = (x == 0 or grid[y][x - 1] == 0)
				var exp_este = (x == GRID_W - 1 or grid[y][x + 1] == 0)
				crear_bloque_muro_festival(pos_celda, exp_norte, exp_sur, exp_oeste, exp_este)
				
	# 9. Instanciar las 4 Puertas Bloqueadas de Colores alrededor del centro
	instanciar_puertas_bloqueadas()
	
	# 10. Instanciar las 4 Llaves en posiciones diametralmente opuestas
	instanciar_llaves_del_festival()
	
	# 11. Decorar con puestos del festival, farolillos y banderines
	decorar_festival_tracen(rng)
	
	# 12. Bosque perimetral exterior
	construir_bosque_perimetral(rng)
	
	# 13. Glorietas de inicio en las esquinas
	for c_idx in range(spawns_esquinas.size()):
		var alfombra = ColorRect.new()
		alfombra.position = spawns_esquinas[c_idx] - Vector2(27, 27)
		alfombra.size = Vector2(54, 54)
		alfombra.color = colores_esquinas[c_idx]
		alfombra.modulate.a = 0.5
		alfombra.z_index = -12
		add_child(alfombra)

func crear_bloque_muro_festival(
	pos: Vector2,
	exp_norte: bool,
	exp_sur: bool,
	exp_oeste: bool,
	exp_este: bool
):
	if exp_sur or exp_este:
		var off_x = 5.0 if exp_este else 0.0
		var off_y = 6.0 if exp_sur else 0.0
		var sombra = ColorRect.new()
		sombra.position = pos + Vector2(off_x, off_y)
		sombra.size = Vector2(CELL_SIZE + off_x, CELL_SIZE + off_y)
		sombra.color = Color(0.0, 0.0, 0.0, 0.32)
		contenedor_sombras.add_child(sombra)
	
	var cuerpo = StaticBody2D.new()
	cuerpo.position = pos + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	
	var col = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(CELL_SIZE, CELL_SIZE)
	col.shape = rect_shape
	cuerpo.add_child(col)
	
	var spr = Sprite2D.new()
	spr.texture = tex_muro_festival
	spr.scale = Vector2(CELL_SIZE / 128.0, CELL_SIZE / 128.0)
	cuerpo.add_child(spr)
	
	var col_borde = Color(0.35, 0.20, 0.10, 1.0)
	var grosor = 3.0
	var h_sz = CELL_SIZE * 0.5
	
	if exp_norte:
		var lin = Line2D.new()
		lin.points = PackedVector2Array([Vector2(-h_sz, -h_sz), Vector2(h_sz, -h_sz)])
		lin.width = grosor
		lin.default_color = col_borde
		cuerpo.add_child(lin)
	if exp_sur:
		var lin = Line2D.new()
		lin.points = PackedVector2Array([Vector2(-h_sz, h_sz), Vector2(h_sz, h_sz)])
		lin.width = grosor
		lin.default_color = col_borde
		cuerpo.add_child(lin)
	if exp_oeste:
		var lin = Line2D.new()
		lin.points = PackedVector2Array([Vector2(-h_sz, -h_sz), Vector2(-h_sz, h_sz)])
		lin.width = grosor
		lin.default_color = col_borde
		cuerpo.add_child(lin)
	if exp_este:
		var lin = Line2D.new()
		lin.points = PackedVector2Array([Vector2(h_sz, -h_sz), Vector2(h_sz, h_sz)])
		lin.width = grosor
		lin.default_color = col_borde
		cuerpo.add_child(lin)
		
	contenedor_setos.add_child(cuerpo)

# ==============================================================================
# SISTEMA DE PUERTAS BLOQUEADAS Y LLAVES DEL FESTIVAL
# ==============================================================================

func instanciar_puertas_bloqueadas():
	for color in pos_puertas_grid:
		var pos_g = pos_puertas_grid[color]
		var pos_m = ORIGEN_LABERINTO + Vector2(pos_g.x * CELL_SIZE + CELL_SIZE * 0.5, pos_g.y * CELL_SIZE + CELL_SIZE * 0.5)
		
		var nodo_puerta = Node2D.new()
		nodo_puerta.name = "Puerta_" + color
		nodo_puerta.position = pos_m
		
		# Cuerpo físico bloqueador (StaticBody2D)
		var cuerpo = StaticBody2D.new()
		cuerpo.name = "BloqueoFisico"
		cuerpo.collision_layer = 1
		cuerpo.collision_mask = 0
		var col = CollisionShape2D.new()
		var box = RectangleShape2D.new()
		box.size = Vector2(CELL_SIZE * 1.1, CELL_SIZE * 1.1)
		col.shape = box
		cuerpo.add_child(col)
		nodo_puerta.add_child(cuerpo)
		
		# Sprite del arco Torii con candado gigante del color
		var spr = Sprite2D.new()
		spr.name = "SpritePuerta"
		spr.texture = tex_puertas[color]
		spr.scale = Vector2(0.68, 0.68)
		nodo_puerta.add_child(spr)
		
		# Animación suave del candado brillante
		var tw = spr.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tw.tween_property(spr, "scale", Vector2(0.72, 0.72), 0.6)
		tw.tween_property(spr, "scale", Vector2(0.66, 0.66), 0.6)
		
		# Area2D para detectar llegada del jugador
		var area = Area2D.new()
		area.name = "AreaApertura"
		area.collision_layer = 0
		area.collision_mask = 1 | 2 | 3
		var col_a = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 55.0
		col_a.shape = circle
		area.add_child(col_a)
		nodo_puerta.add_child(area)
		
		area.body_entered.connect(_on_puerta_body_entered.bind(color))
		area.area_entered.connect(_on_puerta_area_entered.bind(color))
		
		contenedor_puertas.add_child(nodo_puerta)
		nodos_puertas[color] = nodo_puerta

func instanciar_llaves_del_festival():
	for color in pos_llaves_grid:
		var pos_g = pos_llaves_grid[color]
		var pos_m = ORIGEN_LABERINTO + Vector2(pos_g.x * CELL_SIZE + CELL_SIZE * 0.5, pos_g.y * CELL_SIZE + CELL_SIZE * 0.5)
		
		var area_llave = Area2D.new()
		area_llave.name = "Llave_" + color
		area_llave.position = pos_m
		area_llave.collision_layer = 0
		area_llave.collision_mask = 1 | 2 | 3
		
		var col = CollisionShape2D.new()
		var circ = CircleShape2D.new()
		circ.radius = 48.0
		col.shape = circ
		area_llave.add_child(col)
		
		var spr = Sprite2D.new()
		spr.name = "SpriteLlave"
		spr.texture = tex_llaves[color]
		spr.scale = Vector2(0.9, 0.9)
		area_llave.add_child(spr)
		
		# Animación de flotación y destello
		var tw_float = spr.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tw_float.tween_property(spr, "position:y", -10.0, 0.55)
		tw_float.tween_property(spr, "position:y", 2.0, 0.55)
		
		area_llave.body_entered.connect(_on_llave_body_entered.bind(color))
		area_llave.area_entered.connect(_on_llave_area_entered.bind(color))
		
		contenedor_llaves.add_child(area_llave)
		nodos_llaves[color] = area_llave

func _on_llave_body_entered(body: Node2D, color: String):
	if partida_terminada or not partida_iniciada: return
	var id = -1
	if body is CharacterBody2D and body.is_in_group("Jugador"):
		id = body.name.to_int()
	if id > 0:
		intentar_recoger_llave(id, color)

func _on_llave_area_entered(area: Area2D, color: String):
	if partida_terminada or not partida_iniciada: return
	var p = area.get_parent()
	var id = -1
	if p and p is CharacterBody2D and p.is_in_group("Jugador"):
		id = p.name.to_int()
	if id > 0:
		intentar_recoger_llave(id, color)

func intentar_recoger_llave(id_jugador: int, color: String):
	if partida_terminada or not partida_iniciada: return
	# REGLA: Cada jugador puede portar como máximo 1 llave a la vez
	if llaves_jugadores.get(id_jugador, "") != "": return
	if not nodos_llaves.has(color) or not is_instance_valid(nodos_llaves[color]): return
	
	if multiplayer.has_multiplayer_peer():
		reclamar_llave_rpc.rpc_id(1, id_jugador, color)
	else:
		sincronizar_recogida_llave_rpc(id_jugador, color)

@rpc("any_peer", "call_local", "reliable")
func reclamar_llave_rpc(id_jugador: int, color: String):
	if not es_autoridad_de_partida(): return
	if llaves_jugadores.get(id_jugador, "") != "": return
	if not nodos_llaves.has(color) or not is_instance_valid(nodos_llaves[color]): return
	sincronizar_recogida_llave_rpc.rpc(id_jugador, color)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_recogida_llave_rpc(id_jugador: int, color: String):
	llaves_jugadores[id_jugador] = color
	
	# Desactivar la llave recogida del suelo
	if nodos_llaves.has(color) and is_instance_valid(nodos_llaves[color]):
		nodos_llaves[color].queue_free()
		nodos_llaves.erase(color)
		
	# Colocar icono flotante de la llave sobre la cabeza del corredor
	var av = avatares_jugadores.get(id_jugador)
	if av and is_instance_valid(av):
		if iconos_llaves_avatares.has(id_jugador) and is_instance_valid(iconos_llaves_avatares[id_jugador]):
			iconos_llaves_avatares[id_jugador].queue_free()
		var spr_icono = Sprite2D.new()
		spr_icono.name = "IconoLlaveFlotante"
		spr_icono.texture = tex_llaves[color]
		spr_icono.position = Vector2(0, -65)
		spr_icono.scale = Vector2(0.65, 0.65)
		spr_icono.z_index = 10
		av.add_child(spr_icono)
		iconos_llaves_avatares[id_jugador] = spr_icono
		
		var tw = spr_icono.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tw.tween_property(spr_icono, "position:y", -72.0, 0.45)
		tw.tween_property(spr_icono, "position:y", -62.0, 0.45)

func _on_puerta_body_entered(body: Node2D, color: String):
	if partida_terminada or not partida_iniciada: return
	var id = -1
	if body is CharacterBody2D and body.is_in_group("Jugador"):
		id = body.name.to_int()
	if id > 0:
		intentar_abrir_puerta(id, color)

func _on_puerta_area_entered(area: Area2D, color: String):
	if partida_terminada or not partida_iniciada: return
	var p = area.get_parent()
	var id = -1
	if p and p is CharacterBody2D and p.is_in_group("Jugador"):
		id = p.name.to_int()
	if id > 0:
		intentar_abrir_puerta(id, color)

func intentar_abrir_puerta(id_jugador: int, color: String):
	if partida_terminada or not partida_iniciada: return
	if llaves_jugadores.get(id_jugador, "") != color: return
	if puertas_abiertas.get(color, false): return
	
	if multiplayer.has_multiplayer_peer():
		reclamar_apertura_puerta_rpc.rpc_id(1, id_jugador, color)
	else:
		sincronizar_apertura_puerta_rpc(id_jugador, color)

@rpc("any_peer", "call_local", "reliable")
func reclamar_apertura_puerta_rpc(id_jugador: int, color: String):
	if not es_autoridad_de_partida(): return
	if llaves_jugadores.get(id_jugador, "") != color: return
	if puertas_abiertas.get(color, false): return
	sincronizar_apertura_puerta_rpc.rpc(id_jugador, color)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_apertura_puerta_rpc(id_jugador: int, color: String):
	puertas_abiertas[color] = true
	
	# Desvanecer la puerta y desactivar su colisión para que el jugador pueda entrar al corredor hacia el centro
	if nodos_puertas.has(color) and is_instance_valid(nodos_puertas[color]):
		var p_nodo = nodos_puertas[color]
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(p_nodo, "modulate:a", 0.0, 0.4)
		tw.tween_property(p_nodo, "scale", Vector2(1.25, 1.25), 0.4)
		tw.tween_callback(func():
			for child in p_nodo.get_children():
				if child is StaticBody2D:
					child.queue_free()
		)
		
	# Remover la llave usada del jugador
	llaves_jugadores[id_jugador] = ""
	if iconos_llaves_avatares.has(id_jugador) and is_instance_valid(iconos_llaves_avatares[id_jugador]):
		iconos_llaves_avatares[id_jugador].queue_free()
		iconos_llaves_avatares.erase(id_jugador)

# ==============================================================================
# DECORACIÓN FESTIVAL DE TRACEN
# ==============================================================================

func decorar_festival_tracen(rng: RandomNumberGenerator):
	if not contenedor_puestos: return
	
	var info_puestos = [
		{"pos": Vector2i(9, 9), "offset": Vector2(0, -50), "tex": tex_puesto_amarillo},
		{"pos": Vector2i(45, 9), "offset": Vector2(0, -50), "tex": tex_puesto_rojo},
		{"pos": Vector2i(9, 45), "offset": Vector2(0, -50), "tex": tex_puesto_azul},
		{"pos": Vector2i(45, 45), "offset": Vector2(0, -50), "tex": tex_puesto_rojo}
	]
	
	for ip in info_puestos:
		var pos_m = ORIGEN_LABERINTO + Vector2(ip["pos"].x * CELL_SIZE + CELL_SIZE * 0.5, ip["pos"].y * CELL_SIZE + CELL_SIZE * 0.5) + ip["offset"]
		var spr_p = Sprite2D.new()
		spr_p.texture = ip["tex"]
		spr_p.position = pos_m
		spr_p.scale = Vector2(0.85, 0.85)
		spr_p.z_index = 1
		contenedor_puestos.add_child(spr_p)
		
		for off in [Vector2(-60, -30), Vector2(60, -30)]:
			var spr_l = Sprite2D.new()
			spr_l.texture = tex_linterna
			spr_l.position = pos_m + off
			spr_l.z_index = 2
			contenedor_puestos.add_child(spr_l)
			
	var plazas_cardinales = [Vector2i(27, 7), Vector2i(27, 47), Vector2i(7, 27), Vector2i(47, 27)]
	for pc in plazas_cardinales:
		var pos_c = ORIGEN_LABERINTO + Vector2(pc.x * CELL_SIZE, pc.y * CELL_SIZE)
		var spr_b = Sprite2D.new()
		spr_b.texture = tex_banderines
		spr_b.position = pos_c
		spr_b.scale = Vector2(0.9, 0.9)
		spr_b.z_index = 4
		contenedor_puestos.add_child(spr_b)
		
	for _i in range(30):
		var gx = rng.randi_range(4, GRID_W - 5)
		var gy = rng.randi_range(4, GRID_H - 5)
		var p_mundo = ORIGEN_LABERINTO + Vector2(gx * CELL_SIZE, gy * CELL_SIZE)
		if rng.randf() > 0.5:
			var spr_band = Sprite2D.new()
			spr_band.texture = tex_banderines
			spr_band.position = p_mundo
			spr_band.scale = Vector2(0.75, 0.75)
			spr_band.z_index = 4
			contenedor_puestos.add_child(spr_band)
		else:
			var spr_lint = Sprite2D.new()
			spr_lint.texture = tex_linterna
			spr_lint.position = p_mundo
			spr_lint.z_index = 3
			contenedor_puestos.add_child(spr_lint)

func construir_bosque_perimetral(rng: RandomNumberGenerator):
	var agregar_arbol = func(pos_a: Vector2):
		var spr_a = Sprite2D.new()
		spr_a.texture = tex_arbol
		spr_a.position = pos_a
		var escala_rnd = rng.randf_range(1.0, 1.35)
		spr_a.scale = Vector2(escala_rnd, escala_rnd)
		spr_a.rotation = rng.randf_range(0.0, PI * 2.0)
		contenedor_bosque.add_child(spr_a)
		
	for px in range(50, 3340, 90):
		agregar_arbol.call(Vector2(px + rng.randf_range(-10, 10), 80 + rng.randf_range(-14, 14)))
		agregar_arbol.call(Vector2(px + rng.randf_range(-10, 10), 3290 + rng.randf_range(-14, 14)))
		
	for py in range(80, 3300, 90):
		agregar_arbol.call(Vector2(80 + rng.randf_range(-14, 14), py + rng.randf_range(-10, 10)))
		agregar_arbol.call(Vector2(3290 + rng.randf_range(-14, 14), py + rng.randf_range(-10, 10)))

# ==============================================================================
# SECUENCIA DE TRANSICIÓN TRAS CONFIRMAR "¡LISTO!"
# ==============================================================================

func _on_instrucciones_completadas():
	inicio_cuenta_atras.emit()
	al_completar_instrucciones()
	ejecutar_transicion_apertura_mapa()

func ejecutar_transicion_apertura_mapa():
	var tw_out = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_out.tween_property(camera, "zoom", Vector2(0.20, 0.20), 0.8)
	
	if banner_intro:
		banner_intro.visible = true
		banner_intro.modulate.a = 0.0
		var tw_b = create_tween()
		tw_b.tween_property(banner_intro, "modulate:a", 1.0, 0.4)
		
	await tw_out.finished
	
	await get_tree().create_timer(1.8).timeout
	
	if banner_intro:
		var tw_bo = create_tween()
		tw_bo.tween_property(banner_intro, "modulate:a", 0.0, 0.3)
		tw_bo.tween_callback(func(): banner_intro.visible = false)
		
	var av_local = avatares_jugadores.get(id_jugador_local)
	if not av_local or not is_instance_valid(av_local):
		av_local = obtener_avatar_jugador(id_jugador_local)
		
	var pos_destino = av_local.global_position if av_local else spawns_esquinas[0]
	
	var tw_in = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw_in.tween_property(camera, "global_position", pos_destino, 1.4)
	tw_in.tween_property(camera, "zoom", Vector2(1.45, 1.45), 1.4)
	await tw_in.finished
	
	ejecutar_overlay_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	partida_iniciada = true
	bloquear_jugadores(false)
	
	if visual_campana:
		var tw_p = visual_campana.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tw_p.tween_property(visual_campana, "scale", Vector2(1.15, 1.15), 0.7)
		tw_p.tween_property(visual_campana, "scale", Vector2.ONE, 0.7)

# ==============================================================================
# BUCLE DE PROCESO Y SEGUIMIENTO DE CÁMARA
# ==============================================================================

func _process(delta):
	if not partida_iniciada or partida_terminada: return
	
	tiempo_restante -= delta
	if label_reloj:
		label_reloj.text = "%02d:%02d" % [max(0, int(tiempo_restante) / 60), max(0, int(tiempo_restante) % 60)]
		
	var av_local = avatares_jugadores.get(id_jugador_local)
	if av_local and is_instance_valid(av_local):
		camera.global_position = camera.global_position.lerp(av_local.global_position, 12.0 * delta)
		
	_verificar_proximidad_interacciones()
			
	if tiempo_restante <= 0.0 and not partida_terminada:
		partida_terminada = true
		declarar_fin_por_tiempo()

func _verificar_proximidad_interacciones():
	if not partida_iniciada or partida_terminada: return
	var av_local = avatares_jugadores.get(id_jugador_local)
	if not av_local or not is_instance_valid(av_local): return
	
	var pos_jug = av_local.global_position
	var mi_llave = llaves_jugadores.get(id_jugador_local, "")
	
	var boton_accion = _es_boton_accion_presionado()
	
	# 1. Si no tiene llave, verificar recogida de alguna llave en el suelo
	if mi_llave == "":
		for color in nodos_llaves.keys():
			var n_llave = nodos_llaves[color]
			if is_instance_valid(n_llave):
				var dist = pos_jug.distance_to(n_llave.global_position)
				# Recogida automática al pasar por encima (< 48px) o al pulsar acción cerca (< 75px)
				if dist < 48.0 or (dist < 75.0 and boton_accion):
					intentar_recoger_llave(id_jugador_local, color)
					break
	else:
		# 2. Si lleva llave, verificar apertura de su puerta correspondiente
		var n_puerta = nodos_puertas.get(mi_llave)
		if is_instance_valid(n_puerta) and not puertas_abiertas.get(mi_llave, false):
			var dist = pos_jug.distance_to(n_puerta.global_position)
			# Apertura al tocar la puerta (< 52px) o al pulsar acción cerca (< 78px)
			if dist < 52.0 or (dist < 78.0 and boton_accion):
				intentar_abrir_puerta(id_jugador_local, mi_llave)

func _es_boton_accion_presionado() -> bool:
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER):
		return true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	if InputMap.has_action("espacio") and Input.is_action_just_pressed("espacio"):
		return true
	if InputMap.has_action("ui_accept") and Input.is_action_just_pressed("ui_accept"):
		return true
	if InputMap.has_action("ui_select") and Input.is_action_just_pressed("ui_select"):
		return true
	return false

func declarar_fin_por_tiempo():
	var id_mas_cercano = 1
	var menor_dist = 999999.0
	for id in jugadores_info.keys():
		var av = avatares_jugadores.get(id)
		if av and is_instance_valid(av):
			var d = av.global_position.distance_to(CENTRO_MUNDO)
			if d < menor_dist:
				menor_dist = d
				id_mas_cercano = id
				
	declarar_fin_laberinto(id_mas_cercano)

# ==============================================================================
# DETECCIÓN DE META Y VICTORIA (CAMPANA DORADA DEL FESTIVAL)
# ==============================================================================

func _on_campana_tocada(body: Node2D):
	if partida_terminada or not partida_iniciada: return
	if body is CharacterBody2D and body.is_in_group("Jugador"):
		var id = body.name.to_int()
		if id > 0:
			declarar_fin_laberinto(id)

func declarar_fin_laberinto(id_ganador: int):
	if partida_terminada: return
	partida_terminada = true
	
	if multiplayer.has_multiplayer_peer():
		if es_autoridad_de_partida():
			sincronizar_victoria_laberinto_rpc.rpc(id_ganador)
		else:
			reclamar_campana_al_servidor_rpc.rpc_id(1, id_ganador)
	else:
		sincronizar_victoria_laberinto_rpc(id_ganador)

@rpc("any_peer", "call_remote", "reliable")
func reclamar_campana_al_servidor_rpc(id_ganador: int):
	if not es_autoridad_de_partida() or partida_terminada: return
	sincronizar_victoria_laberinto_rpc.rpc(id_ganador)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_victoria_laberinto_rpc(id_ganador: int):
	partida_terminada = true
	bloquear_jugadores(true)
	
	if visual_campana:
		var tw_camp = create_tween().set_loops(5).set_trans(Tween.TRANS_SINE)
		tw_camp.tween_property(visual_campana, "rotation_degrees", -25.0, 0.08)
		tw_camp.tween_property(visual_campana, "rotation_degrees", 25.0, 0.08)
		tw_camp.tween_property(visual_campana, "rotation_degrees", 0.0, 0.06)
		
	if particulas_brillo:
		particulas_brillo.amount = 50
		particulas_brillo.scale_amount_max = 7.0
		
	# Colocar al ganador en el podio de la meta frente a la Campana Dorada
	var pos_meta = CENTRO_MUNDO + Vector2(0.0, 45.0)
	for id in jugadores_info.keys():
		var av = avatares_jugadores.get(id)
		if av and is_instance_valid(av):
			if id == id_ganador:
				av.global_position = pos_meta
				if "sprite" in av and av.sprite:
					var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
					if prefijo == null: prefijo = "SEIK"
					if av.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
						av.sprite.play(prefijo + "_acierto")
			else:
				if "sprite" in av and av.sprite:
					var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
					if prefijo == null: prefijo = "SEIK"
					if av.sprite.sprite_frames.has_animation(prefijo + "_aturdido"):
						av.sprite.play(prefijo + "_aturdido")
						
	# Fijar la cámara de manera directa y firme en la meta (desactivar suavizado para evitar desvíos)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 3370
	camera.limit_bottom = 3370
	camera.position_smoothing_enabled = false
	var tw_cam = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_cam.tween_property(camera, "global_position", CENTRO_MUNDO, 0.7)
	tw_cam.tween_property(camera, "zoom", Vector2(1.35, 1.35), 0.7)
	await tw_cam.finished
	
	ejecutar_secuencia_victoria([id_ganador], pos_meta)
