extends Node2D
class_name DirectoraCanonPista

signal disparo_efectuado(pos_origen: Vector2, dir_disparo: Vector2, vel: float)

@onready var sprite_tanque = $SpriteTanque
@onready var sprite_directora = $SpriteDirectora
@onready var mira_laser = $MiraLaser
@onready var punto_canon = $PuntoCanon
@onready var flash_disparo = $FlashDisparo
@onready var humo_disparo = $HumoDisparo
@onready var sombra = $Sombra

var tex_tanque = {
	"c": null,
	"l": null,
	"r": null
}

var frames_directora_conducir = []
var frames_directora_disparar = []

var direccion_actual: String = "c"
var ocupada: bool = false

func _ready():
	cargar_recursos()
	if mira_laser:
		mira_laser.visible = false
	if flash_disparo:
		flash_disparo.visible = false
	if humo_disparo:
		humo_disparo.emitting = false

func cargar_recursos():
	var dir_base = "res://assets/Sprites/NPCS/Yayoi Akikawa/"
	
	# Texturas del tanque en 3 ángulos
	var r_c = dir_base + "tanque_canon_c.png"
	var r_l = dir_base + "tanque_canon_l.png"
	var r_r = dir_base + "tanque_canon_r.png"
	if ResourceLoader.exists(r_c): tex_tanque["c"] = load(r_c)
	if ResourceLoader.exists(r_l): tex_tanque["l"] = load(r_l)
	if ResourceLoader.exists(r_r): tex_tanque["r"] = load(r_r)
	
	# Frames de la Directora Akikawa conduciendo (akyy_ST01)
	for i in range(4):
		var ruta = dir_base + ("akyy_ST01_0%d.png" % i)
		if ResourceLoader.exists(ruta):
			frames_directora_conducir.append(load(ruta))
			
	# Frames de la Directora disparando / apuntando (akyy_ST03)
	for i in range(3):
		var ruta = dir_base + ("akyy_ST03_0%d.png" % i)
		if ResourceLoader.exists(ruta):
			frames_directora_disparar.append(load(ruta))

func aparecer_y_disparar(pos_spawn: Vector2, objetivo_jugador: Node2D, vel_balon: float = 650.0):
	if ocupada: return
	ocupada = true
	
	global_position = pos_spawn
	visible = true
	modulate = Color.WHITE
	
	# Determinar orientación según la posición en la pista respecto al objetivo
	var dir_al_objetivo = (objetivo_jugador.global_position - global_position).normalized() if is_instance_valid(objetivo_jugador) else Vector2.DOWN
	if dir_al_objetivo.x < -0.32:
		direccion_actual = "l"
		if punto_canon: punto_canon.position = Vector2(-16, 26)
	elif dir_al_objetivo.x > 0.32:
		direccion_actual = "r"
		if punto_canon: punto_canon.position = Vector2(16, 26)
	else:
		direccion_actual = "c"
		if punto_canon: punto_canon.position = Vector2(0, 26)
		
	# Aplicar sprite de tanque según ángulo
	if sprite_tanque and tex_tanque[direccion_actual]:
		sprite_tanque.texture = tex_tanque[direccion_actual]
		
	if sprite_directora:
		sprite_directora.flip_h = (direccion_actual == "r")
		if frames_directora_conducir.size() > 0:
			sprite_directora.texture = frames_directora_conducir[0]
		
	# 1. Animación de entrada conduciendo su máquina al borde de la cancha
	scale = Vector2(0.2, 0.2)
	var tw_in = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(self, "scale", Vector2.ONE, 0.3)
	await tw_in.finished
	
	# Ciclo de motor / preparación (conduciendo la máquina)
	for i in range(4):
		if sprite_directora and frames_directora_conducir.size() > 0:
			sprite_directora.texture = frames_directora_conducir[i % frames_directora_conducir.size()]
			sprite_directora.position.y = -16.0 + (1.0 if (i % 2 == 1) else 0.0) # Vibración de motor
		await get_tree().create_timer(0.08).timeout
		
	# 2. Apuntar con mira láser al jugador objetivo (Aviso táctico claro)
	if mira_laser and is_instance_valid(objetivo_jugador):
		mira_laser.visible = true
		mira_laser.width = 1.5
		mira_laser.modulate.a = 0.4
		
		# Mantener la mira apuntada al objetivo durante 0.5s mientras se ilumina
		var tiempo_mira = 0.5
		var t = 0.0
		while t < tiempo_mira and is_instance_valid(objetivo_jugador):
			var pos_local_canon = punto_canon.position
			var pos_local_target = to_local(objetivo_jugador.global_position)
			mira_laser.points = PackedVector2Array([pos_local_canon, pos_local_target])
			mira_laser.width = 1.5 + (t / tiempo_mira) * 3.0
			mira_laser.modulate.a = 0.4 + (t / tiempo_mira) * 0.55
			await get_tree().process_frame
			t += get_process_delta_time()
			
		mira_laser.visible = false

	# 3. Disparo del cañón: pose de orden/disparo de la Directora
	if sprite_directora and frames_directora_disparar.size() > 0:
		sprite_directora.texture = frames_directora_disparar[0]
		
	if flash_disparo:
		flash_disparo.position = punto_canon.position
		flash_disparo.visible = true
		flash_disparo.scale = Vector2(1.5, 1.5)
		create_tween().tween_property(flash_disparo, "scale", Vector2.ZERO, 0.12).finished.connect(func(): flash_disparo.visible = false)
	if humo_disparo:
		humo_disparo.position = punto_canon.position
		humo_disparo.restart()
		humo_disparo.emitting = true
		
	# Calcular vector exacto de disparo
	var pos_disparo = punto_canon.global_position
	var dir_disparo = Vector2.DOWN
	if is_instance_valid(objetivo_jugador):
		dir_disparo = (objetivo_jugador.global_position - pos_disparo).normalized()
	elif direccion_actual == "l":
		dir_disparo = Vector2(-0.7, 0.7).normalized()
	elif direccion_actual == "r":
		dir_disparo = Vector2(0.7, 0.7).normalized()
		
	# Retroceso del tanque por el disparo
	var pos_original = global_position
	var tw_kick = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_kick.tween_property(self, "global_position", pos_original - dir_disparo * 14.0, 0.08)
	tw_kick.tween_property(self, "global_position", pos_original, 0.15)
	
	# Emitir señal para que la escena instancie el balón de cañón pesado
	disparo_efectuado.emit(pos_disparo, dir_disparo, vel_balon)
	
	# Pausa de celebración / risa triunfal (akyy_ST03_01)
	if sprite_directora and frames_directora_disparar.size() > 1:
		sprite_directora.texture = frames_directora_disparar[1]
	await get_tree().create_timer(0.4).timeout
	
	# 4. Desaparición / retirada rápida en su tanque
	var tw_out = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw_out.tween_property(self, "scale", Vector2.ZERO, 0.28)
	await tw_out.finished
	
	visible = false
	ocupada = false

