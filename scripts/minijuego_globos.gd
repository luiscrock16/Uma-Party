extends BaseMinijuego

@onready var contenedor_globos = $ContenedorGlobos
@onready var camera = $Camera2D

# HUD por equipos
@onready var hud_equipo_0 = $HUD/PanelEquipo0
@onready var hud_equipo_1 = $HUD/PanelEquipo1
@onready var label_restantes_0 = $HUD/PanelEquipo0/Margen/VBox/HBox/LabelRestantes
@onready var label_restantes_1 = $HUD/PanelEquipo1/Margen/VBox/HBox/LabelRestantes
@onready var barra_progreso_0 = $HUD/PanelEquipo0/Margen/VBox/BarraProgreso
@onready var barra_progreso_1 = $HUD/PanelEquipo1/Margen/VBox/BarraProgreso
@onready var label_reloj = $HUD/PanelCentral/Margen/VBox/LabelReloj

var escena_globo = preload("res://escenas/globo_equipo.tscn")

const TOTAL_GLOBOS_POR_EQUIPO = 20
var globos_restantes: Dictionary = { 0: TOTAL_GLOBOS_POR_EQUIPO, 1: TOTAL_GLOBOS_POR_EQUIPO }
var mapa_globos: Dictionary = {} # id_globo -> nodo GloboEquipo

var partida_iniciada: bool = false
var partida_terminada: bool = false
var tiempo_partida: float = 0.0


func _ready():
	modo_actual = Modo.EQUIPOS_2V2
	Global.establecer_texto_accion_tactil("EMPUJAR")
	tiempo_partida = 0.0
	partida_iniciada = false
	partida_terminada = false
	
	globos_restantes[0] = TOTAL_GLOBOS_POR_EQUIPO
	globos_restantes[1] = TOTAL_GLOBOS_POR_EQUIPO
	
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
	var spawns = [
		Vector2(260, 280), # E0 - Jugador 1
		Vector2(260, 460), # E0 - Jugador 2
		Vector2(892, 280), # E1 - Jugador 3
		Vector2(892, 460)  # E1 - Jugador 4
	]
	
	for id in jugadores_info.keys():
		var datos = jugadores_info[id]
		var equipo = datos.get("equipo", 0)
		var spawn_idx = datos.get("spawn", 0)
		
		var avatar = get_node_or_null(str(id))
		if avatar:
			avatar.scale = Vector2(1.0, 1.0)
			avatar.modulate = Color(1, 1, 1, 1)
			
			var punto_spawn = get_node_or_null("Spawns/" + str(spawn_idx))
			if punto_spawn:
				avatar.global_position = punto_spawn.global_position
			elif spawn_idx < spawns.size():
				avatar.global_position = spawns[spawn_idx]
				
			# Movimiento libre con sprint (sin salto)
			avatar.set_movimiento_actual = PersonajeJugable.TipoMovimiento.CON_SPRINT
			avatar.bloquear_controles(true)
			avatar.set_physics_process(true)
			
			# Color de equipo en la etiqueta
			var col_equipo = Color("#ff4757") if equipo == 0 else Color("#1e90ff")
			if "label_nick" in avatar and avatar.label_nick:
				avatar.label_nick.modulate = col_equipo

	generar_tablero_globos()
	actualizar_hud()
	iniciar_secuencia_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	partida_iniciada = true
	tiempo_partida = 0.0
	bloquear_jugadores(false)

func generar_tablero_globos():
	for hijo in contenedor_globos.get_children():
		hijo.queue_free()
	mapa_globos.clear()
	
	# Matriz de 8 columnas x 5 filas = 40 globos exactamente balanceados
	var cols = [275.0, 360.0, 445.0, 530.0, 622.0, 707.0, 792.0, 877.0]
	var rows = [220.0, 295.0, 370.0, 445.0, 520.0]
	
	var id_counter = 0
	for r in range(rows.size()):
		for c in range(cols.size()):
			# Distribución ajedrezada para máxima interacción y cruces
			var equipo_globo = (r + c) % 2
			var pos = Vector2(cols[c] + randf_range(-8.0, 8.0), rows[r] + randf_range(-6.0, 6.0))
			
			var globo = escena_globo.instantiate()
			globo.position = pos
			contenedor_globos.add_child(globo)
			globo.configurar(equipo_globo, id_counter)
			globo.globo_reventado.connect(_on_globo_reventado_signal)
			mapa_globos[id_counter] = globo
			id_counter += 1

func obtener_equipo_jugador(id_jugador: int) -> int:
	if id_jugador in jugadores_info:
		return jugadores_info[id_jugador].get("equipo", 0)
	return 0 if id_jugador == 1 else 1

func reventar_globo_local(id_globo: int, id_jugador: int):
	if id_globo in mapa_globos:
		var globo = mapa_globos[id_globo]
		if is_instance_valid(globo) and not globo.reventado:
			globo.reventar(id_jugador)

@rpc("authority", "call_local", "reliable")
func reventar_globo_rpc(id_globo: int, id_jugador: int):
	reventar_globo_local(id_globo, id_jugador)

func _on_globo_reventado_signal(equipo: int, id_globo: int, _id_jugador: int):
	mapa_globos.erase(id_globo)
	globos_restantes[equipo] = max(0, globos_restantes[equipo] - 1)
	actualizar_hud()
	
	# Verificar si un equipo ha reventado todos sus globos
	var es_autoridad = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if es_autoridad and not partida_terminada:
		if globos_restantes[equipo] <= 0:
			declarar_fin_globos(equipo)

func _process(delta):
	if not partida_iniciada or partida_terminada: return
	
	tiempo_partida += delta
	if label_reloj:
		var total_seg = int(tiempo_partida)
		label_reloj.text = "%02d:%02d" % [total_seg / 60, total_seg % 60]
		

func actualizar_hud():
	if label_restantes_0:
		label_restantes_0.text = "%d / %d" % [globos_restantes[0], TOTAL_GLOBOS_POR_EQUIPO]
	if label_restantes_1:
		label_restantes_1.text = "%d / %d" % [globos_restantes[1], TOTAL_GLOBOS_POR_EQUIPO]
		
	if barra_progreso_0:
		var reventados_0 = TOTAL_GLOBOS_POR_EQUIPO - globos_restantes[0]
		barra_progreso_0.value = (float(reventados_0) / float(TOTAL_GLOBOS_POR_EQUIPO)) * 100.0
	if barra_progreso_1:
		var reventados_1 = TOTAL_GLOBOS_POR_EQUIPO - globos_restantes[1]
		barra_progreso_1.value = (float(reventados_1) / float(TOTAL_GLOBOS_POR_EQUIPO)) * 100.0

func declarar_fin_globos(equipo_ganador: int):
	if partida_terminada: return
	partida_terminada = true
	
	if multiplayer.has_multiplayer_peer():
		rpc("declarar_victoria_globos_rpc", equipo_ganador)
	else:
		declarar_victoria_globos_rpc(equipo_ganador)

@rpc("authority", "call_local", "reliable")
func declarar_victoria_globos_rpc(equipo_ganador: int):
	partida_terminada = true
	bloquear_jugadores(true)
	
	if hud_equipo_0: hud_equipo_0.visible = false
	if hud_equipo_1: hud_equipo_1.visible = false
	var panel_cen = get_node_or_null("HUD/PanelCentral")
	if panel_cen: panel_cen.visible = false
	
	var ganadores = []
	for id in jugadores_info.keys():
		if jugadores_info[id].get("equipo", 0) == equipo_ganador:
			ganadores.append(id)
			
	ejecutar_secuencia_victoria(ganadores, Vector2(576, 380))
