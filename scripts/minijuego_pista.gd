extends BaseMinijuego

@onready var contenedor_sombras = $ContenedorSombras
@onready var contenedor_obstaculos = $ContenedorObstaculos
@onready var contenedor_barrera = $ContenedorBarrera
@onready var camera = $Camera2D

# Marcador y HUD central estilo polideportivo
@onready var marcador_reloj = $HUD/MarcadorCentral/Margen/VBox/LabelReloj
@onready var hud_equipo_0 = $HUD/PanelEquipo0
@onready var hud_equipo_1 = $HUD/PanelEquipo1
@onready var label_integrantes_0 = $HUD/PanelEquipo0/Margen/VBox/LabelIntegrantes
@onready var label_integrantes_1 = $HUD/PanelEquipo1/Margen/VBox/LabelIntegrantes
@onready var label_modo_test = $HUD/LabelModoTest

var escena_caida = preload("res://escenas/obstaculo_caida.tscn")
var escena_balon = preload("res://escenas/proyectil_balon.tscn")
var escena_barrera = preload("res://escenas/barrera_divisoria.tscn")
var escena_directora = preload("res://escenas/directora_canon_pista.tscn")

var partida_iniciada: bool = false
var partida_terminada: bool = false
var tiempo_partida: float = 0.0
var fase_actual: int = 1
var es_modo_f6: bool = false

var nodo_directora: Node2D = null

# Temporizadores de generación de obstáculos
var timer_balones: float = 1.8
var timer_caida: float = 4.0
var timer_barrera: float = 12.0
var timer_directora: float = 7.0
var timer_platanos: float = 4.0

# Sistema de trampas estáticas de plátanos
var bananas_activas: Array = []
var tex_banana_air: Texture2D = null
var tex_banana_ground: Texture2D = null

var jugadores_por_equipo: Dictionary = { 0: [], 1: [] }
var jugadores_vivos_por_equipo: Dictionary = { 0: [], 1: [] }
var jugadores_invulnerables: Dictionary = {}

# Límites de la cancha de madera (área útil de juego)
const CAMPO_MIN_X = 165.0
const CAMPO_MAX_X = 988.0
const CAMPO_MIN_Y = 245.0
const CAMPO_MAX_Y = 575.0

func _ready():
	modo_actual = Modo.EQUIPOS_2V2
	Global.establecer_texto_accion_tactil("ACELERAR")
	tiempo_partida = 0.0
	fase_actual = 1
	partida_iniciada = false
	partida_terminada = false
	es_modo_f6 = not get_tree().root.has_node("Lobby")
	
	if label_modo_test:
		label_modo_test.visible = es_modo_f6

	# Ocultar indicador fijo de fase en HUD: el aviso lo da la Directora Akikawa de forma diegética
	var panel_ronda = get_node_or_null("HUD/MarcadorCentral/Margen/VBox/PanelRonda")
	if panel_ronda:
		panel_ronda.visible = false

	cargar_texturas_platanos()

	# Instanciar a la Directora con su máquina de cañones
	nodo_directora = escena_directora.instantiate()
	nodo_directora.visible = false
	add_child(nodo_directora)
	nodo_directora.disparo_efectuado.connect(_on_directora_disparo)
		
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	
	var mi_id = 1
	var ids_test = [mi_id, 2, 3, 4]
	
	jugadores_info.clear()
	for i in range(ids_test.size()):
		var id = ids_test[i]
		var equipo = 0 if i < 2 else 1
		jugadores_info[id] = {"equipo": equipo, "spawn": i, "es_jefe": false}
		
		if not has_node(str(id)):
			var av = preload("res://escenas/personaje_jugable.tscn").instantiate()
			av.name = str(id)
			add_child(av)
			av.configurar_visual(i % 4, "P" + str(i + 1))
			
	aplicar_roles_locales()

