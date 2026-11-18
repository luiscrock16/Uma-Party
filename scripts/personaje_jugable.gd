extends CharacterBody2D
class_name PersonajeJugable

@onready var sprite = $Sprite
@onready var label_nick = $LabelNick
@onready var puntero_jefe = $PunteroJefe
@onready var collision_shape = $CollisionShape2D

# --- ENUMS DE CONTROL ---
enum Estado { NORMAL, SPRINTANDO, ATURDIDO, SALTANDO, ELIMINADO, RESBALANDO }
enum TipoMovimiento { NORMAL_SOLO,
	CON_SPRINT,
	CINTA_SUPERVIVENCIA,
	LANZADOR_CURSOR,
	CORREDOR_MAQUINA, 
	JEFE_GARRA,
	TEMPLO_PINBALL,
	CAMINAR_Y_EMPUJAR,
	PATINAJE_INERCIA }
const NORMAL = TipoMovimiento.NORMAL_SOLO

const POSICION_FUERA_PANTALLA: Vector2 = Vector2(-5000, -5000)
const DURACION_SALTO = 0.6 # Tiempo total en segundos que dura el salto
var tiempo_salto_actual: float = 0.0
const ALTURA_MAXIMA_SPRITE = 65.0 # Qué tan arriba sube visualmente el sprite

# --- VARIABLES EXPORTABLES ---
@export var estado_actual: Estado = Estado.NORMAL
@export var set_movimiento_actual: TipoMovimiento = TipoMovimiento.CON_SPRINT
@export var fuerza_knockback: Vector2 = Vector2(0, 0)

# --- AJUSTES FÍSICOS GENERALES ---
@export var speed_normal: float = 350.0
@export var speed_sprint: float = 750.0
var modo_globo: bool = false
var modo_globo_autonomo: bool = false
var en_secuencia_lanzamiento_globo: bool = false
var pos_sincronizada_globo: Vector2 = Vector2.ZERO
var timer_envio_globo: float = 0.0
var centro_orbita_globo: Vector2 = Vector2(576, 320)
var radio_globo_x: float = 380.0
var radio_globo_y: float = 210.0
var angulo_globo: float = 0.0
var velocidad_orbita_globo: float = 0.35
var velocidad_globo: float = 260.0
var SPEED_NORMAL: float:
	get: return speed_normal
	set(v): speed_normal = v
var SPEED_SPRINT: float:
	get: return speed_sprint
	set(v): speed_sprint = v
const FUERZA_EMPUJE = 1100.0 
const DURACION_SPRINT = 0.4
const DURACION_ATURDIMIENTO = 1.5

# --- VARIABLES NUEVAS (Para Cinta y Lanzador) ---
const GRAVEDAD_CINTA = 1400.0
const FUERZA_SALTO_CINTA = -480.0
var vel_y_cinta = 0.0
var esta_en_zona_eliminacion: bool = false
var esta_atrapado: bool = false
var posicion_cursor = Vector2(800, 324) 
const VELOCIDAD_CURSOR = 600.0

var prefijo_personaje = "" 
var sprint_disponible = true
var fuerza_externa_plataforma = Vector2.ZERO 
var esta_usando_garra: bool = false
var direccion_mirando: Vector2 = Vector2.RIGHT
var tiempo_cooldown_empuje: float = 0.0
var controles_bloqueados: bool = false

var en_caida_libre: bool = false
var esta_aturdido: bool = false
var destino_y_caida: float = 0.0

const VELOCIDAD_CAIDA: float = 650.0
const VELOCIDAD_ROTACION_CAIDA: float = 12.0 # Velocidad del giro al caer

func establecer_atrapado_servidor(valor: bool):
	esta_atrapado = valor
	if multiplayer.is_server():
		rpc("sincronizar_atrapado_cliente", valor)
		

func _process(delta):
	# Giro constante del AnimatedSprite2D ÚNICAMENTE durante la caída libre
	if en_caida_libre and sprite:
		sprite.rotation += VELOCIDAD_ROTACION_CAIDA * delta


var timer_envio_pos_red: float = 0.0
var posicion_interpolada_remota: Vector2 = Vector2.ZERO

func _ready():
	set_multiplayer_authority(name.to_int())
	# Desactivar MultiplayerSynchronizer que interfiere en Web y bloquea clientes no-servidor
	var sync = get_node_or_null("MultiplayerSynchronizer")
	if sync:
		sync.process_mode = Node.PROCESS_MODE_DISABLED
	if puntero_jefe:
		puntero_jefe.visible = false

