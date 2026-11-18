extends BaseMinijuego

# Constantes de Arena (Pista de entrenamiento de Tracen ampliada 1600x900)
const ARENA_MIN_X: float = 70.0
const ARENA_MAX_X: float = 1530.0
const ARENA_MIN_Y: float = 320.0
const ARENA_MAX_Y: float = 865.0
const CENTRO_ARENA: Vector2 = Vector2(800.0, 590.0)
const POSICION_ESQUINA_KRISS: Vector2 = Vector2(1400.0, 315.0)

# Radio delimitado del área del tornado donde se pierde el control y se comienza a ascender
const RADIO_DELIMITADO_TORNADO: float = 75.0
const TIEMPO_ASCENSO_TORNADO: float = 3.8
const PULSOS_MASHING_LIBERACION: int = 5

const DURACION_PARTIDA: float = 50.0

# Sistema interno de fases de dificultad progresiva (sin textos en pantalla)
# Fase 1: Inicio sorpresa (50s - 38s) -> Rayos repentinos sin aviso, clima tempestuoso inicial
# Fase 2: Escalada (38s - 22s) -> Entra 1er tornado, rayos telegrafiados + repentinos
# Fase 3: Tempestad Mayor (22s - 11s) -> Entra 2do tornado, ráfagas de viento, rayos dobles
# Fase 4: Clímax Frenesí (11s - 0s) -> Entra 3er tornado, máxima velocidad, rayos en ráfaga rápida
var fase_interna: int = 1
const UMBRAL_FASE_2: float = 38.0
const UMBRAL_FASE_3: float = 22.0
const UMBRAL_FASE_4: float = 11.0

# Ráfagas periódicas de viento en fases avanzadas
var timer_rafaga_viento: float = 6.0
var duracion_rafaga_activa: float = 0.0

# Referencias a Nodos
@onready var modulacion_ambiente: CanvasModulate = $ModulacionAmbiente
@onready var cielo_dinamico: ColorRect = $CieloDinamico
@onready var sol: Node2D = $Sol
@onready var nubes_soleadas: Node2D = $NubesSoleadas
@onready var fondo_pista: Sprite2D = $FondoPista
@onready var node_kriss: Node2D = $SymboliKrisS
@onready var sprite_kriss: AnimatedSprite2D = $SymboliKrisS/SpriteKris
@onready var aura_kriss: CPUParticles2D = $SymboliKrisS/AuraKris
@onready var particulas_lluvia: CPUParticles2D = $ParticulasLluvia
@onready var lineas_viento: CPUParticles2D = $LineasViento
@onready var flash_tormenta: ColorRect = $FlashTormenta
@onready var contenedor_tornados: Node2D = $ContenedorTornados
@onready var contenedor_rayos: Node2D = $ContenedorRayos
@onready var camera: Camera2D = $Camera2D

# HUD
@onready var label_supervivientes: Label = $HUD/PanelInfo/HBox/LabelSupervivientes
@onready var label_tiempo: Label = $HUD/PanelInfo/HBox/LabelTiempo
@onready var banner_alerta: Label = $HUD/BannerAlerta
@onready var banner_narrativo: Label = $HUD/BannerNarrativo

# Recursos de Animación de Tornados Cartoon
var frames_tornado_funnel: SpriteFrames = preload("res://recursos/tornado_cartoon_frames.tres")
var frames_tornado_ground_ring: SpriteFrames = preload("res://recursos/tornado_ground_ring_frames.tres")
var tex_rayo_reticula: Texture2D = preload("res://assets/minijuegos/tormenta/rayo_reticula.png")

# Estado de Partida
var partida_iniciada: bool = false
var partida_terminada: bool = false
var tiempo_restante: float = DURACION_PARTIDA
var avatares_jugadores: Dictionary = {} # {id_jugador: PersonajeJugable}

# Estado de Tornados y Jugadores Atrapados
var lista_tornados: Array = []
var jugadores_atrapados: Dictionary = {} # {id_jugador: { "tornado_nombre": String, "tiempo": float, "angulo": float, "mashing": int }}
var impactos_rayo_jugador: Dictionary = {} # {id_jugador: int}

# Temporizadores de Servidor
var timer_proximo_rayo: float = 1.8
var tiempo_anim_viento: float = 0.0

