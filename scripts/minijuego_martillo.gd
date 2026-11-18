extends BaseMinijuego

# Constantes de Posiciones de los 9 Hoyos (Cuadrícula 3x3)
const POS_CASILLAS: Array[Vector2] = [
	Vector2(340.0, 275.0), Vector2(576.0, 275.0), Vector2(812.0, 275.0),
	Vector2(340.0, 395.0), Vector2(576.0, 395.0), Vector2(812.0, 395.0),
	Vector2(340.0, 515.0), Vector2(576.0, 515.0), Vector2(812.0, 515.0)
]
const CENTRO_ARENA: Vector2 = Vector2(576.0, 395.0)
const POS_OPERADOR_JEFE: Vector2 = Vector2(576.0, 125.0)
const MAX_RONDAS: int = 8

# Estado del Juego por Turnos
enum EstadoRonda { SELECCION, REVELACION_GOLPE, CELEBRACION, FIN }
var estado_ronda: EstadoRonda = EstadoRonda.SELECCION

var partida_iniciada: bool = false
var partida_terminada: bool = false
var ronda_actual: int = 1
var tiempo_limite_ronda: float = 5.0
var tiempo_restante_ronda: float = 5.0

# Roles y Jugadores
var id_jefe: int = 1
var ids_topos: Array = []
var avatares_jugadores: Dictionary = {} # {id: CharacterBody2D}

# Casillas activas y bloqueadas
var casillas_activas: Array = [0, 1, 2, 3, 4, 5, 6, 7, 8]
var casillas_bloqueadas: Array = []
var nodos_hoyos: Array[Node2D] = []

# Elecciones del Turno Actual
var eleccion_martillo: int = 4 # Casilla central por defecto
var elecciones_topos: Dictionary = {} # {id_topo: int_casilla}
var selectores_visuales: Dictionary = {} # {id_topo: Sprite2D}

# Referencias a Nodos
@onready var contenedor_hoyos: Node2D = $ContenedorHoyos
@onready var contenedor_topos: Node2D = $ContenedorTopos
@onready var contenedor_selectores: Node2D = $ContenedorSelectores
@onready var mira_martillo: Node2D = $MiraMartillo
@onready var visual_martillo: Node2D = $MiraMartillo/VisualMartillo
@onready var particulas_impacto: CPUParticles2D = $ParticulasImpacto
@onready var camera: Camera2D = $Camera2D

# HUD
@onready var label_ronda: Label = $HUD/PanelInfo/HBox/LabelRonda

# Texturas
var tex_hoyo_activo: Texture2D = preload("res://assets/minijuegos/martillo/hoyo_topo_activo.png")
var tex_hoyo_bloqueado: Texture2D = preload("res://assets/minijuegos/martillo/hoyo_topo_bloqueado.png")
var tex_selector: Texture2D = preload("res://assets/minijuegos/martillo/selector_jugador.png")

func _ready():
	modo_actual = Modo.JEFE_1V3
	partida_iniciada = false
	partida_terminada = false
	ronda_actual = 1
	tiempo_limite_ronda = 5.0
	tiempo_restante_ronda = 5.0
	casillas_activas = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	casillas_bloqueadas.clear()
	
	if visual_martillo: visual_martillo.visible = false
	
	_construir_tablero_hoyos()
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	jugadores_info.clear()
	# Jugador 1 es el Jefe Martillo, Jugadores 2, 3 y 4 son los Topos
	jugadores_info[1] = {"equipo": 0, "spawn": 0, "es_jefe": true}
	for i in [2, 3, 4]:
		jugadores_info[i] = {"equipo": 1, "spawn": i - 1, "es_jefe": false}
		
	for id in jugadores_info.keys():
		if not has_node(str(id)):
			var av = preload("res://escenas/personaje_jugable.tscn").instantiate()
			av.name = str(id)
			add_child(av)
			av.configurar_visual(id - 1, "P" + str(id))
			
	aplicar_roles_locales()

# ==============================================================================
# CONSTRUCCIÓN DEL TABLERO DE LOS 9 HOYOS
# ==============================================================================

