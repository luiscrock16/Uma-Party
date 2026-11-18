extends BaseMinijuego

# Nodos del Escenario
@onready var sol_poniente = $SolPoniente
@onready var farol_poste = $FarolPoste
@onready var destello_senal = $FarolPoste/DestelloSenal
@onready var contenedor_estepicursores = $ContenedorEstepicursores
@onready var filtro_noche = $FiltroNoche
@onready var efecto_destello = $EfectoDestelloDisparo
@onready var fogata_centro = $FogataCentro
@onready var luz_fogata = $FogataCentro/LuzFogata
@onready var chispas_fogata = $FogataCentro/Chispas
@onready var camera = $Camera2D

# HUD Cinematográfico
@onready var barra_cine_sup = $HUD/BarraCineSuperior
@onready var barra_cine_inf = $HUD/BarraCineInferior

# Roles de los Jugadores
var id_duelista_0: int = 1
var id_duelista_1: int = 2
var lista_espectadores: Array = []
var avatares_jugadores: Dictionary = {}

# Posiciones de Duelo
const POS_CENTRO_D0: Vector2 = Vector2(540, 480)
const POS_CENTRO_D1: Vector2 = Vector2(612, 480)
const POS_DUELO_0: Vector2 = Vector2(360, 480)
const POS_DUELO_1: Vector2 = Vector2(792, 480)
const POS_ESP_0: Vector2 = Vector2(190, 425)
const POS_ESP_1: Vector2 = Vector2(960, 425)

# Estado de la Partida y Duelo
var partida_iniciada: bool = false
var partida_terminada: bool = false
var noche_caida: bool = false
var senal_disparo_dada: bool = false
var tiempo_senal_disparo: float = 0.0
var duelo_resuelto: bool = false
var id_ganador_duelo: int = -1

# Tumbleweeds (Estepicursores)
var timer_estepicursor: float = 1.0
var textura_estepicursor: Texture2D

func _ready():
	modo_actual = Modo.FFA
	if has_node("/root/Global"):
		get_node("/root/Global").establecer_texto_accion_tactil("¡DESENFUNDAR!")
		
	partida_iniciada = false
	partida_terminada = false
	noche_caida = false
	senal_disparo_dada = false
	duelo_resuelto = false
	id_ganador_duelo = -1
	
	if camera:
		camera.make_current()
	
	textura_estepicursor = preload("res://assets/minijuegos/duelo/estepicursor.png")
	
	if fogata_centro:
		fogata_centro.visible = false
	if destello_senal:
		destello_senal.modulate.a = 0.0
	if filtro_noche:
		filtro_noche.color = Color(0.04, 0.03, 0.08, 0.0)
	if efecto_destello:
		efecto_destello.color = Color(1.0, 1.0, 1.0, 0.0)
		
	# Barras cinematográficas inicialmente replegadas fuera de pantalla
	if barra_cine_sup:
		barra_cine_sup.position.y = -600.0
		barra_cine_sup.rotation_degrees = 0.0
	if barra_cine_inf:
		barra_cine_inf.position.y = 648.0
		barra_cine_inf.rotation_degrees = 0.0
		
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		solicitar_info_minijuego_al_servidor.rpc_id(1)
		
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	jugadores_info.clear()
	# P1 y P2 son los duelistas principales; P3 y P4 son espectadores en la acera
	for i in range(4):
		var id = i + 1
		jugadores_info[id] = {"equipo": i, "spawn": i, "es_jefe": false}
		if not has_node(str(id)):
			var av = preload("res://escenas/personaje_jugable.tscn").instantiate()
			av.name = str(id)
			add_child(av)
			av.configurar_visual(i, "P" + str(i + 1))
			
	aplicar_roles_locales()

