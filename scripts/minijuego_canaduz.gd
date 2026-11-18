extends BaseMinijuego

# Constantes de Arena y Física
const ARENA_MIN_X = 140.0
const ARENA_MAX_X = 1012.0
const ARENA_MIN_Y = 88.0
const ARENA_MAX_Y = 590.0
const CENTRO_ARENA = Vector2(576.0, 340.0)

const PUNTOS_EMBOSCADA: Array[Vector2] = [
	Vector2(290.0, 200.0),
	Vector2(860.0, 200.0),
	Vector2(860.0, 480.0),
	Vector2(290.0, 480.0)
]

# Sistema de Munición del Artillero
const MUNICION_MAXIMA: int = 5
const TIEMPO_RECARGA_BALA: float = 1.15
var municion_actual: int = 5
var progreso_recarga: float = 0.0

# Nodos Principales
@onready var fondo_arena = $FondoArena
@onready var puestos_festival = $PuestosFestival
@onready var contenedor_barricadas = $ContenedorBarricadas
@onready var contenedor_proyectiles = $ContenedorProyectiles
@onready var torreta_centinela = $TorretaCentinela
@onready var cano_centinela = $TorretaCentinela/CanoCentinela
@onready var punto_disparo_centinela = $TorretaCentinela/CanoCentinela/PuntoDisparo
@onready var plataforma_jefe = $PlataformaJefe
@onready var montura_canones = $PlataformaJefe/MonturaCanones
@onready var cano_frontal = $PlataformaJefe/MonturaCanones/CanoFrontal
@onready var cano_trasero = $PlataformaJefe/MonturaCanones/CanoTrasero
@onready var cano_cono_izq = $PlataformaJefe/MonturaCanones/CanoConoIzq
@onready var cano_cono_der = $PlataformaJefe/MonturaCanones/CanoConoDer
@onready var particulas_humo = $ParticulasHumoTierra
@onready var particulas_explosion = $ParticulasExplosion
@onready var camera = $Camera2D

# HUD
@onready var label_reloj = $HUD/PanelInfo/HBox/LabelReloj
@onready var label_supervivientes = $HUD/PanelInfo/HBox/LabelSupervivientes
@onready var panel_municion = $HUD/PanelMunicion
@onready var label_pips_balas = $HUD/PanelMunicion/VBox/HBoxBalas/LabelPipsBalas
@onready var barra_recarga = $HUD/PanelMunicion/VBox/BarraRecarga

# Estado del Juego
var partida_iniciada: bool = false
var partida_terminada: bool = false
var tiempo_total: float = 90.0
var tiempo_restante: float = 90.0

var id_jefe: int = 1
var ids_supervivientes: Array = []
var avatares_jugadores: Dictionary = {}

# Fases Internas (Sin interfaz de texto)
# Fase 1: 90s - 60s (1 Cañón 360°, SIN rebotes)
# Fase 2: 60s - 30s (2 Cañones opuestos 180°, SIN rebotes)
# Fase 3: 30s - 0s  (Torreta centinela cada 2s + Jefe con 3 cañones con 3 rebotes + 1 Proyectil Destructor)
var fase_actual: int = 1
var en_transicion_fase: bool = false
var cinematica_final_activa: bool = false

# Control de Disparo y Apuntado del Jefe
var angulo_apuntado: float = 0.0
var cooldown_disparo_jefe: float = 0.0

# Control Fase 3
var timer_disparo_centinela: float = 2.0
var timer_emboscada_jefe: float = 4.2
var indice_emboscada: int = 0

# Control de Barricadas Tácticas Dinámicas
var timer_ciclo_barricadas: float = 6.0
var estados_barricadas: Array[bool] = [true, true, true, true, true, true, true, true]
var en_alerta_barricadas: Array[bool] = [false, false, false, false, false, false, false, false]
var nodos_barricadas: Array[StaticBody2D] = []
var nodos_puestos: Array[StaticBody2D] = []

# Cache de texturas de proyectiles de Caos en la Pista
var texturas_proyectiles: Array[Texture2D] = []

func _ready():
	modo_actual = Modo.JEFE_1V3
	partida_iniciada = false
	partida_terminada = false
	cinematica_final_activa = false
	tiempo_restante = tiempo_total
	fase_actual = 1
	en_transicion_fase = false
	municion_actual = MUNICION_MAXIMA
	progreso_recarga = 0.0
	
	_cargar_texturas_proyectiles()
	_inicializar_barricadas()
	
	if torreta_centinela: torreta_centinela.visible = false
	if cano_trasero: cano_trasero.visible = false
	if cano_cono_izq: cano_cono_izq.visible = false
	if cano_cono_der: cano_cono_der.visible = false
	
	_actualizar_hud_municion()
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func _cargar_texturas_proyectiles():
	var rutas = [
		"res://assets/props_clean/item_omoball00.png",
		"res://assets/props_clean/basketball01.png",
		"res://assets/props_clean/crashball01.png",
		"res://assets/props_clean/chanceball01.png",
		"res://assets/props_clean/item_dekaball00.png"
	]
	for r in rutas:
		if ResourceLoader.exists(r):
			texturas_proyectiles.append(load(r))

func _inicializar_barricadas():
	nodos_barricadas.clear()
	for i in range(8):
		var b = contenedor_barricadas.get_node_or_null("Barricada%d" % i) as StaticBody2D
		if b:
			nodos_barricadas.append(b)
			estados_barricadas[i] = true
			en_alerta_barricadas[i] = false
			
	nodos_puestos.clear()
	if puestos_festival:
		for p in puestos_festival.get_children():
			if p is StaticBody2D:
				nodos_puestos.append(p)