func aplicar_roles_locales():
	jugadores_por_equipo[0].clear()
	jugadores_por_equipo[1].clear()
	jugadores_vivos_por_equipo[0].clear()
	jugadores_vivos_por_equipo[1].clear()
	jugadores_invulnerables.clear()
	
	var spawns = [
		Vector2(290, 330), # E0 - Jugador 1
		Vector2(290, 480), # E0 - Jugador 2
		Vector2(862, 330), # E1 - Jugador 3
		Vector2(862, 480)  # E1 - Jugador 4
	]
	
	for id in jugadores_info.keys():
		var datos = jugadores_info[id]
		var equipo = datos.get("equipo", 0)
		var spawn_idx = datos.get("spawn", 0)
		
		jugadores_por_equipo[equipo].append(id)
		jugadores_vivos_por_equipo[equipo].append(id)
		
		var avatar = get_node_or_null(str(id))
		if avatar:
			avatar.scale = Vector2(1.0, 1.0)
			avatar.modulate = Color(1, 1, 1, 1)
			
			var punto_spawn = get_node_or_null("Spawns/" + str(spawn_idx))
			if punto_spawn:
				avatar.global_position = punto_spawn.global_position
			elif spawn_idx < spawns.size():
				avatar.global_position = spawns[spawn_idx]
				
			avatar.set_movimiento_actual = PersonajeJugable.TipoMovimiento.CON_SPRINT
			avatar.bloquear_controles(true)
			avatar.set_physics_process(true)
			
			var col_equipo = Color("#ff4757") if equipo == 0 else Color("#1e90ff")
			if "label_nick" in avatar and avatar.label_nick:
				avatar.label_nick.modulate = col_equipo
				
	actualizar_hud_equipos()
	iniciar_secuencia_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	partida_iniciada = true
	tiempo_partida = 0.0
	fase_actual = 1
	bloquear_jugadores(false)
	actualizar_marcador_reloj()

func _process(delta):
	if not partida_iniciada: return
	if partida_terminada and not es_modo_f6: return
	
	tiempo_partida += delta
	actualizar_marcador_reloj()
	
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad:
		# Escalación exponencial en 4 fases progresivas
		var umbral_fase_2 = 12.0 if es_modo_f6 else 20.0
		var umbral_fase_3 = 25.0 if es_modo_f6 else 45.0
		var umbral_fase_4 = 40.0 if es_modo_f6 else 70.0
		
		if tiempo_partida >= umbral_fase_4 and fase_actual < 4:
			if multiplayer.has_multiplayer_peer():
				cambiar_fase_rpc.rpc(4)
			else:
				cambiar_fase_rpc(4)
		elif tiempo_partida >= umbral_fase_3 and fase_actual < 3:
			if multiplayer.has_multiplayer_peer():
				cambiar_fase_rpc.rpc(3)
			else:
				cambiar_fase_rpc(3)
		elif tiempo_partida >= umbral_fase_2 and fase_actual < 2:
			if multiplayer.has_multiplayer_peer():
				cambiar_fase_rpc.rpc(2)
			else:
				cambiar_fase_rpc(2)
			
		# --- BALONES Y OBSTÁCULOS DE MOVIMIENTO CRUZADO (FASE 1+) ---
		timer_balones -= delta
		if timer_balones <= 0.0:
			lanzar_proyectil_balon()
			match fase_actual:
				1: timer_balones = randf_range(1.3, 1.9)
				2: timer_balones = randf_range(0.85, 1.3)
				3: timer_balones = randf_range(0.55, 0.85)
				4: timer_balones = randf_range(0.35, 0.6) # Ráfaga continua en muerte súbita
				
		# --- TRAMPAS ESTÁTICAS DE PLÁTANO EN EL SUELO (FASE 1+) ---
		timer_platanos -= delta
		if timer_platanos <= 0.0:
			lanzar_platano_suelo()
			match fase_actual:
				1: timer_platanos = randf_range(5.0, 7.5)
				2: timer_platanos = randf_range(3.5, 5.5)
				3: timer_platanos = randf_range(2.5, 4.0)
				4: timer_platanos = randf_range(1.8, 3.0)

		# --- OBJETOS CAYENDO: PIANOS, PESAS DE 1000t, BARRILES (FASE 2+) ---
		if fase_actual >= 2:
			timer_caida -= delta
			if timer_caida <= 0.0:
				lanzar_oleada_caida()
				match fase_actual:
					2: timer_caida = randf_range(1.8, 2.5)
					3: timer_caida = randf_range(1.1, 1.5)
					4: timer_caida = randf_range(0.75, 1.1) # Lluvia constante de pianos/pesas
					
		# --- ATAQUES DE PRECISIÓN DE LA DIRECTORA EN SU CAÑÓN (FASE 1+) ---
		timer_directora -= delta
		if timer_directora <= 0.0:
			lanzar_ataque_directora()
			match fase_actual:
				1: timer_directora = randf_range(10.0, 13.0)
				2: timer_directora = randf_range(7.0, 9.5)
				3: timer_directora = randf_range(5.0, 7.0)
				4: timer_directora = randf_range(3.2, 4.5)
				
		# --- LIMITACIÓN DINÁMICA DEL MAPA (BARRERAS Y CUADRANTES) (FASE 2+) ---
		if fase_actual >= 2:
			timer_barrera -= delta
			if timer_barrera <= 0.0:
				lanzar_barrera_divisoria()
				match fase_actual:
					2: timer_barrera = randf_range(14.0, 18.0)
					3: timer_barrera = randf_range(9.0, 12.0)
					4: timer_barrera = randf_range(6.5, 9.0)

