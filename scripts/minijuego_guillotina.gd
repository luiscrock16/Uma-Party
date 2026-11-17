extends BaseMinijuego

# Nodos Principales
@onready var fondo = $FondoFabrica
@onready var suelo = $SueloFabrica
@onready var base_entrega = $BaseEntrega
@onready var mesa_jurados = $MesaJurados
@onready var directora_mesa = $MesaJurados/DirectoraMesa
@onready var area_entrega = $MesaJurados/AreaEntrega
@onready var maquina_central = $MaquinaCentral
@onready var vapor_rosa = $MaquinaCentral/VaporRosa
@onready var contenedor_charcos = $ContenedorCharcos
@onready var contenedor_platos = $ContenedorPlatos
@onready var contenedor_items = $ContenedorItems
@onready var contenedor_proyectiles = $ContenedorProyectiles
@onready var contenedor_carritos = $ContenedorCarritos
@onready var contenedor_robots = $ContenedorRobotsLimpiadores
@onready var contenedor_peligros = $ContenedorPeligros
@onready var camera = $Camera2D

# Texturas Pre-cargadas
var tex_plato: Texture2D
var tex_capas: Array[Texture2D] = []
var tex_arruinado: Texture2D
var tex_items: Dictionary = {}
var tex_sombra: Texture2D
var tex_bomba_crema: Texture2D
var tex_charco_crema: Texture2D
var tex_yunque_choco: Texture2D
var tex_robot_limpiador: Texture2D

# SpriteFrames para NPCs
var frames_akyy_idle: SpriteFrames
var frames_tazuna_deliver: SpriteFrames
var frames_akyy_deliver: SpriteFrames

# Estado del Minijuego
var partida_iniciada: bool = false
var partida_terminada: bool = false
var id_ganador_partida: int = -1

# Dificultad Dinámica Ambiental y Eventos Especiales
var dificultad_nivel: float = 1.0 # Crece de 1.0 a 3.2
var tiempo_partida: float = 0.0
var timer_spawn_ingrediente: float = 2.0
var timer_spawn_peligro: float = 4.0
var timer_spawn_robot_limpieza: float = 6.0

var evento_tazuna_lanzado: bool = false
var evento_directora_lanzado: bool = false

# Estructura de Jugadores y Platos
# { id: { "avatar": Node, "plato_nodo": Node, "capas": int, "llevando_plato": bool, "item_en_mano": int, "arruinado_cooldown": float } }
var datos_jugadores: Dictionary = {}

func _ready():
	modo_actual = Modo.FFA
	if has_node("/root/Global"):
		get_node("/root/Global").establecer_texto_accion_tactil("INTERACTUAR / LANZAR")
		
	partida_iniciada = false
	partida_terminada = false
	id_ganador_partida = -1
	dificultad_nivel = 1.0
	tiempo_partida = 0.0
	timer_spawn_robot_limpieza = 6.0
	evento_tazuna_lanzado = false
	evento_directora_lanzado = false
	
	_cargar_recursos()
	
	if area_entrega:
		area_entrega.body_entered.connect(_on_area_entrega_body_entered)
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func _cargar_recursos():
	tex_plato = preload("res://assets/minijuegos/fabrica_pastel/plato_pastel.png")
	tex_capas = [
		tex_plato,
		preload("res://assets/minijuegos/fabrica_pastel/pastel_capa_1.png"),
		preload("res://assets/minijuegos/fabrica_pastel/pastel_capa_2.png"),
		preload("res://assets/minijuegos/fabrica_pastel/pastel_capa_3.png"),
		preload("res://assets/minijuegos/fabrica_pastel/pastel_capa_4.png"),
		preload("res://assets/minijuegos/fabrica_pastel/pastel_capa_5.png")
	]
	tex_arruinado = preload("res://assets/minijuegos/fabrica_pastel/pastel_arruinado.png")
	
	tex_items = {
		1: preload("res://assets/minijuegos/fabrica_pastel/item_bizcocho.png"),
		2: preload("res://assets/minijuegos/fabrica_pastel/item_crema.png"),
		3: preload("res://assets/minijuegos/fabrica_pastel/item_chocolate.png"),
		4: preload("res://assets/minijuegos/fabrica_pastel/item_merengue.png"),
		5: preload("res://assets/minijuegos/fabrica_pastel/item_cereza.png"),
		6: preload("res://assets/minijuegos/fabrica_pastel/item_tazuna_dorado.png"),
		7: preload("res://assets/minijuegos/fabrica_pastel/item_directora_corona.png")
	}
	
	tex_sombra = preload("res://assets/minijuegos/fabrica_pastel/sombra_peligro.png")
	tex_bomba_crema = preload("res://assets/minijuegos/fabrica_pastel/peligro_crema_bomba.png")
	tex_charco_crema = preload("res://assets/minijuegos/fabrica_pastel/peligro_charco_crema.png")
	tex_yunque_choco = preload("res://assets/minijuegos/fabrica_pastel/peligro_chocolate_yunque.png")
	tex_robot_limpiador = preload("res://assets/minijuegos/fabrica_pastel/robot_limpiador.png")
	
	# SpriteFrames para Yayoi Akikawa en la mesa
	frames_akyy_idle = SpriteFrames.new()
	frames_akyy_idle.add_animation("idle")
	frames_akyy_idle.set_animation_speed("idle", 4.0)
	for i in range(4):
		var p = "res://assets/Sprites/NPCS/Yayoi Akikawa/akyy_ST01_0%d.png" % i
		if ResourceLoader.exists(p):
			frames_akyy_idle.add_frame("idle", load(p))
			
	if directora_mesa:
		directora_mesa.sprite_frames = frames_akyy_idle
		directora_mesa.play("idle")
		directora_mesa.visible = true
		
	# SpriteFrames para Carrito de Tazuna
	frames_tazuna_deliver = SpriteFrames.new()
	frames_tazuna_deliver.add_animation("deliver")
	frames_tazuna_deliver.set_animation_speed("deliver", 10.0)
	for i in range(6):
		var p = "res://assets/Sprites/NPCS/Tazuna Hayakawa/deliver_tadunasan_0%d.png" % i
		if ResourceLoader.exists(p):
			frames_tazuna_deliver.add_frame("deliver", load(p))
			
	# SpriteFrames para Carrito de la Directora
	frames_akyy_deliver = SpriteFrames.new()
	frames_akyy_deliver.add_animation("deliver")
	frames_akyy_deliver.set_animation_speed("deliver", 10.0)
	for i in range(6):
		var p = "res://assets/Sprites/NPCS/Yayoi Akikawa/deliver_rizicho_0%d.png" % i
		if ResourceLoader.exists(p):
			frames_akyy_deliver.add_frame("deliver", load(p))

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
	datos_jugadores.clear()
	
	# Limpiar contenedores
	for n in [contenedor_charcos, contenedor_platos, contenedor_items, contenedor_proyectiles, contenedor_carritos, contenedor_robots, contenedor_peligros]:
		if n:
			for c in n.get_children():
				c.queue_free()
				
	var spawns_avatares = [
		Vector2(280, 410),
		Vector2(872, 410),
		Vector2(360, 565),
		Vector2(792, 565)
	]
	
	var spawns_platos = [
		Vector2(280, 460),
		Vector2(872, 460),
		Vector2(360, 510),
		Vector2(792, 510)
	]
	
	var colores_bordes = [
		Color(0.2, 0.6, 1.0),
		Color(1.0, 0.25, 0.25),
		Color(0.2, 0.9, 0.3),
		Color(1.0, 0.75, 0.1)
	]
	
	var idx = 0
	for id in jugadores_info.keys():
		var av = get_node_or_null(str(id))
		if not av and get_tree().root:
			av = get_tree().root.find_child(str(id), true, false)
			
		if av:
			av.global_position = spawns_avatares[idx % spawns_avatares.size()]
			av.bloquear_controles(true)
			av.velocity = Vector2.ZERO
			av.modulate = Color.WHITE
			av.scale = Vector2.ONE
			av.visible = true
			if "set_movimiento_actual" in av:
				av.set_movimiento_actual = PersonajeJugable.TipoMovimiento.NORMAL_SOLO
				
			var plato = _crear_plato_jugador(id, idx, spawns_platos[idx % spawns_platos.size()], colores_bordes[idx % colores_bordes.size()])
			
			datos_jugadores[id] = {
				"avatar": av,
				"plato_nodo": plato,
				"capas": 0,
				"llevando_plato": false,
				"item_en_mano": 0,
				"arruinado_cooldown": 0.0
			}
			
		idx += 1
		
	if not instrucciones_mostradas:
		instrucciones_mostradas = true
		mostrar_pantalla_instrucciones()
	else:
		call_deferred("iniciar_secuencia_cuenta_atras")

