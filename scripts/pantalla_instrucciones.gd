extends CanvasLayer

signal instrucciones_completadas

# Nodos principales del Modal Central (Fiel a Screenshot 3 de Party Dash)
@onready var label_titulo = $FondoOscuro/PanelModal/Margen/VBox/Header/LabelTitulo
@onready var label_modo = $FondoOscuro/PanelModal/Margen/VBox/Header/LabelModo
@onready var texture_preview = $FondoOscuro/PanelModal/Margen/VBox/FramePreview/TexturePreview
@onready var label_accion_pill = $FondoOscuro/PanelModal/Margen/VBox/PillAccion/LabelAccion
@onready var label_objetivo = $FondoOscuro/PanelModal/Margen/VBox/BoxTexto/VBox/LabelObjetivo
@onready var label_victoria = $FondoOscuro/PanelModal/Margen/VBox/BoxTexto/VBox/LabelVictoria
@onready var label_controles = $FondoOscuro/PanelModal/Margen/VBox/BoxTexto/VBox/LabelControles

@onready var contenedor_jugadores = $FondoOscuro/PanelModal/Margen/VBox/Footer/ContenedorJugadores
@onready var btn_listo = $FondoOscuro/PanelModal/Margen/VBox/Footer/BtnListo

# Nodos de las presentadoras interactivas
@onready var btn_tazuna = $FondoOscuro/Personajes/BtnTazuna
@onready var anim_tazuna = $FondoOscuro/Personajes/BtnTazuna/TazunaSprite
@onready var bocadillo_tazuna = $FondoOscuro/Personajes/BocadilloTazuna
@onready var label_tazuna_texto = $FondoOscuro/Personajes/BocadilloTazuna/Margen/VBox/LabelTexto

@onready var btn_directora = $FondoOscuro/Personajes/BtnDirectora
@onready var anim_directora = $FondoOscuro/Personajes/BtnDirectora/DirectoraSprite
@onready var bocadillo_directora = $FondoOscuro/Personajes/BocadilloDirectora
@onready var label_directora_texto = $FondoOscuro/Personajes/BocadilloDirectora/Margen/VBox/LabelTexto

@onready var banner_inicio = $BannerInicio
@onready var label_banner = $BannerInicio/Panel/LabelBanner

var clave_juego: String = "garra"
var id_local: int = 1
var jugadores_info: Dictionary = {}
var jugadores_listos: Dictionary = {}
var listo_local: bool = false
var ya_iniciando: bool = false

var sprites_directora: Array = []
var sprites_tazuna: Array = []

# Mapeo de previews reales
const PREVIEWS: Dictionary = {
	"garra": "res://assets/previews/preview_garra.png",
	"cinta": "res://assets/previews/preview_plataformas.png",
	"plataformas": "res://assets/previews/preview_plataformas.png",
	"explosion": "res://assets/previews/preview_ruleta.png",
	"canones": "res://assets/previews/preview_canones.png",
	"pista": "res://assets/previews/preview_pista.png",
	"templo": "res://assets/previews/preview_templo.png",
	"globos": "res://assets/previews/preview_globos.png",
	"janken": "res://assets/previews/preview_janken.png",
	"trivia": "res://assets/previews/preview_trivia.png",
	"atrapa_colas": "res://assets/previews/preview_atrapacolas.png",
	"snowboard": "res://assets/previews/preview_pista.png",
	"laberinto": "res://assets/previews/preview_pista.png",
	"paraguas": "res://assets/previews/preview_plataformas.png",
	"cojines": "res://assets/previews/preview_templo.png",
	"martillo": "res://assets/previews/preview_garra.png",
	"canaduz": "res://assets/previews/preview_canones.png",
	"remo": "res://assets/previews/preview_globos.png",
	"duelo": "res://assets/previews/preview_janken.png",
	"guillotina": "res://assets/previews/preview_ruleta.png"
}