func _ready():
	modo_actual = Modo.FFA
	Global.establecer_texto_accion_tactil("SPRINT")
	partida_iniciada = false
	partida_terminada = false
	tiempo_restante = DURACION_PARTIDA
	fase_interna = 1
	timer_rafaga_viento = 6.0
	duracion_rafaga_activa = 0.0
	
	if banner_alerta: banner_alerta.visible = false
	if banner_narrativo: banner_narrativo.visible = false
	if flash_tormenta:
		flash_tormenta.visible = true
		flash_tormenta.color.a = 0.0
		
	# Estado inicial soleado y calmo
	if modulacion_ambiente:
		modulacion_ambiente.color = Color(1.0, 1.0, 1.0, 1.0)
	cielo_dinamico.color = Color(0.35, 0.68, 0.95, 1.0)
	if sol:
		sol.visible = true
		sol.modulate.a = 1.0
	if nubes_soleadas:
		nubes_soleadas.visible = true
		nubes_soleadas.modulate = Color.WHITE
	if particulas_lluvia: particulas_lluvia.emitting = false
	if lineas_viento: lineas_viento.emitting = false
	if aura_kriss: aura_kriss.emitting = false
	
	# Symboli Kris S posicionada fijamente en la esquina superior derecha
	if node_kriss:
		node_kriss.position = POSICION_ESQUINA_KRISS
		if sprite_kriss:
			sprite_kriss.play("idle")
		
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
	
	var i = 0
	var spawns_iniciales = [
		Vector2(380.0, 520.0),
		Vector2(640.0, 520.0),
		Vector2(460.0, 720.0),
		Vector2(720.0, 720.0)
	]
	for id in jugadores_info.keys():
		jugadores_vivos.append(id)
		impactos_rayo_jugador[id] = 0
		var av = get_node_or_null(str(id))
		if not av and get_tree().root:
			av = get_tree().root.find_child(str(id), true, false)
			
		if av:
			avatares_jugadores[id] = av
			var pos_sp = spawns_iniciales[i % spawns_iniciales.size()]
			av.global_position = pos_sp
			av.bloquear_controles(true)
			av.modulate = Color.WHITE
			av.scale = Vector2.ONE
			av.visible = true
			if "set_movimiento_actual" in av:
				av.set_movimiento_actual = PersonajeJugable.TipoMovimiento.CON_SPRINT
			var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if "sprite" in av and av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_idle"):
				av.sprite.play(prefijo + "_idle")
		i += 1
		
	actualizar_hud_supervivientes()
	
	if not instrucciones_mostradas:
		instrucciones_mostradas = true
		mostrar_pantalla_instrucciones()
	else:
		call_deferred("iniciar_secuencia_umayuru")

func _on_instrucciones_completadas():
	inicio_cuenta_atras.emit()
	al_completar_instrucciones()

func al_completar_instrucciones():
	iniciar_secuencia_umayuru()

# ==============================================================================
# CINEMÁTICA DE INTRODUCCIÓN: ZOOM A KRIS S EN LA ESQUINA -> TORMENTA TOTAL
# ==============================================================================

func iniciar_secuencia_umayuru():
	camera.position_smoothing_enabled = true
	camera.global_position = POSICION_ESQUINA_KRISS
	camera.zoom = Vector2(1.85, 1.85)
	
	if node_kriss and sprite_kriss:
		node_kriss.position = POSICION_ESQUINA_KRISS
		sprite_kriss.play("idle")
		
	if banner_narrativo:
		banner_narrativo.text = "¡Symboli Kris S contempla la pista...!"
		banner_narrativo.visible = true
		banner_narrativo.modulate.a = 0.0
		var tw_b = create_tween()
		tw_b.tween_property(banner_narrativo, "modulate:a", 1.0, 0.4)
		
	await get_tree().create_timer(1.2).timeout
	
	if sprite_kriss:
		sprite_kriss.play("cast")
	if aura_kriss:
		aura_kriss.emitting = true
	agitar_camara(8.0)
	
	if banner_narrativo:
		banner_narrativo.text = "¡El vendaval de Kris S oscurece el horizonte!"
		
	var tw_storm = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if modulacion_ambiente:
		tw_storm.tween_property(modulacion_ambiente, "color", Color(0.24, 0.25, 0.36, 1.0), 1.6)
	tw_storm.tween_property(cielo_dinamico, "color", Color(0.10, 0.11, 0.18, 1.0), 1.6)
	if sol: tw_storm.tween_property(sol, "modulate:a", 0.0, 1.2)
	if nubes_soleadas: tw_storm.tween_property(nubes_soleadas, "modulate", Color(0.2, 0.22, 0.3, 0.3), 1.4)
	
	if lineas_viento: lineas_viento.emitting = true
	await get_tree().create_timer(0.9).timeout
	
	if particulas_lluvia:
		particulas_lluvia.emitting = true
		particulas_lluvia.amount = 280
		
	# Primer rayo de bienvenida que ilumina todo el escenario brevemente
	iluminar_por_rayo()
	ejecutar_impacto_rayo(Vector2(950.0, 520.0))
	agitar_camara(14.0)
	
	await get_tree().create_timer(0.8).timeout
	
	var tw_cam_wide = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw_cam_wide.tween_property(camera, "global_position", Vector2(800.0, 450.0), 1.2)
	tw_cam_wide.tween_property(camera, "zoom", Vector2(0.72, 0.72), 1.2)
	await tw_cam_wide.finished
	
	if banner_narrativo:
		banner_narrativo.visible = false
		
	# Iniciar la cuenta atrás oficial (3, 2, 1, ¡A ESQUIVAR!)
	ejecutar_overlay_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	partida_iniciada = true
	bloquear_jugadores(false)
	fase_interna = 1
	timer_proximo_rayo = 0.8
	timer_rafaga_viento = 6.0
	duracion_rafaga_activa = 0.0
	
	for av in avatares_jugadores.values():
		if av and is_instance_valid(av) and "set_movimiento_actual" in av:
			av.set_movimiento_actual = PersonajeJugable.TipoMovimiento.CON_SPRINT

