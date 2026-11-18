extends CanvasLayer

@onready var cuadrantes = $VistaLobby/ContenedorRanuras
@onready var btn_iniciar = $VistaLobby/BotonIniciar
@onready var edit_nombre = $MenuPrincipal/PanelCentral/VBox/EditNombre
@onready var input_ip = $MenuPrincipal/PanelCentral/VBox/IPInput
@onready var btn_host = $MenuPrincipal/PanelCentral/VBox/BotonHost
@onready var btn_unirse = $MenuPrincipal/PanelCentral/VBox/BotonUnirse
@onready var label_estado = $MenuPrincipal/PanelCentral/VBox.get_node_or_null("LabelEstado")
@onready var panel_minijuegos = $PanelMinijuegos
@onready var balcon_personajes = $PanelMinijuegos/BalconVisual/AvataresBalcon
@onready var grid_minijuegos = $PanelMinijuegos/PizarraMinijuegos/VBox/GridMinijuegos
@onready var bocadillo_titulo = $PanelMinijuegos/BocadilloTitulo
@onready var label_titulo_bocadillo = $PanelMinijuegos/BocadilloTitulo/Margen/LabelTitulo
@onready var btn_al_azar = $PanelMinijuegos/PizarraMinijuegos/VBox/Header/BtnAlAzar

const PORT = 8080

# URL del Servidor Central en Render
var url_servidor_render: String = "wss://uma-party.onrender.com"
var codigo_sala_local: String = ""

func obtener_puerto_servidor() -> int:
	if OS.has_environment("PORT"):
		var p_env = OS.get_environment("PORT").to_int()
		if p_env > 0:
			return p_env
	return PORT

func _generar_codigo_aleatorio() -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var res = ""
	for i in range(4):
		res += chars[randi() % chars.length()]
	return res
var peer: MultiplayerPeer = null
var es_modo_websocket: bool = true # Habilitado por defecto para permitir juego Web / Online
var jugadores_conectados = {} # {id: "nombre"}
var orden_jugadores: Array = []

var catalogo_juegos: Dictionary = {
	"BtnGarra": {
		"ruta": "res://escenas/minijuego_garra.tscn",
		"nombre": "La Garra de Premios",
		"modo": "1 vs 3"
	},
	"BtnCinta": {
		"ruta": "res://escenas/minijuego_plataformas.tscn",
		"nombre": "Caída de Plataformas",
		"modo": "FFA"
	},
	"BtnRuletaJuego": {
		"ruta": "res://escenas/minijuego_explosion.tscn",
		"nombre": "La Gran Explosión",
		"modo": "FFA"
	},
	"BtnCanones": {
		"ruta": "res://escenas/minijuego_canones.tscn",
		"nombre": "Cañones Giratorios",
		"modo": "FFA"
	},
	"BtnPista": {
		"ruta": "res://escenas/minijuego_pista.tscn",
		"nombre": "Caos en la Pista",
		"modo": "2 vs 2"
	},
	"BtnTemplo": {
		"ruta": "res://escenas/minijuego_templo.tscn",
		"nombre": "Templo Pinball",
		"modo": "FFA"
	},
	"BtnGlobos": {
		"ruta": "res://escenas/minijuego_globos.tscn",
		"nombre": "Globos Chocones",
		"modo": "2 vs 2"
	},
	"BtnJanken": {
		"ruta": "res://escenas/minijuego_janken.tscn",
		"nombre": "Duelo Jan-Ken-Pon",
		"modo": "2 vs 2"
	},
	"BtnTrivia": {
		"ruta": "res://escenas/minijuego_trivia.tscn",
		"nombre": "Trivia Show TV",
		"modo": "FFA"
	},
	"BtnAtrapaColas": {
		"ruta": "res://escenas/minijuego_atrapa_colas.tscn",
		"nombre": "Cacería de Colas",
		"modo": "1 vs 3"
	},
	"BtnCarritos": {
		"ruta": "res://escenas/minijuego_snowboard.tscn",
		"nombre": "Carrera de Trineos",
		"modo": "FFA"
	},
	"BtnLaberinto": {
		"ruta": "res://escenas/minijuego_laberinto.tscn",
		"nombre": "Laberinto de Setos",
		"modo": "FFA"
	},
	"BtnParaguas": {
		"ruta": "res://escenas/minijuego_paraguas.tscn",
		"nombre": "Vendaval de Kris S",
		"modo": "FFA"
	},
	"BtnCojines": {
		"ruta": "res://escenas/minijuego_cojines.tscn",
		"nombre": "Batalla de Cojines",
		"modo": "FFA"
	},
	"BtnMartillo": {
		"ruta": "res://escenas/minijuego_martillo.tscn",
		"nombre": "El Martillo de la Feria",
		"modo": "1 vs 3"
	},
	"BtnCanaduz": {
		"ruta": "res://escenas/minijuego_canaduz.tscn",
		"nombre": "Lanzador de Cañaduz",
		"modo": "1 vs 3"
	},
	"BtnRemo": {
		"ruta": "res://escenas/minijuego_remo.tscn",
		"nombre": "Remo Sincronizado",
		"modo": "2 vs 2"
	},
	"BtnDuelo": {
		"ruta": "res://escenas/minijuego_duelo.tscn",
		"nombre": "Duelo del Oeste",
		"modo": "FFA"
	},
	"BtnGuillotina": {
		"ruta": "res://escenas/minijuego_guillotina.tscn",
		"nombre": "Ruleta de Merengue",
		"modo": "FFA"
	}
}