const CATALOGO: Dictionary = {
	"garra": {
		"nombre": "La Garra de Premios",
		"categoria": "1 vs 3 • MODO JEFE",
		"roles": {
			"jefe": {
				"pill": "CONTROLADOR: ATRAPAR CORREDORAS",
				"objetivo": "Desplaza la grúa por el riel superior y presiona el botón para bajar las pinzas mecánicas sobre las 3 corredoras.",
				"victoria": "Atrapar a todas las corredoras antes de que se agote el tiempo.",
				"controles": "A/D o Flechas: Mover grúa | Espacio o Click: Soltar pinzas | Táctil: Botón de descenso",
				"directora": "¡Agarra los peluches del suelo para despejar el espacio y reducir los escondites de las demás corredoras!",
				"tazuna": "¡Presta atención a la sombra en el suelo para predecir con exactitud dónde caerán las pinzas!"
			},
			"superviviente": {
				"pill": "SUPERVIVIENTE: ESQUIVAR LA GARRA",
				"objetivo": "Corre y salta sobre los peluches acumulados dentro de la máquina de premios para evitar ser capturada.",
				"victoria": "Sobrevivir sin ser atrapada cuando el cronómetro llegue a 0.",
				"controles": "A/D o Flechas: Correr | W o Espacio: Saltar sobre peluches | Táctil: Joystick y botón salto",
				"directora": "¡No te quedes arrinconada en las esquinas! ¡Un salto oportuno en el momento del descenso te salvará!",
				"tazuna": "¡Usa los montones de peluches como escudo para entorpecer el descenso directo de la garra!"
			}
		}
	},
	"plataformas": {
		"nombre": "Caída de Plataformas",
		"categoria": "TODOS CONTRA TODOS • FFA",
		"roles": {
			"general": {
				"pill": "SUPERVIVENCIA EN PLATAFORMAS",
				"objetivo": "¡Observa la pantalla gigante! Cuando elija una figura, corre a una plataforma con esa misma figura antes de que las demás caigan al vacío.",
				"victoria": "Ser el último jugador en pie sobre las plataformas.",
				"controles": "WASD / Flechas: Caminar | Espacio / Enter: Empujar a rivales cercanos",
				"directora": "¡En cada ronda caen más plataformas y vuelven a subir menos! ¡El espacio se irá reduciendo!",
				"tazuna": "¡Usa la tecla de acción para empujar a tus rivales al vacío o aturdirlos justo antes del desplome!"
			}
		}
	},
	"cinta": {
		"nombre": "Cinta de Carrera",
		"categoria": "1 vs 3 • MODO JEFE",
		"roles": {
			"jefe": {
				"pill": "LANZADOR: DISPARAR CAJAS",
				"objetivo": "Apunta el cañón lanzador y dispara cajas a diferentes alturas para empujar a las corredoras fuera de la cinta.",
				"victoria": "Tirar a todas las corredoras por la parte trasera de la cinta transportadora.",
				"controles": "W/S o Flechas: Alinear cañón | Espacio o Click: Disparar caja | Táctil: Botón disparo",
				"directora": "¡Dispara ráfagas continuas hacia el carril donde veas a dos corredoras juntas!",
				"tazuna": "¡Aprovecha que la velocidad de la cinta aumenta con el tiempo para rematarlas con cajas pesadas!"
			},
			"superviviente": {
				"pill": "CORREDORA: SUPERVIVENCIA EN CINTA",
				"objetivo": "Corre hacia adelante contra la cinta y salta las cajas rodantes para evitar caer al foso trasero.",
				"victoria": "Permanecer sobre la cinta transportadora cuando termine el tiempo.",
				"controles": "WASD o Flechas: Correr y cambiar carril | Espacio: Saltar cajas | Táctil: Joystick y salto",
				"directora": "¡No te quedes pegada al borde trasero! Si la cinta acelera, ¡no tendrás tiempo de reaccionar!",
				"tazuna": "¡El salto parabólico te permite sobrevolar cajas enteras sin frenar tu avance!"
			}
		}
	},
	"explosion": {
		"nombre": "La Gran Explosión",
		"categoria": "TODOS CONTRA TODOS • FFA",
		"roles": {
			"general": {
				"pill": "PATATA CALIENTE: PASAR LA BOMBA",
				"objetivo": "Si tienes la bomba, corre a tocar a otra jugadora para entregársela. Si no la tienes, ¡huye tan lejos como puedas!",
				"victoria": "Ser la última corredora en pie sin que la bomba estalle en tus manos.",
				"controles": "WASD o Flechas: Moverte libremente | Toque: Pasar la bomba por contacto | Táctil: Joystick virtual",
				"directora": "¡Si la bomba empieza a parpadear en rojo rápido, significa que quedan pocos segundos! ¡Pásala ya!",
				"tazuna": "¡Aprovecha los bordes redondeados del mapa para hacer fintas y cambiar de dirección de imprevisto!"
			}
		}
	},
	"canones": {
		"nombre": "Cañones Giratorios",
		"categoria": "TODOS CONTRA TODOS • FFA",
		"roles": {
			"general": {
				"pill": "SUPERVIVENCIA: ESQUIVAR CAÑONAZOS",
				"objetivo": "Esquiva las balas de cañón giratorias que cruzan la plataforma y no caigas de la arena.",
				"victoria": "Sobrevivir a las oleadas de cañonazos mientras las rivales son eliminadas.",
				"controles": "WASD o Flechas: Moverte | Espacio: Saltar proyectiles rasos | Táctil: Joystick y salto",
				"directora": "¡Los engranajes del centro te indican la rotación de los cañones! ¡Anticípate a sus giros!",
				"tazuna": "¡Mantén la calma! Saltar sin medir bien la distancia puede hacerte aterrizar sobre otra bala."
			}
		}
	},
	"pista": {
		"nombre": "Caos en la Pista",
		"categoria": "2 vs 2 • POR EQUIPOS",
		"roles": {
			"general": {
				"pill": "RELEVOS: COORDINACIÓN DE EQUIPO",
				"objetivo": "Cruza los puntos de control y recolecta orbes de energía junto a tu compañera de equipo.",
				"victoria": "Conseguir la mayor puntuación de equipo al agotarse el tiempo.",
				"controles": "WASD o Flechas: Correr | Espacio: Acelerón de relevo | Táctil: Joystick virtual",
				"directora": "¡La sincronización lo es todo! ¡Si una cubre la zona alta y otra la baja, dominarán la pista!",
				"tazuna": "¡El trabajo en equipo suma el doble! Ayuda a tu compañera bloqueando el paso a las rivales."
			}
		}
	},
	"templo": {
		"nombre": "Templo Pinball",
		"categoria": "TODOS CONTRA TODOS • FFA",
		"roles": {
			"general": {
				"pill": "SANTUARIO: ESQUIVAR ESFERAS",
				"objetivo": "Esquiva las enormes esferas rodantes que rebotan por el templo impulsadas por los pivotes sagrados.",
				"victoria": "Ser la última competidora en no ser expulsada del templo.",
				"controles": "WASD o Flechas: Moverte | Espacio: Salto de emergencia | Táctil: Joystick y salto",
				"directora": "¡Los pivotes dorados rebotan las bolas con fuerza extrema! ¡Usa los postes fijos como escudo!",
				"tazuna": "¡No saltes a lo loco! Guarda el salto de emergencia para cuando una bola venga directa hacia ti."
			}
		}
	},
	"globos": {
		"nombre": "Globos Chocones",
		"categoria": "2 vs 2 • POR EQUIPOS",
		"roles": {
			"general": {
				"pill": "CHOQUE: REVENTAR GLOBOS RIVALES",
				"objetivo": "Embiste a las rivales contra los pinchos para reventar sus globos mientras proteges los de tu equipo.",
				"victoria": "Reventar todos los globos del equipo rival.",
				"controles": "WASD o Flechas: Conducir | Espacio: Turbo de embestida | Táctil: Joystick y embestida",
				"directora": "¡Atacad en pinza! Si una rival queda atrapada entre las dos, ¡sus globos explotarán de inmediato!",
				"tazuna": "¡Ten cuidado con los muros de pinchos cuando utilices el turbo, o rebotarás contra ellos!"
			}
		}
	},
	"janken": {
		"nombre": "Duelo Jan-Ken-Pon",
		"categoria": "2 vs 2 • DUELO POR MESAS",
		"roles": {
			"general": {
				"pill": "DUELO: PIEDRA, PAPEL O TIJERA",
				"objetivo": "Enfréntate a tu rival en cada mesa eligiendo Piedra, Papel o Tijera. La ganadora avanza a la mesa final.",
				"victoria": "Ganar las rondas de tu mesa y proclamarte campeona en la final.",
				"controles": "Teclas 1, 2, 3 o Click en pantalla: Elegir carta | Táctil: Tocar carta deseada",
				"directora": "¡Piedra vence a Tijera, Tijera a Papel, Papel a Piedra! ¡Recuerda las reglas básicas de la academia!",
				"tazuna": "¡Tienes un tiempo límite para seleccionar cada turno! Si empatan, se jugará un desempate al instante."
			}
		}
	},
	"trivia": {
		"nombre": "Trivia Show TV",
		"categoria": "TODOS CONTRA TODOS • FFA",
		"roles": {
			"general": {
				"pill": "CONCURSO: PREGUNTAS Y RESPUESTAS",
				"objetivo": "Escucha las preguntas de la Directora Akikawa y pulsa la opción correcta antes de que acabe el tiempo.",
				"victoria": "Conservar tus 3 corazones de vida y ser la concursante con más aciertos.",
				"controles": "Teclas 1, 2, 3, 4 o Click en pantalla: Seleccionar respuesta A, B, C o D",
				"directora": "¡Atención a las preguntas capciosas! ¡Un tren eléctrico no produce humo! ¡Lean con detenimiento!",
				"tazuna": "¡Por defecto se marcará una respuesta, pero puedes cambiarla hasta el último segundo del reloj!"
			}
		}
	},
	"atrapa_colas": {
		"nombre": "Cacería de Colas",
		"categoria": "1 vs 3 • MODO JEFE",
		"roles": {
			"jefe": {
				"pill": "CAZADORA: ATRAPAR TODAS LAS COLAS",
				"objetivo": "Persigue a las 3 fugitivas por los carriles de césped, tierra e interior y tócalas para atraparlas antes de 45s.",
				"victoria": "Capturar a las 3 fugitivas antes de que se agote el tiempo.",
				"controles": "WASD o Flechas: Correr | Espacio o Click: Turbo Sprint | Táctil: Joystick y botón SPRINT",
				"directora": "¡Guarda tu Sprint para las rectas largas! ¡Y cuidado con resbalar en las cáscaras de plátano!",
				"tazuna": "¡Corta camino por el césped central para interceptar a las fugitivas cuando doblen la curva!"
			},
			"superviviente": {
				"pill": "FUGITIVA: ESCAPAR CON TU ESTRELLA",
				"objetivo": "Huye de la cazadora durante 45 segundos por la pista de entrenamiento sin dejarte tocar.",
				"victoria": "Sobrevivir hasta que el cronómetro llegue a 0.",
				"controles": "WASD o Flechas: Correr libremente por césped y tierra | Táctil: Joystick virtual",
				"directora": "¡Manténganse dispersas por la pista! Si la cazadora persigue a una, ¡las otras dos deben alejarse!",
				"tazuna": "¡Haz que la cazadora pase por encima de los plátanos para que resbale y quede aturdida!"
			}
		}
	},
	"snowboard": {
		"nombre": "Carrera de Trineos Alpina",
		"categoria": "TODOS CONTRA TODOS • FFA",
		"roles": {
			"general": {
				"pill": "DESCENSO EN TRINEO: REBUFO & BLOQUEO",
				"objetivo": "Baja la montaña nevada en flotador estilo Club Penguin. Durante el conteo 3-2-1, pulsa para clavar la aguja en el centro verde. En carrera, ponte tras un rival para cargar rebufo y adelantarlo. Si vas delante, ¡bloquea a tiempo para impulsarte!",
				"victoria": "Ser la primera en cruzar la meta frente a la cabaña alpina.",
				"controles": "W/S o Flechas: Cambiar de carril | Espacio o Click: Clavar aguja en centro / Sprint / Bloqueo",
				"directora": "¡Clava la aguja justo en el centro verde durante el conteo para salir con TURBO PERFECTO!",
				"tazuna": "¡Usa las rampas metálicas para volar sobre los troncos de madera y esquivar los obstáculos!"
			}
		}
	},
	"laberinto": {
		"nombre": "Festival Tracen: Las 4 Llaves",
		"categoria": "TODOS CONTRA TODOS • FFA",
		"roles": {
			"general": {
				"pill": "FESTIVAL: ENCONTRAR LLAVE Y ABRIR PUERTA",
				"objetivo": "Busca una de las 4 llaves de colores por los puestos del festival y cruza hacia su puerta opuesta para acceder a la campana dorada.",
				"victoria": "Ser la primera corredora en abrir su puerta de color y tocar la campana central.",
				"controles": "WASD o Flechas: Correr | Espacio o Click: Sprint | Táctil: Joystick virtual",
				"directora": "¡Las llaves y sus puertas están en extremos opuestos del mapa! ¡Si tomas la llave roja, corre hacia el Norte!",
				"tazuna": "¡Solo puedes portar una llave a la vez! Observa bien tu brújula superior para saber a qué puerta debes dirigirte."
			}
		}
	},
	"paraguas": {
		"nombre": "Vendaval de Kris S",
		"categoria": "TODOS CONTRA TODOS • FFA",
		"roles": {
			"general": {
				"pill": "SUPERVIVENCIA: ESQUIVAR TORNADOS Y RAYOS",
				"objetivo": "¡Symboli Kris S ha invocado una tempestad colosal en la pista! Corre y usa tu sprint para esquivar los tornados errantes y aléjate rápidamente de las marcas en el suelo antes de que caigan los rayos.",
				"victoria": "Sobrevivir a la tormenta hasta que se agote el tiempo. ¡Todas las corredoras que sigan en pie ganarán la partida!",
				"controles": "WASD o Flechas: Correr | Espacio o Click: Sprint de evasión / Forcejear | Táctil: Joystick y Sprint",
				"directora": "¡Si te acercas al núcleo del tornado serás succionada al vórtice y empezarás a girar! ¡Pulsa acción rápidamente para forcejear y escapar antes de que te expulse!",
				"tazuna": "¡Atenta a las retículas amarillas en el suelo! Te avisan con antelación dónde caerá un rayo. ¡Usa el sprint para cruzar la pista y ponerte a salvo!"
			}
		}
	},
	"cojines": {
		"nombre": "Guerra de Cojines en el Dormitorio",
		"categoria": "TODOS CONTRA TODOS • FFA",
		"roles": {
			"general": {
				"pill": "DORMITORIO TRACEN: GUERRA DE ALMOHADAS",
				"objetivo": "¡Pijamada en el dormitorio de Tracen! Deslízate con inercia sobre el tatami y blande tu almohada como una espada para expulsar a tus rivales del ring.",
				"victoria": "Ser la última corredora en pie dentro del tatami antes de que el espacio se reduzca al mínimo.",
				"controles": "WASD / Flechas: Deslizarte con inercia | Espacio, Enter o Click: Blandir almohada | Táctil: Botón GOLPE COJÍN",
				"directora": "¡El tatami se irá encogiendo cada pocos segundos! ¡Aprovecha la inercia del deslizamiento para golpear con impulso!",
				"tazuna": "¡Cuidado al cambiar de dirección! Tu cuerpo seguirá resbalando unos instantes por la inercia del suelo como en una pista de hielo."
			}
		}
	},
	"martillo": {
		"nombre": "Golpe al Topo en la Feria",
		"categoria": "1 vs 3 • MODO JEFE",
		"roles": {
			"jefe": {
				"pill": "OPERADORA: GOLPEAR CON EL MARTILLO",
				"objetivo": "Elige en qué hoyo caerá tu martillo gigante cada ronda antes de que acabe el tiempo para aplastar a los topos.",
				"victoria": "Aplanar y eliminar a todos los topos antes de que finalicen las 8 rondas.",
				"controles": "WASD / Flechas / Números 1-9: Seleccionar hoyo | Táctil: Tocar hoyo deseado",
				"directora": "¡Anticípate a sus movimientos! Conforme pasen las rondas se cerrarán hoyos y será más fácil acorralarlas.",
				"tazuna": "¡Atenta a los hoyos clausurados con una cruz roja! Nadie podrá esconderse en esas casillas."
			},
			"superviviente": {
				"pill": "TOPOS: ESCONDERSE EN LOS HOYOS",
				"objetivo": "Elige en qué hoyo esconderte cada turno antes de que termine el tiempo. Al sonar la campana, ¡asomarás la cabeza! Si varias eligen el mismo hoyo, saldrán juntas.",
				"victoria": "Sobrevivir a todas las rondas de martillazos sin ser aplastada.",
				"controles": "WASD / Flechas / Números 1-9: Elegir hoyo | Táctil: Tocar hoyo deseado",
				"directora": "¡Cuidado con meterse en el mismo hoyo que tus compañeras! Si el martillo cae ahí, ¡las aplastará a todas a la vez!",
				"tazuna": "¡En cada ronda habrá menos tiempo para decidir y se clausurarán más hoyos con tapas de madera!"
			}
		}
	},
	"canaduz": {
		"nombre": "Festival de Cañones de Cañaduz",
		"categoria": "1 vs 3 • MODO JEFE",
		"roles": {
			"jefe": {
				"pill": "ARTILLERA DE FESTIVAL: DISPARAR CAÑONES",
				"objetivo": "Gira 360 grados en tu tarima festiva y dispara manualmente cañonazos de pirotecnia para eliminar a las corredoras. ¡Tu munición de 5 cargas se regenera con el tiempo!",
				"victoria": "Eliminar a todas las corredoras antes de que se agote el 1:30 de tiempo.",
				"controles": "WASD / Flechas / Ratón: Apuntar 360° | Espacio o Click: Disparar proyectil manual",
				"directora": "¡En las primeras fases tus proyectiles son directos! ¡En la fase final tus cañones triples de festival dispararán proyectiles con rebote por los puestos y pasillos!",
				"tazuna": "¡Aprovecha que los pasillos asimétricos canalizan a las corredoras! ¡Espera a que asomen para disparar!"
			},
			"superviviente": {
				"pill": "SUPERVIVIENTE: ESQUIVAR EN EL FESTIVAL",
				"objetivo": "Aprovecha los puestos de comida y los pasillos de barricadas para cubrirte y sobrevive durante 1 minuto y medio.",
				"victoria": "Permanecer con vida cuando el cronómetro llegue a 00:00. ¡Todos los supervivientes ganan!",
				"controles": "WASD o Flechas: Correr libremente | Espacio: Salto / Acelerón evasivo | Táctil: Joystick virtual",
				"directora": "¡Los puestos del festival son coberturas fijas seguras! ¡Úsalos junto a las barricadas dinámicas para no quedar acorralada!",
				"tazuna": "¡Atenta al parpadeo de las barricadas! Te avisa cuando un muro o pasillo va a colapsar bajo tierra. ¡Mantén la distancia con el centro!"
			}
		}
	},
	"remo": {
		"nombre": "Regata del Campamento de Verano",
		"categoria": "2 vs 2 • POR EQUIPOS",
		"roles": {
			"general": {
				"pill": "CAMPAMENTO DE VERANO: REGATA TROPICAL",
				"objetivo": "¡Campamento playero de Tracen! Coordina las remadas con tu compañera de bote. El remero izquierdo gira el bote a la derecha y el derecho a la izquierda. ¡Remen a la vez para alcanzar sincronía perfecta!",
				"victoria": "Ser el primer equipo en cruzar la meta marina y encallar en la playa.",
				"controles": "Espacio / Enter / W o Click / Toque: Dar remada | Táctil: Botón REMAR",
				"directora": "¡Fíjate en los indicadores de flecha curva de tu bote! Te muestran hacia qué lado girará el bote al remar.",
				"tazuna": "¡Cuidado con las rocas marinas! Y recuerda: ¡cuando ambas reman a la vez, el bote se estabiliza y activa el turbo!"
			}
		}
	},
	"duelo": {
		"nombre": "Duelo del Oeste",
		"categoria": "1 vs 1 • DUELO DEL OESTE (CON ESPECTADORES)",
		"roles": {
			"general": {
				"pill": "REFLEJOS: DESENFUNDAR EN LA OSCURIDAD",
				"objetivo": "¡Duelo al atardecer en el Lejano Oeste! Dos corredoras se enfrentan cara a cara mientras los demás observan. El sol caerá y la noche envolverá la calle en penumbra. Espera en suspenso al destello del farol del pueblo para disparar.",
				"victoria": "Ser la más rápida en desenfundar al ver la señal ambiental del farol.",
				"controles": "Espacio / Enter / Click o Toque: Desenfundar y disparar",
				"directora": "¡Cuidado con disparar antes de tiempo en la oscuridad! Si disparas antes del destello, ¡perderás el duelo!",
				"tazuna": "¡No habrá texto en pantalla! Mantén los ojos bien fijos en el farol del escenario cuando caiga la noche."
			}
		}
	},
	"guillotina": {
		"nombre": "Ruleta de Merengue: Fábrica de Pasteles",
		"categoria": "TODOS CONTRA TODOS • FFA",
		"roles": {
			"general": {
				"pill": "REPOSTERÍA: ARMAR PASTEL Y ENTREGAR AL JURADO",
				"objetivo": "Recoge los 5 ingredientes que expulsa la máquina central y móntalos en tu plato. ¡Cuidado con los chorros de crema y bloques de chocolate que pueden arruinar tu pastel! Puedes agarrar tu plato y moverlo a un sitio seguro.",
				"victoria": "Armar las 5 capas del pastel y llevarlo primero a la mesa de jurados.",
				"controles": "Moverse: Flechas / WASD • Espacio / Click / Tacto: Agarrar o soltar plato / recoger y colocar ingredientes",
				"directora": "¡La máquina aumentará su presión con el tiempo arrojando más merengue! ¡Aparten sus platos si ven sombras de peligro!",
				"tazuna": "¡Atención a las sombras rojas de impacto! Si una crema cae en tu plato, el pastel se derretirá y tendrás que empezar de cero."
			}
		}
	}
}

