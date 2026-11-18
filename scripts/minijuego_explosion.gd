extends BaseMinijuego

enum EstadoJuego {
	ESPERANDO_INICIO,
	INICIO_TURNO,
	TURNO_JUGADOR,
	ACCION_PALANCA,
	RESOLUCION,
	RESET_PALANCAS,
	FIN_PARTIDA
}

enum TipoEliminacion {
	FALSO_ALIVIO,
	ABDUCCION_OVNI,
	EXPLOSION_PROPS,
	TRAMPILLA,
	MANO_MAGICA
}

var estado_juego: EstadoJuego = EstadoJuego.ESPERANDO_INICIO

# Cola de jugadores vivos (orden de turnos)
var cola_jugadores: Array = []
var turno_actual_id: int = -1
var indice_palanca_actual: int = 0
var tiempo_turno: float = 10.0

# Reglas de palancas
var palancas_instanciadas: Array[PalancaEmbolo] = []
var en_fase_tres_palancas: bool = false
var rondas_con_tres: int = 0
var seguras_restantes_en_set: int = 0

# Colores de los émbolos
var colores_cinco = [
	Color("#ff4757"), # 0: Rojo
	Color("#a55eea"), # 1: Morado
	Color("#ffa502"), # 2: Amarillo
	Color("#2ed573"), # 3: Verde
	Color("#dfe4ea")  # 4: Blanco
]

# Paleta de colores para explosiones cómicas
const COLORES_EXPLOSION = [
	Color("#ff2d75"), # Rosa Neón
	Color("#00e5ff"), # Cyan Eléctrico
	Color("#ffd13b"), # Oro Brillante
	Color("#2ed573"), # Verde Tóxico
	Color("#b829ff")  # Púrpura Cósmico
]

# Referencias a nodos visuales
@onready var contenedor_palancas = $EscenarioVisual/ContenedorPalancas
@onready var filtro_oscuridad = $EscenarioVisual/FiltroOscuridad
@onready var capa_niebla = $EscenarioVisual/CapaNiebla
@onready var cabeza_bomba = $EscenarioVisual/CabezaBomba
@onready var sprite_sunday = $EscenarioVisual/CabezaBomba/SpriteSundaySilence
@onready var farol_izq = $VigaIzquierda/FarolIzq
@onready var farol_der = $VigaDerecha/FarolDer
@onready var label_cuenta_bomba = $EscenarioVisual/CabezaBomba/LabelCuentaBomba
@onready var flash_explosion = $HUD/FlashExplosion
@onready var label_timer = $HUD/PanelTurno/VBox/HBox/LabelTimer
@onready var label_jugador_turno = $HUD/PanelTurno/VBox/HBox/LabelJugador
@onready var panel_turno = $HUD/PanelTurno
@onready var puntos_cola = $PuntosCola
@onready var punto_escenario = $PuntoEscenario

var escena_palanca = preload("res://escenas/palanca_embolo.tscn")

# Texturas de Sunday Silence (posturas de Manhattan Cafe)
var tex_sunday_idle: Texture2D = preload("res://assets/Sprites/sunday_silence.png")
var tex_sunday_channel: Texture2D = preload("res://assets/Sprites/sunday_silence_channel.png")
var tex_sunday_cast: Texture2D = preload("res://assets/Sprites/sunday_silence_cast.png")

# Texturas de utilería y props cargadas dinámicamente
var tex_magic_hand: Texture2D = null
var tex_magic_bar: Texture2D = null
var tex_spring: Texture2D = null
var texturas_catch = []
var texturas_sweat = []
var texturas_explosion = []
var bancos_niebla: Array = []

# Coordenadas de las escaleras
const X_ESCALERA_DER: float = 912.0
const X_ESCALERA_IZQ: float = 240.0
const Y_SUELO_INFERIOR: float = 530.0
const Y_PLATAFORMA: float = 355.0

func _ready():
	modo_actual = Modo.FFA
	Global.establecer_texto_accion_tactil("SPRINT")
	flash_explosion.visible = false
	label_cuenta_bomba.text = ""
	if cabeza_bomba:
		cabeza_bomba.visible = false
		cabeza_bomba.modulate.a = 0.0
		cabeza_bomba.position = Vector2(576, 175)
		cabeza_bomba.scale = Vector2.ONE
	if filtro_oscuridad:
		filtro_oscuridad.color.a = 0.0
	cargar_recursos_efectos()
	crear_bancos_niebla()