func _crear_plato_jugador(id: int, idx: int, pos: Vector2, color_borde: Color) -> Node2D:
	var nodo = Node2D.new()
	nodo.name = "Plato_" + str(id)
	nodo.global_position = pos
	
	var sprite_plato = Sprite2D.new()
	sprite_plato.name = "SpritePastel"
	sprite_plato.texture = tex_plato
	sprite_plato.position = Vector2.ZERO
	nodo.add_child(sprite_plato)
	
	var aro = Line2D.new()
	aro.name = "AroColor"
	aro.width = 3.0
	aro.default_color = color_borde
	var pts: PackedVector2Array = []
	for a in range(0, 361, 30):
		var rad = deg_to_rad(a)
		pts.append(Vector2(cos(rad) * 44, sin(rad) * 22))
	aro.points = pts
	nodo.add_child(aro)
	
	var label = Label.new()
	label.name = "LabelP"
	label.text = "P" + str(idx + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.offset_left = -30
	label.offset_right = 30
	label.offset_top = 14
	label.offset_bottom = 35
	label.add_theme_color_override("font_color", color_borde)
	label.add_theme_font_size_override("font_size", 13)
	nodo.add_child(label)
	
	var chispas = CPUParticles2D.new()
	chispas.name = "ChispasVictoria"
	chispas.emitting = false
	chispas.amount = 16
	chispas.lifetime = 0.8
	chispas.spread = 180.0
	chispas.gravity = Vector2(0, -30)
	chispas.initial_velocity_min = 20.0
	chispas.initial_velocity_max = 45.0
	chispas.color = Color(1.0, 0.9, 0.3, 0.95)
	nodo.add_child(chispas)
	
	contenedor_platos.add_child(nodo)
	return nodo

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

func agitar_camara(fuerza: float = 4.0):
	if not camera: return
	var pos_original = camera.position
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	for i in range(4):
		var offset = Vector2(randf_range(-fuerza, fuerza), randf_range(-fuerza, fuerza))
		tw.tween_property(camera, "position", pos_original + offset, 0.04)
	tw.tween_property(camera, "position", pos_original, 0.04)

# ==============================================================================
# BUCLE PRINCIPAL, DIFICULTAD Y EVENTOS (ROBOTS LIMPIADORES, TAZUNA & DIRECTORA)
# ==============================================================================

func _process(delta: float):
	if not partida_iniciada or partida_terminada: return
	
	tiempo_partida += delta
	_actualizar_dificultad_dinamica(delta)
	_actualizar_platos_y_manos(delta)
	
	var es_server = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if es_server:
		_procesar_spawns_servidor(delta)
		_comprobar_entregas_servidor()
		_comprobar_eventos_delivery_servidor()
		
	_procesar_inteligencia_artificial_bots(delta)

func _actualizar_dificultad_dinamica(delta: float):
	var dif_tiempo = 1.0 + (tiempo_partida / 45.0)
	
	var max_capas = 0
	for d in datos_jugadores.values():
		if d.capas > max_capas:
			max_capas = d.capas
			
	var bonus_progreso = float(max_capas) * 0.25
	dificultad_nivel = clampf(dif_tiempo + bonus_progreso, 1.0, 3.2)
	
	if vapor_rosa:
		vapor_rosa.speed_scale = 0.9 + dificultad_nivel * 0.4
		vapor_rosa.amount = int(16 + dificultad_nivel * 12)
		
	if maquina_central and dificultad_nivel > 1.8:
		var shake = (dificultad_nivel - 1.8) * 1.5
		maquina_central.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))

