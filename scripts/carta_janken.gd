extends Node2D
class_name CartaJanken

@onready var panel_fondo = $PanelFondo
@onready var label_icono = $PanelFondo/VBox/LabelIcono
@onready var label_nombre = $PanelFondo/VBox/LabelNombre

enum Opcion { PIEDRA = 0, PAPEL = 1, TIJERAS = 2 }

const DATOS_OPCIONES = {
	Opcion.PIEDRA: {
		"icono": "🪨",
		"nombre": "PIEDRA",
		"color_borde": Color("#e74c3c"),
		"color_bg": Color(0.2, 0.1, 0.12, 0.95),
		"color_texto": Color(1.0, 0.8, 0.8)
	},
	Opcion.PAPEL: {
		"icono": "📄",
		"nombre": "PAPEL",
		"color_borde": Color("#f1c40f"),
		"color_bg": Color(0.2, 0.18, 0.08, 0.95),
		"color_texto": Color(1.0, 0.95, 0.8)
	},
	Opcion.TIJERAS: {
		"icono": "✂️",
		"nombre": "TIJERAS",
		"color_borde": Color("#3498db"),
		"color_bg": Color(0.08, 0.15, 0.22, 0.95),
		"color_texto": Color(0.8, 0.9, 1.0)
	}
}

var tween_actual: Tween = null
var eleccion_guardada: int = -1

func _ready():
	visible = false

func mostrar_oculto():
	eleccion_guardada = -1
	visible = true
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 1)
	
	if panel_fondo:
		var sb = panel_fondo.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		sb.border_color = Color("#f39c12")
		sb.bg_color = Color(0.14, 0.12, 0.18, 0.95)
		panel_fondo.add_theme_stylebox_override("panel", sb)
		
	if label_icono:
		label_icono.text = "❓"
	if label_nombre:
		label_nombre.text = "???"
		label_nombre.modulate = Color(1, 0.9, 0.5)
		
	animar_latido()

func animar_latido():
	if tween_actual and tween_actual.is_valid():
		tween_actual.kill()
		
	tween_actual = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween_actual.tween_property(self, "scale", Vector2(1.12, 1.12), 0.22)
	tween_actual.tween_property(self, "scale", Vector2(1.0, 1.0), 0.22)

func revelar(opcion: int):
	eleccion_guardada = opcion
	visible = true
	
	if tween_actual and tween_actual.is_valid():
		tween_actual.kill()
		
	# Efecto de giro y volteo de carta
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale:x", 0.0, 0.12)
	await tw.finished
	
	var datos = DATOS_OPCIONES.get(opcion, DATOS_OPCIONES[Opcion.PIEDRA])
	if label_icono:
		label_icono.text = datos["icono"]
	if label_nombre:
		label_nombre.text = datos["nombre"]
		label_nombre.modulate = datos["color_texto"]
		
	if panel_fondo:
		var sb = panel_fondo.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		sb.border_color = datos["color_borde"]
		sb.bg_color = datos["color_bg"]
		panel_fondo.add_theme_stylebox_override("panel", sb)
		
	var tw_out = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_out.tween_property(self, "scale", Vector2(1.25, 1.25), 0.18)
	tw_out.tween_property(self, "scale", Vector2.ONE, 0.1)

func marcar_victoria():
	if tween_actual and tween_actual.is_valid():
		tween_actual.kill()
		
	var tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.3)
	tw.parallel().tween_property(self, "modulate", Color(1.3, 1.2, 0.8, 1.0), 0.3)
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)

func marcar_derrota():
	if tween_actual and tween_actual.is_valid():
		tween_actual.kill()
		
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	# Temblor
	var orig_x = position.x
	tw.tween_property(self, "position:x", orig_x - 8.0, 0.05)
	tw.tween_property(self, "position:x", orig_x + 8.0, 0.05)
	tw.tween_property(self, "position:x", orig_x - 5.0, 0.05)
	tw.tween_property(self, "position:x", orig_x, 0.05)
	tw.parallel().tween_property(self, "modulate", Color(0.45, 0.45, 0.45, 0.75), 0.25)
	tw.parallel().tween_property(self, "scale", Vector2(0.88, 0.88), 0.25)

func marcar_empate():
	if tween_actual and tween_actual.is_valid():
		tween_actual.kill()
		
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation_degrees", -8.0, 0.06)
	tw.tween_property(self, "rotation_degrees", 8.0, 0.06)
	tw.tween_property(self, "rotation_degrees", 0.0, 0.06)
	tw.parallel().tween_property(self, "modulate", Color(0.9, 0.9, 0.9, 0.9), 0.2)

func ocultar_suave(tiempo: float = 0.25):
	if tween_actual and tween_actual.is_valid():
		tween_actual.kill()
		
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, tiempo)
	tw.parallel().tween_property(self, "scale", Vector2(0.5, 0.5), tiempo)
	await tw.finished
	visible = false
