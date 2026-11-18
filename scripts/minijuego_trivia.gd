extends BaseMinijuego

enum EstadoTrivia {
	INTRO,
	MOSTRANDO_PREGUNTA,
	ESPERANDO_RESPUESTAS,
	ELIMINANDO_OPCIONES,
	MOSTRANDO_RESULTADO,
	VICTORIA
}

# --- NODOS DEL ESCENARIO Y PANTALLA DE TV ---
@onready var camera = $Camera2D
@onready var pantalla_tv = $Escenario/PantallaGiganteTV
@onready var label_categoria = $Escenario/PantallaGiganteTV/Margen/VBox/HBoxMeta/LabelCategoria
@onready var label_numero_pregunta = $Escenario/PantallaGiganteTV/Margen/VBox/HBoxMeta/LabelNumeroPregunta
@onready var label_pregunta = $Escenario/PantallaGiganteTV/Margen/VBox/LabelPregunta
@onready var particulas_estudio = $Escenario/ParticulasEstudio
@onready var publico_teatro = $Escenario.get_node_or_null("PublicoTeatro")
@onready var particulas_confeti_fin = $ParticulasConfetiFin

# --- PRESENTADORA AKIKAWA Y SU STAND ---
@onready var stand_directora = $StandDirectora
@onready var presentadora_akikawa = $PresentadoraAkikawa
@onready var sprite_akikawa = $PresentadoraAkikawa/SpriteAkikawa
@onready var burbuja_akikawa = $PresentadoraAkikawa/BurbujaDialogo
@onready var label_burbuja_akikawa = $PresentadoraAkikawa/BurbujaDialogo/Margen/LabelTexto

# --- ESTACIONES DE JUGADORES ---
@onready var contenedor_estaciones = $EstacionesJugadores

# --- HUD Y CONTROLES DE RESPUESTAS ---
@onready var hud = $HUD
@onready var label_reloj = $HUD/PanelTiempo/Margen/HBox/LabelReloj
@onready var barra_tiempo = $HUD/PanelTiempo/BarraTiempo
@onready var panel_tiempo = $HUD/PanelTiempo
@onready var panel_opciones = $HUD/PanelOpciones
@onready var btn_opcion_a = $HUD/PanelOpciones/Margen/Grid/BtnA
@onready var btn_opcion_b = $HUD/PanelOpciones/Margen/Grid/BtnB
@onready var btn_opcion_c = $HUD/PanelOpciones/Margen/Grid/BtnC
@onready var btn_opcion_d = $HUD/PanelOpciones/Margen/Grid/BtnD
@onready var label_anuncio = $HUD/PanelAnuncio/LabelAnuncio
@onready var panel_anuncio = $HUD/PanelAnuncio

# Estado y Variables de Ronda
var estado_actual_trivia: EstadoTrivia = EstadoTrivia.INTRO
var lista_preguntas: Array[Dictionary] = []
var indice_pregunta: int = 0
var pregunta_actual: Dictionary = {}
var tiempo_restante: float = 10.0
var aviso_tiempo_dado: bool = false
var estacion_por_id: Dictionary = {} # id_jugador: EstacionTrivia
var stands_asignados: Dictionary = {} # id_jugador: int (slot 1..4)

# Bot AI timers

const POSICIONES_ESTACIONES = [
	Vector2(176, 375),
	Vector2(444, 375),
	Vector2(708, 375),
	Vector2(976, 375)
]

func _ready():
	modo_actual = Modo.FFA
	Global.configurar_controles_tactiles(false, false)
	panel_anuncio.modulate.a = 0.0
	panel_tiempo.visible = false
	panel_opciones.visible = false
	if burbuja_akikawa:
		burbuja_akikawa.visible = false
		burbuja_akikawa.modulate.a = 0.0
	
	conectar_botones()
	
	if es_servidor_o_solo():
		lista_preguntas = BancoPreguntas.obtener_preguntas()
		indice_pregunta = 0
	
	if jugadores_info.size() > 0:
		aplicar_roles_locales()
	else:
		call_deferred("preparar_test_local_f6")

func es_servidor_o_solo() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return es_autoridad_de_partida()

