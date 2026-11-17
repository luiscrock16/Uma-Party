extends Node2D
class_name PlataformaCanon

signal proyectil_disparado(id_dueno: int, pos_global: Vector2, rot_global: float)
signal jugador_golpeado(id_jugador: int, vidas_restantes: int)

@export var id_jugador: int = -1
@export var vidas: int = 3
@export var velocidad_giro: float = 2.85 # rad/s (~163 deg/s)
@export var sentido_giro: float = 1.0 # 1.0 o -1.0
@export var color_base: Color = Color("#ff4757")

@onready var base_circulo = $BaseVisual/DiscoBase
@onready var aro_color = $BaseVisual/AroColor
@onready var montura = $Montura
@onready var canon = $Montura/CanonVisual
@onready var canon_tubo = $Montura/CanonVisual/TuboCanon
@onready var punto_disparo = $Montura/CanonVisual/PuntoDisparo
@onready var flash_disparo = $Montura/CanonVisual/FlashDisparo
@onready var punto_personaje = $Montura/PuntoPersonaje
@onready var soporte_personaje = $Montura/SoportePersonaje
@onready var area_personaje = $Montura/PuntoPersonaje/AreaPersonaje
@onready var area_escudo_canon = $Montura/CanonVisual/AreaEscudoCanon
@onready var area_escudo_centro = $BaseVisual/AreaEscudoCentro
@onready var humo_eliminado = $HumoEliminado
@onready var flash_explosion = get_node_or_null("ExplosionFlash")
@onready var explosion_particulas = get_node_or_null("ExplosionParticulas")

var avatar_asignado: Node2D = null
var activa: bool = false
var detenida: bool = false
var eliminada: bool = false
var en_cooldown: bool = false
var en_invulnerabilidad: bool = false
var pos_inicial_tubo: Vector2 = Vector2.ZERO

func _ready():
	if canon_tubo:
		pos_inicial_tubo = canon_tubo.position
	if flash_disparo:
		flash_disparo.visible = false
	if flash_explosion:
		flash_explosion.visible = false
	if explosion_particulas:
		explosion_particulas.emitting = false
	if humo_eliminado:
		humo_eliminado.emitting = false
	aplicar_color(color_base)

func aplicar_color(color: Color):
	color_base = color
	if aro_color:
		aro_color.default_color = color
	if soporte_personaje:
		soporte_personaje.color = color.lerp(Color(0.15, 0.15, 0.2), 0.3)

func configurar(id: int, col: Color, avatar: Node2D, sentido: float = 1.0):
	id_jugador = id
	sentido_giro = sentido
	aplicar_color(col)
	vidas = 3
	velocidad_giro = 2.85
	eliminada = false
	detenida = false
	activa = false
	en_cooldown = false
	en_invulnerabilidad = false
	
	# Configurar metadatos para detección de impactos precisa
	if area_personaje:
		area_personaje.set_meta("es_personaje", true)
		area_personaje.set_meta("id_jugador", id)
		area_personaje.set_meta("plataforma", self)
		
	if area_escudo_canon:
		area_escudo_canon.set_meta("es_escudo", true)
		area_escudo_canon.set_meta("id_jugador", id)
		area_escudo_canon.set_meta("plataforma", self)
		
	if area_escudo_centro:
		area_escudo_centro.set_meta("es_escudo", true)
		area_escudo_centro.set_meta("id_jugador", id)
		area_escudo_centro.set_meta("plataforma", self)
	
	if avatar:
		asignar_avatar(avatar)

func asignar_avatar(avatar: Node2D):
	avatar_asignado = avatar
	
	if avatar.has_method("bloquear_controles"):
		avatar.bloquear_controles(true)
	avatar.set_physics_process(false)
	
	# Desactivamos componentes que puedan interferir en la plataforma
	var sync = avatar.get_node_or_null("MultiplayerSynchronizer")
	if sync:
		sync.replication_config = null
		sync.queue_free()
		
	var hurtbox = avatar.get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.queue_free()
		
	var col = avatar.get_node_or_null("CollisionShape2D")
	if col:
		col.disabled = true
	
	# Reparentar al punto del personaje en la montura
	if avatar.get_parent():
		avatar.get_parent().remove_child(avatar)
	punto_personaje.add_child(avatar)
	avatar.position = Vector2.ZERO
	avatar.rotation = 0.0
	
	if "label_nick" in avatar and avatar.label_nick:
		avatar.label_nick.visible = false

func activar_combate():
	activa = true
	detenida = false
	if avatar_asignado and "prefijo_personaje" in avatar_asignado:
		avatar_asignado.sprite.play(avatar_asignado.prefijo_personaje + "_idle")

func set_velocidad_giro(nueva_vel: float):
	velocidad_giro = nueva_vel