func _construir_tablero_hoyos():
	for c in contenedor_hoyos.get_children():
		c.queue_free()
	nodos_hoyos.clear()
	
	for i in range(POS_CASILLAS.size()):
		var pos = POS_CASILLAS[i]
		var nodo_hoyo = Node2D.new()
		nodo_hoyo.name = "Hoyo_%d" % i
		nodo_hoyo.position = pos
		
		# Sprite Activo
		var spr_activo = Sprite2D.new()
		spr_activo.name = "SpriteActivo"
		spr_activo.texture = tex_hoyo_activo
		nodo_hoyo.add_child(spr_activo)
		
		# Sprite Bloqueado (inicialmente oculto, con z_index sobre el hoyo activo)
		var spr_bloq = Sprite2D.new()
		spr_bloq.name = "SpriteBloqueado"
		spr_bloq.texture = tex_hoyo_bloqueado
		spr_bloq.visible = false
		spr_bloq.z_index = 2
		spr_bloq.scale = Vector2.ZERO
		nodo_hoyo.add_child(spr_bloq)
		
		contenedor_hoyos.add_child(nodo_hoyo)
		nodos_hoyos.append(nodo_hoyo)

# ==============================================================================
# ASIGNACIÓN DE ROLES Y SPAWNS
# ==============================================================================

func aplicar_roles_locales():
	ids_topos.clear()
	avatares_jugadores.clear()
	elecciones_topos.clear()
	selectores_visuales.clear()
	
	for c in contenedor_selectores.get_children():
		c.queue_free()
		
	var spawns_default_topos = [0, 2, 6, 8]
	var idx_topo = 0
	
	for id in jugadores_info.keys():
		var datos = jugadores_info[id]
		var av = get_node_or_null(str(id))
		if not av and get_tree().root:
			av = get_tree().root.find_child(str(id), true, false)
			
		if datos.get("es_jefe", false):
			id_jefe = id
			if av:
				avatares_jugadores[id] = av
				av.global_position = POS_OPERADOR_JEFE
				av.bloquear_controles(true)
				av.modulate = Color.WHITE
				av.scale = Vector2.ONE
				av.visible = true
				var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
				if prefijo == null: prefijo = "SEIK"
				if av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_idle"):
					av.sprite.play(prefijo + "_idle")
		else:
			ids_topos.append(id)
			if av:
				avatares_jugadores[id] = av
				av.bloquear_controles(true)
				av.modulate = Color.WHITE
				av.scale = Vector2.ONE
				# Inicialmente bajo tierra (oculto en el hoyo)
				var c_ini = spawns_default_topos[idx_topo % spawns_default_topos.size()]
				elecciones_topos[id] = c_ini
				av.global_position = POS_CASILLAS[c_ini] + Vector2(0, 30)
				av.visible = false
				
				# Selector visual flotante
				var sel = Sprite2D.new()
				sel.name = "Selector_%d" % id
				sel.texture = tex_selector
				sel.position = POS_CASILLAS[c_ini] + Vector2(0, -65)
				sel.modulate = _color_jugador(idx_topo)
				contenedor_selectores.add_child(sel)
				selectores_visuales[id] = sel
				
				idx_topo += 1
				
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else id_jefe
	var soy_jefe = (mi_id == id_jefe)
	Global.establecer_texto_accion_tactil("¡APLASTAR!" if soy_jefe else "SELECCIONAR")
	
	# Ajustar posición inicial de la mira
	eleccion_martillo = 4
	if mira_martillo:
		mira_martillo.position = POS_CASILLAS[4]
		
	actualizar_hud()
	actualizar_visibilidad_pantalla_local()
	
	if not instrucciones_mostradas:
		instrucciones_mostradas = true
		mostrar_pantalla_instrucciones()
	else:
		call_deferred("iniciar_secuencia_cuenta_atras")

func _color_jugador(idx: int) -> Color:
	var colores = [Color(0.2, 0.7, 1.0), Color(1.0, 0.3, 0.3), Color(0.3, 0.9, 0.4), Color(1.0, 0.85, 0.2)]
	return colores[idx % colores.size()]

func _on_instrucciones_completadas():
	inicio_cuenta_atras.emit()
	al_completar_instrucciones()

func al_completar_instrucciones():
	iniciar_secuencia_cuenta_atras()

func iniciar_secuencia_cuenta_atras():
	ejecutar_overlay_cuenta_atras()

func bloquear_jugadores(_bloquear: bool):
	# En el minijuego del martillo ningún avatar utiliza movimiento físico directo
	for av in avatares_jugadores.values():
		if av and is_instance_valid(av):
			av.bloquear_controles(true)
			av.velocity = Vector2.ZERO