func _actualizar_platos_y_manos(delta: float):
	for id in datos_jugadores.keys():
		var d = datos_jugadores[id]
		var av = d.avatar
		var plato = d.plato_nodo
		
		if not is_instance_valid(av) or not is_instance_valid(plato):
			continue
			
		if d.arruinado_cooldown > 0.0:
			d.arruinado_cooldown -= delta
			if d.arruinado_cooldown <= 0.0:
				_actualizar_visual_plato(id)
				
		if d.llevando_plato:
			plato.global_position = av.global_position + Vector2(0, -28)
			plato.z_index = av.z_index + 1

func _procesar_spawns_servidor(delta: float):
	timer_spawn_ingrediente -= delta
	if timer_spawn_ingrediente <= 0.0:
		timer_spawn_ingrediente = randf_range(2.6, 4.0) / dificultad_nivel
		_expulsar_ingrediente_servidor()
		
	timer_spawn_peligro -= delta
	if timer_spawn_peligro <= 0.0:
		timer_spawn_peligro = randf_range(3.8, 6.0) / dificultad_nivel
		_expulsar_peligro_servidor()
		
	timer_spawn_robot_limpieza -= delta
	if timer_spawn_robot_limpieza <= 0.0:
		timer_spawn_robot_limpieza = randf_range(9.0, 14.0)
		_despachar_robot_limpiador_servidor()

func _comprobar_eventos_delivery_servidor():
	if tiempo_partida >= 35.0 and not evento_tazuna_lanzado:
		evento_tazuna_lanzado = true
		if multiplayer.has_multiplayer_peer():
			despachar_evento_tazuna_rpc.rpc()
		else:
			despachar_evento_tazuna_rpc()
			
	if tiempo_partida >= 65.0 and not evento_directora_lanzado:
		evento_directora_lanzado = true
		if multiplayer.has_multiplayer_peer():
			despachar_evento_directora_rpc.rpc()
		else:
			despachar_evento_directora_rpc()

# ==============================================================================
# ROBOTS LIMPIADORES AMBIENTALES
# ==============================================================================

func _despachar_robot_limpiador_servidor():
	var izq_a_der = randf() < 0.5
	var y_pos = randf_range(350.0, 580.0)
	var origen = Vector2(110.0 if izq_a_der else 1040.0, y_pos)
	var destino = Vector2(1040.0 if izq_a_der else 110.0, randf_range(350.0, 580.0))
	var duracion = randf_range(8.0, 11.0)
	
	if multiplayer.has_multiplayer_peer():
		crear_robot_limpiador_rpc.rpc(origen, destino, duracion)
	else:
		crear_robot_limpiador_rpc(origen, destino, duracion)

@rpc("authority", "call_local", "reliable")
func crear_robot_limpiador_rpc(origen: Vector2, destino: Vector2, duracion: float):
	if not contenedor_robots: return
	
	var robot = Area2D.new()
	robot.name = "RobotLimpiador_" + str(Time.get_ticks_msec())
	robot.global_position = origen
	
	var spr = Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = tex_robot_limpiador
	spr.flip_h = (destino.x > origen.x)
	robot.add_child(spr)
	
	var col = CollisionShape2D.new()
	var cir = CircleShape2D.new()
	cir.radius = 20.0
	col.shape = cir
	robot.add_child(col)
	
	contenedor_robots.add_child(robot)
	
	var tw_bob = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw_bob.tween_property(spr, "rotation", deg_to_rad(6.0), 0.2)
	tw_bob.tween_property(spr, "rotation", deg_to_rad(-6.0), 0.2)
	
	var tw_mov = create_tween().set_trans(Tween.TRANS_LINEAR)
	tw_mov.tween_property(robot, "global_position", destino, duracion)
	
	var pasos = int(duracion / 0.12)
	for i in range(pasos):
		await get_tree().create_timer(0.12).timeout
		if not is_instance_valid(robot): return
		
		# Limpieza de charcos de crema
		if contenedor_charcos:
			for charco in contenedor_charcos.get_children():
				if is_instance_valid(charco) and not charco.is_queued_for_deletion():
					if charco.global_position.distance_to(robot.global_position) < 46.0:
						_efecto_limpieza_charco(charco.global_position)
						charco.queue_free()
						
		# Suave rebote si un jugador lo choca
		for id in datos_jugadores.keys():
			var d = datos_jugadores[id]
			var av = d.avatar
			if is_instance_valid(av) and av.global_position.distance_to(robot.global_position) < 32.0:
				var push_dir = (av.global_position - robot.global_position).normalized()
				if av.has_method("recibir_empuje"):
					av.recibir_empuje(push_dir * 70.0)
					
	await tw_mov.finished
	if is_instance_valid(robot):
		robot.queue_free()

func _efecto_limpieza_charco(pos: Vector2):
	var chispas = CPUParticles2D.new()
	chispas.global_position = pos
	chispas.emitting = true
	chispas.one_shot = true
	chispas.explosiveness = 0.9
	chispas.amount = 14
	chispas.lifetime = 0.45
	chispas.spread = 180.0
	chispas.initial_velocity_min = 25.0
	chispas.initial_velocity_max = 60.0
	chispas.color = Color(0.2, 0.95, 0.9, 0.9)
	add_child(chispas)
	get_tree().create_timer(0.6).timeout.connect(chispas.queue_free)

