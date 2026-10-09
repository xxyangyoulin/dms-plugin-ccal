import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.DDash
import qs.DCommon.Widgets
import "./components"

DashCardComponent {
    id: root

    readonly property string dateKey: Qt.formatDate(clock.date, "yyyy-MM-dd")
    readonly property bool calendarMode: width >= DashMetrics.gridRowUnit * 3 && height >= DashMetrics.gridRowUnit * 4
    focusTarget: calendarMode ? calendar.focusTarget : null
    pad: Theme.spacingS
    property var lunarInfo: null
    property var holidayStatus: null
    readonly property string holidayText: {
        if (!holidayStatus)
            return "";
        if (holidayStatus.inHoliday)
            return I18n.trFor("chineseCalendar", "%1假期还剩 %2 天").arg(holidayStatus.holidayName).arg(holidayStatus.totalDays);
        return I18n.trFor("chineseCalendar", "距离%1还有 %2 天").arg(holidayStatus.name).arg(holidayStatus.daysUntil);
    }

    onDateKeyChanged: refresh()
    onLiveChanged: {
        if (live)
            refresh();
    }
    Component.onCompleted: refresh()

    function refresh() {
        if (!live)
            return;
        const today = clock.date;
        lunarInfo = ChineseCalendarService.getFullLunarDateInfo(today.getDate(), today.getMonth(), today.getFullYear());
        holidayStatus = ChineseCalendarService.getHolidayStatus(today);
    }

    SystemClock {
        id: clock
        enabled: root.live
        precision: SystemClock.Hours
    }

    Connections {
        target: ChineseCalendarService

        function onLunarDataUpdated() {
            root.refresh();
        }

        function onHolidayDataUpdated() {
            root.refresh();
        }
    }

    Column {
        visible: !root.calendarMode
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        StyledText {
            width: parent.width
            text: Qt.formatDate(clock.date, "yyyy-MM · dddd")
            font.pixelSize: Theme.fontSizeSmall
            color: root.mutedColor
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            text: Qt.formatDate(clock.date, "dd")
            font.pixelSize: Theme.fontSizeDisplay
            font.weight: Theme.fontWeightMedium
            color: root.accentColor
        }

        StyledText {
            width: parent.width
            text: ChineseCalendarService.ccalChecking
                ? I18n.trFor("chineseCalendar", "正在检查 ccal…")
                : !ChineseCalendarService.ccalAvailable
                    ? I18n.trFor("chineseCalendar", "未安装 ccal")
                    : root.lunarInfo
                        ? I18n.trFor("chineseCalendar", "农历 %1").arg(root.lunarInfo.fullLunarDate)
                        : I18n.trFor("chineseCalendar", "正在加载农历…")
            font.pixelSize: Theme.fontSizeMedium
            color: root.contentColor
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: !!root.lunarInfo?.solarTerm
            text: root.lunarInfo?.solarTerm ?? ""
            font.pixelSize: Theme.fontSizeSmall
            color: root.accentColor
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: root.holidayText
            font.pixelSize: Theme.fontSizeSmall
            color: root.mutedColor
            elide: Text.ElideRight
        }
    }

    CcalCalendar {
        id: calendar
        anchors.fill: parent
        visible: root.calendarMode
        live: root.live && visible
        interactive: root.interactive
    }
}
