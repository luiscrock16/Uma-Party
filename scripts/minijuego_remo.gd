extends BaseMinijuego

# Constantes del Curso Marino y Playa
const META_Y = 4600.0
const PLAYA_LIMITE_X = 230.0
const MAR_LIMITE_X = 1060.0

# Nodos Principales
@onready var fondo_mar_playa = $FondoMarPlaya
@onready var contenedor_olas = $ContenedorOlas
@onready var decoracion_playa = $DecoracionPlaya
@onready var zona_celebracion = $DecoracionPlaya/ZonaCelebracion
@onready var contenedor_obstaculos = $ContenedorObstaculos
@onready var boyas_der = $BoyasBordeDerecho
@onready var meta_campamento = $MetaCampamento
@onready var contenedor_boyas_meta = $MetaCampamento/ContenedorBoyasMeta
@onready var bote_eq0 = $BoteEquipo0
@onready var bote_eq1 = $BoteEquipo1
@onready var camera = $Camera2D

# HUD Snowboard-Style
@onready var hud = $HUD
@onready var panel_progreso = $HUD/PanelProgreso
@onready var barra_progreso = $HUD/PanelProgreso/Barra
@onready var contenedor_avatares = $HUD/PanelProgreso/ContenedorAvatares
@onready var estrella_meta = $HUD/PanelProgreso/EstrellaMeta

# Chips de Progreso en HUD
var chip_equipo_0: PanelContainer
var chip_equipo_1: PanelContainer

# Estado de la Partida
var partida_iniciada: bool = false
var partida_terminada: bool = false
var cinematica_playa_activa: bool = false
var tiempo_restante: float = 65.0
var avatares_jugadores: Dictionary = {}

# Físicas de los Botes
# Estructura: { 0: { pos, rot, vel, vel_ang, ultimo_izq, ultimo_der, terminado }, 1: ... }
var datos_botes: Dictionary = {}
var orden_llegada: Array = []

# Control de Olas Visuales y Boyas de Meta
var timer_ola: float = 1.2
var timer_sync_red: float = 0.0
var textura_ola: Texture2D
var lista_boyas_meta: Array = []

func _ready():
	modo_actual = Modo.EQUIPOS_2V2
	if has_node("/root/Global"):
		get_node("/root/Global").establecer_texto_accion_tactil("REMAR")
	partida_iniciada = false
	partida_terminada = false
	cinematica_playa_activa = false
	tiempo_restante = 65.0
	orden_llegada.clear()
	
	textura_ola = preload("res://assets/minijuegos/remo/ola_marina_espuma.png")
	
	_inicializar_fisiacas_botes()
	_construir_balizamiento_boyas()
	_construir_boyas_flotantes_meta()
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func _inicializar_fisiacas_botes():
	datos_botes[0] = {
		"rot": 0.0,
		"vel": Vector2(0.0, 90.0),
		"vel_ang": 0.0,
		"ultimo_izq": -99.0,
		"ultimo_der": -99.0,
		"terminado": false
	}
	datos_botes[1] = {
		"rot": 0.0,
		"vel": Vector2(0.0, 90.0),
		"vel_ang": 0.0,
		"ultimo_izq": -99.0,
		"ultimo_der": -99.0,
		"terminado": false
	}
	bote_eq0.position = Vector2(480.0, 220.0)
	bote_eq1.position = Vector2(780.0, 220.0)

func _construir_balizamiento_boyas():
	var tex_boya = preload("res://assets/minijuegos/remo/boya_marina.png")
	# Balizamiento derecho (boyas conectadas a lo largo de todo el curso en el mar abierto)
	for y in range(0, int(META_Y + 500), 120):
		var b = Sprite2D.new()
		b.texture = tex_boya
		b.position = Vector2(MAR_LIMITE_X + 16.0, y)
		boyas_der.add_child(b)

func _construir_boyas_flotantes_meta():
	var tex_boya_meta = preload("res://assets/minijuegos/remo/boya_meta_flotante.png")
	lista_boyas_meta.clear()
	# Fila de boyas de cuadros cruzando el canal de meta de X = 25 a X = 835
	for x in range(35, 845, 80):
		var b = Sprite2D.new()
		b.texture = tex_boya_meta
		b.position = Vector2(x, 0.0)
		contenedor_boyas_meta.add_child(b)
		lista_boyas_meta.append(b)