@rpc("any_peer", "call_remote", "unreliable")
func sincronizar_pos_remota_rpc(p_pos: Vector2, p_vel: Vector2, p_anim: String, p_flip: bool, p_estado: int):
	posicion_interpolada_remota = p_pos
	velocity = p_vel
	estado_actual = p_estado as Estado
	if sprite:
		sprite.flip_h = p_flip
		if p_anim != "" and sprite.sprite_frames and sprite.sprite_frames.has_animation(p_anim):
			if sprite.animation != p_anim:
				sprite.play(p_anim)

func configurar_visual(tipo_idx, nickname):
	var datos = {
		0: "SEIK", 1: "GLSH", 2: "OGRC", 3: "STIL", 4: "MACA",
		5: "AGTC", 6: "DAFL", 7: "JUPC", 8: "SABG", 9: "SPWE"
	}
	prefijo_personaje = datos.get(tipo_idx, "SEIK")
	if not label_nick:
		label_nick = get_node_or_null("LabelNick")
	if not sprite:
		sprite = get_node_or_null("Sprite")
	if label_nick:
		label_nick.text = nickname
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(prefijo_personaje + "_idle"):
		sprite.play(prefijo_personaje + "_idle")

func bloquear_controles(bloquear: bool):
	controles_bloqueados = bloquear
	if bloquear:
		velocity = Vector2.ZERO

func reproducir_intro():
	if sprite and prefijo_personaje != "":
		var anim_intro = prefijo_personaje + "_intro"
		if sprite.sprite_frames.has_animation(anim_intro):
			sprite.play(anim_intro)

func reproducir_idle():
	if modo_globo:
		return
	if sprite and prefijo_personaje != "":
		sprite.play(prefijo_personaje + "_idle")

@rpc("any_peer", "call_local", "reliable")
func sincronizar_atrapado_rpc(atrapado: bool):
	esta_atrapado = atrapado
	velocity = Vector2.ZERO
	
	if atrapado:
		set_physics_process(false)
		# DESACTIVAR COLISIÓN para que la física no empuje al nodo raíz
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
	else:
		set_physics_process(true)
		
	actualizar_visuales()

func _physics_process(delta):
	# Modo espectador con globo morado tras ser eliminado (órbita autónoma como la directora)
	if modo_globo:
		if modo_globo_autonomo:
			angulo_globo += velocidad_orbita_globo * delta
			var px = centro_orbita_globo.x + cos(angulo_globo) * radio_globo_x
			var py = centro_orbita_globo.y + sin(angulo_globo) * radio_globo_y
			
			if is_multiplayer_authority():
				global_position = Vector2(px, py)
				if multiplayer.has_multiplayer_peer():
					timer_envio_globo += delta
					if timer_envio_globo >= 0.05:
						timer_envio_globo = 0.0
						rpc("sincronizar_globo_pos_rpc", global_position, (velocidad_orbita_globo * -sin(angulo_globo) < 0))
			else:
				if pos_sincronizada_globo != Vector2.ZERO:
					global_position = global_position.lerp(pos_sincronizada_globo, 12.0 * delta)
				else:
					global_position = Vector2(px, py)
					
			if sprite:
				sprite.flip_h = (velocidad_orbita_globo * -sin(angulo_globo) < 0)
				sprite.position.y = sin(Time.get_ticks_msec() / 200.0) * 5.0
				
		# Asegurar que el sprite del globo morado se mantenga siempre activo
		if not en_secuencia_lanzamiento_globo and sprite and prefijo_personaje != "":
			var anim_globo = prefijo_personaje + "_globo"
			if sprite.sprite_frames.has_animation(anim_globo) and sprite.animation != anim_globo:
				sprite.play(anim_globo)
		return

	actualizar_visuales()
	
	# Si está atrapado, anulamos cualquier movimiento propio para que la garra tenga control total
	if esta_atrapado:
		velocity = Vector2.ZERO
		return

	# Si los controles están bloqueados durante la cuenta atrás
	if controles_bloqueados:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if en_caida_libre:
		global_position.y += VELOCIDAD_CAIDA * delta
		if multiplayer.is_server():
			if global_position.y >= destino_y_caida:
				global_position.y = destino_y_caida
				en_caida_libre = false
				rpc("aterrizar_jugador_rpc")
		return

	# Si al jugador le toca ser el jefe de la garra, bloqueamos el movimiento de su cuerpo
	if esta_usando_garra:
		velocity = Vector2.ZERO # El personaje se queda quieto en el Marker2D
		move_and_slide()
		return

	if not is_multiplayer_authority():
		if posicion_interpolada_remota != Vector2.ZERO:
			global_position = global_position.lerp(posicion_interpolada_remota, 25.0 * delta)
		move_and_slide()
		return

	fuerza_knockback = fuerza_knockback.move_toward(Vector2.ZERO, 1500.0 * delta)

	if estado_actual == Estado.ATURDIDO:
		velocity = fuerza_knockback
	else:
		manejar_movimiento_por_set(delta)
		if set_movimiento_actual != TipoMovimiento.LANZADOR_CURSOR:
			velocity += fuerza_knockback + fuerza_externa_plataforma

	move_and_slide()
	fuerza_externa_plataforma = Vector2.ZERO
	actualizar_visuales()

	# Transmisión de posición continua hacia el Servidor y demás clientes
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		timer_envio_pos_red += delta
		if timer_envio_pos_red >= 0.033:
			timer_envio_pos_red = 0.0
			var anim_actual = sprite.animation if sprite else ""
			var flip_actual = sprite.flip_h if sprite else false
			sincronizar_pos_remota_rpc.rpc(global_position, velocity, anim_actual, flip_actual, int(estado_actual))

