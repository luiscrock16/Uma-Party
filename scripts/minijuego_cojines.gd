extends BaseMinijuego

# Constantes de Arena y Dormitorio Tracen
const CENTRO_ARENA: Vector2 = Vector2(576.0, 360.0)
const RADIO_INICIAL: float = 265.0
const DURACION_PARTIDA: float = 50.0

# Etapas de reducción de espacio (sin interfaz, puramente visual)
const ETAPA_REDUCCION_1: float = 38.0 # Reduce a 205.0
const ETAPA_REDUCCION_2: float = 24.0 # Reduce a 150.0
const ETAPA_REDUCCION_3: float = 11.0 # Reduce a 95.0 (Clímax Muerte Súbita)

# Referencias a Nodos de Escena
@onready var fondo_dormitorio: Sprite2D = $FondoDormitorio
@onready var ring_tatami: Node2D = $RingTatami
@onready var base_tatami: Sprite2D = $RingTatami/BaseTatami
@onready var alerta_reduccion: Sprite2D = $RingTatami/AlertaReduccion
@onready var particulas_plumas: CPUParticles2D = $ParticulasPlumas
@onready var camera: Camera2D = $Camera2D

# Recursos de Almohada y Efectos
var tex_almohada: Texture2D = preload("res://assets/minijuegos/cojines/almohada_tracen.png")
var tex_swoosh: Texture2D = preload("res://assets/minijuegos/cojines/swoosh_golpe_cojin.png")

# Estado de Partida
var partida_iniciada: bool = false
var partida_terminada: bool = false
var tiempo_restante: float = DURACION_PARTIDA
var radio_seguro_actual: float = RADIO_INICIAL
var etapa_reduccion_actual: int = 0
var advertencia_activa: bool = false

# Diccionarios de Jugadores y Armas
var avatares_jugadores: Dictionary = {} # {id: CharacterBody2D}
var cojines_en_mano: Dictionary = {}    # {id: Node2D}
var cooldown_golpe: Dictionary = {}     # {id: float}

func _ready():
	modo_actual = Modo.FFA
	Global.establecer_texto_accion_tactil("GOLPE COJÍN")
	partida_iniciada = false
	partida_terminada = false
	tiempo_restante = DURACION_PARTIDA
	radio_seguro_actual = RADIO_INICIAL
	etapa_reduccion_actual = 0
	advertencia_activa = false
	
	if alerta_reduccion:
		alerta_reduccion.modulate.a = 0.0
		
	# Ajuste de escala inicial del tatami central (radio ~265px en sprite 600x600)
	var escala_ini = (RADIO_INICIAL / 275.0)
	if base_tatami:
		base_tatami.scale = Vector2(escala_ini, escala_ini)
	if alerta_reduccion:
		alerta_reduccion.scale = Vector2(escala_ini, escala_ini)
		
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

func aplicar_roles_locales():
	avatares_jugadores.clear()
	jugadores_vivos.clear()
	cojines_en_mano.clear()
	cooldown_golpe.clear()
	
	# Spawns cardinales alrededor del tatami de combate
	var posiciones_spawn = [
		CENTRO_ARENA + Vector2(165.0, 0.0),   # Derecha
		CENTRO_ARENA + Vector2(0.0, 155.0),   # Abajo
		CENTRO_ARENA + Vector2(-165.0, 0.0),  # Izquierda
		CENTRO_ARENA + Vector2(0.0, -155.0)   # Arriba
	]
	
	var i = 0
	for id in jugadores_info.keys():
		jugadores_vivos.append(id)
		cooldown_golpe[id] = 0.0
		
		var av = get_node_or_null(str(id))
		if not av and get_tree().root:
			av = get_tree().root.find_child(str(id), true, false)
			
		if av:
			avatares_jugadores[id] = av
			var pos_sp = posiciones_spawn[i % posiciones_spawn.size()]
			av.global_position = pos_sp
			av.bloquear_controles(true)
			av.modulate = Color.WHITE
			av.scale = Vector2.ONE
			av.visible = true
			
			# Movimiento con inercia estilo patinaje sobre hielo / carritos chocones
			if "set_movimiento_actual" in av:
				av.set_movimiento_actual = PersonajeJugable.TipoMovimiento.PATINAJE_INERCIA
				
			var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if "sprite" in av and av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_idle"):
				av.sprite.play(prefijo + "_idle")
				
			# Orientación inicial mirando al centro
			if av.sprite:
				av.sprite.flip_h = (pos_sp.x < CENTRO_ARENA.x) # Si está a la izq, mira a la der (flip_h=true)
				
			# Equipar la almohada de batalla de Tracen
			crear_cojin_visual(av, id)
			
		i += 1
		
	if not instrucciones_mostradas:
		instrucciones_mostradas = true
		mostrar_pantalla_instrucciones()
	else:
		call_deferred("iniciar_secuencia_cuenta_atras")

