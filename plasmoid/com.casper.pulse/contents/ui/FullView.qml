// Pulse, popup view.
// Tabs: Overview, Threats, Local, History, Settings.
//
// (c) Venode Labs

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: full

    property var healthData: ({})
    property var threatsData: ({})
    property var relevantData: ({})
    property var scoreData: ({})
    property var briefingData: ({})
    property string lastError: ""

    signal refreshRequested()

    Layout.preferredWidth:  Kirigami.Units.gridUnit * 28
    Layout.preferredHeight: Kirigami.Units.gridUnit * 38
    implicitWidth:  Kirigami.Units.gridUnit * 28
    implicitHeight: Kirigami.Units.gridUnit * 38

    // -----------------------------------------------------------------
    // Style: all text and colour references go through these properties
    // so the Settings tab changes take effect everywhere instantly.

    readonly property real   fs:       Plasmoid.configuration.fontSizeMultiplier
    readonly property real   smallPx:  Math.round(Kirigami.Theme.smallFont.pixelSize   * fs)
    readonly property real   basePx:   Math.round(Kirigami.Theme.defaultFont.pixelSize * fs)
    readonly property real   largePx:  Math.round(Kirigami.Units.gridUnit * 1.1        * fs)
    readonly property string cfgMono:  Plasmoid.configuration.monoFont   || "Geist Mono"
    readonly property string cfgUi:    Plasmoid.configuration.uiFont      || ""

    readonly property bool   _isDark:  Plasmoid.configuration.themePalette === "dark"
    readonly property bool   _isLight: Plasmoid.configuration.themePalette === "light"

    // Resolved colours — callers use these, never Kirigami.Theme directly.
    readonly property color uiText:  _isDark ? "#e2e2f2" : (_isLight ? "#1a192a" : Kirigami.Theme.textColor)
    readonly property color uiDim:   _isDark ? "#7878a0" : (_isLight ? "#56566a" : Kirigami.Theme.disabledTextColor)
    readonly property color uiBg:    _isDark ? "#13131f" : (_isLight ? "#f4f4f8" : "transparent")
    readonly property color uiAlt:   _isDark ? "#1e1e30" : (_isLight ? "#e8e8f0" : Kirigami.Theme.alternateBackgroundColor)
    readonly property color uiSep:   _isDark ? "#2a2a42" : (_isLight ? "#ccccdd" : Kirigami.Theme.separatorColor)

    // Forced background when the user has picked a non-system palette.
    Rectangle {
        anchors.fill: parent
        color:        uiBg
        visible:      !_isDark === !_isLight && Plasmoid.configuration.themePalette !== "system"
                      || _isDark || _isLight
        z: -1
    }

    // Off-screen TextEdit used as clipboard sink.
    TextEdit { id: clipHelper; visible: false; width: 1; height: 1 }

    function copyToClipboard(str) {
        clipHelper.text = str;
        clipHelper.selectAll();
        clipHelper.copy();
    }

    // -----------------------------------------------------------------
    // Domain helpers

    function severityColour(sev) {
        switch ((sev || "").toString().toLowerCase()) {
            case "critical": return "#d32f2f";
            case "high":     return "#e44b3a";
            case "warn":
            case "medium":   return "#f9a825";
            case "info":
            case "low":      return "#1976d2";
            case "ok":       return "#43a047";
            default:         return uiDim;
        }
    }

    function scoreColour(s) {
        if (s === undefined || s === null) return uiDim;
        if (s >= 85) return "#43a047";
        if (s >= 65) return "#f9a825";
        if (s >= 40) return "#e44b3a";
        return "#d32f2f";
    }

    function prettyKey(k) {
        var map = {
            firewall:        "Firewall",
            apparmor:        "AppArmor",
            usbguard:        "USBGuard",
            updates:         "Pending updates",
            secureboot:      "Secure Boot",
            tpm:             "TPM",
            luks:            "Disk encryption",
            failed_logins:   "Failed logins (24h)",
            listening_ports: "External listeners",
            vpn:             "VPN tunnel",
            kernel:          "Kernel",
            suid:            "SUID inventory",
            ssh:             "SSH daemon",
            last_upgrade:    "Last full upgrade"
        };
        return map[k] || k;
    }

    function detail(k, v) {
        if (!v) return "";
        switch (k) {
            case "firewall":        return v.active ? v.engine : "no firewall service active";
            case "apparmor":        return v.active ? "enforcing" : "inactive";
            case "usbguard":        return v.installed ? (v.active ? "active" : "installed, inactive") : "not installed";
            case "updates":         return v.total + " package(s)" + (v.kernel_pending ? ", kernel update pending" : "");
            case "secureboot":      return v.state;
            case "tpm":             return v.present ? "present" : "not present";
            case "luks":            return v.present ? "encrypted volume present" : "no encrypted volume";
            case "failed_logins":   return v.count_24h + " failed login(s)";
            case "listening_ports": return v.external_listeners + " external listener(s)";
            case "vpn":             return v.active ? "tunnel up" : "no tunnel";
            case "kernel":          return v.running + " · " + v.days_since_install + "d since install";
            case "suid":            return v.count + " bins · +" + v.added_since_baseline + " / -" + v.removed_since_baseline + " vs baseline";
            case "ssh":             return (v.sshd_present || v.sshd_config_present)
                                        ? ("sshd present (password=" + v.password_auth + ", root=" + v.permit_root_login + ")")
                                        : "no sshd";
            case "last_upgrade":    return v.days + " days since last -Syu";
            default:                return JSON.stringify(v);
        }
    }

    function itemEntries() {
        if (!healthData.items) return [];
        var out = [];
        var order = ["firewall","apparmor","usbguard","updates","secureboot",
                     "tpm","luks","failed_logins","listening_ports","vpn",
                     "kernel","suid","ssh","last_upgrade"];
        for (var i = 0; i < order.length; i++) {
            var k = order[i];
            if (healthData.items[k] !== undefined)
                out.push({ key: k, value: healthData.items[k] });
        }
        return out;
    }

    // Font-size label helpers for the Settings slider.
    function fsSizeLabel(v) {
        if (v <= 0.85) return "Compact";
        if (v <= 0.95) return "Small";
        if (v <= 1.05) return "Normal";
        if (v <= 1.20) return "Large";
        return "XL";
    }

    // -----------------------------------------------------------------
    // Header

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width:  Kirigami.Units.gridUnit * 1.2
                height: width
                radius: width / 2
                color:  severityColour(healthData.overall || "info")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Kirigami.Heading { level: 2; text: "Pulse"; color: uiText }
                QQC.Label {
                    text: healthData.host
                        ? (healthData.host + " · " + ((relevantData && relevantData.count) || 0) + " relevant CVE(s)")
                        : "Waiting for collector"
                    color: uiDim
                    font.pixelSize: smallPx
                    font.family:    cfgUi
                }
            }

            QQC.ToolButton {
                icon.name: "view-refresh"
                text: "Refresh"
                onClicked: full.refreshRequested()
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // -----------------------------------------------------------------
        // Tab bar

        QQC.TabBar {
            id: tabs
            Layout.fillWidth: true
            QQC.TabButton { text: "Overview" }
            QQC.TabButton { text: "Threats"  }
            QQC.TabButton { text: "Local"    }
            QQC.TabButton { text: "History"  }
            QQC.TabButton { text: "Settings" }
        }

        StackLayout {
            id: pages
            currentIndex: tabs.currentIndex
            Layout.fillWidth:  true
            Layout.fillHeight: true

            // ============================================================
            // 0 · Overview
            // ============================================================
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                RowLayout {
                    Layout.fillWidth:  true
                    Layout.topMargin:  Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    Item {
                        Layout.preferredWidth:  Kirigami.Units.gridUnit * 8
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 8

                        Canvas {
                            id: gauge
                            anchors.fill: parent
                            property int score: (scoreData && scoreData.score !== undefined)
                                ? scoreData.score : (healthData.score || 0)
                            onScoreChanged:       requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width / 2, cy = height / 2;
                                var r  = Math.min(cx, cy) - 6;
                                var s  = -Math.PI * 0.75, e = Math.PI * 0.75;
                                ctx.lineCap   = "round";
                                ctx.lineWidth = 9;
                                ctx.strokeStyle = full.uiAlt;
                                ctx.beginPath(); ctx.arc(cx, cy, r, s, e); ctx.stroke();
                                var frac = Math.max(0, Math.min(1, score / 100));
                                ctx.strokeStyle = full.scoreColour(score);
                                ctx.beginPath(); ctx.arc(cx, cy, r, s, s + (e - s) * frac); ctx.stroke();
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0
                            QQC.Label {
                                text: (scoreData && scoreData.score !== undefined)
                                    ? scoreData.score : (healthData.score || 0)
                                font.pixelSize: Kirigami.Units.gridUnit * 2.5 * fs
                                font.bold: true
                                font.family: cfgUi
                                color: scoreColour((scoreData && scoreData.score) || 0)
                                horizontalAlignment: Text.AlignHCenter
                                Layout.alignment: Qt.AlignHCenter
                            }
                            QQC.Label {
                                text: "/ 100"
                                color: uiDim
                                font.pixelSize: smallPx
                                font.family:    cfgUi
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Heading { level: 3; text: "Composite score"; color: uiText }
                        QQC.Label {
                            text: "Local health blended with the count of CVEs that match the packages installed on this machine."
                            color: uiDim
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            font.pixelSize: smallPx
                            font.family:    cfgUi
                        }

                        GridLayout {
                            columns: 3
                            columnSpacing: Kirigami.Units.largeSpacing
                            rowSpacing: 0
                            Layout.topMargin: Kirigami.Units.smallSpacing

                            QQC.Label { text: "Critical"; color: "#d32f2f"; font.bold: true; font.pixelSize: basePx; font.family: cfgUi }
                            QQC.Label { text: "High";     color: "#e44b3a"; font.bold: true; font.pixelSize: basePx; font.family: cfgUi }
                            QQC.Label { text: "Medium";   color: "#f9a825"; font.bold: true; font.pixelSize: basePx; font.family: cfgUi }

                            QQC.Label { text: (scoreData && scoreData.relevant) ? scoreData.relevant.critical : 0; font.pixelSize: largePx; font.family: cfgUi; color: uiText }
                            QQC.Label { text: (scoreData && scoreData.relevant) ? scoreData.relevant.high     : 0; font.pixelSize: largePx; font.family: cfgUi; color: uiText }
                            QQC.Label { text: (scoreData && scoreData.relevant) ? scoreData.relevant.medium   : 0; font.pixelSize: largePx; font.family: cfgUi; color: uiText }
                        }
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }
                Kirigami.Heading { level: 3; text: "Top relevant CVEs"; color: uiText }

                QQC.ScrollView {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        model: relevantData.items ? relevantData.items.slice(0, 6) : []
                        spacing: Kirigami.Units.smallSpacing
                        delegate: ColumnLayout {
                            id: ovRow
                            width: ListView.view.width
                            spacing: 2
                            property bool rowHovered: false
                            HoverHandler { onHoveredChanged: ovRow.rowHovered = hovered }

                            RowLayout {
                                Layout.fillWidth: true
                                Rectangle {
                                    width: Kirigami.Units.smallSpacing
                                    Layout.preferredHeight: Kirigami.Units.gridUnit
                                    color: severityColour(modelData.severity)
                                }
                                TextEdit {
                                    text: modelData.id
                                    font.family: cfgMono
                                    font.bold: true
                                    font.pixelSize: basePx
                                    color: uiText
                                    readOnly: true; selectByMouse: true
                                    wrapMode: Text.NoWrap
                                }
                                TextEdit {
                                    text: modelData.package
                                    color: uiDim
                                    font.pixelSize: basePx
                                    font.family: cfgUi
                                    readOnly: true; selectByMouse: true
                                    wrapMode: Text.NoWrap
                                    Layout.fillWidth: true
                                }
                                QQC.Label {
                                    visible: modelData.source === "kev" || modelData.status === "KnownExploited"
                                    text: "KEV"; color: "#d32f2f"
                                    font.pixelSize: smallPx; font.bold: true; font.family: cfgUi
                                }
                                QQC.Label {
                                    visible: modelData.epss !== undefined && modelData.epss !== null
                                    text: (modelData.epss !== undefined && modelData.epss !== null)
                                        ? ("EPSS " + (modelData.epss * 100).toFixed(1) + "%") : ""
                                    color: uiDim; font.pixelSize: smallPx; font.family: cfgUi
                                }
                                QQC.Label {
                                    text: modelData.severity || ""
                                    color: severityColour(modelData.severity)
                                    font.pixelSize: smallPx; font.bold: true; font.family: cfgUi
                                }
                                QQC.ToolButton {
                                    visible: ovRow.rowHovered
                                    icon.name: "edit-copy"; flat: true
                                    implicitWidth: Kirigami.Units.iconSizes.small
                                    implicitHeight: Kirigami.Units.iconSizes.small
                                    onClicked: full.copyToClipboard(modelData.id + " " + modelData.package)
                                    QQC.ToolTip.text: "Copy ID"; QQC.ToolTip.visible: hovered; QQC.ToolTip.delay: 600
                                }
                            }
                            TextEdit {
                                text: modelData.title || ""
                                color: uiDim; font.pixelSize: smallPx; font.family: cfgUi
                                readOnly: true; selectByMouse: true
                                wrapMode: Text.Wrap; Layout.fillWidth: true
                            }
                        }
                    }
                }

                QQC.Label {
                    visible: (briefingData && briefingData.summary) ? true : false
                    text: briefingData.summary || ""
                    wrapMode: Text.Wrap; Layout.fillWidth: true
                    font.italic: true; font.pixelSize: basePx; font.family: cfgUi
                    color: uiText
                }
            }

            // ============================================================
            // 1 · Threats
            // ============================================================
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.largeSpacing
                    QQC.Label {
                        text: threatsData.kev
                            ? (threatsData.kev.new_week + " new CISA KEV this week · " + threatsData.kev.total + " total exploited")
                            : "KEV feed not available"
                        font.pixelSize: smallPx; font.family: cfgUi; color: uiDim
                        Layout.fillWidth: true
                    }
                }

                QQC.ComboBox {
                    id: feedPicker
                    Layout.fillWidth: true
                    model: ["CISA KEV (exploited)", "Arch ALSA", "NVD recent", "GitHub Security Advisories"]
                }

                QQC.ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true

                    ListView {
                        spacing: Kirigami.Units.smallSpacing
                        model: {
                            if (feedPicker.currentIndex === 0) return (threatsData.kev  && threatsData.kev.recent)  || [];
                            if (feedPicker.currentIndex === 1) return (threatsData.arch && threatsData.arch.recent) || [];
                            if (feedPicker.currentIndex === 2) return (threatsData.nvd  && threatsData.nvd.recent)  || [];
                            if (feedPicker.currentIndex === 3) return (threatsData.ghsa && threatsData.ghsa.recent) || [];
                            return [];
                        }
                        delegate: ColumnLayout {
                            id: threatRow
                            width: ListView.view.width; spacing: 2
                            property bool rowHovered: false
                            HoverHandler { onHoveredChanged: threatRow.rowHovered = hovered }

                            RowLayout {
                                Layout.fillWidth: true
                                TextEdit {
                                    text: modelData.cve || modelData.id
                                    font.family: cfgMono; font.bold: true; font.pixelSize: basePx
                                    color: uiText; readOnly: true; selectByMouse: true; wrapMode: Text.NoWrap
                                }
                                QQC.Label {
                                    text: modelData.added || modelData.published || ""
                                    color: uiDim; Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: smallPx; font.family: cfgUi
                                }
                                QQC.ToolButton {
                                    visible: threatRow.rowHovered
                                    icon.name: "edit-copy"; flat: true
                                    implicitWidth: Kirigami.Units.iconSizes.small
                                    implicitHeight: Kirigami.Units.iconSizes.small
                                    onClicked: full.copyToClipboard(modelData.cve || modelData.id)
                                    QQC.ToolTip.text: "Copy ID"; QQC.ToolTip.visible: hovered; QQC.ToolTip.delay: 600
                                }
                            }
                            TextEdit {
                                text: {
                                    if (modelData.vendor)   return modelData.vendor + " · " + modelData.product;
                                    if (modelData.packages) return (modelData.packages || []).join(", ");
                                    if (modelData.severity) return "Severity: " + modelData.severity;
                                    return "";
                                }
                                font.pixelSize: smallPx; font.family: cfgUi; color: uiDim
                                readOnly: true; selectByMouse: true; wrapMode: Text.NoWrap
                            }
                            TextEdit {
                                text: modelData.name || modelData.title || modelData.summary || ""
                                readOnly: true; selectByMouse: true; wrapMode: Text.Wrap
                                font.pixelSize: basePx; font.family: cfgUi; color: uiText
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // ============================================================
            // 2 · Local
            // ============================================================
            ColumnLayout {
                spacing: 0

                QQC.ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.topMargin: Kirigami.Units.largeSpacing; clip: true

                    ListView {
                        model: itemEntries()
                        spacing: 0
                        delegate: ColumnLayout {
                            id: probeRow
                            width: ListView.view.width; spacing: 0
                            property bool expanded:   false
                            property bool rowHovered: false
                            HoverHandler { onHoveredChanged: probeRow.rowHovered = hovered }

                            RowLayout {
                                Layout.fillWidth: true; spacing: Kirigami.Units.smallSpacing
                                Rectangle {
                                    width: Kirigami.Units.smallSpacing; Layout.fillHeight: true
                                    color: severityColour(modelData.value.severity)
                                }
                                QQC.Label {
                                    text: prettyKey(modelData.key)
                                    font.pixelSize: basePx; font.family: cfgUi; color: uiText
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                                }
                                TextEdit {
                                    text: modelData.value.status || detail(modelData.key, modelData.value)
                                    color: uiDim; font.pixelSize: basePx; font.family: cfgUi
                                    readOnly: true; selectByMouse: true; wrapMode: Text.NoWrap
                                    Layout.fillWidth: true; clip: true
                                }
                                QQC.ToolButton {
                                    visible: !!modelData.value.message
                                    text: probeRow.expanded ? "−" : "+"
                                    flat: true
                                    onClicked: probeRow.expanded = !probeRow.expanded
                                }
                                QQC.ToolButton {
                                    visible: probeRow.rowHovered
                                    icon.name: "edit-copy"; flat: true
                                    implicitWidth: Kirigami.Units.iconSizes.small
                                    implicitHeight: Kirigami.Units.iconSizes.small
                                    onClicked: full.copyToClipboard(
                                        prettyKey(modelData.key) + ": " +
                                        (modelData.value.status || detail(modelData.key, modelData.value))
                                    )
                                    QQC.ToolTip.text: "Copy"; QQC.ToolTip.visible: hovered; QQC.ToolTip.delay: 600
                                }
                            }
                            TextEdit {
                                visible: probeRow.expanded && !!modelData.value.message
                                text: modelData.value.message || ""
                                readOnly: true; selectByMouse: true; wrapMode: Text.WordWrap
                                font.pixelSize: smallPx; font.family: cfgUi; color: uiText
                                Layout.fillWidth: true
                                Layout.leftMargin:   Kirigami.Units.gridUnit + Kirigami.Units.smallSpacing
                                Layout.bottomMargin: Kirigami.Units.smallSpacing
                            }
                            QQC.ToolTip.visible: probeHover.containsMouse === true && !!(modelData && modelData.value && modelData.value.message)
                            QQC.ToolTip.text:    (modelData && modelData.value && modelData.value.message) || ""
                            QQC.ToolTip.delay:   400
                            HoverHandler { id: probeHover }
                        }
                    }
                }
            }

            // ============================================================
            // 3 · History
            // ============================================================
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    level: 3; text: "Score over time"; color: uiText
                    Layout.topMargin: Kirigami.Units.largeSpacing
                }
                QQC.Label {
                    text: (scoreData && scoreData.history)
                        ? (scoreData.history.length + " samples in the rolling window") : "No history yet"
                    color: uiDim; font.pixelSize: smallPx; font.family: cfgUi
                }

                Canvas {
                    id: spark
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 7
                    property var points: (scoreData && scoreData.history) || []
                    onPointsChanged:       requestPaint()
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (!points.length) return;
                        var pl = 4, pr = 4, pt = 6, pb = 14;
                        var w = width - pl - pr, h = height - pt - pb;
                        ctx.strokeStyle = full.uiAlt; ctx.lineWidth = 1;
                        ctx.beginPath(); ctx.moveTo(pl, pt + h); ctx.lineTo(pl + w, pt + h); ctx.stroke();
                        ctx.strokeStyle = full.scoreColour(points[points.length - 1].score);
                        ctx.fillStyle = ctx.strokeStyle; ctx.lineWidth = 2;
                        ctx.beginPath();
                        for (var i = 0; i < points.length; i++) {
                            var x = pl + (i / (points.length - 1 || 1)) * w;
                            var y = pt + (1 - Math.max(0, Math.min(1, points[i].score / 100))) * h;
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                        ctx.globalAlpha = 0.12;
                        ctx.lineTo(pl + w, pt + h); ctx.lineTo(pl, pt + h); ctx.closePath(); ctx.fill();
                        ctx.globalAlpha = 1;
                        ctx.fillStyle = full.uiDim; ctx.font = "10px sans-serif";
                        ctx.fillText(points[0].score + "", pl, pt + h + 10);
                        ctx.fillText(points[points.length - 1].score + "", pl + w - 14, pt + h + 10);
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }
                Kirigami.Heading { level: 3; text: "Recent samples"; color: uiText }

                QQC.ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ListView {
                        model: (scoreData && scoreData.history) ? scoreData.history.slice(-25).reverse() : []
                        spacing: 0
                        delegate: RowLayout {
                            width: ListView.view.width
                            TextEdit {
                                text: (modelData.at || "").substring(0, 19).replace("T", " ")
                                font.family: cfgMono; font.pixelSize: smallPx; color: uiDim
                                readOnly: true; selectByMouse: true; wrapMode: Text.NoWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: modelData.score + " / 100"
                                color: scoreColour(modelData.score)
                                font.bold: true; font.pixelSize: basePx; font.family: cfgUi
                            }
                        }
                    }
                }
            }

            // ============================================================
            // 4 · Settings
            // ============================================================
            ColumnLayout {
                spacing: 0

                QQC.ScrollView {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    Layout.topMargin:  Kirigami.Units.largeSpacing
                    clip: true

                    ColumnLayout {
                        width: pages.width - Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        // ── Appearance ────────────────────────────────
                        Kirigami.Heading { level: 3; text: "Appearance"; color: uiText }
                        Kirigami.Separator { Layout.fillWidth: true }

                        // Theme
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            QQC.Label {
                                text: "Theme"
                                font.pixelSize: basePx; font.family: cfgUi; color: uiText
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                            }
                            QQC.ComboBox {
                                Layout.fillWidth: true
                                model: ["Follow system", "Force dark", "Force light"]
                                currentIndex: {
                                    var p = Plasmoid.configuration.themePalette;
                                    if (p === "dark")  return 1;
                                    if (p === "light") return 2;
                                    return 0;
                                }
                                onActivated: {
                                    Plasmoid.configuration.themePalette = ["system","dark","light"][currentIndex];
                                }
                            }
                        }

                        // Font size
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            QQC.Label {
                                text: "Font size"
                                font.pixelSize: basePx; font.family: cfgUi; color: uiText
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                QQC.Slider {
                                    id: fsSlider
                                    Layout.fillWidth: true
                                    from: 0.80; to: 1.50; stepSize: 0.05
                                    value: Plasmoid.configuration.fontSizeMultiplier
                                    onMoved: Plasmoid.configuration.fontSizeMultiplier = value
                                }
                                QQC.Label {
                                    text: fsSizeLabel(fsSlider.value) + "  (" + fsSlider.value.toFixed(2) + "×)"
                                    color: uiDim; font.pixelSize: smallPx; font.family: cfgUi
                                }
                            }
                        }

                        // UI font
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            QQC.Label {
                                text: "UI font"
                                font.pixelSize: basePx; font.family: cfgUi; color: uiText
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                            }
                            QQC.ComboBox {
                                id: uiFontPicker
                                Layout.fillWidth: true
                                property var families: [
                                    { label: "System default",  value: "" },
                                    { label: "Noto Sans",       value: "Noto Sans" },
                                    { label: "DejaVu Sans",     value: "DejaVu Sans" },
                                    { label: "Liberation Sans",  value: "Liberation Sans" },
                                    { label: "Roboto",          value: "Roboto" },
                                    { label: "Inter",           value: "Inter" }
                                ]
                                model: families.map(function(f) { return f.label; })
                                currentIndex: {
                                    var cur = Plasmoid.configuration.uiFont;
                                    for (var i = 0; i < families.length; i++) {
                                        if (families[i].value === cur) return i;
                                    }
                                    return 0;
                                }
                                onActivated: {
                                    Plasmoid.configuration.uiFont = families[currentIndex].value;
                                }
                            }
                        }

                        // Code / mono font
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            QQC.Label {
                                text: "Code font"
                                font.pixelSize: basePx; font.family: cfgUi; color: uiText
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                            }
                            QQC.ComboBox {
                                id: monoFontPicker
                                Layout.fillWidth: true
                                property var families: [
                                    { label: "Geist Mono",       value: "Geist Mono" },
                                    { label: "Noto Sans Mono",   value: "Noto Sans Mono" },
                                    { label: "DejaVu Sans Mono", value: "DejaVu Sans Mono" },
                                    { label: "Hack",             value: "Hack" },
                                    { label: "JetBrains Mono",   value: "JetBrains Mono" },
                                    { label: "Liberation Mono",  value: "Liberation Mono" }
                                ]
                                model: families.map(function(f) { return f.label; })
                                currentIndex: {
                                    var cur = Plasmoid.configuration.monoFont;
                                    for (var i = 0; i < families.length; i++) {
                                        if (families[i].value === cur) return i;
                                    }
                                    return 0;
                                }
                                onActivated: {
                                    Plasmoid.configuration.monoFont = families[currentIndex].value;
                                }
                            }
                        }

                        // Font preview
                        Rectangle {
                            Layout.fillWidth:  true
                            Layout.topMargin:  Kirigami.Units.smallSpacing
                            height: Kirigami.Units.gridUnit * 3
                            color: uiAlt; radius: 4
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                spacing: 2
                                QQC.Label {
                                    text: "The quick brown fox — UI font preview"
                                    font.pixelSize: basePx
                                    font.family:    cfgUi || Kirigami.Theme.defaultFont.family
                                    color: uiText; Layout.fillWidth: true
                                }
                                QQC.Label {
                                    text: "CVE-2024-12345  EPSS 0.94%  pkg-name"
                                    font.pixelSize: basePx
                                    font.family:    cfgMono
                                    color: uiDim; Layout.fillWidth: true
                                }
                            }
                        }

                        Item { height: Kirigami.Units.largeSpacing }
                        Kirigami.Separator { Layout.fillWidth: true }

                        // Reset
                        RowLayout {
                            Layout.fillWidth:   true
                            Layout.topMargin:   Kirigami.Units.smallSpacing
                            Layout.bottomMargin: Kirigami.Units.smallSpacing
                            Item { Layout.fillWidth: true }
                            QQC.Button {
                                text: "Reset to defaults"
                                onClicked: {
                                    Plasmoid.configuration.fontSizeMultiplier = 1.0;
                                    Plasmoid.configuration.uiFont             = "";
                                    Plasmoid.configuration.monoFont           = "Geist Mono";
                                    Plasmoid.configuration.themePalette       = "system";
                                }
                            }
                        }
                    }
                }
            }
        }

        // -----------------------------------------------------------------
        // Footer
        Kirigami.Separator { Layout.fillWidth: true }
        RowLayout {
            Layout.fillWidth: true
            QQC.Label {
                text: healthData.updated
                    ? ("Updated " + healthData.updated.substring(0, 19).replace("T", " ")) : ""
                color: uiDim; font.pixelSize: smallPx; font.family: cfgUi
                Layout.fillWidth: true
            }
            QQC.Label {
                visible: lastError !== ""
                text: lastError
                color: severityColour("warn")
                font.pixelSize: smallPx; font.family: cfgUi
            }
        }
    }
}