@rpc("any_peer", "call_local", "reliable")
func iniciar_caida_libre_rpc(pos_y_destino: float):
	print("[JUGADOR ", name, "] 1. Inicia caída libre. Reactivando colisión...")
	esta_atrapado = false
	en_caida_libre = true
	destino_y_caida = pos_y_destino
	
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
		print("[JUGADOR ", name, "] CollisionShape2D reactivado correctamente.")
	else:
		print("❌ ERROR: collision_shape es null en el jugador.")

# Simplificamos aterrizar_jugador_rpc (ya no necesita evaluar overlap manualmente)
@rpc("any_peer", "call_local", "reliable")
func aterrizar_jugador_rpc():
	en_caida_libre = false
	set_physics_process(true)
	
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
		
	if sprite:
		sprite.rotation = 0.0
	
	# SOLO AL TERMINAR LA CAÍDA EVALUAMOS SI ATERRIZÓ EN LA ZONA DE ELIMINACIÓN
	if esta_en_zona_eliminacion:
		ejecutar_eliminacion_rpc()
	else:
		# Piso normal: aturdimiento de 2 segundos
		if estado_actual != Estado.ELIMINADO:
			aplicar_aturdimiento(2.0)


@rpc("any_peer", "call_local", "reliable")
func ejecutar_eliminacion_rpc():
	estado_actual = Estado.ELIMINADO
	velocity = Vector2.ZERO
	en_caida_libre = false
	esta_en_zona_eliminacion = false
	
	set_physics_process(false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		
	# Mover fuera de pantalla al completar la caída
	global_position = POSICION_FUERA_PANTALLA
	
	var mapa = get_tree().root.get_node_or_null("MapaActual")
	if mapa and mapa.has_method("registrar_jugador_atrapado"):
		mapa.registrar_jugador_atrapado(name.to_int())

func aplicar_aturdimiento(duracion: float):
	estado_actual = Estado.ATURDIDO
	await get_tree().create_timer(duracion).timeout
	if estado_actual == Estado.ATURDIDO:
		estado_actual = Estado.NORMAL

@rpc("any_peer", "call_local", "reliable")
func aplicar_resbalon_rpc(duracion: float = 1.4):
	aplicar_resbalon(duracion)

func aplicar_resbalon(duracion: float = 1.4):
	if estado_actual == Estado.ELIMINADO or modo_globo:
		return
	estado_actual = Estado.RESBALANDO
	if sprite:
		var anim = prefijo_personaje + "_resbalar"
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
	await get_tree().create_timer(duracion).timeout
	if estado_actual == Estado.RESBALANDO:
		estado_actual = Estado.NORMAL
		if sprite:
			sprite.play(prefijo_personaje + "_idle")

func ejecutar_accion_empuje():
	if sprite:
		var anim_ataque = prefijo_personaje + "_ataque"
		if sprite.sprite_frames.has_animation(anim_ataque):
			sprite.play(anim_ataque)
		else:
			var anim_imp = prefijo_personaje + "_impacto"
			if sprite.sprite_frames.has_animation(anim_imp):
				sprite.play(anim_imp)
				
	# Detectar jugador cercano en la dirección en la que está mirando
	var mejor_objetivo: CharacterBody2D = null
	var menor_dist = 95.0
	for otro in get_tree().get_nodes_in_group("Jugador"):
		if otro == self or otro.estado_actual == Estado.ELIMINADO:
			continue
		var vec = otro.global_position - global_position
		var dist = vec.length()
		if dist <= menor_dist:
			var dot = vec.normalized().dot(direccion_mirando)
			# Debe estar en el cono frontal o muy cerca
			if dot > 0.15 or dist < 45.0:
				menor_dist = dist
				mejor_objetivo = otro
				
	if mejor_objetivo:
		# Empujón de 2-3 plataformas de distancia (~165px)
		var dir_final = (mejor_objetivo.global_position - global_position).normalized()
		if dir_final == Vector2.ZERO: dir_final = direccion_mirando
		mejor_objetivo.rpc("recibir_empujon_rpc", dir_final, 165.0, 1.2)

@rpc("any_peer", "call_local", "reliable")
func recibir_empujon_rpc(dir_empuje: Vector2, distancia: float, duracion_aturdimiento: float):
	if estado_actual == Estado.ELIMINADO or modo_globo:
		return
	aplicar_aturdimiento(duracion_aturdimiento)
	if sprite:
		var anim_imp = prefijo_personaje + "_impacto"
		if sprite.sprite_frames.has_animation(anim_imp):
			sprite.play(anim_imp)
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var destino = global_position + dir_empuje.normalized() * distancia
	tw.tween_property(self, "global_position", destino, 0.32)

func manejar_movimiento_por_set(delta):
	var direction = Input.get_vector("a", "d", "w", "s")
	
	if estado_actual == Estado.RESBALANDO:
		# Pérdida de control del personaje: se mueve mucho más lento (~25% de velocidad)
		velocity = direction * (SPEED_NORMAL * 0.25)
		return
	
	match set_movimiento_actual:
		TipoMovimiento.NORMAL_SOLO:
			velocity = direction * SPEED_NORMAL
			
		TipoMovimiento.CON_SPRINT:
			if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("espacio")) and sprint_disponible and direction != Vector2.ZERO:
				activar_sprint_rpc.rpc(direction)
			var vel_base = SPEED_SPRINT if estado_actual == Estado.SPRINTANDO else SPEED_NORMAL
			velocity = direction * vel_base
			
		TipoMovimiento.CINTA_SUPERVIVENCIA:
			var input_x = Input.get_axis("a", "d")
			var input_y = Input.get_axis("w", "s")
			
			# Movimiento 2D totalmente libre por los carriles en X e Y
			velocity.x = input_x * SPEED_NORMAL
			velocity.y = input_y * (SPEED_NORMAL * 0.7)
			
			# LÓGICA DEL SALTO PARABÓLICO CONTROLADO
			if estado_actual == Estado.NORMAL:
				if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("espacio"):
					estado_actual = Estado.SALTANDO
					tiempo_salto_actual = 0.0
			
			if estado_actual == Estado.SALTANDO:
				tiempo_salto_actual += delta
				
				# Calculamos una parábola basada en el tiempo transcurrido (0.0 a 1.0)
				var progreso = tiempo_salto_actual / DURACION_SALTO
				
				if progreso >= 1.0:
					# El salto terminó, regresamos al estado normal
					estado_actual = Estado.NORMAL
					sprite.position.y = 0
				else:
					# Ecuación de parábola simple: 4 * x * (1 - x) da una curva perfecta de 0 a 1 y vuelve a 0
					var formula_parabola = 4.0 * progreso * (1.0 - progreso)
					sprite.position.y = -formula_parabola * ALTURA_MAXIMA_SPRITE
			
			# El Sprint lateral solo se permite si está en estado NORMAL
			if estado_actual == Estado.NORMAL and (Input.is_action_just_pressed("ui_select") or Input.is_action_just_pressed("espacio")) and sprint_disponible and input_x != 0:
				activar_sprint_rpc.rpc(Vector2(input_x, 0))

		TipoMovimiento.TEMPLO_PINBALL:
			var input_x = Input.get_axis("a", "d")
			var input_y = Input.get_axis("w", "s")
			
			velocity.x = input_x * SPEED_NORMAL
			velocity.y = input_y * (SPEED_NORMAL * 0.4)
			
			# Salto para sobrepasar a otros jugadores en el espacio reducido
			if estado_actual == Estado.NORMAL:
				if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("espacio"):
					if multiplayer.has_multiplayer_peer():
						activar_salto_templo_rpc.rpc()
					else:
						iniciar_salto_templo()
			
			if estado_actual == Estado.SALTANDO:
				tiempo_salto_actual += delta
				var progreso = tiempo_salto_actual / DURACION_SALTO
				if progreso >= 1.0:
					if multiplayer.has_multiplayer_peer():
						finalizar_salto_templo_rpc.rpc()
					else:
						aterrizar_salto_templo()
				else:
					var formula_parabola = 4.0 * progreso * (1.0 - progreso)
					sprite.position.y = -formula_parabola * (ALTURA_MAXIMA_SPRITE + 20.0)

		TipoMovimiento.LANZADOR_CURSOR:
			velocity = Vector2.ZERO
			
			# Activamos y hacemos visible el puntero ÚNICAMENTE para el jugador dueño de este jefe
			if is_multiplayer_authority() and puntero_jefe:
				puntero_jefe.visible = true
				# Hacemos que el puntero se dibuje de forma independiente en la pantalla
				puntero_jefe.top_level = true 
			
			# Control del cursor virtual con las teclas WASD / Flechas
			var dir_cursor = Input.get_vector("a", "d", "w", "s")
			posicion_cursor += dir_cursor * VELOCIDAD_CURSOR * delta
			
			# Limitamos el movimiento del cursor en pantalla
			posicion_cursor.x = clamp(posicion_cursor.x, 50, 1100)
			posicion_cursor.y = clamp(posicion_cursor.y, 100, 550) # Mismo rango Y de la cinta
			
			# ACTUALIZACIÓN DE LA GUÍA VISUAL:
			# Queremos que la X se quede fija a la derecha (donde spawnean los bloques, ej: 1050)
			# y que la Y siga subiendo y bajando con nuestro cursor en tiempo real.
			if puntero_jefe and is_multiplayer_authority():
				puntero_jefe.global_position = Vector2(1050.0, posicion_cursor.y)
			
			if Engine.get_process_frames() % 2 == 0:
				sincronizar_cursor_rpc.rpc(posicion_cursor)
			
			if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("espacio"):
				if multiplayer.is_server():
					soltar_bloque_solicitud(posicion_cursor)
				else:
					soltar_bloque_solicitud.rpc(posicion_cursor)
		TipoMovimiento.JEFE_GARRA:
			# El avatar del jefe permanece inmóvil; los controles de la garra los procesa la escena del minijuego
			velocity = Vector2.ZERO

		TipoMovimiento.CORREDOR_MAQUINA:
			# Movimiento base por el suelo para los 3 supervivientes (move_and_slide se llama al final)
			var input_dir = Input.get_vector("a", "d", "w", "s")
			velocity = input_dir * SPEED_NORMAL

		TipoMovimiento.CAMINAR_Y_EMPUJAR:
			if estado_actual == Estado.NORMAL:
				velocity = direction * (SPEED_NORMAL * 0.75) # Caminar a ritmo controlado (~260px/s)
				if direction != Vector2.ZERO:
					direccion_mirando = direction.normalized()
			elif estado_actual in [Estado.ATURDIDO, Estado.ELIMINADO, Estado.RESBALANDO]:
				velocity = Vector2.ZERO
				
			if tiempo_cooldown_empuje > 0.0:
				tiempo_cooldown_empuje -= delta
				
			# Acción de empuje con la tecla de acción (ui_accept / Espacio / Enter)
			if estado_actual == Estado.NORMAL and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("espacio")) and tiempo_cooldown_empuje <= 0.0:
				tiempo_cooldown_empuje = 0.75
				ejecutar_accion_empuje()

		TipoMovimiento.PATINAJE_INERCIA:
			# Movimiento con inercia estilo carritos chocones / patinaje sobre hielo
			var dir_input = Input.get_vector("a", "d", "w", "s")
			var aceleracion = 750.0
			var friccion = 230.0
			var vel_max = 330.0
			
			if estado_actual == Estado.NORMAL:
				if dir_input != Vector2.ZERO:
					velocity = velocity.move_toward(dir_input * vel_max, aceleracion * delta)
					direccion_mirando = dir_input.normalized()
				else:
					velocity = velocity.move_toward(Vector2.ZERO, friccion * delta)
			elif estado_actual in [Estado.ATURDIDO, Estado.RESBALANDO]:
				velocity = velocity.move_toward(Vector2.ZERO, (friccion * 0.7) * delta)

