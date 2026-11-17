extends Node2D
class_name BaseMinijuego

enum Modo {FFA, EQUIPOS_2V2, JEFE_1V3}
@export var modo_actual: Modo = Modo.FFA

# Variables de estado del juego
var jugadores_vivos = [] # IDs de los jugadores en la partida
var jugadores_info = {}  # Diccionario: { id: {"equipo": int, "spawn": int, "es_jefe": bool} }
var nombres_cacheados = {}
var avatares_cacheados = {}

func preparar_partida(lista_ids: Array):
	# Limpiamos datos previos
	jugadores_vivos = lista_ids.duplicate()
	jugadores_info.clear()
	nombres_cacheados.clear()
	avatares_cacheados.clear()
	
	# Mezclamos para que el orden sea justo/aleatorio
	var ids_mezclados = lista_ids.duplicate()
	ids_mezclados.shuffle()
	
	match modo_actual:
		Modo.FFA:
			for i in range(ids_mezclados.size()):
				jugadores_info[ids_mezclados[i]] = {"equipo": i, "spawn": i, "es_jefe": false}
		
		Modo.EQUIPOS_2V2:
			var total = ids_mezclados.size()
			if total == 2:
				# 1 vs 1: un jugador por equipo en spawns enfrentados
				jugadores_info[ids_mezclados[0]] = {"equipo": 0, "spawn": 0, "es_jefe": false}
				jugadores_info[ids_mezclados[1]] = {"equipo": 1, "spawn": 2, "es_jefe": false}
			elif total == 3:
				# 1 vs 2: un jugador solo en equipo 0, y dos en equipo 1
				jugadores_info[ids_mezclados[0]] = {"equipo": 0, "spawn": 0, "es_jefe": false}
				jugadores_info[ids_mezclados[1]] = {"equipo": 1, "spawn": 2, "es_jefe": false}
				jugadores_info[ids_mezclados[2]] = {"equipo": 1, "spawn": 3, "es_jefe": false}
			else:
				# 4 o más: 2 vs 2 estándar
				for i in range(total):
					var equipo = 0 if i < 2 else 1
					jugadores_info[ids_mezclados[i]] = {"equipo": equipo, "spawn": i, "es_jefe": false}
				
		Modo.JEFE_1V3:
			for i in range(ids_mezclados.size()):
				if i == 0:
					# El primero es el jefe: asignado al spawn 3 (zona de control / fuera de pista)
					jugadores_info[ids_mezclados[i]] = {"equipo": 0, "spawn": 3, "es_jefe": true}
				else:
					# Los demás son supervivientes: spawns 0, 1, 2 (en la plataforma)
					jugadores_info[ids_mezclados[i]] = {"equipo": 1, "spawn": i - 1, "es_jefe": false}
	
	# Una vez calculados los roles, mandamos a spawnear
	solicitar_spawns_a_todos.rpc(jugadores_info)

func _ready():
	# Si somos un cliente conectado y entramos a un minijuego, solicitamos la info al Host
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		solicitar_info_minijuego_al_servidor.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func solicitar_info_minijuego_al_servidor():
	if multiplayer.is_server():
		var remitente = multiplayer.get_remote_sender_id()
		if remitente == 0: remitente = multiplayer.get_unique_id()
		if jugadores_info.size() > 0:
			solicitar_spawns_a_todos.rpc_id(remitente, jugadores_info)

@rpc("authority", "call_local", "reliable")
func solicitar_spawns_a_todos(dict_info):
	if jugadores_info.size() > 0 and dict_info == jugadores_info and instrucciones_mostradas:
		return
	jugadores_info = dict_info
	# Asegurar que la lista de vivos esté sincronizada en todos los clientes
	jugadores_vivos = dict_info.keys().duplicate()
	nombres_cacheados.clear()
	avatares_cacheados.clear()
	# Le pedimos al Lobby (o al script que maneja los avatares) que cree los cuerpos
	if get_tree().root.has_node("Lobby"):
		get_tree().root.get_node("Lobby").ejecutar_spawns_en_mapa(jugadores_info)
	
	# Llamamos al molde local que cada minijuego hijo puede implementar
	aplicar_roles_locales()

