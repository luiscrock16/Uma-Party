extends Control

# Nodos Principales
@onready var btn_jugar = $ContenidoPrincipal/VBoxBotones/BtnJugar
@onready var btn_controles = $ContenidoPrincipal/VBoxBotones/BtnControles
@onready var btn_ajustes = $ContenidoPrincipal/VBoxBotones/BtnAjustes
@onready var btn_salir = $ContenidoPrincipal/VBoxBotones/BtnSalir
@onready var label_control_actual = $PildoraControl/Margen/HBox/LabelControl

# Modal de Controles
@onready var modal_controles = $ModalControles
@onready var btn_tarjeta_teclado = $ModalControles/Panel/Margen/VBox/Tarjetas/TarjetaTeclado
@onready var btn_tarjeta_mando = $ModalControles/Panel/Margen/VBox/Tarjetas/TarjetaMando
@onready var btn_tarjeta_tactil = $ModalControles/Panel/Margen/VBox/Tarjetas/TarjetaTactil
@onready var label_mando_info = $ModalControles/Panel/Margen/VBox/Tarjetas/TarjetaMando/Margen/VBox/LabelMandoInfo
@onready var btn_autodetectar = $ModalControles/Panel/Margen/VBox/HBoxAcciones/BtnAutodetectar
@onready var btn_cerrar_controles = $ModalControles/Panel/Margen/VBox/HBoxAcciones/BtnCerrar

# Modal de Ajustes
@onready var modal_ajustes = $ModalAjustes
@onready var check_pantalla_completa = $ModalAjustes/Panel/Margen/VBox/Grid/CheckFullscreen
@onready var slider_volumen = $ModalAjustes/Panel/Margen/VBox/Grid/SliderVolumen
@onready var btn_cerrar_ajustes = $ModalAjustes/Panel/Margen/VBox/BtnCerrarAjustes

func _ready():
	if "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args() or OS.has_environment("GODOT_SERVER"):
		get_tree().change_scene_to_file("res://escenas/lobby.tscn")
		return
		
	Global.configurar_controles_tactiles(false, false)
	# Conexión de botones principales
	btn_jugar.pressed.connect(_on_btn_jugar_pressed)
	btn_controles.pressed.connect(_on_btn_controles_pressed)
	btn_ajustes.pressed.connect(_on_btn_ajustes_pressed)
	btn_salir.pressed.connect(_on_btn_salir_pressed)
	
	# Píldora de control rápido
	var btn_pildora = $PildoraControl/BtnAbrirControles
	if btn_pildora:
		btn_pildora.pressed.connect(_on_btn_controles_pressed)
		
	# Conexión de tarjetas de control
	btn_tarjeta_teclado.pressed.connect(func(): _seleccionar_control(Global.TipoControl.TECLADO))
	btn_tarjeta_mando.pressed.connect(func(): _seleccionar_control(Global.TipoControl.MANDO))
	btn_tarjeta_tactil.pressed.connect(func(): _seleccionar_control(Global.TipoControl.TACTIL))
	
	btn_autodetectar.pressed.connect(_on_autodetectar_pressed)
	btn_cerrar_controles.pressed.connect(func(): modal_controles.visible = false)
	
	# Ajustes
	check_pantalla_completa.toggled.connect(_on_fullscreen_toggled)
	slider_volumen.value_changed.connect(_on_volumen_changed)
	btn_cerrar_ajustes.pressed.connect(func(): modal_ajustes.visible = false)
	
	# Ocultar botón salir si estamos en Web
	if OS.has_feature("web"):
		btn_salir.visible = false
		
	# Estado inicial de modales
	modal_controles.visible = false
	modal_ajustes.visible = false
	
	check_pantalla_completa.button_pressed = Global.pantalla_completa
	slider_volumen.value = Global.volumen_master * 100.0
	
	actualizar_interfaz_controles()
	set_process(false)
	
	Input.joy_connection_changed.connect(func(_device, _connected): _actualizar_texto_mando())
	_actualizar_texto_mando()
	
	if OS.has_environment("TEST_CAPTURE"):
		_run_test_capture()
	elif OS.has_environment("TEST_CAPTURE_TACTIL"):
		_run_test_tactil()

func _run_test_tactil():
	Global.establecer_tipo_control(Global.TipoControl.TACTIL)
	await get_tree().create_timer(0.4).timeout
	var art_dir = "C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/"
	get_viewport().get_texture().get_image().save_png(art_dir + "preview_tactil_ingame.png")
	get_tree().quit()

func _run_test_capture():
	await get_tree().create_timer(0.4).timeout
	var art_dir = "C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/"
	get_viewport().get_texture().get_image().save_png(art_dir + "preview_menu_principal.png")
	
	modal_controles.visible = true
	actualizar_interfaz_controles()
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(art_dir + "preview_menu_controles.png")
	
	get_tree().quit()

func _actualizar_texto_mando():
	if label_mando_info:
		var joypads = Input.get_connected_joypads()
		if joypads.size() > 0:
			label_mando_info.text = "✓ Mando conectado:\n" + Input.get_joy_name(joypads[0])
			label_mando_info.modulate = Color(0.3, 0.95, 0.5)
		else:
			label_mando_info.text = "Ningún mando detectado.\n(Conecta por USB / Bluetooth)"
			label_mando_info.modulate = Color(0.85, 0.85, 0.85, 0.7)

func _on_btn_jugar_pressed():
	get_tree().change_scene_to_file("res://escenas/lobby.tscn")

func _on_btn_controles_pressed():
	modal_controles.visible = true
	_actualizar_texto_mando()
	actualizar_interfaz_controles()

func _on_btn_ajustes_pressed():
	modal_ajustes.visible = true
	check_pantalla_completa.button_pressed = Global.pantalla_completa
	slider_volumen.value = Global.volumen_master * 100.0

func _on_btn_salir_pressed():
	get_tree().quit()

func _seleccionar_control(tipo: Global.TipoControl):
	Global.establecer_tipo_control(tipo)
	actualizar_interfaz_controles()
	set_process(false)

func _on_autodetectar_pressed():
	var recomendado = Global.detectar_dispositivo_recomendado()
	Global.establecer_tipo_control(recomendado)
	actualizar_interfaz_controles()
	set_process(false)

func actualizar_interfaz_controles():
	if label_control_actual:
		label_control_actual.text = Global.obtener_nombre_control_actual()
	
	# Resaltado de tarjetas
	var tc = Global.tipo_control_actual
	_marcar_tarjeta(btn_tarjeta_teclado, tc == Global.TipoControl.TECLADO)
	_marcar_tarjeta(btn_tarjeta_mando, tc == Global.TipoControl.MANDO)
	_marcar_tarjeta(btn_tarjeta_tactil, tc == Global.TipoControl.TACTIL)

func _marcar_tarjeta(boton: Button, seleccionada: bool):
	if not boton: return
	if seleccionada:
		boton.modulate = Color(1.2, 1.2, 1.0)
	else:
		boton.modulate = Color(0.7, 0.75, 0.8, 0.85)

func _on_fullscreen_toggled(activado: bool):
	Global.aplicar_pantalla_completa(activado)
	Global.guardar_configuracion()

func _on_volumen_changed(valor: float):
	Global.volumen_master = valor / 100.0
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if Global.volumen_master <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(Global.volumen_master))
	Global.guardar_configuracion()
