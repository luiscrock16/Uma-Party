extends SceneTree

func _init():
	print("Iniciando captura de vistas del Gran Festival de Tracen...")
	var escena = preload("res://escenas/minijuego_laberinto.tscn").instantiate()
	root.add_child(escena)
	root.size = Vector2i(1280, 720)
	
	call_deferred("procesar_capturas", escena)

func procesar_capturas(escena):
	escena.construir_mundo_laberinto(1337, 0)
	escena.configurar_personajes_centrales()
	
	# 0. Capturar modal de instrucciones actualizado
	for _i in range(8):
		await process_frame
	capturar_pantalla("C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/preview_festival_instrucciones.png")

	# Destruir cualquier CanvasLayer de instrucciones para ver el juego limpio
	for c in escena.get_children():
		if c is CanvasLayer and c != escena.hud:
			c.queue_free()
	for c in root.get_children():
		if c is CanvasLayer:
			c.queue_free()
	for _i in range(5):
		await process_frame

	# 1. Estado Inicial: Escenario central del festival con Directora, Tazuna y espectadoras
	escena.camera.global_position = escena.CENTRO_MUNDO
	escena.camera.zoom = Vector2(1.35, 1.35)
	escena.camera.reset_smoothing()
	for _i in range(8):
		await process_frame
	capturar_pantalla("C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/preview_festival_inicio_centro.png")
	
	# 2. Vista Aérea Rápida del Festival Completo (3370x3370)
	escena.camera.global_position = escena.CENTRO_MUNDO
	escena.camera.zoom = Vector2(0.20, 0.20)
	escena.camera.reset_smoothing()
	if escena.banner_intro:
		escena.banner_intro.visible = true
		escena.banner_intro.modulate.a = 1.0
	for _i in range(8):
		await process_frame
	capturar_pantalla("C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/preview_festival_aereo_completo.png")
	
	# 3. Vista de una de las Plazas Intermedias del Festival (Plaza Noroeste con Puesto y Farolillos)
	if escena.banner_intro:
		escena.banner_intro.visible = false
	var pos_plaza_nw = escena.ORIGEN_LABERINTO + Vector2(9 * escena.CELL_SIZE, 9 * escena.CELL_SIZE)
	escena.camera.global_position = pos_plaza_nw
	escena.camera.zoom = Vector2(1.30, 1.30)
	escena.camera.reset_smoothing()
	for _i in range(8):
		await process_frame
	capturar_pantalla("C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/preview_festival_puesto_plaza.png")
	
	# 4. Vista detallada de una de las Puertas Bloqueadas en Cuadrante (Puerta Roja en Cuadrante NW)
	if escena.nodos_puertas.has("roja"):
		escena.camera.global_position = escena.nodos_puertas["roja"].global_position
	escena.camera.zoom = Vector2(1.5, 1.5)
	escena.camera.reset_smoothing()
	for _i in range(8):
		await process_frame
	capturar_pantalla("C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/preview_festival_puerta_bloqueada.png")

	# 5. Vista detallada de una de las Llaves Mágicas Flotantes (Llave Roja en Cuadrante SE opuesto)
	if escena.nodos_llaves.has("roja"):
		print("Posición Llave Roja: ", escena.nodos_llaves["roja"].global_position)
		escena.camera.global_position = escena.nodos_llaves["roja"].global_position
	else:
		print("ADVERTENCIA: No se encontró Llave Roja en nodos_llaves!")
	escena.camera.zoom = Vector2(1.6, 1.6)
	escena.camera.reset_smoothing()
	for _i in range(8):
		await process_frame
	capturar_pantalla("C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/preview_festival_llave_pickup.png")

	# 6. Zoom de inicio en el spawn de un jugador
	escena.camera.global_position = escena.spawns_esquinas[0] + Vector2(30, 30)
	escena.camera.zoom = Vector2(1.45, 1.45)
	escena.camera.reset_smoothing()
	for _i in range(8):
		await process_frame
	capturar_pantalla("C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/preview_festival_jugador_spawn.png")
	
	# 7. Vista de la Celebración y Pantalla de Victoria en la Meta Central
	escena.sincronizar_victoria_laberinto_rpc(1)
	await create_timer(2.2).timeout
	for _i in range(8):
		await process_frame
	capturar_pantalla("C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/preview_festival_victoria_meta.png")
	
	print("Capturas completadas con éxito.")
	quit()

func capturar_pantalla(ruta: String):
	var img = root.get_texture().get_image()
	if img:
		img.save_png(ruta)
		print("Guardada: ", ruta)
