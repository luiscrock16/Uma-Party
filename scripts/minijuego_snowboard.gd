extends BaseMinijuego

# ==============================================================================
# MINIJUEGO: CARRERA DE TRINEOS ALPINA (ESTILO CLUB PENGUIN: SLED RACER)
# ==============================================================================

const META_S: float = 28000.0 # ~1:15 min de carrera a velocidad media
const VEL_BASE: float = 430.0
const VEL_MAX_SLOPE: float = 480.0
const VEL_SPRINT: float = 760.0
const VEL_DESCONTROL: float = 210.0
const VEL_BOOST_BLOQUEO: float = 670.0

# Geometría empinada estilo Club Penguin: Sled Racer (Image 1 y 2)
const ANGULO_PISTA_DEG: float = 22.0
const ANGULO_PISTA_RAD: float = deg_to_rad(ANGULO_PISTA_DEG)
const DIR_PISTA: Vector2 = Vector2(0.92718385, 0.37460659)   # (cos(22 deg), sin(22 deg))
const NORM_PISTA: Vector2 = Vector2(-0.37460659, 0.92718385) # (-sin(22 deg), cos(22 deg))
const POS_INICIO: Vector2 = Vector2(400.0, 320.0)
const ANCHO_MEDIO_PISTA: float = 180.0
const OFFSETS_CARRILES = [-105.0, -35.0, 35.0, 105.0]

# Assets temáticos estilo Club Penguin: Sled Racer
var tex_tubos: Array = [
	preload("res://assets/minijuegos/snowboard/tube_red.png"),
	preload("res://assets/minijuegos/snowboard/tube_blue.png"),
	preload("res://assets/minijuegos/snowboard/tube_green.png"),
	preload("res://assets/minijuegos/snowboard/tube_pink.png")
]
var tex_rampa = preload("res://assets/minijuegos/snowboard/ramp_metal.png")
var tex_tronco = preload("res://assets/minijuegos/snowboard/log_hurdle.png")
var tex_pino = preload("res://assets/minijuegos/snowboard/pine_tree.png")
var tex_roca = preload("res://assets/minijuegos/snowboard/rock_snow.png")
var tex_estrella = preload("res://assets/minijuegos/snowboard/cp_star.png")
var tex_bump = preload("res://assets/minijuegos/snowboard/fx_bump_star.png")
var tex_sweat = preload("res://assets/minijuegos/snowboard/fx_sweat.png")

@onready var camera: Camera2D = $Camera2D
@onready var fondo_montana: Node2D = $FondoMontana
@onready var contenedor_obstaculos: Node2D = $ContenedorObstaculos
@onready var contenedor_efectos: Node2D = $ContenedorEfectos
@onready var hud: CanvasLayer = $HUD
@onready var panel_progreso: PanelContainer = $HUD/PanelProgreso
@onready var barra_progreso: ProgressBar = $HUD/PanelProgreso/Barra
@onready var contenedor_avatares_progreso: Control = $HUD/PanelProgreso/ContenedorAvatares
@onready var estrella_meta: TextureRect = $HUD/PanelProgreso/EstrellaMeta
@onready var panel_rebufo: PanelContainer = $HUD/PanelRebufo
@onready var barra_rebufo: ProgressBar = $HUD/PanelRebufo/BarraRebufo

# Minijuego de salida y cuenta atrás integrada
@onready var panel_salida: PanelContainer = $HUD/PanelSalida
@onready var label_conteo_salida: Label = $HUD/PanelSalida/VBox/LabelNumeroConteo
@onready var aguja_salida: Polygon2D = $HUD/PanelSalida/VBox/MarcoBarra/Aguja
@onready var label_indicacion_salida: Label = $HUD/PanelSalida/VBox/LabelIndicacion

var partida_iniciada: bool = false
var partida_terminada: bool = false
var tiempo_carrera: float = 0.0

# Estado del minijuego de salida interactivo
var en_minijuego_salida: bool = false
var tiempo_minijuego_salida: float = 0.0
const DURACION_MINIJUEGO_SALIDA: float = 3.2
var aguja_salida_pos: float = 0.5
var aguja_salida_detenida: bool = false
var calidad_salida_local: int = 1 # 0: Tropezón, 1: Normal, 2: Rápida, 3: Perfecta Turbo

# Control analógico debounced para joystick táctil / gamepad
var stick_en_neutro: bool = true

# Screen shake / trauma de cámara
var trauma_camara: float = 0.0

# Sincronización en red a 20 Hz
var timer_sync_red: float = 0.0

# Llegada a meta colectiva y podio
var orden_llegada_meta: Array = []
var primer_ganador_detectado: bool = false
var timer_espera_todos_meta: float = 0.0
var timer_espera_parada_final: float = 0.0
var celebracion_iniciada: bool = false
var transicion_podio_iniciada: bool = false

# Avatares, rigs e iconos de progreso
var avatares_jugadores: Dictionary = {}         # {id: CharacterBody2D}
var rigs_tubos: Dictionary = {}                 # {id: Node2D}
var estelas_rebufo: Dictionary = {}             # {id: Line2D}
var estado_corredores: Dictionary = {}          # {id: Dictionary}
var iconos_progreso_hud: Dictionary = {}        # {id: TextureRect}

var seed_pista: int = 12345
var pista_generada: bool = false
var ultimo_lider_id: int = -999

# Colores distintivos de ranuras de jugador (P1, P2, P3, P4)
const COLORES_RANURAS = [
	Color("#4ea317"), # P1: Verde
	Color("#e67e22"), # P2: Oro / Naranja
	Color("#2471a3"), # P3: Azul
	Color("#8e44ad")  # P4: Morado
]

# --- GEOMETRÍA DE LA PISTA Y CARRILES ---

func obtener_centro_pista(s: float) -> Vector2:
	return POS_INICIO + DIR_PISTA * s

func obtener_posicion_carril(s: float, carril: int) -> Vector2:
	var centro = obtener_centro_pista(s)
	var offset_lat = OFFSETS_CARRILES[clamp(carril, 0, 3)]
	return centro + NORM_PISTA * offset_lat

func _ready():
	modo_actual = Modo.FFA
	partida_iniciada = false
	partida_terminada = false
	en_minijuego_salida = false
	tiempo_carrera = 0.0
	trauma_camara = 0.0
	pista_generada = false
	orden_llegada_meta.clear()
	primer_ganador_detectado = false
	timer_espera_todos_meta = 0.0
	timer_espera_parada_final = 0.0
	celebracion_iniciada = false
	transicion_podio_iniciada = false
	
	if panel_rebufo:
		panel_rebufo.visible = true
	if barra_rebufo:
		barra_rebufo.value = 0.0
	if panel_salida:
		panel_salida.visible = false
		
	construir_escenografia_alpina()
		
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	jugadores_info.clear()
	for i in range(4):
		var id = i + 1
		jugadores_info[id] = {"equipo": i, "spawn": i, "es_jefe": false}
		if not has_node(str(id)):
			var av = preload("res://escenas/personaje_jugable.tscn").instantiate()
			av.name = str(id)
			add_child(av)
			av.configurar_visual(i, "P" + str(i + 1))
	aplicar_roles_locales()

# --- CONSTRUCCIÓN VISUAL DE LA PISTA ESTILO CLUB PENGUIN: SLED RACER ---

func construir_escenografia_alpina():
	if not fondo_montana: return
	for child in fondo_montana.get_children():
		child.queue_free()
		
	var s_min: float = -1200.0
	var s_max: float = META_S + 2800.0
	var paso: float = 350.0
	
	var pts_borde_sup = PackedVector2Array()
	var pts_borde_inf = PackedVector2Array()
	var pts_acantilado_top = PackedVector2Array()
	var pts_ladera_bot = PackedVector2Array()
	var pts_sombra_sup = PackedVector2Array()
	
	var cur_s = s_min
	while cur_s <= s_max:
		var c = obtener_centro_pista(cur_s)
		var b_sup = c - NORM_PISTA * ANCHO_MEDIO_PISTA
		var b_inf = c + NORM_PISTA * ANCHO_MEDIO_PISTA
		var top_c = b_sup - Vector2(0.0, 420.0)
		var bot_l = b_inf + Vector2(0.0, 680.0)
		var sombra_p = b_sup + NORM_PISTA * 22.0
		
		pts_borde_sup.append(b_sup)
		pts_borde_inf.append(b_inf)
		pts_acantilado_top.append(top_c)
		pts_ladera_bot.append(bot_l)
		pts_sombra_sup.append(sombra_p)
		
		cur_s += paso
		
	# 1. Acantilado de roca superior (Pared oscura con silueta cartoon como Image 1)
	var poly_acantilado = PackedVector2Array()
	poly_acantilado.append_array(pts_acantilado_top)
	for k in range(pts_borde_sup.size() - 1, -1, -1):
		poly_acantilado.append(pts_borde_sup[k])
		
	var nodo_acantilado = Polygon2D.new()
	nodo_acantilado.name = "ParedAcantiladoRoca"
	nodo_acantilado.polygon = poly_acantilado
	nodo_acantilado.color = Color("#323740")
	fondo_montana.add_child(nodo_acantilado)
	
	# Capa de nieve en la cima del acantilado
	var pts_nieve_cima = PackedVector2Array()
	for p in pts_acantilado_top:
		pts_nieve_cima.append(p - Vector2(0.0, 45.0))
	for k in range(pts_acantilado_top.size() - 1, -1, -1):
		pts_nieve_cima.append(pts_acantilado_top[k])
		
	var nodo_nieve_cima = Polygon2D.new()
	nodo_nieve_cima.name = "NieveCimaAcantilado"
	nodo_nieve_cima.polygon = pts_nieve_cima
	nodo_nieve_cima.color = Color("#ffffff")
	fondo_montana.add_child(nodo_nieve_cima)
	
	var linea_cima = Line2D.new()
	linea_cima.name = "BordeCima"
	linea_cima.points = pts_acantilado_top
	linea_cima.width = 5.0
	linea_cima.default_color = Color("#16181c")
	fondo_montana.add_child(linea_cima)
	
	# 2. Ladera inferior de nieve (Valle suave hacia abajo)
	var poly_ladera = PackedVector2Array()
	poly_ladera.append_array(pts_borde_inf)
	for k in range(pts_ladera_bot.size() - 1, -1, -1):
		poly_ladera.append(pts_ladera_bot[k])
		
	var nodo_ladera = Polygon2D.new()
	nodo_ladera.name = "LaderaInferiorNieve"
	nodo_ladera.polygon = poly_ladera
	nodo_ladera.color = Color("#eef5fc")
	fondo_montana.add_child(nodo_ladera)
	
	# 3. Pista de Nieve blanca pura central
	var poly_pista = PackedVector2Array()
	poly_pista.append_array(pts_borde_sup)
	for k in range(pts_borde_inf.size() - 1, -1, -1):
		poly_pista.append(pts_borde_inf[k])
		
	var nodo_pista = Polygon2D.new()
	nodo_pista.name = "PistaNieveCentral"
	nodo_pista.polygon = poly_pista
	nodo_pista.color = Color("#ffffff")
	fondo_montana.add_child(nodo_pista)
	
	# 4. Sombra suave bajo el borde superior (Da relieve y profundidad estilo Club Penguin)
	var poly_sombra = PackedVector2Array()
	poly_sombra.append_array(pts_borde_sup)
	for k in range(pts_sombra_sup.size() - 1, -1, -1):
		poly_sombra.append(pts_sombra_sup[k])
		
	var nodo_sombra = Polygon2D.new()
	nodo_sombra.name = "SombraBordeSuperior"
	nodo_sombra.polygon = poly_sombra
	nodo_sombra.color = Color(0.82, 0.90, 0.97, 0.8)
	fondo_montana.add_child(nodo_sombra)
	
	# 5. Bordes gruesos de contorno cartoon negro
	var linea_sup = Line2D.new()
	linea_sup.name = "ContornoBordeSuperior"
	linea_sup.points = pts_borde_sup
	linea_sup.width = 5.5
	linea_sup.default_color = Color("#16181c")
	fondo_montana.add_child(linea_sup)
	
	var linea_inf = Line2D.new()
	linea_inf.name = "ContornoBordeInferior"
	linea_inf.points = pts_borde_inf
	linea_inf.width = 5.5
	linea_inf.default_color = Color("#16181c")
	fondo_montana.add_child(linea_inf)

