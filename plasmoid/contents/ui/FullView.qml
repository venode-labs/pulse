// Security Pulse, popup view.
// Tabs: Overview, Threats, Local, History.
//
// Author: Kaspar Tavitian

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

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
    // Helpers

    function severityColour(sev) {
        switch ((sev || "").toString().toLowerCase()) {
            case "critical": return "#d32f2f";
            case "high":     return "#e44b3a";
            case "warn":
            case "medium":   return "#f9a825";
            case "info":
            case "low":      return "#1976d2";
            case "ok":       return "#43a047";
            default:         return Kirigami.Theme.disabledTextColor;
        }
    }

    function scoreColour(s) {
        if (s === undefined || s === null) return Kirigami.Theme.disabledTextColor;
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
            case "ssh":             return v.sshd_present
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
            if (healthData.items[k] !== undefined) {
                out.push({ key: k, value: healthData.items[k] });
            }
        }
        return out;
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
                width: Kirigami.Units.gridUnit * 1.2
                height: width
                radius: width / 2
                color: severityColour(healthData.overall || "info")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Kirigami.Heading { level: 2; text: "Security Pulse" }
                QQC.Label {
                    text: healthData.host
                        ? (healthData.host + " · " + ((relevantData && relevantData.count) || 0) + " relevant CVE(s)")
                        : "Waiting for collector"
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
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
            QQC.TabButton { text: "Threats" }
            QQC.TabButton { text: "Local" }
            QQC.TabButton { text: "History" }
        }

        StackLayout {
            id: pages
            currentIndex: tabs.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ============================================================
            // 0 · Overview
            // ============================================================
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    // Score gauge
                    Item {
                        Layout.preferredWidth:  Kirigami.Units.gridUnit * 8
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 8

                        Canvas {
                            id: gauge
                            anchors.fill: parent
                            property int score: (scoreData && scoreData.score !== undefined)
                                ? scoreData.score : (healthData.score || 0)
                            onScoreChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width / 2, cy = height / 2;
                                var r = Math.min(cx, cy) - 6;
                                var start = -Math.PI * 0.75;
                                var end   =  Math.PI * 0.75;
                                ctx.lineCap = "round";
                                ctx.lineWidth = 9;
                                // track
                                ctx.strokeStyle = Kirigami.Theme.alternateBackgroundColor;
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, start, end);
                                ctx.stroke();
                                // value
                                var frac = Math.max(0, Math.min(1, score / 100));
                                ctx.strokeStyle = scoreColour(score);
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, start, start + (end - start) * frac);
                                ctx.stroke();
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0
                            QQC.Label {
                                text: (scoreData && scoreData.score !== undefined)
                                    ? scoreData.score : (healthData.score || 0)
                                font.pixelSize: Kirigami.Units.gridUnit * 2.5
                                font.bold: true
                                color: scoreColour((scoreData && scoreData.score) || 0)
                                horizontalAlignment: Text.AlignHCenter
                                Layout.alignment: Qt.AlignHCenter
                            }
                            QQC.Label {
                                text: "/ 100"
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Heading {
                            level: 3
                            text: "Composite score"
                        }
                        QQC.Label {
                            text: "Local health blended with the count of CVEs that match the packages installed on this machine."
                            color: Kirigami.Theme.disabledTextColor
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }

                        GridLayout {
                            columns: 3
                            columnSpacing: Kirigami.Units.largeSpacing
                            rowSpacing: 0
                            Layout.topMargin: Kirigami.Units.smallSpacing

                            QQC.Label { text: "Critical"; color: "#d32f2f"; font.bold: true }
                            QQC.Label { text: "High";     color: "#e44b3a"; font.bold: true }
                            QQC.Label { text: "Medium";   color: "#f9a825"; font.bold: true }

                            QQC.Label {
                                text: (scoreData && scoreData.relevant) ? scoreData.relevant.critical : 0
                                font.pixelSize: Kirigami.Units.gridUnit * 1.2
                            }
                            QQC.Label {
                                text: (scoreData && scoreData.relevant) ? scoreData.relevant.high : 0
                                font.pixelSize: Kirigami.Units.gridUnit * 1.2
                            }
                            QQC.Label {
                                text: (scoreData && scoreData.relevant) ? scoreData.relevant.medium : 0
                                font.pixelSize: Kirigami.Units.gridUnit * 1.2
                            }
                        }
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                Kirigami.Heading { level: 3; text: "Top relevant CVEs" }

                QQC.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        model: relevantData.items
                            ? relevantData.items.slice(0, 6)
                            : []
                        spacing: Kirigami.Units.smallSpacing
                        delegate: ColumnLayout {
                            width: ListView.view.width
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                Rectangle {
                                    width: Kirigami.Units.smallSpacing
                                    Layout.preferredHeight: Kirigami.Units.gridUnit
                                    color: severityColour(modelData.severity)
                                }
                                QQC.Label {
                                    text: modelData.id
                                    font.family: "Geist Mono, monospace"
                                    font.bold: true
                                }
                                QQC.Label {
                                    text: modelData.package
                                    color: Kirigami.Theme.disabledTextColor
                                    Layout.fillWidth: true
                                }
                                QQC.Label {
                                    text: modelData.severity || ""
                                    color: severityColour(modelData.severity)
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    font.bold: true
                                }
                            }
                            QQC.Label {
                                text: modelData.title || ""
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                QQC.Label {
                    visible: (briefingData && briefingData.summary) ? true : false
                    text: briefingData.summary || ""
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    font.italic: true
                    color: Kirigami.Theme.textColor
                }
            }

            // ============================================================
            // 1 · Threats (KEV / ALSA / NVD / GHSA all in one)
            // ============================================================
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.largeSpacing

                    QQC.Label {
                        text: threatsData.kev
                            ? (threatsData.kev.new_week + " new CISA KEV this week · " + threatsData.kev.total + " total exploited")
                            : "KEV feed not available"
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                        Layout.fillWidth: true
                    }
                }

                QQC.ComboBox {
                    id: feedPicker
                    Layout.fillWidth: true
                    model: ["CISA KEV (exploited)", "Arch ALSA", "NVD recent", "GitHub Security Advisories"]
                    currentIndex: 0
                }

                QQC.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

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
                            width: ListView.view.width
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                QQC.Label {
                                    text: modelData.cve || modelData.id
                                    font.family: "Geist Mono, monospace"
                                    font.bold: true
                                }
                                QQC.Label {
                                    text: modelData.added || modelData.published || ""
                                    color: Kirigami.Theme.disabledTextColor
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                }
                            }
                            QQC.Label {
                                text: {
                                    if (modelData.vendor) return modelData.vendor + " · " + modelData.product;
                                    if (modelData.packages) return (modelData.packages || []).join(", ");
                                    if (modelData.severity) return "Severity: " + modelData.severity;
                                    return "";
                                }
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                color: Kirigami.Theme.disabledTextColor
                            }
                            QQC.Label {
                                text: modelData.name || modelData.title || modelData.summary || ""
                                wrapMode: Text.Wrap
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
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    clip: true

                    ListView {
                        model: itemEntries()
                        spacing: 0
                        delegate: RowLayout {
                            width: ListView.view.width
                            spacing: Kirigami.Units.smallSpacing

                            Rectangle {
                                width: Kirigami.Units.smallSpacing
                                Layout.fillHeight: true
                                color: severityColour(modelData.value.severity)
                            }
                            QQC.Label {
                                text: prettyKey(modelData.key)
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                            }
                            QQC.Label {
                                text: detail(modelData.key, modelData.value)
                                color: Kirigami.Theme.disabledTextColor
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
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
                    level: 3
                    text: "Score over time"
                    Layout.topMargin: Kirigami.Units.largeSpacing
                }

                QQC.Label {
                    text: (scoreData && scoreData.history) ? (scoreData.history.length + " samples in the rolling window") : "No history yet"
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                Canvas {
                    id: spark
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 7
                    property var points: (scoreData && scoreData.history) || []
                    onPointsChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (!points.length) return;
                        // Padding
                        var pl = 4, pr = 4, pt = 6, pb = 14;
                        var w = width - pl - pr;
                        var h = height - pt - pb;
                        // Track baseline
                        ctx.strokeStyle = Kirigami.Theme.alternateBackgroundColor;
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(pl, pt + h);
                        ctx.lineTo(pl + w, pt + h);
                        ctx.stroke();
                        // Plot
                        ctx.strokeStyle = scoreColour(points[points.length - 1].score);
                        ctx.fillStyle = ctx.strokeStyle;
                        ctx.lineWidth = 2;
                        ctx.beginPath();
                        for (var i = 0; i < points.length; i++) {
                            var x = pl + (i / (points.length - 1 || 1)) * w;
                            var y = pt + (1 - Math.max(0, Math.min(1, points[i].score / 100))) * h;
                            if (i === 0) ctx.moveTo(x, y);
                            else ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                        // Fill under the curve, soft
                        ctx.globalAlpha = 0.12;
                        ctx.lineTo(pl + w, pt + h);
                        ctx.lineTo(pl, pt + h);
                        ctx.closePath();
                        ctx.fill();
                        ctx.globalAlpha = 1;
                        // Tick: latest
                        ctx.fillStyle = Kirigami.Theme.disabledTextColor;
                        ctx.font = "10px sans-serif";
                        ctx.fillText(points[0].score + "", pl, pt + h + 10);
                        ctx.fillText(points[points.length - 1].score + "",
                                     pl + w - 14, pt + h + 10);
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                Kirigami.Heading {
                    level: 3
                    text: "Recent samples"
                }

                QQC.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        model: (scoreData && scoreData.history) ? scoreData.history.slice(-25).reverse() : []
                        spacing: 0
                        delegate: RowLayout {
                            width: ListView.view.width
                            QQC.Label {
                                text: (modelData.at || "").substring(0, 19).replace("T", " ")
                                font.family: "Geist Mono, monospace"
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: modelData.score + " / 100"
                                color: scoreColour(modelData.score)
                                font.bold: true
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
                    ? ("Updated " + healthData.updated.substring(0, 19).replace("T", " "))
                    : ""
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                Layout.fillWidth: true
            }
            QQC.Label {
                visible: lastError !== ""
                text: lastError
                color: severityColour("warn")
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }
    }
}