func aplicar_roles_locales():
	avatares_jugadores.clear()
	lista_espectadores.clear()
	
	var ids = []
	for k in jugadores_info.keys():
		ids.append(int(k))
	ids.sort()
	
	if ids.size() >= 2:
		id_duelista_0 = ids[0]
		id_duelista_1 = ids[1]
		for i in range(2, ids.size()):
			lista_espectadores.append(ids[i])
	elif ids.size() == 1:
		id_duelista_0 = ids[0]
		id_duelista_1 = 9999
		if not has_node("9999"):
			var av_bot = preload("res://escenas/personaje_jugable.tscn").instantiate()
			av_bot.name = "9999"
			add_child(av_bot)
			av_bot.configurar_visual(1, "Gold Ship (Bot)")
		if not ids.has(9999):
			ids.append(9999)
		
	for id in ids:
		var av = get_node_or_null(str(id))
		if not av and get_tree().root:
			av = get_tree().root.find_child(str(id), true, false)
			
		if av:
			avatares_jugadores[id] = av
			av.bloquear_controles(true)
			av.set_physics_process(false)
			av.set_process(false)
			av.velocity = Vector2.ZERO
			av.rotation = 0.0
			av.rotation_degrees = 0.0
			av.modulate = Color.WHITE
			av.scale = Vector2.ONE
			av.visible = true
			av.z_index = 8
			
			if id == id_duelista_0:
				# Duelista 0 inicia en el centro mirando a la derecha (cara a cara con Duelista 1)
				av.global_position = POS_CENTRO_D0
				_mirar_hacia(av, true)
			elif id == id_duelista_1:
				# Duelista 1 inicia en el centro mirando a la izquierda (cara a cara con Duelista 0)
				av.global_position = POS_CENTRO_D1
				_mirar_hacia(av, false)
			elif lista_espectadores.find(id) == 0:
				av.global_position = POS_ESP_0
				_mirar_hacia(av, true) # Mirar al centro desde el Saloon
			else:
				av.global_position = POS_ESP_1
				_mirar_hacia(av, false) # Mirar al centro desde la comisaría
				
			_reproducir_animacion_avatar(av, "idle")
				
	if not instrucciones_mostradas:
		instrucciones_mostradas = true
		mostrar_pantalla_instrucciones()
	else:
		call_deferred("iniciar_secuencia_cuenta_atras")

func _mirar_hacia(av: CharacterBody2D, a_la_derecha: bool):
	if "sprite" in av and av.sprite:
		# En el spritesheet base, el sprite mira por defecto a la izquierda (flip_h = false).
		# Por lo tanto, para mirar a la derecha activamos flip_h = true.
		av.sprite.flip_h = a_la_derecha

func _reproducir_animacion_avatar(av: CharacterBody2D, nombre_anim: String):
	if not av or not "sprite" in av or not av.sprite: return
	var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
	if prefijo == null or str(prefijo) == "": prefijo = "SEIK"
	var nombre_completo = prefijo + "_" + nombre_anim
	if av.sprite.sprite_frames and av.sprite.sprite_frames.has_animation(nombre_completo):
		av.sprite.play(nombre_completo)
	elif av.sprite.sprite_frames and av.sprite.sprite_frames.has_animation(prefijo + "_idle"):
		av.sprite.play(prefijo + "_idle")

func _on_instrucciones_completadas():
	inicio_cuenta_atras.emit()
	al_completar_instrucciones()

func al_completar_instrucciones():
	iniciar_secuencia_cuenta_atras()

func iniciar_secuencia_cuenta_atras():
	ejecutar_overlay_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	# Asegurar bloqueo físico absoluto para todos los jugadores
	bloquear_jugadores(true)
	for av in avatares_jugadores.values():
		if is_instance_valid(av):
			av.bloquear_controles(true)
			av.set_physics_process(false)
			av.set_process(false)
			av.velocity = Vector2.ZERO
			
	partida_iniciada = true
	
	# Sincronización en red: El servidor coordina el inicio de la cinemática
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		if multiplayer.has_multiplayer_peer():
			sincronizar_inicio_duelo_rpc.rpc()
		else:
			sincronizar_inicio_duelo_rpc()

@rpc("authority", "call_local", "reliable")
func sincronizar_inicio_duelo_rpc():
	_iniciar_secuencia_cinematica_completa()

# ==============================================================================
# PROCESO AMBIENTAL: ESTEPICURSORES Y NIEBLA/FOGATA
# ==============================================================================