# ==============================================================================
# EVENTOS ESPECIALES DE REPARTO: TAZUNA (+3) Y DIRECTORA (INSTA 100%)
# ==============================================================================

@rpc("authority", "call_local", "reliable")
func despachar_evento_tazuna_rpc():
	if not contenedor_carritos: return
	
	var carrito = Node2D.new()
	carrito.name = "CarritoTazuna"
	carrito.global_position = Vector2(90, 370)
	
	var spr = AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = frames_tazuna_deliver
	spr.play("deliver")
	carrito.add_child(spr)
	
	contenedor_carritos.add_child(carrito)
	
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(carrito, "global_position", Vector2(380, 420), 1.2)
	tw.tween_property(carrito, "global_position", Vector2(576, 360), 1.0)
	
	tw.tween_callback(func():
		if not is_instance_valid(carrito): return
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			crear_ingrediente_rpc(6, Vector2(576, 380))
	)
	
	tw.tween_property(carrito, "global_position", Vector2(800, 420), 1.0)
	tw.tween_property(carrito, "global_position", Vector2(1060, 370), 1.2)
	tw.tween_callback(func():
		if is_instance_valid(carrito):
			carrito.queue_free()
	)

@rpc("authority", "call_local", "reliable")
func despachar_evento_directora_rpc():
	if not contenedor_carritos: return
	
	if directora_mesa:
		directora_mesa.visible = false
		
	var carrito = Node2D.new()
	carrito.name = "CarritoDirectora"
	carrito.global_position = Vector2(576, 175)
	
	var spr = AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = frames_akyy_deliver
	spr.play("deliver")
	carrito.add_child(spr)
	
	contenedor_carritos.add_child(carrito)
	
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(carrito, "global_position", Vector2(576, 280), 0.8)
	tw.tween_property(carrito, "global_position", Vector2(380, 460), 1.0)
	tw.tween_property(carrito, "global_position", Vector2(576, 560), 1.0)
	
	tw.tween_callback(func():
		if not is_instance_valid(carrito): return
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			crear_ingrediente_rpc(7, Vector2(576, 530))
	)
	
	tw.tween_property(carrito, "global_position", Vector2(760, 460), 1.0)
	tw.tween_property(carrito, "global_position", Vector2(576, 280), 0.9)
	tw.tween_property(carrito, "global_position", Vector2(576, 175), 0.6)
	
	tw.tween_callback(func():
		if is_instance_valid(carrito):
			carrito.queue_free()
		if is_instance_valid(directora_mesa):
			directora_mesa.visible = true
			directora_mesa.play("idle")
	)

# ==============================================================================
# SPAWN Y GESTIÓN DE INGREDIENTES
# ==============================================================================

func _expulsar_ingrediente_servidor():
	if contenedor_items.get_child_count() >= 14:
		var primero = contenedor_items.get_child(0)
		if is_instance_valid(primero): primero.queue_free()
		
	var tipo = randi_range(1, 5)
	var destino = Vector2(
		randf_range(200, 950),
		randf_range(320, 600)
	)
	
	if multiplayer.has_multiplayer_peer():
		crear_ingrediente_rpc.rpc(tipo, destino)
	else:
		crear_ingrediente_rpc(tipo, destino)

@rpc("authority", "call_local", "reliable")
func crear_ingrediente_rpc(tipo: int, destino: Vector2):
	var item = Area2D.new()
	item.name = "Item_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	item.set_meta("tipo_ingrediente", tipo)
	
	# Sin colisiones físicas para evitar recogida automática al pasar por encima
	item.collision_layer = 0
	item.collision_mask = 0
	
	var spr = Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = tex_items.get(tipo, tex_items[1])
	item.add_child(spr)
	
	var col = CollisionShape2D.new()
	var cir = CircleShape2D.new()
	cir.radius = 20.0
	col.shape = cir
	item.add_child(col)
	
	var pos_origen = maquina_central.global_position + Vector2(0, -30)
	if tipo >= 6:
		pos_origen = destino + Vector2(0, -45)
		
	item.global_position = pos_origen
	item.scale = Vector2(0.3, 0.3)
	contenedor_items.add_child(item)
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "global_position:x", destino.x, 0.75)
	tw.tween_property(item, "scale", Vector2.ONE, 0.75)
	
	var tw_y = create_tween().set_trans(Tween.TRANS_QUAD)
	tw_y.tween_property(item, "global_position:y", min(pos_origen.y, destino.y) - 65.0, 0.38).set_ease(Tween.EASE_OUT)
	tw_y.tween_property(item, "global_position:y", destino.y, 0.38).set_ease(Tween.EASE_IN)
	
	tw.chain().tween_callback(func():
		if is_instance_valid(item):
			var tw_idle = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
			tw_idle.tween_property(spr, "position:y", -4.0, 0.5)
			tw_idle.tween_property(spr, "position:y", 0.0, 0.5)
	)

@rpc("authority", "call_local", "reliable")
func eliminar_item_suelo_rpc(nombre_item: String):
	if not contenedor_items: return
	var nodo = contenedor_items.get_node_or_null(nombre_item)
	if is_instance_valid(nodo):
		nodo.queue_free()

# ==============================================================================
# SPAWN Y RESOLUCIÓN DE PELIGROS (CREMA Y CHOCOLATE)
# ==============================================================================

func _expulsar_peligro_servidor():
	var es_chocolate = (randf() < 0.35)
	var tipo_peligro = 2 if es_chocolate else 1
	
	var destino = Vector2.ZERO
	if randf() < 0.45 and not datos_jugadores.is_empty():
		var lista_platos = []
		for d in datos_jugadores.values():
			if is_instance_valid(d.plato_nodo) and not d.llevando_plato:
				lista_platos.append(d.plato_nodo.global_position)
		if not lista_platos.is_empty():
			destino = lista_platos[randi() % lista_platos.size()]
			
	if destino == Vector2.ZERO:
		destino = Vector2(randf_range(200, 950), randf_range(320, 600))
		
	if multiplayer.has_multiplayer_peer():
		lanzar_peligro_rpc.rpc(tipo_peligro, destino)
	else:
		lanzar_peligro_rpc(tipo_peligro, destino)

