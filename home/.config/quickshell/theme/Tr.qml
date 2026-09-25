// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R                                                                    │
// │   singleton · what language the shell speaks                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick

import "../services"

// Translations, keyed by the English source string, so a missing
// translation falls back to English rather than to an id. `t` reads
// `language`, so bindings through it update when the setting changes.
//
// Grouped by settings page, in page order; strings used on several pages are
// under SHARED.
QtObject {
    id: root

    readonly property string language: SettingsService.language

    readonly property var languages: [
        { id: "en", label: "English" },
        { id: "es", label: "Español" }
    ]

    function t(text: string): string {
        if (root.language === "en")
            return text
        const table = root.tables[root.language]
        return (table && table[text]) ? table[text] : text
    }

    readonly property var tables: ({
        es: {
            // ── SHARED ──────────────────────────────────────────────────────
            "Search settings": "Buscar ajustes",
            "Reset": "Restablecer",
            "Open": "Abrir",
            "Clear": "Quitar",
            "Edit": "Editar",
            "Done": "Hecho",
            "Cancel": "Cancelar",
            "Apply": "Aplicar",
            "Remove": "Quitar",
            "Size": "Tamaño",
            "Scale": "Escala",
            "Shape": "Forma",
            "View": "Ver",
            "Hide": "Ocultar",
            "Shown": "Visible",
            "Hidden": "Oculto",
            "None": "Ninguno",
            "Off": "Apagado",
            "On": "Encendido",
            "Default": "Por defecto",
            "default": "por defecto",
            "Custom": "Personalizado",
            "Left": "Izquierda",
            "Right": "Derecha",
            "Bottom": "Abajo",
            "Start": "Principio",
            "Middle": "Centro",
            "End": "Final",
            "Applications": "Aplicaciones",
            "Search applications": "Busca aplicaciones",
            "Windows": "Ventanas",
            "Window": "Ventana",
            "Screen": "Pantalla",
            "Region": "Región",
            "Workspaces": "Espacios de trabajo",
            "Theme": "Tema",
            "Face": "Temática",
            "Style": "Estilo",
            "Palette": "Paleta",
            "Settings": "Ajustes",
            "Wallpaper": "Fondo",
            "Blur": "Desenfoque",
            "Background": "Fondo",
            "Arrangement": "Disposición",

            // ── THE PANEL ───────────────────────────────────────────────────
            "THE SHELL": "EL SHELL",
            "THE DESK": "EL ESCRITORIO",
            "THE SESSION": "LA SESIÓN",

            "Bar & Island": "Barra e isla",
            "The top bar, the island and notifications.":
                "La barra superior, la isla y las notificaciones.",
            "Modules": "Módulos",
            "Desktop": "Escritorio",
            "What sits on the wallpaper, under the windows.":
                "Lo que se queda sobre el fondo, debajo de las ventanas.",
            "Control Centre": "Centro de control",
            "What the island opens onto when you click it.":
                "Lo que abre la isla al hacer clic en ella.",
            "Dock": "Dock",
            "The dock and the applications kept on it.":
                "El dock y las aplicaciones que guardas en él.",
            "Launcher": "Lanzador",
            "Search, sigils and the clipboard history.":
                "Búsqueda, prefijos e historial del portapapeles.",
            "Results": "Resultados",
            "Sigils": "Prefijos",
            "Clipboard": "Portapapeles",
            "Appearance": "Apariencia",
            "Palette, windows, fonts and animations.":
                "Paleta, ventanas, tipografía y animaciones.",
            "Type": "Tipografía",
            "Motion": "Movimiento",
            "Displays": "Pantallas",
            "Screen layout, modes and the laptop lid.":
                "Disposición y modos de las pantallas, y la tapa del portátil.",
            "The screen": "La pantalla",
            "The lid": "La tapa",
            "Input": "Entrada",
            "The keyboard, the pointer and the cursor.":
                "El teclado, el puntero y el cursor.",
            "Keyboard": "Teclado",
            "Pointer": "Puntero",
            "Keys": "Atajos",
            "Every keybinding, the shell's and Hyprland's.":
                "Todos los atajos, los del shell y los de Hyprland.",
            "Session": "Sesión",
            "Your account, the lock screen and idle behaviour.":
                "Tu cuenta, la pantalla de bloqueo y la inactividad.",
            "Lock screen": "Pantalla de bloqueo",
            "When you leave": "Cuando te vas",
            "System": "Sistema",
            "Profiles, language, this machine and reset.":
                "Perfiles, idioma, esta máquina y restablecer.",
            "Profiles": "Perfiles",

            // ── BAR & ISLAND ────────────────────────────────────────────────
            "The island": "La isla",
            "Island": "Isla",
            "How the bar is drawn, and where the island meets the top edge.":
                "Cómo se dibuja la barra, y dónde encuentra la isla el borde superior.",
            "The style keeps what is on the bar and only changes how it is drawn: grouped round the island, spread to the two edges, or all inside one capsule. What each side carries is arranged in The bar.":
                "El estilo conserva lo que hay en la barra y solo cambia cómo se dibuja: agrupada alrededor de la isla, repartida hacia los dos bordes, o todo dentro de una sola cápsula. Qué lleva cada lado se ordena en La barra.",
            "Grouped": "Agrupada",
            "Spread": "Repartida",
            "The workspaces, the island and the modules together in the middle.":
                "Los espacios, la isla y los módulos, juntos en el centro.",
            "The workspaces at one edge, the modules at the other, the island between them.":
                "Los espacios en un borde, los módulos en el otro, y la isla entre ellos.",
            "Everything inside a single capsule.": "Todo dentro de una sola cápsula.",
            "A glance on hover": "Un vistazo al pasar el cursor",
            "Resting the pointer on the island opens it": "Dejar el cursor sobre la isla lo abre",
            "Only a click opens anything": "Solo un clic abre algo",
            "Lyrics pinned to the island": "Letra fijada en la isla",
            "While a track plays, the island holds its lyric line until unpinned":
                "Mientras suena una canción, la isla muestra su línea de letra hasta quitarla",
            "The clock keeps the island": "El reloj conserva la isla",
            "Muted": "Silenciado",
            "Cut into the top edge": "Recortada en el borde superior",
            "Floating below the top edge": "Flotando bajo el borde superior",
            "Floating": "Flotante",
            "One island": "Una isla",
            "Span the whole screen": "Ocupar toda la pantalla",
            "Edge to edge": "De borde a borde",
            "As wide as the island needs": "Lo ancha que la isla necesite",
            "As wide as the bar can be": "Tan ancha como pueda ser la barra",
            "Only one island can span the screen":
                "Solo una isla puede ocupar la pantalla",
            "The bar itself is the preview: it repaints over this window as the sliders move.":
                "La vista previa es la propia barra: se repinta sobre esta ventana mientras mueves los controles.",
            "Everything on the bar scales with its height. The top margin is the gap to the screen edge (the island ignores it in notch mode), and the side margin is the inset from the left and right edges.":
                "Todo lo de la barra escala con su altura. El margen superior es la distancia al borde de la pantalla (la isla lo ignora en modo notch) y el lateral, la separación de los bordes izquierdo y derecho.",
            "Bar height": "Altura de la barra",
            "Top margin": "Margen superior",
            "Side margin": "Margen lateral",
            "Set by \"Span the whole screen\"": "Lo fija \"Ocupar toda la pantalla\"",
            "The shown workspaces are always drawn; the rest, up to the available count, appear only while they have windows.":
                "Los espacios visibles se dibujan siempre; el resto, hasta los disponibles, solo aparecen mientras tienen ventanas.",
            "Workspaces shown": "Espacios visibles",
            "Workspaces available": "Espacios disponibles",

            "Notifications": "Notificaciones",
            "New notifications appear briefly in the island.":
                "Las notificaciones nuevas aparecen un momento en la isla.",
            "The shell is the notification daemon: notifications without their own timeout use the time below, and critical ones stay until dismissed. Do not disturb only keeps them off the screen; they still collect in the control centre until the shell restarts.":
                "El shell es el demonio de notificaciones: las que no indican su propia duración usan el tiempo de abajo, y las críticas se quedan hasta que las cierras. No molestar solo evita que ocupen la pantalla; siguen acumulándose en el centro de control hasta que el shell se reinicia.",
            "How long one stays": "Cuánto se queda una",
            "Nothing is shown while Do not disturb is on":
                "No se muestra nada con No molestar encendido",
            "Do not disturb": "No molestar",
            "Nothing takes the screen": "Nada toma la pantalla",
            "Everything is shown": "Se muestra todo",
            "Kept": "Guardadas",
            "in this session": "en esta sesión",
            "Nothing kept": "Nada guardado",

            // ── BAR & ISLAND · THE TIME ─────────────────────────────────────
            "The time": "La hora",
            "Beside the time": "Junto a la hora",
            "Shown on the resting island, and larger in the glance.":
                "Se muestra en la isla en reposo, y más grande en el vistazo.",
            "What is running sits either side of the time, two at most.":
                "Lo que está en marcha va a los lados de la hora, dos como mucho.",
            "A recording is always there and comes first; click its dot to stop it. Then a countdown, then media, and either still works from its chip on the bar when kept off the island.":
                "La grabación siempre está y va primero; haz clic en su punto para pararla. Luego la cuenta atrás y luego la música, y las dos siguen funcionando desde su pieza en la barra si no van en la isla.",
            "On the island while it runs": "En la isla mientras está en marcha",
            "Only where its chip is put": "Solo donde esté su pieza",

            // ── BAR & ISLAND · MODULES ──────────────────────────────────────
            "Chips": "Piezas",
            "Every piece on the bar follows these unless it was given its own.":
                "Todas las piezas de la barra siguen esto salvo que se les haya dado uno propio.",
            "Like the bar": "Como la barra",
            "When": "Cuándo",
            "The widgets": "Los widgets",
            "Module settings": "Ajustes de módulos",
            "The bar": "La barra",
            "While it runs": "Mientras está en marcha",
            "Nothing to set: it is drawn one way.": "Nada que ajustar: se dibuja de una sola forma.",
            "Icon shows the module's symbol; Ring draws the gauge of a module that measures something (charge, volume, a countdown) as a circle around it, and the rest keep their symbol. The figure is the value itself, and On hover shows it only while the pointer is over the chip.":
                "Icono muestra el símbolo del módulo; Anillo dibuja el indicador de los módulos que miden algo (carga, volumen, una cuenta atrás) como un círculo a su alrededor, y los demás se quedan con su símbolo. La cifra es el valor en sí, y Al pasar solo la muestra mientras el cursor está sobre la pieza.",
            "Icon": "Icono",
            "Ring": "Anillo",
            "The symbol alone, small.": "El símbolo solo, pequeño.",
            "The gauge, in a circle.": "El indicador, en un círculo.",
            "Figure": "Cifra",
            "No": "No",
            "On hover": "Al pasar",
            "Always": "Siempre",
            "No figure beside it": "Sin cifra al lado",
            "The figure opens under the pointer": "La cifra se abre bajo el cursor",
            "The figure always beside it": "La cifra siempre al lado",
            "Layout": "Disposición",
            "Drag a piece from the catalogue onto the bar.":
                "Arrastra una pieza del catálogo a la barra.",
            "Drop a piece on either half of the bar to place it on that side of the island; drag it along to move it or off the bar to remove it, and click it to give it its own shape and figure. Adjacent modules share a capsule, and a split starts a new one.":
                "Suelta una pieza en una mitad de la barra para ponerla en ese lado de la isla; arrástrala para moverla o fuera de la barra para quitarla, y haz clic en ella para darle forma y cifra propias. Los módulos contiguos comparten cápsula, y una separación empieza otra.",
            "Empty": "Vacío",
            "Search": "Buscar",
            "Overview": "Vista general",
            "Split": "Separación",

            "Media": "Multimedia",
            "Timer": "Temporizador",
            "Battery": "Batería",
            "Volume": "Volumen",
            "Brightness": "Brillo",
            "Network": "Red",
            "Weather": "Tiempo",
            "Updates": "Actualizaciones",
            "Pet": "Mascota",
            "Spectrum": "Espectro",
            "Sound bars from whatever is playing, on the grid or along an edge.":
                "Barras de sonido de lo que esté sonando, en la cuadrícula o a lo largo de un borde.",
            "The bars leave when a window opens on the workspace and come back when the last one closes, and stop listening meanwhile. Off, they stay under the windows.":
                "Las barras se retiran cuando se abre una ventana en el espacio de trabajo y vuelven cuando se cierra la última, y mientras tanto dejan de escuchar. Apagado, se quedan debajo de las ventanas.",
            "Only on an empty workspace": "Solo en un espacio vacío",
            "Under the windows": "Debajo de las ventanas",
            "Fill": "Relleno",
            "From the edge": "Desde el borde",
            "To the tip": "Hasta la punta",
            "Height": "Altura",
            "Bars": "Barras",
            "Gap": "Hueco",
            "Lows": "Graves",
            "At the corners": "En las esquinas",
            "Peaks": "Picos",
            "Rounded columns": "Columnas redondeadas",
            "Square columns": "Columnas rectas",
            "Segments": "Segmentos",
            "Dots": "Puntos",
            "Fading to the tip": "Desvanecido hacia la punta",
            "Solid": "Sólido",
            "Two colours": "Dos colores",
            "Games": "Juegos",
            "Calendar": "Calendario",
            "Notes": "Notas",
            "Tasks": "Tareas",
            "Clock": "Reloj",
            "Photo": "Foto",

            // ── BAR & ISLAND · WHAT A MODULE KNOWS ──────────────────────────
            "Seconds make the clock repaint sixty times as often.":
                "Los segundos hacen que el reloj se repinte sesenta veces más a menudo.",
            "Clock format": "Formato de hora",
            "24-hour": "24 horas",
            "12-hour": "12 horas",
            "Show the date": "Mostrar la fecha",
            "The time alone": "Solo la hora",
            "Show seconds": "Mostrar segundos",

            "Left empty, wttr.in guesses from your connection's IP address, which can be far off. A city, postcode or airport code is more reliable, and the bar uses the same place.":
                "Si lo dejas vacío, wttr.in lo deduce de la IP de tu conexión, y puede fallar bastante. Una ciudad, un código postal o un código de aeropuerto es más fiable, y la barra usa el mismo lugar.",
            "Location": "Ubicación",
            "A city, a postcode or an airport code.":
                "Una ciudad, un código postal o un código de aeropuerto.",
            "Wherever the request comes from": "De donde venga la petición",
            "No such place — the last reading is still showing":
                "No existe ese lugar — se sigue mostrando la última lectura",

            "The graph is read from the public profile page, so no token or account is needed. It stays empty until you enter a username.":
                "El gráfico se lee de la página pública del perfil, así que no hace falta token ni cuenta. Queda vacío hasta que escribes un usuario.",
            "Username": "Usuario",
            "Whose public contribution graph to draw.":
                "De quién se dibuja el gráfico público de contribuciones.",
            "Nobody yet": "Nadie todavía",
            "No such profile — the last grid is still showing":
                "No existe ese perfil — se sigue mostrando la última cuadrícula",

            "A note on the wallpaper is written the same way as one in the panel.":
                "Una nota en el fondo se escribe igual que una del panel.",
            "Handwriting": "A mano",
            "The signature's script": "La letra de la firma",
            "The interface face": "La tipografía de la interfaz",
            "The notes stuck on the screen's edges leave when a window opens on the workspace and come back when the last one closes. Off, they stay over the windows.":
                "Las notas pegadas a los bordes se retiran cuando se abre una ventana en el espacio de trabajo y vuelven cuando se cierra la última. Apagado, se quedan sobre las ventanas.",
            "Edges only on an empty workspace": "Bordes solo en un espacio vacío",
            "Gone while a window is open": "Fuera mientras haya una ventana abierta",
            "Over the windows": "Sobre las ventanas",

            "How the creature is drawn, wherever it is drawn.":
                "Cómo se dibuja la criatura, en todas partes donde se dibuja.",
            "The species decides the colour and what the creature is; the style decides how it is drawn. The same drawing is used on the bar, in the pet's panel and on the desktop.":
                "La especie decide el color y qué criatura es; el estilo decide cómo se dibuja. El mismo dibujo se usa en la barra, en el panel de la mascota y en el escritorio.",
            "Creature": "Criatura",
            "A different animal for each species.":
                "Un animal distinto para cada especie.",
            "Plush": "Peluche",
            "One round body, shaded.": "Un solo cuerpo redondo, sombreado.",
            "Paper": "Papel",
            "Flat, cut from two tones.": "Plano, recortado en dos tonos.",
            "Pixel": "Píxel",
            "A sprite, sixteen cells across.":
                "Un sprite de dieciséis celdas de ancho.",

            "Unhatched — care for it and see": "Sin eclosionar — cuídalo y verás",
            "Bring out": "Sacar",
            "Out": "Fuera",
            "The next egg": "El próximo huevo",
            "Levels across the family": "Niveles de la familia",
            "All five found": "Los cinco encontrados",
            "Nothing left to find — there is a star waiting at level fifteen for each of them.":
                "No queda nada por encontrar — a cada una le espera una estrella en el nivel quince.",

            // ── DESKTOP ─────────────────────────────────────────────────────
            "The desktop": "El escritorio",
            "Widgets are arranged directly on the wallpaper.":
                "Los widgets se colocan directamente sobre el fondo.",
            "Arranging brings the widgets in front of the windows, with a card of every module, moved by the space between them. Drag one onto the grid, pull a widget's corner to change its shape, click it for a look of its own, and drop it back on the card to take it off. Escape or the right button ends it, and the right button on any widget opens the same mode from the picture. This window closes meanwhile.":
                "Colocar trae los widgets por delante de las ventanas, con una tarjeta de todos los módulos que se mueve por el espacio entre ellos. Arrastra uno a la cuadrícula, tira de la esquina de un widget para cambiarle la forma, haz clic en él para darle un aspecto propio y suéltalo sobre la tarjeta para quitarlo. Esc o el botón derecho lo terminan, y el botón derecho sobre cualquier widget abre el mismo modo desde la imagen. Esta ventana se cierra mientras tanto.",
            "Arrange the desktop": "Colocar el escritorio",
            "Arrange widgets": "Colocar widgets",
            "on the wallpaper": "en el fondo",
            "Nothing on the wallpaper yet": "Nada en el fondo todavía",
            "Look": "Aspecto",
            "Every widget follows these unless it was given a look of its own.":
                "Todos los widgets siguen esto salvo que se les haya dado un aspecto propio.",
            "While arranging, click a widget to override these for it alone. Modern shows a figure with a caption and Analogue draws an object such as a dial or a gauge; the style and background set what sits behind it.":
                "Mientras colocas, haz clic en un widget para cambiar esto solo para él. Modern muestra una cifra con un pie y Analógico dibuja un objeto, como una esfera o un indicador; el estilo y el fondo fijan lo que lleva detrás.",

            "Modern": "Modern",
            "Analogue": "Analógico",
            "Capsule": "Cápsula",
            "Accent": "Acento",
            "Outline": "Contorno",
            "No capsule": "Sin cápsula",
            "Small": "Pequeño",
            "Wide": "Ancho",
            "Large": "Grande",
            "Band": "Banda",

            "Notes on the edge": "Notas en el borde",
            "Where": "Dónde",
            "Grid": "Cuadrícula",
            "Along the edge": "A lo largo del borde",
            "Which notes": "Qué notas",
            "New notes land here": "Las notas nuevas van aquí",
            "Which note": "Qué nota",
            "The newest": "La más reciente",
            "New note": "Nota nueva",
            "Choose…": "Elegir…",
            "Caption": "Pie de foto",
            "Written under the picture": "Escrito bajo la foto",
            "Wallpapers": "Fondos",
            "Home": "Carpeta personal",
            "No pictures here": "Aquí no hay fotos",

            // ── CONTROL CENTRE ──────────────────────────────────────────────
            "The panel": "El panel",
            "A six by eight grid, arranged on the panel itself.":
                "Una cuadrícula de seis por ocho, que se coloca en el propio panel.",
            "Edit shows the grid with a card of every block, moved by the space between them: drag a block onto the cells, pull a corner or scroll to resize, and drop one on the card to remove it. Escape leaves this mode, the right button on the panel enters or leaves it without opening settings, and a click on a toggles block chooses its switches.":
                "Editar muestra la cuadrícula con una tarjeta de todos los bloques, que se mueve por el espacio entre ellos: arrastra un bloque a las casillas, tira de una esquina o usa la rueda para cambiar el tamaño, y suelta uno en la tarjeta para quitarlo. Esc sale del modo, con el botón derecho sobre el panel entras o sales sin abrir los ajustes, y haciendo clic en un bloque de conmutadores eliges cuáles lleva.",
            "Arrange the control centre": "Colocar el centro de control",
            "Default layout": "Disposición inicial",
            "The top row": "La fila de arriba",
            "Session actions always sit on the left. These buttons, which open other panels and this window, fill the row from the right in this order.":
                "Las acciones de sesión van siempre a la izquierda. Estos botones, que abren otros paneles y esta ventana, llenan la fila desde la derecha en este orden.",

            "System statistics": "Estadísticas del sistema",
            "Workspace overview": "Vista de espacios",
            "Session menu": "Menú de sesión",
            "Lock the screen": "Bloquear la pantalla",
            "Task board": "Tablero de tareas",
            "Packages": "Paquetes",

            "Toggles": "Conmutadores",
            "Wi-Fi": "Wi-Fi",
            "Power": "Energía",
            "Focus": "Concentración",
            "Microphone": "Micrófono",
            "Airplane": "Modo avión",
            "Output": "Salida",
            "Notch": "Notch",
            "Shadows": "Sombras",
            "Capture": "Capturar",
            "Annotate": "Anotar",
            "Read text": "Leer texto",
            "Colour": "Color",
            "Record": "Grabar",
            "Clear clipboard": "Vaciar el portapapeles",

            // ── DOCK ────────────────────────────────────────────────────────
            "The dock": "El dock",
            "The dock is off": "El dock está apagado",
            "Your kept and open applications, on one edge of the screen.":
                "Tus aplicaciones guardadas y las abiertas, en un borde de la pantalla.",
            "An empty dock is not drawn. Icons are reordered by dragging them on the dock itself, and the top edge is left to the bar.":
                "Un dock vacío no se dibuja. Los iconos se reordenan arrastrándolos en el propio dock, y el borde superior queda para la barra.",
            "Show the dock": "Mostrar el dock",
            "Edge": "Borde",
            "Alignment": "Alineación",
            "Everything on the dock scales with the icon size.":
                "Todo el dock escala con el tamaño de los iconos.",
            "Background sets how opaque the capsule behind the icons is; lower it to let the blurred wallpaper through.":
                "Fondo fija la opacidad de la cápsula tras los iconos; bájalo para que se vea el fondo desenfocado.",
            "Icon size": "Tamaño de icono",
            "Behaviour": "Comportamiento",
            "What else the dock shows, and which screens it is on.":
                "Qué más muestra el dock, y en qué pantallas está.",
            "The launcher button opens the island's launcher, and open applications appear after a divider while they run. Windows always pass under the dock; the desktop keeps its widgets clear of it.":
                "El botón del lanzador abre el lanzador de la isla, y las aplicaciones abiertas aparecen tras un separador mientras están en marcha. Las ventanas siempre pasan por debajo del dock; el escritorio mantiene sus widgets fuera de él.",
            "Launcher button": "Botón del lanzador",
            "Open applications": "Aplicaciones abiertas",
            "On every screen": "En todas las pantallas",
            "One on each, all showing the same": "Uno en cada una, todos iguales",
            "Only on the screen you are on": "Solo en la pantalla en la que estás",
            "One on each, and the one you are on is the live one":
                "Una en cada una, y la de tu pantalla es la que funciona",
            "Hide until pointed at": "Ocultar hasta apuntarlo",
            "Kept on it": "Guardadas en él",
            "These stay whether they are running or not, and they lead the launcher's list too.":
                "Estas se quedan estén o no en marcha, y también van delante en la lista del lanzador.",
            "Their order is set by dragging them on the dock, and right-clicking a dock icon also keeps or removes it. The launcher uses this list too, so it stays editable with the dock off.":
                "El orden se fija arrastrándolas en el dock, y con el botón derecho sobre un icono también lo guardas o lo quitas. El lanzador también usa esta lista, así que se puede editar con el dock apagado.",
            "Nothing kept yet.": "Todavía no hay nada guardado.",
            "This application is no longer installed":
                "Esta aplicación ya no está instalada",
            "Add an application": "Añadir una aplicación",
            "New window": "Ventana nueva",
            "Keep in the dock": "Guardar en el dock",
            "Remove from the dock": "Quitar del dock",
            "Close": "Cerrar",
            "Close all windows": "Cerrar todas las ventanas",

            // ── LAUNCHER ────────────────────────────────────────────────────
            "The list": "La lista",
            "What the launcher lists with nothing typed, and how tall it gets.":
                "Lo que muestra el lanzador sin escribir nada, y cuánto crece.",
            "By use ranks applications by launches, with older launches counting for less; those kept on the dock come first until something else is used more. As tall as the answer sizes the island to the results, up to the limit above; off, the box is fixed and the list scrolls.":
                "Por uso ordena las aplicaciones por aperturas, y las antiguas cuentan menos; las guardadas en el dock van primero hasta que otra se use más. Tan alta como la respuesta ajusta la isla a los resultados, hasta el límite de arriba; apagado, la caja es fija y la lista se desplaza.",
            "Order": "Orden",
            "By use": "Por uso",
            "Alphabetical": "Alfabético",
            "Results shown": "Resultados visibles",
            "rows": "filas",
            "As tall as the answer": "Tan alta como la respuesta",
            "Only as tall as it needs": "Solo lo alta que necesite",
            "A fixed box": "Una caja fija",
            "Kept applications": "Aplicaciones guardadas",
            "They lead the list, and the dock keeps them too.":
                "Van delante en la lista, y el dock también las guarda.",
            "Plain text searches applications, and a sigil in front switches mode. Click one to change it.":
                "El texto normal busca aplicaciones, y un prefijo delante cambia de modo. Haz clic en uno para cambiarlo.",

            "Calculate": "Calcular",
            "Work something out": "Calcula algo",
            "Desk": "Escritorio",
            "Open a panel or an action": "Abre un panel o una acción",
            "Find an open window": "Encuentra una ventana abierta",
            "Start a countdown": "Inicia una cuenta atrás",
            "Note": "Nota",
            "Keep a note": "Guarda una nota",
            "Copy something again": "Vuelve a copiar algo",
            "Apps": "Aplicaciones",

            "Clipboard history": "Historial del portapapeles",
            "Everything copied, searchable from the launcher.":
                "Todo lo copiado, con búsqueda desde el lanzador.",
            "Copies from password managers are never stored, and turning the history off stops the watcher entirely. Emptying on lock is off by default, since the lock already protects the session.":
                "Lo copiado desde un gestor de contraseñas no se guarda nunca, y apagar el historial detiene el vigilante por completo. Vaciarlo al bloquear está apagado por defecto, porque el bloqueo ya protege la sesión.",
            "Keep a history": "Guardar un historial",
            "Watching": "Vigilando",
            "Entries kept": "Entradas guardadas",
            "No history is being kept": "No se guarda ningún historial",
            "Keep images": "Guardar imágenes",
            "Pictures as well as text": "Imágenes además de texto",
            "Text only": "Solo texto",
            "Empty it on lock": "Vaciarlo al bloquear",
            "Thrown away on lock": "Se tira al bloquear",
            "Kept across a lock": "Se conserva al bloquear",

            // ── APPEARANCE ──────────────────────────────────────────────────
            "The palette follows the wallpaper, and both are chosen in the island.":
                "La paleta sigue al fondo, y los dos se eligen en la isla.",
            "This opens the island's appearance panel, where wallpapers and palettes are chosen together.":
                "Esto abre el panel de apariencia de la isla, donde se eligen juntos fondos y paletas.",
            "Theme and wallpaper": "Tema y fondo",

            "Transition": "Transición",
            "How the next wallpaper arrives over the last one.":
                "Cómo llega el siguiente fondo sobre el anterior.",
            "Random picks one of the effects above each time a wallpaper is applied.":
                "Aleatorio elige uno de los efectos de arriba cada vez que se aplica un fondo.",
            "Effect": "Efecto",
            "Fade": "Fundido",
            "Wipe": "Barrido",
            "Wave": "Ola",
            "Circle": "Círculo",
            "Outer": "Desde fuera",
            "Random": "Aleatorio",

            "Greeting": "Saludo",
            "The animation shown beside fastfetch when you run fa.":
                "La animación que aparece junto a fastfetch cuando ejecutas fa.",
            "Four pixel-art scenes, redrawn in the current palette whenever it changes. Random picks a new one on every run, and fa with a scene name (fa koi) plays that one.":
                "Cuatro escenas en pixel art, redibujadas con la paleta actual cada vez que cambia. Aleatorio elige una nueva en cada ejecución, y fa con el nombre de una escena (fa koi) muestra esa.",
            "Scene": "Escena",
            "Lava lamp": "Lámpara de lava",
            "Critters": "Bichos",

            "How Hyprland draws every window, this one included.":
                "Cómo dibuja Hyprland cada ventana, esta incluida.",
            "The preview below is live and at full size. The border stays at zero because gaps and rounding already separate windows; the inner gap applies to each side of a window, so two windows sit twice that apart.":
                "La vista previa de abajo es en vivo y a tamaño real. El borde se queda en cero porque los huecos y el redondeo ya separan las ventanas; el hueco interior se aplica a cada lado de una ventana, así que entre dos queda el doble.",
            "Window rounding": "Redondeo de ventanas",
            "Border width": "Grosor del borde",
            "Inner gap": "Hueco interior",
            "Outer gap": "Hueco exterior",
            "Inactive opacity": "Opacidad inactiva",

            "Depth": "Profundidad",
            "What shows through a window, and what it sits on.":
                "Qué se ve a través de una ventana, y sobre qué se apoya.",
            "Blur shows behind anything translucent, such as the terminal. Glass (a Hyprland plugin, tuned in look.lua) frosts and refracts what is behind a window, and the shadow lifts windows and bar capsules off the wallpaper.":
                "El desenfoque se ve tras todo lo translúcido, como el terminal. El cristal (un plugin de Hyprland, ajustado en look.lua) esmerila y refracta lo que hay detrás de una ventana, y la sombra despega del fondo las ventanas y las cápsulas de la barra.",
            "size": "tamaño",
            "Glass": "Cristal",
            "Needs the glass plugin — run ./setup plugins":
                "Necesita el plugin del cristal — ejecuta ./setup plugins",
            "Shadow": "Sombra",
            "Lifted off the wallpaper": "Despegadas del fondo",
            "Flat": "Planas",
            "Window rules": "Reglas de ventana",
            "Every rule": "Todas las reglas",
            "in windowrules.lua": "en windowrules.lua",
            "Read from hypr/modules/windowrules.lua — changing them means editing that file.":
                "Leídas de hypr/modules/windowrules.lua — cambiarlas es editar ese archivo.",
            "Nothing to show — the file is missing or empty.":
                "Nada que mostrar — el archivo falta o está vacío.",

            "Interface": "Interfaz",
            "Everything Quickshell draws.":
                "Todo lo que dibuja Quickshell.",
            "Monospace": "Monoespaciada",
            "The bar's glyphs and readings, and the terminal.":
                "Los glifos y las lecturas de la barra, y el terminal.",
            "kitty is given the same family, so the terminal and the shell always match. It must be a Nerd Font, or the bar's icons show as empty boxes.":
                "kitty recibe la misma familia, así que el terminal y el shell siempre coinciden. Tiene que ser una Nerd Font, o los iconos de la barra saldrán como cuadros vacíos.",
            "Icons need a Nerd Font patched family.":
                "Los iconos necesitan una fuente parcheada Nerd Font.",

            "The shell": "El shell",
            "The island, its panels, the chips — everything Qt draws.":
                "La isla, sus paneles, las cápsulas — todo lo que dibuja Qt.",
            "Pace": "Ritmo",
            "Smooth": "Suave",
            "Snappy": "Ágil",
            "Springy": "Elástico",
            "How Hyprland animates windows. Reapplied after every reload.":
                "Cómo anima Hyprland las ventanas. Se reaplica tras cada recarga.",
            "Preset": "Preajuste",
            "Glide": "Planeo",
            "Brisk": "Vivo",
            "Calm": "Calma",
            "Bounce": "Rebote",
            "Scales into place and decelerates with a long tail. Quick, and it never bounces.":
                "Escala a su sitio y frena con una cola larga. Rápido, y nunca rebota.",
            "Half the distance and half the time. Movement you register rather than watch.":
                "La mitad de distancia y de tiempo. Movimiento que registras más que miras.",
            "Long and soft, and the screen fades between workspaces rather than sliding.":
                "Largo y suave, y la pantalla funde entre espacios en vez de deslizar.",
            "Overshoots a little and settles back. The look most Hyprland presets are after.":
                "Se pasa un poco y vuelve a asentarse. El aspecto que persiguen la mayoría de preajustes.",
            "Nothing moves. Windows and workspaces appear where they are going to be.":
                "Nada se mueve. Ventanas y espacios aparecen donde van a estar.",

            // ── DISPLAYS ────────────────────────────────────────────────────
            "The screens": "Las pantallas",
            "Drag one to move it, click one to change it.":
                "Arrastra una para moverla, haz clic para cambiarla.",
            "Arrangements are saved per set of connected monitors, identified by the monitor rather than the port, so moving a cable or closing the lid keeps them.":
                "Las disposiciones se guardan por cada conjunto de monitores conectados, identificados por el monitor y no por el puerto, así que cambiar un cable de sitio o cerrar la tapa las conserva.",
            "Every screen shows the primary's": "Todas muestran lo de la principal",
            "Extended across all of them": "Repartido entre todas",
            "Extend": "Extender",
            "Mirror": "Duplicar",
            "The main screen": "La pantalla principal",
            "Where anything with no screen of its own goes, and what mirroring copies.":
                "Donde va lo que no tiene pantalla propia, y lo que duplican las demás.",
            "This arrangement": "Esta disposición",
            "Kept against these screens and no others.":
                "Guardada para estas pantallas y ninguna otra.",
            "Forget it": "Olvidarla",
            "Hands these screens back to Hyprland's own placement":
                "Devuelve estas pantallas a la colocación de Hyprland",
            "Forget": "Olvidar",
            "Which screen": "Qué pantalla",
            "Editing": "Editando",
            "Off — out of the layout, and still plugged in":
                "Apagada — fuera de la disposición, y sigue conectada",
            "Dark — the panel is asleep, and the workspaces are still on it":
                "Oscura — el panel duerme, y sus espacios siguen en ella",
            "The only screen there is": "La única pantalla que hay",
            "Only one screen is plugged in": "Solo hay una pantalla conectada",
            "Only one screen is on": "Solo hay una pantalla encendida",
            "Resolution": "Resolución",
            "What the monitor itself reported, largest first.":
                "Lo que ha reportado el propio monitor, de mayor a menor.",
            "Only the modes the monitor reports are listed. Choosing a resolution selects its highest refresh rate.":
                "Solo aparecen los modos que anuncia el monitor. Al elegir una resolución se usa su frecuencia de refresco más alta.",
            "Refresh rate": "Frecuencia de refresco",
            "The screen is off": "La pantalla está apagada",
            "The only rate at this resolution": "La única frecuencia a esta resolución",
            "Rotation": "Rotación",
            "Variable refresh": "Refresco variable",

            "When the lid closes": "Cuando se cierra la tapa",
            "Only applies with another screen connected.":
                "Solo se aplica con otra pantalla conectada.",
            "With nothing else connected, closing the lid is left to logind, which suspends. With another screen connected, the shell can switch the panel off and move its workspaces to the remaining screen, then bring them back when the lid opens.":
                "Sin nada más conectado, cerrar la tapa lo gestiona logind, que suspende. Con otra pantalla conectada, el shell puede apagar el panel y mover sus espacios a la pantalla que queda, y devolverlos al abrir la tapa.",
            "The laptop's screen": "La pantalla del portátil",
            "Switched off, and its workspaces move over":
                "Se apaga, y sus espacios se mudan",
            "Left on behind the lid": "Se queda encendida tras la tapa",
            "Left to the system": "En manos del sistema",
            "No laptop panel on this machine": "No hay panel de portátil en esta máquina",
            "Switch it off": "Apagarla",
            "Leave it on": "Dejarla encendida",
            "The system decides": "Decide el sistema",

            "Right now": "Ahora mismo",
            "The current state, as the shell detects it.":
                "El estado actual, tal como lo detecta el shell.",
            "The laptop's panel": "El panel del portátil",
            "Not on this machine": "No en esta máquina",
            "%1 — off, and still plugged in": "%1 — apagada, y sigue conectada",
            "%1 — on": "%1 — encendida",
            "Other screens": "Otras pantallas",
            "None — the system handles the lid": "Ninguna — la tapa la gestiona el sistema",

            "Night light": "Luz nocturna",
            "Warmer colours for the evening.":
                "Colores más cálidos para la noche.",
            "It adjusts the gamma ramp, so screenshots keep their original colours. There is no schedule: it stays on until you turn it off.":
                "Ajusta la rampa gamma, así que las capturas conservan sus colores originales. No hay horario: se queda encendida hasta que la apagas.",
            "Warm the screen": "Calentar la pantalla",
            "Needs hyprsunset, which is not installed":
                "Necesita hyprsunset, que no está instalado",
            "Colour temperature": "Temperatura de color",

            // ── INPUT ───────────────────────────────────────────────────────
            "Layouts": "Distribuciones",
            "Loaded in this order; the first is active at login.":
                "Se cargan en este orden; la primera es la activa al iniciar sesión.",
            "Switch between them": "Cambiar entre ellas",
            "Only one layout is loaded": "Solo hay una distribución cargada",
            "Layouts, in order": "Distribuciones, en orden",
            "· the first is the one you start on": "· la primera es con la que empiezas",
            "Search {} layouts": "Busca entre {} distribuciones",
            "Caps Lock": "Bloq Mayús",

            "Typing": "Escritura",
            "How fast a held key repeats, once it has started.":
                "Cuán rápido repite una tecla mantenida, una vez arranca.",
            "Key repeat rate": "Repetición de tecla",

            "Zero is the device's native speed; either side adjusts libinput's acceleration.":
                "Cero es la velocidad nativa del dispositivo; a cada lado se ajusta la aceleración de libinput.",
            "Sensitivity": "Sensibilidad",

            "The cursor": "El cursor",
            "One vector shape, sharp at any size — Palette follows the wallpaper.":
                "Una forma vectorial, nítida a cualquier tamaño — Paleta sigue al fondo.",
            "Colour and size are applied with hyprctl setcursor, so every application updates at once and Palette follows wallpaper changes. Shake to find briefly enlarges the pointer when you shake the mouse; it needs the hypr-dynamic-cursors plugin (./setup plugins).":
                "El color y el tamaño se aplican con hyprctl setcursor, así que todas las aplicaciones cambian a la vez y Paleta sigue los cambios de fondo. Agitar para encontrar agranda el puntero un momento al agitar el ratón; necesita el plugin hypr-dynamic-cursors (./setup plugins).",
            "Cursor colour": "Color del cursor",
            "Cursor size": "Tamaño del cursor",
            "24 px — the default": "24 px — el valor por defecto",
            "Shake to find": "Agitar para encontrar",
            "Needs the cursor plugin — run ./setup plugins":
                "Necesita el plugin del cursor — ejecuta ./setup plugins",
            "Black": "Negro",
            "White": "Blanco",
            "Red": "Rojo",
            "Orange": "Naranja",
            "Yellow": "Amarillo",
            "Green": "Verde",
            "Blue": "Azul",
            "Purple": "Morado",
            "Pink": "Rosa",

            // ── KEYS ────────────────────────────────────────────────────────
            "The shell's own": "Los del shell",
            "Click a combination to change it. Every key here belongs to the profile in use.":
                "Haz clic en una combinación para cambiarla. Cada tecla de aquí es del perfil en uso.",
            "Each profile has its own complete set of keys. A combination already in use is allowed, since Hyprland fires both binds, but the row warns you before you apply it.":
                "Cada perfil tiene su propio juego completo de teclas. Una combinación ya en uso se permite, porque Hyprland dispara los dos atajos, pero la fila te avisa antes de aplicarla.",
            "The compositor's": "Los del compositor",
            "Windows, workspaces, the media keys, the screen off — changed the same way, and kept in the same profile.":
                "Ventanas, espacios, las teclas multimedia, apagar la pantalla — se cambian igual y se guardan en el mismo perfil.",
            "The shell writes these to a file keybinds.lua reads, so applying a change reloads Hyprland. Mouse bindings are shown but cannot be rebound here.":
                "El shell los escribe en un archivo que lee keybinds.lua, así que aplicar un cambio recarga Hyprland. Los atajos del ratón se muestran, pero no se pueden reasignar aquí.",
            "Find a key or an action": "Busca una tecla o una acción",
            "No binding matches that": "Ningún atajo coincide",
            "Utilities": "Utilidades",
            "Other": "Otros",

            "Control centre": "Centro de control",
            "Colour picker": "Selector de color",
            "Capture a region": "Capturar una región",
            "Capture a window": "Capturar una ventana",
            "Capture the screen": "Capturar la pantalla",
            "Capture and annotate": "Capturar y anotar",
            "Read a region": "Leer una región",
            "Record the screen": "Grabar la pantalla",
            "Next module": "Módulo siguiente",
            "Previous module": "Módulo anterior",
            "Clock swap": "Cambiar el reloj",

            "unbound": "sin asignar",
            "Press a key…": "Pulsa una tecla…",
            "Click, then press a key": "Haz clic y pulsa una tecla",
            "Pick the key, and any modifiers to hold with it.":
                "Elige la tecla, y los modificadores que la acompañan.",
            "is already": "ya es",
            "Both would fire.": "Dispararían las dos.",

            // ── SESSION ─────────────────────────────────────────────────────
            "You": "Tú",
            "Picture": "Foto",
            "Click it, or drop an image here": "Haz clic, o suelta una imagen aquí",
            "Choose a picture": "Elige una foto",
            "Name": "Nombre",

            "Just enough to make the text underneath unreadable.":
                "Lo justo para que el texto de debajo no se pueda leer.",
            "The preview uses the wallpaper, since the lock screen's own capture is taken when it locks. It applies the same blur with the capsule on top, so you can judge how it reads.":
                "La vista previa usa el fondo, porque la captura de la pantalla de bloqueo se toma al bloquear. Aplica el mismo desenfoque con la cápsula encima, para que veas cómo se lee.",
            "No wallpaper to show": "No hay fondo que mostrar",
            "The login screen always draws it stacked.":
                "La pantalla de inicio siempre lo dibuja apilado.",
            "The login screen runs before anyone has signed in, so it cannot read your settings.":
                "La pantalla de inicio aparece antes de que nadie haya entrado, así que no puede leer tus ajustes.",
            "Stacked": "Apilado",
            "Inline": "En línea",
            "Type to unlock": "Escribe para desbloquear",

            "When you leave it alone": "Cuando lo dejas quieto",
            "All three are off by default.":
                "Los tres están desactivados por defecto.",
            "The shell uses the compositor's idle notifications, and media that inhibits idle (mpv, browsers) holds all three off. Set screen off after the lock, since the lock captures the screen as it starts; suspend always locks first and is skipped if the lock does not come up.":
                "El shell usa las notificaciones de inactividad del compositor, y lo que impide la inactividad (mpv, navegadores) frena los tres. Pon el apagado de pantalla después del bloqueo, porque el bloqueo captura la pantalla al activarse; suspender siempre bloquea antes, y no suspende si el bloqueo no llega a activarse.",
            "Never": "Nunca",
            "Lock after": "Bloquear tras",
            "Screen off after": "Apagar la pantalla tras",
            "before the lock": "antes del bloqueo",
            "Suspend after": "Suspender tras",

            // ── SYSTEM ──────────────────────────────────────────────────────
            "Changes are saved to the profile in use as you make them.":
                "Los cambios se guardan en el perfil en uso a medida que los haces.",
            "A profile holds the bar, widgets, dock, launcher, control centre, look, keys and wallpaper with its palette. Screens, your name and picture, language, weather location, GitHub user, Do not disturb and night light stay with the machine, and notes, tasks and clipboard are shared by every profile.":
                "Un perfil guarda la barra, los widgets, el dock, el lanzador, el centro de control, el aspecto, las teclas y el fondo con su paleta. Las pantallas, tu nombre y foto, el idioma, la ubicación del tiempo, el usuario de GitHub, No molestar y la luz nocturna se quedan con la máquina, y las notas, las tareas y el portapapeles son comunes a todos los perfiles.",
            "Profile": "Perfil",
            "New profile": "Perfil nuevo",
            "Import…": "Importar…",
            "In use": "En uso",
            "Switch": "Cambiar",
            "Delete": "Borrar",
            "Keep": "Conservar",
            "Rename": "Renombrar",
            "Duplicate": "Duplicar",
            "Export to a file…": "Exportar a un archivo…",
            "Export the profile": "Exportar el perfil",
            "Import a profile": "Importar un perfil",
            "Profiles (*.json)": "Perfiles (*.json)",
            "Deleted for good — there is no undo": "Se borra para siempre — no hay deshacer",
            "Enter to keep the name · Esc to leave it": "Intro para guardar el nombre · Esc para dejarlo",
            "Grouped bar": "Barra agrupada",
            "Spread bar": "Barra repartida",
            "dock at the bottom": "dock abajo",
            "dock on the left": "dock a la izquierda",
            "dock on the right": "dock a la derecha",
            "no dock": "sin dock",
            "nothing on the desk": "nada en el escritorio",
            "widget": "widget",
            "widgets": "widgets",

            "This window": "Esta ventana",
            "The language of this window.":
                "El idioma de esta ventana.",
            "Only the settings window is translated, and anything without a translation appears in English. Files the shell writes, such as generated themes, are always in English.":
                "Solo se traduce la ventana de ajustes, y lo que no tenga traducción aparece en inglés. Los archivos que escribe el shell, como los temas generados, van siempre en inglés.",
            "Language": "Idioma",

            "This machine": "Esta máquina",
            "PROCESSOR": "PROCESADOR",
            "MEMORY": "MEMORIA",
            "UPTIME": "ENCENDIDO",
            "VERSION": "VERSIÓN",
            "edited": "editado",
            "threads": "hilos",
            "% in use": "% en uso",
            "since boot": "desde el arranque",

            "impasto itself, not the packages it runs.":
                "impasto en sí, no los paquetes que usa.",
            "Update pulls the checkout impasto was installed from and runs the installer again in a terminal, where its questions and your password stay visible.":
                "Actualizar descarga el repositorio del que se instaló impasto y vuelve a ejecutar el instalador en una terminal, donde se ven sus preguntas y tu contraseña.",
            "Check for updates": "Buscar actualizaciones",
            "Check": "Buscar",
            "Checking…": "Buscando…",
            "Not checked yet": "Sin comprobar todavía",
            "The remote did not answer": "El remoto no respondió",
            "Up to date": "Al día",
            "checked at": "comprobado a las",
            "commit waiting": "commit esperando",
            "commits waiting": "commits esperando",
            "Update": "Actualizar",
            "To": "A",
            "Commits of your own are not on the remote":
                "Tienes commits que no están en el remoto",
            "No checkout to update from": "No hay repositorio del que actualizar",
            "No remote to compare with": "Sin remoto con el que comparar",
            "WHAT IS WAITING": "LO QUE ESPERA",
            "more": "más",

            "Changed files": "Archivos cambiados",
            "impasto's own files, as you left them.":
                "Los archivos de impasto, tal como los dejaste.",
            "Updates leave a file you deleted deleted, and a file you edited as you edited it, with any newer version beside it as .new. Restore puts impasto's version back; yours, if there was one, is kept in ~/.local/state/impasto/backups.":
                "Las actualizaciones no vuelven a poner un archivo que borraste, ni tocan uno que editaste: si hay una versión nueva, la dejan al lado como .new. Restaurar vuelve a poner la versión de impasto; la tuya, si la había, se guarda en ~/.local/state/impasto/backups.",
            "No checkout to restore from": "No hay repositorio del que restaurar",
            "Every file as installed": "Todo como se instaló",
            "file edited": "archivo editado",
            "files edited": "archivos editados",
            "file deleted": "archivo borrado",
            "files deleted": "archivos borrados",
            "Restore all": "Restaurar todo",
            "Restore": "Restaurar",
            "DELETED": "BORRADOS",
            "EDITED": "EDITADOS",
            "files": "archivos",
            "newer version waiting": "hay una versión nueva",
            "Keep mine": "Quedarme la mía",
            "Use the new one": "Usar la nueva",
            "Show all": "Ver los",
            "Show fewer": "Ver menos",

            "Face unlock": "Desbloqueo facial",
            "The lock screen only, with the infrared camera.":
                "Solo en la pantalla de bloqueo, con la cámara de infrarrojos.",
            "howdy keeps the faces where only root can read them, so adding or removing one asks for your password. The login screen, sudo and polkit still ask for the password.":
                "howdy guarda las caras donde solo root puede leerlas, así que añadir o quitar una pide tu contraseña. La pantalla de inicio de sesión, sudo y polkit siguen pidiendo la contraseña.",
            "Needs an infrared camera": "Necesita una cámara de infrarrojos",
            "Set up": "Configurar",
            "Finish setting up": "Terminar de configurar",
            "Add a face": "Añadir una cara",
            "Confirm with your password, then look at the camera":
                "Confirma con tu contraseña y mira a la cámara",
            "FACES": "CARAS",
            "Try it": "Probar",
            "Try": "Probar",
            "Looking…": "Mirando…",
            "Recognised": "Reconocida",
            "Not recognised": "No reconocida",
            "Not set up": "Sin configurar",
            "Half set up": "A medio configurar",
            "Adding a face…": "Añadiendo una cara…",
            "Removing…": "Quitando…",
            "Face added": "Cara añadida",
            "No face seen — try with more light": "No se vio ninguna cara: prueba con más luz",
            "More than one face in view": "Hay más de una cara a la vista",
            "Too dark for the camera": "Demasiado oscuro para la cámara",
            "The face was not added": "No se añadió la cara",
            "No face yet": "Ninguna cara todavía",
            "Face %1": "Cara %1",
            "%1 face": "%1 cara",
            "%1 faces": "%1 caras",

            "Your account's name and picture, on the lock and login screens.":
                "El nombre y la foto de tu cuenta, en la pantalla de bloqueo y en la de inicio de sesión.",
            "The name is your account's full name, and the picture is kept where the login screen reads it too, made square. Click the picture or drop an image on the card to change it.":
                "El nombre es el nombre completo de tu cuenta, y la foto se guarda, recortada en cuadrado, donde también la lee la pantalla de inicio de sesión. Haz clic en la foto o suelta una imagen en la tarjeta para cambiarla.",
            "Saving…": "Guardando…",
            "The picture was not changed": "La foto no se cambió",
            "The lock screen only, until ./setup system": "Solo en el bloqueo, hasta ./setup system",
            "On the lock and login screens": "En el bloqueo y en el inicio de sesión",

            "Only the profile in use. The others are left as they were.":
                "Solo el perfil en uso. Los demás se quedan como estaban.",
            "Reset returns every setting in this profile to its default, clears the compositor overrides and reloads Hyprland. Machine settings such as screens, name, picture and language are kept, and there is no undo.":
                "Restablecer devuelve cada ajuste de este perfil a su valor por defecto, borra los cambios aplicados al compositor y recarga Hyprland. Los ajustes de la máquina, como las pantallas, el nombre, la foto y el idioma, se conservan, y no se puede deshacer.",
            "Where the settings live": "Dónde viven los ajustes",
            "Reset this profile": "Restablecer este perfil",
            "Back to the defaults": "Volver a los valores por defecto",
            "A Hyprland shell, and the desk around it":
                "Un shell para Hyprland, y el escritorio alrededor",

            // ── INTEGRATIONS ────────────────────────────────────────────────
            "Integrations": "Integraciones",
            "The services the shell speaks to, and their keys.":
                "Los servicios con los que habla el shell, y sus claves.",
            "A self-hosted task board, folded into the board here.":
                "Un tablero de tareas autoalojado, integrado en el tablero de aquí.",
            "Enter the address of your Vikunja server and an API token from Vikunja's Settings → API tokens. Tasks are read from the server and your own changes are sent back; with no server set, the board stays local. The token is kept in the shell's settings file on this machine.":
                "Escribe la dirección de tu servidor Vikunja y un token de la API de Ajustes → Tokens de la API de Vikunja. Las tareas se leen del servidor y tus propios cambios se envían de vuelta; sin servidor, el tablero se queda local. El token se guarda en el archivo de ajustes del shell, en esta máquina.",
            "Server": "Servidor",
            "API token": "Token de la API",
            "Paste the token from Vikunja": "Pega el token de Vikunja",
            "Project": "Proyecto",
            "The first project": "El primer proyecto",
            "the first project": "el primer proyecto",
            "The first project the token owns": "El primer proyecto que tiene el token",
            "Sync": "Sincronización",
            "Set a server and a token first": "Configura antes un servidor y un token",
            "On — the board follows the server": "Activada: el tablero sigue al servidor",
            "Off — the board stays local": "Desactivada: el tablero se queda local",
            "Sync now": "Sincronizar ahora",
            "Refresh": "Actualizar",
            "Synced": "Sincronizado",
            "synced": "sincronizado",
            "Not syncing": "Sin sincronizar",
            "Reaching the server…": "Contactando con el servidor…",
            "reaching the server…": "contactando con el servidor…",
            "Local only — no server yet": "Solo local: aún no hay servidor",
            "task on the server": "tarea en el servidor",
            "tasks on the server": "tareas en el servidor",
            "just now": "ahora mismo",
            "min ago": "min",
            "h ago": "h",
            "Add a server and an API token": "Añade un servidor y un token de la API",
            "The token was refused": "El token fue rechazado",
            "The server did not answer": "El servidor no respondió",
            "No connection to the server": "Sin conexión con el servidor",
            "No project to put a task in": "No hay proyecto donde poner la tarea",
            "The change could not be sent": "No se pudo enviar el cambio",
            "Nothing on the board yet": "Nada en el tablero todavía",
            "task": "tarea",
            "tasks": "tareas",
            "open": "abiertas",
            "due today": "para hoy",
            "overdue": "atrasadas",

            // ── INTEGRATIONS · ASSISTANT USAGE ────────────────────────────────
            "Assistant usage": "Uso del asistente",
            "Tokens for the current block and the last seven days, read from the transcripts on this machine.":
                "Tokens del bloque actual y de los últimos siete días, leídos de las transcripciones de esta máquina.",
            "Nothing is sent anywhere: the numbers are counted from the transcripts each assistant already writes on disk. A block runs five hours from its first message, so the countdown to the reset is exact. Without a quota the ring shows how long the block has been running and no percentage is claimed, since a percentage of what? Put your plan's limits below and the bar is measured against them, and the face turns red as the block runs out.":
                "No se envía nada a ninguna parte: los números se cuentan a partir de las transcripciones que cada asistente ya escribe en disco. Un bloque dura cinco horas desde su primer mensaje, así que la cuenta atrás hasta el reinicio es exacta. Sin cuota, el anillo muestra cuánto lleva el bloque en marcha y no reclama ningún porcentaje, ¿un porcentaje de qué? Pon los límites de tu plan aquí abajo y la barra se mide contra ellos, y la cara se pone roja a medida que el bloque se agota.",
            "Transcripts": "Transcripciones",
            "Each assistant keeps its history in its own place, and the shell reads all the ones it knows. If yours lives somewhere else — a second machine's disk, an encrypted mount, a container — write the extra directories here, one per line, and they are read alongside the usual ones.":
                "Cada asistente guarda su historial en su sitio, y el shell lee todos los que conoce. Si el tuyo vive en otro lugar —el disco de otra máquina, un montaje cifrado, un contenedor— escribe aquí los directorios de más, uno por línea, y se leen junto a los de siempre.",
            "Where to read them, for a home directory that is not where the shell looks.":
                "Dónde leerlas, para un directorio personal que no es donde el shell mira.",
            "Extra directories": "Directorios extra",
            "No transcripts found": "No hay transcripciones",
            "every assistant found": "todos los asistentes encontrados",
            "This block": "Este bloque",
            "This week": "Esta semana",
            "tokens": "tokens",
            "tokens per block": "tokens por bloque",
            "tokens a week": "tokens por semana",
            "models": "modelos",
            "in this block": "en este bloque",
            "OmniRoute": "OmniRoute",
            "A gateway, asked what plan it is on.":
                "Una pasarela, a la que se le pregunta por qué plan va.",
            "Endpoint": "Endpoint",
            "https://gateway.example.com/v1": "https://pasarela.ejemplo.com/v1",
            "API key": "Clave de la API",
            "The key the gateway issued": "La clave que emitió la pasarela",
            "Ask it": "Preguntárselo",
            "Asking\u2026": "Preguntando\u2026",
            "Ask it now": "Preguntárselo ahora",
            "this block": "este bloque",
            "this week": "esta semana",
            "nothing read yet": "nada leído todavía",
            "%1 of the busiest on record":
                "%1 de la más ocupada de las registradas",
            "STATE": "ESTADO",
            "asleep": "dormido",
            "going in": "entrando",
            "coming out": "saliendo",
            "battery reported": "carga informada",
            "no battery report": "sin informe de carga",
            "Phone": "Teléfono",
            "idle": "inactivo",
            "low": "bajo",
            "no transcripts found": "no hay transcripciones",
            "From the desk": "Desde el escritorio",
            "charging": "cargando",
            "pi's logs": "los registros de pi",
            "/mnt/work/agents, /srv/logs/codex": "/mnt/work/agents, /srv/logs/codex",
            "~/.pi/agent/sessions": "~/.pi/agent/sessions",
            // ── INTEGRATIONS · THE PHONE ────────────────────────────────────────
            "Paired phone": "Teléfono emparejado",
            "The phone on this network, and what it will do when asked.":
                "El teléfono de esta red, y lo que hará cuando se le pida.",
            "KDE Connect pairs over the local network and does not need a server or an account. The phone's charge takes the ring on the bar beside the laptop's own battery, and the module's buttons are the things this particular pairing offers — a phone that refuses to be rung is not shown a bell. Music played on the phone can take over the desk's player, so the keys and the bar control it as if it were local.":
                "KDE Connect se empareja por la red local y no necesita servidor ni cuenta. La carga del teléfono ocupa el anillo de la barra junto a la batería del propio portátil, y los botones del módulo son lo que ofrece este emparejamiento en concreto: a un teléfono al que no se pueda llamar no se le enseña una campana. La música que suene en el teléfono puede tomar el reproductor del escritorio, así que las teclas y la barra la controlan como si fuera local.",
            "The one that answers": "El que conteste",
            "phone": "teléfono",
            "tablet": "tableta",
            "Phone": "Teléfono",
            "KDE Connect is not running": "KDE Connect no está en marcha",
            "No paired phone": "Ningún teléfono emparejado",
            "Not paired": "Sin emparejar",
            "That phone is not paired": "Ese teléfono no está emparejado",
            "The phone is out of reach": "El teléfono no está al alcance",
            "out of reach": "no está al alcance",
            "not connected": "sin conexión",
            "Find it": "Encontrarlo",
            "Ping": "Ping",
            "No battery report": "Sin informe de batería",
            "Shared clipboard": "Portapapeles compartido",
            "Off — the two clipboards stay apart":
                "No: los dos porta papeleles se quedan separados",
            "A copy on the phone lands here, and the button sends this desk's back":
                "Lo que copies en el teléfono aparece aquí, y el botón envía el de este escritorio al revés",
            "The phone's music": "La música del teléfono",
            "Not playing on the phone": "No suena en el teléfono",
            // ── INTEGRATIONS · THE GALLERY ──────────────────────────────────────
            "Browse asks the source for pictures on the topic and fills the gallery below; pick one to fetch it into your wallpapers and apply it, and the palette follows the new picture. Two of the sources are free and need no account; Unsplash and Pexels search properly with a key from their developers' pages, which is kept on this machine. The width is what the panel is about to fill, so a source is never asked for a picture smaller than the screen.":
                "Buscar pide a la fuente fotos del tema y llena la galería de abajo; elige una para descargarla a tus fondos y aplicarla, y la paleta sigue a la nueva foto. Dos de las fuentes son gratis y no necesitan cuenta; Unsplash y Pexels buscan bien con una clave de las páginas de sus desarrolladores, que se guarda en esta máquina. La anchura es la que el panel está a punto de llenar, así que nunca se le pide a una fuente una foto más pequeña que la pantalla.",
            "Photographs from whichever source you name, at the width your screens are.":
                "Fotos de la fuente que nombres, a la anchura de tus pantallas.",
            "Width": "Anchura",
            "Browse": "Explorar",
            "Browse again for another set": "Explorar otro conjunto",
            "No source yet": "Aún sin fuente",
            "This source needs a key": "Esta fuente necesita una clave",
            "From the source's developers' page":
                "De la página de los desarrolladores de la fuente",
            "Reaching the source…": "Contactando con la fuente…",
            "The source did not answer": "La fuente no respondió",
            "Nothing that size for that topic": "Nada de ese tamaño para ese tema",
            // ── GOOGLE CALENDAR ───────────────────────────────────────────
            "The script could not be run": "No se pudo ejecutar el script",
            "Add the client id and secret": "Añade el id y el secreto del cliente",
            "Connect once in the browser": "Conecta una vez en el navegador",
            "Google refused the key": "Google rechazó la clave",
            "Google did not answer": "Google no respondió",
            "No connection to Google": "Sin conexión con Google",
            "Set a client id and secret first": "Pon primero el id y el secreto del cliente",
            "Connected": "Conectado",
            "the token is on this machine": "el token está en esta máquina",
            "Not connected yet": "Aún sin conectar",
            "Local only — no client yet": "Solo local: aún no hay cliente",
            "Off — the calendar stays local": "No: el calendario se queda local",
            "Not reading": "Sin leer",
            "Reaching Google…": "Contactando con Google…",
            "event in view": "evento a la vista",
            "events in view": "eventos a la vista",
            "Your days, folded in beside the tasks.": "Tus días, junto a las tareas.",
            "Make an OAuth client of the desktop kind in Google Cloud Console (APIs & Services → Credentials), with the Calendar API enabled, and paste its id and secret here. Connecting opens the browser once to agree; the refresh token is kept in the shell's state on this machine and never in the settings file. Read-only: the shell writes nothing to your calendar.":
                "Crea un cliente OAuth de tipo escritorio en Google Cloud Console (APIs y servicios → Credenciales), con la API de Calendar activada, y pega aquí su id y su secreto. Conectar abre el navegador una vez para dar el permiso; el token de renovación se guarda en el estado del shell, en esta máquina, y nunca en el archivo de ajustes. Solo lectura: el shell no escribe nada en tu calendario.",
            "Client id": "Id del cliente",
            "Client secret": "Secreto del cliente",
            "Paste the client secret": "Pega el secreto del cliente",
            "Calendar": "Calendario",
            "Connection": "Conexión",
            "Connect": "Conectar",
            "Disconnect": "Desconectar",
            "On — events come down and are read": "Sí: los eventos bajan y se leen",
            "event": "evento",
            "events": "eventos",
            "(untitled event)": "(evento sin título)",

            // ── WALLPAPER GALLERY ───────────────────────────────────────────
            "Wallpaper gallery": "Galería de fondos",
            "Photographs from Unsplash — or Picsum, free and keyless.":
                "Fotografías de Unsplash —o Picsum, gratis y sin clave.",
            "Browse asks the provider for pictures on the topic and fills the gallery below; pick one to fetch it into your wallpapers and apply it, and the palette follows the new picture. An access key from unsplash.com/developers turns the topic into a real search; without one, Picsum serves a curated pick and the topic only seeds it. The key is kept on this machine.":
                "Explorar pide al proveedor imágenes del tema y llena la galería de abajo; elige una para traerla a tus fondos y aplicarla, y la paleta seguirá a la nueva imagen. Una clave de unsplash.com/developers convierte el tema en una búsqueda real; sin ella, Picsum sirve una selección curada y el tema solo la siembra. La clave se guarda en esta máquina.",
            "Topic": "Tema",
            "nature, fog, brutalism…": "naturaleza, niebla, brutalismo…",
            "Access key": "Clave de acceso",
            "Optional — from unsplash.com/developers": "Opcional: de unsplash.com/developers",
            "Gallery": "Galería",
            "Reaching the provider…": "Contactando con el proveedor…",
            "The key was refused — check it and browse again":
                "La clave fue rechazada — revísala y vuelve a explorar",
            "No provider yet": "Aún sin proveedor",
            "The provider did not answer": "El proveedor no respondió",
            "Picsum — free, no key; add an Unsplash key for topics":
                "Picsum — gratis, sin clave; añade una clave de Unsplash para temas",
            "Unsplash — your key, your topic": "Unsplash — tu clave, tu tema",
            "Browse to fill the gallery": "Explora para llenar la galería",
            "Browse": "Explorar",
            "Shuffle": "Mezclar",
            "Fetch & apply": "Traer y aplicar",
            "Fetching": "Traendo",
            "Browse first, then pick": "Primero explora, luego elige",
            "Pick a picture below": "Elige una imagen abajo",
            "Shuffle wallpaper": "Fondo al azar",
            "Stop fetching": "Parar la descarga",
            "Stop": "Parar",

            // ── ACTIVITY ────────────────────────────────────────────────────
            "Activity": "Actividad",
            "Whose year of work to draw: GitHub, LeetCode, Codeforces or GitLab.":
                "De quién dibujar el año de trabajo: GitHub, LeetCode, Codeforces o GitLab.",
            "Each is read from its public profile, so no token or account is needed. With more than one handle set, the widget's toggle picks which wall is drawn — or All, which adds them together and caps the sum. With one set, that one is drawn.":
                "Cada uno se lee de su perfil público, así que no hace falta token ni cuenta. Con más de un usuario configurado, el interruptor del widget elige qué muro se dibuja —o All, que los suma y limita el total. Con uno solo, se dibuja ese.",
            "No GitHub, LeetCode, Codeforces or GitLab user set":
                "Sin usuario de GitHub, LeetCode, Codeforces o GitLab",
            "All": "Todo",
            "GitHub": "GitHub",
            "LeetCode": "LeetCode",
            "Codeforces": "Codeforces",
            "GitLab": "GitLab"
        }
    })
}
