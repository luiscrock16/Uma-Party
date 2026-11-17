extends CanvasLayer

@onready var contenedor_joystick = $JoystickContainer
@onready var base_joystick = $JoystickContainer/Base
@onready var pomo_joystick = $JoystickContainer/Base/Pomo
@onready var boton_accion = $BotonAccion

const RADIO_MAXIMO: float = 60.0
var touch_id: int = -1
var tocando_joystick: bool = false
var pos_centro_joystick: Vector2 = Vector2.ZERO
var vector_direccion: Vector2 = Vector2.ZERO

func _ready():
	layer = 120
	if base_joystick:
		pos_centro_joystick = base_joystick.global_position
		
	if boton_accion:
		boton_accion.button_down.connect(_on_boton_accion_down)
		boton_accion.button_up.connect(_on_boton_accion_up)

func _input(event: InputEvent):
	if not visible: return
	if contenedor_joystick and not contenedor_joystick.visible: return
	
	if event is InputEventScreenTouch:
		if event.pressed:
			# Si toca cerca de la zona del joystick (esquina inferior izquierda)
			if event.position.x < 400 and event.position.y > 300:
				if not tocando_joystick:
					touch_id = event.index
					tocando_joystick = true
					_actualizar_posicion_joystick(event.position)
		else:
			if event.index == touch_id:
				_soltar_joystick()
				
	elif event is InputEventScreenDrag:
		if event.index == touch_id and tocando_joystick:
			_actualizar_posicion_joystick(event.position)
			
	# Soporte para ratón en escritorio para probar los controles táctiles
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.position.x < 400 and event.position.y > 300:
					touch_id = 999
					tocando_joystick = true
					_actualizar_posicion_joystick(event.position)
			else:
				if touch_id == 999:
					_soltar_joystick()
					
	elif event is InputEventMouseMotion:
		if touch_id == 999 and tocando_joystick:
			_actualizar_posicion_joystick(event.position)

func _actualizar_posicion_joystick(pos_toque: Vector2):
	if not base_joystick or not pomo_joystick: return
	
	var delta_pos = pos_toque - base_joystick.global_position
	var dist = delta_pos.length()
	
	if dist > RADIO_MAXIMO:
		delta_pos = delta_pos.normalized() * RADIO_MAXIMO
		
	pomo_joystick.position = delta_pos
	vector_direccion = delta_pos / RADIO_MAXIMO
	
	# Inyectar acciones analógicas en InputMap
	_aplicar_vector_en_input(vector_direccion)

func _soltar_joystick():
	tocando_joystick = false
	touch_id = -1
	vector_direccion = Vector2.ZERO
	if pomo_joystick:
		var tw = create_tween().set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		tw.tween_property(pomo_joystick, "position", Vector2.ZERO, 0.12)
		
	_aplicar_vector_en_input(Vector2.ZERO)

func _aplicar_vector_en_input(vec: Vector2):
	# Eje Horizontal (A / D)
	if vec.x < -0.15:
		Input.action_press("a", -vec.x)
		Input.action_release("d")
	elif vec.x > 0.15:
		Input.action_press("d", vec.x)
		Input.action_release("a")
	else:
		Input.action_release("a")
		Input.action_release("d")
		
	# Eje Vertical (W / S)
	if vec.y < -0.15:
		Input.action_press("w", -vec.y)
		Input.action_release("s")
	elif vec.y > 0.15:
		Input.action_press("s", vec.y)
		Input.action_release("w")
	else:
		Input.action_release("w")
		Input.action_release("s")

func _on_boton_accion_down():
	var ev = InputEventAction.new()
	ev.action = "espacio"
	ev.pressed = true
	Input.parse_input_event(ev)
	
	var ev2 = InputEventAction.new()
	ev2.action = "ui_accept"
	ev2.pressed = true
	Input.parse_input_event(ev2)

	Input.action_press("ui_accept", 1.0)
	Input.action_press("espacio", 1.0)
	if boton_accion:
		boton_accion.scale = Vector2(0.92, 0.92)

func _on_boton_accion_up():
	var ev = InputEventAction.new()
	ev.action = "espacio"
	ev.pressed = false
	Input.parse_input_event(ev)
	
	var ev2 = InputEventAction.new()
	ev2.action = "ui_accept"
	ev2.pressed = false
	Input.parse_input_event(ev2)

	Input.action_release("ui_accept")
	Input.action_release("espacio")
	if boton_accion:
		boton_accion.scale = Vector2(1.0, 1.0)

func establecer_texto_accion(texto: String):
	if boton_accion:
		boton_accion.text = texto

func configurar_visibilidad(mostrar_stick: bool, mostrar_boton: bool, texto_boton: String = ""):
	if contenedor_joystick:
		contenedor_joystick.visible = mostrar_stick
	if not mostrar_stick:
		_soltar_joystick()
		
	if boton_accion:
		boton_accion.visible = mostrar_boton
		if texto_boton != "":
			boton_accion.text = texto_boton
