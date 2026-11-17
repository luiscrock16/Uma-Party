extends BaseMinijuego

# Texturas de plataformas y símbolos (Estilo Academia Tracen)
var tex_tile_neutral = preload("res://assets/minijuego_plataformas/tile_neutral.png")
var tex_tile_safe = preload("res://assets/minijuego_plataformas/tile_safe.png")
var tex_tile_hazard = preload("res://assets/minijuego_plataformas/tile_hazard.png")

var texturas_simbolos = [
	preload("res://assets/minijuego_plataformas/simbolo_0_zanahoria.png"),
	preload("res://assets/minijuego_plataformas/simbolo_1_herradura.png"),
	preload("res://assets/minijuego_plataformas/simbolo_2_trebol.png"),
	preload("res://assets/minijuego_plataformas/simbolo_3_estrella.png"),
	preload("res://assets/minijuego_plataformas/simbolo_4_corona.png")
]

# Nodos principales visibles (Solo Jumbotron, Plataformas, Podio y Jugadores)
@onready var contenedor_plataformas = $ContenedorPlataformas
@onready var jumbotron_simbolo: Sprite2D = $Jumbotron/SpriteSimbolo
@onready var jumbotron_label: Label = $Jumbotron/LabelEstado
@onready var podio_victoria: Sprite2D = $PodioVictoria

# Dimensiones de la cuadrícula
const COLS = 8
const ROWS = 6
const TOTAL_TILES = 48
const TILE_SIZE = 64.0
const STEP_X = 70.0
const STEP_Y = 70.0
const START_X = 331.0
const START_Y = 230.0

# Estructura interna de plataformas
var plataformas: Array[Dictionary] = []

# Estado de partida
var ronda_actual: int = 0
var juego_iniciado: bool = false
var partida_concluida: bool = false
var simbolo_ganador_actual: int = -1
var en_fase_desplome: bool = false

func _ready():
	modo_actual = Modo.FFA
	Global.establecer_texto_accion_tactil("EMPUJAR")
	crear_cuadricula_plataformas()
	if podio_victoria:
		podio_victoria.visible = false
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		# Solo si se ejecuta como prueba directa local con F6
		call_deferred("preparar_test_local_f6")

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	
	jugadores_info.clear()
	var mi_id = 1
	var ids_test = [mi_id, 2, 3, 4]
	for i in range(ids_test.size()):
		var id = ids_test[i]
		jugadores_info[id] = {"equipo": i, "spawn": i, "es_jefe": false}
		var avatar = preload("res://escenas/personaje_jugable.tscn").instantiate()
		avatar.name = str(id)
		add_child(avatar)
		var sp = get_node_or_null("Spawns/" + str(i))
		if sp: avatar.global_position = sp.global_position
		avatar.configurar_visual(i % 5, "Jugador %d" % id)
		
	aplicar_roles_locales()

func crear_cuadricula_plataformas():
	plataformas.clear()
	for child in contenedor_plataformas.get_children():
		child.queue_free()
		
	var idx = 0
	for r in range(ROWS):
		for c in range(COLS):
			var pos = Vector2(START_X + c * STEP_X, START_Y + r * STEP_Y)
			
			# Usamos Node2D SIN colisiones físicas en baldosas (las colisiones están en BordesMapa)
			var nodo_tile = Node2D.new()
			nodo_tile.name = "Tile_%d" % idx
			nodo_tile.position = pos
			
			var spr_base = Sprite2D.new()
			spr_base.name = "Base"
			spr_base.texture = tex_tile_neutral
			spr_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			nodo_tile.add_child(spr_base)
			
			var spr_sym = Sprite2D.new()
			spr_sym.name = "Simbolo"
			spr_sym.scale = Vector2(0.55, 0.55)
			spr_sym.position = Vector2(0, -2)
			spr_sym.texture = texturas_simbolos[0]
			nodo_tile.add_child(spr_sym)
			
			contenedor_plataformas.add_child(nodo_tile)
			
			var data = {
				"idx": idx,
				"nodo": nodo_tile,
				"spr_base": spr_base,
				"spr_sym": spr_sym,
				"pos_base": pos,
				"simbolo": 0,
				"activa": true,
				"destruida_permanente": false,
				"caida": false
			}
			plataformas.append(data)
			idx += 1