func aplicar_roles_locales():
	avatares_jugadores.clear()
	estado_corredores.clear()
	rigs_tubos.clear()
	estelas_rebufo.clear()
	iconos_progreso_hud.clear()
	orden_llegada_meta.clear()
	primer_ganador_detectado = false
	timer_espera_todos_meta = 0.0
	timer_espera_parada_final = 0.0
	celebracion_iniciada = false
	transicion_podio_iniciada = false
	
	if contenedor_avatares_progreso:
		for h in contenedor_avatares_progreso.get_children():
			h.queue_free()
	
	var i = 0
	for id in jugadores_info.keys():
		var av = get_node_or_null(str(id))
		if not av and get_tree().root:
			av = get_tree().root.find_child(str(id), true, false)
			
		var carril_idx = i % 4
		var spawn_s = 200.0 + (i * 35.0)
		var spawn_pos = obtener_posicion_carril(spawn_s, carril_idx)
		
		if av:
			avatares_jugadores[id] = av
			av.global_position = spawn_pos
			av.bloquear_controles(true)
			av.modulate = Color.WHITE
			av.scale = Vector2.ONE
			av.visible = true
			av.z_index = 10
			if "set_movimiento_actual" in av:
				av.set_movimiento_actual = PersonajeJugable.TipoMovimiento.NORMAL_SOLO
				
			crear_tubo_rig(av, id, i)
			
		estado_corredores[id] = {
			"carril": carril_idx,
			"pos_s": spawn_s,
			"target_pos_s": spawn_s,
			"lateral_offset": OFFSETS_CARRILES[carril_idx],
			"target_offset": OFFSETS_CARRILES[carril_idx],
			"pos_x": spawn_pos.x,
			"pos_y": spawn_pos.y,
			"vel_s": 0.0,
			"rebufo": 0.0,
			"rebufo_listo": false,
			"en_sprint": false,
			"timer_sprint": 0.0,
			"bloqueando": false,
			"timer_bloqueo": 0.0,
			"cooldown_bloqueo": 0.0,
			"descontrol": false,
			"timer_descontrol": 0.0,
			"en_el_aire": false,
			"timer_aire": 0.0,
			"calidad_salida": 1,
			"tilt_angle": 0.0,
			"cooldown_carril": 0.0,
			"ha_cruzado_meta": false
		}
		
		crear_icono_rostro_progreso(id, i, av)
		i += 1
		
	# --- SINCRONIZACIÓN GARANTIZADA DE LA PISTA Y CUENTA ATRÁS ---
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		seed_pista = randi()
		pista_generada = true
		if multiplayer.has_multiplayer_peer():
			sincronizar_pista_rpc.rpc(seed_pista)
		else:
			sincronizar_pista_rpc(seed_pista)
		get_tree().create_timer(0.35).timeout.connect(func():
			if multiplayer.has_multiplayer_peer():
				iniciar_cuenta_atras_sincronizada_rpc.rpc()
			else:
				iniciar_cuenta_atras_sincronizada_rpc()
		)
	else:
		solicitar_seed_pista_rpc.rpc_id(1)
			
	configurar_zona_meta_y_espectadores()

@rpc("any_peer", "call_remote", "reliable")
func solicitar_seed_pista_rpc():
	if multiplayer.is_server():
		var remitente = multiplayer.get_remote_sender_id()
		sincronizar_pista_rpc.rpc_id(remitente, seed_pista)

@rpc("authority", "call_local", "reliable")
func sincronizar_pista_rpc(p_seed: int):
	seed_pista = p_seed
	generar_pista_nevada(p_seed)
	pista_generada = true

@rpc("authority", "call_local", "reliable")
func iniciar_cuenta_atras_sincronizada_rpc():
	iniciar_minijuego_salida()

func crear_icono_rostro_progreso(id: int, idx: int, av: CharacterBody2D):
	if not contenedor_avatares_progreso: return
	
	var prefijo = "SEIK"
	if av and "prefijo_personaje" in av and str(av.prefijo_personaje) != "":
		prefijo = str(av.prefijo_personaje)
		
	var icono = TextureRect.new()
	icono.name = "IconoP_" + str(id)
	icono.custom_minimum_size = Vector2(28, 28)
	icono.size = Vector2(28, 28)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var ruta_tex = "res://assets/Sprites/iconos_personajes/icono_" + prefijo + ".png"
	if ResourceLoader.exists(ruta_tex):
		icono.texture = load(ruta_tex)
		
	var col_slot = COLORES_RANURAS[idx % COLORES_RANURAS.size()]
	var marco = ReferenceRect.new()
	marco.name = "BordeColor"
	marco.border_color = col_slot
	marco.border_width = 2.5
	marco.editor_only = false
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icono.add_child(marco)
	
	contenedor_avatares_progreso.add_child(icono)
	iconos_progreso_hud[id] = icono

# --- RIG VISUAL DE TUBO DE CLUB PENGUIN ---

func crear_tubo_rig(av: CharacterBody2D, id: int, idx_jugador: int):
	var viejo = av.get_node_or_null("TuboRig")
	if viejo:
		av.remove_child(viejo)
		viejo.queue_free()
	var viejo_s = av.get_node_or_null("SombraNieve")
	if viejo_s:
		av.remove_child(viejo_s)
		viejo_s.queue_free()
	
	# 1. Sombra cartoon a ras de suelo en la nieve (vinculada directamente al avatar)
	var sombra = Polygon2D.new()
	sombra.name = "SombraNieve"
	sombra.color = Color(0.1, 0.15, 0.25, 0.35)
	sombra.polygon = PackedVector2Array([
		Vector2(-42, 14), Vector2(42, 14), Vector2(32, 26), Vector2(-32, 26)
	])
	sombra.z_index = -2
	av.add_child(sombra)
	
	# 2. Rig del neumático de nieve y efectos dinámicos
	var rig = Node2D.new()
	rig.name = "TuboRig"
	rig.z_index = -1
	rig.rotation = ANGULO_PISTA_RAD
	
	var spr_tubo = Sprite2D.new()
	spr_tubo.name = "SpriteTubo"
	spr_tubo.texture = tex_tubos[idx_jugador % tex_tubos.size()]
	spr_tubo.position = Vector2(0, 10)
	spr_tubo.scale = Vector2(0.85, 0.85)
	rig.add_child(spr_tubo)
	
	var part_nieve = CPUParticles2D.new()
	part_nieve.name = "SprayNieve"
	part_nieve.amount = 24
	part_nieve.lifetime = 0.38
	part_nieve.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	part_nieve.emission_rect_extents = Vector2(16, 3)
	part_nieve.position = Vector2(-28, 14)
	part_nieve.direction = -DIR_PISTA
	part_nieve.spread = 20.0
	part_nieve.gravity = Vector2(0, 320)
	part_nieve.initial_velocity_min = 110.0
	part_nieve.initial_velocity_max = 190.0
	part_nieve.scale_amount_min = 2.0
	part_nieve.scale_amount_max = 4.5
	part_nieve.color = Color(0.96, 0.98, 1.0, 0.9)
	rig.add_child(part_nieve)
	
	var part_rebufo = CPUParticles2D.new()
	part_rebufo.name = "VortexRebufo"
	part_rebufo.emitting = false
	part_rebufo.amount = 18
	part_rebufo.lifetime = 0.28
	part_rebufo.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	part_rebufo.emission_sphere_radius = 24.0
	part_rebufo.direction = -DIR_PISTA
	part_rebufo.spread = 15.0
	part_rebufo.gravity = Vector2.ZERO
	part_rebufo.initial_velocity_min = 80.0
	part_rebufo.initial_velocity_max = 150.0
	part_rebufo.scale_amount_min = 2.5
	part_rebufo.scale_amount_max = 5.0
	part_rebufo.color = Color(0.25, 0.95, 1.0, 0.8)
	rig.add_child(part_rebufo)
	
	var escudo = Polygon2D.new()
	escudo.name = "EscudoHielo"
	escudo.color = Color(0.3, 0.85, 1.0, 0.55)
	escudo.polygon = PackedVector2Array([
		Vector2(26, -36), Vector2(38, 0), Vector2(26, 36), Vector2(16, 26), Vector2(22, 0), Vector2(16, -26)
	])
	escudo.visible = false
	rig.add_child(escudo)
	
	av.add_child(rig)
	rigs_tubos[id] = rig
	
	var spr_pj = av.get_node_or_null("Sprite")
	if spr_pj:
		spr_pj.position.y = -10.0
		
	var estela = Line2D.new()
	estela.name = "EstelaViento"
	estela.width = 3.5
	estela.default_color = Color(0.3, 0.9, 1.0, 0.65)
	estela.visible = false
	add_child(estela)
	estelas_rebufo[id] = estela