@rpc("any_peer", "call_local", "reliable")
func activar_sprint_rpc(_dir):
	estado_actual = Estado.SPRINTANDO
	sprint_disponible = false
	await get_tree().create_timer(DURACION_SPRINT).timeout
	if estado_actual == Estado.SPRINTANDO: estado_actual = Estado.NORMAL
	await get_tree().create_timer(2.0).timeout
	sprint_disponible = true

@rpc("any_peer", "call_local", "reliable")
func recibir_golpe_externo_rpc(vector_fuerza):
	if set_movimiento_actual == TipoMovimiento.CINTA_SUPERVIVENCIA:
		fuerza_knockback = Vector2(vector_fuerza.x * 0.6, 0)
		estado_actual = Estado.ATURDIDO
		sprite.play(prefijo_personaje + "_impacto")
		
		await get_tree().create_timer(0.6).timeout 
		estado_actual = Estado.NORMAL
	else:
		fuerza_knockback = vector_fuerza
		estado_actual = Estado.ATURDIDO
		sprite.play(prefijo_personaje + "_impacto")
		
		await get_tree().create_timer(DURACION_ATURDIMIENTO).timeout
		estado_actual = Estado.NORMAL

func actualizar_visuales():
	if modo_globo:
		var anim_globo = prefijo_personaje + "_globo"
		if sprite and sprite.sprite_frames.has_animation(anim_globo):
			if sprite.animation != anim_globo:
				sprite.play(anim_globo)
		return

	# 1. Prioridad Garra / Caída Libre
	if esta_atrapado or en_caida_libre:
		# Centramos la orientación horizontal para evitar desviaciones por textura invertida
		if sprite:
			sprite.flip_h = false
			
		var anim_atrapado = prefijo_personaje + "_atrapado"
		if sprite.sprite_frames.has_animation(anim_atrapado):
			if sprite.animation != anim_atrapado:
				sprite.play(anim_atrapado)
		return

	# Si ya no está cayendo ni atrapado, aseguramos que la rotación vuelva a 0
	if sprite.rotation != 0.0:
		sprite.rotation = 0.0

	# 2. Prioridad Aturdido / Impactado
	if estado_actual == Estado.ATURDIDO:
		var anim_impacto = prefijo_personaje + "_impacto"
		var anim_aturdido = prefijo_personaje + "_aturdido"
		# Mientras la inercia del golpe lo empuja con fuerza, animación de impacto
		if fuerza_knockback.length() > 60.0 and sprite.sprite_frames.has_animation(anim_impacto):
			if sprite.animation != anim_impacto:
				sprite.play(anim_impacto)
		elif sprite.sprite_frames.has_animation(anim_aturdido):
			if sprite.animation != anim_aturdido:
				sprite.play(anim_aturdido)
		return

	# 2.5 Prioridad Resbalando / Descontrol con giro de viento
	if estado_actual == Estado.RESBALANDO:
		var anim_resbalar = prefijo_personaje + "_resbalar"
		if sprite and sprite.sprite_frames.has_animation(anim_resbalar):
			if sprite.animation != anim_resbalar:
				sprite.play(anim_resbalar)
		return

	# DETERMINAR SI EL DUEÑO DE ESTE PERSONAJE ESTÁ PRESIONANDO TECLAS
	# (Si esta pantalla no es el dueño del personaje, no leemos Input)
	var input_x = 0.0
	var input_y = 0.0
	if is_multiplayer_authority():
		input_x = Input.get_axis("a", "d")
		input_y = Input.get_axis("w", "s")

	# 3. Prioridad de Minijuego: Si está saltando en la cinta
	if estado_actual == Estado.SALTANDO:
		var anim_salto = prefijo_personaje + "_saltar"
		sprite.speed_scale = 1.0
		if is_multiplayer_authority() and input_x != 0: 
			sprite.flip_h = input_x < 0
		if sprite.animation != anim_salto: 
			sprite.play(anim_salto)
		return

	# 4. Restricción de Rol: Lanzador
	if set_movimiento_actual == TipoMovimiento.LANZADOR_CURSOR:
		sprite.play(prefijo_personaje + "_idle")
		sprite.flip_h = true
		return

	# 5. Movimiento Terrestre Normal (Caminar / Correr / Idle)
	# Para clientes remotos o patinaje con inercia, decidimos si camina/corre evaluando 'velocity' en lugar de 'Input'
	var se_esta_moviendo = false
	if set_movimiento_actual == TipoMovimiento.PATINAJE_INERCIA:
		se_esta_moviendo = velocity.length() > 25.0
	elif is_multiplayer_authority():
		se_esta_moviendo = (input_x != 0 or input_y != 0)
	else:
		se_esta_moviendo = velocity.length() > 10.0

	var anim = prefijo_personaje + "_idle"

	if estado_actual == Estado.SPRINTANDO:
		anim = prefijo_personaje + "_correr"
		sprite.speed_scale = 2.0
	elif se_esta_moviendo:
		anim = prefijo_personaje + "_caminar"
		sprite.speed_scale = 1.0
	else:
		sprite.speed_scale = 1.0

	# Giro horizontal
	if set_movimiento_actual == TipoMovimiento.PATINAJE_INERCIA and abs(velocity.x) > 15.0:
		sprite.flip_h = -velocity.x < 0
	elif is_multiplayer_authority() and input_x != 0:
		sprite.flip_h = -input_x < 0
	elif not is_multiplayer_authority() and abs(velocity.x) > 10.0:
		sprite.flip_h = velocity.x < 0

	if sprite.animation != anim: 
		sprite.play(anim)