func iniciar_juego_post_cuenta_atras():
	bloquear_jugadores(true)
	partida_iniciada = true
	ronda_actual = 1
	iniciar_ronda_seleccion()

# ==============================================================================
# FLUJO DE RONDAS Y SELECCIÓN
# ==============================================================================

func iniciar_ronda_seleccion():
	estado_ronda = EstadoRonda.SELECCION
	if contenedor_selectores: contenedor_selectores.visible = true
	# Dificultad progresiva: Menos tiempo según avanza la partida
	tiempo_limite_ronda = max(2.2, 5.0 - float(ronda_actual - 1) * 0.45)
	tiempo_restante_ronda = tiempo_limite_ronda
	
	actualizar_hud()
	actualizar_visibilidad_pantalla_local()
	
	# Asegurar que las elecciones actuales caigan en casillas activas
	if not casillas_activas.is_empty():
		for id in ids_topos:
			var c_t = int(elecciones_topos.get(id, -1))
			if c_t not in casillas_activas:
				elecciones_topos[id] = casillas_activas.pick_random()
			elif not multiplayer.has_multiplayer_peer() and ronda_actual > 1:
				# En partidas locales/bots, los topos cambian de escondite entre rondas
				elecciones_topos[id] = casillas_activas.pick_random()
			_actualizar_pos_selector_topo(id)
			
		if eleccion_martillo not in casillas_activas:
			eleccion_martillo = casillas_activas.pick_random()
	else:
		eleccion_martillo = 4
	if mira_martillo:
		mira_martillo.position = POS_CASILLAS[eleccion_martillo]
		
	# Ocultar avatares bajo tierra al inicio de la selección
	for id in ids_topos:
		var av = avatares_jugadores.get(id)
		if av and is_instance_valid(av):
			av.visible = false
			av.global_position = POS_CASILLAS[int(elecciones_topos[id])] + Vector2(0, 30)

func _physics_process(delta: float):
	if not partida_iniciada or partida_terminada: return
	
	# Mantener al operador fijo e inmóvil en su plataforma superior
	var av_jefe = avatares_jugadores.get(id_jefe)
	if av_jefe and is_instance_valid(av_jefe) and estado_ronda != EstadoRonda.FIN:
		av_jefe.global_position = POS_OPERADOR_JEFE
		av_jefe.velocity = Vector2.ZERO
		
	# Bobbing suave de los selectores activos
	var t_bob = Time.get_ticks_msec() * 0.007
	for sel in selectores_visuales.values():
		if sel and is_instance_valid(sel) and sel.visible:
			sel.offset.y = sin(t_bob) * 5.0
	
	if estado_ronda == EstadoRonda.SELECCION:
		tiempo_restante_ronda -= delta
		_procesar_input_local()
		
		if tiempo_restante_ronda <= 0.0:
			tiempo_restante_ronda = 0.0
			var es_autoridad = es_autoridad_de_partida()
			if es_autoridad:
				ejecutar_revelacion_y_golpe()

# ==============================================================================
# ENTRADA DE USUARIO POR CASILLAS (DISCRETO 3x3 Y SOPORTE RATÓN/TÁCTIL)
# ==============================================================================

func _unhandled_input(event: InputEvent):
	if not partida_iniciada or partida_terminada or estado_ronda != EstadoRonda.SELECCION: return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(POS_CASILLAS.size()):
			if event.position.distance_to(POS_CASILLAS[i]) <= 55.0:
				if i in casillas_activas:
					_aplicar_seleccion_local(i)
				break
	elif event is InputEventScreenTouch and event.pressed:
		for i in range(POS_CASILLAS.size()):
			if event.position.distance_to(POS_CASILLAS[i]) <= 55.0:
				if i in casillas_activas:
					_aplicar_seleccion_local(i)
				break

func _aplicar_seleccion_local(nueva_c: int):
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else id_jefe
	if mi_id == id_jefe:
		if nueva_c != eleccion_martillo and nueva_c in casillas_activas:
			eleccion_martillo = nueva_c
			if mira_martillo:
				var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(mira_martillo, "position", POS_CASILLAS[eleccion_martillo], 0.08)
			if multiplayer.has_multiplayer_peer():
				sincronizar_eleccion_martillo_rpc.rpc(eleccion_martillo)
	else:
		if mi_id in ids_topos:
			if nueva_c != int(elecciones_topos.get(mi_id, 0)) and nueva_c in casillas_activas:
				elecciones_topos[mi_id] = nueva_c
				_actualizar_pos_selector_topo(mi_id)
				if multiplayer.has_multiplayer_peer():
					sincronizar_eleccion_topo_rpc.rpc(mi_id, nueva_c)