# --- GENERACIÓN DE PISTA: PROGRESIÓN GRADUAL Y ORIENTACIÓN DIAGONAL ---

func generar_pista_nevada(p_seed: int):
	for h in contenedor_obstaculos.get_children():
		contenedor_obstaculos.remove_child(h)
		h.queue_free()
		
	var rng = RandomNumberGenerator.new()
	rng.seed = p_seed
	
	# Pinos decorativos en la cornisa del acantilado superior (Image 1)
	for ps in range(-400, int(META_S), 360):
		var pino = Sprite2D.new()
		pino.texture = tex_pino
		var c = obtener_centro_pista(float(ps))
		var pos_cliff = c - NORM_PISTA * 220.0 - Vector2(0.0, 380.0) + Vector2(rng.randf_range(-25, 25), rng.randf_range(-15, 15))
		pino.position = pos_cliff
		pino.scale = Vector2(0.85, 0.85)
		pino.z_index = -12
		pino.rotation = 0.0
		contenedor_obstaculos.add_child(pino)
		
		if rng.randf() < 0.4:
			var roca = Sprite2D.new()
			roca.texture = tex_roca
			roca.position = pos_cliff + Vector2(rng.randf_range(60, 110), 40.0)
			roca.scale = Vector2(0.6, 0.6)
			roca.z_index = -11
			roca.rotation = 0.0
			contenedor_obstaculos.add_child(roca)
	
	# Pinos decorativos en la ladera inferior
	for ps in range(-400, int(META_S), 420):
		var pino_inf = Sprite2D.new()
		pino_inf.texture = tex_pino
		var c = obtener_centro_pista(float(ps))
		var pos_ladera = c + NORM_PISTA * 250.0 + Vector2(rng.randf_range(-25, 25), rng.randf_range(-10, 15))
		pino_inf.position = pos_ladera
		pino_inf.scale = Vector2(0.88, 0.88)
		pino_inf.z_index = 10
		pino_inf.rotation = 0.0
		contenedor_obstaculos.add_child(pino_inf)
	
	# --- GENERACIÓN PROGRESIVA DE OBSTÁCULOS EN PISTA ---
	var cur_s = 1300.0
	var ultimo_carril_usado = -1
	
	while cur_s < META_S - 1000.0:
		var paso_s: float = 600.0
		var cant: int = 1
		
		if cur_s < 7000.0:
			paso_s = rng.randf_range(850.0, 1150.0)
			cant = 1
		elif cur_s < 17000.0:
			paso_s = rng.randf_range(580.0, 780.0)
			cant = 1 if rng.randf() < 0.72 else 2
		else:
			paso_s = rng.randf_range(460.0, 620.0)
			cant = 1 if rng.randf() < 0.55 else 2
			
		var carriles_disp = [0, 1, 2, 3]
		if ultimo_carril_usado != -1 and carriles_disp.has(ultimo_carril_usado):
			carriles_disp.erase(ultimo_carril_usado)
		# Barajado determinista estricto con semilla sincronizada (Fisher-Yates)
		for idx_sh in range(carriles_disp.size() - 1, 0, -1):
			var idx_rnd = rng.randi_range(0, idx_sh)
			var tmp_c = carriles_disp[idx_sh]
			carriles_disp[idx_sh] = carriles_disp[idx_rnd]
			carriles_disp[idx_rnd] = tmp_c
		
		for c in range(cant):
			var carril = carriles_disp[c]
			ultimo_carril_usado = carril
			var tipo = rng.randi_range(0, 2) # 0: Rampa metal, 1: Tronco, 2: Roca
			crear_objeto_pista(cur_s, carril, tipo)
			
		cur_s += paso_s

func crear_objeto_pista(pos_s: float, carril: int, tipo: int):
	var pos = obtener_posicion_carril(pos_s, carril)
	var nodo = Area2D.new()
	nodo.position = pos
	nodo.set_meta("pos_s", pos_s)
	nodo.set_meta("carril", carril)
	nodo.set_meta("tipo_obstaculo", tipo)
	
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	
	match tipo:
		0: # Rampa de metal (Alineada con la bajada como Image 1)
			nodo.rotation = ANGULO_PISTA_RAD
			rect.size = Vector2(52, 34)
			col.shape = rect
			nodo.add_child(col)
			
			var spr = Sprite2D.new()
			spr.texture = tex_rampa
			spr.scale = Vector2(0.55, 0.55)
			nodo.add_child(spr)
			
		1: # Tronco con nieve (Atravesado sobre la pista como Image 2)
			nodo.rotation = ANGULO_PISTA_RAD - PI / 2.0
			rect.size = Vector2(34, 56)
			col.shape = rect
			nodo.add_child(col)
			
			var spr = Sprite2D.new()
			spr.texture = tex_tronco
			spr.scale = Vector2(0.52, 0.52)
			nodo.add_child(spr)
			
		2: # Roca con nieve (Vertical en la nieve)
			nodo.rotation = 0.0
			rect.size = Vector2(40, 28)
			col.shape = rect
			nodo.add_child(col)
			
			var spr = Sprite2D.new()
			spr.texture = tex_roca
			spr.scale = Vector2(0.52, 0.52)
			nodo.add_child(spr)
			
	contenedor_obstaculos.add_child(nodo)

# --- META EN EL VALLE EXACTAMENTE ALINEADA CON LA COLINA ---

func configurar_zona_meta_y_espectadores():
	var meta_node = get_node_or_null("ZonaMetaVisual")
	if not meta_node:
		meta_node = Node2D.new()
		meta_node.name = "ZonaMetaVisual"
		add_child(meta_node)
	else:
		for h in meta_node.get_children(): h.queue_free()
		
	var c_meta = obtener_centro_pista(META_S)
	var p_sup = c_meta - NORM_PISTA * ANCHO_MEDIO_PISTA
	var p_inf = c_meta + NORM_PISTA * ANCHO_MEDIO_PISTA
	
	# 1. Línea de Meta en el suelo de nieve: cruza exactamente de borde superior a borde inferior
	var base_blanca = Line2D.new()
	base_blanca.name = "BaseMetaSuelo"
	base_blanca.points = PackedVector2Array([p_sup, p_inf])
	base_blanca.width = 24.0
	base_blanca.default_color = Color("#ffffff")
	base_blanca.z_index = -5
	meta_node.add_child(base_blanca)
	
	var borde_meta_sup = Line2D.new()
	borde_meta_sup.points = PackedVector2Array([p_sup - DIR_PISTA * 12.0, p_inf - DIR_PISTA * 12.0])
	borde_meta_sup.width = 3.5
	borde_meta_sup.default_color = Color("#16181c")
	borde_meta_sup.z_index = -4
	meta_node.add_child(borde_meta_sup)
	
	var borde_meta_inf = Line2D.new()
	borde_meta_inf.points = PackedVector2Array([p_sup + DIR_PISTA * 12.0, p_inf + DIR_PISTA * 12.0])
	borde_meta_inf.width = 3.5
	borde_meta_inf.default_color = Color("#16181c")
	borde_meta_inf.z_index = -4
	meta_node.add_child(borde_meta_inf)
	
	# Franjas rojas de cuadros de meta alternados a lo largo de la línea
	var num_cuadros = 12
	for k in range(num_cuadros):
		if k % 2 == 0:
			var t0 = float(k) / float(num_cuadros)
			var t1 = float(k + 1) / float(num_cuadros)
			var pt0 = p_sup.lerp(p_inf, t0)
			var pt1 = p_sup.lerp(p_inf, t1)
			var cuadro_rojo = Line2D.new()
			cuadro_rojo.points = PackedVector2Array([pt0, pt1])
			cuadro_rojo.width = 18.0
			cuadro_rojo.default_color = Color("#e52b2b")
			cuadro_rojo.z_index = -4
			meta_node.add_child(cuadro_rojo)
			
	# 2. Postes laterales de esquí en los extremos exactos de la pista
	for extremo in [p_sup, p_inf]:
		var poste = Node2D.new()
		poste.position = extremo
		poste.z_index = 8
		
		# Poste a rayas rojas y blancas
		var rect_poste = ColorRect.new()
		rect_poste.color = Color("#ffffff")
		rect_poste.size = Vector2(14, 85)
		rect_poste.position = Vector2(-7, -80)
		poste.add_child(rect_poste)
		
		for r in range(4):
			var raya = ColorRect.new()
			raya.color = Color("#e52b2b")
			raya.size = Vector2(14, 10)
			raya.position = Vector2(-7, -75 + r * 20)
			poste.add_child(raya)
			
		var borde_p = ReferenceRect.new()
		borde_p.border_color = Color("#16181c")
		borde_p.border_width = 2.5
		borde_p.editor_only = false
		borde_p.size = Vector2(14, 85)
		borde_p.position = Vector2(-7, -80)
		poste.add_child(borde_p)
		
		# Estrella dorada en el tope del poste
		var star_top = Sprite2D.new()
		star_top.texture = tex_estrella
		star_top.scale = Vector2(0.5, 0.5)
		star_top.position = Vector2(0, -88)
		poste.add_child(star_top)
		
		meta_node.add_child(poste)
		
	# 3. Cartel flotante "★ M E T A ★" sobre el arco de meta
	var cable_arco = Line2D.new()
	cable_arco.points = PackedVector2Array([
		p_sup + Vector2(0, -75),
		c_meta + Vector2(0, -85),
		p_inf + Vector2(0, -75)
	])
	cable_arco.width = 4.0
	cable_arco.default_color = Color("#16181c")
	cable_arco.z_index = 10
	meta_node.add_child(cable_arco)
	
	var cartel_pancarta = Node2D.new()
	cartel_pancarta.position = c_meta + Vector2(0, -85)
	cartel_pancarta.rotation = 0.0 # Horizontal para máxima legibilidad cartoon
	cartel_pancarta.z_index = 12
	
	var fondo_cartel = Polygon2D.new()
	fondo_cartel.color = Color("#e52b2b")
	fondo_cartel.polygon = PackedVector2Array([
		Vector2(-95, -25), Vector2(95, -25), Vector2(90, 20), Vector2(-90, 20)
	])
	cartel_pancarta.add_child(fondo_cartel)
	
	var borde_cartel = Line2D.new()
	borde_cartel.points = PackedVector2Array([
		Vector2(-95, -25), Vector2(95, -25), Vector2(90, 20), Vector2(-90, 20), Vector2(-95, -25)
	])
	borde_cartel.width = 3.5
	borde_cartel.default_color = Color("#ffd700")
	cartel_pancarta.add_child(borde_cartel)
	
	var label_m = Label.new()
	label_m.text = "★ M E T A ★"
	label_m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_m.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_m.size = Vector2(180, 40)
	label_m.position = Vector2(-90, -23)
	label_m.add_theme_font_size_override("font_size", 22)
	label_m.add_theme_color_override("font_color", Color(1, 0.95, 0.2))
	label_m.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label_m.add_theme_constant_override("outline_size", 5)
	cartel_pancarta.add_child(label_m)
	
	meta_node.add_child(cartel_pancarta)
	
	# 4. Cabaña alpina de madera en la ladera superior
	var cabana = Node2D.new()
	cabana.name = "CabanaAlpina"
	cabana.position = p_sup - NORM_PISTA * 70.0 + DIR_PISTA * 220.0
	cabana.z_index = -3
	
	var pared = Polygon2D.new()
	pared.color = Color(0.48, 0.3, 0.16)
	pared.polygon = PackedVector2Array([
		Vector2(-85, 0), Vector2(85, 0), Vector2(85, 90), Vector2(-85, 90)
	])
	cabana.add_child(pared)
	
	var techo = Polygon2D.new()
	techo.color = Color(0.96, 0.98, 1.0)
	techo.polygon = PackedVector2Array([
		Vector2(0, -45), Vector2(110, 5), Vector2(-110, 5)
	])
	cabana.add_child(techo)
	
	var chimenea = ColorRect.new()
	chimenea.color = Color(0.35, 0.35, 0.4)
	chimenea.position = Vector2(40, -55)
	chimenea.size = Vector2(18, 28)
	cabana.add_child(chimenea)
	
	meta_node.add_child(cabana)
	
	# 5. Espectadores animando (Yayoi Akikawa & Tazuna Hayakawa) en la ladera inferior
	var pos_esp = p_inf + NORM_PISTA * 60.0 + DIR_PISTA * 80.0
	
	var spr_dir = Sprite2D.new()
	spr_dir.texture = load("res://assets/Sprites/NPCS/Yayoi Akikawa/akyy_ST01_00.png")
	spr_dir.position = pos_esp
	spr_dir.scale = Vector2(1.2, 1.2)
	spr_dir.z_index = 9
	meta_node.add_child(spr_dir)
	
	var spr_taz = Sprite2D.new()
	spr_taz.texture = load("res://assets/Sprites/NPCS/Tazuna Hayakawa/hatz_ST01_00.png")
	spr_taz.position = pos_esp + Vector2(75, 0)
	spr_taz.scale = Vector2(1.2, 1.2)
	spr_taz.z_index = 9
	meta_node.add_child(spr_taz)

