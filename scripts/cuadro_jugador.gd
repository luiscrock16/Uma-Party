extends PanelContainer

@onready var sprite = $Margen/VBox/Centro/AnimatedSprite2D
@onready var label_nombre = $Margen/VBox/Footer/LabelNombre
@onready var label_usuario = $Margen/VBox/Header/LabelUsuario
@onready var label_jugador_badge = $Margen/VBox/Header/BadgeJugador/LabelBadge
@onready var badge_jugador = $Margen/VBox/Header/BadgeJugador
@onready var controles = $Margen/VBox/Footer/Controles
@onready var btn_confirmar = $Margen/VBox/Footer/Controles/BtnConfirmar
@onready var btn_izquierda = $Margen/VBox/Footer/Controles/BtnIzquierda
@onready var btn_derecha = $Margen/VBox/Footer/Controles/BtnDerecha
@onready var badge_listo = $Margen/VBox/Footer/BadgeListo

var personajes = {
	0: {"prefijo": "SEIK", "nombre": "Seiun Sky"},
	1: {"prefijo": "GLSH", "nombre": "Gold Ship"},
	2: {"prefijo": "OGRC", "nombre": "Oguri Cap"},
	3: {"prefijo": "STIL", "nombre": "Still in Love"},
	4: {"prefijo": "MACA", "nombre": "Manhattan Cafe"},
	5: {"prefijo": "AGTC", "nombre": "Agnes Tachyon"},
	6: {"prefijo": "DAFL", "nombre": "Dantsu Flame"},
	7: {"prefijo": "JUPC", "nombre": "Jungle Pocket"},
	8: {"prefijo": "SABG", "nombre": "Samson Big"},
	9: {"prefijo": "SPWE", "nombre": "Special Week"}
}

var colores_jugadores = {
	1: Color("#68be1f"), # P1: Verde Party Dash
	2: Color("#f39c12"), # P2: Oro / Amarillo Party Dash
	3: Color("#2980b9"), # P3: Azul Cielo Party Dash
	4: Color("#8e44ad")  # P4: Morado / Lila Party Dash
}

var indice_actual = 0
var esta_confirmado = false
var numero_slot = 1
var nombre_guardado: String = ""

func _ready():
	custom_minimum_size = Vector2(250, 420)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	if btn_derecha and not btn_derecha.pressed.is_connected(_on_btn_derecha_pressed):
		btn_derecha.pressed.connect(_on_btn_derecha_pressed)
	if btn_izquierda and not btn_izquierda.pressed.is_connected(_on_btn_izquierda_pressed):
		btn_izquierda.pressed.connect(_on_btn_izquierda_pressed)
	if btn_confirmar and not btn_confirmar.pressed.is_connected(_on_btn_confirmar_pressed):
		btn_confirmar.pressed.connect(_on_btn_confirmar_pressed)
		
	if controles:
		controles.visible = false
	if badge_listo:
		badge_listo.visible = false
		
	if nombre_guardado != "":
		set_nombre_usuario(nombre_guardado)
		
	configurar_slot(numero_slot)
	actualizar_vista()

var esquemas_slot = {
	1: { "border": Color("#4ea317"), "bg_card": Color("#f4faf1"), "bg_stage": Color("#e4f4dc"), "badge": Color("#449912"), "text": Color("#184605") },
	2: { "border": Color("#e67e22"), "bg_card": Color("#fefaf3"), "bg_stage": Color("#fbebd7"), "badge": Color("#d35400"), "text": Color("#6e2b02") },
	3: { "border": Color("#2471a3"), "bg_card": Color("#f2f8fc"), "bg_stage": Color("#dbebf6"), "badge": Color("#1f618d"), "text": Color("#0c3452") },
	4: { "border": Color("#8e44ad"), "bg_card": Color("#f9f2fb"), "bg_stage": Color("#ecd6f3"), "badge": Color("#71368a"), "text": Color("#3d144e") }
}

