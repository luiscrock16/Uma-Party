extends BaseMinijuego

@onready var garra = $GarraObjeto
@onready var pinzas_contenedor = $GarraObjeto/PinzasContenedor
@onready var pinza_izq = $GarraObjeto/PinzasContenedor/PinzaIzquierda
@onready var pinza_der = $GarraObjeto/PinzasContenedor/PinzaDerecha
@onready var indicador = $GarraObjeto/IndicadorSuelo
@onready var punto_suelo: Marker2D = $GarraObjeto/IndicadorSuelo/PuntoSuelo
@onready var contenedor_peluches = $ContenedorPeluches
@onready var zona_piscina = $ZonaPiscina
@onready var zona_eliminacion = $ZonaEliminacion
@onready var bandeja_premios = get_node_or_null("BandejaPremios")
var contador_premios_sacados: int = 0

# Referencias a la UI del HUD
@onready var label_tiempo = $HUD/PanelTiempo/LabelTiempo
@onready var label_supervivientes = $HUD/LabelSupervivientes
@onready var panel_victoria = $HUD/PanelVictoria
@onready var label_victoria = $HUD/PanelVictoria/LabelVictoria

var escena_peluche = preload("res://escenas/peluche.tscn")

const ANGULO_ABIERTO: float = 35.0
const ANGULO_CERRADO: float = -20.0
const VELOCIDAD_ROTACION_PINZA: float = 10.0

var id_jefe_autorizado: int = -1

const VELOCIDAD_HORIZONTAL: float = 450.0
const VELOCIDAD_VERTICAL_MIRA: float = 350.0 

# Límites del movimiento de la garra y la mira
const LIMITE_IZQ_X: float = 130.0   # Llega directamente sobre la zona de premios
const LIMITE_DER_X: float = 1040.0  # Llega hasta el fondo de la piscina de peluches
const LIMITE_SUP_Y: float = 200.0 
const LIMITE_INF_Y: float = 560.0 

@export var estado_garra: String = "LIBRE" 
@export var destino_objetivo_y: float = 450.0 

var garra_pos_x: float = 500.0
var objeto_atrapado: Node2D = null
var objeto_candidato: Node2D = null
var angulo_visual_actual: float = ANGULO_ABIERTO 
var Y_INICIAL_PINZAS: float = 0.0

# --- CONTROL DEL TIEMPO Y REGLAS DE RONDA ---
@export var duracion_ronda: float = 45.0
var tiempo_restante: float = 45.0
var juego_activo: bool = false
var partida_finalizada: bool = false
var temporizador_peluches: float = 0.0
const CANTIDAD_OBJETIVO_PELUCHES: int = 5

func _ready():
	modo_actual = Modo.JEFE_1V3
	Global.establecer_texto_accion_tactil("ATRAPAR")
	var gl = get_node_or_null("/root/Global")
	if gl:
		gl.nodo_garra_actual = self
	indicador.top_level = true
	if pinzas_contenedor:
		Y_INICIAL_PINZAS = pinzas_contenedor.position.y
	destino_objetivo_y = indicador.global_position.y
	garra_pos_x = 500.0
	garra.global_position.x = garra_pos_x
	tiempo_restante = duracion_ronda
	
	var detector = $GarraObjeto/PinzasContenedor/AreaDetector
	if not detector.body_entered.is_connected(_on_area_detector_body_entered):
		detector.body_entered.connect(_on_area_detector_body_entered)
		
	actualizar_componentes_visuales(0.01)
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	elif not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if not get_tree().root.has_node("Lobby"):
			# Soporte para prueba directa de la escena con F6 en el editor
			id_jefe_autorizado = 1
			Global.configurar_controles_tactiles(true, true, "ATRAPAR")
			iniciar_secuencia_cuenta_atras()

func aplicar_roles_locales():
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for id in jugadores_info.keys():
		var datos = jugadores_info[id]
		var es_jefe = datos.get("es_jefe", false) or datos["spawn"] == 3
		var avatar = get_node_or_null(str(id))
		
		if es_jefe:
			id_jefe_autorizado = id
			if avatar:
				avatar.esta_usando_garra = true
				avatar.set_movimiento_actual = PersonajeJugable.TipoMovimiento.JEFE_GARRA
			if id == mi_id:
				Global.configurar_controles_tactiles(true, true, "ATRAPAR")
		else:
			if avatar:
				avatar.esta_usando_garra = false
				avatar.set_movimiento_actual = PersonajeJugable.TipoMovimiento.CON_SPRINT
			if id == mi_id:
				Global.configurar_controles_tactiles(true, true, "SPRINT")
				
	# Iniciamos la cuenta atrás antes de dar inicio a la partida
	iniciar_secuencia_cuenta_atras()