func _procesar_input_local():
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else id_jefe
	
	if mi_id == id_jefe:
		# Control de selección del martillo
		var nueva_c = _navegar_casilla_con_input(eleccion_martillo)
		if nueva_c != eleccion_martillo:
			_aplicar_seleccion_local(nueva_c)
	else:
		# Control de selección de los topos
		if mi_id in ids_topos:
			var c_actual = int(elecciones_topos.get(mi_id, 0))
			var nueva_c = _navegar_casilla_con_input(c_actual)
			if nueva_c != c_actual:
				_aplicar_seleccion_local(nueva_c)

func _navegar_casilla_con_input(c_actual: int) -> int:
	var d_col = 0
	var d_fila = 0
	
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("a"):
		d_col = -1
	elif Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("d"):
		d_col = 1
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("w"):
		d_fila = -1
	elif Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("s"):
		d_fila = 1
	else:
		# Selección con teclado numérico 1 a 9
		for k in range(9):
			if Input.is_key_pressed(KEY_1 + k) or Input.is_key_pressed(KEY_KP_1 + k):
				if k in casillas_activas: return k
		return c_actual
		
	if d_col != 0 or d_fila != 0:
		return _navegar_direccion(c_actual, d_col, d_fila)
	return c_actual

func _navegar_direccion(c_actual: int, d_col: int, d_fila: int) -> int:
	var col = c_actual % 3
	var fila = c_actual / 3
	
	# Buscar el siguiente hoyo activo en esa dirección (hasta 3 pasos para saltar hoyos bloqueados)
	for paso in range(1, 4):
		var n_col = (col + d_col * paso) % 3
		if n_col < 0: n_col += 3
		var n_fila = (fila + d_fila * paso) % 3
		if n_fila < 0: n_fila += 3
		var cand = n_fila * 3 + n_col
		if cand in casillas_activas:
			return cand
	return c_actual

func _actualizar_pos_selector_topo(id: int):
	var sel = selectores_visuales.get(id)
	var c = int(elecciones_topos.get(id, 0))
	if sel and is_instance_valid(sel):
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sel, "position", POS_CASILLAS[c] + Vector2(0, -65), 0.1)
	actualizar_visibilidad_pantalla_local()

func actualizar_visibilidad_pantalla_local():
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else id_jefe
	var soy_jefe = (mi_id == id_jefe)
	
	if estado_ronda == EstadoRonda.SELECCION:
		if mira_martillo:
			mira_martillo.visible = soy_jefe
		for id in selectores_visuales.keys():
			var sel = selectores_visuales[id]
			if sel and is_instance_valid(sel):
				# En la pantalla de cada topo solo se ve su propio selector; el martillo no ve ninguno
				sel.visible = (!soy_jefe and id == mi_id)
	elif estado_ronda == EstadoRonda.REVELACION_GOLPE:
		if mira_martillo:
			mira_martillo.visible = true
		if contenedor_selectores:
			contenedor_selectores.visible = false

@rpc("any_peer", "call_local", "reliable")
func sincronizar_eleccion_martillo_rpc(c: int):
	eleccion_martillo = c
	if mira_martillo: mira_martillo.position = POS_CASILLAS[c]

@rpc("any_peer", "call_local", "reliable")
func sincronizar_eleccion_topo_rpc(id: int, c: int):
	elecciones_topos[id] = c
	_actualizar_pos_selector_topo(id)

# ==============================================================================
# FASE DE REVELACIÓN Y GOLPE: TOPOS ASOMANDO JUNTOS Y APLASTAMIENTO
# ==============================================================================

