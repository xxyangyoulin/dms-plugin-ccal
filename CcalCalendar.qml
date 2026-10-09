pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.DDash
import "./components"

Item {
    id: root

    property bool live: false
    property bool interactive: true
    property date displayDate: new Date()
    property date selectedDate: new Date()
    property int revision: 0
    property bool showingMonthSelector: false
    property int selectorYear: displayDate.getFullYear()
    readonly property int weekStartQt: SettingsData.firstDayOfWeek >= 0 && SettingsData.firstDayOfWeek < 7 ? SettingsData.firstDayOfWeek : Qt.locale().firstDayOfWeek
    readonly property bool ccalAvailable: ChineseCalendarService.ccalAvailable
    readonly property string dateKey: Qt.formatDate(clock.date, "yyyy-MM-dd")
    readonly property Item focusTarget: ccalAvailable ? previousButton : retryButton
    readonly property var selectedHolidayStatus: {
        root.revision;
        return ChineseCalendarService.getHolidayStatus(selectedDate);
    }
    readonly property string selectedHolidayCountdown: {
        const status = selectedHolidayStatus;
        if (!status)
            return "";
        if (status.inHoliday) {
            if (status.remainingDays > 0)
                return I18n.trFor("chineseCalendar", "%1假期，剩余 %2 天").arg(status.holidayName).arg(status.remainingDays);
            return I18n.trFor("chineseCalendar", "%1假期最后一天").arg(status.holidayName);
        }
        return I18n.trFor("chineseCalendar", "距 %1 还有 %2 天").arg(status.name).arg(status.daysUntil);
    }
    readonly property string selectedLunarText: {
        root.revision;
        const info = ChineseCalendarService.getFullLunarDateInfo(selectedDate.getDate(), selectedDate.getMonth(), selectedDate.getFullYear());
        const holiday = ChineseCalendarService.getHolidayInfo(Qt.formatDate(selectedDate, "yyyy-MM-dd"));
        const parts = [Qt.formatDate(selectedDate, "MMM d")];
        if (info)
            parts.push(I18n.trFor("chineseCalendar", "农历 %1").arg(info.fullLunarDate));
        if (holiday)
            parts.push(holiday.name + (holiday.isWorkday ? I18n.trFor("chineseCalendar", "（调休）") : ""));
        if (info?.solarTerm)
            parts.push(info.solarTerm);
        return parts.join(" · ");
    }

    enabled: interactive
    onDisplayDateChanged: loadMonth()
    onCcalAvailableChanged: loadMonth()
    onDateKeyChanged: {
        if (live)
            goToToday();
    }
    onLiveChanged: {
        if (!live)
            return;
        revision++;
        loadMonth();
    }
    Component.onCompleted: loadMonth()

    function loadMonth() {
        if (!live || !ccalAvailable)
            return;
        const year = displayDate.getFullYear();
        const month = displayDate.getMonth();
        for (let offset = -1; offset <= 1; offset++) {
            const date = new Date(year, month + offset, 1);
            ChineseCalendarService.loadMonthData(date.getFullYear(), date.getMonth());
        }
        ChineseCalendarService.loadHolidayDataForYear(year);
        if (month === 0)
            ChineseCalendarService.loadHolidayDataForYear(year - 1);
        if (month === 11)
            ChineseCalendarService.loadHolidayDataForYear(year + 1);
    }

    function shiftMonth(delta) {
        if (showingMonthSelector) {
            selectorYear += delta;
            return;
        }
        displayDate = new Date(displayDate.getFullYear(), displayDate.getMonth() + delta, 1, 12);
    }

    function goToToday() {
        showingMonthSelector = false;
        selectedDate = clock.date;
        displayDate = clock.date;
    }

    function weekNumberFor(date) {
        const start = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        const weekStart = weekStartQt % 7;
        start.setUTCDate(start.getUTCDate() - (start.getUTCDay() - weekStart + 7) % 7);
        const target = new Date(start);
        target.setUTCDate(target.getUTCDate() + (weekStart === 1 ? 3 : 6));
        const first = new Date(Date.UTC(target.getUTCFullYear(), 0, weekStart === 1 ? 4 : 1));
        first.setUTCDate(first.getUTCDate() - (first.getUTCDay() - weekStart + 7) % 7);
        return Math.floor((start - first) / 604800000) + 1;
    }

    SystemClock {
        id: clock
        enabled: root.live
        precision: SystemClock.Hours
    }

    Connections {
        target: ChineseCalendarService

        function onLunarDataUpdated() {
            if (root.live)
                root.revision++;
        }

        function onHolidayDataUpdated() {
            if (root.live)
                root.revision++;
        }
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: DashMetrics.monthNavSize

        NavButton {
            id: previousButton
            anchors.left: parent.left
            iconName: I18n.isRtl ? "chevron_right" : "chevron_left"
            iconColor: Theme.onSurfaceVariant
            Accessible.name: I18n.tr("Previous")
            onClicked: root.shiftMonth(-1)
        }

        StyledText {
            anchors.centerIn: parent
            width: parent.width - DashMetrics.monthNavSize * 4
            text: root.showingMonthSelector ? root.selectorYear : root.displayDate.toLocaleDateString(I18n.locale(), "MMMM yyyy")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectorYear = root.displayDate.getFullYear();
                    root.showingMonthSelector = !root.showingMonthSelector;
                }
            }
        }

        Row {
            anchors.right: parent.right

            NavButton {
                iconName: "today"
                enabled: root.showingMonthSelector || root.displayDate.getFullYear() !== clock.date.getFullYear() || root.displayDate.getMonth() !== clock.date.getMonth() || !monthGrid.sameDay(root.selectedDate, clock.date)
                Accessible.name: I18n.tr("Today")
                onClicked: root.goToToday()
            }

            NavButton {
                iconName: I18n.isRtl ? "chevron_left" : "chevron_right"
                iconColor: Theme.onSurfaceVariant
                Accessible.name: I18n.tr("Next")
                onClicked: root.shiftMonth(1)
            }
        }
    }

    DMonthGrid {
        id: monthGrid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: Theme.spacingS
        anchors.bottom: details.top
        anchors.bottomMargin: Theme.spacingS
        visible: !root.showingMonthSelector
        displayDate: root.displayDate
        selectedDate: root.selectedDate
        today: clock.date
        firstDayOfWeek: root.weekStartQt % 7
        dayNames: {
            const days = [];
            for (let index = 0; index < 7; index++)
                days.push(I18n.locale().dayName(((root.weekStartQt - 1 + index) % 7) + 1, Locale.ShortFormat));
            return days;
        }
        showWeekNumbers: SettingsData.showWeekNumber
        weekColumnWidth: DashMetrics.weekColumnWidth
        weekNumberFor: date => root.weekNumberFor(date)
        interactive: root.interactive
        onDayClicked: date => {
            root.selectedDate = date;
            if (date.getMonth() !== root.displayDate.getMonth() || date.getFullYear() !== root.displayDate.getFullYear())
                root.displayDate = date;
        }

        Repeater {
            model: root.live && monthGrid.visible ? monthGrid.columns * monthGrid.rows : 0

            StyledText {
                required property int index
                readonly property date dayDate: monthGrid.dateAt(index)
                readonly property bool selected: monthGrid.sameDay(dayDate, root.selectedDate)
                readonly property bool inMonth: dayDate.getMonth() === root.displayDate.getMonth()
                readonly property var holiday: {
                    root.revision;
                    return ChineseCalendarService.getHolidayInfo(Qt.formatDate(dayDate, "yyyy-MM-dd"));
                }
                x: I18n.isRtl ? monthGrid.width - monthGrid.gridLeft - (index % monthGrid.columns) * (monthGrid.cellWidth + monthGrid.cellGap) - width : monthGrid.gridLeft + (index % monthGrid.columns) * (monthGrid.cellWidth + monthGrid.cellGap)
                y: monthGrid.weekdayRowHeight + monthGrid.cellGap + Math.floor(index / monthGrid.columns) * (monthGrid.cellHeight + monthGrid.cellGap) + monthGrid.cellHeight - height - Theme.spacingXS
                width: monthGrid.cellWidth
                text: {
                    root.revision;
                    if (holiday?.isWorkday)
                        return I18n.trFor("chineseCalendar", "班");
                    if (holiday?.name)
                        return holiday.name;
                    return ChineseCalendarService.getLunarDayForDate(dayDate.getDate(), dayDate.getMonth(), dayDate.getFullYear(), root.revision);
                }
                font.pixelSize: Theme.fontSizeSmall
                color: {
                    if (selected)
                        return Theme.onPrimary;
                    const base = holiday?.isHoliday ? Theme.error : holiday?.isWorkday ? Theme.success : Theme.onSurfaceVariant;
                    return inMonth ? base : Theme.withAlpha(base, 0.38);
                }
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: monthGrid.cellHeight >= Theme.fontSizeMedium + implicitHeight + Theme.spacingXS * 3
            }
        }
    }

    Grid {
        anchors.fill: monthGrid
        visible: root.showingMonthSelector
        columns: 3
        spacing: Theme.spacingXS

        Repeater {
            model: 12

            DButton {
                required property int index
                width: (parent.width - parent.spacing * 2) / 3
                height: (parent.height - parent.spacing * 3) / 4
                text: I18n.locale().monthName(index + 1, Locale.ShortFormat)
                onClicked: {
                    root.displayDate = new Date(root.selectorYear, index, 1, 12);
                    root.showingMonthSelector = false;
                }
            }
        }
    }

    Row {
        id: details
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(detailText.implicitHeight, retryButton.visible ? retryButton.implicitHeight : 0)
        spacing: Theme.spacingXS

        StyledText {
            id: detailText
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (retryButton.visible ? retryButton.width + parent.spacing : 0)
            text: !root.ccalAvailable
                ? I18n.trFor("chineseCalendar", "未安装 ccal")
                : [root.selectedLunarText, root.selectedHolidayCountdown].filter(part => part !== "").join(" · ")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.onSurfaceVariant
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        DActionButton {
            id: retryButton
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.ccalAvailable
            enabled: !ChineseCalendarService.ccalChecking
            buttonSize: DashMetrics.monthNavSize
            iconSize: DashMetrics.monthNavIconSize
            iconName: "refresh"
            iconColor: Theme.primary
            tooltipText: I18n.trFor("chineseCalendar", "重新检测 ccal")
            onClicked: ChineseCalendarService.recheckCcalAvailability()
        }
    }

    component NavButton: DActionButton {
        buttonSize: DashMetrics.monthNavSize
        iconSize: DashMetrics.monthNavIconSize
        iconColor: Theme.primary
    }
}
