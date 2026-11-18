extends BaseMinijuego

enum EstadoTorneo {
	INTRO,
	SEMIFINALES,
	TRANSICION_FINAL,
	GRAN_FINAL,
	VICTORIA
}

enum Opcion { PIEDRA = 0, PAPEL = 1, TIJERAS = 2 }

@onready var camera: Camera2D = $Camera2D

# HUD Superior y Anuncios
@onready var hud = $HUD
@onready var label_anuncio_centro = $HUD/AnuncioCentro/LabelAnuncio
@onready var panel_anuncio_centro = $HUD/AnuncioCentro

# HUD Semifinal Mesa A (Izquierda)
@onready var panel_mesa_a = $HUD/PanelMesaA
@onready var label_nom_a1 = $HUD/PanelMesaA/Margen/VBox/HBoxNombres/LabelNom1
@onready var label_nom_a2 = $HUD/PanelMesaA/Margen/VBox/HBoxNombres/LabelNom2
@onready var label_estrellas_a1 = $HUD/PanelMesaA/Margen/VBox/HBoxEstrellas/LabelEstrellas1
@onready var label_estrellas_a2 = $HUD/PanelMesaA/Margen/VBox/HBoxEstrellas/LabelEstrellas2

# HUD Semifinal Mesa B (Derecha)
@onready var panel_mesa_b = $HUD/PanelMesaB
@onready var label_nom_b1 = $HUD/PanelMesaB/Margen/VBox/HBoxNombres/LabelNom1
@onready var label_nom_b2 = $HUD/PanelMesaB/Margen/VBox/HBoxNombres/LabelNom2
@onready var label_estrellas_b1 = $HUD/PanelMesaB/Margen/VBox/HBoxEstrellas/LabelEstrellas1
@onready var label_estrellas_b2 = $HUD/PanelMesaB/Margen/VBox/HBoxEstrellas/LabelEstrellas2

# HUD Gran Final (Centro)
@onready var panel_final = $HUD/PanelFinal
@onready var label_nom_fin1 = $HUD/PanelFinal/Margen/VBox/HBoxNombres/LabelNom1
@onready var label_nom_fin2 = $HUD/PanelFinal/Margen/VBox/HBoxNombres/LabelNom2
@onready var label_estrellas_fin1 = $HUD/PanelFinal/Margen/VBox/HBoxEstrellas/LabelEstrellas1
@onready var label_estrellas_fin2 = $HUD/PanelFinal/Margen/VBox/HBoxEstrellas/LabelEstrellas2

# Botones de selección para jugador local
@onready var panel_botones_jugador = $HUD/PanelBotonesJugador
@onready var label_prompt = $HUD/PanelBotonesJugador/Margen/VBox/LabelPrompt
@onready var btn_piedra = $HUD/PanelBotonesJugador/Margen/VBox/HBox/BtnPiedra
@onready var btn_papel = $HUD/PanelBotonesJugador/Margen/VBox/HBox/BtnPapel
@onready var btn_tijeras = $HUD/PanelBotonesJugador/Margen/VBox/HBox/BtnTijeras

# Cartas flotantes en la escena
@onready var carta_a1: CartaJanken = $Cartas/CartaA1
@onready var carta_a2: CartaJanken = $Cartas/CartaA2
@onready var carta_b1: CartaJanken = $Cartas/CartaB1
@onready var carta_b2: CartaJanken = $Cartas/CartaB2

# Focos / Efectos visuales de pista
@onready var ring_centro = $Escenario/RingCentral
@onready var foco_centro = $Escenario/FocoCentro
@onready var particulas_victoria = $ParticulasVictoria

# Estado general del torneo
var estado_actual_torneo: EstadoTorneo = EstadoTorneo.INTRO
var eleccion_local: int = -1
var tiempo_seleccion_restante: float = 0.0
var tween_camara: Tween = null

# Diccionario de elecciones en el servidor: { id_jugador: opcion }
var elecciones_recibidas: Dictionary = {}

# Participantes
var id_a1: int = 1 # Equipo Rojo
var id_a2: int = 3 # Equipo Azul
var id_b1: int = 2 # Equipo Rojo
var id_b2: int = 4 # Equipo Azul

var puntos_a1: int = 0
var puntos_a2: int = 0
var puntos_b1: int = 0
var puntos_b2: int = 0

var ganador_mesa_a: int = -1
var ganador_mesa_b: int = -1

var finalista_1: int = -1
var finalista_2: int = -1
var puntos_fin1: int = 0
var puntos_fin2: int = 0
var campeon_torneo: int = -1

# Coordenadas clave
const POS_A1 = Vector2(210, 365)
const POS_A2 = Vector2(370, 365)
const POS_B1 = Vector2(782, 365)
const POS_B2 = Vector2(942, 365)

const POS_FINAL_1 = Vector2(506, 365)
const POS_FINAL_2 = Vector2(646, 365)

const POS_BANCA_A = Vector2(150, 520)
const POS_BANCA_B = Vector2(1002, 520)

const POS_HERRADURA = Vector2(576, 385)
const POS_PERDEDORES = [
	Vector2(436, 520),
	Vector2(576, 520),
	Vector2(716, 520)
]

# Coordenadas y zooms de cámaras
const POS_CAM_MESA_A = Vector2(290, 350)
const POS_CAM_MESA_B = Vector2(862, 350)
const POS_CAM_FINAL = Vector2(576, 350)

const ZOOM_MESA = Vector2(1.5, 1.5)
const ZOOM_FINAL = Vector2(1.28, 1.28)

func _ready():
	modo_actual = Modo.FFA
	Global.configurar_controles_tactiles(false, false)
	panel_final.visible = false
	if panel_anuncio_centro:
		panel_anuncio_centro.visible = false
		panel_anuncio_centro.modulate.a = 0.0
	foco_centro.visible = false
	panel_botones_jugador.visible = false
	
	conectar_botones()
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func es_servidor_o_solo() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return es_autoridad_de_partida()

