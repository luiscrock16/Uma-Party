extends Node2D
class_name PublicoTeatro

# Miembros del público en los palcos del teatro
var lista_espectadores: Array[Node2D] = []
var posiciones_base: Dictionary = {}
var lista_penlights: Array[Node2D] = []
var tiempo_anim: float = 0.0
var ovacion_activa: bool = false
var timer_ovacion: float = 0.0

func _ready():
	for hijo in get_children():
		if hijo is Node2D and hijo.name.begins_with("Espectador"):
			lista_espectadores.append(hijo)
			posiciones_base[hijo] = hijo.position
			var pl = hijo.get_node_or_null("Penlight")
			if pl:
				lista_penlights.append(pl)

func _process(delta: float):
	tiempo_anim += delta
	
	if ovacion_activa:
		timer_ovacion -= delta
		if timer_ovacion <= 0.0:
			ovacion_activa = false
			
	var mult_velocidad = 2.4 if ovacion_activa else 1.0
	
	for i in range(lista_espectadores.size()):
		var esp = lista_espectadores[i]
		var pos_base = posiciones_base.get(esp, esp.position)
		var fase = i * 0.95
		
		# Respiración / balanceo vertical suave
		var bob_amp = 3.5 if ovacion_activa else 1.2
		var bob_y = sin((tiempo_anim * 3.0 * mult_velocidad) + fase) * bob_amp
		esp.position.y = pos_base.y + bob_y
		
		# Balanceo de penlight rítmico
		var pl = esp.get_node_or_null("Penlight")
		if pl:
			var rot_amp = 0.45 if ovacion_activa else 0.22
			pl.rotation = sin((tiempo_anim * 3.8 * mult_velocidad) + fase) * rot_amp

func animar_ovacion(duracion: float = 2.0):
	ovacion_activa = true
	timer_ovacion = duracion
	
	for esp in lista_espectadores:
		var pos_base = posiciones_base.get(esp, esp.position)
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(esp, "position:y", pos_base.y - 7.0, 0.14)
		tw.tween_property(esp, "position:y", pos_base.y, 0.18)

func reaccionar_acierto():
	animar_ovacion(1.8)

func reaccionar_fallo():
	for esp in lista_espectadores:
		var pos_base = posiciones_base.get(esp, esp.position)
		var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(esp, "rotation", 0.08, 0.1)
		tw.tween_property(esp, "rotation", -0.08, 0.1)
		tw.tween_property(esp, "rotation", 0.0, 0.1)
