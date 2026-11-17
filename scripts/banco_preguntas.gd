class_name BancoPreguntas

static func obtener_preguntas() -> Array[Dictionary]:
	var lista: Array[Dictionary] = [
		# --- ANIME, MANGA Y VIDEOJUEGOS ---
		{
			"pregunta": "¿Qué comida le encanta comer a Gold Ship para recargar energías?",
			"opciones": ["Yakisoba", "Ramen picante", "Sushi", "Hamburguesa"],
			"correcta": 0,
			"categoria": "UMAMUSUME & ANIME"
		},
		{
			"pregunta": "¿Cómo se llama la espada icónica que porta Link en The Legend of Zelda?",
			"opciones": ["Espada Maestra", "Espada Mortal", "Buster Sword", "Soul Edge"],
			"correcta": 0,
			"categoria": "VIDEOJUEGOS"
		},
		{
			"pregunta": "¿Cuál es el verdadero nombre de Goku en Dragon Ball?",
			"opciones": ["Bardock", "Kakarotto", "Raditz", "Broly"],
			"correcta": 1,
			"categoria": "ANIME & MANGA"
		},
		{
			"pregunta": "¿Qué tipo de fruta comió Luffy en One Piece (nombre original)?",
			"opciones": ["Mera Mera", "Gomu Gomu", "Ope Ope", "Hito Hito"],
			"correcta": 1,
			"categoria": "ANIME & MANGA"
		},
		{
			"pregunta": "¿Cuál fue el primer videojuego en el que apareció Mario?",
			"opciones": ["Super Mario Bros", "Donkey Kong", "Mario Bros", "Jumpman Land"],
			"correcta": 1,
			"categoria": "VIDEOJUEGOS"
		},
		{
			"pregunta": "¿Cuál es el Pokémon inicial de tipo Fuego en la región de Kanto?",
			"opciones": ["Cyndaquil", "Torchic", "Charmander", "Chimchar"],
			"correcta": 2,
			"categoria": "VIDEOJUEGOS & ANIME"
		},
		{
			"pregunta": "¿En Death Note, cuál es la fruta favorita del Shinigami Ryuk?",
			"opciones": ["Naranja", "Manzana", "Plátano", "Sandía"],
			"correcta": 1,
			"categoria": "ANIME & MANGA"
		},
		{
			"pregunta": "¿Qué material se necesita para construir un portal al Nether en Minecraft?",
			"opciones": ["Bedrock", "Obsidiana", "Piedra luminosa", "Hierro"],
			"correcta": 1,
			"categoria": "VIDEOJUEGOS"
		},
		{
			"pregunta": "¿Cómo se llama la aldea ninja natal de Naruto Uzumaki?",
			"opciones": ["Aldea de la Arena", "Aldea de la Niebla", "Aldea de la Hoja", "Aldea de la Nube"],
			"correcta": 2,
			"categoria": "ANIME & MANGA"
		},
		{
			"pregunta": "¿Cuál es el apellido de Edward y Alphonse en Fullmetal Alchemist?",
			"opciones": ["Mustang", "Elric", "Hughes", "Armstrong"],
			"correcta": 1,
			"categoria": "ANIME & MANGA"
		},

		# --- CINE, SERIES Y TV ---
		{
			"pregunta": "¿Cómo se llama la inteligencia artificial creada por Tony Stark en Iron Man?",
			"opciones": ["FRIDAY", "JARVIS", "HAL", "ULTRON"],
			"correcta": 1,
			"categoria": "CINE & SERIES"
		},
		{
			"pregunta": "¿En Star Wars, de qué color es el sable de luz característico de Yoda?",
			"opciones": ["Azul", "Rojo", "Verde", "Morado"],
			"correcta": 2,
			"categoria": "CINE & SERIES"
		},
		{
			"pregunta": "¿En qué casa de Hogwarts es seleccionado Harry Potter?",
			"opciones": ["Slytherin", "Ravenclaw", "Gryffindor", "Hufflepuff"],
			"correcta": 2,
			"categoria": "CINE & SERIES"
		},
		{
			"pregunta": "¿A qué velocidad debe viajar el DeLorean para viajar en el tiempo en Regreso al Futuro?",
			"opciones": ["66 mph", "88 mph", "100 mph", "120 mph"],
			"correcta": 1,
			"categoria": "CINE & SERIES"
		},
		{
			"pregunta": "¿Cuál es el nombre del perro parlante y detective más famoso de los dibujos animados?",
			"opciones": ["Pluto", "Snoopy", "Scooby-Doo", "Coraje"],
			"correcta": 2,
			"categoria": "SERIES & DIBUJOS"
		},
		{
			"pregunta": "¿Quién dirigió la galardonada película animada 'El Viaje de Chihiro'?",
			"opciones": ["Makoto Shinkai", "Hayao Miyazaki", "Satoshi Kon", "Mamoru Hosoda"],
			"correcta": 1,
			"categoria": "CINE & ANIME"
		},
		{
			"pregunta": "¿Cómo se llama el reino ficticio gobernado por la familia real en Juego de Tronos?",
			"opciones": ["Narnia", "Poniente (Westeros)", "Tierra Media", "Hyrule"],
			"correcta": 1,
			"categoria": "CINE & SERIES"
		},

		# --- CULTURA GENERAL & GEOGRAFÍA ---
		{
			"pregunta": "¿Cuál es el río más largo y caudaloso del planeta Tierra?",
			"opciones": ["Nilo", "Misisipi", "Amazonas", "Yangtsé"],
			"correcta": 2,
			"categoria": "CULTURA GENERAL"
		},
		{
			"pregunta": "¿Cuál es la capital oficial de Japón?",
			"opciones": ["Kioto", "Osaka", "Tokio", "Yokohama"],
			"correcta": 2,
			"categoria": "CULTURA GENERAL"
		},
		{
			"pregunta": "¿Quién pintó la famosa obra de arte de 'La Mona Lisa'?",
			"opciones": ["Miguel Ángel", "Leonardo da Vinci", "Pablo Picasso", "Vincent van Gogh"],
			"correcta": 1,
			"categoria": "ARTE & CULTURA"
		},
		{
			"pregunta": "¿En qué país se encuentran las famosas Pirámides de Giza?",
			"opciones": ["México", "Egipto", "Perú", "Grecia"],
			"correcta": 1,
			"categoria": "HISTORIA & MUNDO"
		},
		{
			"pregunta": "¿Cuál es el océano más grande y profundo del mundo?",
			"opciones": ["Océano Atlántico", "Océano Índico", "Océano Ártico", "Océano Pacífico"],
			"correcta": 3,
			"categoria": "CULTURA GENERAL"
		},
		{
			"pregunta": "¿Qué instrumento musical tiene teclas blancas y negras con cuerdas percutidas?",
			"opciones": ["Guitarra", "Piano", "Arpa", "Flauta"],
			"correcta": 1,
			"categoria": "MÚSICA & ARTE"
		},
		{
			"pregunta": "¿En qué año llegó por primera vez el ser humano a la Luna?",
			"opciones": ["1959", "1969", "1975", "1981"],
			"correcta": 1,
			"categoria": "HISTORIA & CIENCIA"
		},

		# --- CIENCIA Y NATURALEZA ---
		{
			"pregunta": "¿Cuál es el planeta más grande de todo nuestro sistema solar?",
			"opciones": ["Saturno", "Neptuno", "Júpiter", "Urano"],
			"correcta": 2,
			"categoria": "CIENCIA Y NATURALEZA"
		},
		{
			"pregunta": "¿Qué animal es considerado el mamífero terrestre más veloz del mundo?",
			"opciones": ["Guepardo (Chita)", "León", "Antílope", "Caballo pura sangre"],
			"correcta": 0,
			"categoria": "CIENCIA Y NATURALEZA"
		},
		{
			"pregunta": "¿Cuál es el elemento químico más abundante en el universo?",
			"opciones": ["Oxígeno", "Carbono", "Hidrógeno", "Helio"],
			"correcta": 2,
			"categoria": "CIENCIA Y NATURALEZA"
		},
		{
			"pregunta": "¿Cuántos corazones tiene un pulpo?",
			"opciones": ["1", "2", "3", "4"],
			"correcta": 2,
			"categoria": "CIENCIA Y NATURALEZA"
		},
		{
			"pregunta": "¿Qué órgano del cuerpo humano consume aproximadamente el 20% de su energía?",
			"opciones": ["Corazón", "Cerebro", "Hígado", "Pulmones"],
			"correcta": 1,
			"categoria": "CIENCIA Y SALUD"
		},
		{
			"pregunta": "¿Cuál es el único mamífero capaz de volar activamente?",
			"opciones": ["Ardilla voladora", "Murciélago", "Colibrí", "Lémur volador"],
			"correcta": 1,
			"categoria": "CIENCIA Y NATURALEZA"
		},

		# --- PREGUNTAS CAPCIOSAS & ACERTIJOS ---
		{
			"pregunta": "Algunos meses tienen 31 días, otros 30... ¿Cuántos meses tienen 28 días?",
			"opciones": ["Solo 1 (Febrero)", "Ninguno", "Los 12 meses", "6 meses"],
			"correcta": 2,
			"categoria": "PREGUNTA CAPCIOSA"
		},
		{
			"pregunta": "Si vas corriendo en una carrera y adelantas al segundo lugar, ¿en qué puesto quedas?",
			"opciones": ["En primer lugar", "En segundo lugar", "En tercer lugar", "Empatado"],
			"correcta": 1,
			"categoria": "PREGUNTA CAPCIOSA"
		},
		{
			"pregunta": "¿Qué cosa se moja y empapa más mientras más seca?",
			"opciones": ["Una toalla", "El sol", "El secador de pelo", "Una esponja"],
			"correcta": 0,
			"categoria": "ACERTIJO & LÓGICA"
		},
		{
			"pregunta": "El padre de Rosa tiene 5 hijas: Chacha, Cheche, Chichi, Chocho y... ¿Quién es la quinta?",
			"opciones": ["Chuchu", "Rosa", "María", "Carmen"],
			"correcta": 1,
			"categoria": "PREGUNTA CAPCIOSA"
		},
		{
			"pregunta": "¿Qué pesa más: un kilogramo de plumas o un kilogramo de plomo?",
			"opciones": ["El plomo", "Las plumas", "Pesan exactamente lo mismo", "Depende del viento"],
			"correcta": 2,
			"categoria": "PREGUNTA CAPCIOSA"
		},
		{
			"pregunta": "¿Qué tiene agujeros por todas partes pero aún así puede retener agua?",
			"opciones": ["Un colador", "Una esponja", "Una red de pesca", "Una botella rota"],
			"correcta": 1,
			"categoria": "ACERTIJO & LÓGICA"
		},
		{
			"pregunta": "Un tren eléctrico viaja hacia el norte a 100 km/h y el viento sopla al sur. ¿Hacia dónde va el humo?",
			"opciones": ["Hacia el sur", "Hacia el norte", "Hacia arriba", "¡No echa humo, es eléctrico!"],
			"correcta": 3,
			"categoria": "PREGUNTA CAPCIOSA"
		},
		{
			"pregunta": "¿Qué es algo que sube y nunca jamás baja?",
			"opciones": ["La marea", "El humo", "Tu edad", "Un globo de helio"],
			"correcta": 2,
			"categoria": "ACERTIJO & LÓGICA"
		},

		# --- MÁS CINE, SERIES Y POP CULTURE ---
		{
			"pregunta": "¿Cómo se llama la escuela para jóvenes dotados en los X-Men?",
			"opciones": ["Academia Tracen", "Instituto Xavier", "Hogwarts", "Stark Tower"],
			"correcta": 1,
			"categoria": "CINE & SERIES"
		},
		{
			"pregunta": "¿Cuál es el titán que posee Eren Jaeger al inicio de Shingeki no Kyojin?",
			"opciones": ["Titán Colosal", "Titán de Ataque", "Titán Blindado", "Titán Bestia"],
			"correcta": 1,
			"categoria": "ANIME & MANGA"
		},
		{
			"pregunta": "¿Qué personaje de anime es conocido por el golpe mortal 'Serious Punch'?",
			"opciones": ["Goku", "Saitama", "All Might", "Luffy"],
			"correcta": 1,
			"categoria": "ANIME & MANGA"
		},
		{
			"pregunta": "¿En el juego Minecraft, qué flor aleja a los gatos salvajes o qué mascota asusta a los Creepers?",
			"opciones": ["Los perros", "Los gatos / ocelotes", "Los caballos", "Las abejas"],
			"correcta": 1,
			"categoria": "VIDEOJUEGOS"
		},
		{
			"pregunta": "¿Cuál es el nombre del ogro verde más famoso del cine de animación?",
			"opciones": ["Hulk", "Shrek", "Sulley", "Mike Wazowski"],
			"correcta": 1,
			"categoria": "CINE & ANIMACIÓN"
		},
		{
			"pregunta": "¿Qué actriz interpreta a Eleven en la serie Stranger Things?",
			"opciones": ["Sadie Sink", "Millie Bobby Brown", "Zendaya", "Emma Watson"],
			"correcta": 1,
			"categoria": "CINE & SERIES"
		},
		{
			"pregunta": "¿Cómo se llama la pequeña criatura compañera de Ash Ketchum que no entra en su Pokéball?",
			"opciones": ["Charmander", "Squirtle", "Pikachu", "Bulbasaur"],
			"correcta": 2,
			"categoria": "ANIME & VIDEOJUEGOS"
		},
		{
			"pregunta": "¿En la mitología nórdica, qué arma legendaria empuña el dios Thor?",
			"opciones": ["Gungnir", "Mjolnir", "Excalibur", "Stormbreaker"],
			"correcta": 1,
			"categoria": "MITOLOGÍA & CINE"
		},
		{
			"pregunta": "¿Cuál es el país con forma de bota en el mapa de Europa?",
			"opciones": ["España", "Italia", "Grecia", "Portugal"],
			"correcta": 1,
			"categoria": "CULTURA GENERAL"
		},
		{
			"pregunta": "Si me tienes me quieres compartir, si me compartes ya no me tienes. ¿Qué soy?",
			"opciones": ["Un secreto", "El dinero", "La comida", "Un chiste"],
			"correcta": 0,
			"categoria": "ACERTIJO & LÓGICA"
		}
	]
	
	# Barajamos la lista para que el orden sea totalmente impredecible
	lista.shuffle()
	return lista