func conectar_botones():
	if btn_opcion_a: btn_opcion_a.pressed.connect(func(): _on_opcion_humana_pulsada(0))
	if btn_opcion_b: btn_opcion_b.pressed.connect(func(): _on_opcion_humana_pulsada(1))
	if btn_opcion_c: btn_opcion_c.pressed.connect(func(): _on_opcion_humana_pulsada(2))
	if btn_opcion_d: btn_opcion_d.pressed.connect(func(): _on_opcion_humana_pulsada(3))

func preparar_test_local_f6():
	if get_tree().root.has_node("Lobby"): return
	
	var ids_test = [1, 2, 3, 4]
	jugadores_info.clear()
	for i in range(ids_test.size()):
		var id = ids_test[i]
		jugadores_info[id] = {"equipo": i, "spawn": i, "es_jefe": false}
		
	aplicar_roles_locales()

func aplicar_roles_locales():
	estacion_por_id.clear()
	jugadores_vivos.clear()
	
	var lista_ids = jugadores_info.keys()
	var escena_estacion = preload("res://escenas/estacion_trivia.tscn")
	var nombres_test = ["P1 Seiun", "P2 GoldShip", "P3 Oguri", "P4 Still"]
	
	for i in range(lista_ids.size()):
		var id = lista_ids[i]
		jugadores_vivos.append(id)
		
		var num_slot = i + 1
		stands_asignados[id] = num_slot
		
		var estacion: EstacionTrivia = escena_estacion.instantiate()
		contenedor_estaciones.add_child(estacion)
		estacion.position = POSICIONES_ESTACIONES[i % POSICIONES_ESTACIONES.size()]
		
		var nombre_j = obtener_nombre_jugador(id)
		if nombre_j.begins_with("Jugador"):
			nombre_j = nombres_test[i % nombres_test.size()]
			
		# Obtener el avatar real instanciado por el Lobby con la skin seleccionada por el jugador
		var avatar_real = get_node_or_null(str(id))
		if not avatar_real and get_tree().root:
			avatar_real = get_tree().root.find_child(str(id), true, false)
			
		var tipo_char_elegido = i % 4
		if get_tree().root.has_node("Lobby"):
			var lobby = get_tree().root.get_node("Lobby")
			if "cuadrantes" in lobby and lobby.cuadrantes and lobby.cuadrantes.has_node(str(id)):
				var cuadro = lobby.cuadrantes.get_node(str(id))
				if "indice_actual" in cuadro:
					tipo_char_elegido = cuadro.indice_actual
					
		estacion.configurar_estacion(id, num_slot, nombre_j, avatar_real, tipo_char_elegido)
		estacion_por_id[id] = estacion

	iniciar_secuencia_cuenta_atras()

# ==============================================================================
# SECUENCIA DE INTRODUCCIÓN CON MOVIMIENTO LATERAL DE LA DIRECTORA
# ==============================================================================

func iniciar_juego_post_cuenta_atras():
	estado_actual_trivia = EstadoTrivia.INTRO
	
	# Asegurar que la burbuja de texto NO esté visible en la secuencia inicial
	if burbuja_akikawa:
		burbuja_akikawa.visible = false
		burbuja_akikawa.modulate.a = 0.0
	
	if presentadora_akikawa and sprite_akikawa:
		# 1. Entrada desde el lateral izquierdo hacia el centro (posición baja: y = 480)
		presentadora_akikawa.position = Vector2(-90, 480)
		presentadora_akikawa.z_index = 10
		sprite_akikawa.play("presentar")
		
		var tw_entrada = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_entrada.tween_property(presentadora_akikawa, "position:x", 576.0, 1.4)
		await tw_entrada.finished
		
		# 2. Spotlight en el centro y cartel de bienvenida
		var foco_centro = presentadora_akikawa.get_node_or_null("FocoLuzCentro")
		if foco_centro:
			var tw_foco = create_tween()
			tw_foco.tween_property(foco_centro, "color:a", 0.35, 0.25)
		
		mostrar_anuncio("¡BIENVENIDOS AL TRIVIA SHOW!", 2.2)
		if publico_teatro:
			publico_teatro.animar_ovacion(2.2)
		sprite_akikawa.play("animar")
		
		# Pequeño salto festivo de la Directora en el centro
		var tw_salto = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw_salto.tween_property(sprite_akikawa, "position:y", -14.0, 0.2)
		tw_salto.tween_property(sprite_akikawa, "position:y", 0.0, 0.2)
		
		await get_tree().create_timer(2.4).timeout
		
		if foco_centro:
			var tw_foco_off = create_tween()
			tw_foco_off.tween_property(foco_centro, "color:a", 0.0, 0.3)
		
		# 3. Trayectoria en L hacia su atril:
		# Paso A: Regresa lateralmente hacia la izquierda hasta (Stand_X - 28px) = (95 - 28) = 67px
		sprite_akikawa.play("presentar")
		var tw_lat = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw_lat.tween_property(presentadora_akikawa, "position:x", 67.0, 1.1)
		await tw_lat.finished
		
		# Paso B: Empieza a subir verticalmente hacia la altura de su atril (y = 142)
		var tw_subir = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw_subir.tween_property(presentadora_akikawa, "position:y", 142.0, 0.9)
		await tw_subir.finished
		
		# Paso C: Se mueve hacia la derecha para cuadrar exactamente su posición X en su atril (x = 95)
		var tw_entrar = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_entrar.tween_property(presentadora_akikawa, "position:x", 95.0, 0.35)
		await tw_entrar.finished
		
		# Queda situada detrás del frente del mostrador con torso, cabeza y abanico visibles
		presentadora_akikawa.z_index = 1
		sprite_akikawa.play("presentar")
		await get_tree().create_timer(0.4).timeout
	
	# Solo el servidor o juego individual da inicio a las preguntas
	if es_servidor_o_solo():
		iniciar_siguiente_pregunta()