func crear_bancos_niebla():
	if not capa_niebla: return
	for child in capa_niebla.get_children():
		child.queue_free()
	bancos_niebla.clear()
	
	var configs_niebla = [
		{"x": 180.0, "y": 540.0, "w": 440.0, "h": 70.0, "vel": 16.0, "color": Color(0.18, 0.1, 0.28, 0.0)},
		{"x": 620.0, "y": 555.0, "w": 500.0, "h": 80.0, "vel": -14.0, "color": Color(0.15, 0.08, 0.24, 0.0)},
		{"x": 980.0, "y": 535.0, "w": 400.0, "h": 65.0, "vel": 18.0, "color": Color(0.2, 0.12, 0.32, 0.0)},
		{"x": 300.0, "y": 360.0, "w": 400.0, "h": 60.0, "vel": -15.0, "color": Color(0.22, 0.12, 0.35, 0.0)},
		{"x": 750.0, "y": 350.0, "w": 440.0, "h": 65.0, "vel": 14.0, "color": Color(0.2, 0.1, 0.3, 0.0)},
		{"x": 420.0, "y": 200.0, "w": 360.0, "h": 90.0, "vel": 10.0, "color": Color(0.26, 0.14, 0.4, 0.0)},
		{"x": 720.0, "y": 185.0, "w": 380.0, "h": 95.0, "vel": -11.0, "color": Color(0.24, 0.13, 0.38, 0.0)}
	]
	
	for cfg in configs_niebla:
		var panel_niebla = Panel.new()
		var st = StyleBoxFlat.new()
		st.bg_color = Color(cfg["color"].r, cfg["color"].g, cfg["color"].b, 1.0)
		st.corner_radius_top_left = int(cfg["h"] / 2.0)
		st.corner_radius_top_right = int(cfg["h"] / 2.0)
		st.corner_radius_bottom_right = int(cfg["h"] / 2.0)
		st.corner_radius_bottom_left = int(cfg["h"] / 2.0)
		st.shadow_color = Color(cfg["color"].r, cfg["color"].g, cfg["color"].b, 0.6)
		st.shadow_size = 25
		panel_niebla.add_theme_stylebox_override("panel", st)
		panel_niebla.custom_minimum_size = Vector2(cfg["w"], cfg["h"])
		panel_niebla.size = Vector2(cfg["w"], cfg["h"])
		panel_niebla.position = Vector2(cfg["x"] - cfg["w"] / 2.0, cfg["y"] - cfg["h"] / 2.0)
		panel_niebla.modulate.a = 0.0
		panel_niebla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa_niebla.add_child(panel_niebla)
		bancos_niebla.append({
			"nodo": panel_niebla,
			"vel": cfg["vel"],
			"w": cfg["w"],
			"alpha_target": 0.48
		})
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()

func cargar_recursos_efectos():
	var r_hand = "res://assets/props_clean/magic_hand_01.png"
	if ResourceLoader.exists(r_hand): tex_magic_hand = load(r_hand)
	var r_bar = "res://assets/props_clean/magic_hand_bar.png"
	if ResourceLoader.exists(r_bar): tex_magic_bar = load(r_bar)
	var r_spring = "res://assets/props_clean/spring_jump04.png"
	if ResourceLoader.exists(r_spring): tex_spring = load(r_spring)
	
	for i in range(1, 6):
		var ruta = "res://assets/props_clean/catch0%d.png" % i
		if ResourceLoader.exists(ruta): texturas_catch.append(load(ruta))
	for i in range(1, 4):
		var ruta = "res://assets/props_clean/sweat0%d.png" % i
		if ResourceLoader.exists(ruta): texturas_sweat.append(load(ruta))
	for i in range(1, 12):
		var ruta = "res://assets/props_clean/explosion%02d.png" % i
		if ResourceLoader.exists(ruta): texturas_explosion.append(load(ruta))

func bloquear_jugadores(_bloquear: bool):
	# En este minijuego TODOS los personajes permanecen SIEMPRE bloqueados del movimiento libre
	super.bloquear_jugadores(true)

func aplicar_roles_locales():
	for id in jugadores_info.keys():
		var datos = jugadores_info[id]
		var idx_spawn = datos["spawn"]
		var avatar = get_node_or_null(str(id))
		if avatar:
			avatar.bloquear_controles(true)
			var sync = avatar.get_node_or_null("MultiplayerSynchronizer")
			if sync:
				sync.process_mode = Node.PROCESS_MODE_DISABLED
			var p_cola = puntos_cola.get_node_or_null(str(idx_spawn))
			if p_cola:
				avatar.global_position = p_cola.global_position
				
	iniciar_secuencia_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	bloquear_jugadores(true)
	
	if es_autoridad_de_partida():
		cola_jugadores.clear()
		for id in jugadores_info.keys():
			cola_jugadores.append(id)
		
		cola_jugadores.shuffle()
		en_fase_tres_palancas = false
		rondas_con_tres = 0
		
		generar_palancas_servidor(5)
		sincronizar_cola_servidor()
		avanzar_siguiente_turno()

func sincronizar_cola_servidor():
	if es_autoridad_de_partida():
		rpc("sincronizar_cola_clientes", cola_jugadores)
	reordenar_avatares_en_cola()

@rpc("any_peer", "call_local", "reliable")
func sincronizar_cola_clientes(nueva_cola: Array):
	cola_jugadores = nueva_cola
	reordenar_avatares_en_cola()

func reordenar_avatares_en_cola():
	for i in range(cola_jugadores.size()):
		var id = cola_jugadores[i]
		var avatar = get_node_or_null(str(id))
		var punto = puntos_cola.get_node_or_null(str(i))
		if avatar and punto and avatar.name != str(turno_actual_id):
			var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(avatar, "global_position", punto.global_position, 0.4)

# --- SISTEMA DE PALANCAS ---

func generar_palancas_servidor(cantidad: int):
	var config_palancas = []
	var num_bombas = 1
	
	if cantidad == 5:
		num_bombas = 1
	elif cantidad == 3:
		rondas_con_tres += 1
		# Si pasan dos rondas con 3 palancas, solo habra 1 segura y 2 bombas
		if rondas_con_tres > 2:
			num_bombas = 2
		else:
			num_bombas = 1
			
	var seguras = cantidad - num_bombas
	seguras_restantes_en_set = seguras
	
	var bolsa = []
	for i in range(num_bombas): bolsa.append(true)
	for i in range(seguras): bolsa.append(false)
	bolsa.shuffle()
	
	for i in range(cantidad):
		config_palancas.append({
			"id": i,
			"color": colores_cinco[i],
			"bomba": bolsa[i]
		})
		
	rpc("aplicar_palancas_clientes", cantidad, config_palancas)

