extends Node2D
class_name GloboEquipo

signal globo_reventado(equipo: int, id_globo: int, id_jugador: int)

@onready var visual = $Visual
@onready var globo_cuerpo = $Visual/GloboCuerpo
@onready var hilo = $Visual/Hilo
@onready var sombra = $SombraSuelo
@onready var area_colision = $AreaColision
@onready var particulas_pop = $ParticulasPop

var equipo: int = 0 # 0: Rojo, 1: Azul
var id_globo: int = 0
var reventado: bool = false

var pos_base: Vector2 = Vector2.ZERO
var offset_tiempo: float = 0.0
var velocidad_flotacion: float = 3.0

func configurar(p_equipo: int, p_id: int):
	equipo = p_equipo
	id_globo = p_id
	pos_base = position
	offset_tiempo = randf() * 10.0
	velocidad_flotacion = randf_range(2.5, 3.5)
	
	actualizar_color_equipo()

func _ready():
	if particulas_pop:
		particulas_pop.emitting = false
	if area_colision:
		area_colision.body_entered.connect(_on_body_entered)
	actualizar_color_equipo()

func actualizar_color_equipo():
	if not visual: return
	var cuerpo = visual.get_node_or_null("GloboCuerpo")
	var nudo = visual.get_node_or_null("Nudo")
	var hilo_nodo = visual.get_node_or_null("Hilo")
	
	if equipo == 0:
		# Equipo Rojo / Magenta festivo
		if cuerpo: cuerpo.color = Color(0.96, 0.22, 0.32, 1)
		if nudo: nudo.color = Color(0.82, 0.16, 0.24, 1)
		if hilo_nodo: hilo_nodo.default_color = Color(0.9, 0.8, 0.85, 0.8)
		if particulas_pop: particulas_pop.color = Color(1.0, 0.3, 0.4, 0.95)
	else:
		# Equipo Azul / Celeste vibrante
		if cuerpo: cuerpo.color = Color(0.18, 0.58, 0.98, 1)
		if nudo: nudo.color = Color(0.12, 0.42, 0.82, 1)
		if hilo_nodo: hilo_nodo.default_color = Color(0.8, 0.88, 0.95, 0.8)
		if particulas_pop: particulas_pop.color = Color(0.3, 0.7, 1.0, 0.95)

func _process(delta):
	if reventado: return
	
	# Suave flotación oscilatoria de globo
	offset_tiempo += delta * velocidad_flotacion
	var desplazamiento_y = sin(offset_tiempo) * 4.5
	var desplazamiento_x = cos(offset_tiempo * 0.7) * 2.0
	visual.position = Vector2(desplazamiento_x, desplazamiento_y)
	
	# La sombra en el suelo responde a la altura del globo
	if sombra:
		var factor_escala = 1.0 - (desplazamiento_y * 0.03)
		sombra.scale = Vector2(factor_escala, factor_escala * 0.45)

func reventar(id_jugador: int):
	if reventado: return
	reventado = true
	
	if area_colision:
		area_colision.set_deferred("monitoring", false)
		
	# Efecto de partículas de estallido
	if particulas_pop:
		particulas_pop.restart()
		particulas_pop.emitting = true
		
	# Animación pop (crece bruscamente y desaparece)
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", Vector2(1.5, 1.5), 0.08)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.09)
	if sombra:
		tween.parallel().tween_property(sombra, "modulate:a", 0.0, 0.08)
		
	await tween.finished
	emit_signal("globo_reventado", equipo, id_globo, id_jugador)
	queue_free()

func rebotar_rival():
	# Si un rival choca con el globo de otro equipo, el globo vibra y lo empuja sutilmente
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", Vector2(0.75, 1.25), 0.06)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.2)

func _on_body_entered(body: Node2D):
	if reventado: return
	if body is CharacterBody2D and body.is_in_group("Jugador"):
		var id_jugador = body.name.to_int()
		var mapa = get_tree().root.get_node_or_null("MapaActual")
		if not mapa:
			mapa = get_parent().get_parent() # Respaldo para F6
			
		var equipo_jugador = 0
		if mapa and mapa.has_method("obtener_equipo_jugador"):
			equipo_jugador = mapa.obtener_equipo_jugador(id_jugador)
			
		if equipo_jugador == equipo:
			# El jugador tocó el globo de su propio equipo -> ¡Revienta!
			if multiplayer.has_multiplayer_peer():
				if multiplayer.is_server():
					mapa.reventar_globo_rpc.rpc(id_globo, id_jugador)
			else:
				if mapa and mapa.has_method("reventar_globo_local"):
					mapa.reventar_globo_local(id_globo, id_jugador)
				else:
					reventar(id_jugador)
		else:
			# Tocó globo rival -> Rebote elástico
			rebotar_rival()
			var dir_empuje = (body.global_position - global_position).normalized()
			if body.has_method("recibir_golpe_externo_rpc"):
				body.fuerza_knockback = dir_empuje * 350.0