# --- CONTROL DE SALTO PARA TEMPLO PINBALL ---
func iniciar_salto_templo():
	if estado_actual == Estado.SALTANDO or estado_actual == Estado.ELIMINADO: return
	estado_actual = Estado.SALTANDO
	tiempo_salto_actual = 0.0
	# Desactivar colisión con otros jugadores en el suelo (capa 2 y máscara 2)
	# La capa 3 (daño/impacto de bolas) permanece activa para que las bolas sigan impactando
	set_collision_layer_value(2, false)
	set_collision_mask_value(2, false)

func aterrizar_salto_templo():
	estado_actual = Estado.NORMAL
	sprite.position.y = 0
	# Reactivar colisión con otros jugadores al tocar suelo
	set_collision_layer_value(2, true)
	set_collision_mask_value(2, true)

@rpc("any_peer", "call_local", "reliable")
func activar_salto_templo_rpc():
	iniciar_salto_templo()

@rpc("any_peer", "call_local", "reliable")
func finalizar_salto_templo_rpc():
	aterrizar_salto_templo()

# --- DETECCIÓN DE CHOQUES ENTRE CORREDORES ---
func _on_hurtbox_body_entered(body: Node2D) -> void:
	if is_multiplayer_authority() and estado_actual == Estado.SPRINTANDO:
		if body is CharacterBody2D and body != self:
			var direccion = global_position.direction_to(body.global_position)
			
			if set_movimiento_actual == TipoMovimiento.CINTA_SUPERVIVENCIA:
				var dir_lateral = Vector2(sign(direccion.x), 0)
				if dir_lateral.x == 0:
					dir_lateral.x = -1 if sprite.flip_h else 1
				body.recibir_golpe_externo_rpc.rpc(dir_lateral * FUERZA_EMPUJE)
			else:
				body.recibir_golpe_externo_rpc.rpc(direccion * FUERZA_EMPUJE)
			
			estado_actual = Estado.NORMAL
			fuerza_knockback = Vector2.ZERO

