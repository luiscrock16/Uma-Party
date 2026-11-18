extends Area2D
class_name ProyectilCanon

signal exploto(pos: Vector2)

@export var velocidad: float = 540.0
var id_dueno: int = -1
var tiempo_vida: float = 3.5
var direccion: Vector2 = Vector2.RIGHT
var ya_impacto: bool = false
var rebotes: int = 0
var max_rebotes: int = 8
var permitir_dano_dueno: bool = false
var ha_rebotado: bool = false

@onready var trail_particulas = $TrailParticulas

func _ready():
	area_entered.connect(_on_area_entered)

func inicializar(dueno_id: int, pos: Vector2, rot: float):
	id_dueno = dueno_id
	set_meta("id_jugador", dueno_id)
	global_position = pos
	global_rotation = rot
	direccion = Vector2.RIGHT.rotated(rot)
	rebotes = 0
	permitir_dano_dueno = false
	ha_rebotado = false
	tiempo_vida = 3.5

func _physics_process(delta):
	if ya_impacto: return
	
	global_position += direccion * velocidad * delta
	tiempo_vida -= delta
	
	# Si ya rebotó, se le permite mantenerse más tiempo en juego rebotando
	if tiempo_vida <= 0.0 or global_position.x < -180 or global_position.x > 1330 or global_position.y < -180 or global_position.y > 830:
		destruir_proyectil(false, false)

func _on_area_entered(area: Area2D):
	if ya_impacto: return
	
	# Caso 0: Impacto contra Muro de Rebote (Fase Muerte Súbita)
	if area.has_meta("es_muro_rebote"):
		var centro_torre: Vector2 = area.get_meta("centro_torre", Vector2(576, 330))
		var normal_rebote: Vector2 = (centro_torre - global_position).normalized()
		rebotar(normal_rebote)
		return
	
	# Caso 3: Colisión frontal / mutua entre proyectiles en el aire (¡Denegación defensiva!)
	if area is ProyectilCanon and area != self:
		ya_impacto = true
		destruir_proyectil(true, false)
		return
	
	var id_area = area.get_meta("id_jugador", -1)
	
	# Caso: ¡Riesgo propio tras rebote!
	# Si la bala ya rebotó y choca contra elementos de su propio dueño (personaje, cañón o plataforma),
	# el dueño recibe daño de inmediato por su propio proyectil rebotado.
	if id_area == id_dueno and permitir_dano_dueno:
		ya_impacto = true
		var plataforma = area.get_meta("plataforma", null)
		if plataforma and not plataforma.eliminada and not plataforma.en_invulnerabilidad:
			plataforma.recibir_impacto()
		destruir_proyectil(true, true)
		return

	# Ignorar colisiones con elementos propios del jugador que disparó mientras sale (sin rebotar aún)
	if id_area == id_dueno and not permitir_dano_dueno:
		return
	
	# Caso 1: Impacto directo sobre el PERSONAJE rival (¡Recibe daño!)
	if area.has_meta("es_personaje"):
		ya_impacto = true
		var plataforma = area.get_meta("plataforma", null)
		if plataforma and not plataforma.eliminada and not plataforma.en_invulnerabilidad:
			plataforma.recibir_impacto()
		destruir_proyectil(true, true)
		return
			
	# Caso 2: Impacto contra el CAÑÓN o el CENTRO BLINDADO rival (¡Bloqueado, 0 daño!)
	if area.has_meta("es_escudo"):
		ya_impacto = true
		destruir_proyectil(true, false)
		return

func rebotar(normal: Vector2):
	if ya_impacto: return
	
	# Si la bala va en dirección al muro (saliendo hacia afuera), calcular rebote hacia adentro
	if direccion.dot(normal) < 0.0:
		direccion = direccion.bounce(normal).normalized()
		global_rotation = direccion.angle()
		rebotes += 1
		ha_rebotado = true
		permitir_dano_dueno = true # ¡A partir de aquí es peligroso para todos, incluido quien lo disparó!
		tiempo_vida = max(tiempo_vida, 5.0)
		
		# Desplazar ligeramente hacia el centro para evitar solapamiento
		global_position += normal * 12.0
		
		# Animación elástica de impacto/rebote
		reproducir_efecto_rebote()
		
		# Si superó el número máximo de rebotes permitidos, se autodestruye
		if rebotes >= max_rebotes:
			destruir_proyectil(true, false)

func reproducir_efecto_rebote():
	# Destello / tinte más vivo de advertencia (balas en rebote activo)
	modulate = Color(1.25, 0.75, 0.4)
	if trail_particulas:
		trail_particulas.color = Color(1.0, 0.35, 0.1, 0.95)
		trail_particulas.speed_scale = 1.8
		
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.35, 0.75), 0.04)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.07)

func destruir_proyectil(con_efecto: bool = true, fue_impacto_personaje: bool = false):
	ya_impacto = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	emit_signal("exploto", global_position)
	
	if con_efecto:
		var tween = create_tween()
		if fue_impacto_personaje:
			# Explosión más llamativa al impactar al personaje
			tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.1)
			tween.parallel().tween_property(self, "modulate", Color(1, 0.4, 0.2, 0.0), 0.1)
		else:
			# Chispazo metálico rápido al impactar contra el cañón o escudo
			tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.06)
			tween.parallel().tween_property(self, "modulate", Color(1, 0.9, 0.5, 0.0), 0.06)
		await tween.finished
		
	queue_free()
