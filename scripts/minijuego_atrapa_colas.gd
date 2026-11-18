extends BaseMinijuego

enum EstadoJuego { INTRO, JUGANDO, FINALIZADO }

@onready var camera: Camera2D = $Camera2D

# HUD
@onready var hud = $HUD
@onready var label_tiempo = $HUD/MarcadorTiempo/Margen/LabelTiempo
@onready var controles_tactiles = $HUD/ControlesTactiles
@onready var btn_sprint_tactil = $HUD/ControlesTactiles/BtnSprintTactil

# Elementos del mapa
@onready var nodo_platanos = $Platanos

# Precargas de efectos y recursos
var texturas_catch = []
var tex_banana_air: Texture2D = null
var tex_banana_ground: Texture2D = null

var estado_juego: EstadoJuego = EstadoJuego.INTRO
var id_cazador: int = 1
var ids_fugitivos: Array = []
var fugitivos_atrapados: Array = []

var tiempo_restante: float = 45.0
var cooldown_sprint_total: float = 2.4
var timer_sprint_cazador: float = 0.0

var bananas_activas: Array = []
var contador_id_platano: int = 0

# Puntos de referencia sugeridos para la pista de atletismo (carriles)
const PUNTOS_PISTA = [
	Vector2(200, 160), Vector2(400, 160), Vector2(750, 160), Vector2(950, 160),
	Vector2(160, 340), Vector2(990, 340),
	Vector2(200, 520), Vector2(420, 520), Vector2(730, 520), Vector2(950, 520),
	Vector2(320, 260), Vector2(830, 260), Vector2(320, 420), Vector2(830, 420)
]

func _ready():
	modo_actual = Modo.JEFE_1V3
	Global.establecer_texto_accion_tactil("ATRAPAR")
	cargar_recursos_sprites()
	conectar_controles_tactiles()
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func cargar_recursos_sprites():
	# Cargar texturas de platanos
	var r_air = "res://assets/props_clean/item_banana_Air.png"
	if ResourceLoader.exists(r_air):
		tex_banana_air = load(r_air)
	var r_ground = "res://assets/props_clean/item_banana_ground.png"
	if ResourceLoader.exists(r_ground):
		tex_banana_ground = load(r_ground)
		
	# Cargar efectos de captura
	for i in range(1, 6):
		var ruta = "res://assets/props_clean/catch0%d.png" % i
		if ResourceLoader.exists(ruta):
			texturas_catch.append(load(ruta))

func conectar_controles_tactiles():
	if btn_sprint_tactil:
		btn_sprint_tactil.pressed.connect(_on_accion_sprint_pulsada)
		
	if controles_tactiles:
		var es_tactil = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
		controles_tactiles.visible = es_tactil

func es_servidor_o_solo() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return es_autoridad_de_partida()

func obtener_mi_id_local() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1

# ==============================================================================
# CONFIGURACION Y ASIGNACION DE ROLES (1 JEFE CAZADOR VS 3 FUGITIVOS)
# ==============================================================================

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	print("--- TEST F6 LOCAL EN PISTA DE ENTRENAMIENTO (ATRAPA COLAS) ---")
	jugadores_info = {
		1: {"nombre": "Host (Cazador)", "personaje": 0, "es_jefe": true},
		2: {"nombre": "Oguri (Fugitiva)", "personaje": 1, "es_jefe": false},
		3: {"nombre": "GoldShip (Fugitiva)", "personaje": 2, "es_jefe": false},
		4: {"nombre": "Seiun (Fugitiva)", "personaje": 3, "es_jefe": false}
	}
	
	for id in jugadores_info.keys():
		var datos = jugadores_info[id]
		if not has_node(str(id)):
			var av = preload("res://escenas/personaje_jugable.tscn").instantiate()
			av.name = str(id)
			add_child(av)
			av.configurar_visual(datos["personaje"], datos["nombre"])
			
	aplicar_roles_locales()

func aplicar_roles_locales():
	id_cazador = 1
	ids_fugitivos.clear()
	fugitivos_atrapados.clear()
	
	for id in jugadores_info.keys():
		var datos = jugadores_info[id]
		if datos.get("es_jefe", false):
			id_cazador = id
		else:
			ids_fugitivos.append(id)
			
	posicionar_avatares_iniciales()
	actualizar_hud()
	
	var mi_id = obtener_mi_id_local()
	if btn_sprint_tactil:
		btn_sprint_tactil.visible = (mi_id == id_cazador)
	
	iniciar_secuencia_cuenta_atras()