func obtener_mi_id_local() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1

func conectar_botones():
	if btn_piedra:
		btn_piedra.pressed.connect(func(): _on_boton_humano_pulsado(Opcion.PIEDRA))
	if btn_papel:
		btn_papel.pressed.connect(func(): _on_boton_humano_pulsado(Opcion.PAPEL))
	if btn_tijeras:
		btn_tijeras.pressed.connect(func(): _on_boton_humano_pulsado(Opcion.TIJERAS))

func _on_boton_humano_pulsado(opcion: int):
	eleccion_local = opcion
	resaltar_boton_seleccionado(opcion)
	var mi_id = obtener_mi_id_local()
	if multiplayer.has_multiplayer_peer():
		enviar_eleccion_al_servidor_rpc.rpc(mi_id, opcion)
	else:
		enviar_eleccion_al_servidor_rpc(mi_id, opcion)

@rpc("any_peer", "call_local")
func enviar_eleccion_al_servidor_rpc(id_jugador: int, opcion: int):
	if es_servidor_o_solo():
		elecciones_recibidas[id_jugador] = opcion

func _unhandled_input(event: InputEvent):
	if not panel_botones_jugador.visible: return
	
	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_1 or event.keycode == KEY_A)):
		_on_boton_humano_pulsado(Opcion.PIEDRA)
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_2 or event.keycode == KEY_W)):
		_on_boton_humano_pulsado(Opcion.PAPEL)
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_3 or event.keycode == KEY_D)):
		_on_boton_humano_pulsado(Opcion.TIJERAS)

func _process(delta):
	if panel_botones_jugador.visible and tiempo_seleccion_restante > 0.0:
		tiempo_seleccion_restante -= delta
		if label_prompt:
			label_prompt.text = "⏱️ ¡ELIGE TU JUGADA! (%.1fs) ⏱️" % max(0.0, tiempo_seleccion_restante)
		if tiempo_seleccion_restante <= 0.0:
			tiempo_seleccion_restante = 0.0
			# Si el jugador no seleccionó nada a tiempo, elegir una opción por defecto
			if eleccion_local == -1:
				_on_boton_humano_pulsado(randi() % 3)

func resaltar_boton_seleccionado(opcion: int):
	var btns = [btn_piedra, btn_papel, btn_tijeras]
	for i in range(btns.size()):
		if btns[i]:
			if i == opcion:
				btns[i].modulate = Color(1.3, 1.3, 1.3)
			else:
				btns[i].modulate = Color(0.65, 0.65, 0.65)

func restablecer_botones_seleccion():
	eleccion_local = -1
	var btns = [btn_piedra, btn_papel, btn_tijeras]
	for b in btns:
		if b: b.modulate = Color(1, 1, 1)

func iniciar_timer_seleccion(tiempo_limite: float):
	tiempo_seleccion_restante = tiempo_limite
	if label_prompt:
		label_prompt.text = "⏱️ ¡ELIGE TU JUGADA! (%.1fs) ⏱️" % tiempo_limite

# ==============================================================================
# GESTIÓN DE CÁMARA DINÁMICA POR MESA Y ESPECTADOR
# ==============================================================================

func actualizar_enfoque_camara_local(animado: bool = true):
	if not camera: return
	
	var target_pos = POS_CAM_FINAL
	var target_zoom = ZOOM_FINAL
	var mi_id = obtener_mi_id_local()
	
	if estado_actual_torneo == EstadoTorneo.SEMIFINALES:
		var total = jugadores_info.keys().size()
		if total == 3:
			# Si hay 3 jugadores, la única mesa en disputa es la Mesa A
			target_pos = POS_CAM_MESA_A
			target_zoom = ZOOM_MESA
		else:
			var pertenezco_a = (mi_id == id_a1 or mi_id == id_a2)
			var pertenezco_b = (mi_id == id_b1 or mi_id == id_b2)
			
			if pertenezco_a:
				if ganador_mesa_a == -1:
					target_pos = POS_CAM_MESA_A
					target_zoom = ZOOM_MESA
				elif ganador_mesa_b == -1:
					target_pos = POS_CAM_MESA_B
					target_zoom = ZOOM_MESA
			elif pertenezco_b:
				if ganador_mesa_b == -1:
					target_pos = POS_CAM_MESA_B
					target_zoom = ZOOM_MESA
				elif ganador_mesa_a == -1:
					target_pos = POS_CAM_MESA_A
					target_zoom = ZOOM_MESA
			else:
				target_pos = POS_CAM_MESA_A
				target_zoom = ZOOM_MESA
	else:
		target_pos = POS_CAM_FINAL
		target_zoom = ZOOM_FINAL
		
	if tween_camara and tween_camara.is_valid():
		tween_camara.kill()
		
	if animado:
		tween_camara = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween_camara.tween_property(camera, "position", target_pos, 1.2)
		tween_camara.tween_property(camera, "zoom", target_zoom, 1.2)
	else:
		camera.position = target_pos
		camera.zoom = target_zoom

# ==============================================================================
# CONFIGURACIÓN INICIAL Y ROLES
# ==============================================================================

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	
	var ids_test = [1, 2, 3, 4]
	jugadores_info.clear()
	for i in range(ids_test.size()):
		var id = ids_test[i]
		jugadores_info[id] = {"equipo": i, "spawn": i, "es_jefe": false}
		
		if not has_node(str(id)):
			var av = preload("res://escenas/personaje_jugable.tscn").instantiate()
			av.name = str(id)
			add_child(av)
			var nombres = ["P1 Seiun", "P2 GoldShip", "P3 Oguri", "P4 Still"]
			av.configurar_visual(i % 4, nombres[i])
			
	aplicar_roles_locales()

