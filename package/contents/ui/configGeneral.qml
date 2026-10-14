import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_apiUrl: apiUrl.text
    property alias cfg_dashboardUrl: dashboardUrl.text
    property alias cfg_label: label.text
    property alias cfg_interval: interval.value
    property string cfg_panelMetrics

    readonly property var metricChoices: [
        { key: "cpu", text: i18n("CPU %") },
        { key: "mem", text: i18n("RAM used") },
        { key: "load", text: i18n("Load (1 min)") },
        { key: "temp", text: i18n("Temperature") },
        { key: "net", text: i18n("Network rate") }
    ]

    function hasMetric(key) {
        return cfg_panelMetrics.split(",").indexOf(key) !== -1;
    }

    function setMetric(key, on) {
        // Keep the canonical order of metricChoices.
        const current = cfg_panelMetrics.split(",").filter(k => k !== "");
        const wanted = metricChoices.map(m => m.key).filter(k => k === key ? on : current.indexOf(k) !== -1);
        cfg_panelMetrics = wanted.join(",");
    }

    Kirigami.FormLayout {
        QQC2.TextField {
            id: apiUrl
            Kirigami.FormData.label: i18n("Glances API URL:")
            placeholderText: "http://host:61208/api/4"
            Layout.fillWidth: true
        }
        QQC2.TextField {
            id: label
            Kirigami.FormData.label: i18n("Name:")
            placeholderText: i18n("Server hostname")
        }
        QQC2.TextField {
            id: dashboardUrl
            Kirigami.FormData.label: i18n("Dashboard link:")
            placeholderText: i18n("Optional, e.g. the Glances web UI")
            Layout.fillWidth: true
        }
        QQC2.SpinBox {
            id: interval
            Kirigami.FormData.label: i18n("Refresh (seconds):")
            from: 2
            to: 60
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel")
        }
        Repeater {
            model: metricChoices
            QQC2.CheckBox {
                required property var modelData
                required property int index
                Kirigami.FormData.label: index === 0 ? i18n("Show:") : ""
                text: modelData.text
                checked: hasMetric(modelData.key)
                onToggled: setMetric(modelData.key, checked)
            }
        }
    }
}