func _ready():
	cargar_animaciones_presentadoras()
	if btn_listo:
		btn_listo.pressed.connect(_on_btn_listo_pulsado)
		btn_listo.grab_focus()
		
	if btn_tazuna:
		btn_tazuna.pressed.connect(_on_btn_tazuna_pulsado)
	if btn_directora:
		btn_directora.pressed.connect(_on_btn_directora_pulsado)

func cargar_animaciones_presentadoras():
	for i in range(4):
		var r_d = "res://assets/Sprites/NPCS/Yayoi Akikawa/akyy_ST01_0%d.png" % i
		if ResourceLoader.exists(r_d):
			sprites_directora.append(load(r_d))
			
	for i in range(4):
		var r_t = "res://assets/Sprites/NPCS/Tazuna Hayakawa/hatz_ST01_0%d.png" % i
		if ResourceLoader.exists(r_t):
			sprites_tazuna.append(load(r_t))

func _process(_delta):
	# Animar los sprites de las presentadoras
	if sprites_directora.size() > 0 and anim_directora:
		var idx_d = int(Time.get_ticks_msec() / 150.0) % sprites_directora.size()
		anim_directora.texture = sprites_directora[idx_d]
		
	if sprites_tazuna.size() > 0 and anim_tazuna:
		var idx_t = int(Time.get_ticks_msec() / 150.0) % sprites_tazuna.size()
		anim_tazuna.texture = sprites_tazuna[idx_t]

