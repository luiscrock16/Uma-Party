extends BaseMinijuego

@onready var contenedor_plataformas = $ContenedorPlataformas
@onready var contenedor_proyectiles = $ContenedorProyectiles
@onready var contenedor_muros = $MurosRebote
@onready var camera = $Camera2D
@onready var plataforma_directora = get_node_or_null("PlataformaDirectora")
@onready var engranaje_central = $TorreCastillo/FosoCentral/EngranajeCentral
@onready var estatua_centro = $TorreCastillo/FosoCentral/EstatuaCentro
@onready var nubes_contenedor = $FondoCielo/NubesContenedor
@onready var panel_alerta = $HUD/PanelAlerta
@onready var label_alerta = $HUD/PanelAlerta/LabelAlerta

# Paneles del HUD en las 4 esquinas
@onready var hud_panels = [
	$HUD/PanelTL,
	$HUD/PanelTR,
	$HUD/PanelBL,
	$HUD/PanelBR
]

var escena_proyectil = preload("res://escenas/proyectil_canon.tscn")

var plataformas: Array[PlataformaCanon] = []
var dict_jugador_plataforma: Dictionary = {} # id: PlataformaCanon
var partida_iniciada: bool = false
var partida_terminada: bool = false
var timer_sync_rot: float = 0.4
var tiempo_partida: float = 0.0
var fase_escalacion: int = 1

const COLORES_JUGADORES = [
	Color("#ff4757"), # P1: Rojo
	Color("#2ed573"), # P2: Verde
	Color("#1e90ff"), # P3: Azul
	Color("#ffa502")  # P4: Naranja / Amarillo
]

func _ready():
	modo_actual = Modo.FFA
	Global.configurar_controles_tactiles(false, true, "DISPARAR")
	tiempo_partida = 0.0
	fase_escalacion = 1
	
	# Configurar muros circulares de rebote
	configurar_muros_rebote()
					
	if panel_alerta:
		panel_alerta.visible = false
	
	# Recopilar las 4 plataformas de la escena
	plataformas.clear()
	for child in contenedor_plataformas.get_children():
		if child is PlataformaCanon:
			plataformas.append(child)
			
	# Ocultar paneles de HUD inicialmente
	for p in hud_panels:
		p.visible = false
		
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
		jugadores_info[id] = {"equipo": i, "spawn": i, "es_jefe": false}
		
		if not has_node(str(id)):
			var av = preload("res://escenas/personaje_jugable.tscn").instantiate()
			av.name = str(id)
			add_child(av)
			av.configurar_visual(i % 4, "P" + str(i + 1))
			
	aplicar_roles_locales()

func _process(delta):
	# Rotación sutil de engranajes del foso central para dar vida al escenario
	if engranaje_central:
		engranaje_central.rotation += 0.4 * delta
	if estatua_centro:
		estatua_centro.rotation -= 0.25 * delta
		
	# Deriva continua de las nubes en el cielo
	if nubes_contenedor:
		for nube in nubes_contenedor.get_children():
			nube.position.x += 18.0 * delta
			if nube.position.x > 1250.0:
				nube.position.x = -150.0

	# Sincronización continua de rotaciones desde el servidor para evitar cualquier desfase
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and partida_iniciada and not partida_terminada:
		timer_sync_rot -= delta
		if timer_sync_rot <= 0.0:
			timer_sync_rot = 0.4
			var rot_dict = {}
			for id in dict_jugador_plataforma:
				var p = dict_jugador_plataforma[id]
				if not p.eliminada:
					rot_dict[id] = p.montura.rotation
			rpc("sincronizar_rotaciones_rpc", rot_dict)

	# Escalación progresiva de la partida (30s: más velocidad, 60s: velocidad x2 + muros de rebote)
	if partida_iniciada and not partida_terminada:
		if Input.is_action_just_pressed("espacio") or Input.is_action_just_pressed("ui_accept"):
			intentar_disparar_local()
			
		var es_autoridad = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
		if es_autoridad:
			tiempo_partida += delta
			if tiempo_partida >= 60.0 and fase_escalacion == 2:
				fase_escalacion = 3
				if multiplayer.has_multiplayer_peer():
					rpc("activar_fase_escalacion_rpc", 3)
				else:
					activar_fase_escalacion_rpc(3)
			elif tiempo_partida >= 30.0 and fase_escalacion == 1:
				fase_escalacion = 2
				if multiplayer.has_multiplayer_peer():
					rpc("activar_fase_escalacion_rpc", 2)
				else:
					activar_fase_escalacion_rpc(2)