func _ready():
	if has_node("/root/Global"):
		get_node("/root/Global").configurar_controles_tactiles(false, false)
	$MenuPrincipal/PanelCentral/VBox/BotonHost.pressed.connect(crear_servidor)
	$MenuPrincipal/PanelCentral/VBox/BotonUnirse.pressed.connect(unirse_partida)
	btn_iniciar.pressed.connect(_on_btn_iniciar_pressed)
	
	var btn_volver_menu = $MenuPrincipal/PanelCentral/VBox.get_node_or_null("BotonVolverMenu")
	if btn_volver_menu:
		btn_volver_menu.pressed.connect(_on_btn_volver_menu_pressed)
		
	var btn_salir_sala = $VistaLobby.get_node_or_null("BtnSalirSala")
	if btn_salir_sala:
		btn_salir_sala.pressed.connect(_on_btn_salir_sala_pressed)
		
	var btn_copiar_ip = $VistaLobby.get_node_or_null("PanelIPHost/BtnCopiarIP")
	if btn_copiar_ip:
		btn_copiar_ip.pressed.connect(_on_btn_copiar_ip_pressed)
	
	# Cargar datos persistentes
	if edit_nombre:
		edit_nombre.text = Global.nombre_jugador_local
	if input_ip:
		input_ip.text = Global.ultima_ip
	
	# Configurar opciones según la plataforma (Web vs PC/Móvil)
	if OS.has_feature("web"):
		es_modo_websocket = true
		if input_ip:
			input_ip.placeholder_text = "Código de Sala (ej: UMA4) o IP"
		# Auto-detección de sala por enlace URL (ej: ?sala=xxxx.trycloudflare.com)
		var param_url = JavaScriptBridge.eval("""
			(function() {
				var params = new URLSearchParams(window.location.search);
				return params.get("sala") || params.get("ip") || params.get("host") || "";
			})()
		""")
		if param_url != null and typeof(param_url) == TYPE_STRING:
			var sala_link = str(param_url).strip_edges()
			if sala_link != "":
				input_ip.text = sanitizar_url_sala(sala_link)
				mostrar_estado("Sala cargada automáticamente desde el enlace.", false)
	else:
		var ip_mi_dispositivo = Global.obtener_ip_local_recomendada()
		var label_sub = $MenuPrincipal/PanelCentral/VBox.get_node_or_null("LabelSubtitulo")
		if label_sub:
			label_sub.text = "Lobby Multijugador • Tu IP: %s" % ip_mi_dispositivo
		if input_ip and input_ip.text == "127.0.0.1":
			input_ip.text = ""
			input_ip.placeholder_text = "Código (ej: UMA4) o IP"
			
		var btn_proto = Button.new()
		btn_proto.name = "BtnProtocoloRed"
		btn_proto.custom_minimum_size = Vector2(0, 36)
		btn_proto.text = "Modo Red: Web & Online (WebSocket) 🌐"
		btn_proto.add_theme_font_size_override("font_size", 13)
		btn_proto.pressed.connect(_on_btn_protocolo_pressed)
		if btn_host and btn_host.get_parent():
			var idx = btn_host.get_index()
			btn_host.get_parent().add_child(btn_proto)
			btn_host.get_parent().move_child(btn_proto, idx)
			
	# Botón Pegar URL / IP (permite pegar cómodamente en Web y móviles donde Ctrl+V está restringido)
	var btn_pegar = Button.new()
	btn_pegar.name = "BtnPegarIP"
	btn_pegar.custom_minimum_size = Vector2(0, 36)
	btn_pegar.text = "📋 Pegar Dirección / URL de Sala"
	btn_pegar.add_theme_font_size_override("font_size", 14)
	btn_pegar.pressed.connect(_on_btn_pegar_ip_pressed)
	if input_ip and input_ip.get_parent():
		var idx_ip = input_ip.get_index() + 1
		input_ip.get_parent().add_child(btn_pegar)
		input_ip.get_parent().move_child(btn_pegar, idx_ip)
	
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	btn_iniciar.visible = false
	panel_minijuegos.visible = false
	$VistaLobby.visible = false
	$MenuPrincipal.visible = true
	
	if "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args() or OS.has_environment("GODOT_SERVER"):
		print("[SERVER] Modo servidor detectado por argumento CLI / Variable de entorno.")
		call_deferred("crear_servidor")
	
	# Conexión de los botones de la bandeja inferior de personajes (Roster)
	var roster = $VistaLobby/BandejaRoster/Margen/HBoxRoster
	if roster:
		if roster.has_node("BtnRandom"):
			roster.get_node("BtnRandom").pressed.connect(_on_roster_random_pressed)
		var char_buttons = [
			["BtnSeiun", 0], ["BtnGold", 1], ["BtnOguri", 2], ["BtnStill", 3], ["BtnCafe", 4],
			["BtnAgnes", 5], ["BtnDantsu", 6], ["BtnJungle", 7], ["BtnSamson", 8], ["BtnSpecial", 9]
		]
		for cb in char_buttons:
			if roster.has_node(cb[0]):
				roster.get_node(cb[0]).pressed.connect(_on_roster_char_pressed.bind(cb[1]))
		
		# Asignar los iconos recortados con bordes circulares a los botones del roster inferior
		var char_prefijos = [
			["BtnSeiun", "SEIK"], ["BtnGold", "GLSH"], ["BtnOguri", "OGRC"], ["BtnStill", "STIL"], ["BtnCafe", "MACA"],
			["BtnAgnes", "AGTC"], ["BtnDantsu", "DAFL"], ["BtnJungle", "JUPC"], ["BtnSamson", "SABG"], ["BtnSpecial", "SPWE"]
		]
		for cp in char_prefijos:
			var btn = roster.get_node_or_null(cp[0])
			if btn:
				var spr = btn.get_node_or_null("Sprite")
				if spr: spr.visible = false
				var ruta_icon = "res://assets/Sprites/iconos_personajes/icono_" + cp[1] + ".png"
				if ResourceLoader.exists(ruta_icon):
					btn.icon = load(ruta_icon)
					btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
					btn.expand_icon = true
		
	# Conexión de las tarjetas de minijuegos (Grid estilo Mario Party)
	configurar_grid_minijuegos()
					
	# Botón de ruleta aleatoria en la pizarra
	if btn_al_azar:
		btn_al_azar.pressed.connect(_on_btn_ruleta_aleatoria_pressed)
		
	# Botón para volver de la pizarra al lobby
	var btn_volver_lobby = $PanelMinijuegos/BtnVolverLobby
	if btn_volver_lobby:
		btn_volver_lobby.pressed.connect(_on_btn_volver_lobby_pressed)
		
	if OS.has_environment("TEST_LOBBY_CAPTURE"):
		_run_test_lobby_capture()

