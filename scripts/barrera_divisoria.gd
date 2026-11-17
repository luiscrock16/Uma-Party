extends Node2D
class_name BarreraDivisoria

@onready var cuerpo_estatico = $CuerpoEstatico
@onready var colision_estatica = $CuerpoEstatico/CollisionShape2D
@onready var area_choque = $AreaChoque
@onready var visual = $Visual
@onready var laser_principal = $Visual/LaserPrincipal
@onready var laser_brillo = $Visual/LaserBrillo
@onready var particulas = $Visual/ParticulasChispas

var duracion_activa: float = 8.5
var activa: bool = false
var es_orientacion_horizontal: bool = false
var longitud_personalizada: float = 350.0

func configurar(duracion: float = 8.5, es_horizontal: bool = false, longitud: float = 350.0):
	duracion_activa = duracion
	es_orientacion_horizontal = es_horizontal
	longitud_personalizada = longitud
	
	if es_horizontal:
		rotation = PI * 0.5
		
	if is_node_ready() and longitud != 350.0:
		ajustar_longitud(longitud)

func ajustar_longitud(longitud: float):
	var half = longitud * 0.5
	if colision_estatica:
		var rect = RectangleShape2D.new()
		rect.size = Vector2(22.0, longitud)
		colision_estatica.shape = rect
		
	var shape_area = area_choque.get_node_or_null("CollisionShape2D") if area_choque else null
	if shape_area:
		var rect_a = RectangleShape2D.new()
		rect_a.size = Vector2(34.0, longitud)
		shape_area.shape = rect_a
		
	if laser_principal: laser_principal.points = PackedVector2Array([Vector2(0, -half), Vector2(0, half)])
	if laser_brillo: laser_brillo.points = PackedVector2Array([Vector2(0, -half), Vector2(0, half)])
	var laser_central = visual.get_node_or_null("LaserCentral")
	if laser_central: laser_central.points = PackedVector2Array([Vector2(0, -half), Vector2(0, half)])
	
	var poste_arriba = visual.get_node_or_null("PosteArriba")
	var poste_abajo = visual.get_node_or_null("PosteAbajo")
	if poste_arriba: poste_arriba.position = Vector2(0, -half)
	if poste_abajo: poste_abajo.position = Vector2(0, half)
	if particulas: particulas.emission_rect_extents = Vector2(4, max(10, half - 10))

func _ready():
	if longitud_personalizada != 350.0:
		ajustar_longitud(longitud_personalizada)
		
	if colision_estatica:
		colision_estatica.set_deferred("disabled", true)
	if area_choque:
		area_choque.monitoring = false
		area_choque.body_entered.connect(_on_body_entered)
	if particulas:
		particulas.emitting = false
		
	iniciar_secuencia()

func iniciar_secuencia():
	# 1. Fase de aviso: Parpadeo tenue previo
	visual.modulate.a = 0.2
	var tween_aviso = create_tween().set_loops(3)
	tween_aviso.tween_property(visual, "modulate:a", 0.75, 0.18)
	tween_aviso.tween_property(visual, "modulate:a", 0.2, 0.18)
	await tween_aviso.finished
	
	# 2. Despliegue y activación total de la barrera
	activa = true
	visual.modulate.a = 1.0
	if colision_estatica:
		colision_estatica.set_deferred("disabled", false)
	if area_choque:
		area_choque.set_deferred("monitoring", true)
	if particulas:
		particulas.emitting = true
		
	# Efecto de escala inicial al emerger
	visual.scale.x = 0.2
	var tween_crecer = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_crecer.tween_property(visual, "scale:x", 1.0, 0.25)
	
	# Parpadeo continuo de energía mientras está activa
	var tween_energia = create_tween().set_loops()
	tween_energia.tween_property(laser_brillo, "modulate:a", 0.4, 0.25)
	tween_energia.tween_property(laser_brillo, "modulate:a", 1.0, 0.25)
	
	# Esperar la duración activa
	await get_tree().create_timer(duracion_activa).timeout
	tween_energia.kill()
	
	# 3. Aviso de desactivación
	var tween_salida = create_tween().set_loops(4)
	tween_salida.tween_property(visual, "modulate:a", 0.3, 0.12)
	tween_salida.tween_property(visual, "modulate:a", 1.0, 0.12)
	await tween_salida.finished
	
	# Desactivar colisiones y desaparecer
	activa = false
	if colision_estatica:
		colision_estatica.set_deferred("disabled", true)
	if area_choque:
		area_choque.set_deferred("monitoring", false)
	if particulas:
		particulas.emitting = false
		
	var tween_colapso = create_tween()
	tween_colapso.tween_property(visual, "scale:x", 0.0, 0.2)
	tween_colapso.tween_property(visual, "modulate:a", 0.0, 0.1)
	await tween_colapso.finished
	queue_free()

func _on_body_entered(body: Node2D):
	if not activa: return
	if body is CharacterBody2D and body.is_in_group("Jugador"):
		# Empujar al jugador hacia su propio lado de la barrera para evitar que quede atrapado
		var dir_repulsion = Vector2.ZERO
		if es_orientacion_horizontal:
			var dir_y = 1.0 if body.global_position.y >= global_position.y else -1.0
			dir_repulsion = Vector2(randf_range(-150.0, 150.0), dir_y * 850.0)
		else:
			var dir_x = 1.0 if body.global_position.x >= global_position.x else -1.0
			dir_repulsion = Vector2(dir_x * 850.0, randf_range(-150.0, 150.0))
			
		if body.has_method("recibir_golpe_externo_rpc"):
			if multiplayer.has_multiplayer_peer():
				body.recibir_golpe_externo_rpc.rpc(dir_repulsion)
			else:
				body.recibir_golpe_externo_rpc(dir_repulsion)
