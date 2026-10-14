import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "network-server"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Sections")
        icon: "view-list-details"
        source: "configSections.qml"
    }
    ConfigCategory {
        name: i18n("AMPs")
        icon: "system-run"
        source: "configAmps.qml"
    }
}