func ejecutar_revelacion_y_golpe():
	estado_ronda = EstadoRonda.REVELACION_GOLPE
	
	if multiplayer.has_multiplayer_peer():
		sincronizar_revelacion_y_golpe_rpc.rpc(eleccion_martillo, elecciones_topos)
	else:
		sincronizar_revelacion_y_golpe_rpc(eleccion_martillo, elecciones_topos)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_revelacion_y_golpe_rpc(c_martillo: int, datos_topos: Dictionary):
	estado_ronda = EstadoRonda.REVELACION_GOLPE
	actualizar_visibilidad_pantalla_local()
	eleccion_martillo = c_martillo
	elecciones_topos = datos_topos
	
	# 1. Agrupar topos por hoyo
	var mapa_hoyo_a_topos: Dictionary = {}
	for id in ids_topos:
		var c = int(elecciones_topos.get(id, 0))
		if not mapa_hoyo_a_topos.has(c):
			mapa_hoyo_a_topos[c] = []
		mapa_hoyo_a_topos[c].append(id)
		
	# 2. Los topos asoman por los hoyos
	# SI MÁS DE UNO ELIGIÓ EL MISMO HOYO, SALEN JUNTOS APRETUJADOS
	for c in mapa_hoyo_a_topos.keys():
		var c_idx = int(c)
		if c_idx < 0 or c_idx >= POS_CASILLAS.size(): continue
		var lista = mapa_hoyo_a_topos[c]
		var n = lista.size()
		var pos_base = POS_CASILLAS[c_idx]
		
		for idx in range(n):
			var id_t = lista[idx]
			var av = avatares_jugadores.get(id_t)
			if not av or not is_instance_valid(av): continue
			
			av.visible = true
			av.scale = Vector2(0.85, 0.85) if n > 1 else Vector2.ONE
			
			# Desplazamiento horizontal según cuántos topos comparten el mismo hoyo
			var offset_x = 0.0
			if n == 2:
				offset_x = -20.0 if idx == 0 else 20.0
			elif n >= 3:
				offset_x = (float(idx) - 1.0) * 24.0
				
			var pos_final = pos_base + Vector2(offset_x, -12.0)
			av.global_position = pos_base + Vector2(offset_x, 35.0) # Empieza bajo tierra
			
			var tw_emerge = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_emerge.tween_property(av, "global_position:y", pos_final.y, 0.28)
			
			var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if av.sprite and is_instance_valid(av.sprite):
				var anim = prefijo + "_intro" if n > 1 else prefijo + "_idle"
				if av.sprite.sprite_frames.has_animation(anim):
					av.sprite.play(anim)
					
	# Breve pausa para ver dónde salió cada uno antes de que caiga el martillo
	await get_tree().create_timer(0.45).timeout
	
	# 3. Caída del Martillo Gigante
	if mira_martillo:
		mira_martillo.position = POS_CASILLAS[c_martillo]
	if visual_martillo:
		visual_martillo.visible = true
		visual_martillo.position = Vector2(0, -320)
		
		var tw_drop = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_drop.tween_property(visual_martillo, "position:y", 0.0, 0.32)
		await tw_drop.finished
		
	# 4. Impacto contundente
	agitar_camara(10.0)
	if particulas_impacto:
		particulas_impacto.global_position = POS_CASILLAS[c_martillo]
		particulas_impacto.restart()
		particulas_impacto.emitting = true
		
	var topos_impactados = mapa_hoyo_a_topos.get(c_martillo, [])
	if not topos_impactados.is_empty():
		# ¡Topos aplastados cómicamente!
		for id_apl in topos_impactados:
			var av_apl = avatares_jugadores.get(id_apl)
			if av_apl and is_instance_valid(av_apl):
				var prefijo = av_apl.get("prefijo_personaje") if "prefijo_personaje" in av_apl else "SEIK"
				if prefijo == null: prefijo = "SEIK"
				if av_apl.sprite and av_apl.sprite.sprite_frames.has_animation(prefijo + "_impacto"):
					av_apl.sprite.play(prefijo + "_impacto")
				var tw_squish = create_tween().set_parallel(true)
				tw_squish.tween_property(av_apl, "scale", Vector2(1.4, 0.22), 0.12)
				tw_squish.tween_property(av_apl, "modulate:a", 0.0, 0.35)
				tw_squish.chain().tween_callback(func():
					if is_instance_valid(av_apl):
						av_apl.visible = false
						av_apl.modulate = Color.WHITE
						av_apl.scale = Vector2.ONE
				)
				
				# Eliminar de la lista de topos vivos y suprimir su selector
				ids_topos.erase(id_apl)
				elecciones_topos.erase(id_apl)
				if selectores_visuales.has(id_apl):
					var sel = selectores_visuales[id_apl]
					if is_instance_valid(sel):
						sel.queue_free()
					selectores_visuales.erase(id_apl)
	else:
		# Golpe al aire: los topos de los otros hoyos celebran
		for id_surv in ids_topos:
			var av_s = avatares_jugadores.get(id_surv)
			if av_s and is_instance_valid(av_s):
				var prefijo = av_s.get("prefijo_personaje") if "prefijo_personaje" in av_s else "SEIK"
				if prefijo == null: prefijo = "SEIK"
				if av_s.sprite and av_s.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
					av_s.sprite.play(prefijo + "_acierto")
					
	actualizar_hud()
	
	# 5. Retirada del martillo hacia arriba
	await get_tree().create_timer(0.65).timeout
	if visual_martillo:
		var tw_up = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_up.tween_property(visual_martillo, "position:y", -320.0, 0.3)
		await tw_up.finished
		visual_martillo.visible = false
		
	# 6. Comprobación de Fin de Partida o Siguiente Ronda
	_evaluar_fin_o_siguiente_ronda()