# --- FUNCIÓN MOLDE / PLANTILLA ---
func aplicar_roles_locales():
	pass

# --- SISTEMA DE INSTRUCCIONES Y CUENTA ATRÁS GLOBAL ---

var escena_instrucciones = preload("res://escenas/pantalla_instrucciones.tscn")
var instrucciones_mostradas: bool = false

func iniciar_secuencia_cuenta_atras():
	bloquear_jugadores(true)
	if not instrucciones_mostradas:
		instrucciones_mostradas = true
		mostrar_pantalla_instrucciones()
	else:
		ejecutar_overlay_cuenta_atras()

func mostrar_pantalla_instrucciones():
	bloquear_jugadores(true)
	var inst = escena_instrucciones.instantiate()
	add_child(inst)
	
	var clave = detectar_clave_minijuego()
	var mi_id = 1
	if multiplayer.has_multiplayer_peer():
		mi_id = multiplayer.get_unique_id()
		
	inst.configurar_pantalla(clave, jugadores_info, mi_id)
	inst.instrucciones_completadas.connect(_on_instrucciones_completadas)

signal inicio_cuenta_atras

func _on_instrucciones_completadas():
	inicio_cuenta_atras.emit()
	al_completar_instrucciones()
	ejecutar_overlay_cuenta_atras()

func al_completar_instrucciones():
	pass

func ejecutar_overlay_cuenta_atras():
	bloquear_jugadores(true)
	var overlay = preload("res://escenas/overlay_cuenta_atras.tscn").instantiate()
	add_child(overlay)
	overlay.cuenta_atras_terminada.connect(_on_cuenta_atras_finalizada)

func detectar_clave_minijuego() -> String:
	if "nombre_minijuego" in self and str(self.get("nombre_minijuego")) != "":
		return str(self.get("nombre_minijuego"))
		
	var ruta = scene_file_path.to_lower()
	if "garra" in ruta: return "garra"
	if "plataforma" in ruta: return "plataformas"
	if "cinta" in ruta or "test_1" in ruta: return "plataformas"
	if "explosion" in ruta or "ruleta" in ruta: return "explosion"
	if "canon" in ruta: return "canones"
	if "pista" in ruta: return "pista"
	if "templo" in ruta: return "templo"
	if "globo" in ruta: return "globos"
	if "janken" in ruta: return "janken"
	if "trivia" in ruta: return "trivia"
	if "atrapa" in ruta or "cola" in ruta: return "atrapa_colas"
	if "snowboard" in ruta or "carrito" in ruta: return "snowboard"
	
	return name.to_lower()

func _on_cuenta_atras_finalizada():
	bloquear_jugadores(false)
	iniciar_juego_post_cuenta_atras()

func bloquear_jugadores(bloquear: bool):
	for hijo in get_children():
		if hijo.has_method("bloquear_controles"):
			hijo.bloquear_controles(bloquear)
			if hijo.has_method("reproducir_idle"):
				hijo.reproducir_idle()

func iniciar_juego_post_cuenta_atras():
	pass

# --- SISTEMA DE PANTALLA DE VICTORIA ESTILO MARIO PARTY ---

var escena_pantalla_victoria = preload("res://escenas/pantalla_victoria.tscn")

func obtener_avatar_jugador(id: Variant) -> Node:
	var id_int = int(id)
	if avatares_cacheados.has(id_int) and is_instance_valid(avatares_cacheados[id_int]):
		return avatares_cacheados[id_int]
	var id_str = str(id)
	var av = get_node_or_null(id_str)
	if not av:
		av = find_child(id_str, true, false)
	if not av and get_tree().root:
		av = get_tree().root.find_child(id_str, true, false)
	if av:
		avatares_cacheados[id_int] = av
	return av