func iniciar_juego_post_cuenta_atras():
	tiempo_restante = duracion_ronda
	juego_activo = true
	partida_finalizada = false

func spawnear_peluche_en_piscina():
	if not multiplayer.is_server(): return
	var nuevo_peluche = escena_peluche.instantiate()
	nuevo_peluche.tipo_peluche = randi() % 3
	nuevo_peluche.name = "Peluche_" + str(randi())
	var pos_x = randf_range(840.0, 1050.0)
	var pos_y = randf_range(280.0, 520.0)
	nuevo_peluche.position = Vector2(pos_x, pos_y)
	contenedor_peluches.add_child(nuevo_peluche, true)

func _process(delta):
	# Actualizar la UI del tiempo en todos los clientes
	if label_tiempo:
		label_tiempo.text = "TIEMPO: %02d" % int(max(tiempo_restante, 0))
	
	# 1. ENTRADA DE INPUT: Solo la procesa el Jefe asignado si la partida está activa
	if juego_activo and id_jefe_autorizado != -1 and id_jefe_autorizado == multiplayer.get_unique_id():
		if estado_garra in ["LIBRE", "LIBRE_CON_CARGA"]:
			var direccion_x = Input.get_axis("a", "d")
			garra_pos_x += direccion_x * VELOCIDAD_HORIZONTAL * delta
			garra_pos_x = clamp(garra_pos_x, LIMITE_IZQ_X, LIMITE_DER_X)
			
			var direccion_y = Input.get_axis("w", "s")
			destino_objetivo_y += direccion_y * VELOCIDAD_VERTICAL_MIRA * delta
			destino_objetivo_y = clamp(destino_objetivo_y, LIMITE_SUP_Y, LIMITE_INF_Y)
			
			if multiplayer.is_server():
				solicitar_movimiento_servidor(garra_pos_x, destino_objetivo_y)
			else:
				rpc_id(1, "solicitar_movimiento_servidor", garra_pos_x, destino_objetivo_y)
		
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("espacio"):
			if multiplayer.is_server():
				solicitar_accion_servidor()
			else:
				rpc_id(1, "solicitar_accion_servidor")

func _physics_process(delta):
	# 2. EL SERVIDOR PROCESA LA FÍSICA, REGLAS Y SINCRONIZACIÓN
	if multiplayer.is_server():
		if juego_activo and not partida_finalizada:
			# Descontar tiempo
			tiempo_restante -= delta
			
			# Chequeo y reposición periódica de peluches en la piscina
			temporizador_peluches += delta
			if temporizador_peluches >= 2.0:
				temporizador_peluches = 0.0
				revisar_reposicion_peluches()
				
			# Evaluación de estado de supervivencia
			evaluar_condiciones_victoria()
			
			# Sincronización del temporizador a todos los clientes
			rpc("sincronizar_tiempo_rpc", tiempo_restante, contar_supervivientes_vivos())

		match estado_garra:
			"BAJANDO":
				var limite_local_y = destino_objetivo_y - garra.global_position.y
				pinzas_contenedor.position.y += 500.0 * delta
				if pinzas_contenedor.position.y >= limite_local_y:
					pinzas_contenedor.position.y = limite_local_y
					evaluar_contacto_garra()
					
			"RETORNANDO_VACIA":
				pinzas_contenedor.position.y -= 350.0 * delta
				if pinzas_contenedor.position.y <= Y_INICIAL_PINZAS:
					pinzas_contenedor.position.y = Y_INICIAL_PINZAS
					estado_garra = "LIBRE"
					
			"SOSTENIENDO":
				pinzas_contenedor.position.y -= 250.0 * delta
				if is_instance_valid(objeto_atrapado):
					objeto_atrapado.global_position = obtener_posicion_agarre()
				if pinzas_contenedor.position.y <= Y_INICIAL_PINZAS:
					pinzas_contenedor.position.y = Y_INICIAL_PINZAS
					estado_garra = "LIBRE_CON_CARGA"
					
		# Sincronización de la garra a todos los clientes
		rpc("sincronizar_garra_total", garra_pos_x, destino_objetivo_y, pinzas_contenedor.position.y, estado_garra)

	# Mover la garra y el objeto atrapado en todas las máquinas
	garra.global_position.x = garra_pos_x

	if is_instance_valid(objeto_atrapado) and estado_garra in ["SOSTENIENDO", "LIBRE_CON_CARGA"]:
		objeto_atrapado.global_position = obtener_posicion_agarre()

	var angulo_objetivo = ANGULO_ABIERTO
	if estado_garra in ["SOSTENIENDO", "LIBRE_CON_CARGA", "RETORNANDO_VACIA"] or is_instance_valid(objeto_atrapado):
		angulo_objetivo = ANGULO_CERRADO

	angulo_visual_actual = lerp(angulo_visual_actual, angulo_objetivo, VELOCIDAD_ROTACION_PINZA * delta)
	actualizar_componentes_visuales(delta)
	indicador.global_position = Vector2(garra.global_position.x, destino_objetivo_y)