func aplicar_roles_locales():
	for id in jugadores_info.keys():
		var avatar = get_node_or_null(str(id))
		if avatar:
			avatar.set_movimiento_actual = PersonajeJugable.TipoMovimiento.CAMINAR_Y_EMPUJAR
			avatar.bloquear_controles(true)
			if avatar.has_method("reproducir_idle"):
				avatar.reproducir_idle()
				
	iniciar_secuencia_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	juego_iniciado = true
	partida_concluida = false
	
	# Desbloqueo garantizado de todas las corredoras
	for id in jugadores_info.keys():
		var avatar = get_node_or_null(str(id))
		if avatar:
			avatar.bloquear_controles(false)
			avatar.set_movimiento_actual = PersonajeJugable.TipoMovimiento.CAMINAR_Y_EMPUJAR
	bloquear_jugadores(false)
	
	if multiplayer.is_server():
		ronda_actual = 0
		iniciar_secuencia_inicio_partida_servidor()

# -------------------------------------------------------------------------
# BUCLE DE RONDAS Y TIEMPOS (SERVIDOR)
# -------------------------------------------------------------------------
func iniciar_secuencia_inicio_partida_servidor():
	# Margen de 3 segundos al inicio de la partida para acomodarse y caminar
	rpc("mostrar_mensaje_jumbotron_rpc", "¡RONDA 1!\n¡PREPARADAS!", Color(1.0, 0.9, 0.2))
	await get_tree().create_timer(3.0).timeout
	if partida_concluida: return
	
	iniciar_siguiente_ronda_servidor()

func iniciar_siguiente_ronda_servidor():
	if partida_concluida: return
	ronda_actual += 1
	
	# Verificar cuántas baldosas siguen vivas en el estadio
	var baldosas_disponibles = []
	for p in plataformas:
		if not p["destruida_permanente"]:
			baldosas_disponibles.append(p["idx"])
			
	if baldosas_disponibles.size() < 3:
		evaluar_ganador_final()
		return
		
	# Elegir símbolo ganador para esta ronda
	simbolo_ganador_actual = randi() % texturas_simbolos.size()
	
	# Proporción de baldosas seguras (disminuye gradualmente)
	var pct_seguras = max(0.40 - (ronda_actual - 1) * 0.10, 0.08)
	var cant_seguras = max(int(baldosas_disponibles.size() * pct_seguras), 2)
	
	baldosas_disponibles.shuffle()
	var mapa_simbolos = {}
	
	for i in range(baldosas_disponibles.size()):
		var idx_tile = baldosas_disponibles[i]
		if i < cant_seguras:
			mapa_simbolos[idx_tile] = simbolo_ganador_actual
		else:
			var otros_simbolos = []
			for s in range(texturas_simbolos.size()):
				if s != simbolo_ganador_actual: otros_simbolos.append(s)
			mapa_simbolos[idx_tile] = otros_simbolos[randi() % otros_simbolos.size()]
			
	# Iniciar fase de parpadeo pausado y sincronizado
	rpc("sincronizar_inicio_ronda_rpc", ronda_actual, mapa_simbolos, simbolo_ganador_actual)
	
	# Ejecutar secuencia temporal de la ronda
	ejecutar_secuencia_ronda_servidor()

func ejecutar_secuencia_ronda_servidor():
	# 1. Barajado pausado y rítmico: 7 pulsos de 0.42s cada uno (~3.0s)
	await get_tree().create_timer(3.2).timeout
	if partida_concluida: return
	
	# 2. Revelar símbolo objetivo en pantalla
	rpc("revelar_simbolo_pantalla_rpc", simbolo_ganador_actual)
	
	# 3. Margen para correr hacia la baldosa segura (2.6s) SIN cuenta atrás numérica
	await get_tree().create_timer(2.6).timeout
	if partida_concluida: return
	
	# 4. Alerta visual de peligro (0.6s) con temblor y cambio de color en baldosas erróneas
	rpc("iniciar_alerta_peligro_rpc")
	await get_tree().create_timer(0.6).timeout
	if partida_concluida: return
	
	# 5. Desplome al vacío de las plataformas incorrectas
	rpc("ejecutar_desplome_rpc")
	
	# 6. Eliminar INMEDIATAMENTE a quienes no estén en plataforma segura
	chequear_eliminaciones_caida_servidor()
	
	# Pausa de 2.5s para asimilar la caída cómica
	await get_tree().create_timer(2.5).timeout
	if partida_concluida: return
	
	# 7. Evaluar si queda una ganadora única o si todas cayeron
	var vivos = contar_jugadores_vivos()
	if vivos <= 1:
		evaluar_ganador_final()
		return
		
	# 8. Subida de plataformas caídas (con pérdida progresiva anti-infinito: 90%, 80%, 70%...)
	var pct_retorno = max(0.90 - (ronda_actual - 1) * 0.10, 0.40)
	var tiles_que_suben = []
	var tiles_caidas_ronda = []
	
	for p in plataformas:
		if p["caida"] and not p["destruida_permanente"]:
			tiles_caidas_ronda.append(p["idx"])
			
	tiles_caidas_ronda.shuffle()
	var cant_a_subir = int(round(tiles_caidas_ronda.size() * pct_retorno))
	for i in range(tiles_caidas_ronda.size()):
		var idx_t = tiles_caidas_ronda[i]
		if i < cant_a_subir:
			tiles_que_suben.append(idx_t)
		else:
			plataformas[idx_t]["destruida_permanente"] = true
			
	rpc("subir_plataformas_rpc", tiles_que_suben)
	
	# Pausa antes de la siguiente ronda
	rpc("mostrar_mensaje_jumbotron_rpc", "¡RONDA %d!\n¡PREPARADAS!" % (ronda_actual + 1), Color(1.0, 0.9, 0.2))
	await get_tree().create_timer(3.0).timeout
	if partida_concluida: return
	
	# Iniciar siguiente ronda
	iniciar_siguiente_ronda_servidor()