# ==============================================================================
# ASIGNACIÓN DE JUGADORES A LOS BOTES Y HUD DE PROGRESO
# ==============================================================================

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	jugadores_info.clear()
	# Equipo 0 (Rojo): P1 (Izquierda), P2 (Derecha)
	jugadores_info[1] = {"equipo": 0, "spawn": 0, "es_jefe": false}
	jugadores_info[2] = {"equipo": 0, "spawn": 1, "es_jefe": false}
	# Equipo 1 (Azul): P3 (Izquierda), P4 (Derecha)
	jugadores_info[3] = {"equipo": 1, "spawn": 2, "es_jefe": false}
	jugadores_info[4] = {"equipo": 1, "spawn": 3, "es_jefe": false}
	
	for id in jugadores_info.keys():
		if not has_node(str(id)):
			var av = preload("res://escenas/personaje_jugable.tscn").instantiate()
			av.name = str(id)
			add_child(av)
			av.configurar_visual(id - 1, "P" + str(id))
			
	aplicar_roles_locales()

func aplicar_roles_locales():
	for id in jugadores_info.keys():
		var datos = jugadores_info[id]
		var eq = datos.get("equipo", 0)
		var es_remo_izq = (datos.get("spawn", 0) % 2 == 0)
		var av = get_node_or_null(str(id))
		if not av and get_tree().root:
			av = get_tree().root.find_child(str(id), true, false)
			
		if av:
			avatares_jugadores[id] = av
			av.bloquear_controles(true)
			av.set_physics_process(false)
			av.scale = Vector2(0.85, 0.85)
			av.z_index = 2
			
			var bote = bote_eq0 if eq == 0 else bote_eq1
			if av.get_parent() != bote:
				av.get_parent().remove_child(av)
				bote.add_child(av)
				
			var asiento = bote.get_node("AsientoIzq") if es_remo_izq else bote.get_node("AsientoDer")
			av.position = asiento.position
			
			var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_idle"):
				av.sprite.play(prefijo + "_idle")
				
	_actualizar_indicadores_visuales_giro()
	_crear_chips_hud_progreso()
	
	if not instrucciones_mostradas:
		instrucciones_mostradas = true
		mostrar_pantalla_instrucciones()
	else:
		call_deferred("iniciar_secuencia_cuenta_atras")

func _crear_chips_hud_progreso():
	if not contenedor_avatares: return
	for c in contenedor_avatares.get_children():
		c.queue_free()
		
	# Separar jugadores por equipo
	var eq0_ids = []
	var eq1_ids = []
	for id in jugadores_info.keys():
		if jugadores_info[id].get("equipo", 0) == 0:
			eq0_ids.append(id)
		else:
			eq1_ids.append(id)
			
	eq0_ids.sort()
	eq1_ids.sort()
	
	chip_equipo_0 = _crear_chip_equipo(0, eq0_ids, Color("#e74c3c"), Color("#f1c40f"))
	chip_equipo_1 = _crear_chip_equipo(1, eq1_ids, Color("#2980b9"), Color("#3498db"))
	
	contenedor_avatares.add_child(chip_equipo_0)
	contenedor_avatares.add_child(chip_equipo_1)

func _crear_chip_equipo(eq: int, ids_jugadores: Array, col_fondo: Color, col_borde: Color) -> PanelContainer:
	var chip = PanelContainer.new()
	chip.name = "ChipEquipo" + str(eq)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = col_fondo
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = col_borde
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.shadow_size = 3
	sb.shadow_color = Color(0, 0, 0, 0.4)
	chip.add_theme_stylebox_override("panel", sb)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(hbox)
	
	# Icono miniatura de bote o etiqueta
	var lbl_bote = Label.new()
	lbl_bote.text = "🚣" if eq == 0 else "🛶"
	lbl_bote.add_theme_font_size_override("font_size", 14)
	hbox.add_child(lbl_bote)
	
	# Avatares de los jugadores del equipo
	for id in ids_jugadores:
		var av = avatares_jugadores.get(id)
		var prefijo = "SEIK"
		if av and "prefijo_personaje" in av and str(av.prefijo_personaje) != "":
			prefijo = str(av.prefijo_personaje)
			
		var icono = TextureRect.new()
		icono.custom_minimum_size = Vector2(24, 24)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var ruta_tex = "res://assets/Sprites/iconos_personajes/icono_" + prefijo + ".png"
		if ResourceLoader.exists(ruta_tex):
			icono.texture = load(ruta_tex)
			
		var marco = ReferenceRect.new()
		marco.border_color = Color.WHITE
		marco.border_width = 1.5
		marco.editor_only = false
		marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icono.add_child(marco)
		
		hbox.add_child(icono)
		
	return chip