# ==============================================================================
# CICLO PRINCIPAL SINCRONIZADO DE PREGUNTAS (RPC)
# ==============================================================================

func iniciar_siguiente_pregunta():
	if not es_servidor_o_solo(): return
	
	if jugadores_vivos.size() <= 1:
		verificar_fin_partida()
		return
		
	if indice_pregunta >= lista_preguntas.size():
		lista_preguntas = BancoPreguntas.obtener_preguntas()
		indice_pregunta = 0
		
	var datos = lista_preguntas[indice_pregunta]
	indice_pregunta += 1
	
	if multiplayer.has_multiplayer_peer():
		sincronizar_pregunta_rpc.rpc(datos, indice_pregunta)
	else:
		sincronizar_pregunta_rpc(datos, indice_pregunta)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_pregunta_rpc(datos: Dictionary, num_preg: int):
	pregunta_actual = datos
	indice_pregunta = num_preg
	aviso_tiempo_dado = false
	
	# 1. Resetear estaciones y botones
	for id in estacion_por_id.keys():
		var est = estacion_por_id[id]
		est.limpiar_para_nueva_ronda()
		
	restablecer_estilos_botones()
	
	# 2. Configurar pantalla gigante
	label_categoria.text = "CATEGORÍA: " + pregunta_actual.get("categoria", "CULTURA GENERAL")
	label_numero_pregunta.text = "PREGUNTA #%d" % indice_pregunta
	label_pregunta.text = pregunta_actual.get("pregunta", "")
	
	# 3. Configurar texto de botones de opciones
	var opciones = pregunta_actual.get("opciones", ["A", "B", "C", "D"])
	btn_opcion_a.text = "A) " + opciones[0]
	btn_opcion_b.text = "B) " + opciones[1]
	btn_opcion_c.text = "C) " + opciones[2]
	btn_opcion_d.text = "D) " + opciones[3]
	
	# 4. Habilitar UI
	panel_tiempo.visible = true
	panel_opciones.visible = true
	habilitar_botones(true)
	
	# 5. ELECCIÓN POR DEFECTO: Opción 0 (A) seleccionada para todos los jugadores vivos
	for id in jugadores_vivos:
		var est = estacion_por_id.get(id)
		if est and not est.esta_eliminado:
			est.fijar_respuesta(0)
			
	# Resaltar la opción A por defecto en el panel local
	resaltar_boton_seleccionado(0)
	
	
	# 7. Directora Akikawa presenta la pregunta en voz alta con bocadillo
	var frases_presentacion = [
		"¡Atención a la Pregunta #%d! ¿Preparadas?" % indice_pregunta,
		"¡Pregunta #%d en pantalla! ¡A pensar bien!" % indice_pregunta,
		"¡Ronda #%d! ¡Concentración máxima, corredoras!" % indice_pregunta,
		"¡Aquí viene la Pregunta #%d! ¡No se apresuren!" % indice_pregunta,
		"¡Pregunta #%d! ¿Quién mantendrá sus vidas intactas?" % indice_pregunta
	]
	var frase = frases_presentacion[(indice_pregunta - 1) % frases_presentacion.size()]
	decir_akikawa(frase, "hablar", 3.0)
	
	# 8. Iniciar cronómetro de 10 segundos
	tiempo_restante = 10.0
	actualizar_reloj_ui()
	estado_actual_trivia = EstadoTrivia.ESPERANDO_RESPUESTAS