func aplicar_roles_locales():
	var lista_ids = jugadores_info.keys()
	var total = lista_ids.size()
	
	if total == 2:
		# 2 Jugadores: paso directo a la Gran Final en el centro
		finalista_1 = lista_ids[0]
		finalista_2 = lista_ids[1]
		id_a1 = finalista_1
		id_a2 = finalista_2
		id_b1 = -1
		id_b2 = -1
		preparar_visual_final_directa()
	elif total == 3:
		# 3 Jugadores: dos se enfrentan en Mesa A, y uno obtiene pase directo a la final
		id_a1 = lista_ids[0]
		id_a2 = lista_ids[1]
		id_b1 = -1
		id_b2 = -1
		finalista_2 = lista_ids[2]
		ganador_mesa_b = finalista_2
		preparar_visual_semifinal_3p()
	else:
		# 4 o más jugadores: torneo estándar de 2 semifinales
		id_a1 = lista_ids[0] if lista_ids.size() > 0 else 1
		id_a2 = lista_ids[1] if lista_ids.size() > 1 else 2
		id_b1 = lista_ids[2] if lista_ids.size() > 2 else 3
		id_b2 = lista_ids[3] if lista_ids.size() > 3 else 4
		posicionar_avatares_inicial()
		actualizar_hud_nombres()
		actualizar_hud_estrellas_semifinal()
		actualizar_enfoque_camara_local(false)
		
	iniciar_secuencia_cuenta_atras()

func preparar_visual_final_directa():
	panel_mesa_a.visible = false
	panel_mesa_b.visible = false
	panel_final.visible = true
	
	carta_a1.visible = true
	carta_a2.visible = true
	carta_b1.visible = false
	carta_b2.visible = false
	
	carta_a1.position = POS_FINAL_1 + Vector2(0, -95)
	carta_a2.position = POS_FINAL_2 + Vector2(0, -95)
	
	configurar_avatar(finalista_1, POS_FINAL_1, false, Color("#ff4757"))
	configurar_avatar(finalista_2, POS_FINAL_2, true,  Color("#1e90ff"))
	
	foco_centro.visible = true
	foco_centro.modulate.a = 1.0
	
	if label_nom_fin1: label_nom_fin1.text = obtener_nombre_jugador(finalista_1)
	if label_nom_fin2: label_nom_fin2.text = obtener_nombre_jugador(finalista_2)
	actualizar_hud_estrellas_final()
	
	estado_actual_torneo = EstadoTorneo.GRAN_FINAL
	if camera:
		camera.position = POS_CAM_FINAL
		camera.zoom = ZOOM_FINAL

func preparar_visual_semifinal_3p():
	panel_mesa_a.visible = true
	panel_mesa_b.visible = true
	panel_final.visible = false
	
	if label_nom_b1: label_nom_b1.text = "PASE A FINAL"
	if label_nom_b2: label_nom_b2.text = "★ " + obtener_nombre_jugador(finalista_2)
	if label_estrellas_b1: label_estrellas_b1.text = "★ ★"
	if label_estrellas_b2: label_estrellas_b2.text = "★ ★"
	
	carta_a1.visible = true
	carta_a2.visible = true
	carta_b1.visible = false
	carta_b2.visible = false
	
	carta_a1.position = POS_A1 + Vector2(0, -95)
	carta_a2.position = POS_A2 + Vector2(0, -95)
	
	configurar_avatar(id_a1, POS_A1, false, Color("#ff4757"))
	configurar_avatar(id_a2, POS_A2, true,  Color("#1e90ff"))
	configurar_avatar(finalista_2, POS_BANCA_B, true, Color("#ffa502"))
	
	if label_nom_a1: label_nom_a1.text = obtener_nombre_jugador(id_a1)
	if label_nom_a2: label_nom_a2.text = obtener_nombre_jugador(id_a2)
	actualizar_hud_estrellas_semifinal()
	
	estado_actual_torneo = EstadoTorneo.SEMIFINALES
	actualizar_enfoque_camara_local(false)

func posicionar_avatares_inicial():
	configurar_avatar(id_a1, POS_A1, false, Color("#ff4757"))
	configurar_avatar(id_a2, POS_A2, true,  Color("#1e90ff"))
	configurar_avatar(id_b1, POS_B1, false, Color("#ff4757"))
	configurar_avatar(id_b2, POS_B2, true,  Color("#1e90ff"))
	
	carta_a1.position = POS_A1 + Vector2(0, -95)
	carta_a2.position = POS_A2 + Vector2(0, -95)
	carta_b1.position = POS_B1 + Vector2(0, -95)
	carta_b2.position = POS_B2 + Vector2(0, -95)

func configurar_avatar(id: int, pos: Vector2, mirar_izq: bool, color_nick: Color):
	var av = get_node_or_null(str(id))
	if av:
		av.global_position = pos
		av.bloquear_controles(true)
		av.set_physics_process(false)
		if "sprite" in av and av.sprite:
			av.sprite.flip_h = mirar_izq
			av.sprite.play(av.prefijo_personaje + "_idle")
		if "label_nick" in av and av.label_nick:
			av.label_nick.modulate = color_nick

func bloquear_jugadores(bloquear: bool):
	for hijo in get_children():
		if hijo.has_method("bloquear_controles"):
			hijo.bloquear_controles(bloquear)
			if "sprite" in hijo and hijo.sprite and "prefijo_personaje" in hijo and hijo.prefijo_personaje != "":
				hijo.sprite.play(hijo.prefijo_personaje + "_idle")

func actualizar_hud_nombres():
	if label_nom_a1: label_nom_a1.text = obtener_nombre_jugador(id_a1)
	if label_nom_a2: label_nom_a2.text = obtener_nombre_jugador(id_a2)
	if label_nom_b1: label_nom_b1.text = obtener_nombre_jugador(id_b1)
	if label_nom_b2: label_nom_b2.text = obtener_nombre_jugador(id_b2)