@rpc("any_peer", "call_local", "reliable")
func cambiar_fase_rpc(nueva_fase: int):
	fase_actual = nueva_fase
	if marcador_reloj:
		if fase_actual == 4:
			marcador_reloj.modulate = Color(1.0, 0.35, 0.35, 1.0)
		elif fase_actual == 3:
			marcador_reloj.modulate = Color(1.0, 0.7, 0.3, 1.0)
		elif fase_actual == 2:
			marcador_reloj.modulate = Color(1.0, 0.9, 0.4, 1.0)
			
	if nodo_directora and is_instance_valid(nodo_directora) and nodo_directora.has_method("anunciar_fase"):
		nodo_directora.anunciar_fase(fase_actual)

func actualizar_marcador_reloj():
	if not marcador_reloj: return
	var total_seg = int(tiempo_partida)
	var mins = total_seg / 60
	var segs = total_seg % 60
	marcador_reloj.text = "%02d:%02d" % [mins, segs]

# --- CARGA Y SPAWN DE PLÁTANOS ESTÁTICOS ---

func cargar_texturas_platanos():
	var r_air = "res://assets/props_clean/item_banana_Air.png"
	if ResourceLoader.exists(r_air):
		tex_banana_air = load(r_air)
	var r_ground = "res://assets/props_clean/item_banana_ground.png"
	if ResourceLoader.exists(r_ground):
		tex_banana_ground = load(r_ground)

func lanzar_platano_suelo():
	if bananas_activas.size() >= 5: return
	var dest = Vector2(
		randf_range(CAMPO_MIN_X + 60.0, CAMPO_MAX_X - 60.0),
		randf_range(CAMPO_MIN_Y + 45.0, CAMPO_MAX_Y - 45.0)
	)
	var origen = Vector2(dest.x + randf_range(-40.0, 40.0), CAMPO_MIN_Y - 70.0)
	if multiplayer.has_multiplayer_peer():
		spawn_platano_suelo_rpc.rpc(origen, dest)
	else:
		spawn_platano_suelo_rpc(origen, dest)