# -------------------------------------------------------------------------
# COMPROBACIÓN FÍSICA DE CAÍDAS (SERVIDOR)
# -------------------------------------------------------------------------
func chequear_eliminaciones_caida_servidor():
	for id in jugadores_info.keys():
		var avatar = get_node_or_null(str(id))
		if not avatar: continue
		if "estado_actual" in avatar and avatar.estado_actual == avatar.Estado.ELIMINADO:
			continue
			
		var pos = avatar.global_position
		var sobre_segura = false
		
		for p in plataformas:
			# Solo es segura si está activa, NO caída, NO destruida permanente Y su símbolo es el ganador
			if p["activa"] and not p["caida"] and not p["destruida_permanente"] and p["simbolo"] == simbolo_ganador_actual:
				if abs(pos.x - p["pos_base"].x) <= 38.0 and abs(pos.y - p["pos_base"].y) <= 38.0:
					sobre_segura = true
					break
					
		if not sobre_segura:
			rpc("eliminar_jugador_por_vacio_rpc", id)

func _process(_delta):
	# Si una jugadora camina o es empujada a un hueco donde no hay plataforma
	if multiplayer.is_server() and juego_iniciado and not partida_concluida:
		if en_fase_desplome:
			return
			
		for id in jugadores_info.keys():
			var avatar = get_node_or_null(str(id))
			if not avatar: continue
			if "estado_actual" in avatar and avatar.estado_actual == avatar.Estado.ELIMINADO:
				continue
				
			var pos = avatar.global_position
			var sobre_piso = false
			for p in plataformas:
				if p["activa"] and not p["caida"] and not p["destruida_permanente"]:
					if abs(pos.x - p["pos_base"].x) <= 38.0 and abs(pos.y - p["pos_base"].y) <= 38.0:
						sobre_piso = true
						break
						
			if not sobre_piso:
				rpc("eliminar_jugador_por_vacio_rpc", id)

# -------------------------------------------------------------------------
# RPCS DE SINCRONIZACIÓN VISUAL (PANTALLA JUMBOTRON Y PLATAFORMAS)
# -------------------------------------------------------------------------
@rpc("authority", "call_local", "reliable")
func mostrar_mensaje_jumbotron_rpc(texto: String, color: Color):
	if jumbotron_label:
		jumbotron_label.text = texto
		jumbotron_label.modulate = color

@rpc("authority", "call_local", "reliable")
func sincronizar_inicio_ronda_rpc(num_ronda: int, mapa_simbolos: Dictionary, simbolo_objetivo: int):
	ronda_actual = num_ronda
	simbolo_ganador_actual = simbolo_objetivo
	en_fase_desplome = false
	
	if jumbotron_label:
		jumbotron_label.text = "¡BARAJANDO...!"
		jumbotron_label.modulate = Color(1.0, 0.9, 0.2)
		
	animar_barajado_pausado(mapa_simbolos)