@rpc("authority", "call_local", "reliable")
func lanzar_peligro_rpc(tipo_peligro: int, destino: Vector2):
	var sombra = Sprite2D.new()
	sombra.texture = tex_sombra
	sombra.global_position = destino
	sombra.scale = Vector2(0.2, 0.2)
	sombra.modulate.a = 0.2
	contenedor_peligros.add_child(sombra)
	
	var duracion_aviso = 1.5 / max(1.0, dificultad_nivel * 0.8)
	var tw_sombra = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_sombra.tween_property(sombra, "scale", Vector2.ONE, duracion_aviso)
	tw_sombra.tween_property(sombra, "modulate:a", 1.0, duracion_aviso)
	
	await tw_sombra.finished
	if not is_instance_valid(sombra): return
	
	var proyectil = Sprite2D.new()
	proyectil.texture = tex_yunque_choco if tipo_peligro == 2 else tex_bomba_crema
	proyectil.global_position = destino + Vector2(0, -350)
	contenedor_peligros.add_child(proyectil)
	
	var tw_caida = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_caida.tween_property(proyectil, "global_position:y", destino.y, 0.28)
	
	await tw_caida.finished
	sombra.queue_free()
	proyectil.queue_free()
	
	_procesar_impacto_peligro(tipo_peligro, destino)

func _procesar_impacto_peligro(tipo_peligro: int, pos_impacto: Vector2):
	agitar_camara(6.0 if tipo_peligro == 2 else 4.0)
	
	if tipo_peligro == 1:
		_crear_charco_crema(pos_impacto)
		
	for id in datos_jugadores.keys():
		var d = datos_jugadores[id]
		var plato = d.plato_nodo
		if is_instance_valid(plato):
			var dist_plato = plato.global_position.distance_to(pos_impacto)
			if dist_plato < 48.0:
				_arruinar_pastel_jugador(id)
				
	for id in datos_jugadores.keys():
		var d = datos_jugadores[id]
		var av = d.avatar
		if is_instance_valid(av):
			var dist_av = av.global_position.distance_to(pos_impacto)
			if dist_av < 52.0:
				_afectar_jugador_por_peligro(id, tipo_peligro)

func _crear_charco_crema(pos: Vector2):
	var charco = Area2D.new()
	charco.name = "Charco_" + str(Time.get_ticks_msec())
	charco.global_position = pos
	
	var spr = Sprite2D.new()
	spr.texture = tex_charco_crema
	charco.add_child(spr)
	
	var col = CollisionShape2D.new()
	var cir = CircleShape2D.new()
	cir.radius = 28.0
	col.shape = cir
	charco.add_child(col)
	
	contenedor_charcos.add_child(charco)
	
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_interval(5.5)
	tw.tween_property(spr, "scale", Vector2.ZERO, 0.4)
	tw.tween_callback(charco.queue_free)

func _afectar_jugador_por_peligro(id: int, tipo_peligro: int):
	var d = datos_jugadores.get(id)
	if not d: return
	var av = d.avatar
	if not is_instance_valid(av): return
	
	if d.llevando_plato:
		d.llevando_plato = false
		d.plato_nodo.global_position = av.global_position + Vector2(randf_range(-25, 25), 10)
		_arruinar_pastel_jugador(id)
		
	if d.item_en_mano > 0:
		_soltar_item_en_manos(id)
		
	if av.has_method("aplicar_resbalon"):
		av.aplicar_resbalon(1.4)
	elif av.has_method("bloquear_controles"):
		av.bloquear_controles(true)
		av.modulate = Color(1.6, 1.4, 1.6)
		var tw = create_tween()
		tw.tween_interval(1.2)
		tw.tween_callback(func():
			if is_instance_valid(av):
				av.bloquear_controles(false)
				av.modulate = Color.WHITE
		)

func _arruinar_pastel_jugador(id: int):
	var d = datos_jugadores.get(id)
	if not d: return
	
	if d.capas > 0:
		d.capas = 0
		d.arruinado_cooldown = 1.4
		var plato = d.plato_nodo
		if is_instance_valid(plato):
			var spr = plato.get_node_or_null("SpritePastel")
			if spr:
				spr.texture = tex_arruinado
				spr.position.y = -24.0
				
			var chispas = plato.get_node_or_null("ChispasVictoria")
			if chispas: chispas.emitting = false
			
			var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_property(plato, "scale", Vector2(1.25, 0.75), 0.25)
			tw.tween_property(plato, "scale", Vector2.ONE, 0.25)

# ==============================================================================
# ENTRADA DE USUARIO Y GESTIÓN DE ACCIONES (INTERACTUAR / LANZAR)
# ==============================================================================

func _unhandled_input(event: InputEvent):
	if not partida_iniciada or partida_terminada: return
	
	var pulsado = false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("espacio"):
		pulsado = true
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		pulsado = true
	elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		pulsado = true
		
	if pulsado:
		var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		var dir_lanzamiento = _calcular_direccion_jugador(mi_id)
		solicitar_accion_jugador(mi_id, dir_lanzamiento)

func _calcular_direccion_jugador(id: int) -> Vector2:
	var d = datos_jugadores.get(id)
	if not d or not is_instance_valid(d.avatar): return Vector2.RIGHT
	var av = d.avatar
	if av.velocity.length() > 20.0:
		return av.velocity.normalized()
	if "sprite" in av and av.sprite:
		return Vector2.RIGHT if av.sprite.flip_h else Vector2.LEFT
	return Vector2.RIGHT