# ==============================================================================
# ASIGNACIÓN DE ROLES Y POSICIÓN VISUAL DEL JEFE
# ==============================================================================

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	jugadores_info.clear()
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

func aplicar_roles_locales():
	ids_supervivientes.clear()
	avatares_jugadores.clear()
	
	var spawns_supervivientes = [
		Vector2(260.0, 310.0),
		Vector2(880.0, 220.0),
		Vector2(576.0, 530.0),
		Vector2(480.0, 140.0)
	]
	
	var idx_sup = 0
	for id in jugadores_info.keys():
		var datos = jugadores_info[id]
		var av = get_node_or_null(str(id))
		if not av and get_tree().root:
			av = get_tree().root.find_child(str(id), true, false)
			
		if datos.get("es_jefe", false):
			id_jefe = id
			if av:
				avatares_jugadores[id] = av
				av.bloquear_controles(true)
				av.visible = true
				av.z_index = 12
				av.global_position = plataforma_jefe.global_position + Vector2(0, -10)
				var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
				if prefijo == null: prefijo = "SEIK"
				if av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_idle"):
					av.sprite.play(prefijo + "_idle")
		else:
			ids_supervivientes.append(id)
			if av:
				avatares_jugadores[id] = av
				av.global_position = spawns_supervivientes[idx_sup % spawns_supervivientes.size()]
				av.bloquear_controles(true)
				av.modulate = Color.WHITE
				av.scale = Vector2.ONE
				av.visible = true
				if "set_movimiento_actual" in av:
					av.set_movimiento_actual = PersonajeJugable.TipoMovimiento.CON_SPRINT
				idx_sup += 1
				
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else id_jefe
	var soy_jefe = (mi_id == id_jefe)
	
	if panel_municion:
		panel_municion.visible = soy_jefe
	Global.establecer_texto_accion_tactil("DISPARAR (%d/5)" % municion_actual if soy_jefe else "SPRINT")
	
	plataforma_jefe.global_position = CENTRO_ARENA
	actualizar_hud_supervivientes()
	_actualizar_hud_municion()
	
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
	tiempo_restante = tiempo_total
	municion_actual = MUNICION_MAXIMA
	progreso_recarga = 0.0
	bloquear_jugadores(false)
	
	var av_jefe = avatares_jugadores.get(id_jefe)
	if av_jefe and is_instance_valid(av_jefe):
		av_jefe.bloquear_controles(true)
		av_jefe.z_index = 12
		av_jefe.global_position = plataforma_jefe.global_position + Vector2(0, -10)

# ==============================================================================
# BUCLE PRINCIPAL DE FÍSICA Y FASES
# ==============================================================================

func _physics_process(delta: float):
	if not partida_iniciada or partida_terminada or cinematica_final_activa: return
	
	tiempo_restante -= delta
	_actualizar_hud_tiempo()
	
	# 1. Mantener al avatar del jefe visualmente sobre su plataforma activa
	var av_jefe = avatares_jugadores.get(id_jefe)
	if av_jefe and is_instance_valid(av_jefe):
		if not en_transicion_fase:
			av_jefe.global_position = plataforma_jefe.global_position + Vector2(0, -10)
		av_jefe.velocity = Vector2.ZERO
		var dir_disparo = Vector2.DOWN.rotated(montura_canones.rotation)
		if av_jefe.sprite:
			av_jefe.sprite.flip_h = (dir_disparo.x < 0)
			
	# 2. Recarga de Munición Gradual con el tiempo
	if municion_actual < MUNICION_MAXIMA:
		progreso_recarga += delta
		if progreso_recarga >= TIEMPO_RECARGA_BALA:
			progreso_recarga = 0.0
			municion_actual = min(MUNICION_MAXIMA, municion_actual + 1)
			_actualizar_hud_municion()
	else:
		progreso_recarga = 0.0
	if barra_recarga:
		barra_recarga.value = (progreso_recarga / TIEMPO_RECARGA_BALA) if municion_actual < MUNICION_MAXIMA else 1.0
		
	# 3. Procesar apuntado y disparo MANUAL del jefe (360°)
	_procesar_control_artillero(delta)
	
	# 4. Transiciones de fases secretas
	_gestionar_fases_internas(delta)
	
	# 5. Barricadas dinámicas con advertencia previa de colapso
	_gestionar_barricadas_dinamicas(delta)
	
	# 6. IA para supervivientes en pruebas locales
	_procesar_ia_bots_local(delta)
	
	# Condición de Victoria: Supervivientes aguantan los 90s
	if tiempo_restante <= 0.0:
		tiempo_restante = 0.0
		declarar_fin_canaduz(ids_supervivientes.size() > 0)

# ==============================================================================
# CONTROL DE APUNTADO Y DISPARO MANUAL (MUNICIÓN LIMITADA)
# ==============================================================================

func _procesar_control_artillero(delta: float):
	if en_transicion_fase or cinematica_final_activa: return
	
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else id_jefe
	var soy_jefe = (mi_id == id_jefe)
	
	if soy_jefe:
		# Apuntado libre 360° con Ratón / Cursor
		var pos_mouse = get_global_mouse_position()
		var vec_mouse = pos_mouse - plataforma_jefe.global_position
		if vec_mouse.length_squared() > 1600.0:
			angulo_apuntado = vec_mouse.angle() - (PI * 0.5)
		else:
			var h = Input.get_axis("ui_left", "ui_right")
			if h == 0.0: h = Input.get_axis("a", "d")
			if h != 0.0: angulo_apuntado += h * 3.6 * delta
			
		montura_canones.rotation = angulo_apuntado
		
		if multiplayer.has_multiplayer_peer():
			sincronizar_angulo_jefe_rpc.rpc(angulo_apuntado)
			
		# Disparo 100% MANUAL
		cooldown_disparo_jefe -= delta
		
		var quiere_disparar = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("espacio") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if quiere_disparar and cooldown_disparo_jefe <= 0.0:
			if municion_actual > 0:
				municion_actual -= 1
				cooldown_disparo_jefe = 0.32
				_actualizar_hud_municion()
				_ejecutar_disparo_segun_fase()
			else:
				_feedback_sin_municion()