# --- OVERRIDE DE CUENTA ATRÁS: PANEL DE SALIDA INTERACTIVO INTEGRADO ---

func ejecutar_overlay_cuenta_atras():
	pass

func iniciar_minijuego_salida():
	en_minijuego_salida = true
	tiempo_minijuego_salida = 0.0
	aguja_salida_pos = 0.5
	aguja_salida_detenida = false
	calidad_salida_local = 1
	
	if panel_salida:
		panel_salida.visible = true
		panel_salida.modulate.a = 1.0
	if label_conteo_salida:
		label_conteo_salida.text = "3"
		label_conteo_salida.modulate = Color(1, 0.95, 0.3)
	if label_indicacion_salida:
		label_indicacion_salida.text = "¡Presiona ESPACIO, W/S o Toca para bloquear la aguja en el CENTRO!"
		label_indicacion_salida.modulate = Color(0.85, 0.95, 1.0)
		
	Global.establecer_texto_accion_tactil("¡BLOQUEAR!")

# --- MANEJO DE ENTRADAS ---

func _input(event: InputEvent):
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var st = estado_corredores.get(mi_id)
	
	# 1. Pulsación durante el conteo de salida para fijar la aguja
	if en_minijuego_salida and not aguja_salida_detenida:
		var pulsado_salida = false
		if event is InputEventKey and event.pressed and not event.echo:
			pulsado_salida = true
		elif event is InputEventMouseButton and event.pressed:
			pulsado_salida = true
		elif event is InputEventScreenTouch and event.pressed:
			pulsado_salida = true
		elif event.is_action_pressed("espacio") or event.is_action_pressed("ui_accept"):
			pulsado_salida = true
			
		if pulsado_salida:
			detener_aguja_salida(mi_id)
			return
			
	if not partida_iniciada or partida_terminada or not st: return
	if st.get("ha_cruzado_meta", false): return
	
	# 2. Cambio de Carril ÚNICO por evento
	var cambio_dir: int = 0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W or event.keycode == KEY_UP:
			cambio_dir = -1
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			cambio_dir = 1
	elif event.is_action_pressed("w") or event.is_action_pressed("ui_up"):
		cambio_dir = -1
	elif event.is_action_pressed("s") or event.is_action_pressed("ui_down"):
		cambio_dir = 1
		
	if cambio_dir != 0:
		solicitar_cambio_carril(mi_id, cambio_dir)
		return
		
	# 3. Acción táctil / Botón Espacio: Sprint de rebufo o Bloqueo defensivo
	var accion_pulsada = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			accion_pulsada = true
	elif event.is_action_pressed("espacio") or event.is_action_pressed("ui_accept"):
		accion_pulsada = true
		
	if accion_pulsada:
		if st["rebufo_listo"]:
			solicitar_sprint_adelanto(mi_id)
		elif st["cooldown_bloqueo"] <= 0.0 and not st["bloqueando"]:
			solicitar_bloqueo(mi_id)

func solicitar_cambio_carril(id: int, dir: int):
	var st = estado_corredores.get(id)
	if not st or st["descontrol"] or st.get("ha_cruzado_meta", false): return
	if st.get("cooldown_carril", 0.0) > 0.0: return
	
	st["cooldown_carril"] = 0.16
	cambiar_carril_local(id, dir)

func cambiar_carril_local(id: int, dir: int):
	var st = estado_corredores.get(id)
	if not st or st["descontrol"]: return
	
	var nuevo_carril = clamp(st["carril"] + dir, 0, 3)
	if nuevo_carril != st["carril"]:
		st["carril"] = nuevo_carril
		st["tilt_angle"] = -12.0 if dir < 0 else 12.0

func detener_aguja_salida(id: int):
	aguja_salida_detenida = true
	var pos = aguja_salida_pos
	var dist_centro = abs(pos - 0.5)
	
	if dist_centro <= 0.055:
		calidad_salida_local = 3
		disparar_particulas_estrellas(aguja_salida.global_position, 8)
		if label_indicacion_salida:
			label_indicacion_salida.text = "★ ¡SALIDA PERFECTA TURBO FIJADA! ★"
			label_indicacion_salida.modulate = Color(0.25, 1.0, 0.45)
	elif dist_centro <= 0.15:
		calidad_salida_local = 2
		if label_indicacion_salida:
			label_indicacion_salida.text = "⚡ ¡SALIDA RÁPIDA FIJADA! ⚡"
			label_indicacion_salida.modulate = Color(1.0, 0.9, 0.25)
	elif dist_centro <= 0.30:
		calidad_salida_local = 1
		if label_indicacion_salida:
			label_indicacion_salida.text = "SALIDA NORMAL FIJADA"
			label_indicacion_salida.modulate = Color(1.0, 0.65, 0.2)
	else:
		calidad_salida_local = 0
		if label_indicacion_salida:
			label_indicacion_salida.text = "¡TROPEZÓN EN LA NIEVE!"
			label_indicacion_salida.modulate = Color(1.0, 0.3, 0.3)
			
	var st = estado_corredores.get(id)
	if st:
		st["calidad_salida"] = calidad_salida_local
		
	if multiplayer.has_multiplayer_peer():
		registrar_calidad_salida_rpc.rpc(id, calidad_salida_local)

@rpc("any_peer", "call_local", "reliable")
func registrar_calidad_salida_rpc(id: int, calidad: int):
	var st = estado_corredores.get(id)
	if st:
		st["calidad_salida"] = calidad

@rpc("authority", "call_local", "reliable")
func lanzar_carrera_sincronizada_rpc():
	finalizar_minijuego_salida_y_lanzar()

func finalizar_minijuego_salida_y_lanzar():
	if partida_iniciada: return
	en_minijuego_salida = false
	partida_iniciada = true
	bloquear_jugadores(false)
	
	if panel_salida:
		var tw = create_tween()
		tw.tween_property(panel_salida, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func(): panel_salida.visible = false)
		
	Global.establecer_texto_accion_tactil("DEFENSA")
	
	for id in estado_corredores.keys():
		var st = estado_corredores[id]
		var av = avatares_jugadores.get(id)
		
		match st["calidad_salida"]:
			3:
				st["vel_s"] = 640.0
				reproducir_animacion_jugador(av, "acierto")
				if av:
					disparar_particulas_estrellas(av.global_position, 14)
				agregar_trauma(0.35)
			2:
				st["vel_s"] = 510.0
				reproducir_animacion_jugador(av, "intro")
			1:
				st["vel_s"] = VEL_BASE
				reproducir_animacion_jugador(av, "idle")
			0:
				st["vel_s"] = 230.0
				st["descontrol"] = true
				st["timer_descontrol"] = 1.1
				reproducir_animacion_jugador(av, "resbalar")
				if av:
					disparar_particulas_sudor(av.global_position)

