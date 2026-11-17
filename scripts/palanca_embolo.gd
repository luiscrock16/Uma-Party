extends Node2D
class_name PalancaEmbolo

signal palanca_presionada(id: int)

@export var id_palanca: int = 0
@export var color_palanca: Color = Color("#ff4757")

@onready var embolo = $EmboloContenedor
@onready var indicador_flecha = $IndicadorFlecha
@onready var base_rect = $BasePodio
@onready var tapa_manija = $EmboloContenedor/TapaManija

var activada: bool = false
var es_bomba: bool = false
var posicion_y_inicial_embolo: float = 0.0

func _ready():
	if embolo:
		posicion_y_inicial_embolo = embolo.position.y
	aplicar_color(color_palanca)
	set_seleccionada(false)

func configurar(id: int, col: Color, bomba: bool):
	id_palanca = id
	color_palanca = col
	es_bomba = bomba
	activada = false
	aplicar_color(col)
	if embolo:
		embolo.position.y = posicion_y_inicial_embolo
	set_seleccionada(false)
	visible = true

func aplicar_color(col: Color):
	color_palanca = col
	if base_rect:
		base_rect.color = col
	if tapa_manija:
		tapa_manija.color = col

func set_seleccionada(seleccionada: bool):
	if indicador_flecha:
		indicador_flecha.visible = seleccionada and not activada
		if seleccionada:
			# Efecto de rebote en la flecha
			var tween = create_tween().set_loops()
			tween.tween_property(indicador_flecha, "position:y", -72.0, 0.3).set_trans(Tween.TRANS_SINE)
			tween.tween_property(indicador_flecha, "position:y", -62.0, 0.3).set_trans(Tween.TRANS_SINE)

func animar_bajada(callback: Callable = Callable()):
	activada = true
	set_seleccionada(false)
	
	# El émbolo desciende rápidamente simulando ser presionado
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(embolo, "position:y", posicion_y_inicial_embolo + 22.0, 0.25)
	
	await tween.finished
	if callback.is_valid():
		callback.call()

func animar_ocultar(al_terminar: Callable = Callable()):
	# Se hunde en el piso del podio
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + 60.0, 0.35)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	await tween.finished
	visible = false
	if al_terminar.is_valid():
		al_terminar.call()

func animar_emerger(pos_x: float, pos_y: float, al_terminar: Callable = Callable()):
	# Emerge desde el suelo hacia su posición final
	position = Vector2(pos_x, pos_y + 60.0)
	modulate = Color.WHITE
	modulate.a = 0.0
	visible = true
	
	if embolo:
		embolo.position.y = posicion_y_inicial_embolo
	activada = false
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", pos_y, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)
	await tween.finished
	visible = true
	modulate.a = 1.0
	if al_terminar.is_valid():
		al_terminar.call()