@rpc("any_peer", "call_local", "reliable")
func aplicar_palancas_clientes(cantidad: int, config: Array):
	for child in contenedor_palancas.get_children():
		contenedor_palancas.remove_child(child)
		child.queue_free()
	palancas_instanciadas.clear()
	
	en_fase_tres_palancas = (cantidad == 3)
	
	var ancho_total = 1152.0
	var centro_x = ancho_total / 2.0
	var pos_y = 310.0
	var espaciado = 85.0 if cantidad == 5 else 115.0
	var inicio_x = centro_x - ((cantidad - 1) * espaciado / 2.0)
	
	for i in range(cantidad):
		var p_inst = escena_palanca.instantiate()
		contenedor_palancas.add_child(p_inst)
		var target_x = inicio_x + (i * espaciado)
		p_inst.configurar(config[i]["id"], config[i]["color"], config[i]["bomba"])
		p_inst.animar_emerger(target_x, pos_y)
		palancas_instanciadas.append(p_inst)
		
	indice_palanca_actual = 0
	actualizar_seleccion_visual_palanca()

func actualizar_seleccion_visual_palanca():
	for i in range(palancas_instanciadas.size()):
		var p = palancas_instanciadas[i]
		p.set_seleccionada(i == indice_palanca_actual)

# --- CAMINATAS SCRIPTEADAS ---

func caminar_hacia_escenario(avatar: Node2D, target_x: float):
	if not avatar: return
	
	var sprite = avatar.get_node_or_null("Sprite")
	if sprite and "prefijo_personaje" in avatar:
		sprite.play(avatar.prefijo_personaje + "_caminar")
		
	if sprite: sprite.flip_h = false
	var tween1 = create_tween().set_trans(Tween.TRANS_LINEAR)
	var dist1 = abs(X_ESCALERA_DER - avatar.global_position.x)
	tween1.tween_property(avatar, "global_position:x", X_ESCALERA_DER, max(dist1 / 300.0, 0.2))
	await tween1.finished
	
	var tween2 = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween2.tween_property(avatar, "global_position:y", Y_PLATAFORMA, 0.35)
	await tween2.finished
	
	if sprite: sprite.flip_h = true
	var tween3 = create_tween().set_trans(Tween.TRANS_LINEAR)
	var dist3 = abs(avatar.global_position.x - target_x)
	tween3.tween_property(avatar, "global_position:x", target_x, max(dist3 / 300.0, 0.2))
	await tween3.finished
	
	if sprite:
		sprite.flip_h = false
		if "prefijo_personaje" in avatar:
			sprite.play(avatar.prefijo_personaje + "_idle")

func caminar_hacia_cola(avatar: Node2D, target_cola: Vector2):
	if not avatar: return
	
	var sprite = avatar.get_node_or_null("Sprite")
	if sprite and "prefijo_personaje" in avatar:
		sprite.play(avatar.prefijo_personaje + "_caminar")
		
	if sprite: sprite.flip_h = true
	var tween1 = create_tween().set_trans(Tween.TRANS_LINEAR)
	var dist1 = abs(avatar.global_position.x - X_ESCALERA_IZQ)
	tween1.tween_property(avatar, "global_position:x", X_ESCALERA_IZQ, max(dist1 / 300.0, 0.2))
	await tween1.finished
	
	var tween2 = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween2.tween_property(avatar, "global_position:y", Y_SUELO_INFERIOR, 0.35)
	await tween2.finished
	
	if sprite: sprite.flip_h = false
	var tween3 = create_tween().set_trans(Tween.TRANS_LINEAR)
	var dist3 = abs(target_cola.x - avatar.global_position.x)
	tween3.tween_property(avatar, "global_position:x", target_cola.x, max(dist3 / 300.0, 0.2))
	await tween3.finished
	
	if sprite and "prefijo_personaje" in avatar:
		sprite.play(avatar.prefijo_personaje + "_idle")

# --- FLUJO DE TURNOS ---

func avanzar_siguiente_turno():
	if estado_juego == EstadoJuego.FIN_PARTIDA: return
	if cola_jugadores.is_empty(): return
	
	turno_actual_id = cola_jugadores[0]
	
	if es_autoridad_de_partida():
		rpc("iniciar_turno_jugador_rpc", turno_actual_id)

@rpc("any_peer", "call_local", "reliable")
func iniciar_turno_jugador_rpc(id_jugador: int):
	turno_actual_id = id_jugador
	estado_juego = EstadoJuego.INICIO_TURNO
	tiempo_turno = 10.0
	label_cuenta_bomba.text = ""
	
	var avatar = get_node_or_null(str(id_jugador))
	var nombre_jugador = "Jugador " + str(id_jugador)
	if avatar and "label_nick" in avatar and avatar.label_nick:
		nombre_jugador = avatar.label_nick.text
		
	if label_jugador_turno:
		label_jugador_turno.text = "TURNO: " + nombre_jugador.to_upper()
		
	if not palancas_instanciadas.is_empty():
		for i in range(palancas_instanciadas.size()):
			if not palancas_instanciadas[i].activada:
				indice_palanca_actual = i
				break
		actualizar_seleccion_visual_palanca()
	
	if avatar and not palancas_instanciadas.is_empty():
		var pos_palanca_x = palancas_instanciadas[indice_palanca_actual].global_position.x
		await caminar_hacia_escenario(avatar, pos_palanca_x)
		
	estado_juego = EstadoJuego.TURNO_JUGADOR