# --- ANUNCIO VISUAL DE CAMBIO DE FASE (SIN HUD FIJO) ---

func anunciar_fase(fase: int):
	ocupada = true
	visible = true
	modulate = Color.WHITE
	
	global_position = Vector2(576, 175)
	direccion_actual = "c"
	if sprite_tanque and tex_tanque["c"]:
		sprite_tanque.texture = tex_tanque["c"]
	if sprite_directora:
		sprite_directora.flip_h = false
		if frames_directora_conducir.size() > 0:
			sprite_directora.texture = frames_directora_conducir[0]
			
	# Entrada rápida triunfal
	scale = Vector2(0.1, 0.1)
	var tw_in = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(self, "scale", Vector2(1.2, 1.2), 0.35)
	await tw_in.finished
	
	# Puffs de humo y bocinazos del tanque
	if humo_disparo:
		humo_disparo.position = Vector2(0, 24)
		humo_disparo.restart()
		humo_disparo.emitting = true
		
	# Bocadillo flotante estilizado
	var cartel = PanelContainer.new()
	cartel.name = "BocadilloFase"
	var sb = StyleBoxFlat.new()
	var color_bg = Color(0.9, 0.45, 0.1, 0.95)
	if fase == 2: color_bg = Color(0.85, 0.65, 0.1, 0.95)
	elif fase == 3: color_bg = Color(0.9, 0.35, 0.1, 0.95)
	elif fase >= 4: color_bg = Color(0.9, 0.1, 0.15, 0.95)
	
	sb.bg_color = color_bg
	sb.border_color = Color.WHITE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	cartel.add_theme_stylebox_override("panel", sb)
	
	var label = Label.new()
	var texto_aviso = "¡FASE 2: PRESIÓN!"
	if fase == 3: texto_aviso = "¡FASE 3: CONFINAMIENTO!"
	elif fase >= 4: texto_aviso = "¡¡FASE 4: MUERTE SÚBITA!!"
	label.text = texto_aviso
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.add_child(label)
	cartel.add_child(margin)
	
	add_child(cartel)
	cartel.position = Vector2(-cartel.size.x * 0.5, -75)
	cartel.scale = Vector2.ZERO
	cartel.pivot_offset = Vector2(cartel.size.x * 0.5, cartel.size.y)
	
	var tw_pop = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop.tween_property(cartel, "scale", Vector2.ONE, 0.25)
	
	# Poses de la directora Akikawa ordenando / agitando los brazos
	for i in range(5):
		if sprite_directora and frames_directora_disparar.size() > 0:
			sprite_directora.texture = frames_directora_disparar[i % frames_directora_disparar.size()]
			sprite_directora.flip_h = (i % 2 == 1)
		await get_tree().create_timer(0.2).timeout
		
	await get_tree().create_timer(0.7).timeout
	
	# Retirada del cartel y salida del tanque
	var tw_out_cartel = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw_out_cartel.tween_property(cartel, "scale", Vector2.ZERO, 0.2)
	await tw_out_cartel.finished
	cartel.queue_free()
	
	var tw_out = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw_out.tween_property(self, "scale", Vector2.ZERO, 0.25)
	await tw_out.finished
	
	visible = false
	ocupada = false