func animar_barajado_pausado(mapa_simbolos: Dictionary):
	var tw = create_tween()
	var pasos = 7
	for i in range(pasos):
		tw.tween_callback(func():
			var sym_rand = randi() % texturas_simbolos.size()
			if jumbotron_simbolo:
				jumbotron_simbolo.texture = texturas_simbolos[sym_rand]
				var tw_j = create_tween()
				tw_j.tween_property(jumbotron_simbolo, "scale", Vector2(0.95, 0.95), 0.1)
				tw_j.tween_property(jumbotron_simbolo, "scale", Vector2(0.85, 0.85), 0.2)
				
			for p in plataformas:
				if p["activa"] and not p["caida"] and not p["destruida_permanente"]:
					var s_rand = randi() % texturas_simbolos.size()
					p["spr_sym"].texture = texturas_simbolos[s_rand]
					p["spr_base"].texture = tex_tile_neutral
		).set_delay(0.42)
		
	tw.tween_callback(func():
		for idx in mapa_simbolos.keys():
			var s_final = mapa_simbolos[idx]
			var p = plataformas[idx]
			p["simbolo"] = s_final
			p["spr_sym"].texture = texturas_simbolos[s_final]
			p["spr_base"].texture = tex_tile_neutral
			var tw_pop = create_tween()
			tw_pop.tween_property(p["spr_sym"], "scale", Vector2(0.7, 0.7), 0.1)
			tw_pop.tween_property(p["spr_sym"], "scale", Vector2(0.55, 0.55), 0.15)
	)

@rpc("authority", "call_local", "reliable")
func revelar_simbolo_pantalla_rpc(simbolo_ganador: int):
	simbolo_ganador_actual = simbolo_ganador
	if jumbotron_simbolo:
		jumbotron_simbolo.texture = texturas_simbolos[simbolo_ganador]
		var tw_sym = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_sym.tween_property(jumbotron_simbolo, "scale", Vector2(1.3, 1.3), 0.25)
		tw_sym.tween_property(jumbotron_simbolo, "scale", Vector2(0.9, 0.9), 0.18)
		
	if jumbotron_label:
		jumbotron_label.text = "¡BUSCAD LA FIGURA!"
		jumbotron_label.modulate = Color(0.3, 1.0, 0.5)

@rpc("authority", "call_local", "reliable")
func iniciar_alerta_peligro_rpc():
	if jumbotron_label:
		jumbotron_label.text = "¡PELIGRO!"
		jumbotron_label.modulate = Color(1.0, 0.35, 0.15)
		var tw = create_tween()
		tw.tween_property(jumbotron_label, "scale", Vector2(1.2, 1.2), 0.1)
		tw.tween_property(jumbotron_label, "scale", Vector2(1.0, 1.0), 0.15)
		
	for p in plataformas:
		if p["activa"] and not p["caida"] and not p["destruida_permanente"]:
			if p["simbolo"] != simbolo_ganador_actual:
				p["spr_base"].texture = tex_tile_hazard
				var tw_shake = create_tween()
				tw_shake.tween_property(p["nodo"], "position:x", p["pos_base"].x - 3.0, 0.05)
				tw_shake.tween_property(p["nodo"], "position:x", p["pos_base"].x + 3.0, 0.05)
				tw_shake.tween_property(p["nodo"], "position:x", p["pos_base"].x, 0.05)
			else:
				p["spr_base"].texture = tex_tile_safe

@rpc("authority", "call_local", "reliable")
func ejecutar_desplome_rpc():
	en_fase_desplome = true
	if jumbotron_label:
		jumbotron_label.text = "¡¡DESPLOME!!"
		jumbotron_label.modulate = Color(1.0, 0.15, 0.15)
		
	for p in plataformas:
		if p["activa"] and not p["caida"] and not p["destruida_permanente"]:
			if p["simbolo"] == simbolo_ganador_actual:
				p["spr_base"].texture = tex_tile_safe
				var tw_safe = create_tween()
				tw_safe.tween_property(p["spr_base"], "modulate", Color(1.4, 1.4, 1.4), 0.1)
				tw_safe.tween_property(p["spr_base"], "modulate", Color(1.0, 1.0, 1.0), 0.25)
			else:
				p["caida"] = true
				var tw_caida = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw_caida.tween_property(p["nodo"], "position:y", p["pos_base"].y + 900.0, 0.6)
				tw_caida.tween_property(p["nodo"], "scale", Vector2(0.2, 0.2), 0.6)
				tw_caida.tween_property(p["nodo"], "modulate:a", 0.0, 0.6)

