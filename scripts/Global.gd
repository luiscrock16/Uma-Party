extends Node

enum TipoControl {
	TECLADO,
	MANDO,
	TACTIL
}

signal control_cambiado(nuevo_control: TipoControl)

# Referencias globales del juego
var nodo_garra_actual: Node = null
var tipo_control_actual: TipoControl = TipoControl.TECLADO
var nombre_jugador_local: String = "Entrenador"
var ultima_ip: String = "127.0.0.1"
var volumen_master: float = 1.0
var pantalla_completa: bool = false

# Instancia global de controles táctiles en pantalla
var capa_controles_tactiles: CanvasLayer = null

const ARCHIVO_CONFIG = "user://config_party.cfg"

func _ready():
	configurar_input_map()
	cargar_configuracion()
	call_deferred("crear_capa_controles_tactiles")
	
	if "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args() or OS.has_environment("GODOT_SERVER"):
		var actual = get_tree().current_scene
		if not (actual and actual.name == "Lobby"):
			print("[SERVER] Modo servidor detectado. Cambiando a lobby...")
			call_deferred("_iniciar_servidor_headless")

func _iniciar_servidor_headless():
	if get_tree().current_scene and get_tree().current_scene.name == "Lobby": return
	get_tree().change_scene_to_file("res://escenas/lobby.tscn")

func configurar_input_map():
	# Teclas de flechas universales para movimiento
	_agregar_tecla_si_falta("w", KEY_UP)
	_agregar_tecla_si_falta("a", KEY_LEFT)
	_agregar_tecla_si_falta("s", KEY_DOWN)
	_agregar_tecla_si_falta("d", KEY_RIGHT)
	
	# Gamepad D-pad (Cruceta)
	_agregar_joy_button_si_falta("w", JOY_BUTTON_DPAD_UP)
	_agregar_joy_button_si_falta("a", JOY_BUTTON_DPAD_LEFT)
	_agregar_joy_button_si_falta("s", JOY_BUTTON_DPAD_DOWN)
	_agregar_joy_button_si_falta("d", JOY_BUTTON_DPAD_RIGHT)
	
	# Gamepad Stick Analógico Izquierdo
	_agregar_joy_axis_si_falta("w", JOY_AXIS_LEFT_Y, -1.0)
	_agregar_joy_axis_si_falta("s", JOY_AXIS_LEFT_Y, 1.0)
	_agregar_joy_axis_si_falta("a", JOY_AXIS_LEFT_X, -1.0)
	_agregar_joy_axis_si_falta("d", JOY_AXIS_LEFT_X, 1.0)
	
	# Botón de Acción / Sprint / Empuje (A en Xbox/Cruz en PS, Gatillos)
	_agregar_joy_button_si_falta("ui_accept", JOY_BUTTON_A)
	_agregar_joy_button_si_falta("espacio", JOY_BUTTON_A)
	_agregar_joy_button_si_falta("ui_accept", JOY_BUTTON_RIGHT_SHOULDER)
	_agregar_joy_button_si_falta("espacio", JOY_BUTTON_RIGHT_SHOULDER)

func _agregar_tecla_si_falta(accion: String, keycode: Key):
	if not InputMap.has_action(accion):
		InputMap.add_action(accion)
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventKey and ev.physical_keycode == keycode:
			return
	var ev_key = InputEventKey.new()
	ev_key.physical_keycode = keycode
	InputMap.action_add_event(accion, ev_key)

func _agregar_joy_button_si_falta(accion: String, boton: JoyButton):
	if not InputMap.has_action(accion):
		InputMap.add_action(accion)
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventJoypadButton and ev.button_index == boton:
			return
	var ev_btn = InputEventJoypadButton.new()
	ev_btn.button_index = boton
	InputMap.action_add_event(accion, ev_btn)

func _agregar_joy_axis_si_falta(accion: String, eje: JoyAxis, valor: float):
	if not InputMap.has_action(accion):
		InputMap.add_action(accion)
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventJoypadMotion and ev.axis == eje and is_equal_approx(ev.axis_value, valor):
			return
	var ev_motion = InputEventJoypadMotion.new()
	ev_motion.axis = eje
	ev_motion.axis_value = valor
	InputMap.action_add_event(accion, ev_motion)

func _input(event: InputEvent):
	if event is InputEventScreenTouch and event.pressed:
		if tipo_control_actual != TipoControl.TACTIL:
			establecer_tipo_control(TipoControl.TACTIL)