func _on_instrucciones_completadas():
	inicio_cuenta_atras.emit()
	al_completar_instrucciones()

func al_completar_instrucciones():
	iniciar_secuencia_cuenta_atras()

func iniciar_secuencia_cuenta_atras():
	ejecutar_overlay_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	partida_iniciada = true
	tiempo_restante = 65.0
	_generar_obstaculos_marinos()

func _actualizar_indicadores_visuales_giro():
	for bote in [bote_eq0, bote_eq1]:
		var ind_izq = bote.get_node_or_null("IndicadorGiroIzq")
		var ind_der = bote.get_node_or_null("IndicadorGiroDer")
		if ind_izq:
			ind_izq.modulate = Color(1, 0.9, 0.3, 0.85)
		if ind_der:
			ind_der.modulate = Color(0.3, 0.9, 1.0, 0.85)

func _generar_obstaculos_marinos():
	for c in contenedor_obstaculos.get_children():
		c.queue_free()
		
	# Patrón simétrico determinista idéntico para ambos equipos:
	# Bote 0 en X = 480.0, Bote 1 en X = 780.0 (distancia = 300px)
	# Para cada obstáculo con offset dx en Y, se genera exactamente en ambos carriles:
	# Carril Equipo 0: (480.0 + dx, Y)
	# Carril Equipo 1: (780.0 + dx, Y)
	var patrones = [
		{"y": 550.0,  "dx": [0.0]},           # Roca central de aviso
		{"y": 880.0,  "dx": [-95.0]},         # Curva a la izquierda
		{"y": 1200.0, "dx": [95.0]},          # Curva a la derecha
		{"y": 1500.0, "dx": [0.0]},           # Roca central
		{"y": 1820.0, "dx": [-100.0, 100.0]}, # Puerta estrecha (pasar por el centro)
		{"y": 2180.0, "dx": [-90.0]},         # Zigzag izquierdo
		{"y": 2480.0, "dx": [90.0]},          # Zigzag derecho
		{"y": 2800.0, "dx": [-80.0]},         # Eslalon entrada
		{"y": 2940.0, "dx": [80.0]},          # Eslalon salida
		{"y": 3280.0, "dx": [0.0]},           # Roca central
		{"y": 3600.0, "dx": [-105.0, 105.0]}, # Puerta doble
		{"y": 3950.0, "dx": [85.0]},          # Chicana pre-meta
		{"y": 4250.0, "dx": [0.0]}            # Obstáculo final antes de las boyas
	]
	
	for pat in patrones:
		var y = pat["y"]
		for dx in pat["dx"]:
			_crear_roca_local(Vector2(480.0 + dx, y))
			_crear_roca_local(Vector2(780.0 + dx, y))

func _crear_roca_local(pos: Vector2):
	var roca = Area2D.new()
	roca.position = pos
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 24.0
	col.shape = shape
	roca.add_child(col)
	
	var spr = Sprite2D.new()
	spr.texture = preload("res://assets/minijuegos/remo/roca_marina.png")
	roca.add_child(spr)
	
	contenedor_obstaculos.add_child(roca)
	roca.body_entered.connect(func(body):
		if body == bote_eq0:
			_chocar_con_obstaculo(0)
		elif body == bote_eq1:
			_chocar_con_obstaculo(1)
	)