func solicitar_sprint_adelanto(id: int):
	activar_sprint_adelanto_local(id)
	if multiplayer.has_multiplayer_peer():
		activar_sprint_adelanto_rpc.rpc(id)

func activar_sprint_adelanto_local(id: int):
	var st = estado_corredores.get(id)
	if not st or st.get("ha_cruzado_meta", false): return
	
	st["en_sprint"] = true
	st["timer_sprint"] = 1.35
	st["vel_s"] = VEL_SPRINT
	st["rebufo"] = 0.0
	st["rebufo_listo"] = false
	
	var av = avatares_jugadores.get(id)
	reproducir_animacion_jugador(av, "ataque")
	if av:
		disparar_particulas_estrellas(av.global_position, 8)
	agregar_trauma(0.2)

@rpc("any_peer", "call_remote", "reliable")
func activar_sprint_adelanto_rpc(id: int):
	activar_sprint_adelanto_local(id)

func solicitar_bloqueo(id: int):
	activar_bloqueo_local(id)
	if multiplayer.has_multiplayer_peer():
		activar_bloqueo_rpc.rpc(id)

func activar_bloqueo_local(id: int):
	var st = estado_corredores.get(id)
	if not st or st["cooldown_bloqueo"] > 0.0 or st.get("ha_cruzado_meta", false): return
	
	st["bloqueando"] = true
	st["timer_bloqueo"] = 0.6
	st["cooldown_bloqueo"] = 2.0
	
	var rig = rigs_tubos.get(id)
	if rig:
		var esc = rig.get_node_or_null("EscudoHielo")
		if esc:
			esc.visible = true
			var tw = create_tween()
			tw.tween_property(esc, "scale", Vector2(1.2, 1.2), 0.15)
			tw.tween_property(esc, "scale", Vector2.ONE, 0.15)

@rpc("any_peer", "call_remote", "reliable")
func activar_bloqueo_rpc(id: int):
	activar_bloqueo_local(id)

# --- BUCLE PRINCIPAL DE FÍSICA Y SIMULACIÓN ---

func _process(delta):
	if partida_iniciada and not partida_terminada:
		var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		var st_mi = estado_corredores.get(mi_id)
		if st_mi and not st_mi.get("ha_cruzado_meta", false):
			var axis_y = Input.get_axis("w", "s")
			if not is_zero_approx(axis_y):
				if stick_en_neutro:
					if axis_y < -0.45:
						solicitar_cambio_carril(mi_id, -1)
						stick_en_neutro = false
					elif axis_y > 0.45:
						solicitar_cambio_carril(mi_id, 1)
						stick_en_neutro = false
			else:
				stick_en_neutro = true
			
	if trauma_camara > 0.0:
		trauma_camara = max(0.0, trauma_camara - delta * 1.6)
		var shake_amount = pow(trauma_camara, 2.0) * 14.0
		camera.offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
	else:
		camera.offset = Vector2.ZERO

