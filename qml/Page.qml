import QtQuick
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
            { "value": "stopwatch", "label": "Stopwatch", "icon": "bolt" },
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
                                text: root.clock.time ?? "00:00:00"
                                color: Theme.foreground
                                font.pixelSize: Theme.textDisplay * 1.45
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

                        // Day Elapsed Progress Card
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: 60
                            radius: Theme.radiusMedium
                            color: Theme.raised

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 24
                                spacing: 8

                                Item {
                                    width: parent.width
                                    height: 16

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Day elapsed"
                                        color: Theme.muted
                                        font.pixelSize: Theme.textCaption
                                        font.family: Theme.fontFamily
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: `${Math.round((root.clock.day_progress ?? 0) * 100)}%`
                                        color: Theme.accent
                                        font.pixelSize: Theme.textCaption
                                        font.family: Theme.fontFamily
                                        font.weight: Font.DemiBold
                                    }
                                }

                                ProgressBar {
                                    width: parent.width
                                    value: root.clock.day_progress ?? 0
                                    fill: Theme.accent
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

                                        width: parent.width
                                        height: 48
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
                                                    text: `${cityClockCard.cityData.country ?? ""} · ${cityClockCard.cityData.offset ?? ""}`
                                                    color: Theme.muted
                                                    font.pixelSize: Theme.textCaption
                                                    font.family: Theme.fontFamily
                                                }
                                            }

                                            Row {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 8

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: cityClockCard.cityData.time ?? "00:00:00"
                                                    color: Theme.accent
                                                    font.pixelSize: Theme.textHeadline
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

        // ================= STOPWATCH VIEW (Shortcuts & History) =================
        Item {
            visible: root.mode === "stopwatch"
            anchors.top: nav.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            Row {
                anchors.fill: parent
                spacing: 18

                // Controls, Big Time, and Key Hints
                Column {
                    width: (parent.width - 18) * 0.48
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.stopwatch.formatted ?? "00:00.0"
                        color: Theme.foreground
                        font.pixelSize: Theme.textDisplay * 1.3
                        font.family: Theme.displayFamily
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }

                    // Action buttons with clean labels
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

                    // Clean Keyboard Shortcuts card (bounded, never overflows)
                    Rectangle {
                        width: parent.width
                        implicitHeight: shortcutsCol.implicitHeight + 16
                        radius: Theme.radiusMedium
                        color: Theme.surface
                        border.width: 1
                        border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)

                        Column {
                            id: shortcutsCol
                            width: parent.width - 16
                            anchors.centerIn: parent
                            spacing: 6

                            // In-App Shortcuts
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6

                                Text {
                                    text: "In-App:"
                                    color: Theme.muted
                                    font.pixelSize: Theme.textCaption
                                    font.family: Theme.fontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Kbd { key: "Space"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Toggle"; color: Theme.muted; font.pixelSize: Theme.textCaption; anchors.verticalCenter: parent.verticalCenter }

                                Text { text: "·"; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }

                                Kbd { key: "L"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Lap"; color: Theme.muted; font.pixelSize: Theme.textCaption; anchors.verticalCenter: parent.verticalCenter }

                                Text { text: "·"; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }

                                Kbd { key: "R"; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Reset"; color: Theme.muted; font.pixelSize: Theme.textCaption; anchors.verticalCenter: parent.verticalCenter }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.05)
                            }

                            // Global In-Game / System-wide Shortcuts (Hyprland)
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8

                                Row {
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Kbd { key: "Super+K"; textColor: Theme.accent }
                                    Text { text: "Pause"; color: Theme.muted; font.pixelSize: Theme.textCaption; anchors.verticalCenter: parent.verticalCenter }
                                }

                                Text { text: "·"; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }

                                Row {
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Kbd { key: "Super+Shift+K"; textColor: Theme.accent }
                                    Text { text: "Lap"; color: Theme.muted; font.pixelSize: Theme.textCaption; anchors.verticalCenter: parent.verticalCenter }
                                }

                                Text { text: "·"; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }

                                Row {
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Kbd { key: "Super+Ctrl+R"; textColor: Theme.danger }
                                    Text { text: "Reset"; color: Theme.muted; font.pixelSize: Theme.textCaption; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }
                }

                // Laps & History Card
                Rectangle {
                    width: (parent.width - 18) * 0.52
                    height: parent.height - 4
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

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
                                    text: "History"
                                    tone: root.stopwatchSubTab === "history" ? "accent" : "ghost"
                                    onClicked: root.stopwatchSubTab = "history"
                                }
                            }

                            Button {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Export"
                                icon: "copy"
                                tone: "ghost"
                                onClicked: Daemon.command("chrono", "stopwatch_export", [])
                            }
                        }

                        // Current Laps view
                        Item {
                            visible: root.stopwatchSubTab === "laps"
                            width: parent.width
                            height: parent.height - 40

                            Text {
                                visible: root.laps.length === 0
                                anchors.centerIn: parent
                                text: "No laps recorded yet\nPress [L] or Super+Shift+K while running"
                                horizontalAlignment: Text.AlignHCenter
                                color: Theme.muted
                                font.pixelSize: Theme.textLabel
                                font.family: Theme.fontFamily
                            }

                            ListView {
                                visible: root.laps.length > 0
                                anchors.fill: parent
                                clip: true
                                model: root.laps.slice().reverse()
                                spacing: 4

                                delegate: Rectangle {
                                    width: parent.width
                                    height: 30
                                    radius: Theme.radiusSmall
                                    color: Theme.raised

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: `Lap ${modelData.index}`
                                            color: Theme.muted
                                            font.pixelSize: Theme.textLabel
                                            font.family: Theme.fontFamily
                                        }

                                        Row {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 14

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: `+${modelData.formatted_split}`
                                                color: Theme.accent
                                                font.pixelSize: Theme.textLabel
                                                font.family: Theme.fontFamily
                                                font.features: { "tnum": 1 }
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.formatted_total
                                                color: Theme.foreground
                                                font.pixelSize: Theme.textLabel
                                                font.family: Theme.fontFamily
                                                font.weight: Font.DemiBold
                                                font.features: { "tnum": 1 }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // History view (last 5 runs)
                        Item {
                            visible: root.stopwatchSubTab === "history"
                            width: parent.width
                            height: parent.height - 40

                            Text {
                                visible: root.history.length === 0
                                anchors.centerIn: parent
                                text: "No history yet\nResetting a run saves it here"
                                horizontalAlignment: Text.AlignHCenter
                                color: Theme.muted
                                font.pixelSize: Theme.textLabel
                                font.family: Theme.fontFamily
                            }

                            ListView {
                                visible: root.history.length > 0
                                anchors.fill: parent
                                clip: true
                                model: root.history
                                spacing: 4

                                delegate: Rectangle {
                                    width: parent.width
                                    height: 34
                                    radius: Theme.radiusSmall
                                    color: Theme.raised

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10

                                        Column {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                text: `Run #${modelData.index} · ${modelData.lap_count} laps`
                                                color: Theme.foreground
                                                font.pixelSize: Theme.textLabel
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
                                            font.pixelSize: Theme.textBody
                                            font.family: Theme.fontFamily
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

            Row {
                anchors.fill: parent
                spacing: 24

                // Left Column: Ready Ring (when idle) or Active Timers List
                Item {
                    width: (parent.width - 24) * 0.46
                    height: parent.height

                    // Idle State (No Timers Running)
                    Column {
                        visible: root.activeTimers.length === 0
                        anchors.centerIn: parent
                        spacing: 16

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 140
                            height: 140

                            Ring {
                                anchors.fill: parent
                                line: 6
                                color: Theme.accent
                                progress: 1
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: `${root.timer.default_minutes ?? 5}:00`
                                    color: Theme.foreground
                                    font.pixelSize: Theme.textTitle * 1.4
                                    font.family: Theme.displayFamily
                                    font.weight: Font.Bold
                                    font.features: { "tnum": 1 }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Ready"
                                    color: Theme.muted
                                    font.pixelSize: Theme.textCaption
                                    font.family: Theme.fontFamily
                                }
                            }
                        }

                        Button {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Start Default"
                            icon: "play"
                            tone: "accent"
                            onClicked: Daemon.command("chrono", "timer_start", [])
                        }
                    }

                    // Active Timers List (1 or more running timers)
                    Item {
                        visible: root.activeTimers.length > 0
                        anchors.fill: parent

                        Column {
                            anchors.fill: parent
                            spacing: 8

                            Item {
                                width: parent.width
                                height: 26

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: `Active Timers (${root.activeTimers.length})`
                                    color: Theme.foreground
                                    font.pixelSize: Theme.textBody
                                    font.family: Theme.fontFamily
                                    font.weight: Font.DemiBold
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
                                height: parent.height - 34
                                clip: true
                                spacing: 6
                                model: root.activeTimers

                                delegate: Rectangle {
                                    id: timerCard

                                    width: parent.width
                                    height: 52
                                    radius: Theme.radiusMedium
                                    color: Theme.surface
                                    border.width: 1
                                    border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)

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

                                    // Right: Action Buttons Row (always visible and right-anchored)
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

                                    // Middle: Label and Remaining Time (flexibly bounded)
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

                // Right Column: Input, Presets & Volume Control
                Column {
                    width: (parent.width - 24) * 0.54
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    // Intuitive text input field to type duration and optional label
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - pageStartBtn.width - 8
                            height: 38
                            radius: 19
                            color: Theme.surface

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
                                    text: "Type duration (e.g. 5m, 15m Tea, 10:00)..."
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

                    // Quick presets grid (clean 25 min without parentheses)
                    Column {
                        spacing: 6

                        Text {
                            text: "Quick presets:"
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
                        }

                        Grid {
                            columns: 4
                            spacing: 6

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
                        height: 54
                        radius: Theme.radiusLarge
                        color: Theme.surface
                        border.width: 1
                        border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.08)

                        property int currentVolume: root.alarmVolume
                        onCurrentVolumeChanged: {
                            if (!volSlider.dragging) {
                                currentVolume = root.alarmVolume;
                            }
                        }

                        Item {
                            anchors.fill: parent
                            anchors.margins: 10

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
                                size: 18
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
                                spacing: 4

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
                }
            }
        }
}