func _process(delta: float):
	_actualizar_estepicursores(delta)
	
	# Parpadeo suave de la fogata una vez encendida
	if fogata_centro and fogata_centro.visible and luz_fogata:
		var t = Time.get_ticks_msec() / 1000.0
		var pulso = 1.35 + sin(t * 7.5) * 0.08 + sin(t * 13.0) * 0.05
		luz_fogata.scale = Vector2(pulso, pulso * 0.85)

func _actualizar_estepicursores(delta: float):
	if not partida_terminada and not noche_caida:
		timer_estepicursor -= delta
		if timer_estepicursor <= 0.0:
			timer_estepicursor = randf_range(3.2, 5.0)
			_spawn_estepicursor()
			
	for estep in contenedor_estepicursores.get_children():
		var vel_x = estep.get_meta("vel_x", 140.0)
		var rebote_freq = estep.get_meta("rebote_freq", 6.0)
		var rebote_alt = estep.get_meta("rebote_alt", 14.0)
		var base_y = estep.get_meta("base_y", 520.0)
		var tiempo_vida = estep.get_meta("tiempo_vida", 0.0) + delta
		estep.set_meta("tiempo_vida", tiempo_vida)
		
		estep.position.x += vel_x * delta
		estep.rotation += (vel_x * 0.02) * delta
		estep.position.y = base_y - abs(sin(tiempo_vida * rebote_freq)) * rebote_alt
		
		if estep.position.x > 1220.0 or estep.position.x < -70.0:
			estep.queue_free()

func _spawn_estepicursor():
	if not textura_estepicursor: return
	var estep = Sprite2D.new()
	estep.texture = textura_estepicursor
	var desde_izq = (randf() > 0.5)
	var x_init = -40.0 if desde_izq else 1190.0
	var vel_x = randf_range(130.0, 180.0) * (1.0 if desde_izq else -1.0)
	var base_y = randf_range(470.0, 560.0)
	
	estep.position = Vector2(x_init, base_y)
	estep.set_meta("vel_x", vel_x)
	estep.set_meta("rebote_freq", randf_range(5.0, 7.5))
	estep.set_meta("rebote_alt", randf_range(12.0, 20.0))
	estep.set_meta("base_y", base_y)
	estep.set_meta("tiempo_vida", 0.0)
	contenedor_estepicursores.add_child(estep)

# ==============================================================================
# SECUENCIA CINEMÁTICA: CAMINATA DE ESPALDAS, LETTERBOX Y PRIMEROS PLANOS
# ==============================================================================

func _ajustar_letterbox(modo: String, duracion: float = 1.0):
	if not barra_cine_sup or not barra_cine_inf: return
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	match modo:
		"oculto":
			# -600.0 coloca el borde inferior de la barra superior en y=0 (oculta arriba)
			tw.tween_property(barra_cine_sup, "position:y", -600.0, duracion)
			tw.tween_property(barra_cine_sup, "rotation_degrees", 0.0, duracion)
			tw.tween_property(barra_cine_inf, "position:y", 648.0, duracion)
			tw.tween_property(barra_cine_inf, "rotation_degrees", 0.0, duracion)
		"estandar":
			# -530.0 coloca el borde inferior de la barra superior en y=70 (70px visibles arriba)
			tw.tween_property(barra_cine_sup, "position:y", -530.0, duracion)
			tw.tween_property(barra_cine_sup, "rotation_degrees", 0.0, duracion)
			tw.tween_property(barra_cine_inf, "position:y", 578.0, duracion)
			tw.tween_property(barra_cine_inf, "rotation_degrees", 0.0, duracion)
		"cerrado_d1":
			# -480.0 coloca el borde inferior en y=120 (120px simétricos) con inclinación de -2.5° para D1
			tw.tween_property(barra_cine_sup, "position:y", -480.0, duracion)
			tw.tween_property(barra_cine_sup, "rotation_degrees", -2.5, duracion)
			tw.tween_property(barra_cine_inf, "position:y", 528.0, duracion)
			tw.tween_property(barra_cine_inf, "rotation_degrees", -2.5, duracion)
		"cerrado_d2":
			# -480.0 coloca el borde inferior en y=120 (120px simétricos) con inclinación de +2.5° para D2
			tw.tween_property(barra_cine_sup, "position:y", -480.0, duracion)
			tw.tween_property(barra_cine_sup, "rotation_degrees", 2.5, duracion)
			tw.tween_property(barra_cine_inf, "position:y", 528.0, duracion)
			tw.tween_property(barra_cine_inf, "rotation_degrees", 2.5, duracion)