@rpc("any_peer", "call_local", "unreliable")
func sincronizar_angulo_jefe_rpc(ang: float):
	angulo_apuntado = ang
	if montura_canones: montura_canones.rotation = ang

func _feedback_sin_municion():
	if label_pips_balas:
		var tw = create_tween()
		tw.tween_property(label_pips_balas, "modulate", Color(1, 0.2, 0.2), 0.08)
		tw.tween_property(label_pips_balas, "modulate", Color.WHITE, 0.12)

func _actualizar_hud_municion():
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else id_jefe
	var soy_jefe = (mi_id == id_jefe)
	
	if panel_municion:
		panel_municion.visible = soy_jefe
		
	if label_pips_balas:
		var pips_str = ""
		for i in range(MUNICION_MAXIMA):
			if i < municion_actual:
				pips_str += "● "
			else:
				pips_str += "○ "
		label_pips_balas.text = pips_str.strip_edges()
		if municion_actual == 0:
			label_pips_balas.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))
		elif municion_actual <= 2:
			label_pips_balas.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		else:
			label_pips_balas.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
			
	if soy_jefe:
		Global.establecer_texto_accion_tactil("DISPARAR (%d/5)" % municion_actual)

func _ejecutar_disparo_segun_fase():
	var dir_frontal = Vector2.DOWN.rotated(montura_canones.rotation)
	var pos_origen = cano_frontal.global_position
	
	match fase_actual:
		1:
			# Fase 1: 1 Proyectil Frontal DIRECTO (SIN rebote)
			_disparar_proyectil(pos_origen, dir_frontal, 460.0, false, false)
		2:
			# Fase 2: 2 Proyectiles Opuestos DIRECTOS (SIN rebote)
			_disparar_proyectil(pos_origen, dir_frontal, 460.0, false, false)
			var dir_trasera = -dir_frontal
			var pos_trasera = cano_trasero.global_position
			_disparar_proyectil(pos_trasera, dir_trasera, 460.0, false, false)
		3:
			# Fase 3: 3 Proyectiles en Cono con REBOTES (3 rebotes)
			# UNO DE LOS PROYECTILES ES ALEATORIAMENTE DESTRUCTOR DE MUROS Y PUESTOS
			var ang_base = dir_frontal.angle()
			var angulos = [ang_base - 0.36, ang_base, ang_base + 0.36]
			var idx_destructor = randi() % 3
			for i in range(angulos.size()):
				var d_cono = Vector2.from_angle(angulos[i])
				var es_dest = (i == idx_destructor)
				_disparar_proyectil(plataforma_jefe.global_position, d_cono, 460.0, true, es_dest)

# ==============================================================================
# GESTIÓN DE FASES SECRETAS (SIN TEXTO EN HUD)
# ==============================================================================

func _gestionar_fases_internas(delta: float):
	if cinematica_final_activa: return
	
	# Transición a Fase 2 a los 60s
	if fase_actual == 1 and tiempo_restante <= 60.0 and not en_transicion_fase:
		_iniciar_transicion_fase_2()
		
	# Transición a Fase 3 a los 30s
	elif fase_actual == 2 and tiempo_restante <= 30.0 and not en_transicion_fase:
		_iniciar_transicion_fase_3()
		
	# Lógica continua de Fase 3
	if fase_actual == 3 and not en_transicion_fase:
		_procesar_fase_3_centinela_y_emboscadas(delta)

func _iniciar_transicion_fase_2():
	en_transicion_fase = true
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad:
		sincronizar_transicion_fase_2_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func sincronizar_transicion_fase_2_rpc():
	en_transicion_fase = true
	_efecto_polvo_en(plataforma_jefe.global_position)
	
	var av_jefe = avatares_jugadores.get(id_jefe)
	
	var tw_baja = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_baja.tween_property(plataforma_jefe, "scale", Vector2(0.2, 0.2), 0.45)
	tw_baja.tween_property(plataforma_jefe, "modulate:a", 0.0, 0.45)
	if av_jefe and is_instance_valid(av_jefe):
		tw_baja.tween_property(av_jefe, "scale", Vector2(0.2, 0.2), 0.45)
		tw_baja.tween_property(av_jefe, "modulate:a", 0.0, 0.45)
	await tw_baja.finished
	
	fase_actual = 2
	if cano_trasero: cano_trasero.visible = true
	plataforma_jefe.global_position = CENTRO_ARENA
	if av_jefe and is_instance_valid(av_jefe):
		av_jefe.global_position = CENTRO_ARENA + Vector2(0, -10)
	_efecto_polvo_en(CENTRO_ARENA)
	
	var tw_sube = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_sube.tween_property(plataforma_jefe, "scale", Vector2.ONE, 0.45)
	tw_sube.tween_property(plataforma_jefe, "modulate:a", 1.0, 0.45)
	if av_jefe and is_instance_valid(av_jefe):
		tw_sube.tween_property(av_jefe, "scale", Vector2.ONE, 0.45)
		tw_sube.tween_property(av_jefe, "modulate:a", 1.0, 0.45)
	await tw_sube.finished
	en_transicion_fase = false