# --- RPCs AUXILIARES PARA EL LANZADOR ---
@rpc("any_peer", "call_remote", "unreliable")
func sincronizar_cursor_rpc(_pos):
	pass

@rpc("any_peer", "call_local", "reliable")
func soltar_bloque_solicitud(_pos_cursor):
	if true:
		var mapa_actual = get_tree().root.get_node_or_null("MapaActual")
		if mapa_actual and mapa_actual.has_method("registrar_solicitud_bloque"):
			mapa_actual.registrar_solicitud_bloque(_pos_cursor)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_atrapado_cliente(atrapado: bool):
	esta_atrapado = atrapado
	if atrapado:
		# APAGAR FÍSICAS MIENTRAS ESTÁ ATRAPADO
		# Si usas CharacterBody2D, esto evita que la gravedad o las colisiones locales luchen
		process_mode = PROCESS_MODE_DISABLED 
	else:
		# REACTIVAR FÍSICAS AL SOLTARLO
		process_mode = PROCESS_MODE_INHERIT

# --- MODO GLOBO ESPECTADOR TRAS SER ELIMINADO ---
@rpc("any_peer", "call_local", "reliable")
func activar_modo_globo_rpc(pos_inicio: Vector2):
	iniciar_secuencia_lanzamiento_globo(pos_inicio)