func _iniciar_secuencia_cinematica_completa():
	var av_0 = avatares_jugadores.get(id_duelista_0)
	if not av_0 or not is_instance_valid(av_0):
		av_0 = obtener_avatar_jugador(id_duelista_0)
		if av_0: avatares_jugadores[id_duelista_0] = av_0
		
	var av_1 = avatares_jugadores.get(id_duelista_1)
	if not av_1 or not is_instance_valid(av_1):
		av_1 = obtener_avatar_jugador(id_duelista_1)
		if av_1: avatares_jugadores[id_duelista_1] = av_1
	
	# -------------------------------------------------------------------------
	# FASE 0: CARA A CARA INICIAL EN EL CENTRO Y CAMINATA DE ESPALDAS A SUS MARCAS
	# -------------------------------------------------------------------------
	if av_0 and is_instance_valid(av_0):
		av_0.global_position = POS_CENTRO_D0
		_mirar_hacia(av_0, true) # Mirando a la derecha (cara a cara hacia D1)
		_reproducir_animacion_avatar(av_0, "idle")
	if av_1 and is_instance_valid(av_1):
		av_1.global_position = POS_CENTRO_D1
		_mirar_hacia(av_1, false) # Mirando a la izquierda (cara a cara hacia D0)
		_reproducir_animacion_avatar(av_1, "idle")
		
	# Miradas intensas cara a cara en el centro
	await get_tree().create_timer(0.8).timeout
	if partida_terminada: return
	
	# Se dan la vuelta de espaldas para caminar hacia sus posiciones
	if av_0 and is_instance_valid(av_0):
		_mirar_hacia(av_0, false) # Mira hacia adelante en dirección de marcha (izquierda)
		_reproducir_animacion_avatar(av_0, "caminar")
	if av_1 and is_instance_valid(av_1):
		_mirar_hacia(av_1, true) # Mira hacia adelante en dirección de marcha (derecha)
		_reproducir_animacion_avatar(av_1, "caminar")
		
	# Caminata solemne y lenta a sus marcas respectivas
	var tw_caminata = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if av_0 and is_instance_valid(av_0):
		tw_caminata.tween_property(av_0, "global_position", POS_DUELO_0, 2.4)
	if av_1 and is_instance_valid(av_1):
		tw_caminata.tween_property(av_1, "global_position", POS_DUELO_1, 2.4)
		
	await tw_caminata.finished
	if partida_terminada: return
	
	# Al llegar a sus marcas, se voltean de vuelta para encararse listos para el duelo
	if av_0 and is_instance_valid(av_0):
		_mirar_hacia(av_0, true) # Se voltea mirando al frente hacia D1 (derecha)
		_reproducir_animacion_avatar(av_0, "idle")
	if av_1 and is_instance_valid(av_1):
		_mirar_hacia(av_1, false) # Se voltea mirando al frente hacia D0 (izquierda)
		_reproducir_animacion_avatar(av_1, "idle")
		
	# Pausa de encare y fijación de postura
	await get_tree().create_timer(0.6).timeout
	if partida_terminada: return
	
	# -------------------------------------------------------------------------
	# FASE 1: LETTERBOX Y ENFOQUE AL SOL PONIENTE EN EL CAÑÓN
	# -------------------------------------------------------------------------
	_ajustar_letterbox("estandar", 1.4)
	
	var tw_cam_sol = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_cam_sol.tween_property(camera, "position", Vector2(576, 250), 3.2)
	tw_cam_sol.tween_property(camera, "zoom", Vector2(1.35, 1.35), 3.2)
	
	var tw_sol = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_sol.tween_property(sol_poniente, "position:y", 385.0, 4.2)
	tw_sol.parallel().tween_property(sol_poniente, "color", Color(0.65, 0.15, 0.05, 0.0), 4.2)
	
	await tw_cam_sol.finished
	if partida_terminada: return
	
	# -------------------------------------------------------------------------
	# FASE 2: PRIMER PLANO HIPER CERCANO AL DUELISTA 1 (BARRAS MÁS CERRADAS Y ROTADAS)
	# -------------------------------------------------------------------------
	if av_0 and is_instance_valid(av_0):
		_ajustar_letterbox("cerrado_d1", 1.0)
		var tw_cam_p1 = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var pos_p1 = Vector2(av_0.global_position.x + 25.0, av_0.global_position.y - 8.0)
		tw_cam_p1.tween_property(camera, "position", pos_p1, 2.5)
		tw_cam_p1.tween_property(camera, "zoom", Vector2(3.6, 3.6), 2.5)
		await tw_cam_p1.finished
		if partida_terminada: return
		await get_tree().create_timer(0.6).timeout
		if partida_terminada: return
		
	# -------------------------------------------------------------------------
	# FASE 3: PRIMER PLANO HIPER CERCANO AL DUELISTA 2 (BARRAS MÁS CERRADAS Y ROTADAS)
	# -------------------------------------------------------------------------
	if av_1 and is_instance_valid(av_1):
		_ajustar_letterbox("cerrado_d2", 1.0)
		var tw_cam_p2 = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var pos_p2 = Vector2(av_1.global_position.x - 25.0, av_1.global_position.y - 8.0)
		tw_cam_p2.tween_property(camera, "position", pos_p2, 2.5)
		tw_cam_p2.tween_property(camera, "zoom", Vector2(3.6, 3.6), 2.5)
		await tw_cam_p2.finished
		if partida_terminada: return
		await get_tree().create_timer(0.6).timeout
		if partida_terminada: return
		
	# -------------------------------------------------------------------------
	# FASE 4: ENFOQUE AL FAROL Y CAÍDA COMPLETA DE LA NOCHE
	# -------------------------------------------------------------------------
	_ajustar_letterbox("estandar", 1.2)
	var tw_cam_farol = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_cam_farol.tween_property(camera, "position", Vector2(576, 335), 2.2)
	tw_cam_farol.tween_property(camera, "zoom", Vector2(1.6, 1.6), 2.2)
	
	var tw_noche = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_noche.tween_property(filtro_noche, "color", Color(0.04, 0.03, 0.08, 0.88), 2.8)
	for av in avatares_jugadores.values():
		if is_instance_valid(av):
			tw_noche.tween_property(av, "modulate", Color(0.12, 0.12, 0.18, 1.0), 2.8)
			
	await tw_cam_farol.finished
	if partida_terminada: return
	await tw_noche.finished
	noche_caida = true
	
	# -------------------------------------------------------------------------
	# FASE 5: PLANO GENERAL PANORÁMICO Y SUSPENSO EN SILUETAS
	# -------------------------------------------------------------------------
	var tw_cam_standoff = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_cam_standoff.tween_property(camera, "position", Vector2(576, 420), 2.2)
	tw_cam_standoff.tween_property(camera, "zoom", Vector2(1.22, 1.22), 2.2)
	await tw_cam_standoff.finished
	if partida_terminada: return
	
	# -------------------------------------------------------------------------
	# FASE 6: SEÑAL AMBIENTAL AUTORITARIA (SÓLO EL SERVIDOR / HOST DECIDE EL TIMING)
	# -------------------------------------------------------------------------
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var tiempo_suspense = randf_range(2.5, 4.0)
		await get_tree().create_timer(tiempo_suspense).timeout
		if partida_terminada or senal_disparo_dada: return
		
		# El servidor emite la señal a todos los clientes al mismo instante
		if multiplayer.has_multiplayer_peer():
			emitir_destello_senal_rpc.rpc()
		else:
			emitir_destello_senal_rpc()