func solicitar_accion_jugador(id_jugador: int, dir: Vector2):
	if not multiplayer.has_multiplayer_peer():
		_ejecutar_accion_servidor(id_jugador, dir)
	elif multiplayer.is_server():
		_ejecutar_accion_servidor(id_jugador, dir)
	else:
		solicitar_interaccion_servidor_rpc.rpc_id(1, id_jugador, dir)

@rpc("any_peer", "call_remote", "reliable")
func solicitar_interaccion_servidor_rpc(id_jugador: int, dir: Vector2):
	if not multiplayer.is_server(): return
	_ejecutar_accion_servidor(id_jugador, dir)

func _ejecutar_accion_servidor(id_jugador: int, dir: Vector2):
	if not datos_jugadores.has(id_jugador) or partida_terminada: return
	var d = datos_jugadores[id_jugador]
	var av = d.avatar
	var plato = d.plato_nodo
	if not is_instance_valid(av) or not is_instance_valid(plato): return
	
	# CASO 1: Ya lleva el plato en las manos -> SOLTARLO en el suelo
	if d.llevando_plato:
		d.llevando_plato = false
		plato.global_position = av.global_position + Vector2(0, 10)
		_sincronizar_estado_jugador(id_jugador)
		return
		
	# CASO 2: Lleva un ingrediente en las manos
	if d.item_en_mano > 0:
		var dist_a_plato = av.global_position.distance_to(plato.global_position)
		# 2.A: Si está cerca de su plato y aún no tiene las 5 capas -> DEPOSITARLO
		if dist_a_plato < 58.0 and d.capas < 5:
			var item_tipo = d.item_en_mano
			if item_tipo == 6: # Especial Tazuna: suma +3 capas
				d.capas = mini(5, d.capas + 3)
			elif item_tipo == 7: # Corona Directora: completa 100% (5 capas)
				d.capas = 5
			else:
				d.capas += 1
				
			d.item_en_mano = 0
			_sincronizar_estado_jugador(id_jugador)
			return
		# 2.B: Si no está en su plato O si el pastel ya tiene las 5 capas -> LANZARLO
		else:
			var tipo = d.item_en_mano
			d.item_en_mano = 0
			_sincronizar_estado_jugador(id_jugador)
			_disparar_proyectil_ingrediente(id_jugador, tipo, av.global_position + Vector2(0, -20), dir)
			return
			
	# CASO 3: Manos vacías -> RECOGIDA MANUAL AL PULSAR ACCIÓN
	if d.item_en_mano == 0 and not d.llevando_plato:
		var dist_a_plato = av.global_position.distance_to(plato.global_position)
		
		# 3.A: Prioridad 1: Si el pastel ya está completo (5 capas), agarrar el plato con prioridad
		if d.capas >= 5 and dist_a_plato < 65.0:
			d.llevando_plato = true
			_sincronizar_estado_jugador(id_jugador)
			return
			
		# 3.B: Si está cerca de su plato -> AGARRAR EL PLATO
		if dist_a_plato < 55.0:
			d.llevando_plato = true
			_sincronizar_estado_jugador(id_jugador)
			return
			
		# 3.C: Si no está en su plato -> RECOGER MANUALMENTE EL INGREDIENTE CERCANO
		var item_cercano = _buscar_item_cercano(av.global_position, 45.0)
		if item_cercano and is_instance_valid(item_cercano):
			var tipo = item_cercano.get_meta("tipo_ingrediente", 1)
			if d.capas >= 5 and tipo <= 5:
				return
				
			d.item_en_mano = tipo
			var nombre_item = item_cercano.name
			item_cercano.queue_free()
			if multiplayer.has_multiplayer_peer():
				eliminar_item_suelo_rpc.rpc(nombre_item)
			_sincronizar_estado_jugador(id_jugador)
			return

func _sincronizar_estado_jugador(id_jugador: int):
	var d = datos_jugadores.get(id_jugador)
	if not d: return
	var pos_plato = d.plato_nodo.global_position if is_instance_valid(d.plato_nodo) else Vector2.ZERO
	if multiplayer.has_multiplayer_peer():
		sincronizar_estado_jugador_rpc.rpc(id_jugador, d.llevando_plato, d.item_en_mano, d.capas, pos_plato)
	else:
		sincronizar_estado_jugador_rpc(id_jugador, d.llevando_plato, d.item_en_mano, d.capas, pos_plato)

@rpc("authority", "call_local", "reliable")
func sincronizar_estado_jugador_rpc(id_jugador: int, llevando_plato: bool, item_en_mano: int, capas: int, pos_plato: Vector2):
	var d = datos_jugadores.get(id_jugador)
	if not d: return
	
	d.llevando_plato = llevando_plato
	d.item_en_mano = item_en_mano
	d.capas = capas
	
	if is_instance_valid(d.plato_nodo):
		if not llevando_plato and pos_plato != Vector2.ZERO:
			d.plato_nodo.global_position = pos_plato
			d.plato_nodo.z_index = 2
	
	if item_en_mano > 0:
		_mostrar_item_visual_manos(id_jugador, item_en_mano)
	else:
		_quitar_item_visual_manos(id_jugador)
		
	_actualizar_visual_plato(id_jugador)

# ==============================================================================
# LANZAMIENTO DE INGREDIENTES COMO PROYECTILES (STUN & DISRUPCIÓN)
# ==============================================================================

func _disparar_proyectil_ingrediente(id_lanzador: int, tipo: int, pos_inicio: Vector2, dir: Vector2):
	if multiplayer.has_multiplayer_peer():
		lanzar_proyectil_ingrediente_rpc.rpc(id_lanzador, tipo, pos_inicio, dir)
	else:
		lanzar_proyectil_ingrediente_rpc(id_lanzador, tipo, pos_inicio, dir)