func _physics_process(delta):
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	
	# 1. Proceso de salida
	if en_minijuego_salida:
		tiempo_minijuego_salida += delta
		
		if label_conteo_salida:
			if tiempo_minijuego_salida < 1.0:
				label_conteo_salida.text = "3"
				label_conteo_salida.modulate = Color(1, 0.95, 0.3)
			elif tiempo_minijuego_salida < 2.0:
				label_conteo_salida.text = "2"
				label_conteo_salida.modulate = Color(1, 0.65, 0.2)
			elif tiempo_minijuego_salida < 2.8:
				label_conteo_salida.text = "1"
				label_conteo_salida.modulate = Color(1, 0.35, 0.2)
			else:
				label_conteo_salida.text = "¡YA!"
				label_conteo_salida.modulate = Color(0.25, 1.0, 0.45)
				
		if not aguja_salida_detenida:
			aguja_salida_pos = (sin(tiempo_minijuego_salida * 7.5) + 1.0) * 0.5
			if aguja_salida:
				aguja_salida.position.x = lerp(12.0, 348.0, aguja_salida_pos)
				
		if tiempo_minijuego_salida >= DURACION_MINIJUEGO_SALIDA:
			if not aguja_salida_detenida:
				detener_aguja_salida(mi_id)
			if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
				if multiplayer.has_multiplayer_peer():
					lanzar_carrera_sincronizada_rpc.rpc()
				else:
					lanzar_carrera_sincronizada_rpc()
		return
		
	if not partida_iniciada or celebracion_iniciada: return
	
	tiempo_carrera += delta
	var id_lider = -1
	var mayor_s = -9999.0
	
	# 2. Actualizar corredores
	for id in estado_corredores.keys():
		var st = estado_corredores[id]
		var av = avatares_jugadores.get(id)
		if not av or not is_instance_valid(av): continue
		
		var es_local = (id == mi_id)
		var altura_actual: float = 0.0
		
		if es_local:
			# --- SIMULACIÓN AUTORITATIVA DEL CORREDOR LOCAL ---
			if st["cooldown_carril"] > 0.0:
				st["cooldown_carril"] -= delta
				
			if st["timer_sprint"] > 0.0:
				st["timer_sprint"] -= delta
				if st["timer_sprint"] <= 0.0:
					st["en_sprint"] = false
					if not st.get("ha_cruzado_meta", false):
						reproducir_animacion_jugador(av, "idle")
					
			if st["timer_bloqueo"] > 0.0:
				st["timer_bloqueo"] -= delta
				if st["timer_bloqueo"] <= 0.0:
					st["bloqueando"] = false
					var rig_b = rigs_tubos.get(id)
					if rig_b:
						var esc = rig_b.get_node_or_null("EscudoHielo")
						if esc: esc.visible = false
						
			if st["cooldown_bloqueo"] > 0.0:
				st["cooldown_bloqueo"] -= delta
				
			if st["timer_descontrol"] > 0.0:
				st["timer_descontrol"] -= delta
				if st["timer_descontrol"] <= 0.0:
					st["descontrol"] = false
					if not st.get("ha_cruzado_meta", false):
						reproducir_animacion_jugador(av, "idle")
					
			if st["timer_aire"] > 0.0:
				st["timer_aire"] -= delta
				if st["timer_aire"] <= 0.0:
					st["en_el_aire"] = false
					st["vel_s"] = min(st["vel_s"] + 65.0, VEL_MAX_SLOPE)
					reproducir_animacion_jugador(av, "idle")
					if av:
						disparar_particulas_estrellas(av.global_position, 6)
			
			# --- SISTEMA DE REMONTADA DINÁMICO (CATCH-UP / REBUFO ELÁSTICO) ---
			# Calcula la distancia al rival más próximo que va adelante
			var dist_rival_adelante: float = 99999.0
			for otro_id in estado_corredores.keys():
				if otro_id == mi_id: continue
				var d_adelante = estado_corredores[otro_id]["pos_s"] - st["pos_s"]
				if d_adelante > 0.0 and d_adelante < dist_rival_adelante:
					dist_rival_adelante = d_adelante
					
			var bonus_remontada: float = 0.0
			if dist_rival_adelante < 99999.0 and dist_rival_adelante > 100.0:
				# Si va rezagado a más de 100px, gana aceleración proporcional hasta +80 px/s
				var factor_dist = clamp((dist_rival_adelante - 100.0) / 900.0, 0.0, 1.0)
				bonus_remontada = factor_dist * 80.0
					
			if not st["en_sprint"] and not st["descontrol"] and not st.get("ha_cruzado_meta", false):
				var vel_objetivo = VEL_BASE + bonus_remontada
				if st["vel_s"] < vel_objetivo:
					st["vel_s"] = move_toward(st["vel_s"], vel_objetivo, 200.0 * delta)
				elif st["vel_s"] > VEL_MAX_SLOPE + bonus_remontada:
					st["vel_s"] = move_toward(st["vel_s"], VEL_MAX_SLOPE + bonus_remontada, 100.0 * delta)
					
			# Si ya cruzó la meta, desacelera suavemente hasta frenar en la nieve
			if st.get("ha_cruzado_meta", false):
				st["vel_s"] = move_toward(st["vel_s"], 0.0, 360.0 * delta)
				
			st["pos_s"] += st["vel_s"] * delta
			
			var target_offset = OFFSETS_CARRILES[clamp(st["carril"], 0, 3)]
			st["lateral_offset"] = move_toward(st["lateral_offset"], target_offset, 750.0 * delta)
			
			var target_pos = obtener_centro_pista(st["pos_s"]) + NORM_PISTA * st["lateral_offset"]
			
			if st["en_el_aire"]:
				var t_prog = 1.0 - (st["timer_aire"] / 0.85)
				altura_actual = max(0.0, sin(t_prog * PI) * 85.0)
				target_pos.y -= altura_actual
				
			av.global_position = target_pos
			st["pos_x"] = av.global_position.x
			st["pos_y"] = av.global_position.y
			st["tilt_angle"] = move_toward(st["tilt_angle"], 0.0, 50.0 * delta)
			
		else:
			# --- CORREDORES REMOTOS: DEAD RECKONING + INTERPOLACIÓN FLUIDA ---
			if st.get("ha_cruzado_meta", false):
				st["vel_s"] = move_toward(st["vel_s"], 0.0, 360.0 * delta)
				
			st["pos_s"] += st["vel_s"] * delta
			st["pos_s"] = lerp(st["pos_s"], st["target_pos_s"], clamp(14.0 * delta, 0.0, 1.0))
			st["lateral_offset"] = lerp(st["lateral_offset"], st["target_offset"], clamp(16.0 * delta, 0.0, 1.0))
			
			var target_pos = obtener_centro_pista(st["pos_s"]) + NORM_PISTA * st["lateral_offset"]
			if st["en_el_aire"]:
				if not st.has("timer_aire_remoto") or st["timer_aire_remoto"] <= 0.0:
					st["timer_aire_remoto"] = 0.85
				st["timer_aire_remoto"] -= delta
				var t_prog = 1.0 - (st["timer_aire_remoto"] / 0.85)
				altura_actual = max(0.0, sin(t_prog * PI) * 85.0)
				target_pos.y -= altura_actual
			else:
				st["timer_aire_remoto"] = 0.0
				
			av.global_position = target_pos
			st["pos_x"] = av.global_position.x
			st["pos_y"] = av.global_position.y
			st["tilt_angle"] = move_toward(st["tilt_angle"], 0.0, 50.0 * delta)
		
		# Sombra dinámica en la nieve: permanece anclada al suelo cambiando de escala y opacidad con la altura
		var sombra = av.get_node_or_null("SombraNieve")
		if sombra:
			sombra.position = Vector2(0.0, 14.0 + altura_actual)
			var factor_h = clamp(altura_actual / 85.0, 0.0, 1.0)
			var esc_s = lerp(1.0, 0.42, factor_h)
			sombra.scale = Vector2(esc_s, esc_s)
			sombra.color.a = lerp(0.35, 0.12, factor_h)
			sombra.visible = not celebracion_iniciada
		
		# Animación y rotación visual del tubo
		var rig = rigs_tubos.get(id)
		if rig:
			var spray = rig.get_node_or_null("SprayNieve")
			if spray:
				spray.emitting = (altura_actual < 6.0 and not st.get("ha_cruzado_meta", false) and st["vel_s"] > 30.0)
				
			if st["en_el_aire"]:
				rig.rotation = ANGULO_PISTA_RAD - deg_to_rad(18.0)
			elif st["descontrol"]:
				rig.rotation += 15.0 * delta
			else:
				rig.rotation = ANGULO_PISTA_RAD + deg_to_rad(st["tilt_angle"])
				
		if st["pos_s"] > mayor_s:
			mayor_s = st["pos_s"]
			id_lider = id
			
		# --- VERIFICACIÓN DE CRUCE DE META INDIVIDUAL ---
		if st["pos_s"] >= META_S and not st.get("ha_cruzado_meta", false):
			registrar_llegada_a_meta_jugador(id)
			
	# --- CONTROL DE TIEMPO Y LLEGADA COLECTIVA A META ---
	if primer_ganador_detectado and not transicion_podio_iniciada:
		timer_espera_todos_meta += delta
		var todos_cruzaron = true
		for id in estado_corredores.keys():
			if not estado_corredores[id].get("ha_cruzado_meta", false):
				todos_cruzaron = false
				break
				
		var todos_detenidos = true
		for id in estado_corredores.keys():
			if estado_corredores[id]["vel_s"] > 14.0:
				todos_detenidos = false
				break
				
		# Esperar a que todos hayan cruzado y detenido por completo (o 9.5s de gracia)
		var listos_para_transicion = (todos_cruzaron and todos_detenidos) or timer_espera_todos_meta >= 9.5
		if listos_para_transicion:
			timer_espera_parada_final += delta
			# Pausa de 1.2s para apreciar a todos los corredores frenados en el banco de nieve
			if timer_espera_parada_final >= 1.2:
				transicion_podio_iniciada = true
				celebracion_iniciada = true
				
				# Asegurar que los rezagados queden registrados en el ranking
				for id in estado_corredores.keys():
					if not orden_llegada_meta.has(id):
						orden_llegada_meta.append(id)
						estado_corredores[id]["ha_cruzado_meta"] = true
						
				if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
					if multiplayer.has_multiplayer_peer():
						sincronizar_celebracion_podio_rpc.rpc(orden_llegada_meta)
					else:
						sincronizar_celebracion_podio_rpc(orden_llegada_meta)
					
	# --- 3. DETECCIÓN Y ACUMULACIÓN DE REBUFO (DRAFTING) ---
	for id in estado_corredores.keys():
		var st = estado_corredores[id]
		var esta_a_rebufo = false
		var pos_rival = Vector2.ZERO
		
		if not st.get("ha_cruzado_meta", false):
			for otro_id in estado_corredores.keys():
				if otro_id == id: continue
				var otro_st = estado_corredores[otro_id]
				
				if st["carril"] == otro_st["carril"]:
					var dist_al_frente = otro_st["pos_s"] - st["pos_s"]
					if dist_al_frente > 25.0 and dist_al_frente <= 280.0:
						esta_a_rebufo = true
						var av_otro = avatares_jugadores.get(otro_id)
						if av_otro:
							pos_rival = av_otro.global_position
						break
						
		var estela = estelas_rebufo.get(id)
		var av_local = avatares_jugadores.get(id)
		if estela and av_local:
			if esta_a_rebufo:
				estela.visible = true
				estela.clear_points()
				estela.add_point(av_local.global_position + Vector2(0, 6))
				estela.add_point(pos_rival - DIR_PISTA * 20.0 + Vector2(0, 6))
			else:
				estela.visible = false
				
		var rig = rigs_tubos.get(id)
		var vortex = rig.get_node_or_null("VortexRebufo") if rig else null
		
		if id == mi_id:
			if esta_a_rebufo and not st["descontrol"] and not st["en_sprint"]:
				st["rebufo"] = min(1.0, st["rebufo"] + delta * 1.1)
				if st["rebufo"] >= 1.0 and not st["rebufo_listo"]:
					st["rebufo_listo"] = true
					if vortex: vortex.emitting = true
			else:
				st["rebufo"] = max(0.0, st["rebufo"] - delta * 0.4)
				if st["rebufo"] <= 0.0:
					st["rebufo_listo"] = false
					if vortex: vortex.emitting = false
				
	# 4. Choques y duelos (Sprint vs Bloqueo o Choque Leve Anti-Superposición)
	var st_mi = estado_corredores.get(mi_id)
	if st_mi and not st_mi.get("ha_cruzado_meta", false):
		if st_mi["en_sprint"]:
			for id_del in estado_corredores.keys():
				if id_del == mi_id: continue
				var st_d = estado_corredores[id_del]
				if st_mi["carril"] == st_d["carril"]:
					var dist = st_d["pos_s"] - st_mi["pos_s"]
					if abs(dist) <= 38.0:
						resolver_duelo_adelantamiento(mi_id, id_del)
						break
		elif not st_mi["descontrol"] and not st_mi["en_el_aire"]:
			# Si alcanza al de adelante sin sprint, choque leve que empuja hacia atrás al de atrás
			for id_del in estado_corredores.keys():
				if id_del == mi_id: continue
				var st_d = estado_corredores[id_del]
				if st_mi["carril"] == st_d["carril"] and not st_d.get("ha_cruzado_meta", false):
					var dist_adelante = st_d["pos_s"] - st_mi["pos_s"]
					if dist_adelante > -10.0 and dist_adelante < 48.0:
						aplicar_choque_leve_adelantamiento(mi_id, id_del)
						break
					
	# 5. Colisión con obstáculos (Gestionada autoritativamente de forma local)
	if not st_mi.get("ha_cruzado_meta", false):
		verificar_colisiones_obstaculos_local()
	
	# 6. Sincronización en red a 20 Hz de MI estado local hacia los demás peers
	if multiplayer.has_multiplayer_peer():
		timer_sync_red += delta
		if timer_sync_red >= 0.05:
			timer_sync_red = 0.0
			if st_mi:
				sincronizar_corredor_rpc.rpc(
					mi_id,
					st_mi["pos_s"],
					st_mi["vel_s"],
					st_mi["carril"],
					st_mi["lateral_offset"],
					st_mi["rebufo"],
					st_mi["rebufo_listo"],
					st_mi["en_sprint"],
					st_mi["bloqueando"],
					st_mi["descontrol"],
					st_mi["en_el_aire"]
				)
			
	# 7. Actualizar HUD y cámara
	actualizar_hud_carrera(id_lider)

func registrar_llegada_a_meta_jugador(id: int):
	var st = estado_corredores.get(id)
	if not st or st.get("ha_cruzado_meta", false): return
	
	st["ha_cruzado_meta"] = true
	if not orden_llegada_meta.has(id):
		orden_llegada_meta.append(id)
		
	var av = avatares_jugadores.get(id)
	if av:
		reproducir_animacion_jugador(av, "acierto")
		disparar_particulas_estrellas(av.global_position, 12)
		
	if not primer_ganador_detectado:
		primer_ganador_detectado = true
		timer_espera_todos_meta = 0.0
		agregar_trauma(0.35)
		var c_meta = obtener_centro_pista(META_S)
		disparar_particulas_estrellas(c_meta, 20)

@rpc("any_peer", "call_remote", "unreliable")
func sincronizar_corredor_rpc(
	id: int,
	p_s: float,
	p_vs: float,
	p_c: int,
	p_off: float,
	p_reb: float,
	p_rl: bool,
	p_sp: bool,
	p_bl: bool,
	p_dc: bool,
	p_air: bool
):
	var st = estado_corredores.get(id)
	if not st: return
	
	st["target_pos_s"] = p_s
	st["vel_s"] = p_vs
	st["carril"] = p_c
	st["target_offset"] = p_off
	st["rebufo"] = p_reb
	st["rebufo_listo"] = p_rl
	st["en_sprint"] = p_sp
	st["bloqueando"] = p_bl
	st["descontrol"] = p_dc
	st["en_el_aire"] = p_air
	
	if p_s >= META_S and not st.get("ha_cruzado_meta", false):
		registrar_llegada_a_meta_jugador(id)
	
	if abs(st["pos_s"] - p_s) > 300.0:
		st["pos_s"] = p_s

func resolver_duelo_adelantamiento(id_atacante: int, id_defensor: int):
	aplicar_duelo_adelantamiento(id_atacante, id_defensor)
	if multiplayer.has_multiplayer_peer():
		notificar_duelo_rpc.rpc(id_atacante, id_defensor)

@rpc("any_peer", "call_remote", "reliable")
func notificar_duelo_rpc(id_atacante: int, id_defensor: int):
	aplicar_duelo_adelantamiento(id_atacante, id_defensor)