@rpc("authority", "call_local", "reliable")
func emitir_destello_senal_rpc():
	if partida_terminada or senal_disparo_dada: return
	senal_disparo_dada = true
	tiempo_senal_disparo = Time.get_ticks_msec() / 1000.0
	
	# Destello visual en el farol del escenario
	if destello_senal:
		destello_senal.scale = Vector2(3.5, 3.5)
		destello_senal.modulate = Color(1.0, 1.0, 0.7, 1.0)
		var tw_dest = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		tw_dest.tween_property(destello_senal, "scale", Vector2(1.2, 1.2), 0.35)
		tw_dest.parallel().tween_property(destello_senal, "modulate:a", 0.0, 0.4)
		
	# Resplandor breve en pantalla
	if efecto_destello:
		efecto_destello.color = Color(1.0, 0.95, 0.75, 0.75)
		var tw_flash = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw_flash.tween_property(efecto_destello, "color:a", 0.0, 0.18)
		
	agitar_camara(5.0)
	
	# Si en local juega un bot en id_duelista_1, el host programa su disparo
	if (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()) and id_duelista_1 != -1:
		# Solo si id_duelista_1 no es un peer humano conectado
		var es_peer_humano = false
		if multiplayer.has_multiplayer_peer():
			es_peer_humano = (id_duelista_1 in multiplayer.get_peers()) or (id_duelista_1 == 1)
		if not es_peer_humano:
			_programar_reaccion_ia_bot()