func _process(delta):
	if activa and not detenida and not eliminada:
		montura.rotation += velocidad_giro * sentido_giro * delta
		
	# Mantener el sprite del personaje erguido mirando en la dirección del cañón
	if avatar_asignado:
		avatar_asignado.global_rotation = 0.0
		var sprite = avatar_asignado.get_node_or_null("Sprite")
		if sprite:
			var dir_x = cos(montura.global_rotation)
			sprite.flip_h = (dir_x < 0)

func puede_disparar() -> bool:
	return activa and not detenida and not eliminada and not en_cooldown

func disparar(angulo_forzado: float = -999.0):
	if eliminada: return
	
	if angulo_forzado != -999.0:
		montura.rotation = angulo_forzado
		
	detenida = true
	en_cooldown = true
	
	# Efecto visual de retroceso del cañón
	var tween_recoil = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_recoil.tween_property(canon_tubo, "position:x", pos_inicial_tubo.x - 12.0, 0.08)
	tween_recoil.tween_property(canon_tubo, "position:x", pos_inicial_tubo.x, 0.22)
	
	# Flash de disparo en la boca del cañón
	if flash_disparo:
		flash_disparo.visible = true
		flash_disparo.scale = Vector2(1.5, 1.5)
		var tween_flash = create_tween()
		tween_flash.tween_property(flash_disparo, "scale", Vector2.ZERO, 0.12)
		await tween_flash.finished
		flash_disparo.visible = false
		
	# Emitir señal de disparo para que el minijuego cree el proyectil
	emit_signal("proyectil_disparado", id_jugador, punto_disparo.global_position, montura.global_rotation)
	
	# Durante 0.85s la plataforma permanece totalmente detenida (cooldown táctico)
	await get_tree().create_timer(0.85).timeout
	
	en_cooldown = false
	if not eliminada:
		detenida = false

func recibir_impacto():
	if eliminada or en_invulnerabilidad: return
	
	vidas -= 1
	emit_signal("jugador_golpeado", id_jugador, vidas)
	
	if vidas <= 0:
		eliminar_plataforma()
	else:
		parpadear_invulnerabilidad()

func parpadear_invulnerabilidad():
	en_invulnerabilidad = true
	
	if avatar_asignado and "sprite" in avatar_asignado and "prefijo_personaje" in avatar_asignado:
		avatar_asignado.sprite.play(avatar_asignado.prefijo_personaje + "_impacto")
		
	# Efecto de parpadeo de daño
	var tween = create_tween().set_loops(4)
	tween.tween_property(self, "modulate:a", 0.3, 0.12)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	await tween.finished
	
	modulate.a = 1.0
	en_invulnerabilidad = false
	if avatar_asignado and "sprite" in avatar_asignado and "prefijo_personaje" in avatar_asignado and not eliminada:
		avatar_asignado.sprite.play(avatar_asignado.prefijo_personaje + "_idle")

func eliminar_plataforma():
	eliminada = true
	detenida = true
	activa = false
	vidas = 0
	
	# 1. Efecto y partículas de explosión de la plataforma
	if explosion_particulas:
		explosion_particulas.restart()
		explosion_particulas.emitting = true
		
	if flash_explosion:
		flash_explosion.visible = true
		flash_explosion.scale = Vector2(0.3, 0.3)
		flash_explosion.modulate.a = 1.0
		var tw_flash = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_flash.tween_property(flash_explosion, "scale", Vector2(2.8, 2.8), 0.18)
		tw_flash.parallel().tween_property(flash_explosion, "modulate:a", 0.0, 0.25)
		tw_flash.finished.connect(func(): if flash_explosion: flash_explosion.visible = false)
		
	# 2. El cañón se desmaya / cae levemente
	var tween_muerte = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween_muerte.tween_property(canon, "scale:y", 0.6, 0.4)
	
	# 3. Posterior a la explosión, activar el humo continuo de los restos destruidos
	get_tree().create_timer(0.2).timeout.connect(func():
		if humo_eliminado and eliminada:
			humo_eliminado.emitting = true
	)
	
	# 4. El personaje sale volando disparado dando vueltas y desciende en globo
	if avatar_asignado and is_instance_valid(avatar_asignado):
		if avatar_asignado.has_method("iniciar_secuencia_lanzamiento_globo"):
			avatar_asignado.iniciar_secuencia_lanzamiento_globo(global_position + Vector2(0, -20))
		elif avatar_asignado.has_method("activar_modo_globo"):
			avatar_asignado.activar_modo_globo(global_position + Vector2(0, -20))

func festejar_victoria():
	detenida = true
	if humo_eliminado:
		humo_eliminado.emitting = false
	if explosion_particulas:
		explosion_particulas.emitting = false
	if flash_explosion:
		flash_explosion.visible = false
	if avatar_asignado and "sprite" in avatar_asignado and "prefijo_personaje" in avatar_asignado:
		avatar_asignado.sprite.play(avatar_asignado.prefijo_personaje + "_acierto")