func aplicar_duelo_adelantamiento(id_atacante: int, id_defensor: int):
	var st_a = estado_corredores.get(id_atacante)
	var st_d = estado_corredores.get(id_defensor)
	var av_a = avatares_jugadores.get(id_atacante)
	var av_d = avatares_jugadores.get(id_defensor)
	if not st_a or not st_d: return
	
	if av_d:
		disparar_particulas_bump(av_d.global_position)
	agregar_trauma(0.4)
	
	if st_d["bloqueando"]:
		st_a["en_sprint"] = false
		st_a["vel_s"] = 260.0
		st_a["pos_s"] -= 40.0
		reproducir_animacion_jugador(av_a, "impacto")
		if av_a:
			disparar_particulas_sudor(av_a.global_position)
		
		st_d["vel_s"] = VEL_BOOST_BLOQUEO
		st_d["bloqueando"] = false
		reproducir_animacion_jugador(av_d, "acierto")
		if av_d:
			disparar_particulas_estrellas(av_d.global_position, 8)
	else:
		st_d["descontrol"] = true
		st_d["timer_descontrol"] = 1.3
		st_d["vel_s"] = VEL_DESCONTROL
		reproducir_animacion_jugador(av_d, "resbalar")
		if av_d:
			disparar_particulas_sudor(av_d.global_position)

func aplicar_choque_leve_adelantamiento(id_atras: int, id_adelante: int):
	ejecutar_choque_leve_local(id_atras, id_adelante)
	if multiplayer.has_multiplayer_peer():
		notificar_choque_leve_rpc.rpc(id_atras, id_adelante)

@rpc("any_peer", "call_remote", "unreliable")
func notificar_choque_leve_rpc(id_atras: int, id_adelante: int):
	ejecutar_choque_leve_local(id_atras, id_adelante)

func ejecutar_choque_leve_local(id_atras: int, id_adelante: int):
	var st_atras = estado_corredores.get(id_atras)
	var st_adelante = estado_corredores.get(id_adelante)
	if not st_atras or not st_adelante: return
	
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	
	# 1. Si soy el jugador que venía detrás: retroceder suavemente a distancia segura (52 px) y emparejar velocidad
	if id_atras == mi_id:
		st_atras["pos_s"] = st_adelante["pos_s"] - 52.0
		st_atras["vel_s"] = min(st_atras["vel_s"], st_adelante["vel_s"] * 0.95)
		st_atras["tilt_angle"] = -10.0 # Reclinación cómica por el tope
		var av_atras = avatares_jugadores.get(id_atras)
		if av_atras:
			disparar_particulas_bump(av_atras.global_position + DIR_PISTA * 20.0)
		agregar_trauma(0.12)
		
	# 2. Jugador de adelante: solo reacción visual (squash & stretch del flotador y chispas) sin perder velocidad
	var rig_del = rigs_tubos.get(id_adelante)
	if rig_del:
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(rig_del, "scale", Vector2(1.22, 0.82), 0.08)
		tw.tween_property(rig_del, "scale", Vector2.ONE, 0.12)
		
	var av_del = avatares_jugadores.get(id_adelante)
	if av_del:
		disparar_particulas_estrellas(av_del.global_position - DIR_PISTA * 15.0, 4)

func verificar_colisiones_obstaculos_local():
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var st = estado_corredores.get(mi_id)
	if not st or st["en_el_aire"] or st.get("ha_cruzado_meta", false): return
	
	var pos_s = st["pos_s"]
	var carril = st["carril"]
	
	for obs in contenedor_obstaculos.get_children():
		if not obs is Area2D: continue
		var obs_carril = obs.get_meta("carril", -1)
		if obs_carril != carril: continue
		
		var obs_s = obs.get_meta("pos_s", -9999.0)
		var dist = obs_s - pos_s
		if abs(dist) < 32.0:
			var tipo = obs.get_meta("tipo_obstaculo", 0)
			procesar_impacto_obstaculo(mi_id, tipo, obs)
			break

func procesar_impacto_obstaculo(id: int, tipo: int, obs: Area2D):
	var st = estado_corredores.get(id)
	var av = avatares_jugadores.get(id)
	
	match tipo:
		0:
			if not st["en_el_aire"]:
				st["en_el_aire"] = true
				st["timer_aire"] = 0.85
				reproducir_animacion_jugador(av, "acierto")
				if av:
					disparar_particulas_estrellas(av.global_position, 8)
				
		1, 2:
			if not st["descontrol"] and not st["bloqueando"]:
				st["descontrol"] = true
				st["timer_descontrol"] = 1.1
				st["vel_s"] = VEL_DESCONTROL
				reproducir_animacion_jugador(av, "impacto")
				if av:
					disparar_particulas_bump(av.global_position)
					disparar_particulas_sudor(av.global_position)
				agregar_trauma(0.4)
				
				var rig = rigs_tubos.get(id)
				if rig:
					var tw = create_tween()
					tw.tween_property(rig, "scale", Vector2(1.3, 0.7), 0.1)
					tw.tween_property(rig, "scale", Vector2.ONE, 0.15)
			elif st["bloqueando"]:
				disparar_particulas_bump(obs.position)
				obs.queue_free()

# --- FX VISUALES ---

func disparar_particulas_estrellas(pos: Vector2, cantidad: int = 10):
	var p = CPUParticles2D.new()
	p.position = pos
	p.texture = tex_estrella
	p.amount = cantidad
	p.lifetime = 0.65
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 320)
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 240.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.65
	contenedor_efectos.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)

func disparar_particulas_bump(pos: Vector2):
	var spr = Sprite2D.new()
	spr.texture = tex_bump
	spr.position = pos
	spr.scale = Vector2(0.3, 0.3)
	contenedor_efectos.add_child(spr)
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "scale", Vector2(1.2, 1.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "modulate:a", 0.0, 0.25).set_delay(0.1)
	tw.finished.connect(spr.queue_free)

func disparar_particulas_sudor(pos: Vector2):
	var p = CPUParticles2D.new()
	p.position = pos + Vector2(0, -25)
	p.texture = tex_sweat
	p.amount = 4
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 0.8
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 300)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 140.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.8
	contenedor_efectos.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.7).timeout.connect(p.queue_free)

func reproducir_animacion_jugador(av: CharacterBody2D, nombre_base: String):
	if not av or not is_instance_valid(av): return
	var spr = av.get_node_or_null("Sprite")
	if not spr or not spr.sprite_frames: return
	
	var prefijo = av.get("prefijo_personaje")
	if not prefijo or prefijo == "": prefijo = "SEIK"
	
	var anim_completa = prefijo + "_" + nombre_base
	if spr.sprite_frames.has_animation(anim_completa):
		spr.play(anim_completa)
	elif spr.sprite_frames.has_animation(prefijo + "_idle"):
		spr.play(prefijo + "_idle")

func agregar_trauma(valor: float):
	trauma_camara = clamp(trauma_camara + valor, 0.0, 1.0)

# --- ACTUALIZACIÓN DE HUD Y CÁMARA ---

func actualizar_hud_carrera(id_lider: int):
	if celebracion_iniciada or partida_terminada:
		if hud: hud.visible = false
		return
		
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var st_mi = estado_corredores.get(mi_id)
	
	var st_lider = estado_corredores.get(id_lider)
	var pos_referencia = st_lider["pos_s"] if st_lider else (st_mi["pos_s"] if st_mi else 0.0)
	var ratio_lider = clamp(pos_referencia / META_S, 0.0, 1.0)
	
	if barra_progreso:
		barra_progreso.value = ratio_lider * 100.0
		
	if barra_progreso and contenedor_avatares_progreso:
		var ancho_barra = barra_progreso.size.x - 36.0
		var pos_x_ocupadas: Array = []
		
		for id in estado_corredores.keys():
			var icono = iconos_progreso_hud.get(id)
			if not icono: continue
			
			var st_p = estado_corredores[id]
			var ratio_p = clamp(st_p["pos_s"] / META_S, 0.0, 1.0)
			var target_x = lerp(4.0, ancho_barra, ratio_p)
			
			var offset_y = 2.0
			for prev_x in pos_x_ocupadas:
				if abs(prev_x - target_x) < 14.0:
					offset_y = 10.0 if offset_y == 2.0 else -4.0
					break
			pos_x_ocupadas.append(target_x)
			
			icono.position.x = lerp(icono.position.x, target_x, 0.15)
			icono.position.y = offset_y
			
	if st_mi:
		if barra_rebufo:
			barra_rebufo.value = st_mi["rebufo"] * 100.0
			if st_mi["rebufo_listo"]:
				barra_rebufo.modulate = Color(1.0, 0.95, 0.2)
			else:
				barra_rebufo.modulate = Color.WHITE
				
		if not st_mi.get("ha_cruzado_meta", false):
			if st_mi["rebufo_listo"]:
				Global.establecer_texto_accion_tactil("¡SPRINT!")
			else:
				Global.establecer_texto_accion_tactil("DEFENSA")
		else:
			Global.establecer_texto_accion_tactil("")
			
	# Cámara siguiendo al jugador local o al centro de meta
	var av_mi = avatares_jugadores.get(mi_id)
	if av_mi and is_instance_valid(av_mi) and not celebracion_iniciada:
		var target_cam = av_mi.global_position + DIR_PISTA * 240.0
		camera.global_position = camera.global_position.lerp(target_cam, 0.08)
		camera.rotation = 0.0

# --- CELEBRACIÓN DE PODIO EN NIEVE (GANADOR EN MONTÍCULO Y DEMÁS ENTERRADOS) ---

@rpc("authority", "call_local", "reliable")
func sincronizar_celebracion_podio_rpc(ranking: Array):
	ejecutar_celebracion_podio_nieve(ranking)

