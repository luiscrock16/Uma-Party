extends SceneTree

func _init():
	print("--- INICIANDO VERIFICACIÓN DE TORNADOS CARTOON Y ÁREA DELIMITADA ---")
	call_deferred("_ejecutar_capturas")

func _ejecutar_capturas():
	var escena = load("res://escenas/minijuego_paraguas.tscn")
	if not escena:
		print("ERROR: No se pudo cargar escenas/minijuego_paraguas.tscn")
		quit(1)
		return
		
	var minijuego = escena.instantiate()
	minijuego.instrucciones_mostradas = true
	root.add_child(minijuego)
	root.size = Vector2i(1152, 648)
	
	print("Escena instanciada correctamente. Ejecutando simulación...")
	
	# Dejar que la cinemática avance hasta el inicio del juego
	await create_timer(7.5).timeout
	
	# Captura 1: Vista de Tornado Cartoon en la pista con su anillo delimitado en el suelo
	if is_instance_valid(minijuego):
		minijuego.crear_tornado_servidor(Vector2(750.0, 560.0), Vector2(1.0, 0.0), 99)
	await create_timer(0.4).timeout
	await _guardar_captura("preview_tornado_cartoon_area_delimitada.png")
	print("Captura 1 guardada: preview_tornado_cartoon_area_delimitada.png")
	
	# Captura 2: Jugador pisando el área delimitada, perdiendo control y comenzando a ascender
	if is_instance_valid(minijuego):
		var t = minijuego.contenedor_tornados.get_node_or_null("Tornado_99")
		if t:
			minijuego.sincronizar_captura_tornado_rpc(1, "Tornado_99")
	await create_timer(1.2).timeout
	await _guardar_captura("preview_jugador_ascendiendo_tornado.png")
	print("Captura 2 guardada: preview_jugador_ascendiendo_tornado.png")
	
	# Captura 3: Jugador en la parte superior del vórtice girando en espiral (estilo Umayuru)
	await create_timer(1.4).timeout
	await _guardar_captura("preview_jugador_espiral_alto_tornado.png")
	print("Captura 3 guardada: preview_jugador_espiral_alto_tornado.png")
	
	print("--- TODAS LAS CAPTURAS DE TORNADO COMPLETADAS CON ÉXITO ---")
	await create_timer(0.5).timeout
	quit(0)

func _guardar_captura(nombre_archivo: String):
	await process_frame
	await process_frame
	var img = root.get_texture().get_image()
	if img:
		var dest = "C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/" + nombre_archivo
		var err = img.save_png(dest)
		if err != OK:
			print("Error guardando imagen:", err)