func _programar_reaccion_ia_bot():
	var tiempo_reaccion_bot = randf_range(0.32, 0.48)
	await get_tree().create_timer(tiempo_reaccion_bot).timeout
	if not partida_terminada and senal_disparo_dada and not duelo_resuelto:
		recibir_intento_disparo_servidor(id_duelista_1)

# ==============================================================================
# GESTIÓN DE ENTRADA Y RESOLUCIÓN AUTORITARIA EN RED
# ==============================================================================

func _unhandled_input(event: InputEvent):
	if not partida_iniciada or partida_terminada or duelo_resuelto: return
	
	var pulsado = false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("espacio"):
		pulsado = true
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		pulsado = true
	elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		pulsado = true
		
	if pulsado:
		var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else id_duelista_0
		# Solo los dos duelistas participantes pueden desenfundar
		if mi_id != id_duelista_0 and mi_id != id_duelista_1:
			return
			
		solicitar_disparo(mi_id)

func solicitar_disparo(id_tirador: int):
	if partida_terminada or duelo_resuelto: return
	
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			recibir_intento_disparo_servidor(id_tirador)
		else:
			recibir_intento_disparo_servidor.rpc_id(1, id_tirador)
	else:
		recibir_intento_disparo_servidor(id_tirador)

@rpc("any_peer", "call_local", "reliable")
func recibir_intento_disparo_servidor(id_tirador: int):
	# ESTA EVALUACIÓN ES 100% AUTORITARIA EN EL SERVIDOR / HOST
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
		
	if partida_terminada or duelo_resuelto:
		return
		
	duelo_resuelto = true
	partida_terminada = true
	
	var id_ganador: int = -1
	var id_perdedor: int = -1
	var fue_disparo_falso: bool = false
	
	if not senal_disparo_dada:
		# ¡DISPARO EN FALSO ANTES DE TIEMPO!
		# El tirador impaciente queda descalificado y pierde de inmediato
		fue_disparo_falso = true
		id_perdedor = id_tirador
		id_ganador = id_duelista_1 if id_tirador == id_duelista_0 else id_duelista_0
	else:
		# ¡DISPARO VÁLIDO Y MÁS RÁPIDO!
		fue_disparo_falso = false
		id_ganador = id_tirador
		id_perdedor = id_duelista_1 if id_tirador == id_duelista_0 else id_duelista_0
		
	id_ganador_duelo = id_ganador
	
	# El servidor difunde la resolución idéntica a todos los clientes
	if multiplayer.has_multiplayer_peer():
		ejecutar_resolucion_duelo_rpc.rpc(id_ganador, id_perdedor, fue_disparo_falso)
	else:
		ejecutar_resolucion_duelo_rpc(id_ganador, id_perdedor, fue_disparo_falso)