func _run_test_lobby_capture():
	await get_tree().create_timer(0.3).timeout
	var art_dir = "C:/Users/User/.gemini/antigravity/brain/686f75d0-0f1f-4edc-80cc-f70e68f92af3/"
	
	crear_servidor()
	await get_tree().create_timer(0.3).timeout
	_on_roster_char_pressed(5) # Agnes Tachyon
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(art_dir + "preview_lobby_sala_10chars.png")
	
	_on_btn_iniciar_pressed()
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(art_dir + "preview_lobby_minijuegos_board.png")
	get_tree().quit()

# --- SELECCIÓN DESDE EL ROSTER INFERIOR ---

func _on_roster_char_pressed(idx: int):
	var mi_id = multiplayer.get_unique_id()
	var mi_cuadro = cuadrantes.get_node_or_null(str(mi_id))
	if mi_cuadro and mi_cuadro.has_method("seleccionar_indice"):
		mi_cuadro.seleccionar_indice(idx)

func _on_roster_random_pressed():
	var idx_aleatorio = randi() % 10
	_on_roster_char_pressed(idx_aleatorio)

# --- CONEXIÓN Y SERVIDOR ---

var temporizador_conexion: SceneTreeTimer = null

func mostrar_estado(texto: String, es_error: bool = false):
	if label_estado:
		label_estado.text = texto
		label_estado.visible = true
		if es_error:
			label_estado.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		else:
			label_estado.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))

func limpiar_estado():
	if label_estado:
		label_estado.text = ""
		label_estado.visible = false

func _on_btn_protocolo_pressed():
	es_modo_websocket = not es_modo_websocket
	var btn = $MenuPrincipal/PanelCentral/VBox.get_node_or_null("BtnProtocoloRed")
	if btn:
		if es_modo_websocket:
			btn.text = "Modo Red: Web & Online (WebSocket) 🌐"
		else:
			btn.text = "Modo Red: LAN Directo (ENet UDP) ⚡"

func sanitizar_url_sala(texto: String) -> String:
	var s = texto.strip_edges()
	if "sala=" in s:
		s = s.substr(s.find("sala=") + 5)
		if "&" in s:
			s = s.substr(0, s.find("&"))
	if s.begins_with("https://"):
		s = s.trim_prefix("https://")
	elif s.begins_with("http://"):
		s = s.trim_prefix("http://")
	elif s.begins_with("wss://"):
		s = s.trim_prefix("wss://")
	elif s.begins_with("ws://"):
		s = s.trim_prefix("ws://")
	s = s.trim_suffix("/")
	return s.strip_edges()

func _on_btn_pegar_ip_pressed():
	limpiar_estado()
	if OS.has_feature("web"):
		var js_code = """
			(function() {
				window._godot_clipboard_val = "";
				if (navigator.clipboard && navigator.clipboard.readText) {
					navigator.clipboard.readText().then(function(clipText) {
						if (clipText && clipText.trim()) {
							window._godot_clipboard_val = clipText.trim();
						}
					}).catch(function(e) {
						var p = window.prompt("Pega aquí la URL o enlace de la sala:", "");
						window._godot_clipboard_val = p ? p.trim() : "";
					});
				} else {
					var p = window.prompt("Pega aquí la URL o enlace de la sala:", "");
					window._godot_clipboard_val = p ? p.trim() : "";
				}
			})()
		"""
		JavaScriptBridge.eval(js_code)
		await get_tree().create_timer(0.2).timeout
		var val = JavaScriptBridge.eval("window._godot_clipboard_val || '';")
		if val != null and typeof(val) == TYPE_STRING and str(val).strip_edges() != "":
			input_ip.text = sanitizar_url_sala(str(val))
			mostrar_estado("¡Dirección pegada con éxito!", false)
		else:
			mostrar_estado("Toca la caja de texto para escribir o pegar.", false)
	else:
		var clip = DisplayServer.clipboard_get()
		if clip != null and clip.strip_edges() != "":
			input_ip.text = sanitizar_url_sala(clip)
			mostrar_estado("¡Dirección pegada con éxito!", false)
		else:
			mostrar_estado("El portapapeles está vacío.", true)

