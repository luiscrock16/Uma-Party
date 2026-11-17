extends Node2D
class_name EstacionTrivia

# --- ELEMENTOS DEL PODIO Y LUCES ---
@onready var foco_luz = $FocoLuz
@onready var capa_back = $CapaBack
@onready var arco_neon = $CapaBack/ArcoNeon
@onready var panel_fondo_neon = $CapaBack/PanelFondoNeon
@onready var badge_p = $CapaBack/BadgeP

@onready var contenedor_avatar = $PuntoAvatar

@onready var capa_front = $CapaFront
@onready var podio_cuerpo = $CapaFront/PodioCuerpo
@onready var podio_borde = $CapaFront/PodioBorde
@onready var linea_neon_frontal = $CapaFront/LineaNeonFrontal
@onready var podio_mesa = $CapaFront/PodioMesa
@onready var podio_mesa_borde = $CapaFront/PodioMesaBorde
@onready var boton_pulsador = $CapaFront/BotonPulsador
@onready var boton_pulsador_luz = $CapaFront/BotonPulsador/BotonPulsadorLuz

@onready var panel_info = $PanelInfo
@onready var label_vidas = $PanelInfo/VBox/LabelVidas
@onready var label_nombre = $PanelInfo/VBox/LabelNombre
@onready var badge_estado = $PanelInfo/VBox/BadgeEstado

var id_jugador: int = -1
var vidas_actuales: int = 3
var esta_eliminado: bool = false
var avatar_instancia: CharacterBody2D = null
var slot_indice: int = 1
var opcion_elegida: int = -1 # 0, 1, 2, 3 o -1 (ninguna)
var color_slot: Color = Color(0.95, 0.3, 0.35)

const COLORES_SLOTS = [
	Color(0.95, 0.3, 0.35), # P1: Rojo Tracen
	Color(0.2, 0.65, 1.0),  # P2: Azul Eléctrico
	Color(1.0, 0.8, 0.2),   # P3: Amarillo Ámbar
	Color(0.25, 0.85, 0.45) # P4: Verde Neón
]

func _ready():
	badge_estado.visible = false
	if foco_luz: foco_luz.modulate.a = 0.2

func configurar_estacion(id: int, num_slot: int, nombre: String, avatar_externo: CharacterBody2D = null, tipo_char: int = 0):
	id_jugador = id
	slot_indice = num_slot
	vidas_actuales = 3
	esta_eliminado = false
	opcion_elegida = -1
	
	# Color temático del atril
	var idx = clamp(num_slot - 1, 0, COLORES_SLOTS.size() - 1)
	color_slot = COLORES_SLOTS[idx]
	aplicar_color_podio(color_slot, num_slot)
	
	# Usar el avatar real del jugador si existe, o instanciar de respaldo
	if avatar_externo and is_instance_valid(avatar_externo):
		avatar_instancia = avatar_externo
		if avatar_instancia.get_parent() != contenedor_avatar:
			avatar_instancia.get_parent().remove_child(avatar_instancia)
			contenedor_avatar.add_child(avatar_instancia)
		avatar_instancia.position = Vector2.ZERO
		avatar_instancia.scale = Vector2(1.65, 1.65)
		avatar_instancia.bloquear_controles(true)
		avatar_instancia.set_physics_process(false)
		avatar_instancia.visible = true
		avatar_instancia.modulate = Color.WHITE
		contenedor_avatar.position = Vector2(0, -58)
		if avatar_instancia.has_node("LabelNick"):
			avatar_instancia.get_node("LabelNick").visible = false
	else:
		if not avatar_instancia:
			var escena_av = preload("res://escenas/personaje_jugable.tscn")
			avatar_instancia = escena_av.instantiate()
			avatar_instancia.name = str(id)
			contenedor_avatar.add_child(avatar_instancia)
			avatar_instancia.bloquear_controles(true)
			avatar_instancia.set_physics_process(false)
			avatar_instancia.scale = Vector2(1.65, 1.65)
			contenedor_avatar.position = Vector2(0, -58)
		avatar_instancia.configurar_visual(tipo_char, nombre)
		if avatar_instancia.has_node("LabelNick"):
			avatar_instancia.get_node("LabelNick").visible = false
		
	label_nombre.text = nombre
	actualizar_vidas_ui()
	badge_estado.visible = false

func aplicar_color_podio(c: Color, num_slot: int):
	if arco_neon: arco_neon.default_color = c
	if linea_neon_frontal: linea_neon_frontal.default_color = c
	if badge_p:
		badge_p.text = "P%d" % num_slot
		badge_p.modulate = c
	if foco_luz:
		foco_luz.modulate = c
		foco_luz.modulate.a = 0.25
	if boton_pulsador:
		boton_pulsador.color = c

