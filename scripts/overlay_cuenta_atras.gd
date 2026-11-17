extends CanvasLayer

signal cuenta_atras_terminada

@onready var label_numero = $Centro/VBox/LabelNumero
@onready var label_subtitulo = $Centro/VBox/LabelSubtitulo
@onready var contenedor_centro = $Centro

func _ready():
	ejecutar_cuenta_atras()

func ejecutar_cuenta_atras():
	# 3
	mostrar_paso("3", Color(1, 0.9, 0.2))
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return

	# 2
	mostrar_paso("2", Color(1, 0.65, 0.15))
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return

	# 1
	mostrar_paso("1", Color(1, 0.35, 0.2))
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return

	# ¡YA!
	if label_subtitulo:
		label_subtitulo.text = "¡A JUGAR!"
	mostrar_paso("¡YA!", Color(0.25, 1.0, 0.45), true)
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree(): return

	# Desvanecer suavemente hacia arriba
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(contenedor_centro, "scale", Vector2(1.3, 1.3), 0.25)
	tween.tween_property(contenedor_centro, "modulate:a", 0.0, 0.25)
	await tween.finished

	cuenta_atras_terminada.emit()
	queue_free()

func mostrar_paso(texto: String, color: Color, es_final: bool = false):
	label_numero.text = texto
	label_numero.add_theme_color_override("font_color", color)
	
	# Efecto pop / rebote elástico
	contenedor_centro.scale = Vector2(1.5, 1.5) if not es_final else Vector2(1.8, 1.8)
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(contenedor_centro, "scale", Vector2.ONE, 0.35)