func crear_servidor():
	limpiar_estado()
	var mp = get_tree().get_multiplayer() if get_tree() else null
	if mp and mp.multiplayer_peer:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
		
	if OS.has_feature("web"):
		# En Web nos conectamos al servidor central de Render como creador de sala
		if codigo_sala_local == "":
			codigo_sala_local = _generar_codigo_aleatorio()
		unirse_partida()
		return
		
	if codigo_sala_local == "":
		codigo_sala_local = _generar_codigo_aleatorio()
		
	var error = OK
	var puerto = obtener_puerto_servidor()
	if es_modo_websocket:
		var ws_peer = WebSocketMultiplayerPeer.new()
		ws_peer.inbound_buffer_size = 2097152
		ws_peer.outbound_buffer_size = 2097152
		ws_peer.max_queued_packets = 8192
		ws_peer.encode_buffer_max_size = 2097152
		error = ws_peer.create_server(puerto)
		peer = ws_peer
		if error == OK:
			print("[SERVER] ¡Servidor WebSocket iniciado exitosamente en puerto %d! Sala inicial: %s" % [puerto, codigo_sala_local])
	else:
		var enet_peer = ENetMultiplayerPeer.new()
		error = enet_peer.create_server(puerto, 4)
		peer = enet_peer
		
	if error != OK:
		print("Error al crear servidor: ", error)
		mostrar_estado("Error al abrir puerto %d (%s) (Código: %d).\nVerifica si el puerto está en uso o permisos del firewall." % [puerto, "WebSocket" if es_modo_websocket else "ENet", error], true)
		return
		
	multiplayer.multiplayer_peer = peer
	$MenuPrincipal.hide()
	$VistaLobby.show()
	
	var es_dedicado = OS.has_environment("GODOT_SERVER") or "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args()
	if es_dedicado:
		orden_jugadores = []
		jugadores_conectados = {}
		print("[SERVER] Servidor dedicado iniciado. Esperando jugadores (máx 4)...")
	else:
		var mi_nombre = edit_nombre.text.strip_edges()
		if mi_nombre == "": mi_nombre = "Host"
		Global.nombre_jugador_local = mi_nombre
		Global.guardar_configuracion()
		
		orden_jugadores = [1]
		jugadores_conectados = {1: mi_nombre}
		sincronizar_lobby_rpc(orden_jugadores, jugadores_conectados)
		btn_iniciar.visible = true
		actualizar_panel_ip_host()

func unirse_partida():
	limpiar_estado()
	var texto_entrada = sanitizar_url_sala(input_ip.text)
	var ip_destino = texto_entrada
	
	# Si no contiene puntos, dos puntos ni barras y no está vacío, es un código de sala
	if texto_entrada != "" and not ("." in texto_entrada or ":" in texto_entrada or "/" in texto_entrada or texto_entrada.to_lower().begins_with("localhost")):
		codigo_sala_local = texto_entrada.to_upper()
		ip_destino = url_servidor_render
		print("[LOBBY] Código de sala ingresado: ", codigo_sala_local, " -> Servidor: ", ip_destino)
	elif ip_destino == "" or (OS.has_feature("web") and (ip_destino == "127.0.0.1" or ip_destino == "localhost")):
		ip_destino = url_servidor_render
		
	var mp = get_tree().get_multiplayer() if get_tree() else null
	if mp and mp.multiplayer_peer:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
		
	var es_ws = false
	if OS.has_feature("web") or ip_destino.begins_with("ws://") or ip_destino.begins_with("wss://") or ip_destino.contains("trycloudflare.com") or ip_destino.contains("ngrok") or es_modo_websocket:
		es_ws = true
		
	var error = OK
	var target_display = ip_destino
	
	if es_ws:
		var ws_peer = WebSocketMultiplayerPeer.new()
		ws_peer.inbound_buffer_size = 2097152
		ws_peer.outbound_buffer_size = 2097152
		ws_peer.max_queued_packets = 8192
		ws_peer.encode_buffer_max_size = 2097152
		var ws_url = ip_destino
		# Limpieza de prefijos comunes y barras finales al pegar URLs
		if ws_url.begins_with("https://"):
			ws_url = "wss://" + ws_url.trim_prefix("https://")
		elif ws_url.begins_with("http://"):
			ws_url = "ws://" + ws_url.trim_prefix("http://")
		ws_url = ws_url.trim_suffix("/")
		
		if not (ws_url.begins_with("ws://") or ws_url.begins_with("wss://")):
			if ws_url.contains("trycloudflare.com") or ws_url.contains("ngrok") or (OS.has_feature("web") and not (ws_url.begins_with("127.0.0.1") or ws_url.begins_with("localhost"))):
				ws_url = "wss://" + ws_url
			elif ws_url.begins_with("127.0.0.1") or ws_url.begins_with("localhost") or ws_url.begins_with("192.168."):
				if not ":" in ws_url:
					ws_url = "ws://" + ws_url + ":" + str(PORT)
				else:
					ws_url = "ws://" + ws_url
			else:
				ws_url = "wss://" + ws_url
				
		error = ws_peer.create_client(ws_url)
		peer = ws_peer
		target_display = ws_url
	else:
		var enet_peer = ENetMultiplayerPeer.new()
		error = enet_peer.create_client(ip_destino, PORT)
		peer = enet_peer
		target_display = "%s:%d" % [ip_destino, PORT]
		
	if error != OK:
		print("Error al conectar: ", error)
		mostrar_estado("Error al iniciar cliente hacia %s (Código: %d)" % [target_display, error], true)
		return
		
	var mi_nombre = edit_nombre.text.strip_edges()
	if mi_nombre == "": mi_nombre = "Invitado"
	Global.nombre_jugador_local = mi_nombre
	Global.ultima_ip = ip_destino
	Global.guardar_configuracion()
	
	multiplayer.multiplayer_peer = peer
	
	# Estado conectando
	mostrar_estado("Conectando con la sala en %s..." % target_display, false)
	if btn_unirse: btn_unirse.disabled = true
	if btn_host: btn_host.disabled = true
	
	# Timeout de 10 segundos
	temporizador_conexion = get_tree().create_timer(10.0)
	temporizador_conexion.timeout.connect(_on_connection_timeout)