func fijar_respuesta(opcion: int):
	if esta_eliminado: return
	opcion_elegida = opcion
	badge_estado.visible = true
	badge_estado.text = "🔒 LISTO"
	badge_estado.modulate = Color(0.4, 1.0, 0.4)
	
	# Animación de pulsar botón físico
	if boton_pulsador:
		var tw_btn = create_tween().set_trans(Tween.TRANS_QUAD)
		tw_btn.tween_property(boton_pulsador, "position:y", -42.0, 0.08)
		tw_btn.parallel().tween_property(boton_pulsador_luz, "color", Color(1.8, 1.8, 1.8, 1.0), 0.08)
		tw_btn.tween_property(boton_pulsador, "position:y", -45.0, 0.12)
		tw_btn.parallel().tween_property(boton_pulsador_luz, "color", Color(1, 0.75, 0.75, 0.85), 0.15)
	
	if foco_luz:
		var tw = create_tween()
		tw.tween_property(foco_luz, "modulate:a", 0.8, 0.12)
		tw.tween_property(foco_luz, "modulate:a", 0.35, 0.2)

func limpiar_para_nueva_ronda():
	opcion_elegida = -1
	if not esta_eliminado:
		badge_estado.visible = false
		badge_estado.text = ""
		if foco_luz: foco_luz.modulate.a = 0.25
		if boton_pulsador: boton_pulsador.position.y = -45.0

func procesar_evaluacion(opcion_correcta: int) -> bool:
	if esta_eliminado: return false
	
	var acerto = (opcion_elegida == opcion_correcta)
	badge_estado.visible = true
	
	if acerto:
		badge_estado.text = "✓ ¡CORRECTO!"
		badge_estado.modulate = Color(0.3, 1.0, 0.4)
		if foco_luz:
			var tw_luz = create_tween().set_loops(3)
			tw_luz.tween_property(foco_luz, "modulate:a", 0.9, 0.12)
			tw_luz.tween_property(foco_luz, "modulate:a", 0.3, 0.12)
			
		animar_victoria_avatar()
		return true
	else:
		vidas_actuales = max(0, vidas_actuales - 1)
		actualizar_vidas_ui()
		animar_fallo_avatar()
		
		if vidas_actuales <= 0:
			esta_eliminado = true
			badge_estado.text = "☠️ ELIMINADO"
			badge_estado.modulate = Color(0.8, 0.2, 0.2)
			apagar_estacion()
			return false
		else:
			badge_estado.text = "❌ ¡FALLASTE!"
			badge_estado.modulate = Color(1.0, 0.4, 0.4)
			return true

func actualizar_vidas_ui():
	var texto = ""
	for i in range(3):
		if i < vidas_actuales:
			texto += "❤️ "
		else:
			texto += "🖤 "
	label_vidas.text = texto.strip_edges()

func animar_victoria_avatar():
	if not avatar_instancia: return
	if "sprite" in avatar_instancia and avatar_instancia.sprite:
		avatar_instancia.sprite.play(avatar_instancia.prefijo_personaje + "_salto")
		
	var orig_y = avatar_instancia.position.y
	var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(avatar_instancia, "position:y", orig_y - 24.0, 0.22)
	tw.tween_property(avatar_instancia, "position:y", orig_y, 0.22)
	await tw.finished
	if is_instance_valid(avatar_instancia) and not esta_eliminado and "sprite" in avatar_instancia:
		avatar_instancia.sprite.play(avatar_instancia.prefijo_personaje + "_idle")

func animar_fallo_avatar():
	if not avatar_instancia: return
	if "sprite" in avatar_instancia and avatar_instancia.sprite:
		avatar_instancia.sprite.play(avatar_instancia.prefijo_personaje + "_impacto")
		
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(avatar_instancia, "modulate", Color(1, 0.3, 0.3), 0.1)
	tw.tween_property(avatar_instancia, "modulate", Color(1, 1, 1), 0.2)
	tw.parallel().tween_property(avatar_instancia, "rotation_degrees", -6.0, 0.08)
	tw.tween_property(avatar_instancia, "rotation_degrees", 6.0, 0.08)
	tw.tween_property(avatar_instancia, "rotation_degrees", 0.0, 0.08)
	
	# Pequeña sacudida del atril
	var orig_x = capa_front.position.x
	var tw_pod = create_tween().set_trans(Tween.TRANS_SINE)
	tw_pod.tween_property(capa_front, "position:x", orig_x - 4.0, 0.05)
	tw_pod.tween_property(capa_front, "position:x", orig_x + 4.0, 0.05)
	tw_pod.tween_property(capa_front, "position:x", orig_x, 0.05)
	
	await tw.finished
	if is_instance_valid(avatar_instancia) and not esta_eliminado and "sprite" in avatar_instancia:
		avatar_instancia.sprite.play(avatar_instancia.prefijo_personaje + "_idle")

func apagar_estacion():
	var tw = create_tween()
	if foco_luz:
		tw.parallel().tween_property(foco_luz, "modulate:a", 0.05, 0.5)
	if arco_neon:
		tw.parallel().tween_property(arco_neon, "default_color", Color(0.25, 0.25, 0.25, 0.5), 0.5)
	if linea_neon_frontal:
		tw.parallel().tween_property(linea_neon_frontal, "default_color", Color(0.2, 0.2, 0.2, 0.5), 0.5)
	if podio_cuerpo:
		tw.parallel().tween_property(podio_cuerpo, "color", Color(0.06, 0.05, 0.08, 0.9), 0.5)
	if boton_pulsador:
		tw.parallel().tween_property(boton_pulsador, "color", Color(0.2, 0.2, 0.2), 0.5)
	if avatar_instancia:
		tw.parallel().tween_property(avatar_instancia, "modulate", Color(0.4, 0.4, 0.45, 0.8), 0.5)
