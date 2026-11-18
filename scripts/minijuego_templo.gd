extends BaseMinijuego

@onready var contenedor_pivotes = $ContenedorPivotes
@onready var contenedor_bolas = $ContenedorBolas
@onready var camera = $Camera2D

# HUD
@onready var label_tiempo = $HUD/PanelSuperior/Margen/HBox/LabelTiempo
@onready var label_supervivientes = $HUD/PanelSuperior/Margen/HBox/LabelSupervivientes
@onready var label_f6 = $HUD/LabelModoF6

var escena_bola = preload("res://escenas/bola_templo.tscn")
var escena_pivote = preload("res://escenas/pivote_templo.tscn")

var partida_iniciada: bool = false
var partida_terminada: bool = false
var tiempo_partida: float = 0.0
var es_modo_f6: bool = false

var timer_spawn_bola: float = 1.8
var timer_conmutar_pivotes: float = 2.4

var pivotes_dinamicos: Array = []
var jugadores_invulnerables: Dictionary = {}

# Puntos de lanzamiento de bolas en la parte superior
const PUNTOS_DISPENSADORES = [
	Vector2(440, 60),
	Vector2(510, 60),
	Vector2(576, 60),
	Vector2(642, 60),
	Vector2(712, 60)
]

func _ready():
	modo_actual = Modo.FFA
	Global.configurar_controles_tactiles(true, true, "IMPULSO")
	tiempo_partida = 0.0
	partida_iniciada = false
	partida_terminada = false
	es_modo_f6 = not get_tree().root.has_node("Lobby")
	
	if label_f6:
		label_f6.visible = es_modo_f6
		
	recopilar_pivotes_dinamicos()
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func recopilar_pivotes_dinamicos():
	pivotes_dinamicos.clear()
	for hijo in contenedor_pivotes.get_children():
		if hijo is PivoteTemplo and not hijo.es_fijo:
			pivotes_dinamicos.append(hijo)

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	
	var mi_id = 1
	var ids_test = [mi_id, 2, 3, 4]
	
	jugadores_info.clear()
	for i in range(ids_test.size()):
		var id = ids_test[i]
		jugadores_info[id] = {"equipo": i, "spawn": i, "es_jefe": false}
		
		if not has_node(str(id)):
			var av = preload("res://escenas/personaje_jugable.tscn").instantiate()
			av.name = str(id)
			add_child(av)
			av.configurar_visual(i % 4, "P" + str(i + 1))
			
	aplicar_roles_locales()

func aplicar_roles_locales():
	jugadores_vivos.clear()
	jugadores_invulnerables.clear()
	
	var spawns = [
		Vector2(380, 560),
		Vector2(490, 560),
		Vector2(660, 560),
		Vector2(770, 560)
	]
	
	for id in jugadores_info.keys():
		var datos = jugadores_info[id]
		var spawn_idx = datos.get("spawn", 0)
		jugadores_vivos.append(id)
		
		var avatar = get_node_or_null(str(id))
		if avatar:
			avatar.scale = Vector2(1.0, 1.0)
			avatar.modulate = Color(1, 1, 1, 1)
			
			var punto_spawn = get_node_or_null("Spawns/" + str(spawn_idx))
			if punto_spawn:
				avatar.global_position = punto_spawn.global_position
			elif spawn_idx < spawns.size():
				avatar.global_position = spawns[spawn_idx]
				
			# Configuración para Tumble Temple: colisión física entre jugadores y salto
			avatar.set_movimiento_actual = PersonajeJugable.TipoMovimiento.TEMPLO_PINBALL
			avatar.collision_layer = 2 | 4
			avatar.collision_mask = 1 | 2
			avatar.bloquear_controles(true)
			avatar.set_physics_process(true)
			
	actualizar_hud()
	iniciar_secuencia_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	partida_iniciada = true
	tiempo_partida = 0.0
	bloquear_jugadores(false)

func _process(delta):
	if not partida_iniciada: return
	if partida_terminada and not es_modo_f6: return
	
	tiempo_partida += delta
	actualizar_hud()
	
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad:
		# Temporizador de caída de bolas por el pinball
		timer_spawn_bola -= delta
		if timer_spawn_bola <= 0.0:
			lanzar_bola_templo()
			# El ritmo se acelera progresivamente
			var cadencia_min = max(0.65, 1.7 - (tiempo_partida * 0.02))
			var cadencia_max = max(1.1, 2.3 - (tiempo_partida * 0.02))
			timer_spawn_bola = randf_range(cadencia_min, cadencia_max)
			
		# Temporizador de conmutación de pivotes (subir y bajar palos)
		timer_conmutar_pivotes -= delta
		if timer_conmutar_pivotes <= 0.0:
			conmutar_pivotes_aleatorios()
			timer_conmutar_pivotes = randf_range(2.0, 3.5)
			

func actualizar_hud():
	if label_tiempo:
		var total_seg = int(tiempo_partida)
		label_tiempo.text = "%02d:%02d" % [total_seg / 60, total_seg % 60]
	if label_supervivientes:
		label_supervivientes.text = "VIVOS: %d / %d" % [jugadores_vivos.size(), jugadores_info.size()]

# --- GENERACIÓN DE BOLAS ---