func _iniciar_transicion_fase_3():
	en_transicion_fase = true
	var es_autoridad = es_autoridad_de_partida()
	if es_autoridad:
		sincronizar_transicion_fase_3_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func sincronizar_transicion_fase_3_rpc():
	en_transicion_fase = true
	_efecto_polvo_en(plataforma_jefe.global_position)
	
	var av_jefe = avatares_jugadores.get(id_jefe)
	
	var tw_oculta = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_oculta.tween_property(plataforma_jefe, "scale", Vector2(0.2, 0.2), 0.4)
	tw_oculta.tween_property(plataforma_jefe, "modulate:a", 0.0, 0.4)
	if av_jefe and is_instance_valid(av_jefe):
		tw_oculta.tween_property(av_jefe, "scale", Vector2(0.2, 0.2), 0.4)
		tw_oculta.tween_property(av_jefe, "modulate:a", 0.0, 0.4)
	await tw_oculta.finished
	
	fase_actual = 3
	torreta_centinela.global_position = CENTRO_ARENA
	torreta_centinela.visible = true
	torreta_centinela.scale = Vector2.ZERO
	_efecto_polvo_en(CENTRO_ARENA)
	
	var tw_torr = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_torr.tween_property(torreta_centinela, "scale", Vector2.ONE, 0.45)
	
	if cano_trasero: cano_trasero.visible = false
	if cano_cono_izq: cano_cono_izq.visible = true
	if cano_cono_der: cano_cono_der.visible = true
	
	indice_emboscada = 0
	plataforma_jefe.global_position = PUNTOS_EMBOSCADA[indice_emboscada]
	if av_jefe and is_instance_valid(av_jefe):
		av_jefe.global_position = PUNTOS_EMBOSCADA[indice_emboscada] + Vector2(0, -10)
	_efecto_polvo_en(plataforma_jefe.global_position)
	
	var tw_jefe = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_jefe.tween_property(plataforma_jefe, "scale", Vector2.ONE, 0.45)
	tw_jefe.tween_property(plataforma_jefe, "modulate:a", 1.0, 0.45)
	if av_jefe and is_instance_valid(av_jefe):
		tw_jefe.tween_property(av_jefe, "scale", Vector2.ONE, 0.45)
		tw_jefe.tween_property(av_jefe, "modulate:a", 1.0, 0.45)
	await tw_jefe.finished
	en_transicion_fase = false

func _procesar_fase_3_centinela_y_emboscadas(delta: float):
	if cinematica_final_activa: return
	
	# 1. Torreta Centinela Central: Dispara cada 2 segundos exactos
	timer_disparo_centinela -= delta
	var obj_cercano = _obtener_superviviente_mas_cercano(CENTRO_ARENA)
	if obj_cercano and torreta_centinela.visible:
		var dir_obj = (obj_cercano.global_position - CENTRO_ARENA).normalized()
		var ang_deseado = dir_obj.angle() - (PI * 0.5)
		cano_centinela.rotation = rotate_toward(cano_centinela.rotation, ang_deseado, 2.8 * delta)
		
		if timer_disparo_centinela <= 0.0:
			timer_disparo_centinela = 2.0
			var dir_disparo = Vector2.DOWN.rotated(cano_centinela.rotation)
			_disparar_proyectil(punto_disparo_centinela.global_position, dir_disparo, 400.0, false, false)
			
	# 2. Emboscadas móviles del Jefe: Salta entre los 4 puntos de la arena
	timer_emboscada_jefe -= delta
	if timer_emboscada_jefe <= 0.0 and not en_transicion_fase:
		timer_emboscada_jefe = 4.5
		var es_autoridad = es_autoridad_de_partida()
		if es_autoridad:
			indice_emboscada = (indice_emboscada + 1) % PUNTOS_EMBOSCADA.size()
			sincronizar_emboscada_jefe_rpc.rpc(indice_emboscada)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_emboscada_jefe_rpc(nuevo_idx: int):
	if cinematica_final_activa: return
	en_transicion_fase = true
	indice_emboscada = nuevo_idx
	_efecto_polvo_en(plataforma_jefe.global_position)
	
	var av_jefe = avatares_jugadores.get(id_jefe)
	
	var tw_down = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_down.tween_property(plataforma_jefe, "scale", Vector2(0.2, 0.2), 0.35)
	tw_down.tween_property(plataforma_jefe, "modulate:a", 0.0, 0.35)
	if av_jefe and is_instance_valid(av_jefe):
		tw_down.tween_property(av_jefe, "scale", Vector2(0.2, 0.2), 0.35)
		tw_down.tween_property(av_jefe, "modulate:a", 0.0, 0.35)
	await tw_down.finished
	
	plataforma_jefe.global_position = PUNTOS_EMBOSCADA[indice_emboscada]
	if av_jefe and is_instance_valid(av_jefe):
		av_jefe.global_position = PUNTOS_EMBOSCADA[indice_emboscada] + Vector2(0, -10)
	_efecto_polvo_en(plataforma_jefe.global_position)
	
	var dir_hacia_centro = (CENTRO_ARENA - plataforma_jefe.global_position).normalized()
	angulo_apuntado = dir_hacia_centro.angle() - (PI * 0.5)
	montura_canones.rotation = angulo_apuntado
	
	var tw_up = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_up.tween_property(plataforma_jefe, "scale", Vector2.ONE, 0.35)
	tw_up.tween_property(plataforma_jefe, "modulate:a", 1.0, 0.35)
	if av_jefe and is_instance_valid(av_jefe):
		tw_up.tween_property(av_jefe, "scale", Vector2.ONE, 0.35)
		tw_up.tween_property(av_jefe, "modulate:a", 1.0, 0.35)
	await tw_up.finished
	en_transicion_fase = false