func iniciar_juego_post_cuenta_atras():
	if es_servidor_o_solo():
		var total = jugadores_info.keys().size()
		if total == 2:
			rpc("sincronizar_inicio_final_directa_rpc", finalista_1, finalista_2)
			await get_tree().create_timer(1.2).timeout
			ejecutar_ciclo_gran_final()
		elif total == 3:
			rpc("sincronizar_inicio_semifinal_3p_rpc", id_a1, id_a2, finalista_2)
			await get_tree().create_timer(1.4).timeout
			ejecutar_ciclo_rondas_semifinales()
		else:
			rpc("sincronizar_inicio_torneo_rpc", id_a1, id_a2, id_b1, id_b2)
			await get_tree().create_timer(1.6).timeout
			ejecutar_ciclo_rondas_semifinales()

@rpc("any_peer", "call_local")
func sincronizar_inicio_final_directa_rpc(p1: int, p2: int):
	finalista_1 = p1
	finalista_2 = p2
	id_a1 = p1
	id_a2 = p2
	preparar_visual_final_directa()
	estado_actual_torneo = EstadoTorneo.GRAN_FINAL
	actualizar_enfoque_camara_local(true)

@rpc("any_peer", "call_local")
func sincronizar_inicio_semifinal_3p_rpc(p_a1: int, p_a2: int, p_bye: int):
	id_a1 = p_a1
	id_a2 = p_a2
	id_b1 = -1
	id_b2 = -1
	finalista_2 = p_bye
	ganador_mesa_b = p_bye
	preparar_visual_semifinal_3p()
	estado_actual_torneo = EstadoTorneo.SEMIFINALES
	actualizar_enfoque_camara_local(true)

@rpc("any_peer", "call_local")
func sincronizar_inicio_torneo_rpc(p_a1: int, p_a2: int, p_b1: int, p_b2: int):
	id_a1 = p_a1
	id_a2 = p_a2
	id_b1 = p_b1
	id_b2 = p_b2
	actualizar_hud_nombres()
	actualizar_hud_estrellas_semifinal()
	
	estado_actual_torneo = EstadoTorneo.SEMIFINALES
	actualizar_enfoque_camara_local(true)
	
	if es_servidor_o_solo():
		get_tree().create_timer(1.6).timeout.connect(ejecutar_ciclo_rondas_semifinales, CONNECT_ONE_SHOT)

# ==============================================================================
# FASE 1: SEMIFINALES SINCRONIZADAS POR RED
# ==============================================================================

func ejecutar_ciclo_rondas_semifinales():
	while ganador_mesa_a == -1 or ganador_mesa_b == -1:
		elecciones_recibidas.clear()
		var tiempo_margen = 3.5
		
		if multiplayer.has_multiplayer_peer():
			sincronizar_inicio_seleccion_semifinales_rpc.rpc(ganador_mesa_a, ganador_mesa_b, tiempo_margen)
		else:
			sincronizar_inicio_seleccion_semifinales_rpc(ganador_mesa_a, ganador_mesa_b, tiempo_margen)
			
		await get_tree().create_timer(tiempo_margen).timeout
		
		# Completar selecciones faltantes para bots o jugadores sin respuesta
		if ganador_mesa_a == -1:
			if not elecciones_recibidas.has(id_a1): elecciones_recibidas[id_a1] = randi() % 3
			if not elecciones_recibidas.has(id_a2): elecciones_recibidas[id_a2] = randi() % 3
		if ganador_mesa_b == -1:
			if not elecciones_recibidas.has(id_b1): elecciones_recibidas[id_b1] = randi() % 3
			if not elecciones_recibidas.has(id_b2): elecciones_recibidas[id_b2] = randi() % 3
			
		var elecc_a1 = elecciones_recibidas.get(id_a1, 0)
		var elecc_a2 = elecciones_recibidas.get(id_a2, 0)
		var elecc_b1 = elecciones_recibidas.get(id_b1, 0)
		var elecc_b2 = elecciones_recibidas.get(id_b2, 0)
		
		var res_a = -1
		var nuevo_gan_a = ganador_mesa_a
		if ganador_mesa_a == -1:
			res_a = evaluar_combate(elecc_a1, elecc_a2)
			if res_a == 1: puntos_a1 += 1
			elif res_a == 2: puntos_a2 += 1
			if puntos_a1 >= 2: nuevo_gan_a = id_a1
			elif puntos_a2 >= 2: nuevo_gan_a = id_a2
			
		var res_b = -1
		var nuevo_gan_b = ganador_mesa_b
		if ganador_mesa_b == -1:
			res_b = evaluar_combate(elecc_b1, elecc_b2)
			if res_b == 1: puntos_b1 += 1
			elif res_b == 2: puntos_b2 += 1
			if puntos_b1 >= 2: nuevo_gan_b = id_b1
			elif puntos_b2 >= 2: nuevo_gan_b = id_b2
			
		if multiplayer.has_multiplayer_peer():
			sincronizar_revelacion_semifinales_rpc.rpc(
				elecc_a1, elecc_a2, elecc_b1, elecc_b2,
				res_a, res_b,
				puntos_a1, puntos_a2, puntos_b1, puntos_b2,
				nuevo_gan_a, nuevo_gan_b
			)
		else:
			sincronizar_revelacion_semifinales_rpc(
				elecc_a1, elecc_a2, elecc_b1, elecc_b2,
				res_a, res_b,
				puntos_a1, puntos_a2, puntos_b1, puntos_b2,
				nuevo_gan_a, nuevo_gan_b
			)
			
		var tiempo_espera = 3.6
		if (nuevo_gan_a != -1 and ganador_mesa_a == -1) or (nuevo_gan_b != -1 and ganador_mesa_b == -1):
			tiempo_espera += 1.6
		await get_tree().create_timer(tiempo_espera).timeout
		
		ganador_mesa_a = nuevo_gan_a
		ganador_mesa_b = nuevo_gan_b
		
	# Ambas mesas tienen ganador -> Transición a Gran Final
	if multiplayer.has_multiplayer_peer():
		sincronizar_transicion_gran_final_rpc.rpc(ganador_mesa_a, ganador_mesa_b)
	else:
		sincronizar_transicion_gran_final_rpc(ganador_mesa_a, ganador_mesa_b)
		
	await get_tree().create_timer(3.5).timeout
	ejecutar_ciclo_gran_final()