func _unhandled_input(event: InputEvent):
	if ya_iniciando: return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		if not listo_local:
			_on_btn_listo_pulsado()

func configurar_pantalla(clave: String, dict_jugadores: Dictionary, mi_id: int):
	clave_juego = clave
	jugadores_info = dict_jugadores.duplicate()
	id_local = mi_id
	jugadores_listos.clear()
	listo_local = false
	ya_iniciando = false
	
	if multiplayer.has_multiplayer_peer():
		if not multiplayer.peer_disconnected.is_connected(_on_peer_desconectado_instrucciones):
			multiplayer.peer_disconnected.connect(_on_peer_desconectado_instrucciones)
			
	# Temporizador de seguridad en el anfitrión: si alguien no confirma en 12s, iniciar automáticamente
	if multiplayer.has_multiplayer_peer() and es_anfitrion():
		get_tree().create_timer(12.0).timeout.connect(func():
			if not ya_iniciando and is_inside_tree():
				print("[Instrucciones] Auto-iniciando por tiempo límite de espera...")
				iniciar_transicion_partida_rpc.rpc()
		)
	
	if not CATALOGO.has(clave_juego):
		if "carritos" in clave_juego.to_lower():
			clave_juego = "snowboard"
		else:
			for k in CATALOGO.keys():
				if k in clave_juego.to_lower():
					clave_juego = k
					break
	
	var datos = CATALOGO.get(clave_juego, CATALOGO["garra"])
	
	# Cargar imagen de preview real
	var ruta_prev = PREVIEWS.get(clave_juego, "res://assets/previews/preview_garra.png")
	if ResourceLoader.exists(ruta_prev) and texture_preview:
		texture_preview.texture = load(ruta_prev)
	
	# Determinar rol local
	var subrol = "general"
	var info_local = jugadores_info.get(id_local, {})
	var es_jefe = info_local.get("es_jefe", false)
	
	if datos["roles"].has("jefe") and datos["roles"].has("superviviente"):
		subrol = "jefe" if es_jefe else "superviviente"
		
	var info_rol = datos["roles"].get(subrol, datos["roles"].values()[0])
	
	# Poblar UI central
	if label_titulo: label_titulo.text = datos["nombre"].to_upper()
	if label_modo: label_modo.text = datos["categoria"]
	if label_accion_pill: label_accion_pill.text = info_rol["pill"]
	if label_objetivo: label_objetivo.text = "Objetivo: " + info_rol["objetivo"]
	if label_victoria: label_victoria.text = "Victoria: " + info_rol["victoria"]
	if label_controles: label_controles.text = "Controles: " + info_rol["controles"]
	
	# Configurar textos de los bocadillos interactivos
	if label_directora_texto: label_directora_texto.text = '"' + info_rol["directora"] + '"'
	if label_tazuna_texto: label_tazuna_texto.text = '"' + info_rol["tazuna"] + '"'
	
	# Ocultar bocadillos inicialmente
	if bocadillo_tazuna: bocadillo_tazuna.visible = false
	if bocadillo_directora: bocadillo_directora.visible = false
	
	actualizar_tarjetas_jugadores()
	
	if not multiplayer.has_multiplayer_peer():
		simular_confirmacion_bots_f6()
		
	# Timer de seguridad por si algún jugador tarda en presionar confirmar
	if es_anfitrion():
		get_tree().create_timer(12.0).timeout.connect(func():
			if is_inside_tree() and not ya_iniciando:
				ya_iniciando = true
				if multiplayer.has_multiplayer_peer():
					iniciar_transicion_partida_rpc.rpc()
				else:
					iniciar_transicion_partida_rpc()
		)