func _on_instrucciones_completadas():
	inicio_cuenta_atras.emit()
	al_completar_instrucciones()

func al_completar_instrucciones():
	iniciar_secuencia_cuenta_atras()

func iniciar_secuencia_cuenta_atras():
	ejecutar_overlay_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	partida_iniciada = true
	bloquear_jugadores(false)
	
	for av in avatares_jugadores.values():
		if av and is_instance_valid(av) and "set_movimiento_actual" in av:
			av.set_movimiento_actual = PersonajeJugable.TipoMovimiento.PATINAJE_INERCIA

# ==============================================================================
# CREACIÓN Y ORIENTACIÓN DE LA ALMOHADA VISUAL
# ==============================================================================

func crear_cojin_visual(av: CharacterBody2D, id: int):
	var viejo = av.get_node_or_null("CojinVisual")
	if viejo: viejo.queue_free()
	
	var contenedor_arma = Node2D.new()
	contenedor_arma.name = "CojinVisual"
	
	# Determinar lado inicial según la orientación del sprite
	# flip_h == true -> Mira a la DERECHA (+16px)
	# flip_h == false -> Mira a la IZQUIERDA (-16px)
	var mirando_der = av.sprite.flip_h if (av.sprite and is_instance_valid(av.sprite)) else false
	contenedor_arma.position = Vector2(16.0 if mirando_der else -16.0, 6.0)
	contenedor_arma.scale.x = 1.0 if mirando_der else -1.0
	
	# Sprite de almohada
	var spr_cojin = Sprite2D.new()
	spr_cojin.name = "SpriteCojin"
	spr_cojin.texture = tex_almohada
	spr_cojin.scale = Vector2(0.85, 0.85)
	spr_cojin.offset = Vector2(10.0, -6.0)
	spr_cojin.rotation_degrees = 22.0
	contenedor_arma.add_child(spr_cojin)
	
	# Swoosh semitransparente para el corte tipo espada
	var spr_swoosh = Sprite2D.new()
	spr_swoosh.name = "SpriteSwoosh"
	spr_swoosh.texture = tex_swoosh
	spr_swoosh.scale = Vector2(0.9, 0.9)
	spr_swoosh.position = Vector2(16.0, -8.0)
	spr_swoosh.visible = false
	spr_swoosh.modulate.a = 0.0
	contenedor_arma.add_child(spr_swoosh)
	
	av.add_child(contenedor_arma)
	cojines_en_mano[id] = contenedor_arma

func _actualizar_orientacion_cojines():
	for id in jugadores_vivos:
		var av = avatares_jugadores.get(id)
		var cojin = cojines_en_mano.get(id)
		if av and is_instance_valid(av) and cojin and is_instance_valid(cojin):
			# Sincronización precisa:
			# flip_h == true  => Personaje mirando a la DERECHA -> Cojín al frente (derecha: +16px, scale.x = 1)
			# flip_h == false => Personaje mirando a la IZQUIERDA -> Cojín al frente (izquierda: -16px, scale.x = -1)
			var mirando_der = av.sprite.flip_h if (av.sprite and is_instance_valid(av.sprite)) else false
			var pos_objetivo_x = 16.0 if mirando_der else -16.0
			var escala_x = 1.0 if mirando_der else -1.0
			cojin.position.x = lerp(cojin.position.x, pos_objetivo_x, 0.3)
			cojin.scale.x = escala_x

# ==============================================================================
# BUCLE DE FÍSICAS, CONTROLES Y REDUCCIÓN DE ESPACIO
# ==============================================================================

func _physics_process(delta: float):
	if not partida_iniciada or partida_terminada: return
	
	tiempo_restante -= delta
	
	if tiempo_restante <= 0.0:
		tiempo_restante = 0.0
		declarar_fin_por_tiempo()
		return
		
	# Reducción de cooldowns
	for id in cooldown_golpe.keys():
		cooldown_golpe[id] = max(0.0, cooldown_golpe[id] - delta)
		
	# Entrada de golpe del jugador local
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if mi_id in jugadores_vivos and cooldown_golpe.get(mi_id, 0.0) <= 0.0:
		if _es_boton_ataque_presionado():
			solicitar_golpe_cojin(mi_id)
			
	# Actualizar orientación de la almohada con el giro del personaje
	_actualizar_orientacion_cojines()
	
	# Gestión de reducción de espacio progresiva en servidor/autoridad
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad:
		_gestionar_etapas_reduccion()
		_verificar_caidas_fuera_ring()