func _process(delta):
	# Deriva horizontal suave de la niebla
	for b in bancos_niebla:
		if b["nodo"] and is_instance_valid(b["nodo"]):
			b["nodo"].position.x += b["vel"] * delta
			if b["vel"] > 0 and b["nodo"].position.x > 1200.0:
				b["nodo"].position.x = -b["w"] - 50.0
			elif b["vel"] < 0 and b["nodo"].position.x < -b["w"] - 50.0:
				b["nodo"].position.x = 1200.0

	if estado_juego == EstadoJuego.TURNO_JUGADOR:
		tiempo_turno -= delta
		if label_timer:
			label_timer.text = "%02d" % int(max(tiempo_turno, 0))
			if tiempo_turno <= 3.0:
				label_timer.add_theme_color_override("font_color", Color.RED)
			else:
				label_timer.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
				
		if tiempo_turno <= 0.0:
			if es_autoridad_de_partida():
				auto_seleccionar_palanca_expirada()
			return
			
		if multiplayer.get_unique_id() == turno_actual_id:
			manejar_input_turno()

func auto_seleccionar_palanca_expirada():
	var disponibles = []
	for i in range(palancas_instanciadas.size()):
		if not palancas_instanciadas[i].activada:
			disponibles.append(i)
	if disponibles.size() > 0:
		var eleccion = disponibles[randi() % disponibles.size()]
		var duracion_suspenso = randf_range(3.0, 4.5)
		rpc("ejecutar_presion_palanca_rpc", turno_actual_id, eleccion, duracion_suspenso)

func manejar_input_turno():
	var cambio = 0
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("a"):
		cambio = -1
	elif Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("d"):
		cambio = 1
		
	if cambio != 0:
		var total = palancas_instanciadas.size()
		var nuevo_idx = indice_palanca_actual
		for _paso in range(total):
			nuevo_idx = (nuevo_idx + cambio + total) % total
			if not palancas_instanciadas[nuevo_idx].activada:
				rpc("sincronizar_seleccion_palanca_rpc", turno_actual_id, nuevo_idx, cambio)
				break
				
	if Input.is_action_just_pressed("ui_accept"):
		confirmar_palanca_actual()

@rpc("any_peer", "call_local", "reliable")
func sincronizar_seleccion_palanca_rpc(id_jugador: int, nuevo_idx: int, dir: int):
	if id_jugador != turno_actual_id: return
	indice_palanca_actual = nuevo_idx
	actualizar_seleccion_visual_palanca()
	
	var avatar = get_node_or_null(str(id_jugador))
	if avatar:
		var pos_p = palancas_instanciadas[nuevo_idx].global_position
		var sprite = avatar.get_node_or_null("Sprite")
		if sprite:
			sprite.flip_h = (dir < 0)
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(avatar, "global_position:x", pos_p.x, 0.15)
		await tween.finished
		if sprite:
			sprite.flip_h = false

func confirmar_palanca_actual():
	if indice_palanca_actual >= 0 and indice_palanca_actual < palancas_instanciadas.size():
		if not palancas_instanciadas[indice_palanca_actual].activada:
			estado_juego = EstadoJuego.ACCION_PALANCA
			solicitar_presionar_palanca_rpc.rpc(turno_actual_id, indice_palanca_actual)

@rpc("any_peer", "call_local", "reliable")
func solicitar_presionar_palanca_rpc(id_jugador: int, idx: int):
	if not es_autoridad_de_partida(): return
	if estado_juego == EstadoJuego.FIN_PARTIDA: return
	if id_jugador != turno_actual_id: return
	
	var duracion_suspenso = randf_range(3.0, 4.5)
	rpc("ejecutar_presion_palanca_rpc", id_jugador, idx, duracion_suspenso)

@rpc("any_peer", "call_local", "reliable")
func ejecutar_presion_palanca_rpc(id_jugador: int, idx: int, tiempo_suspenso: float):
	estado_juego = EstadoJuego.ACCION_PALANCA
	var palanca = palancas_instanciadas[idx]
	var avatar = get_node_or_null(str(id_jugador))
	
	if avatar:
		var pos_palanca = palanca.global_position
		avatar.global_position.x = pos_palanca.x
		if "sprite" in avatar and "prefijo_personaje" in avatar:
			avatar.sprite.play(avatar.prefijo_personaje + "_saltar")
			
		var tween_salto = create_tween()
		tween_salto.tween_property(avatar, "global_position:y", pos_palanca.y + 20.0, 0.15)
		tween_salto.tween_property(avatar, "global_position:y", Y_PLATAFORMA, 0.15)
		await tween_salto.finished
		if "sprite" in avatar and "prefijo_personaje" in avatar:
			avatar.sprite.play(avatar.prefijo_personaje + "_idle")
		
	palanca.animar_bajada()
	
	# FASE DE SUSPENSO: Niebla se esparce por el escenario y Sunday Silence aparece lentamente
	await animar_suspenso_niebla_y_aparicion(tiempo_suspenso)
	
	# RESOLUCION TRAS EL SUSPENSO: SEGURO O BOMBA
	if palanca.es_bomba:
		await detonar_bomba_jugador(id_jugador)
	else:
		await resolver_acierto_seguro(id_jugador)