func obtener_nombre_jugador(id: Variant) -> String:
	var id_int = int(id)
	if nombres_cacheados.has(id_int):
		return nombres_cacheados[id_int]
		
	var id_str = str(id)
	var avatar = obtener_avatar_jugador(id)
	if avatar and "label_nick" in avatar and avatar.label_nick and avatar.label_nick.text != "":
		nombres_cacheados[id_int] = avatar.label_nick.text
		return avatar.label_nick.text
	if get_tree().root.has_node("Lobby"):
		var lobby = get_tree().root.get_node("Lobby")
		if "jugadores_conectados" in lobby:
			if id_int in lobby.jugadores_conectados:
				var n = str(lobby.jugadores_conectados[id_int])
				nombres_cacheados[id_int] = n
				return n
			elif id_str in lobby.jugadores_conectados:
				var n = str(lobby.jugadores_conectados[id_str])
				nombres_cacheados[id_int] = n
				return n
	var n_def = "Jugador " + id_str
	return n_def

func formatear_nombres_ganadores(ids: Array) -> Dictionary:
	var nombres = []
	for id in ids:
		nombres.append(obtener_nombre_jugador(id))
		
	var texto_nombres = ""
	var texto_wins = "Wins!"
	
	if nombres.size() == 1:
		texto_nombres = nombres[0]
		texto_wins = "Wins!"
	elif nombres.size() == 2:
		texto_nombres = nombres[0] + " & " + nombres[1]
		texto_wins = "Win!"
	elif nombres.size() >= 3:
		texto_wins = "Win!"
		var primeros = nombres.slice(0, nombres.size() - 1)
		texto_nombres = ", ".join(primeros) + " & " + nombres[nombres.size() - 1]
	else:
		texto_nombres = "Nadie"
		texto_wins = "..."
		
	return {
		"nombres": texto_nombres,
		"wins": texto_wins
	}

