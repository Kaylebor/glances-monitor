import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showCpu: showCpu.checked
    property alias cfg_showPerCore: showPerCore.checked
    property alias cfg_showMem: showMem.checked
    property alias cfg_showSwap: showSwap.checked
    property alias cfg_showLoad: showLoad.checked
    property alias cfg_showFs: showFs.checked
    property alias cfg_showDiskio: showDiskio.checked
    property alias cfg_showNet: showNet.checked
    property alias cfg_showSensors: showSensors.checked
    property alias cfg_showGpu: showGpu.checked
    property alias cfg_showContainers: showContainers.checked
    property alias cfg_showAmps: showAmps.checked
    property alias cfg_fsFilter: fsFilter.text
    property alias cfg_diskFilter: diskFilter.text
    property alias cfg_netFilter: netFilter.text
    property alias cfg_sensorFilter: sensorFilter.text

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showCpu
            Kirigami.FormData.label: i18n("Show:")
            text: i18n("CPU")
        }
        QQC2.CheckBox {
            id: showPerCore
            text: i18n("Per-core bars")
            enabled: showCpu.checked
            leftPadding: Kirigami.Units.gridUnit
        }
        QQC2.CheckBox {
            id: showLoad
            text: i18n("Load average")
        }
        QQC2.CheckBox {
            id: showMem
            text: i18n("Memory")
        }
        QQC2.CheckBox {
            id: showSwap
            text: i18n("Swap")
        }
        QQC2.CheckBox {
            id: showFs
            text: i18n("File systems")
        }
        QQC2.CheckBox {
            id: showDiskio
            text: i18n("Disk I/O")
        }
        QQC2.CheckBox {
            id: showNet
            text: i18n("Network")
        }
        QQC2.CheckBox {
            id: showSensors
            text: i18n("Sensors")
        }
        QQC2.CheckBox {
            id: showGpu
            text: i18n("GPU")
        }
        QQC2.CheckBox {
            id: showContainers
            text: i18n("Containers")
        }
        QQC2.CheckBox {
            id: showAmps
            text: i18n("AMPs (see AMPs page)")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Filters (comma-separated, * wildcard, empty = all)")
        }
        QQC2.TextField {
            id: fsFilter
            Kirigami.FormData.label: i18n("Mount points:")
            placeholderText: "/, /srv*"
            enabled: showFs.checked
        }
        QQC2.TextField {
            id: diskFilter
            Kirigami.FormData.label: i18n("Disks:")
            placeholderText: "sda, nvme0n1"
            enabled: showDiskio.checked
        }
        QQC2.TextField {
            id: netFilter
            Kirigami.FormData.label: i18n("Interfaces:")
            placeholderText: "enp*, wlan0"
            enabled: showNet.checked
        }
        QQC2.TextField {
            id: sensorFilter
            Kirigami.FormData.label: i18n("Sensors:")
            placeholderText: "Package*, cpu_fan"
            enabled: showSensors.checked
        }
    }
}