# ==============================================================================
# BUCLE PRINCIPAL Y DIFICULTAD PROGRESIVA
# ==============================================================================

func _process(delta: float):
	if not partida_iniciada or partida_terminada:
		return
		
	tiempo_restante -= delta
	actualizar_hud_tiempo()
	
	# Condición de supervivencia: si se agota el tiempo, todos los que sigan en pie ganan
	if tiempo_restante <= 0.0:
		tiempo_restante = 0.0
		declarar_fin_por_tiempo()
		return
		
	# Gestión de dificultad progresiva continua y fases internas
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad:
		_gestionar_fases_internas()
		_gestionar_temporizador_rayos(delta)
		
	_actualizar_tornados(delta)
	_actualizar_jugadores_atrapados(delta)
	_actualizar_rafagas_viento(delta)

func _gestionar_fases_internas():
	# Fase 2 (38s restantes): Entra el 1er tornado
	if fase_interna < 2 and tiempo_restante <= UMBRAL_FASE_2:
		fase_interna = 2
		crear_tornado_servidor(Vector2(1420.0, 600.0), Vector2(-1.0, -0.3).normalized(), 0)
		
	# Fase 3 (22s restantes): Entra el 2do tornado y la tempestad se intensifica
	if fase_interna < 3 and tiempo_restante <= UMBRAL_FASE_3:
		fase_interna = 3
		crear_tornado_servidor(Vector2(180.0, 480.0), Vector2(1.0, 0.35).normalized(), 1)
		if particulas_lluvia:
			particulas_lluvia.amount = 420
		if lineas_viento:
			lineas_viento.amount = 85
		if modulacion_ambiente:
			var tw_dark = create_tween()
			tw_dark.tween_property(modulacion_ambiente, "color", Color(0.18, 0.19, 0.29, 1.0), 1.5)
			
	# Fase 4: Clímax Frenesí (11s restantes): Entra el 3er tornado en la pista
	if fase_interna < 4 and tiempo_restante <= UMBRAL_FASE_4:
		fase_interna = 4
		crear_tornado_servidor(Vector2(800.0, 390.0), Vector2(0.5, 0.86).normalized(), 2)
		if particulas_lluvia:
			particulas_lluvia.amount = 560
		if lineas_viento:
			lineas_viento.amount = 110
		if modulacion_ambiente:
			var tw_frenzy = create_tween()
			tw_frenzy.tween_property(modulacion_ambiente, "color", Color(0.15, 0.16, 0.25, 1.0), 1.0)

func _gestionar_temporizador_rayos(delta: float):
	timer_proximo_rayo -= delta
	if timer_proximo_rayo <= 0.0:
		var progreso = 1.0 - (tiempo_restante / DURACION_PARTIDA) # 0.0 a 1.0
		match fase_interna:
			1:
				# FASE 1: RAYOS REPENTINOS SIN NINGÚN AVISO (SORPRESA)
				disparar_rayo_repentino_servidor()
				timer_proximo_rayo = randf_range(1.6, 2.2)
			2:
				# FASE 2: 75% telegrafiados con retícula, 25% repentinos
				if randf() < 0.75:
					disparar_telegrafo_rayo(1.20)
				else:
					disparar_rayo_repentino_servidor()
				timer_proximo_rayo = randf_range(1.8, 2.3)
			3:
				# FASE 3: Tempestad feroz, retícula más rápida (1.0s) y rayos dobles (40%)
				disparar_telegrafo_rayo(1.0)
				if randf() < 0.45:
					get_tree().create_timer(0.3).timeout.connect(func():
						if partida_iniciada and not partida_terminada:
							disparar_rayo_repentino_servidor()
					)
				timer_proximo_rayo = randf_range(1.1, 1.5)
			4:
				# FASE 4 (CLÍMAX FRENESÍ): Retícula ultrarrápida (0.85s) y barrera doble constante
				disparar_telegrafo_rayo(0.85)
				if randf() < 0.65:
					get_tree().create_timer(0.25).timeout.connect(func():
						if partida_iniciada and not partida_terminada:
							if randf() < 0.5:
								disparar_telegrafo_rayo(0.8)
							else:
								disparar_rayo_repentino_servidor()
					)
				timer_proximo_rayo = randf_range(0.75, 1.05)