func ejecutar_secuencia_victoria(ids_ganadores: Array, centro_celebracion: Vector2 = Vector2(576.0, 520.0)):
	# 1. Bloquear a todos los personajes
	bloquear_jugadores(true)
	
	# 2. Ocultar HUD del minijuego si existe
	var hud = get_node_or_null("HUD")
	if hud:
		var panel_turno = hud.get_node_or_null("PanelTurno")
		if panel_turno: panel_turno.visible = false
		var panel_tiempo = hud.get_node_or_null("PanelTiempo")
		if panel_tiempo: panel_tiempo.visible = false
		var panel_supervivientes = hud.get_node_or_null("LabelSupervivientes")
		if panel_supervivientes: panel_supervivientes.visible = false
		var panel_vic = hud.get_node_or_null("PanelVictoria")
		if panel_vic: panel_vic.visible = false
	
	# 3. Ubicar y preparar a los ganadores
	var avatares_ganadores = []
	for id in ids_ganadores:
		var av = obtener_avatar_jugador(id)
		if av:
			# Si el avatar fue reparentado (e.g. dentro de un cañón o espectador), devolverlo al minijuego
			if av.get_parent() != self:
				var gpos = av.global_position
				av.get_parent().remove_child(av)
				add_child(av)
				av.global_position = gpos
			
			av.visible = true
			av.modulate = Color.WHITE
			av.scale = Vector2.ONE
			av.set_physics_process(true)
			av.z_index = 10 # Al frente de plataformas y fondos
			
			# Si estaba fuera de pantalla por eliminación, traerlo al centro antes de la animación
			if av.global_position.x < -500.0 or av.global_position.y < -500.0 or av.global_position.x > 3000.0 or av.global_position.y > 3000.0:
				av.global_position = centro_celebracion
				
			if "label_nick" in av and av.label_nick:
				av.label_nick.visible = false
			if "sprite" in av and "prefijo_personaje" in av and av.prefijo_personaje != "":
				av.sprite.play(av.prefijo_personaje + "_acierto")
				av.sprite.flip_h = false
			avatares_ganadores.append(av)
	
	# Posicionar a los ganadores según la cantidad (1, dúo o trío)
	var cant = avatares_ganadores.size()
	if cant == 1:
		var tween_pos = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween_pos.tween_property(avatares_ganadores[0], "global_position", centro_celebracion, 0.4)
	elif cant == 2:
		var separacion = 55.0
		var tween1 = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween1.tween_property(avatares_ganadores[0], "global_position", centro_celebracion + Vector2(-separacion, 0), 0.4)
		var tween2 = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween2.tween_property(avatares_ganadores[1], "global_position", centro_celebracion + Vector2(separacion, 0), 0.4)
	elif cant >= 3:
		var separacion = 80.0
		for i in range(cant):
			var offset_x = (i - ((cant - 1.0) / 2.0)) * separacion
			var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(avatares_ganadores[i], "global_position", centro_celebracion + Vector2(offset_x, 0), 0.4)
			
	# 4. Breve pausa antes del zoom cinematográfico
	await get_tree().create_timer(0.4).timeout
	
	# 5. Zoom de cámara hacia el ganador / ganadores
	var cam = get_node_or_null("Camera2D")
	if not cam:
		cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.position = Vector2(576, 324)
		cam.enabled = true
		add_child(cam)
		cam.make_current()
		
	var target_cam_pos = Vector2(centro_celebracion.x, centro_celebracion.y - 85.0)
	var target_zoom = Vector2(1.5, 1.5)
	if cant == 2:
		target_zoom = Vector2(1.45, 1.45)
	elif cant >= 3:
		target_zoom = Vector2(1.35, 1.35)
		
	# Clampear la cámara respetando límites de escenarios grandes (ej. laberinto o snowboard)
	var viewport_w = 1152.0
	var viewport_h = 648.0
	var half_w = (viewport_w * 0.5) / target_zoom.x
	var half_h = (viewport_h * 0.5) / target_zoom.y
	
	var max_w = float(cam.limit_right) if cam.limit_right > int(viewport_w) else viewport_w
	var max_h = float(cam.limit_bottom) if cam.limit_bottom > int(viewport_h) else viewport_h
	var min_w = float(cam.limit_left)
	var min_h = float(cam.limit_top)
	
	target_cam_pos.x = clamp(target_cam_pos.x, min_w + half_w, max_w - half_w)
	target_cam_pos.y = clamp(target_cam_pos.y, min_h + half_h, max_h - half_h)
	
	cam.limit_left = int(min_w)
	cam.limit_top = int(min_h)
	cam.limit_right = int(max_w)
	cam.limit_bottom = int(max_h)
		
	var tween_cam = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween_cam.tween_property(cam, "global_position", target_cam_pos, 0.9)
	tween_cam.tween_property(cam, "zoom", target_zoom, 0.9)
	
	await tween_cam.finished
	
	# 6. Mostrar el cartel de victoria estilo Mario Party
	var overlay_victoria = escena_pantalla_victoria.instantiate()
	add_child(overlay_victoria)
	
	var info = formatear_nombres_ganadores(ids_ganadores)
	overlay_victoria.animar_aparicion(info["nombres"], info["wins"])
	
	# 7. Tiempo de celebración antes de retornar al lobby
	await get_tree().create_timer(4.5).timeout
	
	var es_autoridad = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if es_autoridad:
		if get_tree().root.has_node("Lobby"):
			var lobby = get_tree().root.get_node("Lobby")
			if multiplayer.has_multiplayer_peer():
				lobby.regresar_al_lobby_rpc.rpc()
			else:
				lobby.regresar_al_lobby_rpc()