func _chocar_con_obstaculo(eq: int):
	if cinematica_playa_activa: return
	agitar_camara(6.0)
	var d = datos_botes[eq]
	d["vel"] *= 0.45
	d["vel_ang"] = randf_range(-0.6, 0.6)
	
	var bote = bote_eq0 if eq == 0 else bote_eq1
	var tw = create_tween()
	tw.tween_property(bote, "rotation", bote.rotation + randf_range(-0.35, 0.35), 0.1)
	tw.tween_property(bote, "rotation", d["rot"], 0.15)

# ==============================================================================
# FÍSICA Y CONTROL DE REMO
# ==============================================================================

var cooldown_remada_local: float = 0.0

func _physics_process(delta: float):
	if not partida_iniciada or partida_terminada: return
	
	cooldown_remada_local = max(0.0, cooldown_remada_local - delta)
	tiempo_restante -= delta
	
	# Simulación de Olas suaves y balanceo de boyas de meta
	_actualizar_olas_ambientales(delta)
	_actualizar_boyas_meta()
	
	# Entrada del jugador local
	_procesar_input_local()
	
	# IA para compañeros o rivales bots en partidas locales
	_procesar_ia_botes_local(delta)
	
	# Actualizar físicas y movimiento de ambos botes
	for eq in [0, 1]:
		_actualizar_fisica_bote(eq, delta)
		
	# Sincronización en red periódica para mantener ambos botes exactamente sincronizados
	if es_autoridad_de_partida():
		timer_sync_red -= delta
		if timer_sync_red <= 0.0:
			timer_sync_red = 0.12
			sincronizar_botes_rpc.rpc(
				bote_eq0.position, datos_botes[0]["rot"], datos_botes[0]["vel"],
				bote_eq1.position, datos_botes[1]["rot"], datos_botes[1]["vel"]
			)
		
	# Actualizar barra de progreso estilo snowboard y cámara
	_actualizar_hud_progreso()
	_actualizar_camara()
	
	# Comprobar si ambos botes han llegado a la meta
	if datos_botes[0]["terminado"] and datos_botes[1]["terminado"] and not cinematica_playa_activa:
		_iniciar_cinematica_llegada_playa()
		
	# Tiempo agotado -> forzar llegada
	if tiempo_restante <= 0.0 and not cinematica_playa_activa:
		tiempo_restante = 0.0
		_iniciar_cinematica_llegada_playa()

func _procesar_input_local():
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if mi_id in jugadores_info and not cinematica_playa_activa:
		var datos = jugadores_info[mi_id]
		var mi_eq = datos.get("equipo", 0)
		var es_remo_izq = (datos.get("spawn", 0) % 2 == 0)
		
		var quiere_remar = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("espacio") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if quiere_remar and cooldown_remada_local <= 0.0:
			cooldown_remada_local = 0.26
			solicitar_remada(mi_eq, es_remo_izq)

func solicitar_remada(equipo: int, es_remo_izq: bool):
	if multiplayer.has_multiplayer_peer():
		aplicar_remada_rpc.rpc(equipo, es_remo_izq)
	else:
		aplicar_remada_rpc(equipo, es_remo_izq)

@rpc("any_peer", "call_local", "reliable")
func aplicar_remada_rpc(equipo: int, es_remo_izq: bool):
	var d = datos_botes[equipo]
	var bote = bote_eq0 if equipo == 0 else bote_eq1
	var tiempo_actual = Time.get_ticks_msec() / 1000.0
	
	var dir_proa = Vector2.DOWN.rotated(d["rot"])
	var fuerza_avance = 125.0
	
	if es_remo_izq:
		d["ultimo_izq"] = tiempo_actual
		d["vel_ang"] += 0.38
		d["vel"] += dir_proa * fuerza_avance
		_animar_remo(bote, true)
	else:
		d["ultimo_der"] = tiempo_actual
		d["vel_ang"] -= 0.38
		d["vel"] += dir_proa * fuerza_avance
		_animar_remo(bote, false)
		
	# Sincronía Perfecta (si ambos remaron en un margen de 0.28s)
	var diff_tiempo = abs(d["ultimo_izq"] - d["ultimo_der"])
	if diff_tiempo <= 0.28:
		d["vel_ang"] = lerp(d["vel_ang"], 0.0, 0.85)
		d["vel"] += dir_proa * 155.0
		_efecto_turbo_sincronia(bote)