@rpc("any_peer", "call_local", "reliable")
func spawn_platano_suelo_rpc(origen: Vector2, destino: Vector2):
	var area = Area2D.new()
	area.name = "PlatanoPista_" + str(Time.get_ticks_usec())
	area.monitoring = false
	
	var spr = Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = tex_banana_air if tex_banana_air else tex_banana_ground
	spr.scale = Vector2(1.2, 1.2)
	area.add_child(spr)
	
	var col = CollisionShape2D.new()
	col.name = "Col"
	var c_shape = CircleShape2D.new()
	c_shape.radius = 16.0
	col.shape = c_shape
	area.add_child(col)
	
	contenedor_obstaculos.add_child(area)
	bananas_activas.append(area)
	
	area.global_position = origen
	var duracion = 0.9
	var arc_altura = 110.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(area, "global_position", destino, duracion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var tw_parabola = create_tween()
	tw_parabola.tween_method(func(t: float):
		if is_instance_valid(spr):
			spr.position.y = -sin(t * PI) * arc_altura
			spr.rotation = t * TAU * 2.5
	, 0.0, 1.0, duracion)
	
	tw.chain().tween_callback(func():
		if not is_instance_valid(area) or not is_instance_valid(spr): return
		spr.position = Vector2.ZERO
		spr.rotation = randf_range(-0.3, 0.3)
		if tex_banana_ground:
			spr.texture = tex_banana_ground
		spr.scale = Vector2(1.4, 0.8)
		var tw_pop = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_pop.tween_property(spr, "scale", Vector2(1.15, 1.15), 0.15)
		
		area.monitoring = true
		area.body_entered.connect(_on_platano_pisado.bind(area))
	)

func _on_platano_pisado(body: Node2D, platano: Area2D):
	if partida_terminada and not es_modo_f6: return
	if not is_instance_valid(platano) or not platano.monitoring: return
	if not body.is_in_group("Jugador"): return
	
	platano.set_deferred("monitoring", false)
	bananas_activas.erase(platano)
	
	if body.has_method("aplicar_resbalon_rpc"):
		if multiplayer.has_multiplayer_peer():
			body.aplicar_resbalon_rpc.rpc(1.4)
		else:
			body.aplicar_resbalon_rpc(1.4)
			
	var tw = create_tween()
	tw.tween_property(platano, "scale", Vector2.ZERO, 0.12)
	tw.tween_callback(platano.queue_free)

# --- GENERACIÓN DE PROYECTILES Y BALONES CRUZADOS ---

func lanzar_proyectil_balon():
	# Procedencia aleatoria: 0: Izquierda, 1: Derecha, 2: Arriba (desde las gradas)
	var origen = randi() % 3
	var pos_inicio = Vector2.ZERO
	var dir = Vector2.ZERO
	
	var vel = randf_range(350.0, 440.0)
	if fase_actual == 2: vel = randf_range(390.0, 480.0)
	elif fase_actual == 3: vel = randf_range(440.0, 530.0)
	elif fase_actual == 4: vel = randf_range(490.0, 600.0)
	
	# Tipos de balones e ítems limpios oficiales (0: Baloncesto, 1: Chance, 2: Dodgeball, 3: Freeze, 4: Pesa hierro, 5: Pastel)
	var tipo_balon = randi() % 6
	
	match origen:
		0: # Izquierda -> hacia la derecha
			pos_inicio = Vector2(CAMPO_MIN_X - 45.0, randf_range(CAMPO_MIN_Y + 20, CAMPO_MAX_Y - 20))
			dir = Vector2(1.0, randf_range(-0.25, 0.25)).normalized()
		1: # Derecha -> hacia la izquierda
			pos_inicio = Vector2(CAMPO_MAX_X + 45.0, randf_range(CAMPO_MIN_Y + 20, CAMPO_MAX_Y - 20))
			dir = Vector2(-1.0, randf_range(-0.25, 0.25)).normalized()
		2: # Arriba -> hacia abajo
			pos_inicio = Vector2(randf_range(CAMPO_MIN_X + 30, CAMPO_MAX_X - 30), CAMPO_MIN_Y - 40.0)
			dir = Vector2(randf_range(-0.35, 0.35), 1.0).normalized()
			
	if multiplayer.has_multiplayer_peer():
		rpc("spawn_balon_rpc", pos_inicio, dir, vel, tipo_balon)
	else:
		spawn_balon_rpc(pos_inicio, dir, vel, tipo_balon)

@rpc("any_peer", "call_local", "reliable")
func spawn_balon_rpc(pos_inicio: Vector2, dir: Vector2, vel: float, tipo_balon: int):
	var balon = escena_balon.instantiate()
	contenedor_obstaculos.add_child(balon)
	balon.configurar(pos_inicio, dir, vel, tipo_balon)
	balon.impacto_jugador.connect(_on_jugador_alcanzado)

# --- GENERACIÓN DE OBJETOS QUE CAEN (PIANOS, PESAS 1000t, BARRILES) ---

func lanzar_oleada_caida():
	var cantidad = 1
	var aviso = 1.35
	
	match fase_actual:
		2:
			cantidad = randi_range(1, 2)
			aviso = randf_range(1.15, 1.35)
		3:
			cantidad = randi_range(2, 3)
			aviso = randf_range(0.85, 1.05)
		4: # MUERTE SÚBITA: Lluvia masiva de 3 a 4 objetos simultáneos
			cantidad = randi_range(3, 4)
			aviso = randf_range(0.68, 0.82)
			
	for i in range(cantidad):
		var pos = Vector2(
			randf_range(CAMPO_MIN_X + 45, CAMPO_MAX_X - 45),
			randf_range(CAMPO_MIN_Y + 35, CAMPO_MAX_Y - 35)
		)
		var tipo_idx = randi() % 4 # 0: PIANO, 1: PESA, 2: BARRIL, 3: VALLA
		if multiplayer.has_multiplayer_peer():
			rpc("spawn_caida_rpc", tipo_idx, pos, aviso)
		else:
			spawn_caida_rpc(tipo_idx, pos, aviso)

@rpc("any_peer", "call_local", "reliable")
func spawn_caida_rpc(tipo_idx: int, pos: Vector2, aviso: float):
	var obj = escena_caida.instantiate()
	contenedor_obstaculos.add_child(obj)
	obj.configurar(tipo_idx, pos, aviso)
	obj.aplasto_jugador.connect(_on_jugador_alcanzado)

# --- ATAQUES DE CAÑÓN DE LA DIRECTORA AKIKAWA ---

func lanzar_ataque_directora():
	# Buscar un jugador vivo aleatorio al que apuntar
	var vivos = []
	for eq in [0, 1]:
		for id in jugadores_vivos_por_equipo[eq]:
			var av = get_node_or_null(str(id))
			if av and is_instance_valid(av) and not jugadores_invulnerables.get(id, false):
				vivos.append(id)
				
	if vivos.is_empty(): return
	var id_target = vivos[randi() % vivos.size()]
	
	# Puntos perimetrales donde aparece con su máquina
	var puntos_spawn = [
		Vector2(320, 185), # Grada superior izquierda
		Vector2(576, 185), # Grada superior centro
		Vector2(832, 185), # Grada superior derecha
		Vector2(95, 330),  # Lateral izquierdo alto
		Vector2(95, 480),  # Lateral izquierdo bajo
		Vector2(1055, 330),# Lateral derecho alto
		Vector2(1055, 480),# Lateral derecho bajo
		Vector2(400, 615), # Barandilla inferior izquierda
		Vector2(750, 615)  # Barandilla inferior derecha
	]
	var pos_spawn = puntos_spawn[randi() % puntos_spawn.size()]
	var vel_disparo = 680.0 if fase_actual < 4 else 780.0
	
	if multiplayer.has_multiplayer_peer():
		rpc("ejecutar_ataque_directora_rpc", pos_spawn, id_target, vel_disparo)
	else:
		ejecutar_ataque_directora_rpc(pos_spawn, id_target, vel_disparo)

@rpc("any_peer", "call_local", "reliable")
func ejecutar_ataque_directora_rpc(pos_spawn: Vector2, id_target: int, vel_disparo: float):
	if not nodo_directora: return
	var av_target = get_node_or_null(str(id_target))
	nodo_directora.aparecer_y_disparar(pos_spawn, av_target, vel_disparo)

func _on_directora_disparo(pos_origen: Vector2, dir: Vector2, vel: float):
	# Instanciar el proyectil especial de cañón de la Directora (tipo 99)
	var balon = escena_balon.instantiate()
	contenedor_obstaculos.add_child(balon)
	balon.configurar(pos_origen, dir, vel, 99)
	balon.impacto_jugador.connect(_on_jugador_alcanzado)

# --- RESTRICCIÓN DINÁMICA DEL MAPA (BARRERAS Y CONFINAMIENTO) ---

func lanzar_barrera_divisoria():
	var duracion = 8.0 if fase_actual < 4 else 6.5
	
	if fase_actual == 2:
		# Fase 2: Barrera vertical clásica en el centro (divide en 2 mitades)
		if multiplayer.has_multiplayer_peer():
			rpc("spawn_barrera_rpc", Vector2(576, 410), duracion, false, 350.0)
		else:
			spawn_barrera_rpc(Vector2(576, 410), duracion, false, 350.0)
	else:
		# Fase 3 y 4: Patrones avanzados de confinamiento
		var patron = randi() % 3
		match patron:
			0: # CRUZ: Divide la cancha completa en 4 cuadrantes aislados
				if multiplayer.has_multiplayer_peer():
					rpc("spawn_barrera_rpc", Vector2(576, 410), duracion, false, 350.0)
					rpc("spawn_barrera_rpc", Vector2(576, 410), duracion, true, 830.0)
				else:
					spawn_barrera_rpc(Vector2(576, 410), duracion, false, 350.0)
					spawn_barrera_rpc(Vector2(576, 410), duracion, true, 830.0)
			1: # HORIZONTAL: Divide la cancha longitudinalmente en superior e inferior
				if multiplayer.has_multiplayer_peer():
					rpc("spawn_barrera_rpc", Vector2(576, 410), duracion, true, 830.0)
				else:
					spawn_barrera_rpc(Vector2(576, 410), duracion, true, 830.0)
			2: # DOBLE VERTICAL: Divide la cancha en 3 carriles angostos
				if multiplayer.has_multiplayer_peer():
					rpc("spawn_barrera_rpc", Vector2(380, 410), duracion, false, 350.0)
					rpc("spawn_barrera_rpc", Vector2(772, 410), duracion, false, 350.0)
				else:
					spawn_barrera_rpc(Vector2(380, 410), duracion, false, 350.0)
					spawn_barrera_rpc(Vector2(772, 410), duracion, false, 350.0)

@rpc("any_peer", "call_local", "reliable")
func spawn_barrera_rpc(pos: Vector2, duracion: float, es_horizontal: bool = false, longitud: float = 350.0):
	# Evitar sobrecargar si hay demasiadas barreras en pantalla simultáneas
	if contenedor_barrera.get_child_count() >= 3: return
	
	var barrera = escena_barrera.instantiate()
	barrera.global_position = pos
	barrera.configurar(duracion, es_horizontal, longitud)
	contenedor_barrera.add_child(barrera)

# --- IMPACTO Y SISTEMA DE ELIMINACIÓN / PRUEBAS F6 ---

func _on_jugador_alcanzado(id_jugador: int):
	if partida_terminada and not es_modo_f6: return
	if jugadores_invulnerables.get(id_jugador, false): return
	
	if multiplayer.has_multiplayer_peer():
		if es_autoridad_de_partida():
			procesar_impacto_jugador_rpc.rpc(id_jugador)
		else:
			# Si soy el cliente local que recibió el impacto en mi pantalla, lo reporto al servidor
			if id_jugador == multiplayer.get_unique_id():
				reportar_impacto_al_servidor_rpc.rpc(id_jugador)
	else:
		procesar_impacto_jugador_rpc(id_jugador)

@rpc("any_peer", "call_local", "reliable")
func reportar_impacto_al_servidor_rpc(id_jugador: int):
	if not es_autoridad_de_partida(): return
	var remitente = multiplayer.get_remote_sender_id()
	if remitente != 0 and remitente != id_jugador: return
	if jugadores_invulnerables.get(id_jugador, false): return
	procesar_impacto_jugador_rpc.rpc(id_jugador)

@rpc("any_peer", "call_local", "reliable")
func procesar_impacto_jugador_rpc(id_jugador: int):
	var avatar = get_node_or_null(str(id_jugador))
	if not avatar: return
	
	# ENTORNO DE PRUEBAS F6 CONTINUO: El juego no termina; los avatares reaccionan y siguen en la cancha
	if es_modo_f6:
		jugadores_invulnerables[id_jugador] = true
		
		# Animación de squash & stretch / golpe
		var tween = create_tween()
		tween.tween_property(avatar, "scale", Vector2(1.35, 0.65), 0.08)
		tween.tween_property(avatar, "scale", Vector2(1.0, 1.0), 0.12)
		
		# Parpadeo de invulnerabilidad
		var tween_inv = create_tween().set_loops(4)
		tween_inv.tween_property(avatar, "modulate:a", 0.3, 0.12)
		tween_inv.tween_property(avatar, "modulate:a", 1.0, 0.12)
		
		await get_tree().create_timer(1.2).timeout
		jugadores_invulnerables[id_jugador] = false
		return

	# MODO NORMAL MULTIJUGADOR: Eliminación por equipos 2v2
	var estaba_vivo = false
	for eq in [0, 1]:
		if id_jugador in jugadores_vivos_por_equipo[eq]:
			estaba_vivo = true
			jugadores_vivos_por_equipo[eq].erase(id_jugador)
			
	if not estaba_vivo: return
	
	avatar.bloquear_controles(true)
	avatar.estado_actual = avatar.Estado.ELIMINADO
	
	var tween_elim = create_tween()
	tween_elim.tween_property(avatar, "scale", Vector2(1.4, 0.3), 0.1)
	tween_elim.tween_property(avatar, "modulate:a", 0.0, 0.35)
	await tween_elim.finished
	avatar.global_position = Vector2(-2000, -2000)
	
	actualizar_hud_equipos()
	
	# Verificar si un equipo completo fue eliminado
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad and not partida_terminada:
		var eq0_vivos = jugadores_vivos_por_equipo[0].size()
		var eq1_vivos = jugadores_vivos_por_equipo[1].size()
		
		if eq0_vivos == 0 and eq1_vivos > 0:
			declarar_fin_por_equipos(1)
		elif eq1_vivos == 0 and eq0_vivos > 0:
			declarar_fin_por_equipos(0)
		elif eq0_vivos == 0 and eq1_vivos == 0:
			declarar_fin_por_equipos(0)

func actualizar_hud_equipos():
	if not label_integrantes_0 or not label_integrantes_1: return
	label_integrantes_0.text = formatear_texto_equipo(0)
	label_integrantes_1.text = formatear_texto_equipo(1)

func formatear_texto_equipo(equipo_idx: int) -> String:
	var texto = ""
	var todos = jugadores_por_equipo.get(equipo_idx, [])
	var vivos = jugadores_vivos_por_equipo.get(equipo_idx, [])
	
	for i in range(todos.size()):
		var id = todos[i]
		var nombre = obtener_nombre_jugador(id)
		var estado = "✓" if (id in vivos) else "✗"
		texto += nombre + " [" + estado + "]"
		if i < todos.size() - 1:
			texto += "  •  "
	return texto

func declarar_fin_por_equipos(equipo_ganador: int):
	if partida_terminada: return
	partida_terminada = true
	
	if multiplayer.has_multiplayer_peer():
		rpc("declarar_victoria_2v2_rpc", equipo_ganador)
	else:
		declarar_victoria_2v2_rpc(equipo_ganador)

@rpc("any_peer", "call_local", "reliable")
func declarar_victoria_2v2_rpc(equipo_ganador: int):
	partida_terminada = true
	bloquear_jugadores(true)
	
	if hud_equipo_0: hud_equipo_0.visible = false
	if hud_equipo_1: hud_equipo_1.visible = false
	var marcador = get_node_or_null("HUD/MarcadorCentral")
	if marcador: marcador.visible = false
	
	var ganadores = jugadores_por_equipo[equipo_ganador]
	ejecutar_secuencia_victoria(ganadores, Vector2(576, 400))