func ejecutar_celebracion_podio_nieve(ranking: Array):
	celebracion_iniciada = true
	partida_terminada = true
	bloquear_jugadores(true)
	camera.position_smoothing_enabled = false
	
	# 1. Transición cinemática con cortinilla de nieve suave
	var capa_trans = CanvasLayer.new()
	capa_trans.layer = 95
	var rect_trans = ColorRect.new()
	rect_trans.color = Color(1.0, 1.0, 1.0, 0.0)
	rect_trans.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa_trans.add_child(rect_trans)
	add_child(capa_trans)
	
	var tw_trans_in = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw_trans_in.tween_property(rect_trans, "color:a", 1.0, 0.45)
	await tw_trans_in.finished
	
	# 2. Ocultar completamente HUD de carrera y controles táctiles
	if hud:
		hud.visible = false
	if panel_progreso:
		panel_progreso.visible = false
	if panel_rebufo:
		panel_rebufo.visible = false
	if panel_salida:
		panel_salida.visible = false
	Global.establecer_texto_accion_tactil("")
	Global.configurar_controles_tactiles(false, false)
	
	# Ocultar sombras de juego en los personajes para la cinemática del podio
	for av in avatares_jugadores.values():
		var s = av.get_node_or_null("SombraNieve")
		if s: s.visible = false
	
	if ranking.is_empty():
		for id in estado_corredores.keys():
			ranking.append(id)
			
	var ganador_id = ranking[0]
	var pos_podio = obtener_centro_pista(META_S + 460.0)
	
	# 3. Desbloquear límites de la cámara y centrar en el podio
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	camera.global_position = pos_podio - Vector2(0.0, 25.0)
	camera.zoom = Vector2(1.2, 1.2)
	
	# 4. Construir el podio temático en la nieve
	var podio_nodo = Node2D.new()
	podio_nodo.name = "PodioCelebracionNieve"
	podio_nodo.position = pos_podio
	podio_nodo.z_index = 15
	add_child(podio_nodo)
	
	# Montículo de nieve para el ganador (Curva cartoon con sombra y contorno)
	var monticulo_ganador = Polygon2D.new()
	monticulo_ganador.color = Color("#ffffff")
	monticulo_ganador.polygon = PackedVector2Array([
		Vector2(-75, 40), Vector2(-65, 20), Vector2(-40, 5), Vector2(0, 0),
		Vector2(40, 5), Vector2(65, 20), Vector2(75, 40)
	])
	podio_nodo.add_child(monticulo_ganador)
	
	var sombra_monticulo = Polygon2D.new()
	sombra_monticulo.color = Color(0.82, 0.90, 0.98, 0.8)
	sombra_monticulo.polygon = PackedVector2Array([
		Vector2(-75, 40), Vector2(-65, 20), Vector2(0, 18), Vector2(65, 20), Vector2(75, 40)
	])
	podio_nodo.add_child(sombra_monticulo)
	
	var borde_monticulo = Line2D.new()
	borde_monticulo.points = monticulo_ganador.polygon
	borde_monticulo.width = 4.5
	borde_monticulo.default_color = Color("#16181c")
	podio_nodo.add_child(borde_monticulo)
	
	# 5. Posicionar al GANADOR en la cima del montículo
	var av_ganador = avatares_jugadores.get(ganador_id)
	if av_ganador:
		var rig_g = av_ganador.get_node_or_null("TuboRig")
		if rig_g: rig_g.visible = false
		
		av_ganador.z_index = 32
		av_ganador.global_position = pos_podio + Vector2(0.0, -18.0)
		av_ganador.visible = true
		reproducir_animacion_jugador(av_ganador, "acierto")
		
		disparar_particulas_estrellas(av_ganador.global_position + Vector2(0, -20), 24)
		agregar_trauma(0.35)
		
	# 6. Directora Yayoi Akikawa y Tazuna Hayakawa presentes en el encuadre animando
	var spr_dir = Sprite2D.new()
	spr_dir.name = "DirectoraYayoiCelebracion"
	spr_dir.texture = load("res://assets/Sprites/NPCS/Yayoi Akikawa/akyy_ST01_00.png")
	spr_dir.position = pos_podio + Vector2(-95.0, -14.0)
	spr_dir.scale = Vector2(1.18, 1.18)
	spr_dir.z_index = 29
	podio_nodo.add_child(spr_dir)
	
	var tw_cheer_dir = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw_cheer_dir.tween_property(spr_dir, "position:y", pos_podio.y - 22.0, 0.42)
	tw_cheer_dir.tween_property(spr_dir, "position:y", pos_podio.y - 14.0, 0.42)
	
	var spr_taz = Sprite2D.new()
	spr_taz.name = "TazunaCelebracion"
	spr_taz.texture = load("res://assets/Sprites/NPCS/Tazuna Hayakawa/hatz_ST01_00.png")
	spr_taz.position = pos_podio + Vector2(95.0, -14.0)
	spr_taz.scale = Vector2(1.18, 1.18)
	spr_taz.z_index = 29
	podio_nodo.add_child(spr_taz)
	
	var tw_cheer_taz = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw_cheer_taz.tween_property(spr_taz, "position:y", pos_podio.y - 22.0, 0.42).set_delay(0.2)
	tw_cheer_taz.tween_property(spr_taz, "position:y", pos_podio.y - 14.0, 0.42)
	
	# Espectadores adicionales: personajes no seleccionados animando
	var tipos_usados = []
	for av_inst in avatares_jugadores.values():
		if "prefijo_personaje" in av_inst and str(av_inst.prefijo_personaje) != "":
			tipos_usados.append(str(av_inst.prefijo_personaje))
	var todos_los_tipos = ["SEIK", "GLSH", "OGRC", "STIL", "MACA", "AGTC", "DAFL", "JUPC", "SABG", "SPWE"]
	var libres = []
	for t in todos_los_tipos:
		if not tipos_usados.has(t):
			libres.append(t)
	var offsets_espectadores = [Vector2(-170.0, -26.0), Vector2(170.0, -26.0)]
	for e_i in range(min(2, libres.size())):
		var spr_esp = AnimatedSprite2D.new()
		spr_esp.sprite_frames = load("res://recursos/personajes_frames.tres")
		var anim_cheer = libres[e_i] + "_acierto"
		if spr_esp.sprite_frames.has_animation(anim_cheer):
			spr_esp.play(anim_cheer)
		elif spr_esp.sprite_frames.has_animation(libres[e_i] + "_idle"):
			spr_esp.play(libres[e_i] + "_idle")
		spr_esp.position = pos_podio + offsets_espectadores[e_i]
		spr_esp.scale = Vector2(1.05, 1.05)
		spr_esp.z_index = 26
		podio_nodo.add_child(spr_esp)
		
	# 7. Posicionar a los DEMÁS JUGADORES medio enterrados en la nieve, más abajo del ganador
	var offsets_perdedores = [
		Vector2(-135.0, 75.0),
		Vector2(135.0, 75.0),
		Vector2(-230.0, 85.0),
		Vector2(230.0, 85.0)
	]
	
	var perdedores = ranking.slice(1)
	for idx in range(perdedores.size()):
		var p_id = perdedores[idx]
		var av_p = avatares_jugadores.get(p_id)
		if not av_p: continue
		
		# Ocultar tubo para simular entierro
		var rig_p = av_p.get_node_or_null("TuboRig")
		if rig_p: rig_p.visible = false
		
		av_p.z_index = 25
		var pos_base = pos_podio + offsets_perdedores[idx % offsets_perdedores.size()]
		av_p.global_position = pos_base
		av_p.visible = true
		
		# Animación aturdida cómica (estrellitas giratorias de impacto en la nieve)
		reproducir_animacion_jugador(av_p, "aturdido")
		disparar_particulas_sudor(av_p.global_position)
		
		var part_mareo = CPUParticles2D.new()
		part_mareo.texture = tex_estrella
		part_mareo.position = pos_base + Vector2(0.0, -32.0)
		part_mareo.amount = 4
		part_mareo.lifetime = 1.1
		part_mareo.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		part_mareo.emission_sphere_radius = 14.0
		part_mareo.gravity = Vector2.ZERO
		part_mareo.angular_velocity_min = 120.0
		part_mareo.angular_velocity_max = 240.0
		part_mareo.scale_amount_min = 0.35
		part_mareo.scale_amount_max = 0.5
		part_mareo.z_index = 35
		podio_nodo.add_child(part_mareo)
		
		# Montoncito de nieve que cubre sus piernas y cadera (visible medio enterrado)
		var monton_enterrado = Node2D.new()
		monton_enterrado.position = pos_base + Vector2(0.0, 16.0)
		monton_enterrado.z_index = 28
		
		var poly_nieve = Polygon2D.new()
		poly_nieve.color = Color("#ffffff")
		poly_nieve.polygon = PackedVector2Array([
			Vector2(-35, 12), Vector2(-28, -8), Vector2(0, -18), Vector2(28, -8), Vector2(35, 12)
		])
		monton_enterrado.add_child(poly_nieve)
		
		var borde_nieve = Line2D.new()
		borde_nieve.points = poly_nieve.polygon
		borde_nieve.width = 4.0
		borde_nieve.default_color = Color("#16181c")
		monton_enterrado.add_child(borde_nieve)
		
		podio_nodo.add_child(monton_enterrado)
		
	# 8. Abrir cortinilla suavemente revelando el podio temático completo
	var tw_trans_out = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_trans_out.tween_property(rect_trans, "color:a", 0.0, 0.55)
	tw_trans_out.tween_property(camera, "zoom", Vector2(1.28, 1.28), 1.2)
	await tw_trans_out.finished
	capa_trans.queue_free()
	
	# 9. Mostrar el banner oficial de victoria estilo Mario Party
	var overlay_victoria = escena_pantalla_victoria.instantiate()
	add_child(overlay_victoria)
	
	var info = formatear_nombres_ganadores([ganador_id])
	overlay_victoria.animar_aparicion(info["nombres"], info["wins"])
	
	# 10. Tiempo de celebración y retorno al lobby
	await get_tree().create_timer(5.0).timeout
	
	var es_autoridad = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if es_autoridad:
		if get_tree().root.has_node("Lobby"):
			var lobby = get_tree().root.get_node("Lobby")
			if multiplayer.has_multiplayer_peer():
				lobby.regresar_al_lobby_rpc.rpc()
			else:
				lobby.regresar_al_lobby_rpc()

# Anulamos la secuencia por defecto de BaseMinijuego para usar la cinematográfica alpina
func ejecutar_secuencia_victoria(_ganadores: Array, _centro: Vector2 = Vector2.ZERO):
	pass