func activar_modo_globo(pos_inicio: Vector2 = Vector2.ZERO):
	iniciar_secuencia_lanzamiento_globo(pos_inicio)

func iniciar_secuencia_lanzamiento_globo(pos_inicio: Vector2 = Vector2.ZERO):
	modo_globo = true
	modo_globo_autonomo = false
	en_secuencia_lanzamiento_globo = true
	estado_actual = Estado.ELIMINADO
	set_physics_process(true)
	velocity = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	z_index = 30
	
	# Reparentar a la escena del minijuego (MapaActual o nodo de mapa contenedor)
	var destino_padre = null
	if get_tree() and get_tree().root:
		destino_padre = get_tree().root.get_node_or_null("MapaActual")
	if not destino_padre:
		var p = get_parent()
		var script_base = load("res://scripts/BaseMinijuego.gd")
		while p and not (p.has_method("preparar_partida") or (script_base and p.get_script() == script_base)):
			p = p.get_parent()
		destino_padre = p
	if not destino_padre and get_tree():
		destino_padre = get_tree().current_scene
		
	if destino_padre and get_parent() != destino_padre:
		var p_glob = pos_inicio if pos_inicio != Vector2.ZERO else global_position
		get_parent().remove_child(self)
		destino_padre.add_child(self)
		global_position = p_glob
	elif pos_inicio != Vector2.ZERO:
		global_position = pos_inicio
		
	# Desactivar colisiones físicas para no interferir con proyectiles ni plataformas
	collision_layer = 0
	collision_mask = 0
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if label_nick:
		label_nick.visible = false
		
	# 1. Animación de impacto mientras es lanzado
	if sprite and prefijo_personaje != "":
		var anim_imp = prefijo_personaje + "_impacto"
		if sprite.sprite_frames.has_animation(anim_imp):
			sprite.play(anim_imp)
			
	var pos_lanzamiento_y = -190.0 # Completamente fuera de pantalla por arriba
	var dir_x = sign(global_position.x - 576.0)
	if dir_x == 0.0: dir_x = 1.0
	var pos_lanzamiento_x = clamp(global_position.x + (dir_x * 40.0), 120.0, 1032.0)
	var pos_descenso = Vector2(clamp(pos_lanzamiento_x, 150.0, 1002.0), 210.0)
	
	# 2. Impulso vertical dando vueltas (rotación visible, 1.1s de vuelo notorio)
	var vueltas = (PI * 4.0) * dir_x
	var tween_lanzamiento = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_lanzamiento.tween_property(self, "global_position:y", pos_lanzamiento_y, 1.1)
	tween_lanzamiento.tween_property(self, "global_position:x", pos_lanzamiento_x, 1.1)
	tween_lanzamiento.tween_property(self, "rotation", vueltas, 1.1)
	await tween_lanzamiento.finished
	
	# 3. Fuera de pantalla: resetear rotación y cambiar al sprite del globo morado
	rotation = 0.0
	if sprite and prefijo_personaje != "":
		var anim_globo = prefijo_personaje + "_globo"
		if sprite.sprite_frames.has_animation(anim_globo):
			sprite.play(anim_globo)
			
	await get_tree().create_timer(0.2).timeout
	
	# 4. Caída / descenso lento flotando de regreso a la arena visible (2.2s)
	var tween_descenso = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_descenso.tween_property(self, "global_position", pos_descenso, 2.2)
	await tween_descenso.finished
	
	# 5. Ya visible en el mapa: asegurar animación de globo e iniciar órbita autónoma (como la directora)
	en_secuencia_lanzamiento_globo = false
	if sprite and prefijo_personaje != "":
		var anim_globo = prefijo_personaje + "_globo"
		if sprite.sprite_frames.has_animation(anim_globo):
			sprite.play(anim_globo)
			
	iniciar_orbita_autonoma()

func iniciar_orbita_autonoma():
	modo_globo_autonomo = true
	var mi_id = name.to_int()
	if mi_id == 0:
		mi_id = int(str(get_instance_id()))
		
	centro_orbita_globo = Vector2(576, 320)
	angulo_globo = (global_position - centro_orbita_globo).angle()
	radio_globo_x = 360.0 + ((mi_id % 3) * 45.0)
	radio_globo_y = 205.0 + ((mi_id % 3) * 30.0)
	velocidad_orbita_globo = 0.36 if (mi_id % 2 == 0) else -0.36

@rpc("any_peer", "call_remote", "unreliable")
func sincronizar_globo_pos_rpc(pos: Vector2, mirando_izq: bool):
	pos_sincronizada_globo = pos
	if sprite:
		sprite.flip_h = mirando_izq

func desactivar_modo_globo():
	modo_globo = false
	modo_globo_autonomo = false
	en_secuencia_lanzamiento_globo = false
	pos_sincronizada_globo = Vector2.ZERO
	rotation = 0.0
	if sprite:
		sprite.position = Vector2.ZERO
		sprite.rotation = 0.0
		if prefijo_personaje != "":
			sprite.play(prefijo_personaje + "_idle")
