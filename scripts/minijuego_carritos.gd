extends BaseMinijuego

@onready var contenedor_obstaculos = $ContenedorObstaculos
@onready var linea_meta = $LineaMeta
@onready var hud = $HUD
@onready var label_posicion = $HUD/PanelInfo/VBox/LabelPosicion
@onready var label_reloj = $HUD/PanelInfo/VBox/LabelReloj
@onready var camera = $Camera2D

var partida_iniciada: bool = false
var partida_terminada: bool = false
var tiempo_restante: float = 40.0

var progreso_jugadores: Dictionary = {} # {id: float (pos_x)}
var velocidades_carritos: Dictionary = {} # {id: Vector2}
var carritos_visuales: Dictionary = {} # {id: Node2D}
var avatares_jugadores: Dictionary = {} # {id: CharacterBody2D}
var ultimo_lider_id: int = -999

const META_X = 2200.0
const PISTA_MIN_Y = 220.0
const PISTA_MAX_Y = 560.0

func _ready():
	get_tree().change_scene_to_file("res://escenas/minijuego_snowboard.tscn")
	return
	modo_actual = Modo.FFA
	Global.establecer_texto_accion_tactil("TURBO")
	partida_iniciada = false
	partida_terminada = false
	tiempo_restante = 40.0
	
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
	progreso_jugadores.clear()
	velocidades_carritos.clear()
	avatares_jugadores.clear()
	
	var y_offsets = [260.0, 350.0, 440.0, 530.0]
	var i = 0
	for id in jugadores_info.keys():
		var av = get_node_or_null(str(id))
		if not av and get_tree().root:
			av = get_tree().root.find_child(str(id), true, false)
			
		var spawn_y = y_offsets[i % y_offsets.size()]
		if av:
			avatares_jugadores[id] = av
			av.global_position = Vector2(180.0, spawn_y)
			av.bloquear_controles(true)
			av.modulate = Color.WHITE
			av.scale = Vector2.ONE
			av.visible = true
			if "set_movimiento_actual" in av:
				av.set_movimiento_actual = PersonajeJugable.TipoMovimiento.NORMAL_SOLO
				
			# Añadir sprite de carrito de supermercado bajo el avatar
			crear_carrito_para_avatar(av, id)
			
		progreso_jugadores[id] = 180.0
		velocidades_carritos[id] = Vector2.ZERO
		i += 1
		
	iniciar_secuencia_cuenta_atras()

func crear_carrito_para_avatar(av: CharacterBody2D, id: int):
	var carrito = Node2D.new()
	carrito.name = "CarritoVisual"
	
	# Polígono estilizado del carrito de compras metálico
	var cuerpo = Polygon2D.new()
	cuerpo.color = Color(0.8, 0.85, 0.9, 0.9)
	cuerpo.polygon = PackedVector2Array([
		Vector2(-20, 10), Vector2(25, 10), Vector2(30, -10), Vector2(-15, -10)
	])
	carrito.add_child(cuerpo)
	
	# Borde rojo/azul de manija
	var manija = Line2D.new()
	manija.width = 3.0
	manija.default_color = Color(0.9, 0.2, 0.2)
	manija.points = PackedVector2Array([Vector2(-15, -10), Vector2(-22, -22)])
	carrito.add_child(manija)
	
	# Ruedas
	for rx in [-12.0, 18.0]:
		var rueda = Polygon2D.new()
		rueda.color = Color(0.2, 0.2, 0.25)
		rueda.polygon = PackedVector2Array([
			Vector2(rx - 4, 10), Vector2(rx + 4, 10), Vector2(rx + 4, 18), Vector2(rx - 4, 18)
		])
		carrito.add_child(rueda)
		
	av.add_child(carrito)
	carrito.position = Vector2(0, 8)
	carritos_visuales[id] = carrito

func iniciar_juego_post_cuenta_atras():
	partida_iniciada = true
	bloquear_jugadores(false)
	
	# En el servidor o local, generar obstáculos a lo largo del pasillo
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		generar_obstaculos_pista()