func posicionar_avatares_iniciales():
	# Cazador en el centro (Spawn 3)
	var spawn_cazador = get_node_or_null("Spawns/3")
	var av_cazador = get_node_or_null(str(id_cazador))
	if av_cazador and spawn_cazador:
		av_cazador.global_position = spawn_cazador.global_position
		av_cazador.set_movimiento_actual = PersonajeJugable.TipoMovimiento.CON_SPRINT
		av_cazador.SPEED_NORMAL = 385.0
		av_cazador.SPEED_SPRINT = 780.0
		if "label_nick" in av_cazador and av_cazador.label_nick:
			av_cazador.label_nick.modulate = Color("#ff4757")
			av_cazador.label_nick.text = obtener_nombre_jugador(id_cazador)
			
	# Fugitivos en sus respectivos spawns
	for i in range(ids_fugitivos.size()):
		var f_id = ids_fugitivos[i]
		var av_f = get_node_or_null(str(f_id))
		var spawn_f = get_node_or_null("Spawns/" + str(i))
		if av_f and spawn_f:
			av_f.global_position = spawn_f.global_position
			av_f.set_movimiento_actual = PersonajeJugable.TipoMovimiento.NORMAL_SOLO
			av_f.SPEED_NORMAL = 350.0
			av_f.SPEED_SPRINT = 720.0
			if "label_nick" in av_f and av_f.label_nick:
				av_f.label_nick.modulate = Color("#1e90ff")

func actualizar_hud():
	pass

func iniciar_juego_post_cuenta_atras():
	estado_juego = EstadoJuego.JUGANDO
	tiempo_restante = 45.0
	timer_sprint_cazador = 0.0
	
	# El servidor lanza la oleada inicial de platanos sobre la pista
	if es_servidor_o_solo():
		lanzar_oleada_inicial_platanos()

# ==============================================================================
# SISTEMA DE LANZAMIENTO DINAMICO DE PLATANOS
# ==============================================================================

func lanzar_oleada_inicial_platanos():
	var puntos = PUNTOS_PISTA.duplicate()
	puntos.shuffle()
	var cantidad = mini(6, puntos.size())
	
	for i in range(cantidad):
		var destino = puntos[i] + Vector2(randf_range(-25, 25), randf_range(-20, 20))
		var origen = Vector2(destino.x + randf_range(-60, 60), -40.0)
		contador_id_platano += 1
		var id_p = contador_id_platano
		var retardo = i * 0.12
		get_tree().create_timer(retardo).timeout.connect(func():
			if estado_juego == EstadoJuego.JUGANDO:
				if multiplayer.has_multiplayer_peer():
					lanzar_platano_rpc.rpc(id_p, origen, destino, 0.48)
				else:
					lanzar_platano_rpc(id_p, origen, destino, 0.48)
		)

func lanzar_platano_reemplazo():
	if estado_juego != EstadoJuego.JUGANDO or not es_servidor_o_solo():
		return
	var puntos = PUNTOS_PISTA.duplicate()
	puntos.shuffle()
	var destino = puntos[0] + Vector2(randf_range(-35, 35), randf_range(-25, 25))
	
	# Origen desde los laterales o tribuna superior
	var origen = Vector2.ZERO
	var lado = randi() % 3
	if lado == 0:
		origen = Vector2(destino.x, -40.0)
	elif lado == 1:
		origen = Vector2(-30.0, destino.y)
	else:
		origen = Vector2(1180.0, destino.y)
		
	contador_id_platano += 1
	var id_p = contador_id_platano
	
	if multiplayer.has_multiplayer_peer():
		lanzar_platano_rpc.rpc(id_p, origen, destino, 0.5)
	else:
		lanzar_platano_rpc(id_p, origen, destino, 0.5)