func _actualizar_rafagas_viento(delta: float):
	# En fases 3 y 4 se producen ráfagas de viento laterales
	if fase_interna < 3: return
	
	if duracion_rafaga_activa > 0.0:
		duracion_rafaga_activa -= delta
		var fuerza_viento = 65.0 if fase_interna == 3 else 90.0
		for id in jugadores_vivos:
			if jugadores_atrapados.has(id): continue
			var av = avatares_jugadores.get(id)
			if av and is_instance_valid(av):
				# Viento soplando suavemente hacia la izquierda
				av.global_position.x -= fuerza_viento * delta
				av.global_position.x = clamp(av.global_position.x, ARENA_MIN_X + 20.0, ARENA_MAX_X - 20.0)
	else:
		timer_rafaga_viento -= delta
		if timer_rafaga_viento <= 0.0:
			duracion_rafaga_activa = 1.3
			timer_rafaga_viento = randf_range(5.5, 7.5)
			agitar_camara(5.0)

# ==============================================================================
# ILUMINACIÓN BREVE DE ESCENARIO Y CIELO AL CAER RAYOS
# ==============================================================================

func iluminar_por_rayo():
	if modulacion_ambiente:
		var color_base = Color(0.24, 0.25, 0.36, 1.0)
		if fase_interna == 3: color_base = Color(0.18, 0.19, 0.29, 1.0)
		elif fase_interna == 4: color_base = Color(0.15, 0.16, 0.25, 1.0)
		
		var tw_mod = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_mod.tween_property(modulacion_ambiente, "color", Color(1.4, 1.45, 1.6, 1.0), 0.04)
		tw_mod.tween_property(modulacion_ambiente, "color", color_base, 0.18)
		
	if cielo_dinamico:
		var cielo_base = Color(0.10, 0.11, 0.18, 1.0)
		var tw_cielo = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_cielo.tween_property(cielo_dinamico, "color", Color(0.88, 0.94, 1.0, 1.0), 0.04)
		tw_cielo.tween_property(cielo_dinamico, "color", cielo_base, 0.20)
		
	if flash_tormenta:
		var tw_fl = create_tween().set_trans(Tween.TRANS_SINE)
		tw_fl.tween_property(flash_tormenta, "color:a", 0.55, 0.04)
		tw_fl.tween_property(flash_tormenta, "color:a", 0.0, 0.16)

# ==============================================================================
# RAYOS: REPENTINOS (SIN AVISO) Y TELEGRAFIADOS
# ==============================================================================

func disparar_rayo_repentino_servidor():
	var target_pos = _calcular_posicion_impacto_rayo()
	if multiplayer.has_multiplayer_peer():
		crear_rayo_repentino_rpc.rpc(target_pos)
	else:
		crear_rayo_repentino_rpc(target_pos)

@rpc("any_peer", "call_local", "reliable")
func crear_rayo_repentino_rpc(pos: Vector2):
	ejecutar_impacto_rayo(pos)

func disparar_telegrafo_rayo(tiempo_aviso: float = 1.25):
	var target_pos = _calcular_posicion_impacto_rayo()
	if multiplayer.has_multiplayer_peer():
		crear_telegrafo_rayo_rpc.rpc(target_pos, tiempo_aviso)
	else:
		crear_telegrafo_rayo_rpc(target_pos, tiempo_aviso)