func generar_obstaculos_pista():
	# Cajas de cereal, cáscaras de plátano y latas en el pasillo
	var tipos_props = [
		"res://assets/props_clean/item_banana_ground.png",
		"res://assets/props_clean/item_omoball00.png",
		"res://assets/props_clean/item_pie.png"
	]
	
	for x in range(350, int(META_X - 100), 160):
		var cant = randi_range(1, 2)
		for c in range(cant):
			var pos = Vector2(x + randf_range(-30, 30), randf_range(PISTA_MIN_Y + 20, PISTA_MAX_Y - 20))
			var tipo = randi() % tipos_props.size()
			if multiplayer.has_multiplayer_peer():
				spawn_obstaculo_carritos_rpc.rpc(pos, tipo)
			else:
				spawn_obstaculo_carritos_rpc(pos, tipo)

@rpc("authority", "call_local", "reliable")
func spawn_obstaculo_carritos_rpc(pos: Vector2, tipo: int):
	var area = Area2D.new()
	area.position = pos
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	col.shape = shape
	area.add_child(col)
	
	var spr = Sprite2D.new()
	var texs = [
		"res://assets/props_clean/item_banana_ground.png",
		"res://assets/props_clean/item_omoball00.png",
		"res://assets/props_clean/item_pie.png"
	]
	spr.texture = load(texs[tipo])
	spr.scale = Vector2(1.3, 1.3)
	area.add_child(spr)
	
	contenedor_obstaculos.add_child(area)
	area.body_entered.connect(func(body):
		if body is CharacterBody2D and body.is_in_group("Jugador"):
			var tw = create_tween()
			tw.tween_property(spr, "scale", Vector2.ZERO, 0.1)
			tw.tween_callback(area.queue_free)
			if body.has_method("aplicar_resbalon_rpc"):
				body.aplicar_resbalon_rpc(1.2)
	)

func _physics_process(delta):
	if not partida_iniciada or partida_terminada: return
	
	tiempo_restante -= delta
	if label_reloj:
		label_reloj.text = "%02d:%02d" % [max(0, int(tiempo_restante) / 60), max(0, int(tiempo_restante) % 60)]
		
	# Actualizar progreso y verificar meta
	var id_lider = -1
	var mayor_x = -9999.0
	
	for id in jugadores_info.keys():
		var av = avatares_jugadores.get(id)
		if not av or not is_instance_valid(av):
			av = get_node_or_null(str(id))
			if av: avatares_jugadores[id] = av
			
		if av:
			# Impulso constante hacia adelante tipo carrito de compras
			var es_mi_avatar = av.is_multiplayer_authority() if multiplayer.has_multiplayer_peer() else true
			if es_mi_avatar:
				if Input.is_action_pressed("ui_accept"):
					av.velocity.x = min(av.velocity.x + 350.0 * delta, 520.0)
				else:
					av.velocity.x = min(av.velocity.x + 180.0 * delta, 320.0)
					
				# Clampear en los pasillos de supermercado
				av.global_position.y = clamp(av.global_position.y, PISTA_MIN_Y, PISTA_MAX_Y)
				
			progreso_jugadores[id] = av.global_position.x
			if av.global_position.x > mayor_x:
				mayor_x = av.global_position.x
				id_lider = id
				
			# ¿Cruzó la meta?
			if av.global_position.x >= META_X and not partida_terminada:
				declarar_ganador(id)
				return
				
	# Centrar cámara en el líder o en el jugador local
	if camera:
		var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		var mi_av = avatares_jugadores.get(mi_id)
		if mi_av and is_instance_valid(mi_av):
			camera.position.x = clamp(mi_av.global_position.x + 150.0, 576.0, META_X)
			
	if label_posicion and id_lider != -1 and id_lider != ultimo_lider_id:
		ultimo_lider_id = id_lider
		label_posicion.text = "LÍDER: " + obtener_nombre_jugador(id_lider)
		
	if tiempo_restante <= 0.0 and not partida_terminada:
		declarar_ganador(id_lider if id_lider != -1 else 1)

func declarar_ganador(id_ganador: int):
	if partida_terminada: return
	partida_terminada = true
	
	if multiplayer.has_multiplayer_peer():
		declarar_victoria_rpc.rpc(id_ganador)
	else:
		declarar_victoria_rpc(id_ganador)

@rpc("authority", "call_local", "reliable")
func declarar_victoria_rpc(id_ganador: int):
	partida_terminada = true
	bloquear_jugadores(true)
	
	var av_ganador = avatares_jugadores.get(id_ganador)
	if not av_ganador or not is_instance_valid(av_ganador):
		av_ganador = obtener_avatar_jugador(id_ganador)
	var pos_vic = av_ganador.global_position if av_ganador else Vector2(576, 380)
	ejecutar_secuencia_victoria([id_ganador], pos_vic)