# --- REPOSICIÓN Y CONTEO EN SERVIDOR ---

func revisar_reposicion_peluches():
	var peluches_en_piscina = 0
	for nodo in contenedor_peluches.get_children():
		if nodo is CharacterBody2D and zona_piscina.overlaps_body(nodo):
			peluches_en_piscina += 1
	
	if peluches_en_piscina < CANTIDAD_OBJETIVO_PELUCHES:
		spawnear_peluche_en_piscina()

func contar_supervivientes_vivos() -> int:
	var vivos = 0
	for id in jugadores_info.keys():
		if id == id_jefe_autorizado: continue
		var avatar = get_node_or_null(str(id))
		if avatar:
			if "estado_actual" in avatar and avatar.estado_actual != avatar.Estado.ELIMINADO:
				vivos += 1
	return vivos

func evaluar_condiciones_victoria():
	if partida_finalizada: return
	
	var vivos = contar_supervivientes_vivos()
	
	# Condición A: Todos los sobrevivientes han sido eliminados -> Gana el Jefe
	if vivos == 0 and jugadores_info.size() > 1:
		partida_finalizada = true
		juego_activo = false
		rpc("finalizar_partida_rpc", false)
		return
		
	# Condición B: Se acabó el tiempo y queda al menos 1 sobreviviente -> Ganan los supervivientes
	if tiempo_restante <= 0.0:
		partida_finalizada = true
		juego_activo = false
		rpc("finalizar_partida_rpc", true)

@rpc("authority", "call_local", "reliable")
func sincronizar_tiempo_rpc(t_restante: float, cant_supervivientes: int):
	tiempo_restante = t_restante
	if label_supervivientes:
		label_supervivientes.text = "Supervivientes restantes: " + str(cant_supervivientes)

@rpc("authority", "call_local", "reliable")
func finalizar_partida_rpc(ganaron_supervivientes: bool):
	juego_activo = false
	partida_finalizada = true
	
	if panel_victoria:
		panel_victoria.visible = false
		
	var ids_ganadores = []
	if ganaron_supervivientes:
		for id in jugadores_info.keys():
			if not jugadores_info[id].get("es_jefe", false):
				ids_ganadores.append(id)
	else:
		for id in jugadores_info.keys():
			if jugadores_info[id].get("es_jefe", false):
				ids_ganadores.append(id)
		if ids_ganadores.is_empty() and id_jefe_autorizado > 0:
			ids_ganadores.append(id_jefe_autorizado)
			
	ejecutar_secuencia_victoria(ids_ganadores, Vector2(576.0, 480.0))

# --- ACCIONES DE LA GARRA ---

@rpc("any_peer", "call_local", "unreliable")
func solicitar_movimiento_servidor(nueva_x: float, nueva_y: float):
	if multiplayer.is_server():
		garra_pos_x = nueva_x
		destino_objetivo_y = nueva_y

@rpc("any_peer", "call_local", "reliable")
func solicitar_accion_servidor():
	if multiplayer.is_server():
		if estado_garra == "LIBRE":
			objeto_candidato = null
			estado_garra = "BAJANDO"
		elif estado_garra == "LIBRE_CON_CARGA":
			soltar_carga()

@rpc("any_peer", "call_local", "unreliable")
func sincronizar_garra_total(pos_x: float, dest_y: float, pinza_y: float, estado: String):
	if multiplayer.is_server(): return
	if multiplayer.get_unique_id() != id_jefe_autorizado:
		garra_pos_x = pos_x
		destino_objetivo_y = dest_y
	pinzas_contenedor.position.y = pinza_y
	estado_garra = estado
	
	if estado_garra == "SOSTENIENDO" and is_instance_valid(objeto_atrapado):
		objeto_atrapado.global_position = obtener_posicion_agarre()