func animar_suspenso_niebla_y_aparicion(duracion: float):
	cabeza_bomba.visible = true
	cabeza_bomba.modulate.a = 0.0
	cabeza_bomba.scale = Vector2.ONE
	cabeza_bomba.position = Vector2(576, 175)
	
	if sprite_sunday:
		sprite_sunday.texture = tex_sunday_channel
	
	var tw_suspenso = create_tween().set_parallel(true)
	
	# 1. El escenario se oscurece y los faroles se atenúan
	if filtro_oscuridad:
		tw_suspenso.tween_property(filtro_oscuridad, "color:a", 0.70, duracion * 0.4).set_trans(Tween.TRANS_SINE)
	if farol_izq:
		tw_suspenso.tween_property(farol_izq, "color", Color(0.65, 0.48, 0.2, 0.4), duracion * 0.35)
	if farol_der:
		tw_suspenso.tween_property(farol_der, "color", Color(0.65, 0.48, 0.2, 0.4), duracion * 0.35)
		
	# 2. Los bancos de niebla se densifican y fluyen por el escenario
	for b in bancos_niebla:
		if b["nodo"] and is_instance_valid(b["nodo"]):
			tw_suspenso.tween_property(b["nodo"], "modulate:a", b["alpha_target"], duracion * 0.55).set_trans(Tween.TRANS_SINE)
			
	# 3. Sunday Silence aparece LENTAMENTE de entre la niebla (fade-in gradual, sin vibración)
	tw_suspenso.tween_property(cabeza_bomba, "modulate:a", 1.0, duracion * 0.85).set_trans(Tween.TRANS_SINE)
	
	await tw_suspenso.finished
	
	# Breve pausa inmóvil de máxima tensión antes de revelar si es segura o bomba
	await get_tree().create_timer(0.4).timeout

func desvanecer_sunday_silence_y_niebla(duracion: float = 1.2):
	var tw = create_tween().set_parallel(true)
	tw.tween_property(cabeza_bomba, "modulate:a", 0.0, duracion).set_trans(Tween.TRANS_SINE)
	if filtro_oscuridad:
		tw.tween_property(filtro_oscuridad, "color:a", 0.0, duracion).set_trans(Tween.TRANS_SINE)
	if farol_izq:
		tw.tween_property(farol_izq, "color", Color(1, 0.85, 0.35, 0.9), duracion)
	if farol_der:
		tw.tween_property(farol_der, "color", Color(1, 0.85, 0.35, 0.9), duracion)
		
	for b in bancos_niebla:
		if b["nodo"] and is_instance_valid(b["nodo"]):
			tw.tween_property(b["nodo"], "modulate:a", 0.0, duracion).set_trans(Tween.TRANS_SINE)
			
	await tw.finished
	cabeza_bomba.visible = false
	cabeza_bomba.scale = Vector2.ONE
	cabeza_bomba.position = Vector2(576, 175)
	if sprite_sunday:
		sprite_sunday.texture = tex_sunday_idle

func resolver_acierto_seguro(id_jugador: int):
	var avatar = get_node_or_null(str(id_jugador))
	if avatar and "sprite" in avatar and "prefijo_personaje" in avatar:
		avatar.sprite.play(avatar.prefijo_personaje + "_acierto")
		
	# Sunday Silence y la niebla se desvanecen lentamente despejando el mapa
	await desvanecer_sunday_silence_y_niebla(1.3)
	
	cola_jugadores.erase(id_jugador)
	cola_jugadores.append(id_jugador)
	
	var idx_final = cola_jugadores.size() - 1
	var pos_cola_destino = puntos_cola.get_node(str(idx_final)).global_position
	await caminar_hacia_cola(avatar, pos_cola_destino)
	
	if es_autoridad_de_partida():
		sincronizar_cola_servidor()
		seguras_restantes_en_set -= 1
		
		var quedan_activas = false
		for p in palancas_instanciadas:
			if not p.activada:
				quedan_activas = true
				break
				
		if seguras_restantes_en_set <= 0 or not quedan_activas:
			reiniciar_palancas_siguiente_ciclo()
		else:
			avanzar_siguiente_turno()

# --- DETONACION Y ELIMINACIONES VARIADAS Y COMICAS ---

func detonar_bomba_jugador(id_jugador: int):
	# El servidor elige aleatoriamente entre los 5 métodos cómicos de eliminación
	if es_autoridad_de_partida():
		var metodo = randi() % 5
		rpc("ejecutar_eliminacion_variada_rpc", id_jugador, metodo)

func mostrar_emoticono_sudor(pos: Vector2):
	if texturas_sweat.is_empty(): return
	var sp = Sprite2D.new()
	sp.texture = texturas_sweat[randi() % texturas_sweat.size()]
	sp.global_position = pos
	sp.scale = Vector2(1.6, 1.6)
	sp.z_index = 40
	add_child(sp)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sp, "global_position:y", pos.y - 20.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "modulate:a", 0.0, 0.55)
	tw.finished.connect(sp.queue_free)