@rpc("any_peer", "call_local")
func sincronizar_inicio_seleccion_semifinales_rpc(gan_a: int, gan_b: int, tiempo_limite: float):
	restablecer_botones_seleccion()
	var mi_id = obtener_mi_id_local()
	
	var en_mesa_a_activa = (gan_a == -1 and (mi_id == id_a1 or mi_id == id_a2))
	var en_mesa_b_activa = (gan_b == -1 and (mi_id == id_b1 or mi_id == id_b2))
	
	panel_botones_jugador.visible = (en_mesa_a_activa or en_mesa_b_activa)
	if panel_botones_jugador.visible:
		iniciar_timer_seleccion(tiempo_limite)

@rpc("any_peer", "call_local")
func sincronizar_revelacion_semifinales_rpc(
	elecc_a1: int, elecc_a2: int, elecc_b1: int, elecc_b2: int,
	res_a: int, res_b: int,
	pts_a1: int, pts_a2: int, pts_b1: int, pts_b2: int,
	nuevo_gan_a: int, nuevo_gan_b: int
):
	panel_botones_jugador.visible = false
	
	var duelistas_activos = []
	if ganador_mesa_a == -1:
		duelistas_activos.append(id_a1)
		duelistas_activos.append(id_a2)
	if ganador_mesa_b == -1:
		duelistas_activos.append(id_b1)
		duelistas_activos.append(id_b2)
	
	# 1. "¡JAN...!"
	mostrar_burbuja_canto(duelistas_activos, "¡JAN...!", 0.55)
	if ganador_mesa_a == -1:
		carta_a1.mostrar_oculto()
		carta_a2.mostrar_oculto()
		animar_salto_personaje(id_a1, 0.25)
		animar_salto_personaje(id_a2, 0.25)
	if ganador_mesa_b == -1:
		carta_b1.mostrar_oculto()
		carta_b2.mostrar_oculto()
		animar_salto_personaje(id_b1, 0.25)
		animar_salto_personaje(id_b2, 0.25)
	await get_tree().create_timer(0.65).timeout
	
	# 2. "¡KEN...!"
	mostrar_burbuja_canto(duelistas_activos, "¡KEN...!", 0.55)
	if ganador_mesa_a == -1:
		animar_salto_personaje(id_a1, 0.25)
		animar_salto_personaje(id_a2, 0.25)
	if ganador_mesa_b == -1:
		animar_salto_personaje(id_b1, 0.25)
		animar_salto_personaje(id_b2, 0.25)
	await get_tree().create_timer(0.65).timeout
	
	# 3. "¡PON!" - Revelar cartas
	mostrar_burbuja_canto(duelistas_activos, "¡PON!", 0.8)
	if ganador_mesa_a == -1:
		carta_a1.revelar(elecc_a1)
		carta_a2.revelar(elecc_a2)
	if ganador_mesa_b == -1:
		carta_b1.revelar(elecc_b1)
		carta_b2.revelar(elecc_b2)
	await get_tree().create_timer(0.35).timeout
	
	# 4. Actualizar puntos y evaluar resultados visuales
	puntos_a1 = pts_a1
	puntos_a2 = pts_a2
	puntos_b1 = pts_b1
	puntos_b2 = pts_b2
	
	if ganador_mesa_a == -1 and res_a != -1:
		procesar_resultado_mesa("A", id_a1, id_a2, carta_a1, carta_a2, res_a)
	if ganador_mesa_b == -1 and res_b != -1:
		procesar_resultado_mesa("B", id_b1, id_b2, carta_b1, carta_b2, res_b)
		
	actualizar_hud_estrellas_semifinal()
	
	# 5. Comprobar si alguna mesa terminó en esta ronda
	var mesa_a_recien_terminada = (ganador_mesa_a == -1 and nuevo_gan_a != -1)
	var mesa_b_recien_terminada = (ganador_mesa_b == -1 and nuevo_gan_b != -1)
	
	if mesa_a_recien_terminada:
		ganador_mesa_a = nuevo_gan_a
		marcar_mesa_terminada("A", nuevo_gan_a)
		var perdedor_a = id_a2 if nuevo_gan_a == id_a1 else id_a1
		trasladar_avatar(nuevo_gan_a, POS_FINAL_1, false, 1.3)
		trasladar_avatar(perdedor_a, POS_BANCA_A, false, 1.3)
		carta_a1.ocultar_suave()
		carta_a2.ocultar_suave()
		
	if mesa_b_recien_terminada:
		ganador_mesa_b = nuevo_gan_b
		marcar_mesa_terminada("B", nuevo_gan_b)
		var perdedor_b = id_b2 if nuevo_gan_b == id_b1 else id_b1
		trasladar_avatar(nuevo_gan_b, POS_FINAL_2, true, 1.3)
		trasladar_avatar(perdedor_b, POS_BANCA_B, true, 1.3)
		carta_b1.ocultar_suave()
		carta_b2.ocultar_suave()
		
	# 6. Actualizar cámara local: si mi mesa terminó pero la otra sigue, paso a espectar la otra mesa
	actualizar_enfoque_camara_local(true)

func procesar_resultado_mesa(mesa: String, id1: int, id2: int, c1: CartaJanken, c2: CartaJanken, resultado: int):
	if resultado == 0:
		c1.marcar_empate()
		c2.marcar_empate()
	elif resultado == 1:
		c1.marcar_victoria()
		c2.marcar_derrota()
		animar_victoria_personaje(id1)
		animar_derrota_personaje(id2)
	else:
		c2.marcar_victoria()
		c1.marcar_derrota()
		animar_victoria_personaje(id2)
		animar_derrota_personaje(id1)