func _calcular_posicion_impacto_rayo() -> Vector2:
	var target_pos = Vector2(
		randf_range(ARENA_MIN_X + 120.0, ARENA_MAX_X - 120.0),
		randf_range(ARENA_MIN_Y + 50.0, ARENA_MAX_Y - 50.0)
	)
	if randf() < 0.65 and jugadores_vivos.size() > 0:
		var id_target = jugadores_vivos[randi() % jugadores_vivos.size()]
		var av = avatares_jugadores.get(id_target)
		if av and is_instance_valid(av):
			target_pos = av.global_position + Vector2(randf_range(-90.0, 90.0), randf_range(-70.0, 70.0))
			target_pos.x = clamp(target_pos.x, ARENA_MIN_X + 60.0, ARENA_MAX_X - 60.0)
			target_pos.y = clamp(target_pos.y, ARENA_MIN_Y + 40.0, ARENA_MAX_Y - 40.0)
	return target_pos

@rpc("any_peer", "call_local", "reliable")
func crear_telegrafo_rayo_rpc(pos: Vector2, tiempo_aviso: float = 1.25):
	var reticula = Sprite2D.new()
	reticula.texture = tex_rayo_reticula
	reticula.position = pos
	reticula.scale = Vector2(0.5, 0.5)
	reticula.modulate = Color(1.0, 1.0, 1.0, 0.2)
	contenedor_rayos.add_child(reticula)
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(reticula, "scale", Vector2(1.15, 1.15), tiempo_aviso)
	tw.tween_property(reticula, "modulate:a", 1.0, tiempo_aviso)
	
	await tw.finished
	if is_instance_valid(reticula):
		reticula.queue_free()
		ejecutar_impacto_rayo(pos)

func ejecutar_impacto_rayo(pos: Vector2):
	iluminar_por_rayo()
	agitar_camara(12.0)
	
	var rayo = Line2D.new()
	rayo.width = 7.0
	rayo.default_color = Color(0.92, 0.96, 1.0, 1.0)
	
	var puntos = PackedVector2Array()
	var cur = Vector2(pos.x + randf_range(-30.0, 30.0), -40.0)
	puntos.append(cur)
	
	var pasos = 11
	for i in range(pasos):
		var t = float(i + 1) / float(pasos)
		var dest_y = lerp(-40.0, pos.y, t)
		var dest_x = lerp(cur.x, pos.x, t) + randf_range(-35.0, 35.0)
		if i == pasos - 1: dest_x = pos.x
		puntos.append(Vector2(dest_x, dest_y))
	rayo.points = puntos
	contenedor_rayos.add_child(rayo)
	
	var tw_rayo = create_tween()
	tw_rayo.tween_property(rayo, "modulate:a", 0.0, 0.22)
	tw_rayo.tween_callback(func(): rayo.queue_free())
	
	var sparks = CPUParticles2D.new()
	sparks.position = pos
	sparks.amount = 30
	sparks.lifetime = 0.45
	sparks.explosiveness = 1.0
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 16.0
	sparks.direction = Vector2(0.0, -1.0)
	sparks.spread = 180.0
	sparks.gravity = Vector2(0.0, 300.0)
	sparks.initial_velocity_min = 160.0
	sparks.initial_velocity_max = 350.0
	sparks.scale_amount_min = 3.0
	sparks.scale_amount_max = 5.5
	sparks.color = Color(1.0, 0.92, 0.4, 1.0)
	contenedor_rayos.add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(0.6).timeout.connect(func(): if is_instance_valid(sparks): sparks.queue_free())
	
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad:
		for id in jugadores_vivos:
			if jugadores_atrapados.has(id): continue
			var av = avatares_jugadores.get(id)
			if not av or not is_instance_valid(av): continue
			
			if av.global_position.distance_to(pos) <= 60.0:
				impactar_jugador_por_rayo(id, pos)

func impactar_jugador_por_rayo(id: int, pos_impacto: Vector2):
	impactos_rayo_jugador[id] = impactos_rayo_jugador.get(id, 0) + 1
	var expulsar = impactos_rayo_jugador[id] >= 2
	
	if multiplayer.has_multiplayer_peer():
		sincronizar_impacto_rayo_rpc.rpc(id, pos_impacto, expulsar)
	else:
		sincronizar_impacto_rayo_rpc(id, pos_impacto, expulsar)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_impacto_rayo_rpc(id: int, pos_impacto: Vector2, expulsar: bool):
	var av = avatares_jugadores.get(id)
	if not av or not is_instance_valid(av): return
	
	var dir_empuje = (av.global_position - pos_impacto).normalized()
	if dir_empuje == Vector2.ZERO: dir_empuje = Vector2.UP
	av.global_position += dir_empuje * 105.0
	
	var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
	if prefijo == null: prefijo = "SEIK"
	if "sprite" in av and av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_aturdido"):
		av.sprite.play(prefijo + "_aturdido")
		
	if expulsar:
		if multiplayer.has_multiplayer_peer():
			expulsar_jugador_rpc.rpc(id)
		else:
			expulsar_jugador_rpc(id)
	else:
		av.bloquear_controles(true)
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(av) and id in jugadores_vivos and not jugadores_atrapados.has(id):
			av.bloquear_controles(false)

