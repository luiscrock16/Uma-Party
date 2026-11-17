extends Node2D
class_name PlataformaDirectora

@onready var visual = $Visual
@onready var sprite_directora = $Visual/DirectoraSprite
@onready var podio_boton = $Visual/Podio/BotonRojo
@onready var bocadillo = $Visual/Bocadillo
@onready var label_bocadillo = $Visual/Bocadillo/Margen/LabelTexto

var centro_orbita: Vector2 = Vector2(576, 324)
var radio_x: float = 460.0
var radio_y: float = 265.0
var angulo: float = -PI * 0.5 # Empieza en la parte superior
var velocidad_orbita: float = 0.35
var en_vuelo: bool = true
var en_secuencia: bool = false

var sprites_akikawa = {
	"idle": [],
	"accion": [],
	"celebrar": []
}

func _ready():
	cargar_sprites_directora()
	if bocadillo:
		bocadillo.visible = false
		bocadillo.scale = Vector2.ZERO

func cargar_sprites_directora():
	# ST01: Idle / vuelo
	for i in range(4):
		var r = "res://assets/Sprites/NPCS/Yayoi Akikawa/akyy_ST01_0%d.png" % i
		if ResourceLoader.exists(r):
			sprites_akikawa["idle"].append(load(r))
			
	# ST03: Acción / pulsar botón
	for i in range(3):
		var r = "res://assets/Sprites/NPCS/Yayoi Akikawa/akyy_ST03_0%d.png" % i
		if ResourceLoader.exists(r):
			sprites_akikawa["accion"].append(load(r))
			
	# ST05: Celebración
	for i in range(2):
		var r = "res://assets/Sprites/NPCS/Yayoi Akikawa/akyy_ST05_0%d.png" % i
		if ResourceLoader.exists(r):
			sprites_akikawa["celebrar"].append(load(r))

func iniciar_vuelo():
	en_vuelo = true
	en_secuencia = false

func _process(delta):
	# Animación de frames de la directora
	animar_sprite_directora()
	
	# Movimiento orbital
	if en_vuelo and not en_secuencia:
		angulo += velocidad_orbita * delta
		global_position.x = centro_orbita.x + cos(angulo) * radio_x
		global_position.y = centro_orbita.y + sin(angulo) * radio_y
		
		# Suave oscilación de flotación aérea
		if visual:
			visual.position.y = sin(Time.get_ticks_msec() / 200.0) * 5.0
			
		# Orientar a la directora mirando hacia el interior de la arena
		if sprite_directora:
			sprite_directora.flip_h = (cos(angulo) > 0.0)

func animar_sprite_directora():
	if not sprite_directora: return
	
	var lista: Array = sprites_akikawa["idle"]
	var speed_ms = 180.0
	
	if en_secuencia:
		lista = sprites_akikawa["accion"] if sprites_akikawa["accion"].size() > 0 else sprites_akikawa["idle"]
		speed_ms = 120.0
		
	if lista.size() > 0:
		var idx = int(Time.get_ticks_msec() / speed_ms) % lista.size()
		sprite_directora.texture = lista[idx]

func ejecutar_secuencia_fase(fase: int, callback_cambio: Callable):
	en_secuencia = true
	en_vuelo = false
	
	var texto_aviso = "¡ACELERACIÓN DE PLATAFORMAS!" if fase == 2 else "¡MUROS DE REBOTE ACTIVADOS!"
	
	# 1. Mostrar bocadillo de diálogo flotante
	if bocadillo and label_bocadillo:
		label_bocadillo.text = texto_aviso
		bocadillo.visible = true
		bocadillo.scale = Vector2.ZERO
		var tw_b = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_b.tween_property(bocadillo, "scale", Vector2.ONE, 0.25)
	
	# 2. Pequeña pausa dramática
	await get_tree().create_timer(0.6).timeout
	
	# 3. Animación de pulsar botón de la consola
	if podio_boton:
		var pos_y_base = podio_boton.position.y
		var tw_btn = create_tween()
		tw_btn.tween_property(podio_boton, "position:y", pos_y_base + 3.0, 0.08)
		tw_btn.tween_property(podio_boton, "position:y", pos_y_base, 0.12)
		
	# 4. Ejecutar el cambio de fase en el minijuego
	if callback_cambio.is_valid():
		callback_cambio.call()
		
	# 5. Festejo de la directora tras activar el cambio
	await get_tree().create_timer(1.2).timeout
	
	# 6. Ocultar bocadillo y reanudar órbita aérea
	if bocadillo:
		var tw_out = create_tween()
		tw_out.tween_property(bocadillo, "scale", Vector2.ZERO, 0.2)
		await tw_out.finished
		bocadillo.visible = false
		
	en_secuencia = false
	en_vuelo = true