func _on_connection_timeout():
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		_on_connection_failed()

func actualizar_panel_ip_host():
	var panel_ip = $VistaLobby.get_node_or_null("PanelIPHost")
	if not panel_ip: return
	panel_ip.visible = true
	var label_ip = panel_ip.get_node_or_null("BadgeIP/MarginIP/LabelIP")
	if label_ip:
		if codigo_sala_local != "":
			label_ip.text = "CÓDIGO DE SALA: %s" % codigo_sala_local
		else:
			var ip_local = Global.obtener_ip_local_recomendada()
			var tipo = "WebSocket" if es_modo_websocket else "ENet"
			var puerto = obtener_puerto_servidor()
			label_ip.text = "IP: %s (%s :%d)" % [ip_local, tipo, puerto]

func _on_btn_copiar_ip_pressed():
	var texto = codigo_sala_local if codigo_sala_local != "" else Global.obtener_ip_local_recomendada()
	DisplayServer.clipboard_set(texto)
	var btn = $VistaLobby.get_node_or_null("PanelIPHost/BtnCopiarIP")
	if btn:
		btn.text = "¡Copiado! ✓"
		await get_tree().create_timer(1.8).timeout
		if is_instance_valid(btn):
			btn.text = "Copiar 📋"

func _on_btn_volver_menu_pressed():
	var mp = get_tree().get_multiplayer() if get_tree() else null
	if mp and mp.multiplayer_peer:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
	get_tree().change_scene_to_file("res://escenas/menu_principal.tscn")

func _on_btn_salir_sala_pressed():
	if btn_unirse: btn_unirse.disabled = false
	if btn_host: btn_host.disabled = false
	limpiar_estado()
	var mp = get_tree().get_multiplayer() if get_tree() else null
	if mp and mp.multiplayer_peer:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
	orden_jugadores.clear()
	jugadores_conectados.clear()
	for cuadro in cuadrantes.get_children():
		cuadro.queue_free()
	$VistaLobby.hide()
	panel_minijuegos.hide()
	$MenuPrincipal.show()

func _on_connection_failed():
	if btn_unirse: btn_unirse.disabled = false
	if btn_host: btn_host.disabled = false
	var mp = get_tree().get_multiplayer() if get_tree() else null
	if mp and mp.multiplayer_peer:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
	orden_jugadores.clear()
	jugadores_conectados.clear()
	mostrar_estado("No se pudo conectar al Host en %s.\nVerifica que la IP sea correcta y que ambos equipos estén en la misma red." % input_ip.text.strip_edges(), true)
	$VistaLobby.hide()
	$MenuPrincipal.show()

func _on_server_disconnected():
	if btn_unirse: btn_unirse.disabled = false
	if btn_host: btn_host.disabled = false
	var mp = get_tree().get_multiplayer() if get_tree() else null
	if mp and mp.multiplayer_peer:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
	orden_jugadores.clear()
	jugadores_conectados.clear()
	for cuadro in cuadrantes.get_children():
		cuadro.queue_free()
	mostrar_estado("El Host cerró la sala.", true)
	$VistaLobby.hide()
	panel_minijuegos.hide()
	$MenuPrincipal.show()

func _on_connected_ok():
	limpiar_estado()
	if btn_unirse: btn_unirse.disabled = false
	if btn_host: btn_host.disabled = false
	$MenuPrincipal.hide()
	$VistaLobby.show()
	actualizar_panel_ip_host()
	
	var mi_id = multiplayer.get_unique_id()
	var mi_nombre = edit_nombre.text.strip_edges()
	if mi_nombre == "": mi_nombre = "Invitado"
	pedir_registro_al_servidor.rpc_id(1, mi_id, mi_nombre, codigo_sala_local)

@rpc("any_peer", "reliable")
func pedir_registro_al_servidor(id, nombre_enviado, codigo_solicitado: String = ""):
	if multiplayer.is_server():
		var es_dedicado = OS.has_environment("GODOT_SERVER") or "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args()
		if es_dedicado and orden_jugadores.is_empty():
			if codigo_solicitado != "":
				codigo_sala_local = codigo_solicitado
		
		if not orden_jugadores.has(id):
			if orden_jugadores.size() >= 4:
				print("[SERVER] Sala llena (máx 4 jugadores). Rechazando ID: ", id)
				return
			orden_jugadores.append(id)
			
		jugadores_conectados[id] = nombre_enviado
		sincronizar_lobby_rpc.rpc(orden_jugadores, jugadores_conectados, codigo_sala_local)

func _on_player_connected(_id):
	pass