# ==============================================================================
# TORNADOS CARTOON CON VELOCIDAD Y AGILIDAD ESCALABLE
# ==============================================================================

func crear_tornado_servidor(pos: Vector2, dir_inicial: Vector2, idx: int):
	if multiplayer.has_multiplayer_peer():
		instanciar_tornado_rpc.rpc(pos, dir_inicial, idx)
	else:
		instanciar_tornado_rpc(pos, dir_inicial, idx)

@rpc("any_peer", "call_local", "reliable")
func instanciar_tornado_rpc(pos: Vector2, dir_inicial: Vector2, idx: int):
	var t = Node2D.new()
	t.name = "Tornado_" + str(idx)
	t.position = pos
	t.set_meta("dir", dir_inicial)
	t.set_meta("velocidad_base", 95.0)
	
	# Anillo visual delimitado del área de peligro en el suelo
	var spr_ring = AnimatedSprite2D.new()
	spr_ring.name = "GroundRing"
	spr_ring.sprite_frames = frames_tornado_ground_ring
	spr_ring.play("default")
	spr_ring.position = Vector2(0.0, 0.0)
	spr_ring.scale = Vector2(1.0, 1.0)
	t.add_child(spr_ring)
	
	# Vórtice de tornado cartoon animado
	var spr_funnel = AnimatedSprite2D.new()
	spr_funnel.name = "Funnel"
	spr_funnel.sprite_frames = frames_tornado_funnel
	spr_funnel.play("default")
	spr_funnel.position = Vector2(0.0, -170.0)
	spr_funnel.scale = Vector2(1.0, 1.0)
	t.add_child(spr_funnel)
	
	# Partículas suaves de viento
	var parts = CPUParticles2D.new()
	parts.name = "VientoSpirals"
	parts.position = Vector2(0.0, -120.0)
	parts.amount = 26
	parts.lifetime = 0.75
	parts.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	parts.emission_sphere_radius = 40.0
	parts.direction = Vector2(0.0, -1.0)
	parts.spread = 40.0
	parts.gravity = Vector2(0.0, -90.0)
	parts.initial_velocity_min = 120.0
	parts.initial_velocity_max = 210.0
	parts.angular_velocity_min = 360.0
	parts.angular_velocity_max = 720.0
	parts.scale_amount_min = 3.0
	parts.scale_amount_max = 5.0
	parts.color = Color(0.88, 0.94, 1.0, 0.65)
	t.add_child(parts)
	
	contenedor_tornados.add_child(t)
	lista_tornados.append(t)

func _actualizar_tornados(delta: float):
	tiempo_anim_viento += delta
	
	# Dificultad progresiva: La velocidad de los tornados escala con el tiempo transcurrido
	var progreso_dificultad = 1.0 - (tiempo_restante / DURACION_PARTIDA)
	var vel_actual = lerp(95.0, 142.0, progreso_dificultad)
	
	for t in lista_tornados:
		if not is_instance_valid(t): continue
		
		var dir = t.get_meta("dir") as Vector2
		
		# Movimiento con rebote en los bordes de la arena
		t.position += dir * vel_actual * delta
		
		if t.position.x <= ARENA_MIN_X + 110.0 and dir.x < 0.0:
			dir.x = abs(dir.x)
		elif t.position.x >= ARENA_MAX_X - 110.0 and dir.x > 0.0:
			dir.x = -abs(dir.x)
			
		if t.position.y <= ARENA_MIN_Y + 110.0 and dir.y < 0.0:
			dir.y = abs(dir.y)
		elif t.position.y >= ARENA_MAX_Y - 100.0 and dir.y > 0.0:
			dir.y = -abs(dir.y)
			
		t.set_meta("dir", dir)
		
		# Animación oscilatoria visual
		var spr_funnel = t.get_node_or_null("Funnel")
		if spr_funnel:
			spr_funnel.rotation = sin(tiempo_anim_viento * (6.0 + progreso_dificultad * 4.0)) * 0.06
			
		var es_autoridad = es_autoridad_de_partida()
		for id in jugadores_vivos:
			if jugadores_atrapados.has(id): continue
			var av = avatares_jugadores.get(id)
			if not av or not is_instance_valid(av): continue
			
			# Comprobación de colisión elíptica en el suelo
			var offset = av.global_position - t.global_position
			var dist_elip = (offset.x * offset.x) / (RADIO_DELIMITADO_TORNADO * RADIO_DELIMITADO_TORNADO) + (offset.y * offset.y) / (38.0 * 38.0)
			
			if dist_elip <= 1.0 and es_autoridad:
				engullir_jugador_en_tornado(id, t.name)