func actualizar_tarjetas_jugadores():
	if not contenedor_jugadores: return
	for c in contenedor_jugadores.get_children():
		c.queue_free()
		
	var ids = jugadores_info.keys()
	if ids.size() == 0:
		ids = [1]
		
	var colores_event_prep = [
		{"bg": Color(0.93, 0.98, 0.92), "border": Color(0.45, 0.82, 0.28), "text": Color(0.2, 0.6, 0.15)}, # P1 Verde
		{"bg": Color(0.99, 0.98, 0.9),  "border": Color(0.95, 0.78, 0.22), "text": Color(0.75, 0.55, 0.1)}, # P2 Oro
		{"bg": Color(0.92, 0.97, 0.99), "border": Color(0.3, 0.72, 0.94),  "text": Color(0.15, 0.45, 0.8)}, # P3 Azul
		{"bg": Color(0.98, 0.93, 0.98), "border": Color(0.78, 0.45, 0.85), "text": Color(0.6, 0.25, 0.65)}  # P4 Rosa/Lila
	]
	
	var idx = 0
	for id in ids:
		var p_info = jugadores_info.get(id, {})
		var nom = p_info.get("nombre", "P" + str(id))
		var listo = jugadores_listos.get(id, false)
		var esquema = colores_event_prep[idx % colores_event_prep.size()]
		idx += 1
		
		var chip = PanelContainer.new()
		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.bg_color = esquema["bg"]
		sb.border_color = esquema["border"] if listo else Color(0.8, 0.82, 0.85)
		chip.add_theme_stylebox_override("panel", sb)
		
		var m = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 10)
		m.add_theme_constant_override("margin_right", 10)
		m.add_theme_constant_override("margin_top", 4)
		m.add_theme_constant_override("margin_bottom", 4)
		chip.add_child(m)
		
		var lbl = Label.new()
		if listo:
			lbl.text = "OK! " + nom
			lbl.add_theme_color_override("font_color", esquema["text"])
		else:
			lbl.text = "" + nom
			lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		lbl.add_theme_font_size_override("font_size", 12)
		m.add_child(lbl)
		
		contenedor_jugadores.add_child(chip)