func establecer_tipo_control(nuevo_tipo: TipoControl):
	tipo_control_actual = nuevo_tipo
	actualizar_visibilidad_tactil()
	guardar_configuracion()
	emit_signal("control_cambiado", tipo_control_actual)

func detectar_dispositivo_recomendado() -> TipoControl:
	var os_name = OS.get_name()
	if os_name in ["Android", "iOS"] or DisplayServer.is_touchscreen_available():
		return TipoControl.TACTIL
	
	if OS.has_feature("web"):
		var es_movil = JavaScriptBridge.eval("""
			(function() {
				var ua = navigator.userAgent || "";
				var touchPoints = navigator.maxTouchPoints || 0;
				return /Android|iPhone|iPad|iPod|Mobile|Silk/i.test(ua) || touchPoints > 0;
			})()
		""")
		if es_movil == true:
			return TipoControl.TACTIL
			
	if Input.get_connected_joypads().size() > 0:
		return TipoControl.MANDO
	else:
		return TipoControl.TECLADO

func obtener_nombre_control_actual() -> String:
	match tipo_control_actual:
		TipoControl.TECLADO: return "Teclado & Ratón (WASD / Flechas)"
		TipoControl.MANDO:
			var joypads = Input.get_connected_joypads()
			if joypads.size() > 0:
				return "Mando: " + Input.get_joy_name(joypads[0])
			return "Mando / Gamepad"
		TipoControl.TACTIL: return "Pantalla Táctil (Virtual)"
		_: return "Desconocido"

func crear_capa_controles_tactiles():
	if capa_controles_tactiles: return
	var escena = preload("res://escenas/controles_tactiles.tscn")
	capa_controles_tactiles = escena.instantiate()
	add_child(capa_controles_tactiles)
	actualizar_visibilidad_tactil()

func actualizar_visibilidad_tactil():
	if capa_controles_tactiles:
		capa_controles_tactiles.visible = (tipo_control_actual == TipoControl.TACTIL)

func establecer_texto_accion_tactil(texto: String):
	if capa_controles_tactiles and capa_controles_tactiles.has_method("establecer_texto_accion"):
		capa_controles_tactiles.establecer_texto_accion(texto)
		capa_controles_tactiles.configurar_visibilidad(true, true, texto)

func configurar_controles_tactiles(mostrar_stick: bool = true, mostrar_boton: bool = true, texto_boton: String = ""):
	if capa_controles_tactiles and capa_controles_tactiles.has_method("configurar_visibilidad"):
		capa_controles_tactiles.configurar_visibilidad(mostrar_stick, mostrar_boton, texto_boton)

func guardar_configuracion():
	var cfg = ConfigFile.new()
	cfg.set_value("juego", "tipo_control", int(tipo_control_actual))
	cfg.set_value("jugador", "nombre", nombre_jugador_local)
	cfg.set_value("red", "ultima_ip", ultima_ip)
	cfg.set_value("video", "pantalla_completa", pantalla_completa)
	cfg.set_value("audio", "volumen_master", volumen_master)
	cfg.save(ARCHIVO_CONFIG)

func cargar_configuracion():
	var cfg = ConfigFile.new()
	if cfg.load(ARCHIVO_CONFIG) == OK:
		var ct = cfg.get_value("juego", "tipo_control", -1)
		if ct != -1:
			tipo_control_actual = ct as TipoControl
		else:
			tipo_control_actual = detectar_dispositivo_recomendado()
			
		nombre_jugador_local = cfg.get_value("jugador", "nombre", "Entrenador")
		ultima_ip = cfg.get_value("red", "ultima_ip", "127.0.0.1")
		pantalla_completa = cfg.get_value("video", "pantalla_completa", false)
		volumen_master = cfg.get_value("audio", "volumen_master", 1.0)
		
		aplicar_pantalla_completa(pantalla_completa)
	else:
		tipo_control_actual = detectar_dispositivo_recomendado()

func aplicar_pantalla_completa(activar: bool):
	pantalla_completa = activar
	if activar:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func obtener_ip_local_recomendada() -> String:
	var ips = IP.get_local_addresses()
	# Primera prioridad: IP clásica de red local doméstica (192.168.x.x excluyendo VirtualBox 192.168.56.x)
	for ip in ips:
		if ip.begins_with("192.168.") and not ip.begins_with("192.168.56."):
			return ip
	# Segunda prioridad: Otras IPs privadas válidas (10.x o 172.x) que no sean loopback ni enlace local
	for ip in ips:
		if "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254.") and not ip.begins_with("192.168.56."):
			return ip
	return "127.0.0.1"