func lanzar_bola_templo():
	var idx = randi() % PUNTOS_DISPENSADORES.size()
	var pos = PUNTOS_DISPENSADORES[idx]
	# Pequeña variación lateral e impulso inicial hacia abajo
	pos.x += randf_range(-18.0, 18.0)
	var impulso_x = randf_range(-40.0, 40.0)
	
	# Variedad de balones deportivos oficiales (básquetbol, estrella, choque, deka)
	var tipos = [0, 0, 1, 2] # 50% básquetbol, 25% estrella, 25% choque
	if tiempo_partida > 22.0:
		tipos.append(3) # A partir de los 22s pueden caer balones gigantes pesados
	var tipo_elegido = tipos[randi() % tipos.size()]
	
	if multiplayer.has_multiplayer_peer():
		rpc("spawn_bola_rpc", pos, impulso_x, tipo_elegido)
	else:
		spawn_bola_rpc(pos, impulso_x, tipo_elegido)

@rpc("any_peer", "call_local", "reliable")
func spawn_bola_rpc(pos_inicio: Vector2, impulso_x: float, tipo_bola: int = 0):
	var bola = escena_bola.instantiate()
	bola.global_position = pos_inicio
	bola.linear_velocity = Vector2(impulso_x, randf_range(20.0, 60.0))
	bola.configurar_tipo(tipo_bola)
	contenedor_bolas.add_child(bola)
	bola.aplasto_jugador.connect(_on_jugador_alcanzado)

# --- SISTEMA DE PIVOTES / PALOS QUE SE ALZAN Y ESCONDEN ---

func conmutar_pivotes_aleatorios():
	if pivotes_dinamicos.is_empty(): return
	var cantidad_a_cambiar = randi_range(2, 4)
	var indices_cambiados = []
	
	for i in range(cantidad_a_cambiar):
		var idx = randi() % pivotes_dinamicos.size()
		if idx not in indices_cambiados:
			indices_cambiados.append(idx)
			
	if multiplayer.has_multiplayer_peer():
		rpc("aplicar_conmutacion_pivotes_rpc", indices_cambiados)
	else:
		aplicar_conmutacion_pivotes_rpc(indices_cambiados)

@rpc("any_peer", "call_local", "reliable")
func aplicar_conmutacion_pivotes_rpc(indices: Array):
	for idx in indices:
		if idx >= 0 and idx < pivotes_dinamicos.size():
			pivotes_dinamicos[idx].conmutar()

# --- COLISIÓN / ELIMINACIÓN ---

func _on_jugador_alcanzado(id_jugador: int):
	if partida_terminada and not es_modo_f6: return
	if jugadores_invulnerables.get(id_jugador, false): return
	
	if multiplayer.has_multiplayer_peer():
		if es_autoridad_de_partida():
			eliminar_jugador_templo_rpc.rpc(id_jugador)
		else:
			if id_jugador == multiplayer.get_unique_id():
				reportar_impacto_templo_rpc.rpc(id_jugador)
	else:
		eliminar_jugador_templo_rpc(id_jugador)

@rpc("any_peer", "call_local", "reliable")
func reportar_impacto_templo_rpc(id_jugador: int):
	if not es_autoridad_de_partida(): return
	var remitente = multiplayer.get_remote_sender_id()
	if remitente != 0 and remitente != id_jugador: return
	if jugadores_invulnerables.get(id_jugador, false): return
	eliminar_jugador_templo_rpc.rpc(id_jugador)

@rpc("any_peer", "call_local", "reliable")
func eliminar_jugador_templo_rpc(id_jugador: int):
	var avatar = get_node_or_null(str(id_jugador))
	if not avatar: return
	
	if es_modo_f6:
		# MODO PRUEBA F6: Reacción al impacto e invulnerabilidad temporal sin cortar la prueba
		jugadores_invulnerables[id_jugador] = true
		var tween = create_tween()
		tween.tween_property(avatar, "scale", Vector2(1.4, 0.5), 0.08)
		tween.tween_property(avatar, "scale", Vector2(1.0, 1.0), 0.14)
		
		var tween_inv = create_tween().set_loops(4)
		tween_inv.tween_property(avatar, "modulate:a", 0.3, 0.12)
		tween_inv.tween_property(avatar, "modulate:a", 1.0, 0.12)
		await get_tree().create_timer(1.2).timeout
		jugadores_invulnerables[id_jugador] = false
		return
		
	# MODO NORMAL MULTIJUGADOR: Eliminación estándar
	if id_jugador not in jugadores_vivos: return
	jugadores_vivos.erase(id_jugador)
	
	avatar.bloquear_controles(true)
	avatar.estado_actual = avatar.Estado.ELIMINADO
	
	var tween_elim = create_tween()
	tween_elim.tween_property(avatar, "scale", Vector2(1.5, 0.3), 0.1)
	tween_elim.tween_property(avatar, "modulate:a", 0.0, 0.35)
	await tween_elim.finished
	avatar.global_position = Vector2(-2000, -2000)
	
	actualizar_hud()
	
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad and not partida_terminada:
		if jugadores_vivos.size() <= 1:
			declarar_fin_templo(jugadores_vivos)

func declarar_fin_templo(ganadores: Array):
	if partida_terminada: return
	partida_terminada = true
	
	if multiplayer.has_multiplayer_peer():
		rpc("declarar_victoria_templo_rpc", ganadores)
	else:
		declarar_victoria_templo_rpc(ganadores)

@rpc("any_peer", "call_local", "reliable")
func declarar_victoria_templo_rpc(ganadores: Array):
	partida_terminada = true
	bloquear_jugadores(true)
	
	var hud_sup = get_node_or_null("HUD/PanelSuperior")
	if hud_sup: hud_sup.visible = false
	
	ejecutar_secuencia_victoria(ganadores, Vector2(576, 560))