func _on_btn_tazuna_pulsado():
	if not bocadillo_tazuna: return
	bocadillo_tazuna.visible = !bocadillo_tazuna.visible
	if bocadillo_tazuna.visible:
		bocadillo_tazuna.scale = Vector2(0.3, 0.3)
		var tw = create_tween()
		tw.tween_property(bocadillo_tazuna, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_btn_directora_pulsado():
	if not bocadillo_directora: return
	bocadillo_directora.visible = !bocadillo_directora.visible
	if bocadillo_directora.visible:
		bocadillo_directora.scale = Vector2(0.3, 0.3)
		var tw = create_tween()
		tw.tween_property(bocadillo_directora, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func simular_confirmacion_bots_f6():
	await get_tree().create_timer(1.2).timeout
	for id in jugadores_info.keys():
		if id != id_local:
			jugadores_listos[id] = true
	actualizar_tarjetas_jugadores()

func es_anfitrion() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	if multiplayer.is_server() and not (OS.has_environment("GODOT_SERVER") or "--server" in OS.get_cmdline_args()):
		return true
	if get_tree().root.has_node("Lobby"):
		var lobby = get_tree().root.get_node("Lobby")
		if lobby.orden_jugadores.size() > 0 and lobby.orden_jugadores[0] == multiplayer.get_unique_id():
			return true
	return false

func _on_peer_desconectado_instrucciones(id_desconectado: int):
	if jugadores_info.has(id_desconectado):
		jugadores_info.erase(id_desconectado)
	if jugadores_listos.has(id_desconectado):
		jugadores_listos.erase(id_desconectado)
	actualizar_tarjetas_jugadores()
	if es_anfitrion() and not ya_iniciando:
		var todos_listos = true
		for id in jugadores_info.keys():
			var listo = jugadores_listos.get(id, jugadores_listos.get(int(id), jugadores_listos.get(str(id), false)))
			if not listo:
				todos_listos = false
				break
		if todos_listos and jugadores_info.size() > 0:
			ya_iniciando = true
			if multiplayer.has_multiplayer_peer():
				iniciar_transicion_partida_rpc.rpc()
			else:
				iniciar_transicion_partida_rpc()

func _on_btn_listo_pulsado():
	if listo_local or ya_iniciando: return
	listo_local = true
	
	if btn_listo:
		btn_listo.text = "¡CONFIRMADO!"
		btn_listo.disabled = true
		
	if multiplayer.has_multiplayer_peer():
		confirmar_listo_rpc.rpc(id_local)
	else:
		confirmar_listo_rpc(id_local)

@rpc("any_peer", "call_local", "reliable")
func confirmar_listo_rpc(id_jugador: int):
	jugadores_listos[id_jugador] = true
	actualizar_tarjetas_jugadores()
	
	if es_anfitrion():
		if not multiplayer.has_multiplayer_peer():
			for id in jugadores_info.keys():
				jugadores_listos[id] = true
			actualizar_tarjetas_jugadores()
			
		var todos_listos = true
		for id in jugadores_info.keys():
			var listo = jugadores_listos.get(id, jugadores_listos.get(int(id), jugadores_listos.get(str(id), false)))
			if not listo:
				todos_listos = false
				break
				
		if todos_listos and not ya_iniciando:
			ya_iniciando = true
			if multiplayer.has_multiplayer_peer():
				iniciar_transicion_partida_rpc.rpc()
			else:
				iniciar_transicion_partida_rpc()

@rpc("any_peer", "call_local", "reliable")
func iniciar_transicion_partida_rpc():
	ya_iniciando = true
	if banner_inicio:
		banner_inicio.visible = true
		banner_inicio.scale = Vector2(0.2, 0.2)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(banner_inicio, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	await get_tree().create_timer(0.8).timeout
	
	var tw_fade = create_tween()
	tw_fade.tween_property(self, "offset:y", -700.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw_fade.finished
	
	instrucciones_completadas.emit()
	queue_free()
