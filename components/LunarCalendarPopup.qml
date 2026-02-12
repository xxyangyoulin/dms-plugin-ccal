import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Services
import qs.Widgets
import "../services"

Rectangle {
    id: root

    property var parentPopout: null

    implicitHeight: contentColumn.height + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    property date displayDate: new Date()
    property string currentMonthKey: Qt.formatDate(displayDate, "yyyy-MM")
    property date selectedDate: new Date()
    property bool isShowingToday: true

    function changeMonth(delta) {
        const newDate = new Date(displayDate)
        newDate.setMonth(newDate.getMonth() + delta)
        displayDate = newDate
        currentMonthKey = Qt.formatDate(newDate, "yyyy-MM")
        ChineseCalendarService.loadMonthData(newDate.getFullYear(), newDate.getMonth())
        ChineseCalendarService.loadHolidayDataForYear(newDate.getFullYear())
        updateShowingToday()
    }

    function selectDate(date) {
        selectedDate = date
        updateShowingToday()
    }

    function goToToday() {
        const today = new Date()
        displayDate = today
        selectedDate = today
        currentMonthKey = Qt.formatDate(today, "yyyy-MM")
        ChineseCalendarService.loadMonthData(today.getFullYear(), today.getMonth())
        ChineseCalendarService.loadHolidayDataForYear(today.getFullYear())
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
        ChineseCalendarService.loadMonthData(displayDate.getFullYear(), displayDate.getMonth())
        ChineseCalendarService.loadHolidayDataForYear(displayDate.getFullYear())
        Qt.callLater(() => {
            currentMonthKey = Qt.formatDate(displayDate, "yyyy-MM")
        })
        updateShowingToday()
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

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
                    onClicked: root.changeMonth(-1)
                }
            }

            StyledText {
                width: parent.width - 56
                height: 28
                text: root.displayDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
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
                    onClicked: root.changeMonth(1)
                }
            }
        }

        // Week day headers
        Row {
            width: parent.width
            height: 18

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
                    height: 18
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                        font.weight: Font.Medium
                    }
                }
            }
        }

        // Calendar grid
        Grid {
            id: calendarGrid

            property date displayDate: root.displayDate
            property string displayMonthKey: root.currentMonthKey ?? ""
            property int cacheVersion: ChineseCalendarService.dataVersion
            readonly property date firstDay: {
                if (!displayDate) return new Date()
                const firstOfMonth = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1)
                return ChineseCalendarService.startOfWeek(firstOfMonth)
            }

            width: parent.width
            height: 240
            columns: 7
            rows: 6
            spacing: 1

            Repeater {
                model: 42

                Rectangle {
                    readonly property date dayDate: {
                        if (!parent.firstDay) return new Date()
                        const date = new Date(parent.firstDay)
                        date.setDate(date.getDate() + index)
                        return date
                    }
                    readonly property bool isCurrentMonth: dayDate.getMonth() === calendarGrid.displayDate.getMonth()
                    readonly property bool isToday: dayDate.toDateString() === new Date().toDateString()
                    readonly property bool isSelected: dayDate.toDateString() === root.selectedDate.toDateString()
                    readonly property string dateStr: Qt.formatDate(dayDate, "yyyy-MM-dd")
                    readonly property var holidayInfo: ChineseCalendarService.getHolidayInfo(dateStr)
                    readonly property bool isHoliday: holidayInfo?.isHoliday || false
                    readonly property bool isWorkday: holidayInfo?.isWorkday || false
                    readonly property string displayText: {
                        const dateStr = Qt.formatDate(dayDate, "yyyy-MM-dd")
                        const holidayName = ChineseCalendarService.getHolidayName(dateStr)
                        if (holidayName) return holidayName
                        return ChineseCalendarService.getLunarDayForDate(dayDate.getDate(), dayDate.getMonth(), dayDate.getFullYear(), calendarGrid.cacheVersion)
                    }
                    readonly property bool hasHoliday: displayText !== ChineseCalendarService.getLunarDayForDate(dayDate.getDate(), dayDate.getMonth(), dayDate.getFullYear(), calendarGrid.cacheVersion)

                    width: parent.width / 7
                    height: parent.height / 6
                    color: "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 2, parent.height - 2)
                        height: width
                        color: {
                            if (isToday) return Theme.withAlpha(Theme.primary, 0.12)
                            if (isHoliday) return Theme.withAlpha(Theme.error, 0.15)
                            if (isWorkday) return Theme.withAlpha("#43a047", 0.12)
                            if (dayMouseArea.containsMouse) return Theme.withAlpha(Theme.primary, 0.08)
                            return "transparent"
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
                                color: isToday ? Theme.primary : isCurrentMonth ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.4)
                                font.weight: isToday ? Font.Medium : Font.Normal
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (displayText === "国庆节、中秋节") return "国庆+中秋"
                                    if (displayText === "春节、清明节") return "春节+清明"
                                    if (displayText === "清明节、劳动节") return "清明+劳动"
                                    if (displayText.includes("、")) {
                                        return displayText.split("、")[0]
                                    }
                                    return displayText
                                }
                                font.pixelSize: hasHoliday ? Theme.fontSizeSmall - 1 : Theme.fontSizeSmall
                                color: {
                                    if (hasHoliday) {
                                        if (isHoliday) return Theme.error
                                        if (isWorkday) return "#43a047"
                                    }
                                    return Theme.withAlpha(Theme.primary, isCurrentMonth ? 0.8 : 0.5)
                                }
                                visible: isCurrentMonth && text !== ""
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
                                root.selectDate(dayDate)
                            }
                        }
                    }
                }
            }
        }

        // Selected date info
        Rectangle {
            width: parent.width
            height: infoCol.height + Theme.spacingM
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.primary, 0.1)

            Column {
                id: infoCol
                width: parent.width
                padding: Theme.spacingM
                spacing: Theme.spacingXS

                StyledText {
                    text: {
                        const date = root.selectedDate
                        const monthKey = Qt.formatDate(date, "yyyy-MM")
                        const header = ChineseCalendarService.getMonthHeader(date.getFullYear(), date.getMonth())
                        return header || Qt.formatDate(date, "yyyy年M月")
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.primary
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        const date = root.selectedDate
                        const dateStr = Qt.formatDate(date, "yyyy-MM-dd")
                        const lunarDay = ChineseCalendarService.getLunarDayForDate(date.getDate(), date.getMonth(), date.getFullYear(), ChineseCalendarService.dataVersion)
                        const holidayInfo = ChineseCalendarService.getHolidayInfo(dateStr)
                        const isToday = date.toDateString() === new Date().toDateString()

                        let prefix = isToday ? "今天" : Qt.formatDate(date, "M月d日")

                        if (holidayInfo?.isHoliday) {
                            return prefix + "是 " + holidayInfo.name + "（放假）"
                        }
                        if (holidayInfo?.isWorkday && holidayInfo.name) {
                            return prefix + "是 " + holidayInfo.name + "（调休上班）"
                        }

                        const fullInfo = ChineseCalendarService.getFullLunarDateInfo(date.getDate(), date.getMonth(), date.getFullYear())
                        if (fullInfo) {
                            let lunarText = fullInfo.fullLunarDate
                            if (fullInfo.solarTerm) {
                                lunarText += " · " + fullInfo.solarTerm
                            }
                            return prefix + "是农历 " + lunarText
                        }

                        if (lunarDay) {
                            return prefix + "是农历 " + lunarDay
                        }
                        return prefix
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: {
                        const date = root.selectedDate
                        const dateStr = Qt.formatDate(date, "yyyy-MM-dd")
                        const holidayInfo = ChineseCalendarService.getHolidayInfo(dateStr)
                        if (holidayInfo?.isHoliday) return Theme.error
                        if (holidayInfo?.isWorkday) return "#43a047"
                        return Theme.withAlpha(Theme.primary, 0.8)
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: text !== ""
                }
            }
        }
    }

    Rectangle {
        id: fab
        width: 48
        height: 48
        radius: width / 2
        color: Theme.primary
        visible: !root.isShowingToday

        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: Theme.spacingM
        }

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 0
            verticalOffset: 2
            radius: 8
            samples: 16
            color: "#40000000"
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
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goToToday()
        }
    }

    Component.onCompleted: {
        currentMonthKey = ""
        ChineseCalendarService.loadMonthData(root.displayDate.getFullYear(), root.displayDate.getMonth())
        Qt.callLater(() => {
            currentMonthKey = Qt.formatDate(root.displayDate, "yyyy-MM")
        })
        updateShowingToday()
    }
}