func _obtener_superviviente_mas_cercano(desde_pos: Vector2) -> Node2D:
	var mejor_dist: float = 999999.0
	var mejor_nodo: Node2D = null
	for id in ids_supervivientes:
		var av = avatares_jugadores.get(id)
		if not av or not is_instance_valid(av):
			av = obtener_avatar_jugador(id)
		if av and is_instance_valid(av) and av.visible:
			var d = desde_pos.distance_squared_to(av.global_position)
			if d < mejor_dist:
				mejor_dist = d
				mejor_nodo = av
	return mejor_nodo

# ==============================================================================
# BARRICADAS TÁCTICAS DINÁMICAS (ALERTA DE COLAPSO Y REAPARICIÓN)
# ==============================================================================

func _gestionar_barricadas_dinamicas(delta: float):
	if cinematica_final_activa: return
	timer_ciclo_barricadas -= delta
	if timer_ciclo_barricadas <= 0.0:
		timer_ciclo_barricadas = randf_range(6.0, 7.5)
		var es_autoridad = es_autoridad_de_partida()
		if es_autoridad:
			var activas = []
			var inactivas = []
			for i in range(estados_barricadas.size()):
				if estados_barricadas[i]: activas.append(i)
				else: inactivas.append(i)
				
			activas.shuffle()
			inactivas.shuffle()
			
			var a_colapsar = activas.slice(0, min(2, activas.size()))
			var a_emerger = inactivas.slice(0, min(2, inactivas.size()))
			
			sincronizar_alerta_barricadas_rpc.rpc(a_colapsar, a_emerger)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_alerta_barricadas_rpc(indices_colapsar: Array, indices_emerger: Array):
	if cinematica_final_activa: return
	for idx in indices_colapsar:
		if idx < nodos_barricadas.size():
			var b = nodos_barricadas[idx]
			if b and is_instance_valid(b):
				var spr = b.get_node_or_null("SpriteBarricada") as Sprite2D
				if spr:
					var tw_warn = create_tween().set_loops(4)
					tw_warn.tween_property(spr, "modulate", Color(1, 0.45, 0.2), 0.18)
					tw_warn.tween_property(spr, "modulate", Color.WHITE, 0.18)
					
	await get_tree().create_timer(1.5).timeout
	if cinematica_final_activa: return
	
	for idx in indices_colapsar:
		if idx < nodos_barricadas.size():
			estados_barricadas[idx] = false
			var b = nodos_barricadas[idx]
			if b and is_instance_valid(b):
				var col = b.get_node_or_null("CollisionShape2D") as CollisionShape2D
				var spr = b.get_node_or_null("SpriteBarricada") as Sprite2D
				if col: col.set_deferred("disabled", true)
				_efecto_polvo_en(b.global_position)
				if spr:
					var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tw.tween_property(spr, "scale", Vector2(0.2, 0.2), 0.35)
					tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.35)
					tw.tween_callback(func(): if is_instance_valid(spr): spr.visible = false)
					
	for idx in indices_emerger:
		if idx < nodos_barricadas.size():
			estados_barricadas[idx] = true
			var b = nodos_barricadas[idx]
			if b and is_instance_valid(b):
				var col = b.get_node_or_null("CollisionShape2D") as CollisionShape2D
				var spr = b.get_node_or_null("SpriteBarricada") as Sprite2D
				if col: col.set_deferred("disabled", false)
				_efecto_polvo_en(b.global_position)
				if spr:
					spr.visible = true
					spr.scale = Vector2.ZERO
					spr.modulate = Color.WHITE
					var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					tw.tween_property(spr, "scale", Vector2.ONE, 0.4)

# ==============================================================================
# SISTEMA DE PROYECTILES (PROYECTIL DESTRUCTOR DE PUESTOS Y MUROS)
# ==============================================================================

func _disparar_proyectil(pos: Vector2, dir: Vector2, vel: float = 460.0, con_rebote: bool = false, es_destructor: bool = false):
	if multiplayer.has_multiplayer_peer():
		if es_autoridad_de_partida():
			spawn_proyectil_canaduz_rpc.rpc(pos, dir, vel, con_rebote, es_destructor)
		else:
			spawn_proyectil_canaduz_rpc.rpc(pos, dir, vel, con_rebote, es_destructor)
	else:
		spawn_proyectil_canaduz_rpc(pos, dir, vel, con_rebote, es_destructor)