func _on_player_disconnected(id):
	if multiplayer.is_server():
		orden_jugadores.erase(id)
		jugadores_conectados.erase(id)
		if orden_jugadores.is_empty():
			var es_dedicado = OS.has_environment("GODOT_SERVER") or "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args()
			if es_dedicado:
				codigo_sala_local = _generar_codigo_aleatorio()
				print("[SERVER] Todos los jugadores salieron. Sala reseteada. Nuevo código: ", codigo_sala_local)
		else:
			sincronizar_lobby_rpc.rpc(orden_jugadores, jugadores_conectados, codigo_sala_local)

@rpc("authority", "call_local", "reliable")
func sincronizar_lobby_rpc(orden: Array, nombres: Dictionary, codigo_asignado: String = ""):
	orden_jugadores = orden
	jugadores_conectados = nombres
	if codigo_asignado != "":
		codigo_sala_local = codigo_asignado
	actualizar_panel_ip_host()
	
	# 1. Eliminar cuadros locales de jugadores desconectados
	for cuadro in cuadrantes.get_children():
		var id = int(cuadro.name)
		if not orden.has(id):
			cuadro.queue_free()
			
	# 2. Asegurar que los cuadros existan, estén en orden estricto y con su slot correcto
	for i in range(orden.size()):
		var id = orden[i]
		var nombre_u = nombres.get(id, "Jugador " + str(id))
		var cuadro = cuadrantes.get_node_or_null(str(id))
		
		if not cuadro:
			cuadro = preload("res://escenas/cuadro_jugador.tscn").instantiate()
			cuadro.name = str(id)
			cuadrantes.add_child(cuadro)
			cuadro.activar_si_es_mio()
			
		# Colocar el nodo en el índice exacto de la lista de hijos (para el layout horizontal)
		cuadrantes.move_child(cuadro, i)
		
		# Configurar explícitamente el slot (1, 2, 3, 4) según el orden del servidor
		if cuadro.has_method("configurar_slot"):
			cuadro.configurar_slot(i + 1)
			
		if cuadro.has_method("set_nombre_usuario"):
			cuadro.set_nombre_usuario(nombre_u)
			
	var es_lider = false
	if multiplayer.is_server() and not OS.has_environment("GODOT_SERVER"):
		es_lider = true
	elif orden.size() > 0 and orden[0] == multiplayer.get_unique_id():
		es_lider = true
		
	btn_iniciar.visible = es_lider

# --- BOTÓN INICIAR / ABRIR MINIJUEGOS ---

var en_ruleta: bool = false

func configurar_grid_minijuegos():
	if not grid_minijuegos: return
	
	for clave in catalogo_juegos.keys():
		var btn = grid_minijuegos.get_node_or_null(clave)
		if not btn:
			# Si no existe botón con esa clave, reutilizar el primer Q disponible del grid
			for q_idx in range(10, 40):
				var q_nodo = grid_minijuegos.get_node_or_null("Q" + str(q_idx))
				if q_nodo:
					var nuevo_btn = Button.new()
					nuevo_btn.name = clave
					nuevo_btn.custom_minimum_size = Vector2(100, 64)
					nuevo_btn.text = catalogo_juegos[clave]["nombre"]
					nuevo_btn.add_theme_font_size_override("font_size", 9)
					nuevo_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					
					var pos_idx = q_nodo.get_index()
					q_nodo.queue_free()
					grid_minijuegos.add_child(nuevo_btn)
					grid_minijuegos.move_child(nuevo_btn, pos_idx)
					btn = nuevo_btn
					break
					
		if btn and btn is Button:
			btn.pressed.connect(_on_card_minijuego_selected.bind(catalogo_juegos[clave]["ruta"]))
			btn.mouse_entered.connect(_on_tile_hovered.bind(btn, catalogo_juegos[clave]["nombre"]))
			btn.focus_entered.connect(_on_tile_hovered.bind(btn, catalogo_juegos[clave]["nombre"]))

	# Conectar también los cuadros de misterio si se desean mostrar como "???"
	for hijo in grid_minijuegos.get_children():
		if hijo is PanelContainer:
			hijo.mouse_entered.connect(_on_mystery_tile_hovered.bind(hijo))

func _on_tile_hovered(tile: Control, nombre_juego: String):
	if not bocadillo_titulo or not label_titulo_bocadillo: return
	label_titulo_bocadillo.text = nombre_juego
	bocadillo_titulo.visible = true
	# Posicionar el bocadillo debajo del tile centrado
	var pos_x = tile.global_position.x + (tile.size.x * 0.5) - (bocadillo_titulo.size.x * 0.5)
	var pos_y = tile.global_position.y + tile.size.y + 6.0
	if pos_y + bocadillo_titulo.size.y > 510.0:
		pos_y = tile.global_position.y - bocadillo_titulo.size.y - 6.0
	bocadillo_titulo.global_position = Vector2(clamp(pos_x, 20.0, 1152.0 - bocadillo_titulo.size.x - 20.0), pos_y)

func _on_mystery_tile_hovered(tile: Control):
	if not bocadillo_titulo or not label_titulo_bocadillo: return
	label_titulo_bocadillo.text = "???"
	bocadillo_titulo.visible = true
	var pos_x = tile.global_position.x + (tile.size.x * 0.5) - (bocadillo_titulo.size.x * 0.5)
	var pos_y = tile.global_position.y + tile.size.y + 6.0
	if pos_y + bocadillo_titulo.size.y > 510.0:
		pos_y = tile.global_position.y - bocadillo_titulo.size.y - 6.0
	bocadillo_titulo.global_position = Vector2(clamp(pos_x, 20.0, 1152.0 - bocadillo_titulo.size.x - 20.0), pos_y)