func intentar_disparar_local():
	if not partida_iniciada or partida_terminada: return
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if mi_id in dict_jugador_plataforma:
		var mi_plat = dict_jugador_plataforma[mi_id]
		if mi_plat.puede_disparar():
			if multiplayer.has_multiplayer_peer():
				rpc_id(1, "solicitar_disparo_rpc", mi_id, mi_plat.montura.rotation)
			else:
				mi_plat.disparar()

func _unhandled_input(event):
	if event.is_action_pressed("espacio") or event.is_action_pressed("ui_accept"):
		intentar_disparar_local()

# --- INICIALIZACIÓN Y ANIMACIÓN DE ENTRADA CON ZOOM ---

func aplicar_roles_locales():
	dict_jugador_plataforma.clear()
	jugadores_vivos.clear()
	
	# Sentidos de giro alternados para las 4 plataformas
	var sentidos = [1.0, -1.0, -1.0, 1.0]
	
	for id in jugadores_info.keys():
		jugadores_vivos.append(id)
		var datos = jugadores_info[id]
		var spawn_idx = datos["spawn"]
		
		if spawn_idx < plataformas.size():
			var plat = plataformas[spawn_idx]
			dict_jugador_plataforma[id] = plat
			
			var avatar = get_node_or_null(str(id))
			var col = COLORES_JUGADORES[spawn_idx % COLORES_JUGADORES.size()]
			var sentido = sentidos[spawn_idx % sentidos.size()]
			
			plat.configurar(id, col, avatar, sentido)
			
			# Conexión de disparo para instanciar proyectil
			if not plat.proyectil_disparado.is_connected(_on_plataforma_disparo):
				plat.proyectil_disparado.connect(_on_plataforma_disparo)
				
			# Conexión de impacto en el servidor
			if not plat.jugador_golpeado.is_connected(_on_plataforma_golpeada):
				plat.jugador_golpeado.connect(_on_plataforma_golpeada)
				
			# Configurar HUD correspondiente
			configurar_hud_jugador(spawn_idx, id, col, avatar)
			
	# Ocultar plataformas no utilizadas si hay menos de 4 jugadores
	for i in range(plataformas.size()):
		var ocupada = false
		for plat in dict_jugador_plataforma.values():
			if plat == plataformas[i]:
				ocupada = true
				break
		if not ocupada:
			plataformas[i].visible = false
			plataformas[i].process_mode = Node.PROCESS_MODE_DISABLED
			
	# ANIMACIÓN DE ENTRADA CON ZOOM EN EL PROPIO PERSONAJE
	ejecutar_intro_zoom_jugador()

func configurar_hud_jugador(idx: int, id: int, col: Color, _avatar: Node2D):
	if idx >= hud_panels.size(): return
	var panel = hud_panels[idx]
	panel.visible = true
	
	var label_nombre = panel.get_node_or_null("Margen/HBox/VBox/LabelNombre")
	if label_nombre:
		var nombre = obtener_nombre_jugador(id)
		label_nombre.text = nombre
		label_nombre.modulate = col
		
	# Las 3 vidas en blanco al inicio
	actualizar_vidas_hud(idx, 3)

func actualizar_vidas_hud(idx: int, vidas: int):
	if idx >= hud_panels.size(): return
	var contenedor_vidas = hud_panels[idx].get_node_or_null("Margen/HBox/VBox/HBoxVidas")
	if not contenedor_vidas: return
	
	var puntos = contenedor_vidas.get_children()
	for i in range(puntos.size()):
		if i < vidas:
			puntos[i].modulate = Color.WHITE
		else:
			puntos[i].modulate = Color(0.25, 0.25, 0.35, 0.4)

func ejecutar_intro_zoom_jugador():
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var plat_objetivo: PlataformaCanon = null
	
	if mi_id in dict_jugador_plataforma:
		plat_objetivo = dict_jugador_plataforma[mi_id]
	elif not plataformas.is_empty():
		plat_objetivo = plataformas[0]
		
	if plat_objetivo and camera:
		# Comienza con zoom cercano centrado en su propio personaje y se queda fijo ahí durante las instrucciones
		camera.position = plat_objetivo.global_position
		camera.zoom = Vector2(2.4, 2.4)
		
	# Iniciar instrucciones y cuenta atrás global
	iniciar_secuencia_cuenta_atras()

func al_completar_instrucciones():
	# La animación de alejamiento cinematográfico solo ocurre cuando todos han confirmado las instrucciones
	if camera:
		var tween_intro = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween_intro.tween_property(camera, "position", Vector2(576, 324), 2.2)
		tween_intro.tween_property(camera, "zoom", Vector2(1.0, 1.0), 2.2)