@rpc("any_peer", "call_remote", "reliable")
func pedir_disparo_al_servidor_rpc(pos: Vector2, dir: Vector2, vel: float, con_rebote: bool, es_destructor: bool):
	if not es_autoridad_de_partida(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != id_jefe: return
	spawn_proyectil_canaduz_rpc.rpc(pos, dir, vel, con_rebote, es_destructor)

@rpc("any_peer", "call_local", "reliable")
func spawn_proyectil_canaduz_rpc(pos: Vector2, dir: Vector2, vel: float, con_rebote: bool, es_destructor: bool):
	var p = Node2D.new()
	p.position = pos
	
	var spr = Sprite2D.new()
	if es_destructor:
		# Proyectil Gigante Destructor Fiery con aura
		spr.texture = preload("res://assets/props_clean/item_dekaball00.png")
		spr.scale = Vector2(2.1, 2.1)
		spr.modulate = Color(1.5, 0.45, 0.2)
	else:
		if not texturas_proyectiles.is_empty():
			spr.texture = texturas_proyectiles.pick_random()
		else:
			spr.texture = preload("res://assets/props_clean/item_omoball00.png")
		spr.scale = Vector2(1.4, 1.4)
		
	p.add_child(spr)
	contenedor_proyectiles.add_child(p)
	_procesar_vida_proyectil(p, spr, dir.normalized(), vel, con_rebote, es_destructor)

func _procesar_vida_proyectil(p: Node2D, spr: Sprite2D, dir_inicial: Vector2, vel_magnitud: float, con_rebote: bool, es_destructor: bool):
	var vel = dir_inicial * vel_magnitud
	var rebotes_restantes = 3 if con_rebote else 0
	var tiempo_vida = 7.0
	var rot_speed = randf_range(8.0, 14.0) * (1.0 if vel.x >= 0 else -1.0)
	
	var tree = get_tree()
	while tiempo_vida > 0.0 and is_instance_valid(p):
		var delta = get_process_delta_time()
		tiempo_vida -= delta
		p.position += vel * delta
		if is_instance_valid(spr):
			spr.rotation += rot_speed * delta
			
		# 1. Comprobar choque con Límites de la Arena
		var choco_pared = false
		if p.position.x <= ARENA_MIN_X:
			p.position.x = ARENA_MIN_X + 2.0
			vel.x = abs(vel.x)
			choco_pared = true
		elif p.position.x >= ARENA_MAX_X:
			p.position.x = ARENA_MAX_X - 2.0
			vel.x = -abs(vel.x)
			choco_pared = true
			
		if p.position.y <= ARENA_MIN_Y:
			p.position.y = ARENA_MIN_Y + 2.0
			vel.y = abs(vel.y)
			choco_pared = true
		elif p.position.y >= ARENA_MAX_Y:
			p.position.y = ARENA_MAX_Y - 2.0
			vel.y = -abs(vel.y)
			choco_pared = true
			
		# 2. Comprobar choque con Barricadas Activas
		var choco_barricada = false
		for i in range(nodos_barricadas.size()):
			if not estados_barricadas[i]: continue
			var b = nodos_barricadas[i]
			if not is_instance_valid(b): continue
			
			var b_pos = b.global_position
			var diff = p.global_position - b_pos
			
			var es_vert = (i == 1 or i == 5 or i == 7)
			var w_col = 22.0 if es_vert else 54.0
			var h_col = 54.0 if es_vert else 22.0
			
			if abs(diff.x) <= w_col and abs(diff.y) <= h_col:
				if es_destructor:
					# ¡DESTRUYE LA BARRICADA COMPLETAMENTE!
					estados_barricadas[i] = false
					_efecto_destruccion_obstaculo(b.global_position)
					b.queue_free()
					_efecto_explosion_proyectil(p.global_position)
					choco_barricada = true
					break
				else:
					if abs(diff.x) / w_col > abs(diff.y) / h_col:
						vel.x = -vel.x
					else:
						vel.y = -vel.y
					choco_barricada = true
					break
					
		# 2b. Comprobar choque con Puestos de Festival
		var choco_puesto = false
		if not choco_barricada:
			for puesto in nodos_puestos.duplicate():
				if not is_instance_valid(puesto): continue
				var diff_pst = p.global_position - puesto.global_position
				if abs(diff_pst.x) <= 46.0 and abs(diff_pst.y) <= 28.0:
					if es_destructor:
						# ¡DESTRUYE EL PUESTO DE FESTIVAL!
						nodos_puestos.erase(puesto)
						_efecto_destruccion_obstaculo(puesto.global_position)
						puesto.queue_free()
						_efecto_explosion_proyectil(p.global_position)
						choco_puesto = true
						break
					else:
						if abs(diff_pst.x) / 46.0 > abs(diff_pst.y) / 28.0:
							vel.x = -vel.x
						else:
							vel.y = -vel.y
						choco_puesto = true
						break
						
		var choco_obstaculo = choco_pared or choco_barricada or choco_puesto
		if choco_obstaculo:
			if es_destructor or not con_rebote:
				_efecto_explosion_proyectil(p.global_position)
				break
			else:
				rebotes_restantes -= 1
				_efecto_destello_impacto(p.global_position)
				if rebotes_restantes <= 0:
					_efecto_explosion_proyectil(p.global_position)
					break
					
		# 3. Comprobar Impacto Directo a Supervivientes
		var impacto_jugador = false
		for id in ids_supervivientes.duplicate():
			var av = avatares_jugadores.get(id)
			if not av or not is_instance_valid(av):
				av = obtener_avatar_jugador(id)
			if av and is_instance_valid(av) and av.visible:
				if av.global_position.distance_to(p.global_position) <= 28.0:
					_efecto_explosion_proyectil(p.global_position)
					if multiplayer.has_multiplayer_peer():
						eliminar_superviviente_rpc.rpc(id, vel.normalized())
					else:
						eliminar_superviviente_rpc(id, vel.normalized())
					impacto_jugador = true
					break
					
		if impacto_jugador:
			break
			
		await tree.process_frame
		
	if is_instance_valid(p):
		p.queue_free()

func _efecto_destello_impacto(pos: Vector2):
	if particulas_explosion:
		particulas_explosion.global_position = pos
		particulas_explosion.amount = 12
		particulas_explosion.restart()

func _efecto_explosion_proyectil(pos: Vector2):
	agitar_camara(5.0)
	if particulas_explosion:
		particulas_explosion.global_position = pos
		particulas_explosion.amount = 32
		particulas_explosion.restart()

func _efecto_destruccion_obstaculo(pos: Vector2):
	agitar_camara(9.0)
	_efecto_polvo_en(pos)
	if particulas_explosion:
		particulas_explosion.global_position = pos
		particulas_explosion.amount = 45
		particulas_explosion.restart()

func _efecto_polvo_en(pos: Vector2):
	if particulas_humo:
		particulas_humo.global_position = pos
		particulas_humo.restart()

# ==============================================================================
# ELIMINACIÓN (SUPERVIVIENTES SALEN VOLANDO FUERA DE LA PANTALLA)
# ==============================================================================

@rpc("any_peer", "call_local", "reliable")
func eliminar_superviviente_rpc(id: int, dir_impacto: Vector2 = Vector2.ZERO):
	if not ids_supervivientes.has(id): return
	ids_supervivientes.erase(id)
	var av = avatares_jugadores.get(id)
	if not av or not is_instance_valid(av):
		av = obtener_avatar_jugador(id)
	if av and is_instance_valid(av):
		av.bloquear_controles(true)
		var prefijo = av.get("prefijo_personaje") if "prefijo_personaje" in av else "SEIK"
		if prefijo == null: prefijo = "SEIK"
		if av.sprite and av.sprite.sprite_frames.has_animation(prefijo + "_impacto"):
			av.sprite.play(prefijo + "_impacto")
			
		# Salen volando con trayectoria alta fuera de la pantalla
		var dir_salida = dir_impacto.normalized()
		if dir_salida.length_squared() < 0.1:
			dir_salida = Vector2(randf_range(-1.0, 1.0), -1.3).normalized()
		else:
			dir_salida = (dir_salida + Vector2(0.0, -1.2)).normalized()
			
		var destino = av.global_position + dir_salida * 1150.0
		var rot_giro = randf_range(16.0, 24.0) * (1.0 if dir_salida.x >= 0 else -1.0)
		
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(av, "global_position", destino, 0.9)
		tw.tween_property(av, "rotation", rot_giro, 0.9)
		tw.tween_property(av, "scale", Vector2(0.35, 0.35), 0.9)
		tw.chain().tween_callback(func():
			if is_instance_valid(av):
				av.visible = false
				av.rotation = 0.0
		)
		
	actualizar_hud_supervivientes()
	if ids_supervivientes.is_empty() and not partida_terminada:
		declarar_fin_canaduz(false) # Gana el Jefe

func declarar_fin_canaduz(ganaron_supervivientes: bool):
	if partida_terminada: return
	partida_terminada = true
	
	if multiplayer.has_multiplayer_peer():
		declarar_victoria_rpc.rpc(ganaron_supervivientes)
	else:
		declarar_victoria_rpc(ganaron_supervivientes)

# ==============================================================================
# CINEMÁTICAS DE VICTORIA Y SECUENCIA FINAL
# ==============================================================================

@rpc("any_peer", "call_local", "reliable")
func declarar_victoria_rpc(ganaron_supervivientes: bool):
	partida_terminada = true
	cinematica_final_activa = true
	bloquear_jugadores(true)
	
	# Detener centinela y controles de inmediato
	if torreta_centinela:
		var cano_c = torreta_centinela.get_node_or_null("CanoCentinela")
		if cano_c: cano_c.set_process(false)
		
	var av_jefe = avatares_jugadores.get(id_jefe)
	
	if not ganaron_supervivientes:
		# ----------------------------------------------------------------------
		# CASO A: GANA EL JEFE / ARTILLERO
		# ----------------------------------------------------------------------
		# 1. Centrar la cámara en su posición actual
		var tw_cam = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_cam.tween_property(camera, "position", plataforma_jefe.global_position, 0.6)
		await tw_cam.finished
		await get_tree().create_timer(0.4).timeout
		
		# 2. El jefe y su tarima se esconden bajo tierra
		_efecto_polvo_en(plataforma_jefe.global_position)
		var tw_sink = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_sink.tween_property(plataforma_jefe, "scale", Vector2(0.2, 0.2), 0.45)
		tw_sink.tween_property(plataforma_jefe, "modulate:a", 0.0, 0.45)
		if av_jefe and is_instance_valid(av_jefe):
			tw_sink.tween_property(av_jefe, "scale", Vector2(0.2, 0.2), 0.45)
			tw_sink.tween_property(av_jefe, "modulate:a", 0.0, 0.45)
		await tw_sink.finished
		
		# 3. La cámara viaja hacia el centro del mapa
		var tw_cam_center = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_cam_center.tween_property(camera, "position", CENTRO_ARENA, 0.7)
		await tw_cam_center.finished
		await get_tree().create_timer(0.2).timeout
		
		# 4. Emerge en el centro con celebración
		plataforma_jefe.global_position = CENTRO_ARENA
		if av_jefe and is_instance_valid(av_jefe):
			av_jefe.global_position = CENTRO_ARENA + Vector2(0, -10)
		_efecto_polvo_en(CENTRO_ARENA)
		
		var tw_rise = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_rise.tween_property(plataforma_jefe, "scale", Vector2.ONE, 0.5)
		tw_rise.tween_property(plataforma_jefe, "modulate:a", 1.0, 0.5)
		if av_jefe and is_instance_valid(av_jefe):
			tw_rise.tween_property(av_jefe, "scale", Vector2.ONE, 0.5)
			tw_rise.tween_property(av_jefe, "modulate:a", 1.0, 0.5)
		await tw_rise.finished
		
		if av_jefe and is_instance_valid(av_jefe):
			var prefijo = av_jefe.get("prefijo_personaje") if "prefijo_personaje" in av_jefe else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if av_jefe.sprite and av_jefe.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
				av_jefe.sprite.play(prefijo + "_acierto")
				
		ejecutar_secuencia_victoria([id_jefe], CENTRO_ARENA)
		
	else:
		# ----------------------------------------------------------------------
		# CASO B: GANAN LOS SUPERVIVIENTES (SLAPSTICK BACKFIRE DEL ARTILLERO)
		# ----------------------------------------------------------------------
		# 1. Congelar movimientos pero no terminar de golpe; enfocar la torreta triple
		var tw_cam = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_cam.tween_property(camera, "position", plataforma_jefe.global_position, 0.6)
		await tw_cam.finished
		await get_tree().create_timer(0.4).timeout
		
		# 2. El artillero intenta disparar en vano: retrocesos secos y solo sale humo de los 3 cañones
		for intento in range(3):
			if not is_instance_valid(montura_canones): break
			var tw_click = create_tween()
			tw_click.tween_property(montura_canones, "position", Vector2(0, 6), 0.08)
			tw_click.tween_property(montura_canones, "position", Vector2.ZERO, 0.1)
			
			_efecto_polvo_en(cano_frontal.global_position)
			if cano_cono_izq.visible: _efecto_polvo_en(cano_cono_izq.global_position)
			if cano_cono_der.visible: _efecto_polvo_en(cano_cono_der.global_position)
			await get_tree().create_timer(0.38).timeout
			
		await get_tree().create_timer(0.3).timeout
		
		# 3. La torreta tiembla con sobrecalentamiento y humo negro
		if is_instance_valid(montura_canones):
			var tw_shake = create_tween().set_loops(6)
			tw_shake.tween_property(montura_canones, "rotation", montura_canones.rotation + 0.14, 0.06)
			tw_shake.tween_property(montura_canones, "rotation", montura_canones.rotation - 0.14, 0.06)
			await tw_shake.finished
			
		# 4. ¡¡¡KABOOM!!! Explosión cómica de la torreta
		_efecto_explosion_proyectil(plataforma_jefe.global_position)
		agitar_camara(14.0)
		plataforma_jefe.modulate = Color(0.25, 0.25, 0.25) # Queda calcinada
		
		# 5. El jefe sale disparado dando vueltas por los aires fuera de la pantalla
		if av_jefe and is_instance_valid(av_jefe):
			var prefijo = av_jefe.get("prefijo_personaje") if "prefijo_personaje" in av_jefe else "SEIK"
			if prefijo == null: prefijo = "SEIK"
			if av_jefe.sprite and av_jefe.sprite.sprite_frames.has_animation(prefijo + "_impacto"):
				av_jefe.sprite.play(prefijo + "_impacto")
				
			var tw_blast = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_blast.tween_property(av_jefe, "global_position", av_jefe.global_position + Vector2(randf_range(-120, 120), -950.0), 1.1)
			tw_blast.tween_property(av_jefe, "rotation", 26.0, 1.1)
			tw_blast.tween_property(av_jefe, "scale", Vector2(0.35, 0.35), 1.1)
			await tw_blast.finished
			av_jefe.visible = false
			
		await get_tree().create_timer(0.6).timeout
		
		# 6. La cámara viaja hacia el centro del mapa
		var tw_cam_back = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_cam_back.tween_property(camera, "position", CENTRO_ARENA, 0.7)
		await tw_cam_back.finished
		
		# 7. Reunir a las supervivientes en el centro con celebración
		var ganadores = []
		var spawns_finales = [
			CENTRO_ARENA + Vector2(-60, 0),
			CENTRO_ARENA + Vector2(60, 0),
			CENTRO_ARENA + Vector2(0, 50)
		]
		var idx_w = 0
		for id in jugadores_info.keys():
			if not jugadores_info[id].get("es_jefe", false):
				ganadores.append(id)
				var av_surv = avatares_jugadores.get(id)
				if av_surv and is_instance_valid(av_surv):
					av_surv.visible = true
					av_surv.modulate = Color.WHITE
					av_surv.scale = Vector2.ONE
					av_surv.global_position = spawns_finales[idx_w % spawns_finales.size()]
					idx_w += 1
					var prefijo = av_surv.get("prefijo_personaje") if "prefijo_personaje" in av_surv else "SEIK"
					if prefijo == null: prefijo = "SEIK"
					if av_surv.sprite and av_surv.sprite.sprite_frames.has_animation(prefijo + "_acierto"):
						av_surv.sprite.play(prefijo + "_acierto")
						
		ejecutar_secuencia_victoria(ganadores, CENTRO_ARENA)

# ==============================================================================
# INTELIGENCIA ARTIFICIAL EN PRUEBAS LOCALES / BOTS
# ==============================================================================

func _procesar_ia_bots_local(delta: float):
	if multiplayer.has_multiplayer_peer() or cinematica_final_activa: return
	
	for id in ids_supervivientes:
		var av = avatares_jugadores.get(id)
		if not av or not is_instance_valid(av) or not av.visible: continue
		
		var dir_escape = Vector2.ZERO
		for p in contenedor_proyectiles.get_children():
			if not is_instance_valid(p): continue
			var dist = av.global_position.distance_to(p.global_position)
			if dist < 170.0:
				dir_escape += (av.global_position - p.global_position).normalized() * (170.0 - dist)
				
		if dir_escape == Vector2.ZERO:
			if randf() < 0.03:
				av.velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 210.0
		else:
			av.velocity = dir_escape.normalized() * 320.0
			
		av.global_position.x = clamp(av.global_position.x + av.velocity.x * delta, ARENA_MIN_X + 24.0, ARENA_MAX_X - 24.0)
		av.global_position.y = clamp(av.global_position.y + av.velocity.y * delta, ARENA_MIN_Y + 24.0, ARENA_MAX_Y - 24.0)

# ==============================================================================
# MÉTODOS AUXILIARES Y HUD
# ==============================================================================

func agitar_camara(intensidad: float):
	if not camera: return
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	for i in range(3):
		tw.tween_property(camera, "offset", Vector2(randf_range(-intensidad, intensidad), randf_range(-intensidad, intensidad)), 0.04)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.04)

func _actualizar_hud_tiempo():
	if label_reloj:
		var mins = max(0, int(tiempo_restante) / 60)
		var segs = max(0, int(tiempo_restante) % 60)
		label_reloj.text = "%02d:%02d" % [mins, segs]

func actualizar_hud_supervivientes():
	if label_supervivientes:
		label_supervivientes.text = "SUPERVIVIENTES: %d" % ids_supervivientes.size()