func _process(delta):
	if estado_actual_trivia != EstadoTrivia.ESPERANDO_RESPUESTAS: return
	
	tiempo_restante -= delta
	actualizar_reloj_ui()
	
	if tiempo_restante <= 3.0 and not aviso_tiempo_dado:
		aviso_tiempo_dado = true
		decir_akikawa("¡Últimos 3 segundos! ¡Elegid ya!", "sorpresa", 2.0)
	
	if tiempo_restante <= 0.0:
		tiempo_restante = 0.0
		actualizar_reloj_ui()
		if es_servidor_o_solo():
			if multiplayer.has_multiplayer_peer():
				finalizar_tiempo_respuestas_rpc.rpc()
			else:
				finalizar_tiempo_respuestas_rpc()

func actualizar_reloj_ui():
	var seg_int = int(ceil(tiempo_restante))
	label_reloj.text = "%d" % seg_int
	barra_tiempo.value = (tiempo_restante / 10.0) * 100.0
	
	if tiempo_restante <= 3.0:
		label_reloj.modulate = Color(1.0, 0.2, 0.2)
		barra_tiempo.modulate = Color(1.0, 0.2, 0.2)
	else:
		label_reloj.modulate = Color(1.0, 0.9, 0.4)
		barra_tiempo.modulate = Color(0.2, 0.8, 1.0)

func _on_opcion_humana_pulsada(opcion: int):
	if estado_actual_trivia != EstadoTrivia.ESPERANDO_RESPUESTAS: return
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if multiplayer.has_multiplayer_peer():
		enviar_opcion_rpc.rpc(mi_id, opcion)
	else:
		enviar_opcion_rpc(mi_id, opcion)

@rpc("any_peer", "call_local", "reliable")
func enviar_opcion_rpc(id_jugador: int, opcion: int):
	var est = estacion_por_id.get(id_jugador)
	if est and not est.esta_eliminado:
		est.fijar_respuesta(opcion)
		
	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if id_jugador == mi_id:
		resaltar_boton_seleccionado(opcion)

func _unhandled_input(event: InputEvent):
	if estado_actual_trivia != EstadoTrivia.ESPERANDO_RESPUESTAS: return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1, KEY_A: _on_opcion_humana_pulsada(0)
			KEY_2, KEY_B: _on_opcion_humana_pulsada(1)
			KEY_3, KEY_C: _on_opcion_humana_pulsada(2)
			KEY_4, KEY_D: _on_opcion_humana_pulsada(3)

# ==============================================================================
# SECUENCIA DE REVELACIÓN SINCRONIZADA
# ==============================================================================

@rpc("any_peer", "call_local", "reliable")
func finalizar_tiempo_respuestas_rpc():
	estado_actual_trivia = EstadoTrivia.ELIMINANDO_OPCIONES
	habilitar_botones(false)
	
	mostrar_anuncio("¡TIEMPO AGOTADO!", 1.2)
	await get_tree().create_timer(1.3).timeout
	await secuencia_eliminacion_opciones()

func secuencia_eliminacion_opciones():
	var correcta = pregunta_actual.get("correcta", 0)
	var incorrectas = []
	for i in range(4):
		if i != correcta:
			incorrectas.append(i)
			
	incorrectas.shuffle()
	var btns = [btn_opcion_a, btn_opcion_b, btn_opcion_c, btn_opcion_d]
	
	mostrar_anuncio("REVELANDO RESPUESTAS...", 1.0)
	decir_akikawa("¡Vamos a ver quién acertó y quién no...!", "hablar", 2.2)
	await get_tree().create_timer(1.0).timeout
	
	for inc in incorrectas:
		await get_tree().create_timer(1.1).timeout
		animar_eliminacion_boton(btns[inc])
		if publico_teatro:
			publico_teatro.reaccionar_fallo()
		
	await get_tree().create_timer(1.0).timeout
	
	animar_boton_ganador(btns[correcta])
	mostrar_anuncio("¡RESPUESTA CORRECTA!", 1.5)
	decir_akikawa("¡Esa era la respuesta correcta!", "animar", 2.5)
	if publico_teatro:
		publico_teatro.reaccionar_acierto()
	
	await get_tree().create_timer(1.8).timeout
	
	if es_servidor_o_solo():
		evaluar_jugadores_y_vidas_servidor()