func obtener_posicion_agarre() -> Vector2:
	return Vector2(garra.global_position.x, pinzas_contenedor.global_position.y + 50)

# Comprueba si un cuerpo cumple las condiciones y está exactamente en la mira del suelo
func es_candidato_valido(nodo: Node, pos_mira: Vector2) -> bool:
	if not is_instance_valid(nodo) or not (nodo is Node2D):
		return false
		
	# No agarrar al jefe que maneja la garra
	if str(nodo.name).is_valid_int() and nodo.name.to_int() == id_jefe_autorizado:
		return false
		
	# No agarrar objetos ya eliminados o en plena caída
	if "estado_actual" in nodo and nodo.estado_actual == nodo.Estado.ELIMINADO:
		return false
	if "en_caida_libre" in nodo and nodo.en_caida_libre:
		return false
		
	var es_jugador = nodo.is_in_group("Jugador") or nodo.has_method("recibir_golpe_externo_rpc")
	var es_peluche = nodo.is_in_group("Peluche") or ("esta_atrapado" in nodo and not es_jugador)
	if not (es_jugador or es_peluche):
		return false
		
	# VALIDACIÓN ESTRICTA DE LA MIRA:
	# El objeto debe coincidir con la posición del marcador en el suelo (tanto X como Y)
	var dist_x = abs(nodo.global_position.x - pos_mira.x)
	var dist_y = abs(nodo.global_position.y - pos_mira.y)
	
	# Margen de tolerancia para capturar lo que esté bajo el indicador
	return dist_x <= 48.0 and dist_y <= 50.0

func _on_area_detector_body_entered(body: Node):
	if estado_garra == "BAJANDO":
		var pos_mira = Vector2(garra.global_position.x, destino_objetivo_y)
		# Solo se toma en cuenta si está en el punto exacto de la mira
		if es_candidato_valido(body, pos_mira):
			objeto_candidato = body

func evaluar_contacto_garra():
	var pos_mira = Vector2(garra.global_position.x, destino_objetivo_y)
	var candidatos_encontrados: Array[Node2D] = []
	
	# 1. Chequeo por AreaDetector físico
	var detector = $GarraObjeto/PinzasContenedor/AreaDetector
	for b in detector.get_overlapping_bodies():
		if es_candidato_valido(b, pos_mira) and not candidatos_encontrados.has(b):
			candidatos_encontrados.append(b)
			
	# 2. Chequeo por objeto_candidato que entró en la mira
	if is_instance_valid(objeto_candidato) and es_candidato_valido(objeto_candidato, pos_mira):
		if not candidatos_encontrados.has(objeto_candidato):
			candidatos_encontrados.append(objeto_candidato)
			
	# 3. Búsqueda de proximidad directa bajo la mira en caso de retraso en broadphase física
	for jugador in get_tree().get_nodes_in_group("Jugador"):
		if es_candidato_valido(jugador, pos_mira) and not candidatos_encontrados.has(jugador):
			candidatos_encontrados.append(jugador)
			
	for peluche in get_tree().get_nodes_in_group("Peluche"):
		if es_candidato_valido(peluche, pos_mira) and not candidatos_encontrados.has(peluche):
			candidatos_encontrados.append(peluche)
			
	# Seleccionar el objeto más cercano al centro exacto de la mira
	var candidato_final: Node2D = null
	var menor_distancia: float = 99999.0
	for c in candidatos_encontrados:
		var dist = c.global_position.distance_to(pos_mira)
		if dist < menor_distancia:
			menor_distancia = dist
			candidato_final = c
			
	if is_instance_valid(candidato_final):
		objeto_atrapado = candidato_final
		objeto_atrapado.global_position = obtener_posicion_agarre()
		
		if objeto_atrapado.has_method("sincronizar_atrapado_rpc"):
			objeto_atrapado.rpc("sincronizar_atrapado_rpc", true)
		elif "esta_atrapado" in objeto_atrapado:
			objeto_atrapado.esta_atrapado = true
			
		estado_garra = "SOSTENIENDO"
		rpc("notificar_objeto_atrapado_clientes", objeto_atrapado.get_path())
	else:
		estado_garra = "RETORNANDO_VACIA"
		rpc("notificar_objeto_atrapado_clientes", NodePath(""))
		
	objeto_candidato = null