func es_anfitrion() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	if multiplayer.is_server() and not (OS.has_environment("GODOT_SERVER") or "--server" in OS.get_cmdline_args()):
		return true
	if orden_jugadores.size() > 0 and orden_jugadores[0] == multiplayer.get_unique_id():
		return true
	return false

func obtener_id_anfitrion() -> int:
	if orden_jugadores.size() > 0:
		return int(orden_jugadores[0])
	return 1

func _on_btn_iniciar_pressed():
	if not es_anfitrion(): return
	
	var cuadros = cuadrantes.get_children()
	if cuadros.is_empty(): return
	
	var todos_listos = true
	for cuadro in cuadros:
		if cuadro.has_method("esta_listo_para_jugar") and not cuadro.esta_listo_para_jugar():
			todos_listos = false
			break
			
	if todos_listos or cuadros.size() == 1:
		abrir_pantalla_minijuegos_rpc.rpc()
	else:
		var texto_orig = btn_iniciar.text
		btn_iniciar.text = "¡FALTA QUE TODOS DEN LISTO!"
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(btn_iniciar):
			btn_iniciar.text = texto_orig

@rpc("any_peer", "reliable")
func solicitar_abrir_minijuegos_al_servidor():
	abrir_pantalla_minijuegos_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func abrir_pantalla_minijuegos_rpc():
	en_ruleta = false
	$VistaLobby.hide()
	panel_minijuegos.show()
	actualizar_balcon_personajes()
	
	# Seleccionar y mostrar el primer minijuego por defecto
	var btn_inicial = grid_minijuegos.get_node_or_null("BtnGarra")
	if btn_inicial:
		btn_inicial.grab_focus()
		_on_tile_hovered(btn_inicial, catalogo_juegos["BtnGarra"]["nombre"])

func actualizar_balcon_personajes():
	if not balcon_personajes: return
	var avatares = balcon_personajes.get_children()
	var cuadros = cuadrantes.get_children()
	
	for i in range(avatares.size()):
		var sprite_balcon = avatares[i]
		if i < cuadros.size():
			var cuadro = cuadros[i]
			var idx_char = cuadro.indice_actual
			var prefijos = {
				0: "SEIK", 1: "GLSH", 2: "OGRC", 3: "STIL", 4: "MACA",
				5: "AGTC", 6: "DAFL", 7: "JUPC", 8: "SABG", 9: "SPWE"
			}
			var prefijo = prefijos.get(idx_char, "SEIK")
			var anim = prefijo + "_idle"
			sprite_balcon.visible = true
			if sprite_balcon.sprite_frames.has_animation(anim):
				sprite_balcon.play(anim)
		else:
			sprite_balcon.visible = false

func _on_btn_volver_lobby_pressed():
	cerrar_pantalla_minijuegos_rpc.rpc()

@rpc("any_peer", "reliable")
func solicitar_cerrar_pantalla_minijuegos_rpc():
	cerrar_pantalla_minijuegos_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func cerrar_pantalla_minijuegos_rpc():
	en_ruleta = false
	panel_minijuegos.hide()
	$VistaLobby.show()

# --- SELECCIÓN Y LANZAMIENTO DE MINIJUEGOS ---

func _on_card_minijuego_selected(ruta_mapa: String):
	if en_ruleta: return
	if not es_anfitrion():
		print("[LOBBY] Solo el Host de la sala puede elegir minijuego.")
		return
	lanzar_minijuego_como_anfitrion(ruta_mapa)

@rpc("any_peer", "reliable")
func solicitar_iniciar_mapa_rpc(ruta_mapa: String):
	lanzar_minijuego_como_anfitrion(ruta_mapa)

func lanzar_minijuego_como_anfitrion(ruta: String):
	print("[LOBBY] Anfitrión lanzando minijuego: ", ruta)
	var ids_jugadores = orden_jugadores.duplicate()
	if ids_jugadores.is_empty():
		ids_jugadores = [multiplayer.get_unique_id()]
		
	var info_partida = {}
	var ids_mezclados = ids_jugadores.duplicate()
	ids_mezclados.shuffle()
	for i in range(ids_mezclados.size()):
		var id_p = ids_mezclados[i]
		var nom_p = jugadores_conectados.get(int(id_p), jugadores_conectados.get(str(id_p), "Jugador %s" % str(id_p)))
		info_partida[id_p] = {"equipo": i, "spawn": i, "es_jefe": (i == 0), "nombre": nom_p}
		
	iniciar_mapa_rpc.rpc(ruta, info_partida)

func servidor_iniciar_minijuego(ruta: String):
	lanzar_minijuego_como_anfitrion(ruta)

func _on_btn_ruleta_aleatoria_pressed():
	if en_ruleta: return
	if not es_anfitrion():
		print("[LOBBY] Solo el Host de la sala puede girar la ruleta.")
		return
	var claves = catalogo_juegos.keys()
	var clave_elegida = claves[randi() % claves.size()]
	ejecutar_animacion_ruleta.rpc(clave_elegida)

@rpc("any_peer", "reliable")
func solicitar_ruleta_rpc():
	if not en_ruleta:
		var claves = catalogo_juegos.keys()
		var clave_elegida = claves[randi() % claves.size()]
		ejecutar_animacion_ruleta.rpc(clave_elegida)

