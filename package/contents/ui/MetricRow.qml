import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// One compact line: label | optional bar | value, coloured by Glances' alert level.
RowLayout {
    id: row

    property string label
    property real percent: -1          // < 0 hides the bar
    property string valueText
    property string decoration: "DEFAULT"

    readonly property color levelColor: {
        const d = decoration.replace("_LOG", "");
        if (d === "CRITICAL") {
            return Kirigami.Theme.negativeTextColor;
        }
        if (d === "WARNING") {
            return Kirigami.Theme.neutralTextColor;
        }
        return Kirigami.Theme.textColor;
    }

    spacing: Kirigami.Units.smallSpacing
    Layout.fillWidth: true

    PlasmaComponents3.Label {
        text: row.label
        elide: Text.ElideRight
        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
    }
    PlasmaComponents3.ProgressBar {
        visible: row.percent >= 0
        from: 0
        to: 100
        value: Math.max(0, row.percent)
        Layout.fillWidth: true
    }
    Item {
        visible: row.percent < 0
        Layout.fillWidth: true
    }
    PlasmaComponents3.Label {
        text: row.valueText
        color: row.levelColor
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
    }
}
