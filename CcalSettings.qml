import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root
    pluginId: "chineseCalendar"

    StyledText {
        text: "农历插件设置"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "在状态栏显示当前日期，点击可查看完整农历日历。"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    // Date format section
    StyledText {
        text: "日期格式"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    Column {
        width: parent.width
        spacing: Theme.spacingM

        StringSetting {
            id: dateFormatSetting
            settingKey: "dateFormat"
            label: "格式字符串"
            description: "使用 d、M、yyyy 等表示日期，LL 表示农历日期"
            placeholder: "例如：ddd MM月dd日 LL"
            defaultValue: "ddd MM月dd日 LL"
        }

        // Quick format presets
        StyledText {
            text: "快捷预设"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: [
                    { label: "ddd MM月dd日 LL", format: "ddd MM月dd日 LL" },
                    { label: "yyyy/MM/dd LL", format: "yyyy/MM/dd LL" },
                    { label: "MM/dd LL", format: "MM/dd LL" },
                    { label: "LL", format: "LL" }
                ]

                Rectangle {
                    width: (parent.width - Theme.spacingS * 3) / 4
                    height: 32
                    radius: Theme.cornerRadius
                    color: mouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.1) : Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Theme.outlineVariant

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.saveValue("dateFormat", modelData.format)
                            // Trigger reload to update the text field
                            Qt.callLater(function() {
                                dateFormatSetting.loadValue()
                            })
                        }
                    }
                }
            }
        }

        // Format legend
        StyledRect {
            width: parent.width
            height: formatHelpColumn.height + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: formatHelpColumn
                width: parent.width
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingXS

                StyledText {
                    text: "格式说明"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primary
                    font.weight: Font.Medium
                }

                Column {
                    width: parent.width
                    spacing: 2

                    StyledText { text: "• d/dd - 日期 (3/03)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    StyledText { text: "• ddd/dddd - 星期 (三/星期三)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    StyledText { text: "• M/MM/MMMM - 月份 (2/02/二月)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    StyledText { text: "• yyyy - 年份 (2025)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    StyledText { text: "• LL - 农历日 (廿一)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    StyledText { text: "• LLL - 农历月日 (正月廿一)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    StyledText { text: "• LLLL - 完整农历 (丙午年正月大17日始廿一)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    StyledText { text: "• LY - 干支 (丙午)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    StyledText { text: "• LA - 生肖 (马)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                }
            }
        }
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "确保系统已安装 ccal 和 curl 命令。"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        width: parent.width
    }
}