func animar_eliminacion_boton(btn: Button):
	if not btn: return
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "modulate", Color(1.0, 0.25, 0.25, 1.0), 0.1)
	tw.tween_property(btn, "modulate", Color(0.35, 0.35, 0.35, 0.55), 0.2)
	btn.text = "X " + btn.text

func animar_boton_ganador(btn: Button):
	if not btn: return
	var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "modulate", Color(1.3, 1.3, 0.8, 1.0), 0.25)
	tw.tween_property(btn, "modulate", Color(1.0, 1.0, 0.6, 1.0), 0.2)
	btn.text = "OK " + btn.text

# ==============================================================================
# EVALUACIÓN DE VIDAS Y SINCRONIZACIÓN DE RESULTADOS
# ==============================================================================

func evaluar_jugadores_y_vidas_servidor():
	var correcta = pregunta_actual.get("correcta", 0)
	var dict_vidas = {}
	var recien_eliminados = []
	var nuevos_vivos = []
	
	for id in jugadores_vivos:
		var est = estacion_por_id.get(id)
		if est:
			var acerto = (est.opcion_elegida == correcta)
			var vidas = est.vidas_actuales
			if not acerto:
				vidas = max(0, vidas - 1)
			dict_vidas[id] = vidas
			if vidas > 0:
				nuevos_vivos.append(id)
			else:
				recien_eliminados.append(id)
				
	if multiplayer.has_multiplayer_peer():
		sincronizar_evaluacion_rpc.rpc(dict_vidas, recien_eliminados, nuevos_vivos, correcta)
	else:
		sincronizar_evaluacion_rpc(dict_vidas, recien_eliminados, nuevos_vivos, correcta)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_evaluacion_rpc(dict_vidas: Dictionary, eliminados: Array, vivos: Array, correcta: int):
	estado_actual_trivia = EstadoTrivia.MOSTRANDO_RESULTADO
	
	for id in dict_vidas.keys():
		var est = estacion_por_id.get(id)
		if est:
			est.vidas_actuales = dict_vidas[id]
			est.actualizar_vidas_ui()
			var acerto = (est.opcion_elegida == correcta)
			if acerto:
				est.badge_estado.text = "¡CORRECTO!"
				est.badge_estado.modulate = Color(0.3, 1.0, 0.4)
				est.animar_victoria_avatar()
			else:
				est.badge_estado.text = "¡FALLASTE!"
				est.badge_estado.modulate = Color(1.0, 0.4, 0.4)
				est.animar_fallo_avatar()
				
			if id in eliminados:
				est.esta_eliminado = true
				est.badge_estado.text = "ELIMINADO"
				est.badge_estado.modulate = Color(0.8, 0.2, 0.2)
				est.apagar_estacion()
				
	jugadores_vivos = vivos
	
	if eliminados.size() > 0:
		decir_akikawa("¡Oh no! ¡Una competidora se ha quedado sin vidas!", "sorpresa", 2.2)
		
	await get_tree().create_timer(2.4).timeout
	
	if es_servidor_o_solo():
		verificar_fin_partida()

func verificar_fin_partida():
	if jugadores_vivos.size() == 1:
		if multiplayer.has_multiplayer_peer():
			declarar_ganador_rpc.rpc(jugadores_vivos[0])
		else:
			declarar_ganador_rpc(jugadores_vivos[0])
	elif jugadores_vivos.size() == 0:
		if multiplayer.has_multiplayer_peer():
			declarar_empate_o_revivir_rpc.rpc()
		else:
			declarar_empate_o_revivir_rpc()
	else:
		iniciar_siguiente_pregunta()