func _animar_remo(bote: Node2D, es_izq: bool):
	var remo = bote.get_node_or_null("RemoIzq" if es_izq else "RemoDer")
	var salp = bote.get_node_or_null("SalpicaduraIzq" if es_izq else "SalpicaduraDer")
	var ind = bote.get_node_or_null("IndicadorGiroIzq" if es_izq else "IndicadorGiroDer")
	
	if salp: salp.restart()
	
	if ind:
		var tw_ind = create_tween()
		tw_ind.tween_property(ind, "scale", Vector2(1.25, 1.25) * (1.0 if es_izq else -1.0), 0.08)
		tw_ind.tween_property(ind, "scale", Vector2(0.8, 0.8) * (1.0 if es_izq else -1.0), 0.15)
		
	if remo:
		var spr_remo = remo.get_node_or_null("SpriteRemo")
		if spr_remo:
			var rot_orig = spr_remo.rotation
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(spr_remo, "rotation", rot_orig + (0.55 if es_izq else -0.55), 0.1)
			tw.tween_property(spr_remo, "rotation", rot_orig, 0.18)

func _efecto_turbo_sincronia(bote: Node2D):
	var estela = bote.get_node_or_null("EstelaAgua") as CPUParticles2D
	if estela:
		estela.amount = 45
		estela.speed_scale = 2.2
		var tw = create_tween()
		tw.tween_interval(0.6)
		tw.tween_callback(func():
			if is_instance_valid(estela):
				estela.amount = 24
				estela.speed_scale = 1.2
		)

func _actualizar_fisica_bote(eq: int, delta: float):
	var d = datos_botes[eq]
	var bote = bote_eq0 if eq == 0 else bote_eq1
	
	if not cinematica_playa_activa:
		d["rot"] += d["vel_ang"] * delta
		d["rot"] = clamp(d["rot"], -0.9, 0.9)
		d["vel_ang"] = lerp(d["vel_ang"], 0.0, 3.8 * delta)
		bote.rotation = d["rot"]
		
		var dir_proa = Vector2.DOWN.rotated(d["rot"])
		d["vel"] = d["vel"].lerp(dir_proa * 95.0, 1.8 * delta)
		bote.position += d["vel"] * delta
		
		bote.position.x = clamp(bote.position.x, PLAYA_LIMITE_X + 24.0, MAR_LIMITE_X - 24.0)
		
		if bote.position.y >= META_Y and not d["terminado"]:
			d["terminado"] = true
			orden_llegada.append(eq)

# ==============================================================================
# INTELIGENCIA ARTIFICIAL EN PRUEBAS LOCALES / BOTS
# ==============================================================================

var timer_ia_bots: float = 0.0

func _procesar_ia_botes_local(delta: float):
	if multiplayer.has_multiplayer_peer() or cinematica_playa_activa: return
	timer_ia_bots -= delta
	if timer_ia_bots <= 0.0:
		timer_ia_bots = randf_range(0.24, 0.34)
		
		# 1. Compañero de Equipo (P2 - Remo Derecho)
		var d0 = datos_botes[0]
		if not d0["terminado"]:
			if d0["rot"] > 0.08 or randf() < 0.65:
				solicitar_remada(0, false)
				
		# 2. Equipo Rival Azul (P3 Izq y P4 Der)
		var d1 = datos_botes[1]
		if not d1["terminado"]:
			if d1["rot"] < -0.1:
				solicitar_remada(1, true)
			elif d1["rot"] > 0.1:
				solicitar_remada(1, false)
			else:
				if randf() < 0.7: solicitar_remada(1, true)
				if randf() < 0.7: solicitar_remada(1, false)

# ==============================================================================
# OLAS MARINAS AMBIENTALES Y BOYAS DE META
# ==============================================================================

func _actualizar_olas_ambientales(delta: float):
	timer_ola -= delta
	if timer_ola <= 0.0:
		timer_ola = randf_range(1.1, 1.8)
		_spawn_ola_ambiental()
		
	for ola in contenedor_olas.get_children():
		ola.position.x -= 160.0 * delta
		if ola.position.x <= 160.0:
			var tw = create_tween()
			tw.tween_property(ola, "modulate:a", 0.0, 0.4)
			tw.tween_callback(ola.queue_free)