@rpc("any_peer", "call_local", "reliable")
func ejecutar_animacion_ruleta(clave_final: String):
	en_ruleta = true
	if btn_al_azar:
		btn_al_azar.disabled = true
	
	var claves = catalogo_juegos.keys()
	var total_pasos = 14 + (randi() % 4)
	var paso_actual = 0
	var espera = 0.06
	
	for i in range(total_pasos):
		var clave_actual = claves[paso_actual % claves.size()]
		var btn = grid_minijuegos.get_node_or_null(clave_actual)
		if btn:
			btn.grab_focus()
			_on_tile_hovered(btn, catalogo_juegos[clave_actual]["nombre"])
		paso_actual += 1
		await get_tree().create_timer(espera).timeout
		espera += 0.015
	
	# Destacar el seleccionado definitivo
	var btn_final = grid_minijuegos.get_node_or_null(clave_final)
	if btn_final:
		btn_final.grab_focus()
		_on_tile_hovered(btn_final, catalogo_juegos[clave_final]["nombre"])
		
	await get_tree().create_timer(0.9).timeout
	en_ruleta = false
	if btn_al_azar:
		btn_al_azar.disabled = false
		
	if es_anfitrion():
		lanzar_minijuego_como_anfitrion(catalogo_juegos[clave_final]["ruta"])

@rpc("any_peer", "call_local", "reliable")
func iniciar_mapa_rpc(ruta: String, dict_info: Dictionary = {}):
	if OS.has_environment("GODOT_SERVER") or "--server" in OS.get_cmdline_args():
		return
		
	$VistaLobby.hide()
	panel_minijuegos.hide()
	$MenuPrincipal.hide()
	
	var mapa = get_tree().root.get_node_or_null("MapaActual")
	if mapa:
		mapa.name = "MapaAnterior_Free"
		mapa.queue_free()
		
	mapa = load(ruta).instantiate()
	mapa.name = "MapaActual"
	get_tree().root.add_child(mapa)
	
	mapa.set_multiplayer_authority(obtener_id_anfitrion(), true)
	
	# Crear y configurar los avatares en el mapa
	ejecutar_spawns_en_mapa(dict_info)
	
	# Inicializar roles y pantalla de instrucciones
	if mapa.has_method("solicitar_spawns_a_todos"):
		mapa.solicitar_spawns_a_todos(dict_info)
	elif mapa.has_method("aplicar_roles_locales"):
		mapa.jugadores_info = dict_info
		mapa.aplicar_roles_locales()

func ejecutar_spawns_en_mapa(dict_info):
	var mapa = get_tree().root.get_node_or_null("MapaActual")
	if not mapa: return
	
	for id in dict_info.keys():
		var datos = dict_info[id]
		if mapa.has_node(str(id)): continue
			
		var avatar = preload("res://escenas/personaje_jugable.tscn").instantiate()
		avatar.name = str(id)
		mapa.add_child(avatar)
		
		# Buscar punto de spawn por nombre "0", "1", o por índice de hijo en Spawns
		var punto_spawn = mapa.get_node_or_null("Spawns/" + str(datos.spawn))
		if not punto_spawn and mapa.has_node("Spawns"):
			var contenedor_spawns = mapa.get_node("Spawns")
			if datos.spawn >= 0 and datos.spawn < contenedor_spawns.get_child_count():
				punto_spawn = contenedor_spawns.get_child(datos.spawn)
		if punto_spawn:
			avatar.global_position = punto_spawn.global_position
		
		if cuadrantes.has_node(str(id)):
			var cuadro = cuadrantes.get_node(str(id))
			avatar.configurar_visual(cuadro.indice_actual, cuadro.label_usuario.text)
		else:
			var nombre_fall = jugadores_conectados.get(int(id), jugadores_conectados.get(str(id), "Jugador %s" % str(id)))
			avatar.configurar_visual(0, nombre_fall)

@rpc("any_peer", "call_local", "reliable")
func regresar_al_lobby_rpc():
	Global.configurar_controles_tactiles(false, false)
	var mapa = get_tree().root.get_node_or_null("MapaActual")
	if mapa:
		mapa.queue_free()
		
	# Limpieza de seguridad por si algún avatar quedó en la raíz o en el lobby
	for hijo in get_tree().root.get_children():
		if hijo != self and (hijo.has_method("configurar_visual") or hijo.has_method("activar_modo_globo")):
			hijo.queue_free()
	for hijo in get_children():
		if hijo.has_method("configurar_visual") or hijo.has_method("activar_modo_globo"):
			hijo.queue_free()

	$VistaLobby.show()
	$MenuPrincipal.hide()
	panel_minijuegos.hide()
	
	# Resetear estado de confirmación ("LISTO") de los cuadros para la siguiente partida
	for cuadro in cuadrantes.get_children():
		if cuadro.has_method("confirmar_personaje_rpc"):
			cuadro.esta_confirmado = false
			if cuadro.badge_listo:
				cuadro.badge_listo.visible = false
			if cuadro.btn_confirmar and cuadro.is_multiplayer_authority():
				cuadro.btn_confirmar.text = "¡LISTO!"
				if cuadro.btn_derecha: cuadro.btn_derecha.visible = true
				if cuadro.btn_izquierda: cuadro.btn_izquierda.visible = true
			cuadro.actualizar_vista()
			
	var es_lider = false
	if multiplayer.is_server() and not OS.has_environment("GODOT_SERVER"):
		es_lider = true
	elif orden_jugadores.size() > 0 and orden_jugadores[0] == multiplayer.get_unique_id():
		es_lider = true
	btn_iniciar.visible = es_lider