@rpc("any_peer", "call_local", "reliable")
func declarar_ganador_rpc(id_campeon: int):
	estado_actual_trivia = EstadoTrivia.VICTORIA
	panel_tiempo.visible = false
	panel_opciones.visible = false
	
	var nombre_campeon = obtener_nombre_jugador(id_campeon)
	mostrar_anuncio("¡CAMPEÓN DEL TRIVIA SHOW: " + nombre_campeon.to_upper() + "!", 3.5)
	decir_akikawa("¡Felicidades, campeona! ¡Una actuación magistral!", "animar", 4.0)
	
	if particulas_confeti_fin:
		particulas_confeti_fin.emitting = true
		
	var est_ganador = estacion_por_id.get(id_campeon)
	var pos_centro = est_ganador.global_position if est_ganador else Vector2(576, 380)
	
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "position", pos_centro, 1.2)
	tw.parallel().tween_property(camera, "zoom", Vector2(1.25, 1.25), 1.2)
	
	await get_tree().create_timer(2.0).timeout
	ejecutar_secuencia_victoria([id_campeon], pos_centro)

@rpc("any_peer", "call_local", "reliable")
func declarar_empate_o_revivir_rpc():
	mostrar_anuncio("¡MUERTE SÚBITA! 1 VIDA EXTRA PARA TODOS", 2.0)
	decir_akikawa("¡Muerte súbita! ¡Una última oportunidad!", "sorpresa", 2.5)
	for id in estacion_por_id.keys():
		var est = estacion_por_id[id]
		est.vidas_actuales = 1
		est.esta_eliminado = false
		est.actualizar_vidas_ui()
		jugadores_vivos.append(id)
		
	await get_tree().create_timer(2.2).timeout
	if es_servidor_o_solo():
		iniciar_siguiente_pregunta()

# ==============================================================================
# HELPERS DE UI Y PRESENTADORA
# ==============================================================================

func decir_akikawa(texto: String, anim: String = "hablar", duracion: float = 3.0):
	if not sprite_akikawa or not burbuja_akikawa or not label_burbuja_akikawa: return
	sprite_akikawa.play(anim)
	label_burbuja_akikawa.text = texto
	
	burbuja_akikawa.visible = true
	burbuja_akikawa.scale = Vector2(0.5, 0.5)
	burbuja_akikawa.modulate.a = 0.0
	
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(burbuja_akikawa, "scale", Vector2.ONE, 0.2)
	tw.parallel().tween_property(burbuja_akikawa, "modulate:a", 1.0, 0.15)
	
	var orig_y = sprite_akikawa.position.y
	var tw_salto = create_tween().set_trans(Tween.TRANS_SINE)
	tw_salto.tween_property(sprite_akikawa, "position:y", orig_y - 8.0, 0.12)
	tw_salto.tween_property(sprite_akikawa, "position:y", orig_y, 0.12)
	
	if duracion > 0:
		await get_tree().create_timer(duracion).timeout
		if is_instance_valid(sprite_akikawa):
			sprite_akikawa.play("presentar")

func habilitar_botones(habilitar: bool):
	var btns = [btn_opcion_a, btn_opcion_b, btn_opcion_c, btn_opcion_d]
	for b in btns:
		if b: b.disabled = !habilitar

func resaltar_boton_seleccionado(opcion: int):
	var btns = [btn_opcion_a, btn_opcion_b, btn_opcion_c, btn_opcion_d]
	for i in range(btns.size()):
		if btns[i]:
			if i == opcion:
				btns[i].modulate = Color(1.3, 1.3, 1.3)
			else:
				btns[i].modulate = Color(0.65, 0.65, 0.65)

func restablecer_estilos_botones():
	var btns = [btn_opcion_a, btn_opcion_b, btn_opcion_c, btn_opcion_d]
	for b in btns:
		if b:
			b.modulate = Color(1, 1, 1, 1)
			b.scale = Vector2.ONE
	var grid = $HUD/PanelOpciones/Margen/Grid
	if grid:
		grid.queue_sort()

func mostrar_anuncio(texto: String, duracion: float = 1.0):
	if not label_anuncio or not panel_anuncio: return
	label_anuncio.text = texto
	
	panel_anuncio.scale = Vector2(0.6, 0.6)
	panel_anuncio.modulate.a = 0.0
	
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_anuncio, "scale", Vector2.ONE, 0.2)
	tw.parallel().tween_property(panel_anuncio, "modulate:a", 1.0, 0.15)
	tw.tween_interval(duracion)
	tw.tween_property(panel_anuncio, "modulate:a", 0.0, 0.25)