func iniciar_juego_post_cuenta_atras():
	if plataforma_directora and plataforma_directora.has_method("iniciar_vuelo"):
		plataforma_directora.iniciar_vuelo()
	partida_iniciada = true
	tiempo_partida = 0.0
	fase_escalacion = 1
	for plat in dict_jugador_plataforma.values():
		plat.activar_combate()

# --- SISTEMA DE ESCALACIÓN Y MUERTE SÚBITA ---

@rpc("authority", "call_local", "reliable")
func activar_fase_escalacion_rpc(nueva_fase: int):
	fase_escalacion = nueva_fase
	if plataforma_directora and is_instance_valid(plataforma_directora) and plataforma_directora.has_method("ejecutar_secuencia_fase"):
		plataforma_directora.ejecutar_secuencia_fase(nueva_fase, func():
			aplicar_cambios_fase(nueva_fase)
		)
	else:
		aplicar_cambios_fase(nueva_fase)

func aplicar_cambios_fase(nueva_fase: int):
	if nueva_fase == 2:
		# Fase 2 (30s): Aumento leve de velocidad para meter presión
		for plat in dict_jugador_plataforma.values():
			if not plat.eliminada:
				plat.set_velocidad_giro(4.2)
	elif nueva_fase == 3:
		# Fase 3 (60s): Muerte Súbita -> Velocidad duplicada + Muros perimetrales de rebote
		for plat in dict_jugador_plataforma.values():
			if not plat.eliminada:
				plat.set_velocidad_giro(5.8)
		elevar_muros_rebote()
		ejecutar_temblor_camara(0.5, 4.5)

func configurar_muros_rebote():
	if not contenedor_muros: return
	contenedor_muros.visible = false
	contenedor_muros.position = Vector2(576, 330)
	contenedor_muros.set_meta("es_muro_rebote", true)
	contenedor_muros.set_meta("centro_torre", Vector2(576, 330))
	
	# Limpiar shapes previos si existiesen
	for hijo in contenedor_muros.get_children():
		if hijo is CollisionShape2D:
			hijo.queue_free()
			
	# Generar los 16 segmentos que siguen el contorno circular sobresaliendo de MuroExterior (R=340)
	var radio_muro = 340.0
	var segmentos = 16
	var paso_angulo = TAU / float(segmentos)
	var longitud_segmento = (2.0 * radio_muro * sin(paso_angulo / 2.0)) + 14.0
	
	for i in range(segmentos):
		var angulo = (i * paso_angulo) + (paso_angulo / 2.0)
		var pos_seg = Vector2(cos(angulo), sin(angulo)) * radio_muro
		
		var col_shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(longitud_segmento, 28.0)
		col_shape.shape = rect
		col_shape.position = pos_seg
		col_shape.rotation = angulo + (PI / 2.0)
		col_shape.disabled = true
		contenedor_muros.add_child(col_shape)

func elevar_muros_rebote():
	if not contenedor_muros: return
	contenedor_muros.visible = true
	
	# Activar los 16 segmentos de colisión del perímetro
	for hijo in contenedor_muros.get_children():
		if hijo is CollisionShape2D:
			hijo.set_deferred("disabled", false)
				
	# Animación de emergencia desde el suelo con rebote
	contenedor_muros.scale = Vector2(0.92, 0.92)
	contenedor_muros.modulate.a = 0.0
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(contenedor_muros, "scale", Vector2(1.0, 1.0), 0.5)
	tween.parallel().tween_property(contenedor_muros, "modulate:a", 1.0, 0.35)

func mostrar_alerta_escalacion(texto: String, col: Color):
	if not label_alerta or not panel_alerta: return
	label_alerta.text = texto
	label_alerta.modulate = col
	panel_alerta.visible = true
	panel_alerta.modulate.a = 0.0
	panel_alerta.scale = Vector2(0.6, 0.6)
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_alerta, "scale", Vector2(1.08, 1.08), 0.22)
	tween.parallel().tween_property(panel_alerta, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel_alerta, "scale", Vector2(1.0, 1.0), 0.12)
	tween.tween_interval(1.8)
	tween.tween_property(panel_alerta, "modulate:a", 0.0, 0.35)
	await tween.finished
	if panel_alerta.modulate.a <= 0.05:
		panel_alerta.visible = false

func ejecutar_temblor_camara(duracion: float, intensidad: float):
	if not camera: return
	var pos_original = Vector2(576, 324)
	var tween = create_tween()
	var pasos = int(duracion / 0.05)
	for i in range(pasos):
		var offset = Vector2(randf_range(-intensidad, intensidad), randf_range(-intensidad, intensidad))
		tween.tween_property(camera, "position", pos_original + offset, 0.04)
	tween.tween_property(camera, "position", pos_original, 0.05)

