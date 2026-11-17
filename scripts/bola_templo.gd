extends RigidBody2D
class_name BolaTemplo

signal aplasto_jugador(id_jugador: int)

@onready var visual = $Visual
@onready var sprite_bola: Sprite2D = $Visual/SpriteBola
@onready var sombra: Polygon2D = $Visual/SombraEsfera
@onready var area_impacto = $AreaImpacto
@onready var particulas_rastro = $ParticulasRastro
@onready var particulas_golpe = $ParticulasGolpe

var ya_impacto: bool = false
var tipo_bola: int = 0

# Texturas oficiales de balones de Tracen
const TEXTURAS_BALONES = [
	preload("res://assets/props_clean/basketball01.png"),
	preload("res://assets/props_clean/chanceball01.png"),
	preload("res://assets/props_clean/crashball01.png"),
	preload("res://assets/props_clean/item_dekaball00.png")
]

const ESCALAS_BALONES = [
	Vector2(1.78, 1.78), # 18x18 -> 32px
	Vector2(1.6, 1.6),   # 20x20 -> 32px
	Vector2(1.6, 1.6),   # 20x20 -> 32px
	Vector2(0.9, 0.9)    # 36x36 -> 32.4px
]

const COLORES_RASTRO = [
	Color(1.0, 0.62, 0.2, 0.5), # Naranja básquet
	Color(1.0, 0.88, 0.25, 0.65), # Oro estrella
	Color(0.95, 0.25, 0.3, 0.6), # Rojo choque
	Color(0.4, 0.75, 1.0, 0.6)   # Azul deka
]

func _ready():
	if area_impacto:
		area_impacto.body_entered.connect(_on_body_entered)
		area_impacto.area_entered.connect(_on_area_entered)
	if particulas_golpe:
		particulas_golpe.emitting = false
	aplicar_tipo_visual(tipo_bola)

func configurar_tipo(p_tipo: int):
	tipo_bola = p_tipo
	if is_inside_tree():
		aplicar_tipo_visual(tipo_bola)

func aplicar_tipo_visual(p_tipo: int):
	var idx = clamp(p_tipo, 0, TEXTURAS_BALONES.size() - 1)
	if sprite_bola:
		sprite_bola.texture = TEXTURAS_BALONES[idx]
		sprite_bola.scale = ESCALAS_BALONES[idx]
	if particulas_rastro:
		particulas_rastro.color = COLORES_RASTRO[idx]

func _physics_process(delta):
	# Rotación visual según velocidad física angular y lateral
	if sprite_bola:
		sprite_bola.rotation += linear_velocity.x * 0.015 * delta
		
	# Si cae por debajo del foso inferior de la plataforma
	if global_position.y > 680 or global_position.x < -100 or global_position.x > 1250:
		queue_free()

func _on_body_entered(body: Node2D):
	if ya_impacto: return
	if body is CharacterBody2D and body.is_in_group("Jugador"):
		impactar_jugador(body.name.to_int())

func _on_area_entered(area: Area2D):
	if ya_impacto: return
	var padre = area.get_parent()
	if padre is CharacterBody2D and padre.is_in_group("Jugador"):
		impactar_jugador(padre.name.to_int())

func impactar_jugador(id_jugador: int):
	if ya_impacto or id_jugador <= 0: return
	ya_impacto = true
	if particulas_golpe:
		particulas_golpe.restart()
		particulas_golpe.emitting = true
	emit_signal("aplasto_jugador", id_jugador)