@rpc("authority", "call_local", "reliable")
func ejecutar_resolucion_duelo_rpc(id_ganador: int, id_perdedor: int, fue_disparo_falso: bool):
	partida_terminada = true
	duelo_resuelto = true
	id_ganador_duelo = id_ganador
	bloquear_jugadores(true)
	
	# Destello del disparo en pantalla
	if efecto_destello:
		efecto_destello.color = Color(1.0, 0.9, 0.4, 0.9)
		var tw_f = create_tween()
		tw_f.tween_property(efecto_destello, "color:a", 0.0, 0.09)
	agitar_camara(7.0)
	
	# Resplandor que ilumina brevemente al jugador que disparó primero en la oscuridad
	var id_tirador = id_perdedor if fue_disparo_falso else id_ganador
	var av_tirador = avatares_jugadores.get(id_tirador)
	if not av_tirador and get_tree().root:
		av_tirador = get_tree().root.find_child(str(id_tirador), true, false)
		
	if av_tirador and is_instance_valid(av_tirador):
		av_tirador.z_index = 15
		
		# Aura radial cálida que brota del tirador iluminando el polvo y el entorno
		var resplandor = Sprite2D.new()
		resplandor.texture = preload("res://assets/minijuegos/duelo/luz_fogata_radial.png")
		resplandor.global_position = av_tirador.global_position + Vector2(0, -12)
		resplandor.scale = Vector2(0.4, 0.3)
		resplandor.modulate = Color(1.0, 0.96, 0.65, 0.95)
		resplandor.z_index = 13
		add_child(resplandor)
		
		var tw_luz_disparo = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_luz_disparo.tween_property(resplandor, "scale", Vector2(2.0, 1.5), 0.6)
		tw_luz_disparo.tween_property(resplandor, "modulate:a", 0.0, 0.6)
		
		# Destello que revela vivamente los colores del tirador en la penumbra
		av_tirador.modulate = Color(2.6, 2.3, 1.5, 1.0)
		var tw_tirador = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_tirador.tween_property(av_tirador, "modulate", Color(1.15, 1.08, 0.92, 1.0), 0.22)
		tw_tirador.tween_property(av_tirador, "modulate", Color(0.88, 0.88, 0.95, 1.0), 0.48)
		
		tw_luz_disparo.chain().tween_callback(resplandor.queue_free)
	
	# Congelamiento dramático de impacto en la oscuridad: ambos personajes se quedan inmóviles
	await get_tree().create_timer(0.75).timeout
	
	# Caída desplomada del perdedor
	var av_loser = avatares_jugadores.get(id_perdedor)
	if not av_loser and get_tree().root:
		av_loser = get_tree().root.find_child(str(id_perdedor), true, false)
		
	if av_loser and is_instance_valid(av_loser):
		var prefijo_l = av_loser.get("prefijo_personaje") if "prefijo_personaje" in av_loser else "SEIK"
		if prefijo_l == null or str(prefijo_l) == "": prefijo_l = "SEIK"
		if av_loser.sprite:
			var anim_at = prefijo_l + "_aturdido"
			if av_loser.sprite.sprite_frames and av_loser.sprite.sprite_frames.has_animation(anim_at):
				av_loser.sprite.play(anim_at)
				av_loser.sprite.stop() # Frame estático de desmayo
				
		var tw_caida = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var rot_caida = 90.0 if av_loser.global_position.x < 576.0 else -90.0
		tw_caida.tween_property(av_loser, "rotation_degrees", rot_caida, 0.22)
		tw_caida.tween_property(av_loser, "position:y", av_loser.position.y + 24.0, 0.22)
		
	# Asegurar que el ganador permanezca completamente erguido (rotación 0.0 exacta)
	var av_winner = avatares_jugadores.get(id_ganador)
	if not av_winner and get_tree().root:
		av_winner = get_tree().root.find_child(str(id_ganador), true, false)
	if av_winner and is_instance_valid(av_winner):
		av_winner.rotation = 0.0
		av_winner.rotation_degrees = 0.0
		av_winner.scale = Vector2.ONE
		
	# Espera breve antes de iniciar la reunión de la fogata
	await get_tree().create_timer(0.8).timeout
	_iniciar_reunion_fogata(id_ganador)

# ==============================================================================
# CELEBRACIÓN: REUNIÓN DE ESPECTADORES Y ENCENDIDO DE FOGATA EN LA NOCHE
# ==============================================================================

