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
    readonly property var laps: stopwatch.laps ?? []
    readonly property var history: stopwatch.history ?? []
    readonly property var worldClocks: clock.world_clocks ?? ({})
    readonly property var availableCities: clock.available_cities ?? [
        { "id": "los_angeles", "city": "Los Angeles", "country": "United States" },
        { "id": "new_york", "city": "New York", "country": "United States" },
        { "id": "london", "city": "London", "country": "United Kingdom" },
        { "id": "paris", "city": "Paris", "country": "France" },
        { "id": "dubai", "city": "Dubai", "country": "United Arab Emirates" },
        { "id": "singapore", "city": "Singapore", "country": "Singapore" },
        { "id": "tokyo", "city": "Tokyo", "country": "Japan" },
        { "id": "sydney", "city": "Sydney", "country": "Australia" }
    ]

    // Selected cities for World Clock (Los Angeles & Tokyo selected by default)
    property var selectedCities: ["los_angeles", "tokyo"]

    property string stopwatchSubTab: "laps" // "laps" or "history"

    implicitWidth: 800
    implicitHeight: 380

    focus: true

    function toggleCity(cityId) {
        const idx = selectedCities.indexOf(cityId);
        if (idx >= 0) {
            const next = selectedCities.slice();
            next.splice(idx, 1);
            selectedCities = next;
        } else {
            selectedCities = selectedCities.concat([cityId]);
        }
    }

    function startTimerWithText(text) {
        const secs = ClockHelper.parseDuration(text);
        if (secs && secs > 0) {
            Daemon.command("chrono", "timer_start", [`${secs}s`]);
            return true;
        }
        return false;
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

    Column {
        anchors.fill: parent
        spacing: 12

        // Tab bar navigation
        Segmented {
            id: nav

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

        // ================= CLOCK VIEW (Selectable World Clocks) =================
        Item {
            visible: root.mode === "clock"
            width: parent.width
            height: parent.height - nav.height - 12

            Row {
                anchors.fill: parent
                spacing: 18

                // Local Time & Day Progress
                Column {
                    width: parent.width * 0.38
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Column {
                        spacing: 2

                        Text {
                            text: root.clock.time ?? "00:00:00"
                            color: Theme.foreground
                            font.pixelSize: Theme.textDisplay * 1.3
                            font.family: Theme.displayFamily
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                        }

                        Text {
                            text: root.clock.date ?? ""
                            color: Theme.muted
                            font.pixelSize: Theme.textSubtitle
                            font.family: Theme.fontFamily
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 64
                        radius: Theme.radiusLarge
                        color: Theme.surface

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            width: parent.width - 24

                            Item {
                                width: parent.width
                                height: 16

                                Text {
                                    anchors.left: parent.left
                                    text: "Day elapsed"
                                    color: Theme.muted
                                    font.pixelSize: Theme.textCaption
                                    font.family: Theme.fontFamily
                                }

                                Text {
                                    anchors.right: parent.right
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

                // World Clocks Card with City Selector
                Rectangle {
                    width: parent.width * 0.62
                    height: parent.height - 4
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Theme.radiusLarge
                    color: Theme.surface
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "Select World Clocks"
                            color: Theme.foreground
                            font.pixelSize: Theme.textBody
                            font.family: Theme.fontFamily
                            font.weight: Font.DemiBold
                        }

                        // City Selection Chips
                        Flickable {
                            width: parent.width
                            height: 32
                            contentWidth: chipRow.implicitWidth
                            clip: true
                            flickableDirection: Flickable.HorizontalFlick

                            Row {
                                id: chipRow
                                spacing: 6

                                Repeater {
                                    model: root.availableCities

                                    Button {
                                        readonly property bool isSelected: root.selectedCities.indexOf(modelData.id) >= 0
                                        text: modelData.city
                                        icon: isSelected ? "check" : "plus"
                                        tone: isSelected ? "accent" : "raised"
                                        onClicked: root.toggleCity(modelData.id)
                                    }
                                }
                            }
                        }

                        // Active World Clocks List (Model is static selectedCities array, scroll never resets!)
                        Item {
                            width: parent.width
                            height: parent.height - 76

                            Text {
                                visible: root.selectedCities.length === 0
                                anchors.centerIn: parent
                                text: "No world clocks selected\nClick any city above to add it"
                                horizontalAlignment: Text.AlignHCenter
                                color: Theme.muted
                                font.pixelSize: Theme.textLabel
                                font.family: Theme.fontFamily
                            }

                            ListView {
                                visible: root.selectedCities.length > 0
                                anchors.fill: parent
                                clip: true
                                spacing: 5
                                model: root.selectedCities

                                delegate: Rectangle {
                                    id: cityCard

                                    readonly property var cityData: root.worldClocks[modelData] ?? ({})

                                    width: parent.width
                                    height: 40
                                    radius: Theme.radiusSmall
                                    color: Theme.raised

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 8

                                        Column {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                text: cityCard.cityData.city ?? modelData
                                                color: Theme.foreground
                                                font.pixelSize: Theme.textBody
                                                font.family: Theme.fontFamily
                                                font.weight: Font.DemiBold
                                            }

                                            Text {
                                                text: `${cityCard.cityData.offset ?? ""} · ${cityCard.cityData.date ?? ""}`
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
                                                text: cityCard.cityData.time ?? "00:00:00"
                                                color: Theme.accent
                                                font.pixelSize: Theme.textTitle
                                                font.family: Theme.displayFamily
                                                font.weight: Font.Bold
                                                font.features: { "tnum": 1 }
                                            }

                                            Button {
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
            width: parent.width
            height: parent.height - nav.height - 12

            Row {
                anchors.fill: parent
                spacing: 18

                // Controls, Big Time, and Key Hints
                Column {
                    width: (parent.width - 18) * 0.48
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.stopwatch.formatted ?? "00:00.0"
                        color: Theme.foreground
                        font.pixelSize: Theme.textDisplay * 1.3
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }

                    // Action buttons with keyboard shortcut badges
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Button {
                            visible: !root.stopwatch.running
                            text: "Start [Space]"
                            icon: "play"
                            tone: "accent"
                            onClicked: Daemon.command("chrono", "stopwatch_start", [])
                        }

                        Button {
                            visible: root.stopwatch.running
                            text: root.stopwatch.paused ? "Resume [Space]" : "Pause [Space]"
                            icon: root.stopwatch.paused ? "play" : "pause"
                            tone: root.stopwatch.paused ? "accent" : "neutral"
                            onClicked: Daemon.command("chrono", "stopwatch_pause", [])
                        }

                        Button {
                            visible: root.stopwatch.running && !root.stopwatch.paused
                            text: "Lap [L]"
                            icon: "plus"
                            tone: "neutral"
                            onClicked: Daemon.command("chrono", "stopwatch_lap", [])
                        }

                        Button {
                            visible: root.stopwatch.running
                            text: "Reset [R]"
                            icon: "stop"
                            tone: "danger"
                            onClicked: Daemon.command("chrono", "stopwatch_reset", [])
                        }
                    }

                    // Global & in-app shortcut hints
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "In-app: [Space] Start/Pause · [L] Lap · [R] Reset"
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Global (in-game): Super+K (Pause) · Super+Shift+K (Lap) · Super+Ctrl+R (Reset)"
                            color: Theme.accent
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
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

                        // Sub-tabs: Current Laps vs History
                        Row {
                            width: parent.width
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

        // ================= TIMER VIEW (Clean 25 min & Intuitive Input) =================
        Item {
            visible: root.mode === "timer"
            width: parent.width
            height: parent.height - nav.height - 12

            Row {
                anchors.centerIn: parent
                spacing: 36

                // Circular countdown ring
                Item {
                    width: 140
                    height: 140
                    anchors.verticalCenter: parent.verticalCenter

                    Ring {
                        anchors.fill: parent
                        line: 6
                        color: root.timer.paused ? Theme.muted : Theme.accent
                        progress: root.timer.running ? (root.timer.progress ?? 1) : 1
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.timer.running ? (root.timer.formatted ?? "00:00") : `${root.timer.default_minutes ?? 5}:00`
                            color: Theme.foreground
                            font.pixelSize: Theme.textTitle
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.timer.paused ? "Paused" : (root.timer.running ? "Running" : "Ready")
                            color: Theme.muted
                            font.pixelSize: Theme.textCaption
                            font.family: Theme.fontFamily
                        }
                    }
                }

                // Controls, Input and Presets
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    width: 360

                    // Intuitive text input field to type duration
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - (root.timer.running ? 0 : pageStartBtn.width + 8)
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
                                    text: "Type duration (e.g. 5m, 90s, 1h 30m, 10:00)..."
                                    color: Theme.muted
                                    font: pageTimerInput.font
                                }
                            }
                        }

                        Button {
                            id: pageStartBtn
                            visible: !root.timer.running
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

                    // Action buttons when running
                    Row {
                        spacing: 8
                        visible: root.timer.running

                        Button {
                            text: root.timer.paused ? "Resume" : "Pause"
                            icon: root.timer.paused ? "play" : "pause"
                            tone: root.timer.paused ? "accent" : "neutral"
                            onClicked: Daemon.command("chrono", "timer_pause", [])
                        }

                        Button {
                            text: "+1 min"
                            tone: "neutral"
                            onClicked: Daemon.command("chrono", "timer_add", ["1m"])
                        }

                        Button {
                            text: "+5 min"
                            tone: "neutral"
                            onClicked: Daemon.command("chrono", "timer_add", ["5m"])
                        }

                        Button {
                            text: "Stop"
                            icon: "stop"
                            tone: "danger"
                            onClicked: Daemon.command("chrono", "timer_stop", [])
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
                }
            }
        }
    }
}
