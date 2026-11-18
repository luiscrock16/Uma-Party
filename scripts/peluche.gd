extends CharacterBody2D
class_name Peluche

@export var tipo_peluche: int = 0 # 0: Suzuka, 1: Zanahoria, 2: Caballito Rosa

var esta_atrapado: bool = false
var en_caida_libre: bool = false
var destino_y_caida: float = 0.0
const VELOCIDAD_CAIDA: float = 600.0

@onready var sprite: Sprite2D = $Sprite
@onready var visual_rect = $VisualRect
@onready var label_icono = $VisualRect/LabelIcono
@onready var collision_shape = $CollisionShape2D

var tex_suzuka = preload("res://assets/minijuego_garra/peluche_0_suzuka.png")
var tex_zanahoria = preload("res://assets/minijuego_garra/peluche_1_zanahoria.png")
var tex_caballito = preload("res://assets/minijuego_garra/peluche_2_caballito.png")

func _ready():
	add_to_group("Peluche")
	aplicar_estilo_visual()

func aplicar_estilo_visual():
	if not sprite:
		sprite = get_node_or_null("Sprite")
	match tipo_peluche:
		0:
			if sprite: sprite.texture = tex_suzuka
			if visual_rect: visual_rect.color = Color(1.0, 0.85, 0.1, 1.0)
			if label_icono: label_icono.text = "★"
		1:
			if sprite: sprite.texture = tex_zanahoria
			if visual_rect: visual_rect.color = Color(1.0, 0.5, 0.1, 1.0)
			if label_icono: label_icono.text = "🥕"
		2:
			if sprite: sprite.texture = tex_caballito
			if visual_rect: visual_rect.color = Color(1.0, 0.45, 0.75, 1.0)
			if label_icono: label_icono.text = "🧸"
		_:
			if sprite: sprite.texture = tex_suzuka

func _physics_process(delta):
	if esta_atrapado:
		velocity = Vector2.ZERO
		return
		
	if en_caida_libre:
		global_position.y += VELOCIDAD_CAIDA * delta
		
		# Si llega o pasa la altura del suelo
		if global_position.y >= destino_y_caida:
			global_position.y = destino_y_caida
			en_caida_libre = false
			aterrizar_peluche()
		return

func aterrizar_peluche():
	# Pequeño efecto de rebote / squash
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "scale", Vector2(1.1, 0.65), 0.08)
		tw.tween_property(sprite, "scale", Vector2(0.85, 0.85), 0.14)

	var mapa = get_tree().root.get_node_or_null("MapaActual")
	var es_autoridad = not multiplayer.has_multiplayer_peer() or (mapa and mapa.has_method("es_autoridad_de_partida") and mapa.es_autoridad_de_partida())
	if es_autoridad:
		# Verificar si aterrizó en la zona de eliminación / premios
		if mapa and mapa.has_node("ZonaEliminacion"):
			var zona = mapa.get_node("ZonaEliminacion")
			# Si el peluche cayó dentro del área de eliminación
			if zona.overlaps_body(self):
				if mapa.has_method("registrar_premio_peluche"):
					mapa.registrar_premio_peluche(tipo_peluche)
				queue_free()
				return
				
	# Si aterrizó en la plataforma, queda como obstáculo sólido
	velocity = Vector2.ZERO

@rpc("any_peer", "call_local", "reliable")
func sincronizar_atrapado_rpc(atrapado: bool):
	esta_atrapado = atrapado
	if collision_shape:
		collision_shape.set_deferred("disabled", atrapado)

@rpc("any_peer", "call_local", "reliable")
func iniciar_caida_libre_rpc(pos_y_destino: float):
	esta_atrapado = false
	en_caida_libre = true
	destino_y_caida = pos_y_destino
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

func recibir_golpe_externo_rpc(_fuerza):
	pass