func _spawn_ola_ambiental():
	if not textura_ola: return
	var ola = Sprite2D.new()
	ola.texture = textura_ola
	var y_pos = camera.position.y + randf_range(-300.0, 350.0)
	ola.position = Vector2(1180.0, y_pos)
	ola.modulate = Color(1, 1, 1, 0.0)
	ola.scale = Vector2(randf_range(0.8, 1.2), randf_range(0.8, 1.1))
	contenedor_olas.add_child(ola)
	
	var tw = create_tween()
	tw.tween_property(ola, "modulate:a", randf_range(0.65, 0.9), 0.5)

func _actualizar_boyas_meta():
	var t = Time.get_ticks_msec() / 1000.0
	for i in range(lista_boyas_meta.size()):
		var b = lista_boyas_meta[i]
		if is_instance_valid(b):
			b.position.y = sin(t * 3.0 + i * 0.7) * 4.0

# ==============================================================================
# CINEMÁTICA FINAL: ENCALLAR EN PARALELO Y CELEBRACIÓN DECORADA
# ==============================================================================

func _iniciar_cinematica_llegada_playa():
	if cinematica_playa_activa: return
	cinematica_playa_activa = true
	partida_terminada = true
	bloquear_jugadores(true)
	
	var eq_ganador = 0
	if orden_llegada.size() > 0:
		eq_ganador = orden_llegada[0]
	else:
		eq_ganador = 0 if bote_eq0.position.y >= bote_eq1.position.y else 1
		
	if multiplayer.has_multiplayer_peer():
		ejecutar_cinematica_playa_rpc.rpc(eq_ganador)
	else:
		ejecutar_cinematica_playa_rpc(eq_ganador)

@rpc("any_peer", "call_local", "reliable")
func ejecutar_cinematica_playa_rpc(eq_ganador: int):
	cinematica_playa_activa = true
	partida_terminada = true
	bloquear_jugadores(true)
	
	# Ocultar suavemente el HUD de progreso durante la celebración
	if panel_progreso:
		var tw_hud = create_tween()
		tw_hud.tween_property(panel_progreso, "modulate:a", 0.0, 0.5)
	
	# 1. Ambos botes encallan en la playa en PARALELO orientados hacia tierra (-PI/2)
	var pos_playa_0 = Vector2(90.0, META_Y + 230.0)
	var pos_playa_1 = Vector2(90.0, META_Y + 410.0)
	
	var tw_giro = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_giro.tween_property(bote_eq0, "rotation", -PI * 0.5, 0.9)
	tw_giro.tween_property(bote_eq1, "rotation", -PI * 0.5, 0.9)
	tw_giro.tween_property(bote_eq0, "position", pos_playa_0, 1.5)
	tw_giro.tween_property(bote_eq1, "position", pos_playa_1, 1.5)
	
	# Paneo de cámara a la zona de celebración decorada en la playa extendida
	var tw_cam = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_cam.tween_property(camera, "position", Vector2(-120.0, META_Y + 310.0), 1.4)
	await tw_giro.finished
	
	agitar_camara(5.0)
	await get_tree().create_timer(0.4).timeout
	
	# 2. Desembarcar y separar personajes:
	# - Ganadores en el podio tropical bajo el arco de victoria
	# - Segundos separados junto a su bote descansando/aplaudiendo
	var ganadores = []
	var perdedores = []
	for id in jugadores_info.keys():
		if jugadores_info[id].get("equipo", 0) == eq_ganador:
			ganadores.append(id)
		else:
			perdedores.append(id)
			
	# Ganadores en el Podio Decorado (ZonaCelebracion en X = -200)
	var pos_ganadores = [Vector2(-240.0, META_Y + 310.0), Vector2(-160.0, META_Y + 310.0)]
	var idx_w = 0
	for id in ganadores:
		var av = avatares_jugadores.get(id)
		if not av and get_tree().root: av = get_tree().root.find_child(str(id), true, false)
		if av:
			if av.get_parent() != self:
				av.get_parent().remove_child(av)
				add_child(av)
			av.z_index = 8
			av.visible = true
			av.scale = Vector2.ONE
			av.global_position = pos_ganadores[idx_w % pos_ganadores.size()]
			idx_w += 1
			var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
				av.sprite.play(prefijo + "_acierto")
				
	# Segundos separados abajo, cerca de su respectivo bote
	var pos_perdedores = [Vector2(-20.0, META_Y + 415.0), Vector2(40.0, META_Y + 415.0)]
	var idx_l = 0
	for id in perdedores:
		var av = avatares_jugadores.get(id)
		if not av and get_tree().root: av = get_tree().root.find_child(str(id), true, false)
		if av:
			if av.get_parent() != self:
				av.get_parent().remove_child(av)
				add_child(av)
			av.z_index = 8
			av.visible = true
			av.scale = Vector2.ONE
			av.global_position = pos_perdedores[idx_l % pos_perdedores.size()]
			idx_l += 1
			var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_idle"):
				av.sprite.play(prefijo + "_idle")
				
	ejecutar_secuencia_victoria(ganadores, Vector2(-200.0, META_Y + 310.0))

