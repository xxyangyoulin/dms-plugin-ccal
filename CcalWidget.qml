import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.DDash
import "./components"

PluginComponent {
    id: root

    pluginId: "chineseCalendar"

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

            CcalCalendar {
                id: calendar
                width: parent.width
                height: DashMetrics.gridRowUnit * 4
                live: popoutRoot.parentPopout?.shouldBeVisible ?? false
                onLiveChanged: {
                    if (live)
                        goToToday();
                }
            }
        }
    }
}