@rpc("authority", "call_local", "reliable")
func lanzar_proyectil_ingrediente_rpc(id_lanzador: int, tipo: int, pos_inicio: Vector2, dir: Vector2):
	var proj = Area2D.new()
	proj.name = "Proyectil_" + str(Time.get_ticks_msec())
	proj.global_position = pos_inicio
	
	var spr = Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = tex_items.get(tipo, tex_items[1])
	proj.add_child(spr)
	
	var col = CollisionShape2D.new()
	var cir = CircleShape2D.new()
	cir.radius = 16.0
	col.shape = cir
	proj.add_child(col)
	
	contenedor_proyectiles.add_child(proj)
	
	var dir_norm = dir.normalized()
	if dir_norm.length() < 0.1: dir_norm = Vector2.RIGHT
	var dist_viaje = 340.0
	var pos_final = pos_inicio + dir_norm * dist_viaje
	pos_final.x = clampf(pos_final.x, 150.0, 1000.0)
	pos_final.y = clampf(pos_final.y, 250.0, 620.0)
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(proj, "global_position", pos_final, 0.52)
	tw.tween_property(spr, "rotation", TAU * 2.0 * sign(dir_norm.x), 0.52)
	
	var impactado = false
	proj.body_entered.connect(func(body):
		if not is_instance_valid(proj) or impactado: return
		for id_victima in datos_jugadores.keys():
			if id_victima == id_lanzador: continue
			var dv = datos_jugadores[id_victima]
			if dv.avatar == body:
				impactado = true
				tw.stop()
				_ejecutar_impacto_proyectil(id_victima, tipo, proj.global_position, dir_norm)
				proj.queue_free()
				return
	)
	
	await tw.finished
	if is_instance_valid(proj) and not impactado:
		proj.queue_free()
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			if multiplayer.has_multiplayer_peer():
				crear_ingrediente_rpc.rpc(tipo, pos_final)
			else:
				crear_ingrediente_rpc(tipo, pos_final)

func _ejecutar_impacto_proyectil(id_victima: int, tipo: int, pos: Vector2, dir_empuje: Vector2):
	var dv = datos_jugadores.get(id_victima)
	if not dv: return
	var av = dv.avatar
	if not is_instance_valid(av): return
	
	if av.has_method("recibir_empuje"):
		av.recibir_empuje(dir_empuje * 260.0)
	if av.has_method("aplicar_resbalon"):
		av.aplicar_resbalon(1.2)
		
	if dv.llevando_plato:
		dv.llevando_plato = false
		dv.plato_nodo.global_position = av.global_position + Vector2(dir_empuje.x * 20, 10)
		_sincronizar_estado_jugador(id_victima)
		
	if dv.item_en_mano > 0:
		dv.item_en_mano = 0
		_sincronizar_estado_jugador(id_victima)
		
	agitar_camara(4.0)
	var splash = CPUParticles2D.new()
	splash.global_position = pos
	splash.emitting = true
	splash.one_shot = true
	splash.explosiveness = 0.95
	splash.amount = 18
	splash.lifetime = 0.5
	splash.spread = 180.0
	splash.initial_velocity_min = 40.0
	splash.initial_velocity_max = 90.0
	splash.color = Color(1.0, 0.85, 0.9)
	contenedor_charcos.add_child(splash)
	get_tree().create_timer(0.6).timeout.connect(splash.queue_free)

func _buscar_item_cercano(pos: Vector2, radio: float) -> Area2D:
	var mejor_item = null
	var mejor_dist = radio
	for item in contenedor_items.get_children():
		if is_instance_valid(item):
			var d = item.global_position.distance_to(pos)
			if d < mejor_dist:
				mejor_dist = d
				mejor_item = item
	return mejor_item

func _mostrar_item_visual_manos(id: int, tipo: int):
	var d = datos_jugadores.get(id)
	if not d: return
	var av = d.avatar
	if not is_instance_valid(av): return
	
	_quitar_item_visual_manos(id)
	
	var spr_mano = Sprite2D.new()
	spr_mano.name = "ItemEnMano"
	spr_mano.texture = tex_items.get(tipo, tex_items[1])
	spr_mano.position = Vector2(0, -42)
	spr_mano.scale = Vector2(0.85, 0.85)
	spr_mano.z_index = 10
	av.add_child(spr_mano)

func _quitar_item_visual_manos(id: int):
	var d = datos_jugadores.get(id)
	if not d: return
	var av = d.avatar
	if is_instance_valid(av):
		var antiguo = av.get_node_or_null("ItemEnMano")
		if antiguo: antiguo.queue_free()

func _soltar_item_en_manos(id: int):
	var d = datos_jugadores.get(id)
	if not d or d.item_en_mano == 0: return
	_quitar_item_visual_manos(id)
	d.item_en_mano = 0
	_sincronizar_estado_jugador(id)

func _actualizar_visual_plato(id: int):
	var d = datos_jugadores.get(id)
	if not d: return
	var plato = d.plato_nodo
	if not is_instance_valid(plato): return
	
	var spr = plato.get_node_or_null("SpritePastel")
	if spr:
		var c = clamp(d.capas, 0, 5)
		spr.texture = tex_capas[c]
		# AJUSTE DE ALTURA:
		# Cuando c == 0 (plato vacío), spr.position.y = 0.0
		# Cuando c >= 1 (capas 1 a 5), la textura tiene 84px de alto y la base del plato debe subir exactamente 24px
		spr.position.y = -24.0 if c > 0 else 0.0
		
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "scale", Vector2(1.25, 1.25), 0.15)
		tw.tween_property(spr, "scale", Vector2.ONE, 0.15)
		
	var chispas = plato.get_node_or_null("ChispasVictoria")
	if chispas:
		chispas.emitting = (d.capas >= 5)

# ==============================================================================
# RESOLUCIÓN Y ENTREGA A LA MESA DE JURADOS (SINCRONIZACIÓN MULTIPLAYER)
# ==============================================================================

func _esta_en_zona_entrega(pos: Vector2) -> bool:
	return abs(pos.x - 576.0) <= 95.0 and pos.y >= 230.0 and pos.y <= 290.0

