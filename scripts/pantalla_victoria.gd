extends CanvasLayer

@onready var contenedor = $Centro
@onready var label_nombre = $Centro/VBox/LabelNombre
@onready var contenedor_wins = $Centro/VBox/ContenedorWins
@onready var label_wins_sombra = $Centro/VBox/ContenedorWins/LabelWinsSombra
@onready var label_wins_borde = $Centro/VBox/ContenedorWins/LabelWinsBorde
@onready var label_wins_texto = $Centro/VBox/ContenedorWins/LabelWinsTexto
@onready var particulas_confeti = $ParticulasConfeti

func _ready():
	contenedor.modulate.a = 0.0
	contenedor_wins.scale = Vector2.ZERO
	if particulas_confeti:
		particulas_confeti.emitting = false

func animar_aparicion(nombre_texto: String, wins_texto: String):
	label_nombre.text = nombre_texto
	label_wins_sombra.text = wins_texto
	label_wins_borde.text = wins_texto
	label_wins_texto.text = wins_texto
	
	if particulas_confeti:
		particulas_confeti.emitting = true
		particulas_confeti.restart()
		
	# 1. Fade in del contenedor
	var tween_fade = create_tween()
	tween_fade.tween_property(contenedor, "modulate:a", 1.0, 0.25)
	
	# 2. Pop-in con rotación al estilo Mario Party para "Wins!"
	contenedor_wins.rotation_degrees = -5.0
	contenedor_wins.scale = Vector2.ZERO
	
	var tween_wins = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_wins.tween_property(contenedor_wins, "scale", Vector2(1.25, 1.25), 0.35)
	tween_wins.tween_property(contenedor_wins, "scale", Vector2.ONE, 0.15)
	
	# 3. Leve rebote continuo mientras se celebra
	await tween_wins.finished
	var tween_loop = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween_loop.tween_property(contenedor_wins, "scale", Vector2(1.05, 1.05), 0.5)
	tween_loop.tween_property(contenedor_wins, "scale", Vector2.ONE, 0.5)