func soltar_carga():
	if is_instance_valid(objeto_atrapado):
		var altura_suelo_y = punto_suelo.global_position.y
		
		# 1. Notificamos que ya no está atrapado
		if objeto_atrapado.has_method("sincronizar_atrapado_rpc"):
			objeto_atrapado.rpc("sincronizar_atrapado_rpc", false)
		elif "esta_atrapado" in objeto_atrapado:
			objeto_atrapado.esta_atrapado = false
			
		# 2. Iniciar caída libre
		if objeto_atrapado.has_method("iniciar_caida_libre_rpc"):
			objeto_atrapado.rpc("iniciar_caida_libre_rpc", altura_suelo_y)
		else:
			if "destino_y_caida" in objeto_atrapado:
				objeto_atrapado.destino_y_caida = altura_suelo_y
			if "en_caida_libre" in objeto_atrapado:
				objeto_atrapado.en_caida_libre = true
			
	objeto_atrapado = null
	objeto_candidato = null
	estado_garra = "LIBRE"
	rpc("notificar_objeto_atrapado_clientes", NodePath(""))

func actualizar_componentes_visuales(delta: float):
	if pinza_izq and pinza_der:
		pinza_izq.rotation = deg_to_rad(-angulo_visual_actual)
		pinza_der.rotation = deg_to_rad(angulo_visual_actual)
	if indicador:
		indicador.rotation += 1.8 * delta

@rpc("any_peer", "call_local", "reliable")
func notificar_objeto_atrapado_clientes(ruta_nodo: NodePath):
	if multiplayer.is_server(): return
	if ruta_nodo == NodePath(""):
		objeto_atrapado = null
	else:
		objeto_atrapado = get_node_or_null(ruta_nodo)

func _on_zona_eliminacion_body_entered(body: Node2D):
	if body.is_in_group("Jugador"):
		body.esta_en_zona_eliminacion = true

func _on_zona_eliminacion_body_exited(body: Node2D):
	if body.is_in_group("Jugador"):
		body.esta_en_zona_eliminacion = false

func registrar_premio_peluche(tipo: int):
	rpc("agregar_premio_bandeja_rpc", "peluche", tipo, -1)

func registrar_jugador_atrapado(id_jugador: int):
	rpc("agregar_premio_bandeja_rpc", "jugador", 0, id_jugador)

@rpc("any_peer", "call_local", "reliable")
func agregar_premio_bandeja_rpc(tipo_item: String, subtipo: int, id_jugador: int):
	if not bandeja_premios:
		bandeja_premios = get_node_or_null("BandejaPremios")
	if not bandeja_premios: return
	
	contador_premios_sacados += 1
	var total = bandeja_premios.get_child_count()
	var offset_x = (total % 4) * 36.0 - 54.0 + randf_range(-4.0, 4.0)
	var offset_y = randf_range(-3.0, 3.0)
	
	if tipo_item == "peluche":
		var spr = Sprite2D.new()
		spr.scale = Vector2(0.55, 0.55)
		spr.position = Vector2(offset_x, -40.0) # Aparece cayendo por el chute
		match subtipo:
			0: spr.texture = preload("res://assets/minijuego_garra/peluche_0_suzuka.png")
			1: spr.texture = preload("res://assets/minijuego_garra/peluche_1_zanahoria.png")
			2: spr.texture = preload("res://assets/minijuego_garra/peluche_2_caballito.png")
			_: spr.texture = preload("res://assets/minijuego_garra/peluche_0_suzuka.png")
		bandeja_premios.add_child(spr)
		var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "position:y", offset_y, 0.45)
	elif tipo_item == "jugador":
		var spr = Sprite2D.new()
		spr.scale = Vector2(0.65, 0.65)
		spr.position = Vector2(offset_x, -40.0)
		var avatar = get_node_or_null(str(id_jugador))
		if avatar and "sprite" in avatar and avatar.sprite.sprite_frames:
			var anim_derrota = avatar.prefijo_personaje + "_derrota"
			if avatar.sprite.sprite_frames.has_animation(anim_derrota):
				spr.texture = avatar.sprite.sprite_frames.get_frame_texture(anim_derrota, 0)
			else:
				spr.texture = avatar.sprite.sprite_frames.get_frame_texture(avatar.prefijo_personaje + "_idle", 0)
		bandeja_premios.add_child(spr)
		var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "position:y", offset_y, 0.45)