func _on_area_entrega_body_entered(body: Node2D):
	if partida_terminada: return
	for id in datos_jugadores.keys():
		var d = datos_jugadores[id]
		if d.avatar == body:
			_verificar_y_solicitar_entrega(id)
			return

func _comprobar_entregas_servidor():
	if partida_terminada: return
	for id in datos_jugadores.keys():
		var d = datos_jugadores[id]
		if d.llevando_plato and d.capas >= 5 and is_instance_valid(d.avatar):
			if _esta_en_zona_entrega(d.avatar.global_position):
				_entregar_pastel_ganador(id)
				return

func _verificar_y_solicitar_entrega(id_jugador: int):
	if partida_terminada: return
	var d = datos_jugadores.get(id_jugador)
	if not d or not d.llevando_plato or d.capas < 5: return
	
	if not multiplayer.has_multiplayer_peer():
		_entregar_pastel_ganador(id_jugador)
	elif multiplayer.is_server():
		_entregar_pastel_ganador(id_jugador)
	else:
		solicitar_entrega_al_servidor_rpc.rpc_id(1, id_jugador)

@rpc("any_peer", "call_remote", "reliable")
func solicitar_entrega_al_servidor_rpc(id_jugador: int):
	if not multiplayer.is_server() or partida_terminada: return
	var d = datos_jugadores.get(id_jugador)
	if d and d.llevando_plato and d.capas >= 5:
		_entregar_pastel_ganador(id_jugador)

func _entregar_pastel_ganador(id_ganador: int):
	if partida_terminada: return
	partida_terminada = true
	id_ganador_partida = id_ganador
	bloquear_jugadores(true)
	
	if multiplayer.has_multiplayer_peer():
		ejecutar_victoria_entrega_rpc.rpc(id_ganador)
	else:
		ejecutar_victoria_entrega_rpc(id_ganador)

@rpc("authority", "call_local", "reliable")
func ejecutar_victoria_entrega_rpc(id_ganador: int):
	partida_terminada = true
	id_ganador_partida = id_ganador
	bloquear_jugadores(true)
	
	var d = datos_jugadores.get(id_ganador)
	var pos_ganador = Vector2(576, 260)
	
	if d and is_instance_valid(d.avatar):
		var av = d.avatar
		var plato = d.plato_nodo
		d.llevando_plato = false
		
		# Limpiar carritos si estaban en pista
		if contenedor_carritos:
			for c in contenedor_carritos.get_children():
				c.queue_free()
				
		# Asegurar que la directora esté presente en su mesa celebrando
		if is_instance_valid(directora_mesa):
			directora_mesa.visible = true
			directora_mesa.play("idle")
			
		# Colocar el pastel sobre la mesa de jurados frente a la Directora
		if is_instance_valid(plato):
			plato.global_position = Vector2(576, 155)
			plato.z_index = 12
			var aro = plato.get_node_or_null("AroColor")
			if aro: aro.visible = false
			var lbl = plato.get_node_or_null("LabelP")
			if lbl: lbl.visible = false
			var tw_p = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_p.tween_property(plato, "scale", Vector2(1.3, 1.3), 0.35)
			
		# Mover al ganador sobre la base de entrega
		var tw_av = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_av.tween_property(av, "global_position", pos_ganador, 0.7)
		
	# Zoom suave de cámara hacia la mesa de jurados con la Directora y el ganador
	var tw_cam = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_cam.tween_property(camera, "position", Vector2(576, 215), 1.2)
	tw_cam.tween_property(camera, "zoom", Vector2(1.3, 1.3), 1.2)
	
	await get_tree().create_timer(1.2).timeout
	ejecutar_secuencia_victoria([id_ganador], pos_ganador)

# ==============================================================================
# INTELIGENCIA ARTIFICIAL PARA BOTS (SOLO PRUEBAS LOCALES F6, NUNCA MULTIJUGADOR)
# ==============================================================================

func _procesar_inteligencia_artificial_bots(delta: float):
	if multiplayer.has_multiplayer_peer():
		return # En partidas multijugador TODOS son humanos reales. NUNCA ejecutar IA automática.
		
	for id in datos_jugadores.keys():
		if id == 1: continue # P1 es el jugador humano local en pruebas F6
		
		var d = datos_jugadores[id]
		var av = d.avatar
		var plato = d.plato_nodo
		if not is_instance_valid(av) or not is_instance_valid(plato): continue
		
		# 1. Si el pastel está al máximo (5 capas)
		if d.capas >= 5:
			if not d.llevando_plato:
				var dir = (plato.global_position - av.global_position).normalized()
				av.velocity = dir * 140.0
				if av.global_position.distance_to(plato.global_position) < 50.0:
					_ejecutar_accion_servidor(id, dir)
			else:
				var destino_jurados = Vector2(576, 260)
				var dir = (destino_jurados - av.global_position).normalized()
				av.velocity = dir * 155.0
				if _esta_en_zona_entrega(av.global_position):
					_verificar_y_solicitar_entrega(id)
			continue
			
		# 2. Si lleva un ingrediente en mano -> Llevarlo al plato para montarlo
		if d.item_en_mano > 0:
			var dir = (plato.global_position - av.global_position).normalized()
			av.velocity = dir * 140.0
			if av.global_position.distance_to(plato.global_position) < 50.0:
				_ejecutar_accion_servidor(id, dir)
			continue
			
		# 3. Si no lleva nada -> Buscar ingrediente más cercano en el suelo
		var item_obj = _buscar_item_cercano(av.global_position, 600.0)
		if item_obj and is_instance_valid(item_obj):
			var dir = (item_obj.global_position - av.global_position).normalized()
			av.velocity = dir * 135.0
			if av.global_position.distance_to(item_obj.global_position) < 42.0:
				_ejecutar_accion_servidor(id, dir)
		else:
			av.velocity = Vector2.ZERO
