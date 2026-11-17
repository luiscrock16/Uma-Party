extends Node2D
class_name ObstaculoCaida

signal aplasto_jugador(id_jugador: int)

enum Tipo { PIANO, PESA, BARRIL, VALLA }
var tipo_actual: Tipo = Tipo.PIANO

@onready var sombra = $Sombra
@onready var sprite_objeto = $ObjetoVisual
@onready var area_impacto = $AreaImpacto
@onready var shape_impacto = $AreaImpacto/CollisionShape2D
@onready var particulas_polvo = $ParticulasPolvo
@onready var particulas_notas = $ParticulasNotas

var target_pos: Vector2 = Vector2.ZERO
var tiempo_aviso: float = 1.8
var ya_impacto: bool = false

func configurar(tipo: int, pos_destino: Vector2, duracion_aviso: float, _radio_unused: float = 52.0):
	tipo_actual = tipo as Tipo
	target_pos = pos_destino
	global_position = pos_destino
	tiempo_aviso = duracion_aviso

func _ready():
	configurar_hitbox_por_tipo()
	configurar_apariencia_por_tipo()
	
	if area_impacto:
		area_impacto.monitoring = false
		area_impacto.monitorable = false
		area_impacto.body_entered.connect(_on_body_entered)
		
	if particulas_polvo:
		particulas_polvo.emitting = false
	if particulas_notas:
		particulas_notas.emitting = false
		
	iniciar_secuencia_caida()

func configurar_hitbox_por_tipo():
	if not shape_impacto: return
	
	# Variedad de hitboxes según la silueta de cada objeto
	match tipo_actual:
		Tipo.PIANO:
			# Hitbox rectangular ancha para el piano de cola
			var rect = RectangleShape2D.new()
			rect.size = Vector2(104, 68)
			shape_impacto.shape = rect
			shape_impacto.position = Vector2(0, 0)
		Tipo.PESA:
			# Hitbox compacta pero densa para la pesa de 1000t
			var rect = RectangleShape2D.new()
			rect.size = Vector2(76, 54)
			shape_impacto.shape = rect
			shape_impacto.position = Vector2(0, 0)
		Tipo.BARRIL:
			# Hitbox circular/cilíndrica
			var circle = CircleShape2D.new()
			circle.radius = 35.0
			shape_impacto.shape = circle
			shape_impacto.position = Vector2(0, 0)
		Tipo.VALLA:
			# Hitbox alargada horizontal (valla de salto/obstáculo de pista)
			var rect = RectangleShape2D.new()
			rect.size = Vector2(146, 38)
			shape_impacto.shape = rect
			shape_impacto.position = Vector2(0, 0)

func configurar_apariencia_por_tipo():
	if not sprite_objeto or not sombra: return
	
	# Activar únicamente el nodo visual correspondiente
	var nodo_piano = sprite_objeto.get_node_or_null("Piano")
	var nodo_pesa = sprite_objeto.get_node_or_null("Pesa")
	var nodo_barril = sprite_objeto.get_node_or_null("Barril")
	var nodo_valla = sprite_objeto.get_node_or_null("Valla")
	
	if nodo_piano: nodo_piano.visible = (tipo_actual == Tipo.PIANO)
	if nodo_pesa: nodo_pesa.visible = (tipo_actual == Tipo.PESA)
	if nodo_barril: nodo_barril.visible = (tipo_actual == Tipo.BARRIL)
	if nodo_valla: nodo_valla.visible = (tipo_actual == Tipo.VALLA)
	
	# Ajustar forma de la sombra según el objeto
	var sombra_piano = sombra.get_node_or_null("SombraPiano")
	var sombra_circulo = sombra.get_node_or_null("SombraCirculo")
	var sombra_valla = sombra.get_node_or_null("SombraValla")
	
	if sombra_piano: sombra_piano.visible = (tipo_actual == Tipo.PIANO)
	if sombra_circulo: sombra_circulo.visible = (tipo_actual == Tipo.PESA or tipo_actual == Tipo.BARRIL)
	if sombra_valla: sombra_valla.visible = (tipo_actual == Tipo.VALLA)

func iniciar_secuencia_caida():
	# 1. La sombra empieza pequeña y tenue en el suelo
	sombra.scale = Vector2(0.2, 0.2)
	sombra.modulate.a = 0.25
	
	# El objeto inicia muy arriba fuera de la pantalla
	sprite_objeto.position = Vector2(0, -780)
	sprite_objeto.scale = Vector2(1.0, 1.0)
	
	# Crecimiento progresivo de la sombra conforme se "acerca" el objeto
	var tween_sombra = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween_sombra.tween_property(sombra, "scale", Vector2(1.15, 1.15), tiempo_aviso)
	tween_sombra.parallel().tween_property(sombra, "modulate:a", 0.9, tiempo_aviso)
	
	# El objeto cae en picada en el último tramo del tiempo de aviso
	var tiempo_caida_visible = min(0.42, tiempo_aviso * 0.38)
	var tiempo_espera = max(0.01, tiempo_aviso - tiempo_caida_visible)
	
	await get_tree().create_timer(tiempo_espera).timeout
	
	var tween_caida = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween_caida.tween_property(sprite_objeto, "position:y", 0.0, tiempo_caida_visible)
	await tween_caida.finished
	
	impactar_suelo()

func impactar_suelo():
	if ya_impacto: return
	ya_impacto = true
	
	# Activar la hitbox letal durante el impacto
	area_impacto.set_deferred("monitoring", true)
	
	# Partículas de choque según el tipo
	if particulas_polvo:
		particulas_polvo.restart()
		particulas_polvo.emitting = true
	if tipo_actual == Tipo.PIANO and particulas_notas:
		particulas_notas.restart()
		particulas_notas.emitting = true
		
	# Efecto elástico de impacto (squash & stretch cartoon)
	var tween_impacto = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween_impacto.tween_property(sprite_objeto, "scale", Vector2(1.3, 0.7), 0.07)
	tween_impacto.tween_property(sprite_objeto, "scale", Vector2(1.0, 1.0), 0.14)
	
	# Apagar la hitbox tras el golpe
	await get_tree().create_timer(0.12).timeout
	area_impacto.set_deferred("monitoring", false)
	
	# El objeto permanece brevemente en el suelo y se desvanece
	await get_tree().create_timer(0.55).timeout
	var tween_fade = create_tween()
	tween_fade.tween_property(self, "modulate:a", 0.0, 0.28)
	await tween_fade.finished
	queue_free()

func _on_body_entered(body: Node2D):
	if body is CharacterBody2D and body.is_in_group("Jugador"):
		var id_jugador = body.name.to_int()
		if id_jugador > 0:
			emit_signal("aplasto_jugador", id_jugador)