@rpc("any_peer", "call_local", "reliable")
func ejecutar_eliminacion_variada_rpc(id_jugador: int, metodo: int):
	var avatar = get_node_or_null(str(id_jugador))
	if not avatar: return
	
	# Reacción de sorpresa en los espectadores de la cola
	for id in cola_jugadores:
		if id != id_jugador:
			var espectador = get_node_or_null(str(id))
			if espectador and "sprite" in espectador and "prefijo_personaje" in espectador:
				espectador.sprite.play(espectador.prefijo_personaje + "_impacto")
				
	match metodo:
		TipoEliminacion.FALSO_ALIVIO:
			await _animar_elim_falso_alivio(avatar)
		TipoEliminacion.ABDUCCION_OVNI:
			await _animar_elim_abduccion_ovni(avatar)
		TipoEliminacion.EXPLOSION_PROPS:
			await _animar_elim_explosion_props(avatar)
		TipoEliminacion.TRAMPILLA:
			await _animar_elim_trampilla(avatar)
		TipoEliminacion.MANO_MAGICA:
			await _animar_elim_mano_magica(avatar)
			
	avatar.visible = false
	avatar.set_physics_process(false)
	
	cola_jugadores.erase(id_jugador)
	
	if es_autoridad_de_partida():
		sincronizar_cola_servidor()
		if cola_jugadores.size() <= 1:
			var id_ganador = cola_jugadores[0] if cola_jugadores.size() > 0 else 1
			await get_tree().create_timer(0.8).timeout
			rpc("declarar_ganador_final_rpc", id_ganador)
		else:
			en_fase_tres_palancas = (cola_jugadores.size() <= 3)
			reiniciar_palancas_siguiente_ciclo()

# METODO 1: Falso Alivio -> Sunday Silence se desvanece dando la impresión de salvado.
# La uma camina alegremente hacia la escalera izquierda, se detiene, Sunday Silence
# se materializa DETRÁS de ella, se toman un momento de suspenso, y se la lleva por la IZQUIERDA.
func _animar_elim_falso_alivio(avatar: Node2D):
	# 1. Alivio momentáneo pausado
	if "sprite" in avatar and "prefijo_personaje" in avatar:
		avatar.sprite.play(avatar.prefijo_personaje + "_acierto")
	await get_tree().create_timer(0.7).timeout
		
	# Sunday Silence y la niebla se disuelven dando la ilusión de salvado
	await desvanecer_sunday_silence_y_niebla(1.0)
	await get_tree().create_timer(0.3).timeout
	
	# 2. La uma camina alegremente hacia la escalera izquierda
	var sprite = avatar.get_node_or_null("Sprite")
	if sprite and "prefijo_personaje" in avatar:
		sprite.play(avatar.prefijo_personaje + "_caminar")
	if sprite: sprite.flip_h = true
	
	var tw_caminar = create_tween().set_trans(Tween.TRANS_LINEAR)
	var punto_detencion_x = X_ESCALERA_IZQ + 65.0
	var dist = abs(avatar.global_position.x - punto_detencion_x)
	tw_caminar.tween_property(avatar, "global_position:x", punto_detencion_x, max(dist / 220.0, 0.7))
	await tw_caminar.finished
	
	# 3. ¡El jugador se detiene en seco en el descanso de la escalera!
	if sprite and "prefijo_personaje" in avatar:
		sprite.play(avatar.prefijo_personaje + "_idle")
	await get_tree().create_timer(0.35).timeout
	
	# 4. Sunday Silence emerge claramente DETRÁS del jugador (a su derecha, ya que mira a la izquierda)
	cabeza_bomba.position = Vector2(avatar.global_position.x + 55.0, avatar.global_position.y - 35.0)
	cabeza_bomba.scale = Vector2(1.25, 1.25)
	cabeza_bomba.visible = true
	cabeza_bomba.modulate.a = 0.0
	if sprite_sunday:
		sprite_sunday.texture = tex_sunday_cast
		
	# Destello tétrico y aparición clara
	flash_explosion.color = Color(0.25, 0.05, 0.35, 0.6)
	flash_explosion.visible = true
	var tw_flash = create_tween()
	tw_flash.tween_property(flash_explosion, "modulate:a", 0.75, 0.08)
	tw_flash.tween_property(flash_explosion, "modulate:a", 0.0, 0.35)
	
	var tw_aparicion = create_tween()
	tw_aparicion.tween_property(cabeza_bomba, "modulate:a", 1.0, 0.35)
	await tw_aparicion.finished
	
	# Gotita de sudor y giro de la uma para mirar hacia atrás en shock
	mostrar_emoticono_sudor(avatar.global_position + Vector2(0, -55))
	if sprite and "prefijo_personaje" in avatar:
		sprite.play(avatar.prefijo_personaje + "_impacto")
		sprite.flip_h = false # Se da vuelta mirando a Sunday Silence directamente
		
	# Pausa deliberada para que los jugadores procesen el momento cómico
	await get_tree().create_timer(0.85).timeout
	
	# 5. Sunday Silence envuelve a la uma y se la lleva velozmente fuera por la IZQUIERDA
	if sprite: sprite.flip_h = true
	var tw_drag = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_drag.tween_property(avatar, "global_position:x", -280.0, 0.65)
	tw_drag.tween_property(cabeza_bomba, "position:x", -230.0, 0.65)
	tw_drag.tween_property(avatar, "rotation", -5.0, 0.65)
	await tw_drag.finished
	
	cabeza_bomba.visible = false
	cabeza_bomba.scale = Vector2.ONE
	cabeza_bomba.position = Vector2(576, 175)
	if sprite_sunday:
		sprite_sunday.texture = tex_sunday_idle
	await get_tree().create_timer(0.5).timeout