# ==============================================================================
# JUGADORES ENGULLIDOS: ASCENSO POR EL VÓRTICE
# ==============================================================================

func engullir_jugador_en_tornado(id: int, tornado_nombre: String):
	if multiplayer.has_multiplayer_peer():
		sincronizar_captura_tornado_rpc.rpc(id, tornado_nombre)
	else:
		sincronizar_captura_tornado_rpc(id, tornado_nombre)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_captura_tornado_rpc(id: int, tornado_nombre: String):
	var av = avatares_jugadores.get(id)
	if not av or not is_instance_valid(av): return
	
	jugadores_atrapados[id] = {
		"tornado_nombre": tornado_nombre,
		"tiempo": 0.0,
		"angulo": randf() * TAU,
		"mashing": 0
	}
	
	av.bloquear_controles(true)
	var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
	if prefijo == null: prefijo = "SEIK"
	if "sprite" in av and av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_resbalar"):
		av.sprite.play(prefijo + "_resbalar")

func _actualizar_jugadores_atrapados(delta: float):
	var lista_ids = jugadores_atrapados.keys()
	var es_local_o_autoridad = es_autoridad_de_partida()
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	
	for id in lista_ids:
		var datos = jugadores_atrapados.get(id)
		if not datos: continue
		
		datos["tiempo"] += delta
		datos["angulo"] += delta * 8.0
		
		var t = contenedor_tornados.get_node_or_null(datos["tornado_nombre"])
		var av = avatares_jugadores.get(id)
		
		if not is_instance_valid(t) or not is_instance_valid(av):
			jugadores_atrapados.erase(id)
			continue
			
		var prog_ascenso = clamp(datos["tiempo"] / TIEMPO_ASCENSO_TORNADO, 0.0, 1.0)
		var altura = lerp(0.0, -260.0, prog_ascenso)
		var radio_giro = lerp(24.0, 70.0, prog_ascenso)
		var offset_orbita = Vector2(cos(datos["angulo"]), sin(datos["angulo"]) * 0.38) * radio_giro
		
		av.global_position = t.global_position + Vector2(offset_orbita.x, altura + offset_orbita.y)
		av.rotation = datos["angulo"] * 1.6
		av.scale = Vector2.ONE * lerp(1.0, 0.72, prog_ascenso)
		
		if id == mi_id and _es_boton_accion_presionado():
			datos["mashing"] += 1
			if multiplayer.has_multiplayer_peer():
				reportar_mashing_rpc.rpc(id)
			else:
				verificar_liberacion_mashing(id)
				
		if es_local_o_autoridad and datos["tiempo"] >= TIEMPO_ASCENSO_TORNADO:
			if multiplayer.has_multiplayer_peer():
				expulsar_jugador_rpc.rpc(id)
			else:
				expulsar_jugador_rpc(id)

@rpc("any_peer", "call_local", "reliable")
func reportar_mashing_rpc(id: int):
	if not es_autoridad_de_partida(): return
	verificar_liberacion_mashing(id)

func verificar_liberacion_mashing(id: int):
	var datos = jugadores_atrapados.get(id)
	if not datos: return
	datos["mashing"] += 1
	if datos["mashing"] >= PULSOS_MASHING_LIBERACION:
		if multiplayer.has_multiplayer_peer():
			liberar_jugador_tornado_rpc.rpc(id)
		else:
			liberar_jugador_tornado_rpc(id)

@rpc("any_peer", "call_local", "reliable")
func liberar_jugador_tornado_rpc(id: int):
	if not jugadores_atrapados.has(id): return
	var datos = jugadores_atrapados[id]
	var t = contenedor_tornados.get_node_or_null(datos["tornado_nombre"])
	jugadores_atrapados.erase(id)
	
	var av = avatares_jugadores.get(id)
	if av and is_instance_valid(av):
		av.rotation = 0.0
		av.scale = Vector2.ONE
		var dir_expulsion = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)).normalized()
		var pos_base = t.global_position if is_instance_valid(t) else av.global_position
		av.global_position = pos_base + dir_expulsion * 135.0
		av.global_position.x = clamp(av.global_position.x, ARENA_MIN_X + 25.0, ARENA_MAX_X - 25.0)
		av.global_position.y = clamp(av.global_position.y, ARENA_MIN_Y + 25.0, ARENA_MAX_Y - 25.0)
		
		var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
		if prefijo == null: prefijo = "SEIK"
		if "sprite" in av and av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_aturdido"):
			av.sprite.play(prefijo + "_aturdido")
			
		av.bloquear_controles(true)
		await get_tree().create_timer(0.8).timeout
		if is_instance_valid(av) and id in jugadores_vivos:
			av.bloquear_controles(false)