func _evaluar_fin_o_siguiente_ronda():
	var es_autoridad = es_autoridad_de_partida()
	if not es_autoridad: return
	
	# Condición A: Todos los topos fueron eliminados -> Gana el Martillo
	if ids_topos.is_empty():
		declarar_fin_martillo(false)
		return
		
	# Condición B: Se completaron todas las rondas -> Ganan los Topos que sobrevivieron
	if ronda_actual >= MAX_RONDAS:
		declarar_fin_martillo(true)
		return
		
	# Siguiente ronda: Bloquear casillas según dificultad
	ronda_actual += 1
	_aplicar_dificultad_bloqueo_casillas()
	
	# Sincronizar inicio de la siguiente ronda
	if multiplayer.has_multiplayer_peer():
		sincronizar_siguiente_ronda_rpc.rpc(ronda_actual, casillas_activas.duplicate(), casillas_bloqueadas.duplicate())
	else:
		sincronizar_siguiente_ronda_rpc(ronda_actual, casillas_activas.duplicate(), casillas_bloqueadas.duplicate())

func _aplicar_dificultad_bloqueo_casillas():
	# Reducción progresiva de casillas: tapar agujeros según avanzan las rondas (mínimo 3)
	var max_activas = 9
	if ronda_actual == 2: max_activas = 8
	elif ronda_actual == 3: max_activas = 7
	elif ronda_actual == 4: max_activas = 6
	elif ronda_actual == 5: max_activas = 5
	elif ronda_actual >= 6 and ronda_actual < 8: max_activas = 4
	elif ronda_actual >= 8: max_activas = 3
	
	while casillas_activas.size() > max_activas and casillas_activas.size() > 3:
		var candidata = casillas_activas.pick_random()
		casillas_activas.erase(candidata)
		if not casillas_bloqueadas.has(candidata):
			casillas_bloqueadas.append(candidata)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_siguiente_ronda_rpc(nueva_ronda: int, activas: Array, bloqueadas: Array):
	ronda_actual = nueva_ronda
	var lista_act: Array = []
	for a in activas: lista_act.append(int(a))
	var lista_bloq: Array = []
	for b in bloqueadas: lista_bloq.append(int(b))
	casillas_activas = lista_act
	casillas_bloqueadas = lista_bloq
	
	# Actualizar visuales de los hoyos bloqueados con tapa de madera
	for idx_b in casillas_bloqueadas:
		if idx_b < nodos_hoyos.size():
			var n_hoyo = nodos_hoyos[idx_b]
			var spr_bloq = n_hoyo.get_node_or_null("SpriteBloqueado")
			if spr_bloq:
				spr_bloq.visible = true
				if spr_bloq.scale.x < 0.9:
					spr_bloq.scale = Vector2.ZERO
					var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					tw.tween_property(spr_bloq, "scale", Vector2.ONE, 0.35)
				
	# Iniciar siguiente turno de selección
	iniciar_ronda_seleccion()

# ==============================================================================
# FIN DE PARTIDA Y VICTORIA
# ==============================================================================

func declarar_fin_martillo(ganaron_topos: bool):
	if partida_terminada: return
	partida_terminada = true
	estado_ronda = EstadoRonda.FIN
	
	if multiplayer.has_multiplayer_peer():
		declarar_victoria_rpc.rpc(ganaron_topos)
	else:
		declarar_victoria_rpc(ganaron_topos)