# METODO 2: Abducción extraterrestre pausada con cono de luz cósmico
func _animar_elim_abduccion_ovni(avatar: Node2D):
	if sprite_sunday:
		sprite_sunday.texture = tex_sunday_cast
	var tw_ss = create_tween()
	tw_ss.tween_property(cabeza_bomba, "scale", Vector2(1.2, 1.2), 0.3)
	await get_tree().create_timer(0.4).timeout
	
	# 1. Haz de luz en cono brillante desciende desde el cielo
	var cono = Polygon2D.new()
	var pos_av = avatar.global_position
	cono.color = Color(0.12, 0.95, 0.85, 0.45)
	cono.polygon = PackedVector2Array([
		Vector2(pos_av.x - 25, 0),
		Vector2(pos_av.x + 25, 0),
		Vector2(pos_av.x + 95, pos_av.y + 45),
		Vector2(pos_av.x - 95, pos_av.y + 45)
	])
	cono.z_index = 25
	cono.modulate.a = 0.0
	add_child(cono)
	
	var tw_cono = create_tween()
	tw_cono.tween_property(cono, "modulate:a", 1.0, 0.4)
	await tw_cono.finished
	
	# 2. El personaje se da cuenta, mira hacia arriba y entra en pánico
	if "sprite" in avatar and "prefijo_personaje" in avatar:
		avatar.sprite.play(avatar.prefijo_personaje + "_impacto")
	mostrar_emoticono_sudor(avatar.global_position + Vector2(0, -55))
	await get_tree().create_timer(0.6).timeout
	
	# 3. Flotación pausada hacia el espacio mientras patalea desesperada
	if "sprite" in avatar and "prefijo_personaje" in avatar:
		avatar.sprite.play(avatar.prefijo_personaje + "_aturdido")
		
	var tw_beam = create_tween().set_parallel(true)
	tw_beam.tween_property(avatar, "global_position:y", -180.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw_beam.tween_property(avatar, "rotation", 6.0, 2.4)
	
	desvanecer_sunday_silence_y_niebla(1.8)
	await tw_beam.finished
	
	# Apagar el cono de luz con destello
	var tw_c_out = create_tween()
	tw_c_out.tween_property(cono, "modulate:a", 0.0, 0.3)
	await tw_c_out.finished
	cono.queue_free()
	await get_tree().create_timer(0.5).timeout

# METODO 3: Explosión cómica clásica con sprites de props
func _animar_elim_explosion_props(avatar: Node2D):
	if sprite_sunday:
		sprite_sunday.texture = tex_sunday_cast
	cabeza_bomba.scale = Vector2(1.3, 1.3)
	
	# 1. Tensión previa: mecha / aviso de detonación
	if "sprite" in avatar and "prefijo_personaje" in avatar:
		avatar.sprite.play(avatar.prefijo_personaje + "_impacto")
	mostrar_emoticono_sudor(avatar.global_position + Vector2(0, -50))
	await get_tree().create_timer(0.65).timeout
	
	# 2. Explosión animada con sprites de props
	var spr_exp = Sprite2D.new()
	spr_exp.scale = Vector2(2.6, 2.6)
	spr_exp.global_position = avatar.global_position + Vector2(0, -10)
	spr_exp.z_index = 35
	add_child(spr_exp)
	
	flash_explosion.color = Color(1.0, 0.82, 0.2, 0.85)
	flash_explosion.visible = true
	var tw_flash = create_tween()
	tw_flash.tween_property(flash_explosion, "modulate:a", 0.95, 0.05)
	tw_flash.tween_property(flash_explosion, "modulate:a", 0.0, 0.3)
	
	# 3. Lanzamiento balístico de la uma por los aires
	var tw_av = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_av.tween_property(avatar, "global_position:y", -320.0, 0.7)
	tw_av.tween_property(avatar, "global_position:x", avatar.global_position.x + randf_range(-100, 100), 0.7)
	tw_av.tween_property(avatar, "rotation", 14.0, 0.7)
	
	if not texturas_explosion.is_empty():
		for tex in texturas_explosion:
			spr_exp.texture = tex
			await get_tree().create_timer(0.065).timeout
	else:
		await get_tree().create_timer(0.7).timeout
		
	spr_exp.queue_free()
	flash_explosion.visible = false
	desvanecer_sunday_silence_y_niebla(0.9)
	await tw_av.finished
	await get_tree().create_timer(0.5).timeout

# METODO 4: Trampilla cómica clásica estilo Coyote y Correcaminos
func _animar_elim_trampilla(avatar: Node2D):
	await get_tree().create_timer(0.3).timeout
	
	# 1. Crear el hueco oscuro bajo los pies
	var agujero = Polygon2D.new()
	agujero.color = Color(0.06, 0.03, 0.1, 1.0)
	var pos_av = avatar.global_position
	agujero.polygon = PackedVector2Array([
		Vector2(pos_av.x - 38, pos_av.y + 12),
		Vector2(pos_av.x + 38, pos_av.y + 12),
		Vector2(pos_av.x + 32, pos_av.y + 36),
		Vector2(pos_av.x - 32, pos_av.y + 36)
	])
	agujero.z_index = avatar.z_index - 1
	add_child(agujero)
	
	# 2. La compuerta de madera se abre hacia abajo con bisagra (Clack!)
	var tapa = ColorRect.new()
	tapa.color = Color(0.36, 0.22, 0.16, 1.0)
	tapa.size = Vector2(76, 8)
	tapa.pivot_offset = Vector2(0, 4)
	tapa.position = Vector2(pos_av.x - 38, pos_av.y + 12)
	tapa.z_index = avatar.z_index - 1
	add_child(tapa)
	
	var tw_tapa = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw_tapa.tween_property(tapa, "rotation_degrees", 95.0, 0.14)
	await tw_tapa.finished
	
	# 3. BEAT COYOTE: Suspensión flotando en el aire sin darse cuenta
	await get_tree().create_timer(0.4).timeout
	
	# Mira hacia abajo y nota el vacío
	if "sprite" in avatar and "prefijo_personaje" in avatar:
		avatar.sprite.play(avatar.prefijo_personaje + "_impacto")
	mostrar_emoticono_sudor(avatar.global_position + Vector2(0, -50))
	await get_tree().create_timer(0.45).timeout
	
	# Intenta correr en el aire desesperadamente
	if "sprite" in avatar and "prefijo_personaje" in avatar:
		avatar.sprite.play(avatar.prefijo_personaje + "_correr")
	await get_tree().create_timer(0.6).timeout
	
	# Se resigna, mira a la pantalla
	if "sprite" in avatar and "prefijo_personaje" in avatar:
		avatar.sprite.play(avatar.prefijo_personaje + "_aturdido")
	await get_tree().create_timer(0.35).timeout
	
	# 4. Caída libre fulminante a plomo por el agujero
	var tw_caer = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_caer.tween_property(avatar, "global_position:y", 750.0, 0.35)
	tw_caer.tween_property(avatar, "scale", Vector2(0.2, 1.6), 0.35)
	await tw_caer.finished
	
	desvanecer_sunday_silence_y_niebla(0.7)
	
	# La compuerta se cierra
	var tw_cerrar = create_tween()
	tw_cerrar.tween_property(tapa, "rotation_degrees", 0.0, 0.2)
	await tw_cerrar.finished
	agujero.queue_free()
	tapa.queue_free()
	await get_tree().create_timer(0.5).timeout

# METODO 5: Mano mágica gigante de caricatura pausada
func _animar_elim_mano_magica(avatar: Node2D):
	await get_tree().create_timer(0.35).timeout
	
	var nodo_mano = Node2D.new()
	nodo_mano.z_index = 25
	nodo_mano.global_position = Vector2(1200.0, avatar.global_position.y - 10.0)
	
	var spr_mano = Sprite2D.new()
	spr_mano.texture = tex_magic_hand
	spr_mano.scale = Vector2(3.0, 3.0)
	nodo_mano.add_child(spr_mano)
	
	var spr_barra = Sprite2D.new()
	spr_barra.texture = tex_magic_bar
	spr_barra.scale = Vector2(4.0, 2.5)
	spr_barra.position = Vector2(60, 0)
	nodo_mano.add_child(spr_barra)
	
	add_child(nodo_mano)
	
	# 1. Extensión rápida del guante
	var tw_punch = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_punch.tween_property(nodo_mano, "global_position:x", avatar.global_position.x + 15.0, 0.25)
	await tw_punch.finished
	
	# 2. Impacto y forcejeo pausado
	if "sprite" in avatar and "prefijo_personaje" in avatar:
		avatar.sprite.play(avatar.prefijo_personaje + "_impacto")
	mostrar_emoticono_sudor(avatar.global_position + Vector2(0, -50))
	await get_tree().create_timer(0.55).timeout
	
	# 3. Retracción veloz llevándose al personaje hacia la derecha
	var tw_drag = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_drag.tween_property(nodo_mano, "global_position:x", 1350.0, 0.45)
	tw_drag.tween_property(avatar, "global_position:x", 1300.0, 0.45)
	tw_drag.tween_property(avatar, "rotation", 5.0, 0.45)
	
	desvanecer_sunday_silence_y_niebla(0.8)
	await tw_drag.finished
	nodo_mano.queue_free()
	await get_tree().create_timer(0.5).timeout
func reiniciar_palancas_siguiente_ciclo():
	if not es_autoridad_de_partida():
		return
		
	estado_juego = EstadoJuego.RESET_PALANCAS
	rpc("ocultar_palancas_rpc")
	await get_tree().create_timer(0.45).timeout
	
	var cant = 3 if en_fase_tres_palancas else 5
	generar_palancas_servidor(cant)
	
	await get_tree().create_timer(0.5).timeout
	avanzar_siguiente_turno()

@rpc("any_peer", "call_local", "reliable")
func ocultar_palancas_rpc():
	for p in palancas_instanciadas:
		if is_instance_valid(p):
			p.animar_ocultar()

@rpc("any_peer", "call_local", "reliable")
func declarar_ganador_final_rpc(id_ganador: int):
	estado_juego = EstadoJuego.FIN_PARTIDA
	if panel_turno:
		panel_turno.visible = false
		
	var ids = []
	if id_ganador > 0:
		ids.append(id_ganador)
	elif cola_jugadores.size() > 0:
		ids.append(cola_jugadores[0])
		
	var centro = Vector2(576.0, 520.0)
	ejecutar_secuencia_victoria(ids, centro)
