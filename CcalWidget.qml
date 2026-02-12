import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components"

PluginComponent {
    id: root

    readonly property string pluginId: "chineseCalendar"

    // Settings - load from SettingsData to properly react to changes
    readonly property string dateFormat: {
        const data = SettingsData.getPluginSettingsForPlugin(pluginId)
        return data.dateFormat ?? "ddd MM月dd日 LL"
    }

    // Formatted date string using the service's formatDate function
    property string formattedDate: ""

    function updateFormattedDate() {
        if (!ChineseCalendarService.ccalAvailable) {
            formattedDate = "未安装 ccal"
            return
        }
        const format = SettingsData.getPluginSettingsForPlugin(pluginId).dateFormat ?? "ddd MM月dd日 LL"
        formattedDate = ChineseCalendarService.formatDate(format) || ""
    }

    // Update formatted date when format or lunar data changes
    Connections {
        target: ChineseCalendarService
        function onLunarDataUpdated() {
            updateFormattedDate()
        }
        function onCurrentLunarDayChanged() {
            updateFormattedDate()
        }
        function onCcalCheckCompleted() {
            updateFormattedDate()
        }
    }

    // Listen for plugin data changes from PluginService
    Connections {
        target: pluginService
        enabled: pluginService !== null
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId) {
                // Force immediate update
                updateFormattedDate()
            }
        }
    }

    Component.onCompleted: {
        // Immediately load lunar data if ccal is available and data is empty
        if (ChineseCalendarService.ccalAvailable && !ChineseCalendarService.currentLunarDay) {
            ChineseCalendarService.loadCurrentMonthData()
        }
        // Initial update of formatted date
        updateFormattedDate()
    }

    // Trigger update when pluginSettings changes using JSON string for change detection
    readonly property string settingsJson: JSON.stringify(SettingsData.pluginSettings[pluginId] ?? {})
    onSettingsJsonChanged: updateFormattedDate()

    horizontalBarPill: Component {
        StyledText {
            text: root.formattedDate
            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
            color: Theme.widgetTextColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    verticalBarPill: Component {
        StyledText {
            text: root.formattedDate
            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
            color: Theme.widgetTextColor
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutRoot
            headerText: "农历日历"
            showCloseButton: true

            property date displayDate: new Date()
            property string currentMonthKey: Qt.formatDate(displayDate, "yyyy-MM")
            property date selectedDate: new Date()
            property bool isShowingToday: true

            // F4: Month selector state
            property bool showingMonthSelector: false
            property int selectorYear: displayDate.getFullYear()

            // Ccal availability status from service
            readonly property bool ccalAvailable: ChineseCalendarService.ccalAvailable
            readonly property bool ccalChecking: ChineseCalendarService.ccalChecking
            readonly property color workdayColor: "#43a047"

            // F1: Weekend color and helper
            readonly property color weekendColor: Theme.error
            function isWeekendColumn(columnIndex) {
                const loc = Qt.locale()
                const qtFirst = loc.firstDayOfWeek
                const qtDay = ((qtFirst - 1 + columnIndex) % 7) + 1
                return qtDay === 6 || qtDay === 7 // Saturday or Sunday
            }

            // F7: Wheel cooldown
            property bool wheelCooldown: false
            Timer {
                id: wheelCooldownTimer
                interval: 300
                onTriggered: popoutRoot.wheelCooldown = false
            }

            function changeMonth(delta) {
                if (!ccalAvailable) return
                const newDate = new Date(displayDate)
                newDate.setMonth(newDate.getMonth() + delta)
                displayDate = newDate
            }

            function selectDate(date) {
                selectedDate = date
                updateShowingToday()
            }

            function goToToday() {
                if (!ccalAvailable) return
                showingMonthSelector = false
                const today = new Date()
                displayDate = today
                selectedDate = today
                updateShowingToday()
            }

            function updateShowingToday() {
                const today = new Date()
                isShowingToday = (
                    selectedDate.toDateString() === today.toDateString() &&
                    displayDate.getMonth() === today.getMonth() &&
                    displayDate.getFullYear() === today.getFullYear()
                )
            }

            onDisplayDateChanged: {
                currentMonthKey = ""
                if (ccalAvailable) {
                    const y = displayDate.getFullYear()
                    const m = displayDate.getMonth()
                    ChineseCalendarService.loadMonthData(y, m)
                    ChineseCalendarService.loadHolidayDataForYear(y)
                    // Preload adjacent months
                    const prev = new Date(y, m - 1, 1)
                    const next = new Date(y, m + 1, 1)
                    ChineseCalendarService.loadMonthData(prev.getFullYear(), prev.getMonth())
                    ChineseCalendarService.loadMonthData(next.getFullYear(), next.getMonth())
                    // Preload adjacent year holidays for Dec/Jan
                    if (m === 11) ChineseCalendarService.loadHolidayDataForYear(y + 1)
                    if (m === 0) ChineseCalendarService.loadHolidayDataForYear(y - 1)
                }
                Qt.callLater(() => {
                    currentMonthKey = Qt.formatDate(displayDate, "yyyy-MM")
                })
                updateShowingToday()
            }

            // Main content area - shows either error message or calendar
            Item {
                width: parent.width
                height: ccalAvailable ? contentColumn.height : errorColumn.height

                // Error message when ccal is not installed
                Column {
                    id: errorColumn
                    visible: !ccalAvailable
                    width: parent.width
                    spacing: Theme.spacingL

                    // Warning icon
                    Item {
                        width: parent.width
                        height: 80

                        DankIcon {
                            anchors.centerIn: parent
                            name: "warning"
                            size: 48
                            color: Theme.warning
                        }
                    }

                    // Error message
                    StyledText {
                        width: parent.width
                        text: "未安装 ccal"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Description
                    StyledText {
                        width: parent.width - Theme.spacingL * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "农历日历功能需要安装 ccal 工具"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.7)
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Refresh button
                    Item {
                        width: parent.width
                        height: 48

                        Rectangle {
                            width: 120
                            height: 40
                            radius: Theme.cornerRadius
                            color: !ccalChecking && refreshArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.primary, 0.08)
                            opacity: ccalChecking ? 0.7 : 1.0
                            anchors.centerIn: parent

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "refresh"
                                    size: 18
                                    color: Theme.primary
                                    // Spinning animation when checking
                                    RotationAnimation on rotation {
                                        running: ccalChecking
                                        from: 0
                                        to: 360
                                        loops: Animation.Infinite
                                        duration: 1000
                                    }
                                }

                                StyledText {
                                    text: ccalChecking ? "检查中..." : "刷新"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: refreshArea
                                anchors.fill: parent
                                hoverEnabled: !ccalChecking
                                cursorShape: ccalChecking ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    if (!ccalChecking) {
                                        ChineseCalendarService.recheckCcalAvailability()
                                    }
                                }
                            }
                        }
                    }
                }

                // Normal calendar content (shown when ccal is available)
                Column {
                    id: contentColumn
                    visible: ccalAvailable
                    width: parent.width

                    // Month navigation
                    Row {
                        width: parent.width
                        height: 28

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.cornerRadius
                            color: prevMonthArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "chevron_left"
                                size: 14
                                color: Theme.primary
                            }

                            MouseArea {
                                id: prevMonthArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (popoutRoot.showingMonthSelector) {
                                        popoutRoot.selectorYear--
                                    } else {
                                        popoutRoot.changeMonth(-1)
                                    }
                                }
                            }
                        }

                        // F4: Month title - clickable for month selector
                        Item {
                            width: parent.width - 56
                            height: 28

                            StyledText {
                                anchors.fill: parent
                                text: popoutRoot.showingMonthSelector
                                    ? popoutRoot.selectorYear + " 年"
                                    : popoutRoot.displayDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                                font.pixelSize: Theme.fontSizeMedium
                                color: monthTitleArea.containsMouse ? Theme.primary : Theme.surfaceText
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            MouseArea {
                                id: monthTitleArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (popoutRoot.showingMonthSelector) {
                                        popoutRoot.showingMonthSelector = false
                                    } else {
                                        popoutRoot.selectorYear = popoutRoot.displayDate.getFullYear()
                                        popoutRoot.showingMonthSelector = true
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.cornerRadius
                            color: nextMonthArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "chevron_right"
                                size: 14
                                color: Theme.primary
                            }

                            MouseArea {
                                id: nextMonthArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (popoutRoot.showingMonthSelector) {
                                        popoutRoot.selectorYear++
                                    } else {
                                        popoutRoot.changeMonth(1)
                                    }
                                }
                            }
                        }
                    }

                    // F4: Month selector grid (4x3)
                    Grid {
                        id: monthSelectorGrid
                        visible: popoutRoot.showingMonthSelector
                        width: parent.width
                        columns: 4
                        rows: 3

                        Repeater {
                            model: 12

                            Rectangle {
                                readonly property bool isCurrentMonth: popoutRoot.selectorYear === popoutRoot.displayDate.getFullYear() && index === popoutRoot.displayDate.getMonth()
                                width: monthSelectorGrid.width / 4
                                height: 40
                                radius: Theme.cornerRadius
                                color: {
                                    if (isCurrentMonth) return Theme.withAlpha(Theme.primary, 0.2)
                                    if (monthSelArea.containsMouse) return Theme.withAlpha(Theme.primary, 0.08)
                                    return "transparent"
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: (index + 1) + "月"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: isCurrentMonth ? Font.Bold : Font.Normal
                                    color: isCurrentMonth ? Theme.primary : Theme.surfaceText
                                }

                                MouseArea {
                                    id: monthSelArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        popoutRoot.displayDate = new Date(popoutRoot.selectorYear, index, 1)
                                        popoutRoot.showingMonthSelector = false
                                    }
                                }
                            }
                        }
                    }

                    // Week day headers (hidden in month selector mode)
                    Row {
                        visible: !popoutRoot.showingMonthSelector
                        width: parent.width
                        height: 24

                        Repeater {
                            model: {
                                const days = []
                                const loc = Qt.locale()
                                const qtFirst = loc.firstDayOfWeek
                                for (let i = 0; i < 7; ++i) {
                                    const qtDay = ((qtFirst - 1 + i) % 7) + 1
                                    days.push(loc.dayName(qtDay, Locale.ShortFormat))
                                }
                                return days
                            }

                            Rectangle {
                                width: parent.width / 7
                                height: 24
                                color: "transparent"

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: Theme.fontSizeSmall
                                    // F1: Weekend column header color
                                    color: popoutRoot.isWeekendColumn(index) ? Theme.withAlpha(popoutRoot.weekendColor, 0.7) : Theme.withAlpha(Theme.surfaceText, 0.5)
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }

                    // Spacing between week headers and calendar grid
                    Item {
                        visible: !popoutRoot.showingMonthSelector
                        width: parent.width
                        height: 4
                    }

                    // F7: Wheel area wrapping calendar grid (hidden in month selector mode)
                    Item {
                        visible: !popoutRoot.showingMonthSelector
                        width: parent.width
                        height: calendarGrid.height

                        Behavior on height {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                if (popoutRoot.wheelCooldown) return
                                popoutRoot.wheelCooldown = true
                                wheelCooldownTimer.restart()
                                if (popoutRoot.showingMonthSelector) {
                                    if (wheel.angleDelta.y > 0) popoutRoot.selectorYear--
                                    else popoutRoot.selectorYear++
                                } else {
                                    if (wheel.angleDelta.y > 0) popoutRoot.changeMonth(-1)
                                    else popoutRoot.changeMonth(1)
                                }
                            }
                        }

                        // Calendar grid
                        Grid {
                            id: calendarGrid

                            property date displayDate: popoutRoot.displayDate
                            property string displayMonthKey: popoutRoot.currentMonthKey ?? ""
                            property int cacheVersion: ChineseCalendarService.dataVersion
                            readonly property string todayDateString: new Date().toDateString()
                            readonly property date firstDay: {
                                if (!displayDate) return new Date()
                                const firstOfMonth = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1)
                                return ChineseCalendarService.startOfWeek(firstOfMonth)
                            }

                            // F5: Dynamic row count
                            readonly property int cellHeight: 40
                            readonly property int numRows: {
                                if (!displayDate) return 6
                                const y = displayDate.getFullYear()
                                const m = displayDate.getMonth()
                                const firstOfMonth = new Date(y, m, 1)
                                const daysInMonth = new Date(y, m + 1, 0).getDate()
                                const startOffset = (firstOfMonth.getDay() - ChineseCalendarService.weekStartJs() + 7) % 7
                                return Math.ceil((startOffset + daysInMonth) / 7)
                            }

                            width: parent.width
                            height: numRows * cellHeight
                            columns: 7
                            rows: numRows

                            Repeater {
                                model: calendarGrid.numRows * 7

                                Item {
                                    readonly property date dayDate: {
                                        if (!calendarGrid.firstDay) return new Date()
                                        const date = new Date(calendarGrid.firstDay)
                                        date.setDate(date.getDate() + index)
                                        return date
                                    }
                                    readonly property bool isCurrentMonth: dayDate.getMonth() === calendarGrid.displayDate.getMonth()
                                    readonly property bool isToday: dayDate.toDateString() === calendarGrid.todayDateString
                                    readonly property bool isSelected: dayDate.toDateString() === popoutRoot.selectedDate.toDateString()
                                    readonly property string dateStr: Qt.formatDate(dayDate, "yyyy-MM-dd")
                                    readonly property var holidayInfo: ChineseCalendarService.getHolidayInfo(dateStr)
                                    readonly property bool isHoliday: holidayInfo?.isHoliday || false
                                    readonly property bool isWorkday: holidayInfo?.isWorkday || false
                                    // F1: Weekend per cell
                                    readonly property bool isWeekend: popoutRoot.isWeekendColumn(index % 7)
                                    readonly property string lunarDayText: ChineseCalendarService.getLunarDayForDate(dayDate.getDate(), dayDate.getMonth(), dayDate.getFullYear(), calendarGrid.cacheVersion)
                                    readonly property string displayText: {
                                        const holidayName = ChineseCalendarService.getHolidayName(dateStr)
                                        if (holidayName) return holidayName
                                        return lunarDayText
                                    }
                                    readonly property bool hasHoliday: displayText !== lunarDayText

                                    width: calendarGrid.width / 7
                                    height: calendarGrid.cellHeight

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        color: {
                                            if (isSelected) {
                                                return Theme.withAlpha(Theme.primary, 0.2)
                                            } else if (isToday) {
                                                return Theme.withAlpha(Theme.primary, 0.12)
                                            } else if (isHoliday) {
                                                return Theme.withAlpha(Theme.error, 0.15)
                                            } else if (isWorkday) {
                                                return Theme.withAlpha(popoutRoot.workdayColor, 0.12)
                                            } else if (dayMouseArea.containsMouse) {
                                                return Theme.withAlpha(Theme.primary, 0.06)
                                            // F1: Weekend background tint (current month only)
                                            } else if (isWeekend && isCurrentMonth) {
                                                return Theme.withAlpha(Theme.error, 0.04)
                                            } else {
                                                return "transparent"
                                            }
                                        }
                                        radius: Theme.cornerRadius
                                        border.width: isSelected ? 2 : 0
                                        border.color: Theme.primary

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: hasHoliday ? 2 : 1

                                            StyledText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: dayDate.getDate()
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: {
                                                    if (isToday) return Theme.primary
                                                    if (!isCurrentMonth) return Theme.withAlpha(Theme.surfaceText, 0.4)
                                                    // F1: Weekend date number color (don't override today/holiday/workday)
                                                    if (isWeekend && !isHoliday && !isWorkday) return Theme.withAlpha(popoutRoot.weekendColor, 0.8)
                                                    return Theme.surfaceText
                                                }
                                                font.weight: isToday ? Font.Medium : Font.Normal
                                            }

                                            StyledText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: {
                                                    if (displayText.includes("、")) {
                                                        const parts = displayText.split("、")
                                                        const shortened = parts.map(p => p.endsWith("节") && p.length > 2 ? p.slice(0, -1) : p)
                                                        const joined = shortened.join("+")
                                                        return joined.length > 5 ? shortened[0] : joined
                                                    }
                                                    return displayText
                                                }
                                                font.pixelSize: hasHoliday ? Theme.fontSizeSmall - 1 : Theme.fontSizeSmall
                                                color: {
                                                    // F2: Non-current-month lunar colors with lower opacity
                                                    if (hasHoliday) {
                                                        if (isHoliday) return isCurrentMonth ? Theme.error : Theme.withAlpha(Theme.error, 0.4)
                                                        if (isWorkday) return isCurrentMonth ? popoutRoot.workdayColor : Theme.withAlpha(popoutRoot.workdayColor, 0.4)
                                                    }
                                                    return Theme.withAlpha(Theme.primary, isCurrentMonth ? 0.8 : 0.35)
                                                }
                                                // F2: Show lunar text for non-current-month dates too
                                                visible: text !== ""
                                                font.weight: hasHoliday ? Font.Medium : Font.Normal
                                                maximumLineCount: 1
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: dayMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                popoutRoot.selectDate(dayDate)
                                                // F10: Jump to that month if not current month
                                                if (!isCurrentMonth) {
                                                    popoutRoot.displayDate = new Date(dayDate.getFullYear(), dayDate.getMonth(), 1)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Spacing before info section
                    Item {
                        width: parent.width
                        height: Theme.spacingS
                    }

                    // Selected date info - enhanced with better styling
                    Rectangle {
                        width: parent.width
                        height: infoCol.height + Theme.spacingM
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.8)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.outlineVariant, 0.3)

                        Column {
                            id: infoCol
                            width: parent.width
                            padding: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: {
                                    const date = popoutRoot.selectedDate
                                    const monthKey = Qt.formatDate(date, "yyyy-MM")
                                    const cache = ChineseCalendarService.lunarDataCache[monthKey]
                                    return cache?.monthInfo?.header || Qt.formatDate(date, "yyyy年M月")
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.primary
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            // F3: Main info text (without solar term inline)
                            StyledText {
                                text: {
                                    const date = popoutRoot.selectedDate
                                    const dateStr = Qt.formatDate(date, "yyyy-MM-dd")
                                    const lunarDay = ChineseCalendarService.getLunarDayForDate(date.getDate(), date.getMonth(), date.getFullYear(), ChineseCalendarService.dataVersion)
                                    const holidayInfo = ChineseCalendarService.getHolidayInfo(dateStr)
                                    const isToday = date.toDateString() === new Date().toDateString()

                                    let prefix = isToday ? "今天" : Qt.formatDate(date, "M月d日")

                                    if (holidayInfo?.isHoliday) {
                                        return prefix + "是 " + holidayInfo.name + "（放假）"
                                    }
                                    if (holidayInfo?.isWorkday && holidayInfo.name) {
                                        return prefix + "是 " + holidayInfo.name + "（调休）"
                                    }

                                    const fullInfo = ChineseCalendarService.getFullLunarDateInfo(date.getDate(), date.getMonth(), date.getFullYear())
                                    if (fullInfo) {
                                        return prefix + "是农历 " + fullInfo.fullLunarDate
                                    }

                                    if (lunarDay) {
                                        return prefix + "是农历 " + lunarDay
                                    }
                                    return prefix
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: {
                                    const date = popoutRoot.selectedDate
                                    const dateStr = Qt.formatDate(date, "yyyy-MM-dd")
                                    const holidayInfo = ChineseCalendarService.getHolidayInfo(dateStr)
                                    if (holidayInfo?.isHoliday) return Theme.error
                                    if (holidayInfo?.isWorkday) return popoutRoot.workdayColor
                                    return Theme.withAlpha(Theme.surfaceText, 0.9)
                                }
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: text !== ""
                            }

                            // F3: Solar term display (bold, primary color)
                            StyledText {
                                text: {
                                    const date = popoutRoot.selectedDate
                                    const fullInfo = ChineseCalendarService.getFullLunarDateInfo(date.getDate(), date.getMonth(), date.getFullYear())
                                    if (fullInfo && fullInfo.solarTerm) return "节气：" + fullInfo.solarTerm
                                    return ""
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: Theme.primary
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: text !== ""
                            }

                            // F3: Holiday countdown
                            StyledText {
                                readonly property var nextHoliday: {
                                    // Depend on holidayDataVersion for reactivity
                                    const v = ChineseCalendarService.holidayDataVersion
                                    return ChineseCalendarService.getNextHoliday(popoutRoot.selectedDate)
                                }
                                readonly property bool selectedIsHoliday: {
                                    const dateStr = Qt.formatDate(popoutRoot.selectedDate, "yyyy-MM-dd")
                                    const info = ChineseCalendarService.getHolidayInfo(dateStr)
                                    return info?.isHoliday || false
                                }
                                text: nextHoliday && !selectedIsHoliday ? "距 " + nextHoliday.name + " 还有 " + nextHoliday.daysUntil + " 天" : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.surfaceText, 0.7)
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: text !== ""
                            }
                        }
                    }
                }

                // F6: "今" FAB with hover feedback
                Rectangle {
                    id: fab
                    width: 48
                    height: 48
                    radius: width / 2
                    color: Theme.primary
                    visible: ccalAvailable && !popoutRoot.isShowingToday
                    scale: fabMouseArea.containsMouse ? 1.08 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        margins: Theme.spacingM
                    }

                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0
                        verticalOffset: fabMouseArea.containsMouse ? 4 : 2
                        radius: fabMouseArea.containsMouse ? 12 : 8
                        samples: 16
                        color: fabMouseArea.containsMouse ? "#60000000" : "#40000000"

                        Behavior on verticalOffset {
                            NumberAnimation { duration: 150 }
                        }
                        Behavior on radius {
                            NumberAnimation { duration: 150 }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: "今"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.primaryText
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: fabMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popoutRoot.goToToday()
                    }
                }
            }

            Component.onCompleted: {
                if (ccalAvailable) {
                    const y = displayDate.getFullYear()
                    const m = displayDate.getMonth()
                    ChineseCalendarService.loadMonthData(y, m)
                    ChineseCalendarService.loadHolidayDataForYear(y)
                    // Preload adjacent months
                    const prev = new Date(y, m - 1, 1)
                    const next = new Date(y, m + 1, 1)
                    ChineseCalendarService.loadMonthData(prev.getFullYear(), prev.getMonth())
                    ChineseCalendarService.loadMonthData(next.getFullYear(), next.getMonth())
                    if (m === 11) ChineseCalendarService.loadHolidayDataForYear(y + 1)
                    if (m === 0) ChineseCalendarService.loadHolidayDataForYear(y - 1)
                }
                updateShowingToday()
            }
        }
    }
}
