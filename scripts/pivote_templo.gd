extends Node2D
class_name PivoteTemplo

@onready var cuerpo_estatico = $CuerpoEstatico
@onready var colision = $CuerpoEstatico/CollisionShape2D
@onready var visual = $Visual
@onready var sprite_bumper: Sprite2D = $Visual/SpriteBumper
@onready var sprite_hueco: Sprite2D = $Visual/SpriteHueco
@onready var particulas_polvo = $ParticulasPolvo

var esta_alzado: bool = true
var es_fijo: bool = false # Si es fijo, nunca se esconde

func _ready():
	if particulas_polvo:
		particulas_polvo.emitting = false
	if esta_alzado:
		alzar(false)
	else:
		esconder(false)

func configurar(alzado_inicial: bool = true, fijo: bool = false):
	esta_alzado = alzado_inicial
	es_fijo = fijo

func alzar(con_animacion: bool = true):
	esta_alzado = true
	if colision:
		colision.set_deferred("disabled", false)
		
	if not con_animacion:
		if sprite_bumper:
			sprite_bumper.scale = Vector2(1.0, 1.0)
			sprite_bumper.modulate.a = 1.0
			sprite_bumper.visible = true
		return
		
	if particulas_polvo:
		particulas_polvo.restart()
		particulas_polvo.emitting = true
		
	if sprite_bumper:
		sprite_bumper.visible = true
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite_bumper, "scale", Vector2(1.0, 1.0), 0.22)
		tween.parallel().tween_property(sprite_bumper, "modulate:a", 1.0, 0.18)

func esconder(con_animacion: bool = true):
	if es_fijo: return
	esta_alzado = false
	if colision:
		colision.set_deferred("disabled", true)
		
	if not con_animacion:
		if sprite_bumper:
			sprite_bumper.scale = Vector2(0.2, 0.2)
			sprite_bumper.modulate.a = 0.0
			sprite_bumper.visible = false
		return
		
	if sprite_bumper:
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite_bumper, "scale", Vector2(0.2, 0.2), 0.18)
		tween.parallel().tween_property(sprite_bumper, "modulate:a", 0.0, 0.18)
		tween.tween_callback(func(): sprite_bumper.visible = false)

func conmutar():
	if es_fijo: return
	if esta_alzado:
		esconder()
	else:
		alzar()

func reaccionar_impacto():
	if not esta_alzado: return
	if sprite_bumper:
		var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite_bumper, "scale", Vector2(1.3, 0.8), 0.06)
		tween.tween_property(sprite_bumper, "scale", Vector2(1.0, 1.0), 0.16)
