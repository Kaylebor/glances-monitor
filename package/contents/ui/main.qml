import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property string api: cfg.apiUrl.replace(/\/+$/, "")

    property bool online: false
    property string lastError: ""
    property string hostname: ""
    property var plugins: []            // from /pluginslist; empty = unknown, assume all
    property var d: ({})                // latest data per endpoint, e.g. d["quicklook"]

    // One polling round = several requests; replies from an older round are ignored.
    property int round: 0
    property int pending: 0
    property bool roundOk: true
    property var roundData: ({})

    readonly property string title: cfg.label !== "" ? cfg.label : (hostname !== "" ? hostname : "Glances")

    // ---------- helpers ----------

    function has(plugin) {
        return plugins.length === 0 || plugins.indexOf(plugin) !== -1;
    }

    function gib(bytes) {
        return (bytes / 1073741824).toFixed(1) + "G";
    }

    function rate(bytesPerSec) {
        const b = bytesPerSec || 0;
        if (b >= 1048576) {
            return (b / 1048576).toFixed(1) + "M";
        }
        if (b >= 1024) {
            return Math.round(b / 1024) + "K";
        }
        return Math.round(b) + "B";
    }

    // Comma-separated globs -> predicate. Empty filter matches everything.
    function matcher(filter) {
        const globs = filter.split(",").map(s => s.trim()).filter(s => s !== "");
        if (globs.length === 0) {
            return () => true;
        }
        const res = globs.map(g => new RegExp("^" + g.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".") + "$"));
        return name => res.some(re => re.test(name));
    }

    function views(endpoint) {
        return d[endpoint + "/views"] || {};
    }

    function deco(view) {
        return view && view.decoration ? view.decoration : "DEFAULT";
    }

    // Severity: 0 normal, 1 warning, 2 critical
    function severity(decoration) {
        const s = decoration.replace("_LOG", "");
        return s === "CRITICAL" ? 2 : s === "WARNING" ? 1 : 0;
    }

    function ampHealthy(a) {
        if (cfg.ampOkPattern !== "") {
            try {
                return new RegExp(cfg.ampOkPattern).test(String(a.result));
            } catch (e) {
                return true;
            }
        }
        if (a.countmin !== null && a.countmin !== undefined && a.count < a.countmin) {
            return false;
        }
        if (a.countmax !== null && a.countmax !== undefined && a.count > a.countmax) {
            return false;
        }
        return true;
    }

    function ampText(a) {
        const text = String(a.result || "");
        if (cfg.ampStripMatch && cfg.ampOkPattern !== "") {
            try {
                return text.replace(new RegExp(cfg.ampOkPattern), "").trim();
            } catch (e) {
                return text;
            }
        }
        return text;
    }

    // ---------- derived data ----------

    readonly property var quick: d["quicklook"] || ({})
    readonly property var mem: d["mem"] || ({})
    readonly property var swap: d["memswap"] || ({})
    readonly property var load: d["load"] || ({})
    readonly property var fsList: {
        const m = matcher(cfg.fsFilter);
        return (d["fs"] || []).filter(f => m(f.mnt_point));
    }
    readonly property var diskList: {
        const m = matcher(cfg.diskFilter);
        return (d["diskio"] || []).filter(x => m(x.disk_name));
    }
    readonly property var netList: {
        const m = matcher(cfg.netFilter);
        return (d["network"] || []).filter(x => m(x.interface_name));
    }
    readonly property var sensorList: {
        const m = matcher(cfg.sensorFilter);
        return (d["sensors"] || []).filter(s => m(s.label));
    }
    readonly property var gpuList: d["gpu"] || []
    readonly property var containerList: d["containers"] || []
    readonly property var ampList: (d["amps"] || []).filter(a => (cfg.hiddenAmps || []).indexOf(a.name) === -1)

    readonly property string tempText: {
        const t = sensorList.find(s => String(s.type).startsWith("temperature"));
        return t ? Math.round(t.value) + "°" : "–";
    }

    readonly property int worst: {
        if (!online) {
            return 2;
        }
        const qv = views("quicklook");
        let w = Math.max(severity(deco(qv.cpu)), severity(deco(qv.mem)), severity(deco(qv.swap)));
        const sv = views("sensors");
        for (const s of sensorList) {
            w = Math.max(w, severity(deco(sv[s.label] && sv[s.label].value)));
        }
        if (cfg.showAmps && ampList.some(a => !ampHealthy(a))) {
            w = Math.max(w, 1);
        }
        return w;
    }

    readonly property color stateColor: worst === 2 ? Kirigami.Theme.negativeTextColor
        : worst === 1 ? Kirigami.Theme.neutralTextColor
        : Kirigami.Theme.textColor

    function panelText(metric) {
        switch (metric) {
        case "cpu":
            return Math.round(quick.cpu || 0) + "%";
        case "mem":
            return gib(mem.used || 0);
        case "load":
            return (load.min1 || 0).toFixed(2);
        case "temp":
            return tempText;
        case "net": {
            let rx = 0, tx = 0;
            for (const n of netList) {
                rx += n.bytes_recv_rate_per_sec || 0;
                tx += n.bytes_sent_rate_per_sec || 0;
            }
            return "↓" + rate(rx) + " ↑" + rate(tx);
        }
        }
        return "";
    }

    readonly property var panelMetrics: cfg.panelMetrics.split(",").filter(m => m !== "")

    Plasmoid.icon: "network-server"
    toolTipMainText: title
    toolTipSubText: online
        ? "CPU " + Math.round(quick.cpu || 0) + "% · RAM " + gib(mem.used || 0) + "/" + gib(mem.total || 0) + (tempText !== "–" ? " · " + tempText : "")
        : i18n("Unreachable: %1", lastError)

    // ---------- polling ----------

    function get(path, myRound) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || myRound !== root.round) {
                return;
            }
            if (xhr.status === 200) {
                try {
                    root.roundData[path] = JSON.parse(xhr.responseText);
                } catch (e) {
                    root.roundOk = false;
                    root.lastError = path + ": " + e;
                }
            } else {
                root.roundOk = false;
                root.lastError = path + ": " + (xhr.status === 0 ? i18n("no connection") : "HTTP " + xhr.status);
            }
            root.pending -= 1;
            if (root.pending === 0) {
                root.finishRound();
            }
        };
        xhr.open("GET", api + "/" + path);
        xhr.send();
    }

    function finishRound() {
        const rd = roundData;
        if (rd["system"]) {
            hostname = rd["system"].hostname || "";
        }
        if (rd["pluginslist"]) {
            plugins = rd["pluginslist"];
        }
        // Keep previous values for endpoints that failed this round.
        const merged = Object.assign({}, d, rd);
        d = merged;
        online = roundOk;
        if (online) {
            lastError = "";
        }
    }

    function endpoints() {
        const e = ["quicklook", "quicklook/views", "mem", "uptime"];
        if (hostname === "") {
            e.push("system");
        }
        if (plugins.length === 0) {
            e.push("pluginslist");
        }
        const want = [
            [cfg.showSwap, "memswap", false],
            [cfg.showLoad || panelMetrics.indexOf("load") !== -1, "load", true],
            [cfg.showFs, "fs", true],
            [cfg.showDiskio, "diskio", false],
            [cfg.showNet || panelMetrics.indexOf("net") !== -1, "network", false],
            [cfg.showSensors || panelMetrics.indexOf("temp") !== -1, "sensors", true],
            [cfg.showGpu, "gpu", false],
            [cfg.showContainers, "containers", false],
            [cfg.showAmps, "amps", false]
        ];
        for (const [on, plugin, withViews] of want) {
            if (on && has(plugin)) {
                e.push(plugin);
                if (withViews) {
                    e.push(plugin + "/views");
                }
            }
        }
        return e;
    }

    function refresh() {
        // Previous round still waiting (host down, TCP timeout): count as offline.
        if (pending > 0) {
            online = false;
            if (lastError === "") {
                lastError = i18n("timeout");
            }
        }
        const list = endpoints();
        round += 1;
        pending = list.length;
        roundOk = true;
        roundData = {};
        for (const p of list) {
            get(p, round);
        }
    }

    Timer {
        interval: Math.max(2, root.cfg.interval) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ---------- panel ----------

    compactRepresentation: MouseArea {
        id: compact

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

        Layout.minimumWidth: vertical ? -1 : grid.implicitWidth
        Layout.preferredWidth: vertical ? -1 : grid.implicitWidth
        Layout.minimumHeight: vertical ? grid.implicitHeight : -1
        Layout.preferredHeight: vertical ? grid.implicitHeight : -1
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        GridLayout {
            id: grid
            anchors.centerIn: parent
            flow: compact.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: compact.vertical ? -1 : 1
            columns: compact.vertical ? 1 : -1
            rowSpacing: 0
            columnSpacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "network-server"
                color: root.stateColor
                isMask: root.worst > 0
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                Layout.alignment: Qt.AlignCenter
            }
            PlasmaComponents3.Label {
                visible: !root.online
                text: i18n("offline")
                color: root.stateColor
                font: compact.vertical ? Kirigami.Theme.smallFont : Kirigami.Theme.defaultFont
                Layout.alignment: Qt.AlignCenter
            }
            Repeater {
                model: root.online ? root.panelMetrics : []
                PlasmaComponents3.Label {
                    required property string modelData
                    text: root.panelText(modelData)
                    color: root.stateColor
                    font: compact.vertical ? Kirigami.Theme.smallFont : Kirigami.Theme.defaultFont
                    Layout.alignment: Qt.AlignCenter
                }
            }
        }
    }

    // ---------- popup ----------

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading {
                level: 4
                text: root.title
                color: root.online ? Kirigami.Theme.textColor : Kirigami.Theme.negativeTextColor
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                text: root.online ? i18n("up %1", String(root.d["uptime"] || "")) : i18n("unreachable")
                opacity: 0.7
            }
            PlasmaComponents3.ToolButton {
                visible: root.cfg.dashboardUrl !== ""
                icon.name: "internet-web-browser"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: i18n("Open dashboard")
                PlasmaComponents3.ToolTip.text: text
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: Qt.openUrlExternally(root.cfg.dashboardUrl)
            }
        }
        PlasmaComponents3.Label {
            visible: !root.online && root.lastError !== ""
            text: root.lastError
            wrapMode: Text.Wrap
            opacity: 0.7
            Layout.fillWidth: true
        }

        // CPU
        MetricRow {
            visible: root.cfg.showCpu
            label: "CPU"
            percent: root.quick.cpu || 0
            valueText: Math.round(root.quick.cpu || 0) + "%"
            decoration: root.deco(root.views("quicklook").cpu)
        }
        RowLayout {
            visible: root.cfg.showCpu && root.cfg.showPerCore
            spacing: 2
            Layout.fillWidth: true
            Item { Layout.preferredWidth: Kirigami.Units.gridUnit * 5 }
            Repeater {
                model: root.quick.percpu || []
                PlasmaComponents3.ProgressBar {
                    required property var modelData
                    from: 0
                    to: 100
                    value: modelData.total
                    Layout.fillWidth: true
                }
            }
            Item { Layout.preferredWidth: Kirigami.Units.gridUnit * 6 }
        }
        MetricRow {
            visible: root.cfg.showLoad && root.d["load"] !== undefined
            label: i18n("Load")
            valueText: (root.load.min1 || 0).toFixed(2) + " " + (root.load.min5 || 0).toFixed(2) + " " + (root.load.min15 || 0).toFixed(2)
            decoration: root.deco(root.views("load").min5)
        }

        // Memory
        MetricRow {
            visible: root.cfg.showMem
            label: "RAM"
            percent: root.mem.percent || 0
            valueText: root.gib(root.mem.used || 0) + "/" + root.gib(root.mem.total || 0)
            decoration: root.deco(root.views("quicklook").mem)
        }
        MetricRow {
            visible: root.cfg.showSwap && root.d["memswap"] !== undefined
            label: i18n("Swap")
            percent: root.swap.percent || 0
            valueText: root.gib(root.swap.used || 0) + "/" + root.gib(root.swap.total || 0)
            decoration: root.deco(root.views("quicklook").swap)
        }

        // File systems
        Repeater {
            model: root.cfg.showFs ? root.fsList : []
            MetricRow {
                required property var modelData
                label: modelData.mnt_point
                percent: modelData.percent
                valueText: root.gib(modelData.used) + "/" + root.gib(modelData.size)
                decoration: {
                    const v = root.views("fs")[modelData.mnt_point];
                    return root.deco(v && v.used);
                }
            }
        }

        // Disk I/O
        Repeater {
            model: root.cfg.showDiskio ? root.diskList : []
            MetricRow {
                required property var modelData
                label: modelData.disk_name
                valueText: "R " + root.rate(modelData.read_bytes_rate_per_sec) + "/s W " + root.rate(modelData.write_bytes_rate_per_sec) + "/s"
            }
        }

        // Network
        Repeater {
            model: root.cfg.showNet ? root.netList : []
            MetricRow {
                required property var modelData
                label: modelData.interface_name
                valueText: "↓" + root.rate(modelData.bytes_recv_rate_per_sec) + "/s ↑" + root.rate(modelData.bytes_sent_rate_per_sec) + "/s"
            }
        }

        // Sensors
        Repeater {
            model: root.cfg.showSensors ? root.sensorList : []
            MetricRow {
                required property var modelData
                label: modelData.label
                valueText: modelData.value + (modelData.unit === "C" ? "°C" : modelData.unit === "R" ? " rpm" : modelData.unit)
                decoration: {
                    const v = root.views("sensors")[modelData.label];
                    return root.deco(v && v.value);
                }
            }
        }

        // GPU
        Repeater {
            model: root.cfg.showGpu ? root.gpuList : []
            MetricRow {
                required property var modelData
                label: modelData.name
                percent: modelData.proc !== null ? modelData.proc : -1
                valueText: (modelData.proc !== null ? Math.round(modelData.proc) + "%" : "–") + (modelData.temperature !== null ? " " + modelData.temperature + "°C" : "")
            }
        }

        // Containers
        Repeater {
            model: root.cfg.showContainers ? root.containerList : []
            MetricRow {
                required property var modelData
                label: modelData.name
                valueText: String(modelData.status || "")
                decoration: String(modelData.status) === "running" ? "DEFAULT" : "WARNING"
            }
        }

        // AMPs
        Kirigami.Separator {
            visible: root.cfg.showAmps && root.ampList.length > 0
            Layout.fillWidth: true
        }
        Repeater {
            model: root.cfg.showAmps ? root.ampList : []
            RowLayout {
                required property var modelData
                readonly property bool healthy: root.ampHealthy(modelData)
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: modelData.name
                    font.bold: true
                    color: healthy ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                    elide: Text.ElideRight
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                }
                PlasmaComponents3.Label {
                    text: root.ampText(modelData)
                    elide: Text.ElideRight
                    opacity: 0.85
                    Layout.fillWidth: true
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: truncated && hoverHandler.hovered
                    HoverHandler {
                        id: hoverHandler
                    }
                }
            }
        }
    }
}