# ==============================================================================
# HUD SNOWBOARD-STYLE Y CÁMARA
# ==============================================================================

func agitar_camara(intensidad: float):
	if not camera: return
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	for i in range(3):
		tw.tween_property(camera, "offset", Vector2(randf_range(-intensidad, intensidad), randf_range(-intensidad, intensidad)), 0.04)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.04)

func _actualizar_hud_progreso():
	if not barra_progreso: return
	var r0 = clamp(bote_eq0.position.y / META_Y, 0.0, 1.0)
	var r1 = clamp(bote_eq1.position.y / META_Y, 0.0, 1.0)
	
	barra_progreso.value = max(r0, r1) * 100.0
	
	if contenedor_avatares and chip_equipo_0 and chip_equipo_1:
		var ancho_util = barra_progreso.size.x - 90.0
		var x0 = lerp(4.0, ancho_util, r0)
		var x1 = lerp(4.0, ancho_util, r1)
		
		# Separación vertical para evitar que se superpongan si están muy cerca
		var y0 = 4.0
		var y1 = 4.0
		if abs(x0 - x1) < 64.0:
			if r0 >= r1:
				y0 = -4.0
				y1 = 14.0
			else:
				y0 = 14.0
				y1 = -4.0
				
		chip_equipo_0.position = Vector2(x0, y0)
		chip_equipo_1.position = Vector2(x1, y1)

func _obtener_mi_equipo() -> int:
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if mi_id in jugadores_info:
		return jugadores_info[mi_id].get("equipo", 0)
	return 0

func _actualizar_camara():
	if not camera or cinematica_playa_activa: return
	
	# Cada equipo enfoca la vista en su propio bote
	# El bote se posiciona en la parte superior-media para dejar más de 450px de visión frontal despejada
	var mi_eq = _obtener_mi_equipo()
	var bote_local = bote_eq0 if mi_eq == 0 else bote_eq1
	var target_y = clamp(bote_local.position.y + 140.0, 324.0, META_Y + 240.0)
	camera.position.y = lerp(camera.position.y, target_y, 0.12)
	camera.position.x = 576.0

@rpc("any_peer", "call_remote", "unreliable")
func sincronizar_botes_rpc(p0: Vector2, r0: float, v0: Vector2, p1: Vector2, r1: float, v1: Vector2):
	if not cinematica_playa_activa:
		bote_eq0.position = bote_eq0.position.lerp(p0, 0.45)
		datos_botes[0]["rot"] = lerp(datos_botes[0]["rot"], r0, 0.45)
		datos_botes[0]["vel"] = datos_botes[0]["vel"].lerp(v0, 0.45)
		
		bote_eq1.position = bote_eq1.position.lerp(p1, 0.45)
		datos_botes[1]["rot"] = lerp(datos_botes[1]["rot"], r1, 0.45)
		datos_botes[1]["vel"] = datos_botes[1]["vel"].lerp(v1, 0.45)