func configurar_slot(num: int):
	numero_slot = num
	if not is_node_ready():
		return
		
	var esquema = esquemas_slot.get(num, esquemas_slot[1])
	var color_slot = esquema["border"]
	
	if label_jugador_badge:
		label_jugador_badge.text = "P" + str(num)
	if badge_jugador:
		badge_jugador.self_modulate = esquema["badge"]
		
	var estilo = get_theme_stylebox("panel")
	if estilo and estilo is StyleBoxFlat:
		var nuevo_estilo = estilo.duplicate()
		nuevo_estilo.border_color = color_slot
		nuevo_estilo.bg_color = esquema["bg_card"]
		add_theme_stylebox_override("panel", nuevo_estilo)
		
	var stage = get_node_or_null("Margen/VBox/Centro")
	if stage:
		var st_estilo = stage.get_theme_stylebox("panel")
		if st_estilo and st_estilo is StyleBoxFlat:
			var nuevo_st = st_estilo.duplicate()
			nuevo_st.bg_color = esquema["bg_stage"]
			nuevo_st.border_color = color_slot.lerp(Color.WHITE, 0.4)
			stage.add_theme_stylebox_override("panel", nuevo_st)
			
	if badge_listo:
		badge_listo.text = "OK!"
		badge_listo.add_theme_color_override("font_color", color_slot)

func esta_listo_para_jugar() -> bool:
	return esta_confirmado

func activar_si_es_mio():
	if not is_inside_tree(): await tree_entered
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	
	var mi_id = multiplayer.get_unique_id()
	var nodo_id = int(str(name))
	
	if nodo_id == mi_id:
		set_multiplayer_authority(mi_id)
		if controles:
			controles.visible = true
	else:
		if controles:
			controles.visible = false
		solicitar_personaje_actual.rpc_id(nodo_id)

func _on_btn_confirmar_pressed():
	esta_confirmado = !esta_confirmado
	confirmar_personaje_rpc.rpc(esta_confirmado)

@rpc("any_peer", "call_local", "reliable")
func confirmar_personaje_rpc(valor):
	esta_confirmado = valor
	if not is_node_ready(): await ready 
	
	var datos = personajes[indice_actual]
	
	if esta_confirmado:
		var anim_intro = datos["prefijo"] + "_intro"
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_intro):
			sprite.play(anim_intro)
		
		if badge_listo:
			badge_listo.visible = true
			
		if is_multiplayer_authority() and btn_confirmar:
			btn_confirmar.text = "CANCELAR"
			btn_izquierda.visible = false
			btn_derecha.visible = false
	else:
		actualizar_vista()
		if badge_listo:
			badge_listo.visible = false
			
		if is_multiplayer_authority() and btn_confirmar:
			btn_confirmar.text = "¡LISTO!"
			btn_izquierda.visible = true
			btn_derecha.visible = true

@rpc("any_peer", "call_remote", "reliable")
func solicitar_personaje_actual():
	if is_multiplayer_authority():
		var preguntador_id = multiplayer.get_remote_sender_id()
		var nick = label_usuario.text if label_usuario else "Jugador"
		responder_sincronizacion.rpc_id(preguntador_id, indice_actual, nick, esta_confirmado)

@rpc("any_peer", "call_local", "reliable")
func responder_sincronizacion(idx, nombre_red, listo):
	indice_actual = idx
	if nombre_red != "":
		set_nombre_usuario(nombre_red)
	if listo:
		confirmar_personaje_rpc(true) 
	else:
		actualizar_vista()

func _on_btn_derecha_pressed():
	if esta_confirmado: return
	var nuevo_idx = (indice_actual + 1) % personajes.size()
	cambiar_rpc.rpc(nuevo_idx)

func _on_btn_izquierda_pressed():
	if esta_confirmado: return
	var nuevo_idx = (indice_actual - 1 + personajes.size()) % personajes.size()
	cambiar_rpc.rpc(nuevo_idx)

func seleccionar_indice(idx: int):
	if esta_confirmado: return
	cambiar_rpc.rpc(idx)

@rpc("any_peer", "call_local", "reliable")
func cambiar_rpc(idx):
	indice_actual = idx
	actualizar_vista()

func set_nombre_usuario(nuevo_nombre: String):
	nombre_guardado = nuevo_nombre
	if label_usuario:
		label_usuario.text = nuevo_nombre

func actualizar_vista():
	if not is_node_ready(): return
	var datos = personajes.get(indice_actual, personajes[0])
	if label_nombre:
		label_nombre.text = datos["nombre"].to_upper()
	
	if sprite and sprite.sprite_frames:
		var anim_objetivo = datos["prefijo"] + "_idle"
		if sprite.sprite_frames.has_animation(anim_objetivo):
			sprite.play(anim_objetivo)