@rpc("any_peer", "call_local", "reliable")
func expulsar_jugador_rpc(id: int):
	jugadores_atrapados.erase(id)
	var av = avatares_jugadores.get(id)
	if av and is_instance_valid(av):
		av.bloquear_controles(true)
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(av, "position:y", av.position.y - 850.0, 0.75)
		tw.tween_property(av, "scale", Vector2.ZERO, 0.75)
		tw.tween_property(av, "modulate:a", 0.0, 0.65)
		
	eliminar_jugador(id)

# ==============================================================================
# ELIMINACIÓN Y FIN DE PARTIDA: VICTORIA PARA TODOS LOS SUPERVIVIENTES
# ==============================================================================

func eliminar_jugador(id: int):
	if id not in jugadores_vivos: return
	jugadores_vivos.erase(id)
	actualizar_hud_supervivientes()
	
	# Solo finaliza prematuramente si TODOS los jugadores han sido eliminados (0 supervivientes)
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad and jugadores_vivos.is_empty() and not partida_terminada:
		partida_terminada = true
		declarar_victoria([])

func declarar_fin_por_tiempo():
	if partida_terminada: return
	partida_terminada = true
	
	# Todos los jugadores que siguen con vida y no están atrapados ganan
	var ganadores: Array = []
	for id in jugadores_vivos:
		if not jugadores_atrapados.has(id):
			ganadores.append(id)
			
	declarar_victoria(ganadores)

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
	if banner_alerta: banner_alerta.visible = false
	
	# Retorno de la luz natural al escenario (la tormenta cesa)
	var tw_clear = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
	if modulacion_ambiente:
		tw_clear.tween_property(modulacion_ambiente, "color", Color(1.0, 1.0, 1.0, 1.0), 1.6)
	tw_clear.tween_property(cielo_dinamico, "color", Color(0.35, 0.68, 0.95, 1.0), 1.6)
	if particulas_lluvia: particulas_lluvia.emitting = false
	if lineas_viento: lineas_viento.emitting = false
	if aura_kriss: aura_kriss.emitting = false
	if sprite_kriss: sprite_kriss.play("idle")
	
	# Disipar tornados y limpiar retículas residuales al calmarse el viento
	for t in lista_tornados:
		if is_instance_valid(t):
			var tw_t = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD)
			tw_t.tween_property(t, "scale", Vector2.ZERO, 0.8)
			tw_t.tween_property(t, "modulate:a", 0.0, 0.8)
			tw_t.chain().tween_callback(func(): if is_instance_valid(t): t.queue_free())
	lista_tornados.clear()
	
	if contenedor_rayos:
		for r in contenedor_rayos.get_children():
			if is_instance_valid(r):
				r.queue_free()
	
	# Cada superviviente celebra su victoria en la pista
	for id_win in ids_ganadores:
		var av_win = avatares_jugadores.get(id_win)
		if av_win and is_instance_valid(av_win):
			av_win.rotation = 0.0
			av_win.modulate = Color.WHITE
			av_win.scale = Vector2.ONE
			var prefijo = av_win.get("prefijo_personaje") if "prefijo_personaje" in av_win else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if "sprite" in av_win and av_win.sprite and av_win.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
				av_win.sprite.play(prefijo + "_acierto")
				
	# Delegar la secuencia de victoria colectiva al framework base
	ejecutar_secuencia_victoria(ids_ganadores, CENTRO_ARENA)

# ==============================================================================
# MÉTODOS AUXILIARES DE HUD, CÁMARA Y CONTROL SEGURO
# ==============================================================================

func agitar_camara(intensidad: float):
	if not camera: return
	var tw = create_tween().set_loops(4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(camera, "offset", Vector2(randf_range(-intensidad, intensidad), randf_range(-intensidad, intensidad)), 0.04)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.04)

func actualizar_hud_supervivientes():
	if label_supervivientes:
		var total = jugadores_info.size() if jugadores_info.size() > 0 else 4
		label_supervivientes.text = "SUPERVIVIENTES: %d / %d" % [jugadores_vivos.size(), total]

func actualizar_hud_tiempo():
	if label_tiempo:
		label_tiempo.text = "TIEMPO: %ds" % int(max(0.0, tiempo_restante))

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