func marcar_mesa_terminada(mesa: String, id_ganador: int):
	var nom = obtener_nombre_jugador(id_ganador)
	if mesa == "A":
		label_nom_a1.text = "★ " + nom if id_ganador == id_a1 else label_nom_a1.text
		label_nom_a2.text = "★ " + nom if id_ganador == id_a2 else label_nom_a2.text
	else:
		label_nom_b1.text = "★ " + nom if id_ganador == id_b1 else label_nom_b1.text
		label_nom_b2.text = "★ " + nom if id_ganador == id_b2 else label_nom_b2.text

func actualizar_hud_estrellas_semifinal():
	if label_estrellas_a1: label_estrellas_a1.text = formatear_estrellas(puntos_a1)
	if label_estrellas_a2: label_estrellas_a2.text = formatear_estrellas(puntos_a2)
	if label_estrellas_b1: label_estrellas_b1.text = formatear_estrellas(puntos_b1)
	if label_estrellas_b2: label_estrellas_b2.text = formatear_estrellas(puntos_b2)

func formatear_estrellas(pts: int) -> String:
	match pts:
		0: return "☆ ☆"
		1: return "★ ☆"
		_: return "★ ★"

# ==============================================================================
# FASE 2: CAMBIO DE ESCENARIO Y GRAN FINAL
# ==============================================================================

@rpc("any_peer", "call_local")
func sincronizar_transicion_gran_final_rpc(gan_a: int, gan_b: int):
	ganador_mesa_a = gan_a
	ganador_mesa_b = gan_b
	finalista_1 = gan_a
	finalista_2 = gan_b
	estado_actual_torneo = EstadoTorneo.TRANSICION_FINAL
	
	carta_a1.ocultar_suave()
	carta_a2.ocultar_suave()
	carta_b1.ocultar_suave()
	carta_b2.ocultar_suave()
	panel_botones_jugador.visible = false
	
	# Transición de cámara de TODOS los jugadores al centro (zoom general enfocado a la final)
	actualizar_enfoque_camara_local(true)
	
	# Encender foco central
	foco_centro.visible = true
	var tw_foco = create_tween()
	tw_foco.tween_property(foco_centro, "modulate:a", 1.0, 1.2)
	
	# Asegurar posicionamiento de avatares
	var perdedor_a = id_a2 if finalista_1 == id_a1 else id_a1
	var perdedor_b = id_b2 if finalista_2 == id_b1 else id_b1
	trasladar_avatar(perdedor_a, POS_BANCA_A, false, 0.8)
	trasladar_avatar(perdedor_b, POS_BANCA_B, true, 0.8)
	trasladar_avatar(finalista_1, POS_FINAL_1, false, 0.8)
	trasladar_avatar(finalista_2, POS_FINAL_2, true, 0.8)
	
	await get_tree().create_timer(1.8).timeout
	
	panel_mesa_a.visible = false
	panel_mesa_b.visible = false
	panel_final.visible = true
	
	label_nom_fin1.text = obtener_nombre_jugador(finalista_1)
	label_nom_fin2.text = obtener_nombre_jugador(finalista_2)
	
	var col_fin1 = Color("#ff4757") if jugadores_info.get(finalista_1, {}).get("equipo", 0) == 0 else Color("#1e90ff")
	var col_fin2 = Color("#ff4757") if jugadores_info.get(finalista_2, {}).get("equipo", 0) == 0 else Color("#1e90ff")
	label_nom_fin1.modulate = col_fin1
	label_nom_fin2.modulate = col_fin2
	
	actualizar_hud_estrellas_final()
	
	# Reposicionar cartas en el centro
	carta_a1.position = POS_FINAL_1 + Vector2(0, -95)
	carta_a2.position = POS_FINAL_2 + Vector2(0, -95)
	
	estado_actual_torneo = EstadoTorneo.GRAN_FINAL

func trasladar_avatar(id: int, destino: Vector2, mirar_izq: bool, tiempo: float):
	var av = get_node_or_null(str(id))
	if av:
		if "sprite" in av and av.sprite:
			av.sprite.play(av.prefijo_personaje + "_run")
			av.sprite.flip_h = mirar_izq
			
		var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(av, "global_position", destino, tiempo)
		await tw.finished
		
		if "sprite" in av and av.sprite:
			av.sprite.play(av.prefijo_personaje + "_idle")

func ejecutar_ciclo_gran_final():
	while campeon_torneo == -1:
		elecciones_recibidas.clear()
		var tiempo_margen = 3.5
		
		if multiplayer.has_multiplayer_peer():
			sincronizar_inicio_seleccion_final_rpc.rpc(tiempo_margen)
		else:
			sincronizar_inicio_seleccion_final_rpc(tiempo_margen)
			
		await get_tree().create_timer(tiempo_margen).timeout
		
		if not elecciones_recibidas.has(finalista_1): elecciones_recibidas[finalista_1] = randi() % 3
		if not elecciones_recibidas.has(finalista_2): elecciones_recibidas[finalista_2] = randi() % 3
		
		var elecc_1 = elecciones_recibidas[finalista_1]
		var elecc_2 = elecciones_recibidas[finalista_2]
		
		var res = evaluar_combate(elecc_1, elecc_2)
		var nuevo_campeon = -1
		if res == 1:
			puntos_fin1 += 1
		elif res == 2:
			puntos_fin2 += 1
			
		if puntos_fin1 >= 2: nuevo_campeon = finalista_1
		elif puntos_fin2 >= 2: nuevo_campeon = finalista_2
		
		if multiplayer.has_multiplayer_peer():
			sincronizar_revelacion_final_rpc.rpc(elecc_1, elecc_2, res, puntos_fin1, puntos_fin2, nuevo_campeon)
		else:
			sincronizar_revelacion_final_rpc(elecc_1, elecc_2, res, puntos_fin1, puntos_fin2, nuevo_campeon)
			
		var tiempo_espera = 3.6
		if nuevo_campeon != -1:
			tiempo_espera += 1.0
		await get_tree().create_timer(tiempo_espera).timeout
		
		if nuevo_campeon != -1:
			campeon_torneo = nuevo_campeon
			break
			
	if multiplayer.has_multiplayer_peer():
		coronar_campeon_rpc.rpc(campeon_torneo)
	else:
		coronar_campeon_rpc(campeon_torneo)

