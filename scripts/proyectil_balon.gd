extends Node2D
class_name ProyectilBalon

signal impacto_jugador(id_jugador: int)

@onready var visual = $Visual
@onready var sprite_balon = $Visual/SpriteBalon
@onready var area_colision = $AreaColision
@onready var shape_colision = $AreaColision/CollisionShape2D
@onready var rastro = $Rastro

static var cache_texturas: Dictionary = {}

var direccion: Vector2 = Vector2.RIGHT
var velocidad: float = 380.0
var velocidad_rotacion: float = 8.0
var activo: bool = true
var tiempo_vida: float = 6.0
var es_disparo_directora: bool = false

func obtener_textura_balon(tipo_balon: int) -> Texture2D:
	if tipo_balon in cache_texturas and cache_texturas[tipo_balon] != null:
		return cache_texturas[tipo_balon]
		
	var mapa_rutas = {
		0: "res://assets/props_clean/basketball01.png",
		1: "res://assets/props_clean/chanceball01.png",
		2: "res://assets/props_clean/crashball01.png",
		3: "res://assets/props_clean/item_freeze_ball.png",
		4: "res://assets/props_clean/item_omoball00.png",
		5: "res://assets/props_clean/item_pie.png",
		6: "res://assets/props_clean/item_banana_ground.png",
		99: "res://assets/props_clean/item_dekaball00.png"
	}
	
	var ruta = mapa_rutas.get(tipo_balon, mapa_rutas[0])
	var tex: Texture2D = null
	if ResourceLoader.exists(ruta):
		tex = load(ruta)
	else:
		var img = Image.load_from_file(ProjectSettings.globalize_path(ruta))
		if img:
			tex = ImageTexture.create_from_image(img)
			
	cache_texturas[tipo_balon] = tex
	return tex

func configurar(pos_inicio: Vector2, dir: Vector2, vel: float = 380.0, tipo_balon: int = 0):
	global_position = pos_inicio
	direccion = dir.normalized()
	velocidad = vel
	velocidad_rotacion = randf_range(8.0, 13.0) * (1.0 if dir.x >= 0 else -1.0)
	es_disparo_directora = (tipo_balon == 99)
	
	if sprite_balon:
		var tex = obtener_textura_balon(tipo_balon)
		sprite_balon.texture = tex
		
		# Ajuste de escala según la resolución del sprite limpio
		match tipo_balon:
			0, 1, 2, 4: # Balones estándar (18-20px)
				sprite_balon.scale = Vector2(1.9, 1.9)
			3: # Freeze ball (30px)
				sprite_balon.scale = Vector2(1.3, 1.3)
				if rastro: rastro.color = Color(0.2, 0.9, 1.0, 0.65)
			5: # Pastel (27px)
				sprite_balon.scale = Vector2(1.4, 1.4)
				velocidad_rotacion *= 0.5
				if rastro: rastro.color = Color(1.0, 0.95, 0.8, 0.5)
			6: # Plátano (21px)
				sprite_balon.scale = Vector2(1.7, 1.7)
				velocidad_rotacion *= 1.4
				if rastro: rastro.color = Color(1.0, 0.88, 0.2, 0.5)
			99: # Cañonazo súper veloz de la Directora (36px dekaball o bola gigante de fuego)
				sprite_balon.scale = Vector2(1.5, 1.5)
				velocidad_rotacion *= 1.6
				if shape_colision and shape_colision.shape is CircleShape2D:
					shape_colision.shape.radius = 24.0
				if rastro:
					rastro.amount = 18
					rastro.lifetime = 0.35
					rastro.color = Color(1.0, 0.45, 0.1, 0.85)

func _ready():
	if area_colision:
		area_colision.body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if not activo: return
	
	global_position += direccion * velocidad * delta
	if sprite_balon:
		sprite_balon.rotation += velocidad_rotacion * delta
		
	tiempo_vida -= delta
	if tiempo_vida <= 0.0 or global_position.x < -100 or global_position.x > 1250 or global_position.y < -100 or global_position.y > 750:
		queue_free()

func _on_body_entered(body: Node2D):
	if not activo: return
	if body is CharacterBody2D and body.is_in_group("Jugador"):
		var id_jugador = body.name.to_int()
		if id_jugador > 0:
			activo = false
			emit_signal("impacto_jugador", id_jugador)
			
			# Pequeña animación de rebote y desaparición al golpear
			var tween = create_tween()
			tween.tween_property(self, "scale", Vector2(1.4, 0.6), 0.06)
			tween.tween_property(self, "modulate:a", 0.0, 0.15)
			await tween.finished
			queue_free()
