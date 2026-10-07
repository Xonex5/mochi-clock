import QtQuick
import QtQuick.Shapes
import qs.island
import "ClockHelper.js" as ClockHelper

// Dedicated Hub Page view for Clock, Stopwatch, and Timer
Item {
    id: root

    property var payload: null
    readonly property string mode: payload?.mode ?? "timer"
    readonly property var clock: payload?.clock ?? ({})
    readonly property var stopwatch: payload?.stopwatch ?? ({})
    readonly property var timer: payload?.timer ?? ({})
    readonly property var activeTimers: timer.active_timers ?? []
    readonly property int alarmVolume: timer.volume ?? 80
    readonly property var laps: stopwatch.laps ?? []
    readonly property var history: stopwatch.history ?? []
    readonly property var worldClocks: clock.world_clocks ?? ({})
    readonly property var availableCities: clock.available_cities ?? []

    property bool use12hFormat: false
    property int timerMinutes: 5
    property int timerSeconds: 0
    property bool timerInitDone: false

    onTimerChanged: {
        if (!timerInitDone && root.timer?.default_minutes) {
            timerMinutes = root.timer.default_minutes;
            timerInitDone = true;
        }
    }

    function formatClockTime(h, m, s, is12h) {
        if (h === undefined || m === undefined || s === undefined) return "00:00:00";
        const mm = String(m).padStart(2, '0');
        const ss = String(s).padStart(2, '0');
        if (!is12h) {
            return `${String(h).padStart(2, '0')}:${mm}:${ss}`;
        }
        const h12 = (h % 12) === 0 ? 12 : (h % 12);
        const ampm = h >= 12 ? "PM" : "AM";
        return `${h12}:${mm}:${ss} ${ampm}`;
    }

    function formatCityTime(h, m, fallback, is12h) {
        if (h === undefined || m === undefined) return fallback ?? "00:00:00";
        if (!is12h) return fallback ?? "00:00:00";
        const h12 = (h % 12) === 0 ? 12 : (h % 12);
        const mm = String(m).padStart(2, '0');
        const ampm = h >= 12 ? "PM" : "AM";
        return `${h12}:${mm} ${ampm}`;
    }

    component DayNightIcon: Item {
        id: dni
        property bool isDay: true
        property real size: 16
        implicitWidth: size
        implicitHeight: size

        Symbol {
            visible: !dni.isDay
            anchors.centerIn: parent
            name: "moon"
            size: dni.size
            color: Theme.muted
        }

        Shape {
            visible: dni.isDay
            anchors.centerIn: parent
            width: 24
            height: 24
            scale: dni.size / 24
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.accent
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: "M12 8a4 4 0 1 0 0 8a4 4 0 1 0 0-8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"
                }
            }
        }
    }

    // Selected cities for World Clock
    property var selectedCities: root.clock.selected_cities ?? ["paris", "tokyo", "new_york"]
    onClockChanged: {
        if (root.clock?.selected_cities) {
            selectedCities = root.clock.selected_cities;
        }
    }

    property bool isSearchingCity: false
    property string citySearchText: ""

    readonly property var filteredCities: {
        const query = root.citySearchText.trim().toLowerCase();
        if (!query) return root.availableCities;
        return root.availableCities.filter(item => {
            const c = (item.city ?? "").toLowerCase();
            const co = (item.country ?? "").toLowerCase();
            return c.indexOf(query) !== -1 || co.indexOf(query) !== -1;
        });
    }

    property string stopwatchSubTab: "laps" // "laps" or "history"

    implicitWidth: 832
    implicitHeight: 480
    height: implicitHeight

    focus: true

    function toggleCity(cityId) {
        const idx = selectedCities.indexOf(cityId);
        if (idx >= 0) {
            Daemon.command("chrono", "clock_remove_city", [cityId]);
            const next = selectedCities.slice();
            next.splice(idx, 1);
            selectedCities = next;
        } else {
            Daemon.command("chrono", "clock_add_city", [cityId]);
            selectedCities = selectedCities.concat([cityId]);
        }
    }

    function startTimerWithText(text) {
        if (!text || text.trim() === "") return false;
        Daemon.command("chrono", "timer_start", [text.trim()]);
        return true;
    }

    // Keyboard shortcuts for Stopwatch (only in this Page, not in Home)
    Keys.onSpacePressed: (event) => {
        if (root.mode === "stopwatch") {
            Daemon.command("chrono", "stopwatch_pause", []);
            event.accepted = true;
        }
    }

    Keys.onPressed: (event) => {
        if (root.mode === "stopwatch") {
            if (event.key === Qt.Key_L) {
                Daemon.command("chrono", "stopwatch_lap", []);
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                Daemon.command("chrono", "stopwatch_reset", []);
                event.accepted = true;
            }
        }
    }

    // Tab bar navigation
    Segmented {
        id: nav

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, 420)
        height: 38
        color: Theme.raised
        options: [
            { "value": "clock", "label": "Clock", "icon": "clock" },
            { "value": "stopwatch", "label": "Stopwatch", "icon": "clock" },
            { "value": "timer", "label": "Timer", "icon": "bell" }
        ]
        current: root.mode
        onPicked: value => Daemon.command("chrono", "mode", [value])
    }

    // ================= CLOCK VIEW (Centered Hero & World Clocks Picker) =================
    Item {
        visible: root.mode === "clock"
        anchors.top: nav.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        // Left Panel: Centered Hero Local Time
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: (parent.width - 16) * 0.44
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 36
                        spacing: 18

                        // Local Time Badge Pill
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 26
                            radius: 13
                            color: Theme.raised
                            implicitWidth: localBadgeRow.implicitWidth + 20

                            Row {
                                id: localBadgeRow
                                anchors.centerIn: parent
                                spacing: 6

                                Symbol {
                                    name: "clock"
                                    size: 13
                                    color: Theme.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Local Time"
                                    color: Theme.foreground
                                    font.pixelSize: Theme.textCaption
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Huge Digital Clock & Date
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.formatClockTime(root.clock.hours, root.clock.minutes, root.clock.seconds, root.use12hFormat)
                                color: Theme.foreground
                                font.pixelSize: root.use12hFormat ? Theme.textDisplay * 1.25 : Theme.textDisplay * 1.45
                                font.family: Theme.displayFamily
                                font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.clock.date ?? ""
                                color: Theme.muted
                                font.pixelSize: Theme.textSubtitle
                                font.family: Theme.fontFamily
                            }
                        }

                        // Time Format Switcher (12h AM/PM vs 24h)
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: 62
                            radius: Theme.radiusMedium
                            color: Theme.raised

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 24
                                spacing: 6

                                Text {
                                    text: "Time Format"
                                    color: Theme.muted
                                    font.pixelSize: Theme.textCaption
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Medium
                                }

                                Segmented {
                                    width: parent.width
                                    height: 28
                                    color: Theme.surface
                                    options: [
                                        { "value": "24h", "label": "24-Hour" },
                                        { "value": "12h", "label": "12-Hour (AM/PM)" }
                                    ]
                                    current: root.use12hFormat ? "12h" : "24h"
                                    onPicked: value => { root.use12hFormat = (value === "12h"); }
                                }
                            }
                        }
                    }
                }

        // Right Panel: World Clocks with + Button & Search Picker
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: (parent.width - 16) * 0.56
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        // Header with Title, Count badge, and + / Done Button
                        Item {
                            width: parent.width
                            height: 32

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    text: root.isSearchingCity ? "Choose Country / City" : "World Clocks"
                                    color: Theme.foreground
                                    font.pixelSize: Theme.textBody
                                    font.family: Theme.fontFamily
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    visible: !root.isSearchingCity && root.selectedCities.length > 0
                                    height: 20
                                    radius: 10
                                    color: Theme.raised
                                    implicitWidth: cityCountText.implicitWidth + 12
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: cityCountText
                                        anchors.centerIn: parent
                                        text: `${root.selectedCities.length}`
                                        color: Theme.muted
                                        font.pixelSize: Theme.textCaption
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }

                            Button {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                icon: root.isSearchingCity ? "close" : "plus"
                                text: root.isSearchingCity ? "Done" : ""
                                tone: root.isSearchingCity ? "neutral" : "accent"
                                onClicked: {
                                    root.isSearchingCity = !root.isSearchingCity;
                                    if (!root.isSearchingCity) {
                                        root.citySearchText = "";
                                    }
                                }
                            }
                        }

                        // Search Field (Visible only when searching)
                        Rectangle {
                            visible: root.isSearchingCity
                            width: parent.width
                            height: 34
                            radius: 17
                            color: Theme.raised

                            Symbol {
                                id: searchIcon
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                name: "search"
                                size: 14
                                color: Theme.muted
                            }

                            TextInput {
                                id: searchInput
                                anchors.left: searchIcon.right
                                anchors.leftMargin: 8
                                anchors.right: clearSearchBtn.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.foreground
                                selectionColor: Theme.accent
                                font.pixelSize: Theme.textBody
                                font.family: Theme.fontFamily
                                clip: true
                                text: root.citySearchText
                                onTextChanged: root.citySearchText = text

                                Text {
                                    visible: searchInput.text === ""
                                    text: "Search country or city (e.g. Japan, London)..."
                                    color: Theme.muted
                                    font: searchInput.font
                                }
                            }

                            Button {
                                id: clearSearchBtn
                                visible: searchInput.text !== ""
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "close"
                                tone: "ghost"
                                iconSize: 12
                                implicitHeight: 26
                                onClicked: {
                                    searchInput.text = "";
                                    root.citySearchText = "";
                                }
                            }
                        }

                        // Main Content Area (Picker list OR Active clocks list)
                        Item {
                            width: parent.width
                            height: parent.height - (root.isSearchingCity ? 86 : 42)

                            // --- VIEW 1: Country / City Picker (When user clicked +) ---
                            Item {
                                visible: root.isSearchingCity
                                anchors.fill: parent

                                Text {
                                    visible: root.filteredCities.length === 0
                                    anchors.centerIn: parent
                                    text: "No matching country or city found"
                                    color: Theme.muted
                                    font.pixelSize: Theme.textCaption
                                    font.family: Theme.fontFamily
                                }

                                ListView {
                                    visible: root.filteredCities.length > 0
                                    anchors.fill: parent
                                    clip: true
                                    spacing: 6
                                    model: root.filteredCities

                                    delegate: Rectangle {
                                        id: pickerItemCard
                                        readonly property bool isAdded: root.selectedCities.indexOf(modelData.id) >= 0

                                        width: parent.width
                                        height: 44
                                        radius: Theme.radiusSmall
                                        color: isAdded ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) : Theme.raised

                                        Item {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 8

                                            Column {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2

                                                Text {
                                                    text: modelData.city
                                                    color: Theme.foreground
                                                    font.pixelSize: Theme.textBody
                                                    font.family: Theme.fontFamily
                                                    font.weight: Font.DemiBold
                                                }

                                                Text {
                                                    text: modelData.country
                                                    color: Theme.muted
                                                    font.pixelSize: Theme.textCaption
                                                    font.family: Theme.fontFamily
                                                }
                                            }

                                            Button {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: pickerItemCard.isAdded ? "Added" : "Add"
                                                icon: pickerItemCard.isAdded ? "check" : "plus"
                                                tone: pickerItemCard.isAdded ? "ghost" : "accent"
                                                onClicked: root.toggleCity(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }

                            // --- VIEW 2: Selected World Clocks List (No predefined chips) ---
                            Item {
                                visible: !root.isSearchingCity
                                anchors.fill: parent

                                // Empty State: Centered placeholder with Add button
                                Column {
                                    visible: root.selectedCities.length === 0
                                    anchors.centerIn: parent
                                    spacing: 12

                                    Symbol {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        name: "clock"
                                        size: 32
                                        color: Theme.muted
                                    }

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 4

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "No world clocks added"
                                            color: Theme.foreground
                                            font.pixelSize: Theme.textBody
                                            font.family: Theme.fontFamily
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "Click + to choose a country or city"
                                            color: Theme.muted
                                            font.pixelSize: Theme.textCaption
                                            font.family: Theme.fontFamily
                                        }
                                    }

                                    Button {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        icon: "plus"
                                        text: "Add Clock"
                                        tone: "accent"
                                        onClicked: root.isSearchingCity = true
                                    }
                                }

                                // Populated Clocks ListView
                                ListView {
                                    visible: root.selectedCities.length > 0
                                    anchors.fill: parent
                                    clip: true
                                    spacing: 6
                                    model: root.selectedCities

                                    delegate: Rectangle {
                                        id: cityClockCard
                                        readonly property var cityData: root.worldClocks[modelData] ?? ({})
                                        readonly property int cityHours: cityClockCard.cityData.hours ?? 12
                                        readonly property bool isDay: cityHours >= 6 && cityHours < 20

                                        width: parent.width
                                        height: 52
                                        radius: Theme.radiusMedium
                                        color: Theme.raised

                                        Item {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 8

                                            Column {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2

                                                Text {
                                                    text: cityClockCard.cityData.city ?? modelData
                                                    color: Theme.foreground
                                                    font.pixelSize: Theme.textBody
                                                    font.family: Theme.fontFamily
                                                    font.weight: Font.DemiBold
                                                }

                                                Text {
                                                    text: `${cityClockCard.cityData.country ?? ""} · ${cityClockCard.cityData.relative_day ?? "Today"}, ${cityClockCard.cityData.offset ?? ""}`
                                                    color: Theme.muted
                                                    font.pixelSize: Theme.textCaption
                                                    font.family: Theme.fontFamily
                                                }
                                            }

                                            Row {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 8

                                                DayNightIcon {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    isDay: cityClockCard.isDay
                                                    size: 16
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.formatCityTime(cityClockCard.cityData.hours, cityClockCard.cityData.minutes, cityClockCard.cityData.time, root.use12hFormat)
                                                    color: Theme.accent
                                                    font.pixelSize: root.use12hFormat ? Theme.textHeadline * 0.9 : Theme.textHeadline
                                                    font.family: Theme.displayFamily
                                                    font.weight: Font.Bold
                                                    font.features: { "tnum": 1 }
                                                }

                                                Button {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    icon: "close"
                                                    tone: "ghost"
                                                    onClicked: root.toggleCity(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
        }

        // ================= STOPWATCH VIEW (Hero & Laps/History) =================
        Item {
            visible: root.mode === "stopwatch"
            anchors.top: nav.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            // Left Panel: Centered Hero Stopwatch & Controls
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: (parent.width - 16) * 0.44
                radius: Theme.radiusLarge
                color: Theme.surface
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 36
                    spacing: 18

                    // Status Pill Badge
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 26
                        radius: 13
                        color: Theme.raised
                        implicitWidth: swBadgeRow.implicitWidth + 20

                        Row {
                            id: swBadgeRow
                            anchors.centerIn: parent
                            spacing: 6

                            Symbol {
                                name: "clock"
                                size: 13
                                color: root.stopwatch.running ? (root.stopwatch.paused ? Theme.muted : Theme.accent) : Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: !root.stopwatch.running ? "Stopwatch" : (root.stopwatch.paused ? "Paused" : "Running")
                                color: Theme.foreground
                                font.pixelSize: Theme.textCaption
                                font.family: Theme.fontFamily
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Huge Digital Time
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.stopwatch.formatted ?? "00:00.0"
                        color: Theme.foreground
                        font.pixelSize: Theme.textDisplay * 1.45
                        font.family: Theme.displayFamily
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }

                    // Action Buttons Row
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Button {
                            visible: !root.stopwatch.running
                            text: "Start"
                            icon: "play"
                            tone: "accent"
                            onClicked: Daemon.command("chrono", "stopwatch_start", [])
                        }

                        Button {
                            visible: root.stopwatch.running
                            text: root.stopwatch.paused ? "Resume" : "Pause"
                            icon: root.stopwatch.paused ? "play" : "pause"
                            tone: root.stopwatch.paused ? "accent" : "neutral"
                            onClicked: Daemon.command("chrono", "stopwatch_pause", [])
                        }

                        Button {
                            visible: root.stopwatch.running && !root.stopwatch.paused
                            text: "Lap"
                            icon: "plus"
                            tone: "neutral"
                            onClicked: Daemon.command("chrono", "stopwatch_lap", [])
                        }

                        Button {
                            visible: root.stopwatch.running
                            text: "Reset"
                            icon: "stop"
                            tone: "danger"
                            onClicked: Daemon.command("chrono", "stopwatch_reset", [])
                        }
                    }

                    // Keyboard Shortcuts Card
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        radius: Theme.radiusMedium
                        color: Theme.raised
                        implicitHeight: shortcutsCol.implicitHeight + 20

                        Column {
                            id: shortcutsCol
                            width: parent.width - 24
                            anchors.centerIn: parent
                            spacing: 8

                            // Header with column labels
                            Item {
                                width: parent.width
                                height: 16

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Shortcuts"
                                    color: Theme.muted
                                    font.pixelSize: Theme.textCaption
                                    font.family: Theme.fontFamily
                                    font.weight: Font.DemiBold
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 16

                                    Text {
                                        text: "In-App"
                                        color: Theme.muted
                                        font.pixelSize: Theme.textCaption
                                        font.family: Theme.fontFamily
                                        width: 50
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        text: "Global"
                                        color: Theme.muted
                                        font.pixelSize: Theme.textCaption
                                        font.family: Theme.fontFamily
                                        width: 100
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.06)
                            }

                            // Row 1: Start / Pause
                            Item {
                                width: parent.width
                                height: 22

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Start / Pause"
                                    color: Theme.foreground
                                    font.pixelSize: Theme.textCaption
                                    font.family: Theme.fontFamily
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 16

                                    Item {
                                        width: 50
                                        height: 20
                                        Kbd {
                                            anchors.centerIn: parent
                                            key: "Space"
                                        }
                                    }

                                    Item {
                                        width: 100
                                        height: 20
                                        Kbd {
                                            anchors.centerIn: parent
                                            key: "Super+K"
                                            textColor: Theme.accent
                                        }
                                    }
                                }
                            }

                            // Row 2: Record Lap
                            Item {
                                width: parent.width
                                height: 22

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Record lap"
                                    color: Theme.foreground
                                    font.pixelSize: Theme.textCaption
                                    font.family: Theme.fontFamily
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 16

                                    Item {
                                        width: 50
                                        height: 20
                                        Kbd {
                                            anchors.centerIn: parent
                                            key: "L"
                                        }
                                    }

                                    Item {
                                        width: 100
                                        height: 20
                                        Kbd {
                                            anchors.centerIn: parent
                                            key: "Super+Shift+K"
                                            textColor: Theme.accent
                                        }
                                    }
                                }
                            }

                            // Row 3: Reset
                            Item {
                                width: parent.width
                                height: 22

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Reset"
                                    color: Theme.foreground
                                    font.pixelSize: Theme.textCaption
                                    font.family: Theme.fontFamily
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 16

                                    Item {
                                        width: 50
                                        height: 20
                                        Kbd {
                                            anchors.centerIn: parent
                                            key: "R"
                                        }
                                    }

                                    Item {
                                        width: 100
                                        height: 20
                                        Kbd {
                                            anchors.centerIn: parent
                                            key: "Super+Ctrl+R"
                                            textColor: Theme.danger
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Right Panel: Laps & History Card
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: (parent.width - 16) * 0.56
                radius: Theme.radiusLarge
                color: Theme.surface
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // Sub-tabs: Current Laps vs History + Export
                    Item {
                        width: parent.width
                        height: 32

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Button {
                                text: `Laps (${root.laps.length})`
                                tone: root.stopwatchSubTab === "laps" ? "accent" : "ghost"
                                onClicked: root.stopwatchSubTab = "laps"
                            }

                            Button {
                                text: `History (${root.history.length})`
                                tone: root.stopwatchSubTab === "history" ? "accent" : "ghost"
                                onClicked: root.stopwatchSubTab = "history"
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Button {
                                visible: root.stopwatchSubTab === "history" && root.history.length > 0
                                text: "Clear"
                                icon: "trash"
                                tone: "ghost"
                                onClicked: Daemon.command("chrono", "stopwatch_clear_history", [])
                            }

                            Button {
                                text: "Export"
                                icon: "copy"
                                tone: "ghost"
                                onClicked: Daemon.command("chrono", "stopwatch_export", [])
                            }
                        }
                    }

                    // Main List Content Area (Laps OR History)
                    Item {
                        width: parent.width
                        height: parent.height - 42

                        // Laps View
                        Item {
                            visible: root.stopwatchSubTab === "laps"
                            anchors.fill: parent

                            // Empty State
                            Column {
                                visible: root.laps.length === 0
                                anchors.centerIn: parent
                                spacing: 12

                                Symbol {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: "clock"
                                    size: 32
                                    color: Theme.muted
                                }

                                Column {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "No laps recorded yet"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.textBody
                                        font.family: Theme.fontFamily
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Press [L] or Super+Shift+K while running"
                                        color: Theme.muted
                                        font.pixelSize: Theme.textCaption
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }

                            ListView {
                                visible: root.laps.length > 0
                                anchors.fill: parent
                                clip: true
                                model: root.laps.slice().reverse()
                                spacing: 6

                                delegate: Rectangle {
                                    width: parent.width
                                    height: 38
                                    radius: Theme.radiusSmall
                                    color: Theme.raised

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: `Lap ${modelData.index}`
                                            color: Theme.foreground
                                            font.pixelSize: Theme.textBody
                                            font.family: Theme.fontFamily
                                            font.weight: Font.Medium
                                        }

                                        Row {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 14

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: `+${modelData.formatted_split}`
                                                color: Theme.accent
                                                font.pixelSize: Theme.textCaption
                                                font.family: Theme.fontFamily
                                                font.features: { "tnum": 1 }
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.formatted_total
                                                color: Theme.foreground
                                                font.pixelSize: Theme.textHeadline
                                                font.family: Theme.displayFamily
                                                font.weight: Font.Bold
                                                font.features: { "tnum": 1 }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // History View
                        Item {
                            visible: root.stopwatchSubTab === "history"
                            anchors.fill: parent

                            // Empty State
                            Column {
                                visible: root.history.length === 0
                                anchors.centerIn: parent
                                spacing: 12

                                Symbol {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: "clock"
                                    size: 32
                                    color: Theme.muted
                                }

                                Column {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "No history yet"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.textBody
                                        font.family: Theme.fontFamily
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Resetting a completed run will save it here"
                                        color: Theme.muted
                                        font.pixelSize: Theme.textCaption
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }

                            ListView {
                                visible: root.history.length > 0
                                anchors.fill: parent
                                clip: true
                                model: root.history
                                spacing: 6

                                delegate: Rectangle {
                                    width: parent.width
                                    height: 44
                                    radius: Theme.radiusSmall
                                    color: Theme.raised

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12

                                        Column {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2

                                            Text {
                                                text: `Run #${modelData.index} · ${modelData.lap_count} laps`
                                                color: Theme.foreground
                                                font.pixelSize: Theme.textBody
                                                font.family: Theme.fontFamily
                                                font.weight: Font.DemiBold
                                            }

                                            Text {
                                                text: modelData.timestamp
                                                color: Theme.muted
                                                font.pixelSize: Theme.textCaption
                                                font.family: Theme.fontFamily
                                            }
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.formatted_total
                                            color: Theme.accent
                                            font.pixelSize: Theme.textHeadline
                                            font.family: Theme.displayFamily
                                            font.weight: Font.Bold
                                            font.features: { "tnum": 1 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ================= TIMER VIEW (Multi-timers, Volume Control & Presets) =================
        Item {
            visible: root.mode === "timer"
            anchors.top: nav.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            // Left Panel: Ready Ring (when idle) or Active Timers List
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: (parent.width - 16) * 0.44
                radius: Theme.radiusLarge
                color: Theme.surface
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                clip: true

                // Idle State (No Timers Running)
                Column {
                    visible: root.activeTimers.length === 0
                    anchors.centerIn: parent
                    width: parent.width - 36
                    spacing: 18

                    // Timer Status Pill Badge
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 26
                        radius: 13
                        color: Theme.raised
                        implicitWidth: timerBadgeRow.implicitWidth + 20

                        Row {
                            id: timerBadgeRow
                            anchors.centerIn: parent
                            spacing: 6

                            Symbol {
                                name: "bell"
                                size: 13
                                color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Timer"
                                color: Theme.foreground
                                font.pixelSize: Theme.textCaption
                                font.family: Theme.fontFamily
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Hero Circular Countdown Ring (Interactive scroll on MM & SS)
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 146
                        height: 146

                        Ring {
                            anchors.fill: parent
                            line: 6
                            color: (minArea.containsMouse || secArea.containsMouse) ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7)
                            progress: 1
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            // Digits row: MM : SS
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 2

                                // Minutes zone
                                Item {
                                    id: minBox
                                    width: minText.implicitWidth + 8
                                    height: minText.implicitHeight + 4

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radiusSmall
                                        color: minArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent"
                                    }

                                    Text {
                                        id: minText
                                        anchors.centerIn: parent
                                        text: String(root.timerMinutes).padStart(2, '0')
                                        color: minArea.containsMouse ? Theme.accent : Theme.foreground
                                        font.pixelSize: Theme.textTitle * 1.35
                                        font.family: Theme.displayFamily
                                        font.weight: Font.Bold
                                        font.features: { "tnum": 1 }
                                    }

                                    MouseArea {
                                        id: minArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onWheel: (wheel) => {
                                            if (wheel.angleDelta.y > 0) {
                                                root.timerMinutes = Math.min(999, root.timerMinutes + 1);
                                            } else if (wheel.angleDelta.y < 0) {
                                                root.timerMinutes = Math.max(0, root.timerMinutes - 1);
                                            }
                                            wheel.accepted = true;
                                        }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ":"
                                    color: Theme.muted
                                    font.pixelSize: Theme.textTitle * 1.35
                                    font.family: Theme.displayFamily
                                    font.weight: Font.Bold
                                    font.features: { "tnum": 1 }
                                }

                                // Seconds zone
                                Item {
                                    id: secBox
                                    width: secText.implicitWidth + 8
                                    height: secText.implicitHeight + 4

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radiusSmall
                                        color: secArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : "transparent"
                                    }

                                    Text {
                                        id: secText
                                        anchors.centerIn: parent
                                        text: String(root.timerSeconds).padStart(2, '0')
                                        color: secArea.containsMouse ? Theme.accent : Theme.foreground
                                        font.pixelSize: Theme.textTitle * 1.35
                                        font.family: Theme.displayFamily
                                        font.weight: Font.Bold
                                        font.features: { "tnum": 1 }
                                    }

                                    MouseArea {
                                        id: secArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onWheel: (wheel) => {
                                            if (wheel.angleDelta.y > 0) {
                                                if (root.timerSeconds + 5 >= 60) {
                                                    root.timerMinutes = Math.min(999, root.timerMinutes + 1);
                                                    root.timerSeconds = (root.timerSeconds + 5) % 60;
                                                } else {
                                                    root.timerSeconds += 5;
                                                }
                                            } else if (wheel.angleDelta.y < 0) {
                                                if (root.timerSeconds - 5 < 0) {
                                                    if (root.timerMinutes > 0) {
                                                        root.timerMinutes -= 1;
                                                        root.timerSeconds = 55;
                                                    } else {
                                                        root.timerSeconds = 0;
                                                    }
                                                } else {
                                                    root.timerSeconds -= 5;
                                                }
                                            }
                                            wheel.accepted = true;
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (minArea.containsMouse) return "Scroll minutes";
                                    if (secArea.containsMouse) return "Scroll seconds";
                                    return "Scroll to adjust";
                                }
                                color: (minArea.containsMouse || secArea.containsMouse) ? Theme.accent : Theme.muted
                                font.pixelSize: Theme.textCaption
                                font.family: Theme.fontFamily
                            }
                        }
                    }

                    // Steppers & Start Button Row
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Button {
                            text: "-1m"
                            tone: "ghost"
                            enabled: root.timerMinutes > 0 || root.timerSeconds > 0
                            onClicked: {
                                if (root.timerMinutes > 0) root.timerMinutes -= 1;
                                else root.timerSeconds = 0;
                            }
                        }

                        Button {
                            text: `Start ${root.timerMinutes}m${root.timerSeconds > 0 ? " " + root.timerSeconds + "s" : ""}`
                            icon: "play"
                            tone: "accent"
                            enabled: root.timerMinutes > 0 || root.timerSeconds > 0
                            onClicked: {
                                const dur = root.timerSeconds > 0 ? `${root.timerMinutes}m ${root.timerSeconds}s` : `${root.timerMinutes}m`;
                                Daemon.command("chrono", "timer_start", [dur]);
                            }
                        }

                        Button {
                            text: "+1m"
                            tone: "ghost"
                            onClicked: root.timerMinutes = Math.min(999, root.timerMinutes + 1)
                        }
                    }
                }

                // Active Timers List (1 or more running timers)
                Item {
                    visible: root.activeTimers.length > 0
                    anchors.fill: parent

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Item {
                            width: parent.width
                            height: 32

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    text: "Active Timers"
                                    color: Theme.foreground
                                    font.pixelSize: Theme.textBody
                                    font.family: Theme.fontFamily
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    height: 20
                                    radius: 10
                                    color: Theme.raised
                                    implicitWidth: timerCountText.implicitWidth + 12
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: timerCountText
                                        anchors.centerIn: parent
                                        text: `${root.activeTimers.length}`
                                        color: Theme.muted
                                        font.pixelSize: Theme.textCaption
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }

                            Button {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.activeTimers.length > 1
                                text: "Stop all"
                                icon: "stop"
                                tone: "ghost"
                                onClicked: Daemon.command("chrono", "timer_stop", [])
                            }
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 42
                            clip: true
                            spacing: 6
                            model: root.activeTimers

                            delegate: Rectangle {
                                id: timerCard

                                width: parent.width
                                height: 52
                                radius: Theme.radiusMedium
                                color: Theme.raised

                                // Left: Progress Ring
                                Ring {
                                    id: cardRing
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 30
                                    line: 3
                                    color: modelData.paused ? Theme.muted : Theme.accent
                                    progress: modelData.progress ?? 0
                                }

                                // Right: Action Buttons Row
                                Row {
                                    id: cardActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Button {
                                        text: "+1m"
                                        tone: "ghost"
                                        onClicked: Daemon.command("chrono", "timer_add", ["1m", modelData.id])
                                    }

                                    Button {
                                        icon: modelData.paused ? "play" : "pause"
                                        tone: modelData.paused ? "accent" : "neutral"
                                        onClicked: Daemon.command("chrono", "timer_pause", [modelData.id])
                                    }

                                    Button {
                                        icon: "close"
                                        tone: "ghost"
                                        onClicked: Daemon.command("chrono", "timer_stop", [modelData.id])
                                    }
                                }

                                // Middle: Label and Remaining Time
                                Column {
                                    anchors.left: cardRing.right
                                    anchors.leftMargin: 10
                                    anchors.right: cardActions.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    clip: true

                                    Text {
                                        width: parent.width
                                        text: modelData.label && modelData.label !== "" ? modelData.label : "Timer"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.textBody
                                        font.family: Theme.fontFamily
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        spacing: 6

                                        Text {
                                            text: modelData.formatted ?? "00:00"
                                            color: modelData.paused ? Theme.muted : Theme.accent
                                            font.pixelSize: Theme.textCaption
                                            font.family: Theme.displayFamily
                                            font.weight: Font.Bold
                                            font.features: { "tnum": 1 }
                                        }

                                        Text {
                                            visible: modelData.paused
                                            text: "PAUSED"
                                            color: Theme.muted
                                            font.pixelSize: Theme.textCaption * 0.8
                                            font.family: Theme.fontFamily
                                            font.weight: Font.Bold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Right Panel: Input, Presets & Volume Control
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: (parent.width - 16) * 0.56
                radius: Theme.radiusLarge
                color: Theme.surface
                border.width: 1
                border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    // Header
                    Item {
                        width: parent.width
                        height: 32

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "New Timer & Controls"
                            color: Theme.foreground
                            font.pixelSize: Theme.textBody
                            font.family: Theme.fontFamily
                            font.weight: Font.DemiBold
                        }
                    }

                    // Intuitive text input field to type duration and optional label
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - pageStartBtn.width - 8
                            height: 38
                            radius: 19
                            color: Theme.raised

                            Symbol {
                                id: pageInputIcon
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                name: "bell"
                                size: 14
                                color: Theme.muted
                            }

                            TextInput {
                                id: pageTimerInput
                                anchors.left: pageInputIcon.right
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.foreground
                                selectionColor: Theme.accent
                                font.pixelSize: Theme.textBody
                                font.family: Theme.fontFamily
                                clip: true
                                onAccepted: {
                                    if (root.startTimerWithText(text)) {
                                        text = "";
                                    }
                                }

                                Text {
                                    visible: pageTimerInput.text === ""
                                    text: "Duration & label (e.g. 5m, 15m Tea, 10:00)..."
                                    color: Theme.muted
                                    font: pageTimerInput.font
                                }
                            }
                        }

                        Button {
                            id: pageStartBtn
                            text: "Start"
                            icon: "play"
                            tone: "accent"
                            onClicked: {
                                if (pageTimerInput.text !== "") {
                                    if (root.startTimerWithText(pageTimerInput.text)) {
                                        pageTimerInput.text = "";
                                    }
                                } else {
                                    Daemon.command("chrono", "timer_start", []);
                                }
                            }
                        }
                    }

                    // Quick Presets Grid
                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Quick Presets"
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                        }

                        Grid {
                            width: parent.width
                            columns: 4
                            spacing: 8

                            Repeater {
                                model: [
                                    { "label": "1 min", "val": "1m" },
                                    { "label": "3 min", "val": "3m" },
                                    { "label": "5 min", "val": "5m" },
                                    { "label": "10 min", "val": "10m" },
                                    { "label": "15 min", "val": "15m" },
                                    { "label": "20 min", "val": "20m" },
                                    { "label": "25 min", "val": "25m" },
                                    { "label": "30 min", "val": "30m" }
                                ]

                                Button {
                                    width: (parent.width - 24) / 4
                                    implicitHeight: 34
                                    text: modelData.label
                                    tone: "raised"
                                    onClicked: Daemon.command("chrono", "timer_start", [modelData.val])
                                }
                            }
                        }
                    }

                    // Alarm Volume Control Slider
                    Rectangle {
                        id: volumeCard
                        width: parent.width
                        height: 60
                        radius: Theme.radiusMedium
                        color: Theme.raised

                        property int currentVolume: root.alarmVolume
                        onCurrentVolumeChanged: {
                            if (!volSlider.dragging) {
                                currentVolume = root.alarmVolume;
                            }
                        }

                        Item {
                            anchors.fill: parent
                            anchors.margins: 12

                            Symbol {
                                id: volIcon
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                name: {
                                    const v = volumeCard.currentVolume;
                                    if (v === 0) return "volume-muted";
                                    if (v < 34) return "volume-1";
                                    if (v < 67) return "volume-2";
                                    return "volume-3";
                                }
                                size: 20
                                color: Theme.muted
                            }

                            Button {
                                id: testSoundBtn
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Test"
                                icon: "play"
                                tone: "ghost"
                                onClicked: Daemon.command("chrono", "timer_test_sound", [])
                            }

                            Column {
                                anchors.left: volIcon.right
                                anchors.leftMargin: 12
                                anchors.right: testSoundBtn.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5

                                Item {
                                    width: parent.width
                                    height: 16

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Alarm Volume"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.textCaption
                                        font.family: Theme.fontFamily
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: `${volumeCard.currentVolume}%`
                                        color: Theme.accent
                                        font.pixelSize: Theme.textCaption
                                        font.family: Theme.fontFamily
                                        font.features: { "tnum": 1 }
                                    }
                                }

                                Slider {
                                    id: volSlider
                                    width: parent.width
                                    thickness: 6
                                    value: root.alarmVolume / 100
                                    fill: Theme.accent
                                    onMoved: val => {
                                        volumeCard.currentVolume = Math.round(val * 100);
                                    }
                                    onReleased: val => {
                                        const v = Math.round(val * 100);
                                        volumeCard.currentVolume = v;
                                        Daemon.command("chrono", "timer_volume", [`${v}`]);
                                    }
                                }
                            }
                        }
                    }

                    // Informational Tip Card
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: Theme.radiusMedium
                        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.04)

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Symbol {
                                name: "bell"
                                size: 14
                                color: Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Tip: Add custom labels like '15m Coffee' or '25m Pomodoro'"
                                color: Theme.muted
                                font.pixelSize: Theme.textCaption
                                font.family: Theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
}