@rpc("any_peer", "call_local")
func sincronizar_inicio_seleccion_final_rpc(tiempo_limite: float):
	restablecer_botones_seleccion()
	var mi_id = obtener_mi_id_local()
	var es_finalista = (mi_id == finalista_1 or mi_id == finalista_2)
	panel_botones_jugador.visible = es_finalista
	if es_finalista:
		iniciar_timer_seleccion(tiempo_limite)

@rpc("any_peer", "call_local")
func sincronizar_revelacion_final_rpc(elecc_1: int, elecc_2: int, res: int, pts_1: int, pts_2: int, _nuevo_campeon: int):
	panel_botones_jugador.visible = false
	
	var duelistas_final = [finalista_1, finalista_2]
	mostrar_burbuja_canto(duelistas_final, "¡JAN...!", 0.55)
	carta_a1.mostrar_oculto()
	carta_a2.mostrar_oculto()
	animar_salto_personaje(finalista_1, 0.25)
	animar_salto_personaje(finalista_2, 0.25)
	await get_tree().create_timer(0.65).timeout
	
	mostrar_burbuja_canto(duelistas_final, "¡KEN...!", 0.55)
	animar_salto_personaje(finalista_1, 0.25)
	animar_salto_personaje(finalista_2, 0.25)
	await get_tree().create_timer(0.65).timeout
	
	mostrar_burbuja_canto(duelistas_final, "¡PON!", 0.8)
	carta_a1.revelar(elecc_1)
	carta_a2.revelar(elecc_2)
	await get_tree().create_timer(0.35).timeout
	
	puntos_fin1 = pts_1
	puntos_fin2 = pts_2
	actualizar_hud_estrellas_final()
	
	if res == 0:
		carta_a1.marcar_empate()
		carta_a2.marcar_empate()
	elif res == 1:
		carta_a1.marcar_victoria()
		carta_a2.marcar_derrota()
		animar_victoria_personaje(finalista_1)
		animar_derrota_personaje(finalista_2)
	else:
		carta_a2.marcar_victoria()
		carta_a1.marcar_derrota()
		animar_victoria_personaje(finalista_2)
		animar_derrota_personaje(finalista_1)

func actualizar_hud_estrellas_final():
	if label_estrellas_fin1: label_estrellas_fin1.text = formatear_estrellas(puntos_fin1)
	if label_estrellas_fin2: label_estrellas_fin2.text = formatear_estrellas(puntos_fin2)

@rpc("any_peer", "call_local")
func coronar_campeon_rpc(id_campeon: int):
	campeon_torneo = id_campeon
	estado_actual_torneo = EstadoTorneo.VICTORIA
	
	# Ocultar cartas, HUDs y avisos de juego
	carta_a1.ocultar_suave()
	carta_a2.ocultar_suave()
	panel_botones_jugador.visible = false
	panel_mesa_a.visible = false
	panel_mesa_b.visible = false
	panel_final.visible = false
	if panel_anuncio_centro:
		panel_anuncio_centro.modulate.a = 0.0
		
	# 1. Identificar a los 3 perdedores
	var perdedores = []
	for id in jugadores_info.keys():
		if id != campeon_torneo:
			perdedores.append(id)
			
	bloquear_jugadores(true)
	
	# 2. Desplazar al ganador al centro en la herradura (Vector2(576, 385))
	var av_ganador = get_node_or_null(str(campeon_torneo))
	if av_ganador:
		av_ganador.visible = true
		av_ganador.z_index = 10
		if "label_nick" in av_ganador and av_ganador.label_nick:
			av_ganador.label_nick.visible = false
		if "sprite" in av_ganador and av_ganador.sprite:
			av_ganador.sprite.flip_h = false
			av_ganador.sprite.play(av_ganador.prefijo_personaje + "_acierto")
		var tw_win = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_win.tween_property(av_ganador, "global_position", POS_HERRADURA, 0.6)
		
	# 3. Desplazar a los 3 perdedores a la parte inferior
	for i in range(min(perdedores.size(), POS_PERDEDORES.size())):
		var p_id = perdedores[i]
		var av_p = get_node_or_null(str(p_id))
		if av_p:
			av_p.visible = true
			av_p.z_index = 5
			if "label_nick" in av_p and av_p.label_nick:
				av_p.label_nick.visible = false
			if "sprite" in av_p and av_p.sprite:
				av_p.sprite.flip_h = (i == 2)
				av_p.sprite.play(av_p.prefijo_personaje + "_idle")
			var tw_perd = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw_perd.tween_property(av_p, "global_position", POS_PERDEDORES[i], 0.6)
			
	# 4. Encuadrar podio completo con la cámara (ganador en herradura Y=385, perdedores abajo en Y=520)
	var tw_cam = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw_cam.tween_property(camera, "position", Vector2(576, 440), 1.0)
	tw_cam.tween_property(camera, "zoom", Vector2(1.15, 1.15), 1.0)
	
	if particulas_victoria:
		particulas_victoria.position = POS_HERRADURA
		particulas_victoria.emitting = true
		
	await tw_cam.finished
	await get_tree().create_timer(0.3).timeout
	
	# 5. Mostrar cartel de victoria estilo Mario Party arriba en pantalla para NO tapar al ganador
	var overlay_victoria = escena_pantalla_victoria.instantiate()
	add_child(overlay_victoria)
	
	var ctrl_centro = overlay_victoria.get_node_or_null("Centro")
	if ctrl_centro:
		ctrl_centro.offset_top = 18.0
		ctrl_centro.offset_bottom = 205.0
		
	var info = formatear_nombres_ganadores([campeon_torneo])
	overlay_victoria.animar_aparicion(info["nombres"], info["wins"])
	
	# 6. Celebración y retorno al lobby coordinado por el servidor
	await get_tree().create_timer(4.5).timeout
	
	if es_autoridad_de_partida():
		if get_tree().root.has_node("Lobby"):
			get_tree().root.get_node("Lobby").regresar_al_lobby_rpc.rpc()