# --- SISTEMA DE DISPARO SINCRONIZADO ---

@rpc("any_peer", "call_local", "reliable")
func solicitar_disparo_rpc(id_jugador: int, angulo_rot: float):
	if not multiplayer.is_server(): return
	if not partida_iniciada or partida_terminada: return
	if not (id_jugador in dict_jugador_plataforma): return
	
	var plat = dict_jugador_plataforma[id_jugador]
	if plat.puede_disparar():
		rpc("ejecutar_disparo_rpc", id_jugador, angulo_rot)

@rpc("authority", "call_local", "reliable")
func ejecutar_disparo_rpc(id_jugador: int, angulo_rot: float):
	if id_jugador in dict_jugador_plataforma:
		dict_jugador_plataforma[id_jugador].disparar(angulo_rot)

func _on_plataforma_disparo(id_dueno: int, pos_global: Vector2, rot_global: float):
	# Instanciar el proyectil Bullet Bill en el contenedor
	var proyectil = escena_proyectil.instantiate()
	contenedor_proyectiles.add_child(proyectil)
	proyectil.inicializar(id_dueno, pos_global, rot_global)

@rpc("authority", "unreliable")
func sincronizar_rotaciones_rpc(rot_dict: Dictionary):
	if multiplayer.is_server(): return
	for id in rot_dict:
		if id in dict_jugador_plataforma:
			var plat = dict_jugador_plataforma[id]
			if plat.activa and not plat.detenida and not plat.eliminada:
				plat.montura.rotation = lerp_angle(plat.montura.rotation, rot_dict[id], 0.3)

# --- DAÑO, VIDAS Y ELIMINACIÓN ---

func _on_plataforma_golpeada(id_jugador: int, vidas_restantes: int):
	# Se ejecuta en el servidor cuando el proyectil impacta directamente al personaje
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return
	if not (id_jugador in dict_jugador_plataforma): return
	
	var eliminado = (vidas_restantes <= 0)
	
	if multiplayer.has_multiplayer_peer():
		rpc("sincronizar_impacto_rpc", id_jugador, vidas_restantes, eliminado)
	else:
		sincronizar_impacto_rpc(id_jugador, vidas_restantes, eliminado)
	
	if eliminado:
		jugadores_vivos.erase(id_jugador)
		verificar_fin_partida()

@rpc("authority", "call_local", "reliable")
func sincronizar_impacto_rpc(id_jugador: int, vidas_restantes: int, eliminado: bool):
	if id_jugador in dict_jugador_plataforma:
		var plat = dict_jugador_plataforma[id_jugador]
		plat.vidas = vidas_restantes
		
		# Reacción visual y de estado para todos los clientes y servidor
		if eliminado:
			if not plat.eliminada:
				plat.eliminar_plataforma()
		else:
			plat.parpadear_invulnerabilidad()
			
		# Actualizar vidas en el HUD de la esquina para todos
		if id_jugador in jugadores_info:
			var spawn_idx = jugadores_info[id_jugador]["spawn"]
			actualizar_vidas_hud(spawn_idx, vidas_restantes)

func verificar_fin_partida():
	if partida_terminada: return
	
	if jugadores_vivos.size() <= 1:
		partida_terminada = true
		var id_ganador = jugadores_vivos[0] if jugadores_vivos.size() > 0 else 1
		await get_tree().create_timer(1.0).timeout
		if multiplayer.has_multiplayer_peer():
			rpc("declarar_ganador_canones_rpc", id_ganador)
		else:
			declarar_ganador_canones_rpc(id_ganador)

@rpc("authority", "call_local", "reliable")
func declarar_ganador_canones_rpc(id_ganador: int):
	partida_terminada = true
	if panel_alerta:
		panel_alerta.visible = false
	
	var pos_celebracion = Vector2(576, 330)
	if id_ganador in dict_jugador_plataforma:
		var plat_ganadora = dict_jugador_plataforma[id_ganador]
		plat_ganadora.festejar_victoria()
		pos_celebracion = plat_ganadora.global_position
		
	# Bloquear controles de todos los espectadores en globo durante la celebración
	for plat in plataformas:
		if plat.avatar_asignado and is_instance_valid(plat.avatar_asignado):
			plat.avatar_asignado.bloquear_controles(true)
		
	# Usamos el sistema de victoria oficial estilo Mario Party de BaseMinijuego
	ejecutar_secuencia_victoria([id_ganador], pos_celebracion)