@rpc("any_peer", "call_local", "reliable")
func lanzar_platano_rpc(id_p: int, origen: Vector2, destino: Vector2, duracion: float = 0.5):
	if not nodo_platanos: return
	
	var area = Area2D.new()
	area.name = "Platano_" + str(id_p)
	area.monitoring = false
	area.monitorable = true
	area.collision_layer = 1
	area.collision_mask = 1
	area.z_index = 2
	
	# Sombra en el suelo
	var sombra = Polygon2D.new()
	sombra.name = "Sombra"
	sombra.color = Color(0, 0, 0, 0.3)
	sombra.polygon = PackedVector2Array([
		Vector2(-12, 0), Vector2(-8, -4), Vector2(0, -6),
		Vector2(8, -4), Vector2(12, 0), Vector2(8, 4),
		Vector2(0, 6), Vector2(-8, 4)
	])
	sombra.position = Vector2(0, 4)
	area.add_child(sombra)
	
	# Sprite del platano (inicia con textura en el aire)
	var spr = Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = tex_banana_air if tex_banana_air else tex_banana_ground
	spr.scale = Vector2(1.2, 1.2)
	area.add_child(spr)
	
	# Forma de colision (se activara al aterrizar)
	var col = CollisionShape2D.new()
	col.name = "Col"
	var c_shape = CircleShape2D.new()
	c_shape.radius = 16.0
	col.shape = c_shape
	area.add_child(col)
	
	nodo_platanos.add_child(area)
	bananas_activas.append(area)
	
	# Animacion de trayectoria parabolica y rotacion rapida
	area.global_position = origen
	var arc_altura = 120.0
	var tw = create_tween().set_parallel(true)
	
	# Desplazamiento horizontal y base hacia el destino
	tw.tween_property(area, "global_position", destino, duracion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Elevacion y caida del sprite relativo al nodo
	var tw_parabola = create_tween()
	tw_parabola.tween_method(func(t: float):
		if is_instance_valid(spr):
			spr.position.y = -sin(t * PI) * arc_altura
			spr.rotation = t * TAU * 2.5 # Giros veloces en el aire
	, 0.0, 1.0, duracion)
	
	# Al aterrizar en el suelo
	tw.chain().tween_callback(func():
		if not is_instance_valid(area) or not is_instance_valid(spr): return
		spr.position = Vector2.ZERO
		spr.rotation = randf_range(-0.3, 0.3)
		if tex_banana_ground:
			spr.texture = tex_banana_ground
			
		# Squash and stretch de aterrizaje
		spr.scale = Vector2(1.5, 0.8)
		var tw_pop = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_pop.tween_property(spr, "scale", Vector2(1.15, 1.15), 0.15)
		
		# Activar monitoreo de colision
		area.monitoring = true
		area.body_entered.connect(_on_platano_pisado.bind(area))
	)

func _on_platano_pisado(body: Node2D, platano: Area2D):
	if estado_juego != EstadoJuego.JUGANDO: return
	if not is_instance_valid(platano) or not platano.monitoring: return
	
	# Desactivar inmediatamente para evitar activaciones multiples
	platano.set_deferred("monitoring", false)
	
	# Aplicar el resbalon y reduccion drastica de velocidad con giro
	if body.has_method("aplicar_resbalon_rpc"):
		if multiplayer.has_multiplayer_peer():
			body.aplicar_resbalon_rpc.rpc(1.4)
		else:
			body.aplicar_resbalon_rpc(1.4)
	elif body.has_method("aplicar_aturdimiento"):
		body.aplicar_aturdimiento(1.4)
		
	# Efecto visual de desaparicion del platano
	bananas_activas.erase(platano)
	var tw = create_tween()
	tw.tween_property(platano, "scale", Vector2.ZERO, 0.12)
	tw.tween_callback(platano.queue_free)
	
	# Si es el servidor, lanzar un nuevo platano de reemplazo tras un breve cooldown
	if es_servidor_o_solo():
		get_tree().create_timer(randf_range(2.8, 4.0)).timeout.connect(lanzar_platano_reemplazo)

# ==============================================================================
# BUCLE PRINCIPAL DE JUEGO
# ==============================================================================

func _process(delta):
	if estado_juego != EstadoJuego.JUGANDO: return
	
	# 1. Cronometro en HUD
	tiempo_restante -= delta
	if label_tiempo:
		label_tiempo.text = "%ds" % max(0, int(ceil(tiempo_restante)))
		if tiempo_restante <= 10.0:
			label_tiempo.modulate = Color(1.0, 0.25, 0.25)
		else:
			label_tiempo.modulate = Color(0.18, 0.16, 0.22)
			
	# 2. Cazador Sprint Cooldown interno
	var av_cazador = get_node_or_null(str(id_cazador))
	if av_cazador:
		var sprint_listo = av_cazador.get("sprint_disponible")
		if sprint_listo == null: sprint_listo = true
		if not sprint_listo:
			timer_sprint_cazador = max(0.0, timer_sprint_cazador - delta)
			
	# 3. Comprobacion de fin de tiempo por el servidor
	if es_servidor_o_solo():
		if tiempo_restante <= 0.0:
			tiempo_restante = 0.0
			if multiplayer.has_multiplayer_peer():
				declarar_fin_juego_rpc.rpc(false) # Ganan las fugitivas por tiempo
			else:
				declarar_fin_juego_rpc(false)

func _physics_process(_delta):
	if estado_juego != EstadoJuego.JUGANDO: return
	if not es_servidor_o_solo(): return
	
	# Verificacion de captura por contacto directo del Cazador
	var av_cazador = get_node_or_null(str(id_cazador))
	if not av_cazador: return
	
	for f_id in ids_fugitivos:
		if fugitivos_atrapados.has(f_id): continue
		var av_f = get_node_or_null(str(f_id))
		if av_f:
			if av_cazador.global_position.distance_to(av_f.global_position) < 44.0:
				capturar_fugitivo(f_id)

func _unhandled_input(event: InputEvent):
	if estado_juego != EstadoJuego.JUGANDO: return
	
	var mi_id = obtener_mi_id_local()
	if mi_id == id_cazador:
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
			_on_accion_sprint_pulsada()

func _on_accion_sprint_pulsada():
	if estado_juego != EstadoJuego.JUGANDO: return
	var mi_id = obtener_mi_id_local()
	if mi_id != id_cazador: return
	
	var av_cazador = get_node_or_null(str(id_cazador))
	if not av_cazador: return
	
	var sprint_listo = av_cazador.get("sprint_disponible")
	if sprint_listo == false: return
	
	var dir = Vector2.LEFT if av_cazador.sprite.flip_h else Vector2.RIGHT
	if av_cazador.velocity.length() > 20.0:
		dir = av_cazador.velocity.normalized()
		
	timer_sprint_cazador = cooldown_sprint_total
	av_cazador.activar_sprint_rpc.rpc(dir)

func capturar_fugitivo(id_fugitivo: int):
	if fugitivos_atrapados.has(id_fugitivo): return
	
	if multiplayer.has_multiplayer_peer():
		sincronizar_captura_rpc.rpc(id_fugitivo)
	else:
		sincronizar_captura_rpc(id_fugitivo)

@rpc("any_peer", "call_local")
func sincronizar_captura_rpc(id_fugitivo: int):
	if fugitivos_atrapados.has(id_fugitivo): return
	fugitivos_atrapados.append(id_fugitivo)
	
	# Efecto visual de captura y traslado al banquillo superior
	var av = get_node_or_null(str(id_fugitivo))
	if av:
		crear_animacion_catch(av.global_position)
		if av.has_method("bloquear_controles"):
			av.bloquear_controles(true)
			if "sprite" in av and av.sprite:
				av.sprite.play(av.prefijo_personaje + "_aturdido")
				
		var idx_banquillo = fugitivos_atrapados.size() - 1
		var destino_banquillo = Vector2(470 + (idx_banquillo * 72), 44)
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(av, "global_position", destino_banquillo, 0.6)
	
	# Comprobar si todas fueron atrapadas
	if es_servidor_o_solo():
		if fugitivos_atrapados.size() >= ids_fugitivos.size():
			if multiplayer.has_multiplayer_peer():
				declarar_fin_juego_rpc.rpc(true) # Gana Cazador
			else:
				declarar_fin_juego_rpc(true)

func crear_animacion_catch(pos: Vector2):
	var nodo_catch = AnimatedSprite2D.new()
	nodo_catch.global_position = pos
	nodo_catch.z_index = 12
	var frames = SpriteFrames.new()
	frames.add_animation("pop")
	frames.set_animation_loop("pop", false)
	frames.set_animation_speed("pop", 14.0)
	for tex in texturas_catch:
		frames.add_frame("pop", tex)
	nodo_catch.sprite_frames = frames
	add_child(nodo_catch)
	nodo_catch.play("pop")
	nodo_catch.animation_finished.connect(nodo_catch.queue_free)

# ==============================================================================
# FINALIZACION Y SECUENCIA DE VICTORIA
# ==============================================================================

@rpc("any_peer", "call_local")
func declarar_fin_juego_rpc(cazador_gana: bool):
	if estado_juego == EstadoJuego.FINALIZADO: return
	estado_juego = EstadoJuego.FINALIZADO
	
	bloquear_jugadores(true)
	
	if cazador_gana:
		ejecutar_secuencia_victoria([id_cazador], Vector2(576, 330))
	else:
		var ganadores = []
		for f_id in ids_fugitivos:
			if not fugitivos_atrapados.has(f_id):
				ganadores.append(f_id)
		if ganadores.size() == 0:
			ganadores = ids_fugitivos.duplicate()
		ejecutar_secuencia_victoria(ganadores, Vector2(576, 330))
