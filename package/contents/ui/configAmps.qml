import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property var cfg_hiddenAmps: []
    property alias cfg_ampOkPattern: okPattern.text
    property alias cfg_ampStripMatch: stripMatch.checked
    // Provided to every config page; needed here to query the server.
    property string cfg_apiUrl

    property var serverAmps: []
    property string status: i18n("Loading…")

    // Hidden names that the server no longer reports stay listed so they can be un-hidden.
    readonly property var allNames: {
        const names = serverAmps.slice();
        for (const n of cfg_hiddenAmps) {
            if (names.indexOf(n) === -1) {
                names.push(n);
            }
        }
        return names;
    }

    function setShown(name, shown) {
        const hidden = cfg_hiddenAmps.filter(n => n !== name);
        if (!shown) {
            hidden.push(name);
        }
        cfg_hiddenAmps = hidden;
    }

    function load() {
        status = i18n("Loading…");
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            if (xhr.status === 200) {
                try {
                    page.serverAmps = JSON.parse(xhr.responseText).map(a => a.name);
                    page.status = page.serverAmps.length ? "" : i18n("The server defines no AMPs.");
                } catch (e) {
                    page.status = String(e);
                }
            } else {
                page.status = i18n("Could not reach %1 (%2)", cfg_apiUrl, xhr.status === 0 ? i18n("no connection") : "HTTP " + xhr.status);
            }
        };
        xhr.open("GET", cfg_apiUrl + "/amps");
        xhr.send();
    }

    Component.onCompleted: load()

    Kirigami.FormLayout {
        QQC2.Label {
            visible: page.status !== ""
            text: page.status
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        // The list arrives after the form is built, so keep it in one column item:
        // FormLayout does not lay out children a Repeater adds later.
        ColumnLayout {
            visible: page.allNames.length > 0
            Kirigami.FormData.label: i18n("Show:")
            Repeater {
                model: page.allNames
                QQC2.CheckBox {
                    required property string modelData
                    text: page.serverAmps.indexOf(modelData) === -1 ? i18n("%1 (not on server)", modelData) : modelData
                    checked: page.cfg_hiddenAmps.indexOf(modelData) === -1
                    onToggled: page.setShown(modelData, checked)
                }
            }
        }
        QQC2.Button {
            text: i18n("Reload list")
            icon.name: "view-refresh"
            onClicked: page.load()
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }
        QQC2.TextField {
            id: okPattern
            Kirigami.FormData.label: i18n("Healthy if result matches:")
            placeholderText: "^active"
        }
        QQC2.CheckBox {
            id: stripMatch
            text: i18n("Hide the matched part")
            enabled: okPattern.text !== ""
        }
        QQC2.Label {
            text: i18n("Regular expression. Empty: use the AMP's own process-count limits, if it defines any.")
            wrapMode: Text.Wrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            Layout.fillWidth: true
        }
    }
}