@rpc("any_peer", "call_local", "reliable")
func declarar_victoria_rpc(ganaron_topos: bool):
	partida_terminada = true
	bloquear_jugadores(true)
	estado_ronda = EstadoRonda.FIN
	
	var ganadores = []
	if ganaron_topos:
		# Ganan todos los topos que lograron sobrevivir
		for id in ids_topos:
			ganadores.append(id)
		secuencia_victoria_topos(ganadores)
	else:
		# Gana el Jefe del Martillo
		ganadores.append(id_jefe)
		var av_jefe = avatares_jugadores.get(id_jefe)
		if av_jefe and is_instance_valid(av_jefe):
			av_jefe.visible = true
			av_jefe.scale = Vector2.ONE
			av_jefe.modulate = Color.WHITE
			var prefijo = av_jefe.get("prefijo_personaje") if "prefijo_personaje" in av_jefe else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if av_jefe.sprite and av_jefe.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
				av_jefe.sprite.play(prefijo + "_acierto")
		ejecutar_secuencia_victoria(ganadores, POS_OPERADOR_JEFE)

# ==============================================================================
# SECUENCIA DE VENGANZA SLAPSTICK (VICTORIA DE LOS TOPOS)
# ==============================================================================

func secuencia_victoria_topos(ganadores: Array):
	if mira_martillo: mira_martillo.visible = false
	if contenedor_selectores: contenedor_selectores.visible = false
	
	# PASO 1: Todos los topos supervivientes salen de sus hoyos celebrando la ronda final
	for id_t in ganadores:
		var av = avatares_jugadores.get(id_t)
		if not av or not is_instance_valid(av): continue
		av.visible = true
		av.scale = Vector2.ONE
		av.modulate = Color.WHITE
		var c = int(elecciones_topos.get(id_t, 4))
		if c < 0 or c >= POS_CASILLAS.size(): c = 4
		av.global_position = POS_CASILLAS[c] + Vector2(0, 30)
		var tw_pop = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_pop.tween_property(av, "global_position:y", POS_CASILLAS[c].y - 12.0, 0.35)
		
		var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
		if prefijo == null: prefijo = "SEIK"
		if av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
			av.sprite.play(prefijo + "_acierto")
			
	await get_tree().create_timer(1.1).timeout
	
	# PASO 2: Vuelven a entrar todos juntos por un único agujero (el hoyo central)
	for id_t in ganadores:
		var av = avatares_jugadores.get(id_t)
		if not av or not is_instance_valid(av): continue
		var tw_dive = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_dive.tween_property(av, "global_position:x", CENTRO_ARENA.x, 0.45)
		tw_dive.tween_property(av, "global_position:y", CENTRO_ARENA.y + 45.0, 0.45)
		tw_dive.tween_property(av, "scale", Vector2(0.25, 0.25), 0.45)
		
	await get_tree().create_timer(0.55).timeout
	for id_t in ganadores:
		var av = avatares_jugadores.get(id_t)
		if av and is_instance_valid(av):
			av.visible = false
			
	# PASO 3: El jugador del martillo baja al centro del escenario mirando confuso
	var av_jefe = avatares_jugadores.get(id_jefe)
	if av_jefe and is_instance_valid(av_jefe):
		var pref_jefe = av_jefe.get("prefijo_personaje") if "prefijo_personaje" in av_jefe else "SEIK"
		if pref_jefe == null: pref_jefe = "SEIK"
		if av_jefe.sprite and av_jefe.sprite.sprite_frames.has_animation(pref_jefe + "_caminar"):
			av_jefe.sprite.play(pref_jefe + "_caminar")
			
		var tw_walk = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw_walk.tween_property(av_jefe, "global_position", CENTRO_ARENA + Vector2(0, -10), 0.95)
		await tw_walk.finished
		
		# Mirar a los lados confundido
		if av_jefe.sprite:
			if av_jefe.sprite.sprite_frames.has_animation(pref_jefe + "_aturdido"):
				av_jefe.sprite.play(pref_jefe + "_aturdido")
			elif av_jefe.sprite.sprite_frames.has_animation(pref_jefe + "_idle"):
				av_jefe.sprite.play(pref_jefe + "_idle")
			av_jefe.sprite.flip_h = false
			await get_tree().create_timer(0.25).timeout
			av_jefe.sprite.flip_h = true
			await get_tree().create_timer(0.25).timeout
			av_jefe.sprite.flip_h = false
			
	await get_tree().create_timer(0.35).timeout
	
	# PASO 4: Los topos reaparecen desde fuera de la pantalla cayendo sobre la plataforma del martillo
	var n_topos = ganadores.size()
	for idx in range(n_topos):
		var id_t = ganadores[idx]
		var av = avatares_jugadores.get(id_t)
		if not av or not is_instance_valid(av): continue
		
		var offset_x = (float(idx) - float(n_topos - 1) * 0.5) * 36.0
		var pos_balcon = POS_OPERADOR_JEFE + Vector2(offset_x, 0)
		av.global_position = Vector2(pos_balcon.x, -60.0)
		av.scale = Vector2.ONE
		av.visible = true
		
		var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
		if prefijo == null: prefijo = "SEIK"
		if av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_intro"):
			av.sprite.play(prefijo + "_intro")
			
		var tw_drop = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw_drop.tween_property(av, "global_position:y", pos_balcon.y, 0.42)
		
	await get_tree().create_timer(0.55).timeout
	
	# PASO 5: Animación conjunta de ataque/activación y cae el martillo aplastando al jefe
	for id_t in ganadores:
		var av = avatares_jugadores.get(id_t)
		if not av or not is_instance_valid(av): continue
		var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
		if prefijo == null: prefijo = "SEIK"
		if av.sprite:
			if av.sprite.sprite_frames.has_animation(prefijo + "_ataque"):
				av.sprite.play(prefijo + "_ataque")
			elif av.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
				av.sprite.play(prefijo + "_acierto")
				
	# Martillo gigante cae sobre el centro donde está el jefe
	if mira_martillo:
		mira_martillo.position = CENTRO_ARENA
		mira_martillo.visible = true
	if visual_martillo:
		visual_martillo.visible = true
		visual_martillo.position = Vector2(0, -360)
		
		var tw_slam = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_slam.tween_property(visual_martillo, "position:y", 0.0, 0.26)
		await tw_slam.finished
		
	# Impacto y aplastamiento cómico del jefe
	agitar_camara(15.0)
	if particulas_impacto:
		particulas_impacto.global_position = CENTRO_ARENA
		particulas_impacto.restart()
		particulas_impacto.emitting = true
		
	if av_jefe and is_instance_valid(av_jefe):
		var pref_jefe = av_jefe.get("prefijo_personaje") if "prefijo_personaje" in av_jefe else "SEIK"
		if pref_jefe == null: pref_jefe = "SEIK"
		if av_jefe.sprite and av_jefe.sprite.sprite_frames.has_animation(pref_jefe + "_impacto"):
			av_jefe.sprite.play(pref_jefe + "_impacto")
		var tw_sq = create_tween().set_parallel(true)
		tw_sq.tween_property(av_jefe, "scale", Vector2(1.6, 0.2), 0.12)
		tw_sq.tween_property(av_jefe, "global_position:y", CENTRO_ARENA.y + 15.0, 0.12)
		tw_sq.tween_property(av_jefe, "modulate", Color(0.9, 0.2, 0.2, 0.8), 0.3)
		
	# PASO 6: Los topos en el balcón celebran la victoria
	await get_tree().create_timer(0.4).timeout
	for id_t in ganadores:
		var av = avatares_jugadores.get(id_t)
		if not av or not is_instance_valid(av): continue
		var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
		if prefijo == null: prefijo = "SEIK"
		if av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
			av.sprite.play(prefijo + "_acierto")
			
	await get_tree().create_timer(1.2).timeout
	ejecutar_secuencia_victoria(ganadores, POS_OPERADOR_JEFE)

# ==============================================================================
# MÉTODOS AUXILIARES Y HUD
# ==============================================================================

func agitar_camara(intensidad: float):
	if not camera: return
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	for i in range(4):
		tw.tween_property(camera, "offset", Vector2(randf_range(-intensidad, intensidad), randf_range(-intensidad, intensidad)), 0.04)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.04)

func actualizar_hud():
	if label_ronda:
		label_ronda.text = "RONDA: %d / %d" % [ronda_actual, MAX_RONDAS]
