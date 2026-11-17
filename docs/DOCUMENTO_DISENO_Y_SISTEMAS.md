================================================================================
DOCUMENTO MAESTRO DE DISEÑO, SISTEMAS Y CONOCIMIENTO: UMAMUSUME PARTY (UMA PARTY)
================================================================================
Versión del Proyecto: 1.0 Stable Build
Motor de Desarrollo: Godot Engine 4.4 / 4.7.2 (Forward+ y GL Compatibility WebGL2)
Género: Slapstick Party Game / Minijuegos Multijugador estilo Mario Party
Público Objetivo: Competencia local festiva entre 1 y 4 jugadores simultáneos

--------------------------------------------------------------------------------
1. CONCEPTO Y FILOSOFÍA CENTRAL DE JUEGO (GAME DESIGN)
--------------------------------------------------------------------------------
Umamusume: Party Dash es un videojuego de minijuegos para fiestas inspirado en el
universo deportivo de Umamusume: Pretty Derby. Traslada las rivalidades de las chicas
caballo de la Academia Tracen a pruebas de habilidad, reflejos y slapstick cómico.

REGLA DE ORO DE EQUIDAD (FILOSOFÍA MARIO PARTY):
- La elección de personaje es 100% COSMÉTICA y VISUAL. Ninguna corredora tiene ventaja
  estadística, mayor velocidad, peso extra o saltos diferentes.
- Todas las corredoras comparten exactamente las mismas físicas:
  * Velocidad de caminata base: 350 píxeles por segundo.
  * Velocidad de sprint rápido: 750 píxeles por segundo.
  * Hitboxes y cajas de colisión idénticas.
- El set de controles y movimientos depende EXCLUSIVAMENTE del minijuego que se esté
  jugando (controlado por el enum TipoMovimiento en personaje_jugable.gd).
- Esto garantiza que la victoria sea mérito exclusivo de la pericia, tiempo de reacción
  y psicología de cada jugador.

--------------------------------------------------------------------------------
2. PLANTILLA COMPLETA DE PERSONAJES JUGABLES (10 CORREDORAS)
--------------------------------------------------------------------------------
1. Special Week (Spe-chan) [SPWE]:
   La protagonista e ícono principal del juego. Noble, ingenua, apasionada y de corazón
   gigante. Su sprite de victoria con los puños en alto y expresión eufórica protagoniza
   el icono oficial del juego sobre fondo verde Tracen.

2. Gold Ship (Golshi) [GLSH]:
   El vórtice del caos slapstick. Rompe la cuarta pared, desafía la lógica y convierte
   cada minijuego en una travesura impredecible.

3. Oguri Cap [OGRC]:
   La leyenda de Kasamatsu. Atleta espartana de espíritu implacable, pocas palabras y
   un legendario amor por las zanahorias y la buena comida.

4. Seiun Sky [SEIK]:
   La estratega relajada. Amante de la pesca y las siestas; engaña a sus rivales con su
   aparente desinterés para dar golpes maestros en el momento justo.

5. Still in Love [STIL]:
   La llama oscura y apasionada. Vive cada partida con devoción e intensidad casi mística.

6. Matikanefukukitar [MACA]:
   La sacerdotisa de los amuletos y la buena suerte. Cómica y expresiva ante los tropiezos.

7. Agnes Tachyon [AGTC]:
   La científica de batas blancas y brebajes humeantes. Observa cada minijuego como un
   fascinante laboratorio de física aplicada.

8. Dantsu Flame [DAFL]:
   El coraje incansable y la humildad de Tracen. Compite con calidez y entrega total.

9. Jungle Pocket [JUPC]:
   El rugido salvaje de la pista. Orgullosa, apasionada y con hambre voraz de coronarse.

10. Samson Big [SABG]:
   La compañera fiel y optimista de corazón gigante.

SISTEMA GRÁFICO MODULAR DE PERSONAJES:
Cada avatar se renderiza componiendo capas sincronizadas frame a frame: sprite de cuerpo
base + accesorios y cabello izquierdo + accesorios y cabello derecho, permitiendo
animaciones fluidas de carrera, salto, tropiezo, golpe de cañón y celebración.

--------------------------------------------------------------------------------
3. GUÍA COMPLETA DE LOS 9 MINIJUEGOS
--------------------------------------------------------------------------------
MINIJUEGO 1: LA GARRA ARCADE (minijuego_garra.gd)
- Modo: 1 vs 3 Asimétrico. Duración: 45 segundos.
- Rol del Jefe: Maneja la grúa aérea de Pretty Catch. Mueve el carro en X (130-1040)
  y la mira en Y (200-560) para capturar a los corredores sobre la plataforma.
- Rol de Supervivientes: 3 corredores deben correr y esquivar el descenso de las tenazas.
- Fases de la Garra: LIBRE -> BAJANDO (500 px/s) -> CERRANDO (-20°) -> SUBIENDO ->
  VIAJANDO A PREMIOS (X=130) -> SOLTANDO al pozo de eliminación.
- Ambientación: Peluches de zanahorias, estrellas y caballitos en la piscina derecha.

MINIJUEGO 2: DUELO DE CAÑONES GIRATORIOS (minijuego_canones.gd)
- Modo: Todos contra Todos (FFA, 4 Jugadores).
- Mecánica: 4 plataformas rotatorias en las esquinas. Cada jugador comanda su montura.
- Disparo: Al pulsar DISPARAR se expulsa una bala estilo Bullet Bill.
- Físicas: Knockback vectorial para expulsar rivales de su plataforma.
- Escalación: A los 30s se acelera la rotación; a los 60s se activan muros de rebote.