@rpc("authority", "call_local", "reliable")
func subir_plataformas_rpc(indices_que_suben: Array):
	en_fase_desplome = false
	if jumbotron_label:
		jumbotron_label.text = "¡SUBIENDO BALDOSAS!"
		jumbotron_label.modulate = Color(0.3, 0.9, 1.0)
		
	for idx in indices_que_suben:
		var p = plataformas[idx]
		p["caida"] = false
		p["spr_base"].texture = tex_tile_neutral
		p["nodo"].position.y = p["pos_base"].y + 600.0
		p["nodo"].scale = Vector2(0.4, 0.4)
		p["nodo"].modulate.a = 0.0
		
		var tw_subir = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var delay = randf_range(0.05, 0.45)
		tw_subir.tween_property(p["nodo"], "position:y", p["pos_base"].y, 0.6).set_delay(delay)
		tw_subir.tween_property(p["nodo"], "scale", Vector2(1.0, 1.0), 0.6).set_delay(delay)
		tw_subir.tween_property(p["nodo"], "modulate:a", 1.0, 0.4).set_delay(delay)

@rpc("authority", "call_local", "reliable")
func eliminar_jugador_por_vacio_rpc(id_jugador: int):
	var avatar = get_node_or_null(str(id_jugador))
	if not avatar: return
	if "estado_actual" in avatar and avatar.estado_actual == avatar.Estado.ELIMINADO:
		return
		
	avatar.estado_actual = avatar.Estado.ELIMINADO
	avatar.set_physics_process(false)
	avatar.bloquear_controles(true)
	if "collision_shape" in avatar and avatar.collision_shape:
		avatar.collision_shape.set_deferred("disabled", true)
		
	if "sprite" in avatar and avatar.sprite:
		var anim_caida = avatar.prefijo_personaje + "_atrapado"
		if avatar.sprite.sprite_frames.has_animation(anim_caida):
			avatar.sprite.play(anim_caida)
			
	var tw_fall = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_fall.tween_property(avatar, "global_position:y", avatar.global_position.y + 750.0, 0.7)
	tw_fall.tween_property(avatar, "scale", Vector2(0.15, 0.15), 0.7)
	tw_fall.tween_property(avatar, "rotation", 4.0, 0.7)
	tw_fall.tween_property(avatar, "modulate:a", 0.0, 0.7)

func contar_jugadores_vivos() -> int:
	var vivos = 0
	for id in jugadores_info.keys():
		var avatar = get_node_or_null(str(id))
		if avatar and "estado_actual" in avatar and avatar.estado_actual != avatar.Estado.ELIMINADO:
			vivos += 1
	return vivos

# -------------------------------------------------------------------------
# EVALUACIÓN DE GANADOR Y SECUENCIAS FINALES
# -------------------------------------------------------------------------
func evaluar_ganador_final():
	partida_concluida = true
	var ganadores = []
	for id in jugadores_info.keys():
		var avatar = get_node_or_null(str(id))
		if avatar and "estado_actual" in avatar and avatar.estado_actual != avatar.Estado.ELIMINADO:
			ganadores.append(id)
			
	if ganadores.is_empty():
		# Si todas las corredoras cayeron en la misma ronda, ¡nadie gana!
		rpc("ejecutar_secuencia_sin_ganadores_rpc")
	else:
		# Secuencia especial de victoria: desplome total de la pista con el ganador
		# y posterior elevación triunfal en el podio dorado en el centro.
		rpc("ejecutar_secuencia_victoria_podio_rpc", ganadores)

@rpc("authority", "call_local", "reliable")
func ejecutar_secuencia_sin_ganadores_rpc():
	partida_concluida = true
	bloquear_jugadores(true)
	
	if jumbotron_label:
		jumbotron_label.text = "¡NADIE GANA!\n¡TODAS HAN CAÍDO!"
		jumbotron_label.modulate = Color(1.0, 0.25, 0.25)
		
	# Esperar 2.0 segundos y lanzar pantalla de victoria con lista vacía (muestra 'Nadie')
	await get_tree().create_timer(2.0).timeout
	ejecutar_secuencia_victoria([], Vector2(576.0, 405.0))