func _iniciar_reunion_fogata(id_ganador: int):
	# Retirar el Letterbox y regresar suavemente la cámara al centro
	_ajustar_letterbox("oculto", 1.4)
	var tw_cam_vic = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_cam_vic.tween_property(camera, "position", Vector2(576, 335), 1.4)
	tw_cam_vic.tween_property(camera, "zoom", Vector2(1.0, 1.0), 1.4)
	
	var av_winner = avatares_jugadores.get(id_ganador)
	if not av_winner and get_tree().root:
		av_winner = get_tree().root.find_child(str(id_ganador), true, false)
		
	var pos_fogata = Vector2(576, 485)
	var pos_ganador_fogata = Vector2(576, 435)
	
	# Asegurar que el avatar del ganador esté erguido y con rotación en cero absoluto
	if av_winner and is_instance_valid(av_winner):
		av_winner.rotation = 0.0
		av_winner.rotation_degrees = 0.0
		av_winner.scale = Vector2.ONE
		if "sprite" in av_winner and av_winner.sprite:
			av_winner.sprite.rotation = 0.0
			av_winner.sprite.rotation_degrees = 0.0
			
	var tw_caminar = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if av_winner and is_instance_valid(av_winner):
		var dir_x = pos_ganador_fogata.x - av_winner.global_position.x
		_mirar_hacia(av_winner, dir_x > 0)
		_reproducir_animacion_avatar(av_winner, "caminar")
		tw_caminar.tween_property(av_winner, "global_position", pos_ganador_fogata, 1.2)
		
	# Los espectadores también caminan al centro desde los laterales
	var pos_espectadores_fogata = [Vector2(495, 465), Vector2(655, 465)]
	var idx_e = 0
	for id_esp in lista_espectadores:
		var av_esp = avatares_jugadores.get(id_esp)
		if not av_esp and get_tree().root:
			av_esp = get_tree().root.find_child(str(id_esp), true, false)
		if av_esp and is_instance_valid(av_esp):
			av_esp.rotation = 0.0
			av_esp.rotation_degrees = 0.0
			var target_pos = pos_espectadores_fogata[idx_e % pos_espectadores_fogata.size()]
			var dir_esp = target_pos.x - av_esp.global_position.x
			_mirar_hacia(av_esp, dir_esp > 0)
			_reproducir_animacion_avatar(av_esp, "caminar")
			tw_caminar.tween_property(av_esp, "global_position", target_pos, 1.3)
			idx_e += 1
			
	await tw_caminar.finished
	
	# Encender la fogata: chispa, llamarada y luz ambiental
	if fogata_centro:
		fogata_centro.visible = true
		fogata_centro.scale = Vector2(0.2, 0.2)
		var tw_fogo = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_fogo.tween_property(fogata_centro, "scale", Vector2.ONE, 0.35)
		
	if chispas_fogata:
		chispas_fogata.restart()
		
	# Resplandor de la fogata iluminando la escena
	var tw_luz = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if luz_fogata:
		tw_luz.tween_property(luz_fogata, "modulate:a", 0.95, 0.6)
		
	# Restaurar colores normales a los personajes reunidos iluminados por el fuego
	if av_winner and is_instance_valid(av_winner):
		av_winner.z_index = 15
		av_winner.rotation = 0.0
		av_winner.rotation_degrees = 0.0
		tw_luz.tween_property(av_winner, "modulate", Color(1.0, 0.94, 0.85), 0.5)
		_reproducir_animacion_avatar(av_winner, "acierto")
			
	for id_esp in lista_espectadores:
		var av_esp = avatares_jugadores.get(id_esp)
		if av_esp and is_instance_valid(av_esp):
			av_esp.z_index = 15
			tw_luz.tween_property(av_esp, "modulate", Color(0.92, 0.86, 0.78), 0.5)
			_mirar_hacia(av_esp, av_esp.global_position.x < pos_fogata.x)
			_reproducir_animacion_avatar(av_esp, "idle")
				
	# Proclamación de victoria
	ejecutar_secuencia_victoria([id_ganador], pos_ganador_fogata)
	if av_winner and is_instance_valid(av_winner):
		av_winner.z_index = 15
		av_winner.rotation = 0.0
		av_winner.rotation_degrees = 0.0

func agitar_camara(intensidad: float):
	if not camera: return
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	for i in range(3):
		tw.tween_property(camera, "offset", Vector2(randf_range(-intensidad, intensidad), randf_range(-intensidad, intensidad)), 0.04)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.04)