MINIJUEGO 3: ESTALLIDO DE GLOBOS (minijuego_globos.gd)
- Modo: 2 vs 2 Cooperativo (Equipo Rojo vs Equipo Azul).
- Mecánica: Cada equipo tiene un émbolo neumático y un globo colosal.
- Objetivo: Accionar repetidamente el botón de acción para bombear aire al globo.
  El primer globo en estallar otorga la victoria.

MINIJUEGO 4: TORNEO JAN-KEN-PON (minijuego_janken.gd)
- Modo: Torneo eliminatorio (Semifinal A, Semifinal B y Gran Final en el Ring Central).
- Mecánica: Selección a ciegas en 3 segundos (Piedra, Papel o Tijera).
- Presentación: Focos de estadio y cantos dinámicos (¡JAN...!, ¡KEN...!, ¡PON!) con
  burbujas de diálogo animadas sobre cada duelista, revelación simultánea y estrellas.

MINIJUEGO 5: TEMPLO PINBALL (minijuego_templo.gd)
- Modo: Supervivencia (FFA).
- Mecánica: Arena con bumpers de Tracen Academy donde caen balones de baloncesto,
  chance balls y crash balls con físicas de impacto y rebote elástico.
- Movimiento especial: Salto parabólico de evasión con capa de colisión independiente.

MINIJUEGO 6: RELEVOS EN PISTA (minijuego_pista.gd)
- Modo: 2 vs 2 Cooperativo.
- Mecánica: Pista deportiva con cinta transportadora en contra y barriles rodantes
  lanzados desde el estrado de la Directora Akikawa. Relevo de testigo obligatorio.

MINIJUEGO 7: BALDOSAS DESPLEGABLES (minijuego_plataformas.gd)
- Modo: Memoria y Reflejos (Supervivencia FFA).
- Mecánica: El jumbotron central muestra el símbolo seguro (Zanahoria, Herradura, Trébol,
  Estrella o Corona). Tras 3 segundos las demás baldosas caen al vacío. Culmina con
  elevación del podio dorado de victoria para el único superviviente.

MINIJUEGO 8: TRIVIA TEATRAL TRACEN (minijuego_trivia.gd)
- Modo: Concurso de Conocimiento (FFA).
- Presentadores: Yayoi Akikawa y Tazuna Hayakawa en el gran auditorio.
- Mecánica: Preguntas con 4 opciones (A, B, C, D) y temporizador de 10s en atriles
  interactivos. Público con penlights de colores celebrando aciertos.

MINIJUEGO 9: PASTEL BOMBA (minijuego_explosion.gd)
- Modo: La Patata Caliente Slapstick (FFA).
- Mecánica: Los corredores se pasan un pastel con mecha encendida mediante contacto
  cuerpo a cuerpo. Quien sostenga el pastel cuando el temporizador oculto expire
  queda cubierto de merengue y eliminado.

--------------------------------------------------------------------------------
4. ARQUITECTURA TÉCNICA, RED Y CÓDIGO INTERNO
--------------------------------------------------------------------------------
MOTOR Y RENDERIZADO:
- Desarrollado en Godot 4.4 / 4.7.2 utilizando GDScript.
- Renderizador GL Compatibility (WebGL2 en navegadores, GLES3 en móviles y PC).
- Resolución nativa de 1152 x 648 (16:9) con escalado pixel-art de filtrado 0 (Nearest).

SISTEMA DE RED LOCAL (LAN ENet):
- Protocolo ENetMultiplayerPeer sobre UDP en red local doméstica.
- Modelo Servidor-Autoritativo: El Host ejecuta _physics_process, computa la física real
  y las colisiones de Area2D/CharacterBody2D. Los clientes transmiten exclusivamente sus
  intenciones de control vía rpc_id(1), impidiendo desincronizaciones o trampas.
- Latencia típica en red Wi-Fi LAN: 0 a 4 milisegundos.
- Priorización de IP inteligente en scripts/Global.gd con autodescubrimiento en la subred
  192.168.15.x y fallback para inserción manual.

SISTEMA DE CONTROLES MULTI-DISPOSITIVO:
- Detección y soporte automático de Teclado, Gamepad USB/Bluetooth y Pantalla Táctil.
- scripts/controles_tactiles.gd gestiona un joystick flotante con retorno elástico y un
  botón de acción táctil con emisión dual (InputEventAction vía parse_input_event y
  action_press en InputMap).
- Visibilidad adaptativa inteligente: La función Global.configurar_controles_tactiles()
  oculta el joystick en minijuegos que no lo requieren (Trivia, Jan-Ken-Pon, Cañones) y
  actualiza dinámicamente la etiqueta del botón (DISPARAR, ATRAPAR, SPRINT, IMPULSO).

CÁMARA CINEMATOGRÁFICA Y VICTORIA (BaseMinijuego.gd):
- Al concluir cada minijuego, ejecutar_secuencia_victoria() calcula los semi-extremos
  visibles según el zoom (half_w = 576.0 / zoom.x, half_h = 324.0 / zoom.y) y restringe
  la cámara estrictamente dentro de clamp(x, half_w, 1152 - half_w) y clamp(y, half_h,
  648 - half_h), con límites cam.limit_left=0, top=0, right=1152, bottom=648.
  Esto garantiza que jamás se expongan áreas vacías ni bordes negros fuera del escenario.

BUILDS MULTIPLATAFORMA DISPONIBLES:
1. Android (APK firmado): builds/android/UmaParty.apk (~72 MB).
   Totalmente compatible con pantallas táctiles y juego Wi-Fi local.
2. Web HTML5 / WASM: builds/web/index.html (~48 MB total con wasm y pck).
   Compilación single-threaded (no-threads) que no requiere cabeceras COOP/COEP y corre
   en cualquier servidor estático web o hosting personal.
3. PC Windows (.exe de 64 bits): Control nativo con teclado y mando a 60 FPS estables.