@rpc("authority", "call_local", "reliable")
func ejecutar_secuencia_victoria_podio_rpc(ids_ganadores: Array):
	partida_concluida = true
	bloquear_jugadores(true)
	
	var pos_centro = Vector2(576.0, 405.0)
	var avatares_ganadores = []
	for id in ids_ganadores:
		var av = get_node_or_null(str(id))
		if av: avatares_ganadores.append(av)
		
	if jumbotron_label:
		jumbotron_label.text = "¡TENEMOS GANADORA!"
		jumbotron_label.modulate = Color(1.0, 0.85, 0.2)
		
	# Paso 1: El ganador se traslada hacia el centro del estadio
	if avatares_ganadores.size() > 0:
		var tw_move = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if avatares_ganadores.size() == 1:
			tw_move.tween_property(avatares_ganadores[0], "global_position", pos_centro, 0.6)
		else:
			for i in range(avatares_ganadores.size()):
				var off_x = (i - (avatares_ganadores.size() - 1.0) / 2.0) * 45.0
				tw_move.parallel().tween_property(avatares_ganadores[i], "global_position", pos_centro + Vector2(off_x, 0), 0.6)
		await tw_move.finished
	else:
		await get_tree().create_timer(0.6).timeout
		
	await get_tree().create_timer(0.4).timeout
	
	# Paso 2: DESPLOME TOTAL: ¡todas las plataformas que quedaban caen junto con el ganador!
	if jumbotron_label:
		jumbotron_label.text = "¡¡DESPLOME TOTAL!!"
		jumbotron_label.modulate = Color(1.0, 0.2, 0.2)
		
	for p in plataformas:
		if p["activa"] and not p["caida"] and not p["destruida_permanente"]:
			p["caida"] = true
			var tw_c = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw_c.tween_property(p["nodo"], "position:y", p["pos_base"].y + 900.0, 0.65)
			tw_c.tween_property(p["nodo"], "scale", Vector2(0.2, 0.2), 0.65)
			tw_c.tween_property(p["nodo"], "modulate:a", 0.0, 0.65)
			
	var tw_caer_ganadores = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for av in avatares_ganadores:
		av.set_physics_process(false)
		av.bloquear_controles(true)
		if "sprite" in av and av.sprite:
			var anim_caida = av.prefijo_personaje + "_atrapado"
			if av.sprite.sprite_frames.has_animation(anim_caida):
				av.sprite.play(anim_caida)
		tw_caer_ganadores.tween_property(av, "global_position:y", pos_centro.y + 700.0, 0.65)
		tw_caer_ganadores.tween_property(av, "scale", Vector2(0.2, 0.2), 0.65)
		tw_caer_ganadores.tween_property(av, "modulate:a", 0.0, 0.65)
		
	await tw_caer_ganadores.finished
	
	# Paso 3: Pausa dramática en el abismo vacío (~0.5s)
	await get_tree().create_timer(0.5).timeout
	
	# Paso 4: ¡APARICIÓN Y ELEVACIÓN DEL PODIO TEMÁTICO EN EL CENTRO!
	if jumbotron_label:
		jumbotron_label.text = "¡VICTORIA TRIUNFAL!"
		jumbotron_label.modulate = Color(0.3, 1.0, 0.6)
		
	if podio_victoria:
		podio_victoria.visible = true
		podio_victoria.position = Vector2(576.0, 850.0) # Aparece desde abajo de la pantalla
		podio_victoria.scale = Vector2(1.3, 1.3)
		podio_victoria.modulate.a = 1.0
		
	for i in range(avatares_ganadores.size()):
		var av = avatares_ganadores[i]
		var off_x = (i - (avatares_ganadores.size() - 1.0) / 2.0) * 45.0
		av.visible = true
		av.global_position = Vector2(576.0 + off_x, 850.0 - 25.0)
		av.scale = Vector2(1.0, 1.0)
		av.rotation = 0.0
		av.modulate.a = 1.0
		av.z_index = 10
		if "sprite" in av and av.sprite:
			var anim_win = av.prefijo_personaje + "_acierto"
			if av.sprite.sprite_frames.has_animation(anim_win):
				av.sprite.play(anim_win)
				
	# Subida triunfal sincronizada del podio y el ganador con rebote (TRANS_BACK)
	var tw_podio = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if podio_victoria:
		tw_podio.tween_property(podio_victoria, "position:y", pos_centro.y + 15.0, 0.95)
	for i in range(avatares_ganadores.size()):
		var av = avatares_ganadores[i]
		tw_podio.tween_property(av, "global_position:y", pos_centro.y - 12.0, 0.95)
		
	await tw_podio.finished
	await get_tree().create_timer(0.5).timeout
	
	# Paso 5: Llamar a la secuencia de victoria global (zoom de cámara y banner de victoria)
	ejecutar_secuencia_victoria(ids_ganadores, Vector2(576.0, pos_centro.y - 12.0))