# ==============================================================================
# REGLAS Y EVALUACIÓN
# ==============================================================================

func evaluar_combate(e1: int, e2: int) -> int:
	if e1 == e2: return 0 # Empate
	if (e1 == Opcion.PIEDRA and e2 == Opcion.TIJERAS) or \
	   (e1 == Opcion.PAPEL and e2 == Opcion.PIEDRA) or \
	   (e1 == Opcion.TIJERAS and e2 == Opcion.PAPEL):
		return 1 # Gana Jugador 1
	return 2 # Gana Jugador 2

# ==============================================================================
# BURBUJAS DE DIÁLOGO Y ANUNCIOS ESTILIZADOS
# ==============================================================================

var dict_burbujas: Dictionary = {}

func mostrar_burbuja_canto(ids_jugadores: Array, texto: String, duracion: float = 0.55):
	for id in ids_jugadores:
		var av = get_node_or_null(str(id))
		if not av: continue
		
		var burbuja = null
		if id in dict_burbujas and is_instance_valid(dict_burbujas[id]):
			burbuja = dict_burbujas[id]
		else:
			burbuja = crear_nodo_burbuja()
			av.add_child(burbuja)
			dict_burbujas[id] = burbuja
			
		burbuja.position = Vector2(0, -68)
		burbuja.mostrar_texto(texto, duracion)

func crear_nodo_burbuja() -> Node2D:
	var root = Node2D.new()
	root.z_index = 25
	
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(80, 32)
	panel.pivot_offset = Vector2(40, 32)
	panel.position = Vector2(-40, -32)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.96)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.18, 0.12, 0.32, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)
	
	var lbl = Label.new()
	lbl.name = "LabelTexto"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.18, 0.1, 0.3, 1.0))
	margin.add_child(lbl)
	root.add_child(panel)
	
	# Puntero / colita inferior de la burbuja
	var cola = Polygon2D.new()
	cola.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(0, 7)])
	cola.color = Color(1.0, 1.0, 1.0, 0.96)
	root.add_child(cola)
	
	var borde_cola = Line2D.new()
	borde_cola.points = PackedVector2Array([Vector2(-6, 0), Vector2(0, 7), Vector2(6, 0)])
	borde_cola.width = 2.5
	borde_cola.default_color = Color(0.18, 0.12, 0.32, 1.0)
	root.add_child(borde_cola)
	
	var script_burbuja = GDScript.new()
	script_burbuja.source_code = """extends Node2D
var tw_anim: Tween = null
func mostrar_texto(t: String, dur: float):
	var lbl = find_child("LabelTexto", true, false)
	if lbl:
		lbl.text = t
	visible = true
	modulate.a = 1.0
	scale = Vector2(0.2, 0.2)
	if tw_anim:
		tw_anim.kill()
	tw_anim = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var escala_final = Vector2(1.22, 1.22) if "PON" in t else Vector2.ONE
	tw_anim.tween_property(self, "scale", escala_final, 0.14)
	tw_anim.tween_interval(dur)
	tw_anim.tween_property(self, "modulate:a", 0.0, 0.15)
"""
	script_burbuja.reload()
	root.set_script(script_burbuja)
	
	return root

func mostrar_anuncio_central(_texto: String, _duracion: float = 1.0):
	# Reemplazado por las burbujas de diálogo dinámicas sobre los duelistas
	if panel_anuncio_centro:
		panel_anuncio_centro.visible = false

func animar_salto_personaje(id: int, duracion: float = 0.25):
	var av = get_node_or_null(str(id))
	if not av: return
	var orig_y = av.global_position.y
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(av, "global_position:y", orig_y - 28.0, duracion * 0.5)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(av, "global_position:y", orig_y, duracion * 0.5)

func animar_victoria_personaje(id: int):
	var av = get_node_or_null(str(id))
	if not av: return
	if "sprite" in av and av.sprite:
		av.sprite.play(av.prefijo_personaje + "_salto")
	var orig_y = av.global_position.y
	var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(av, "global_position:y", orig_y - 40.0, 0.28)
	tw.tween_property(av, "global_position:y", orig_y, 0.32)
	await tw.finished
	if is_instance_valid(av) and "sprite" in av and av.sprite:
		av.sprite.play(av.prefijo_personaje + "_idle")

func animar_derrota_personaje(id: int):
	var av = get_node_or_null(str(id))
	if not av: return
	if "sprite" in av and av.sprite:
		av.sprite.play(av.prefijo_personaje + "_impacto")
	var orig_x = av.global_position.x
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(av, "global_position:x", orig_x - 8.0, 0.05)
	tw.tween_property(av, "global_position:x", orig_x + 8.0, 0.05)
	tw.tween_property(av, "global_position:x", orig_x - 6.0, 0.05)
	tw.tween_property(av, "global_position:x", orig_x, 0.05)
	await tw.finished
	if is_instance_valid(av) and "sprite" in av and av.sprite:
		av.sprite.play(av.prefijo_personaje + "_aturdido")
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(av) and "sprite" in av and av.sprite:
			av.sprite.play(av.prefijo_personaje + "_idle")