func _es_boton_ataque_presionado() -> bool:
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("espacio"):
		return true
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER):
		return true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_action_just_pressed("click"):
		return true
	if InputMap.has_action("accion_habilidad") and Input.is_action_just_pressed("accion_habilidad"):
		return true
	return false

# ==============================================================================
# MECÁNICA DE ATAQUE: BLANDIR LA ALMOHADA COMO UNA ESPADA
# ==============================================================================

func solicitar_golpe_cojin(id_atacante: int):
	cooldown_golpe[id_atacante] = 0.48
	if multiplayer.has_multiplayer_peer():
		ejecutar_golpe_cojin_rpc.rpc(id_atacante)
	else:
		ejecutar_golpe_cojin_rpc(id_atacante)

@rpc("any_peer", "call_local", "reliable")
func ejecutar_golpe_cojin_rpc(id_atacante: int):
	var av_atacante = avatares_jugadores.get(id_atacante)
	if not av_atacante or not is_instance_valid(av_atacante): return
	
	var cojin_node = cojines_en_mano.get(id_atacante)
	var spr_cojin = cojin_node.get_node_or_null("SpriteCojin") if cojin_node else null
	var spr_swoosh = cojin_node.get_node_or_null("SpriteSwoosh") if cojin_node else null
	
	# Dirección del golpe
	var mirando_der = av_atacante.sprite.flip_h if (av_atacante.sprite and is_instance_valid(av_atacante.sprite)) else false
	var dir_ataque = Vector2.RIGHT if mirando_der else Vector2.LEFT
	if "direccion_mirando" in av_atacante and av_atacante.direccion_mirando != Vector2.ZERO:
		dir_ataque = av_atacante.direccion_mirando.normalized()
		
	# Animación de ataque en el personaje
	var prefijo = av_atacante.get("prefijo_personaje") if "prefijo_personaje" in av_atacante else "SEIK"
	if prefijo == null: prefijo = "SEIK"
	if av_atacante.sprite and is_instance_valid(av_atacante.sprite):
		var anim_atk = prefijo + "_ataque"
		if av_atacante.sprite.sprite_frames.has_animation(anim_atk):
			av_atacante.sprite.play(anim_atk)
		else:
			var anim_imp = prefijo + "_impacto"
			if av_atacante.sprite.sprite_frames.has_animation(anim_imp):
				av_atacante.sprite.play(anim_imp)
				
	# Animación de rotación hacia el frente como si blandiera una espada
	if spr_cojin and is_instance_valid(spr_cojin):
		var tw_sword = create_tween().set_parallel(false)
		tw_sword.tween_property(spr_cojin, "rotation_degrees", -50.0, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_sword.tween_property(spr_cojin, "rotation_degrees", 85.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_sword.tween_property(spr_cojin, "rotation_degrees", 22.0, 0.15).set_trans(Tween.TRANS_SINE)
		
	# Estela de corte / swoosh
	if spr_swoosh and is_instance_valid(spr_swoosh):
		spr_swoosh.visible = true
		spr_swoosh.modulate.a = 1.0
		spr_swoosh.scale = Vector2(0.6, 0.6)
		var tw_sw = create_tween().set_parallel(true)
		tw_sw.tween_property(spr_swoosh, "scale", Vector2(1.25, 1.25), 0.18)
		tw_sw.tween_property(spr_swoosh, "modulate:a", 0.0, 0.22)
		tw_sw.chain().tween_callback(func():
			if is_instance_valid(spr_swoosh): spr_swoosh.visible = false
		)
		
	# Detección de impacto en el cono frontal de barrido
	var es_autoridad = es_autoridad_de_partida()
	for id_rival in jugadores_vivos:
		if id_rival == id_atacante: continue
		var av_rival = avatares_jugadores.get(id_rival)
		if not av_rival or not is_instance_valid(av_rival): continue
		
		var vec_hacia_rival = av_rival.global_position - av_atacante.global_position
		var dist = vec_hacia_rival.length()
		
		# Rango de la almohada (~125px) y dentro del cono frontal
		if dist <= 125.0:
			var dir_rival_norm = vec_hacia_rival.normalized() if dist > 0.1 else dir_ataque
			var dot = dir_rival_norm.dot(dir_ataque)
			if dot >= 0.20 or dist <= 48.0:
				ejecutar_impacto_en_rival(id_atacante, id_rival, dir_rival_norm)

func ejecutar_impacto_en_rival(id_atacante: int, id_rival: int, dir_empuje: Vector2):
	var av_rival = avatares_jugadores.get(id_rival)
	if not av_rival or not is_instance_valid(av_rival): return
	
	if particulas_plumas:
		particulas_plumas.global_position = (av_rival.global_position + avatares_jugadores[id_atacante].global_position) * 0.5
		particulas_plumas.restart()
		particulas_plumas.emitting = true
		
	agitar_camara(5.0)
	
	# Empuje con inercia hacia atrás
	if "velocity" in av_rival:
		av_rival.velocity = dir_empuje * 580.0
	if "fuerza_knockback" in av_rival:
		av_rival.fuerza_knockback = dir_empuje * 360.0
		
	var prefijo_rival = av_rival.get("prefijo_personaje") if "prefijo_personaje" in av_rival else "SEIK"
	if prefijo_rival == null: prefijo_rival = "SEIK"
	if av_rival.sprite and is_instance_valid(av_rival.sprite):
		var anim_imp = prefijo_rival + "_impacto"
		if av_rival.sprite.sprite_frames.has_animation(anim_imp):
			av_rival.sprite.play(anim_imp)
			
	if av_rival.has_method("aplicar_aturdimiento"):
		av_rival.aplicar_aturdimiento(0.35)

# ==============================================================================
# REDUCCIÓN PROGRESIVA DEL ESPACIO (VISUAL, SIN TEXTOS)
# ==============================================================================

func _gestionar_etapas_reduccion():
	# Aviso puramente visual 2.8s antes de la reducción
	if etapa_reduccion_actual == 0 and tiempo_restante <= ETAPA_REDUCCION_1 + 2.8 and not advertencia_activa:
		_activar_advertencia_reduccion()
	elif etapa_reduccion_actual == 1 and tiempo_restante <= ETAPA_REDUCCION_2 + 2.8 and not advertencia_activa:
		_activar_advertencia_reduccion()
	elif etapa_reduccion_actual == 2 and tiempo_restante <= ETAPA_REDUCCION_3 + 2.8 and not advertencia_activa:
		_activar_advertencia_reduccion()
		
	# Reducción efectiva a los umbrales
	if etapa_reduccion_actual == 0 and tiempo_restante <= ETAPA_REDUCCION_1:
		etapa_reduccion_actual = 1
		advertencia_activa = false
		aplicar_nueva_escala_ring(205.0)
	elif etapa_reduccion_actual == 1 and tiempo_restante <= ETAPA_REDUCCION_2:
		etapa_reduccion_actual = 2
		advertencia_activa = false
		aplicar_nueva_escala_ring(150.0)
	elif etapa_reduccion_actual == 2 and tiempo_restante <= ETAPA_REDUCCION_3:
		etapa_reduccion_actual = 3
		advertencia_activa = false
		aplicar_nueva_escala_ring(95.0)

func _activar_advertencia_reduccion():
	advertencia_activa = true
	# Parpadeo de peligro en el anillo exterior para delimitar visualmente el área en riesgo
	if alerta_reduccion:
		var escala_actual = radio_seguro_actual / 275.0
		alerta_reduccion.scale = Vector2(escala_actual, escala_actual)
		var tw_ring = create_tween().set_loops(5)
		tw_ring.tween_property(alerta_reduccion, "modulate", Color(1.0, 0.25, 0.25, 0.95), 0.26)
		tw_ring.tween_property(alerta_reduccion, "modulate", Color(1.0, 0.9, 0.2, 0.25), 0.26)
		tw_ring.finished.connect(func():
			if is_instance_valid(alerta_reduccion):
				alerta_reduccion.modulate.a = 0.0
		)

func aplicar_nueva_escala_ring(nuevo_radio: float):
	radio_seguro_actual = nuevo_radio
	var nueva_escala = nuevo_radio / 275.0
	
	if multiplayer.has_multiplayer_peer():
		sincronizar_escala_ring_rpc.rpc(nueva_escala)
	else:
		sincronizar_escala_ring_rpc(nueva_escala)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_escala_ring_rpc(nueva_escala: float):
	agitar_camara(5.0)
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if base_tatami:
		tw.tween_property(base_tatami, "scale", Vector2(nueva_escala, nueva_escala), 1.2)
	if alerta_reduccion:
		tw.tween_property(alerta_reduccion, "scale", Vector2(nueva_escala, nueva_escala), 1.2)

func _verificar_caidas_fuera_ring():
	for id in jugadores_vivos:
		var av = avatares_jugadores.get(id)
		if not av or not is_instance_valid(av): continue
		
		var dist = av.global_position.distance_to(CENTRO_ARENA)
		# Si cruza el límite del tatami hacia el suelo de madera
		if dist > radio_seguro_actual + 18.0:
			eliminar_jugador(id)

# ==============================================================================
# ELIMINACIÓN: JUGADOR ATURDIDO EN EL SUELO Y LUEGO EN IDLE SIN CONTROL
# ==============================================================================

func eliminar_jugador(id: int):
	if id not in jugadores_vivos: return
	jugadores_vivos.erase(id)
	
	if multiplayer.has_multiplayer_peer():
		sincronizar_eliminacion_rpc.rpc(id)
	else:
		sincronizar_eliminacion_rpc(id)
		
	var es_autoridad = es_autoridad_de_partida()
	# Solo un ganador: termina si queda 1 o 0
	if es_autoridad and jugadores_vivos.size() <= 1 and not partida_terminada:
		partida_terminada = true
		declarar_victoria(jugadores_vivos)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_eliminacion_rpc(id: int):
	var av = avatares_jugadores.get(id)
	if av and is_instance_valid(av):
		# 1. Quitar control total al jugador eliminado
		av.bloquear_controles(true)
		if "velocity" in av:
			av.velocity = Vector2.ZERO
		if "fuerza_knockback" in av:
			av.fuerza_knockback = Vector2.ZERO
			
		# 2. Ocultar la almohada de combate
		var cojin = cojines_en_mano.get(id)
		if cojin and is_instance_valid(cojin):
			cojin.visible = false
			
		# 3. Mantener al personaje visible en su tamaño completo en la habitación
		av.scale = Vector2.ONE
		av.modulate = Color.WHITE
		
		# 4. Reproducir aturdimiento en el punto donde cayó fuera del tatami
		var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
		if prefijo == null: prefijo = "SEIK"
		if av.sprite and is_instance_valid(av.sprite):
			var anim_aturdido = prefijo + "_aturdido"
			var anim_impacto = prefijo + "_impacto"
			if av.sprite.sprite_frames.has_animation(anim_aturdido):
				av.sprite.play(anim_aturdido)
			elif av.sprite.sprite_frames.has_animation(anim_impacto):
				av.sprite.play(anim_impacto)
				
		# 5. Tras 1.4s de aturdimiento, pasar a idle y quedarse allí hasta el fin de la ronda
		get_tree().create_timer(1.4).timeout.connect(func():
			if is_instance_valid(av) and av.sprite and is_instance_valid(av.sprite):
				if av.sprite.sprite_frames.has_animation(prefijo + "_idle"):
					av.sprite.play(prefijo + "_idle")
		)

func declarar_fin_por_tiempo():
	if partida_terminada: return
	partida_terminada = true
	declarar_victoria(jugadores_vivos)

func declarar_victoria(ids_ganadores: Array):
	partida_terminada = true
	bloquear_jugadores(true)
	
	if multiplayer.has_multiplayer_peer():
		sincronizar_victoria_rpc.rpc(ids_ganadores)
	else:
		sincronizar_victoria_rpc(ids_ganadores)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_victoria_rpc(ids_ganadores: Array):
	partida_terminada = true
	bloquear_jugadores(true)
	if alerta_reduccion: alerta_reduccion.modulate.a = 0.0
	
	# Celebración del único ganador en el tatami
	for id_win in ids_ganadores:
		var av_win = avatares_jugadores.get(id_win)
		if av_win and is_instance_valid(av_win):
			av_win.rotation = 0.0
			av_win.modulate = Color.WHITE
			av_win.scale = Vector2.ONE
			var prefijo = av_win.get("prefijo_personaje") if "prefijo_personaje" in av_win else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if av_win.sprite and is_instance_valid(av_win.sprite):
				if av_win.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
					av_win.sprite.play(prefijo + "_acierto")
					
	ejecutar_secuencia_victoria(ids_ganadores, CENTRO_ARENA)

# ==============================================================================
# MÉTODOS AUXILIARES
# ==============================================================================

func agitar_camara(intensidad: float):
	if not camera: return
	var tw = create_tween().set_loops(4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(camera, "offset", Vector2(randf_range(-intensidad, intensidad), randf_range(-intensidad, intensidad)), 0.04)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.04)
