pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils

Variants {
    id: root

    model: Screens.screens

    StyledWindow {
        id: win

        required property ShellScreen modelData
        screen: modelData

        name: "twofactor"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"

        anchors.top: true
        anchors.right: true

        property bool collapsed: false
        property var accounts: []
        property int accountCount: 0
        property int remaining: 30
        property real progress: 1.0
        property string copiedAccount: ""

        implicitWidth: card.width + 32
        implicitHeight: card.height + 32

        Process {
            id: fetchProc

            command: ["python3", Paths.config + "/scripts/2fa.py", "get"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text);
                        win.remaining = data.remaining ?? 30;
                        win.progress = data.progress ?? 1.0;
                        win.accountCount = data.accounts ? data.accounts.length : 0;
                        win.accounts = data.accounts ?? [];
                    } catch (e) {}
                }
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!fetchProc.running)
                    fetchProc.running = true;
            }
        }

        Timer {
            id: copyResetTimer
            interval: 1500
            onTriggered: win.copiedAccount = ""
        }

        StyledRect {
            id: card

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 16

            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large
            border.width: 1
            border.color: Colours.tPalette.m3outlineVariant
            clip: true

            implicitWidth: 330
            width: implicitWidth
            implicitHeight: win.collapsed ? (headerRow.implicitHeight + 28) : (mainCol.implicitHeight + 28)
            height: implicitHeight

            Column {
                id: mainCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 10

                // Header
                RowLayout {
                    id: headerRow

                    width: parent.width
                    spacing: 8

                    MaterialIcon {
                        text: "lock"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: "2FA"
                        font: Tokens.font.title.small
                        color: Colours.palette.m3onSurface
                        Layout.fillWidth: true
                    }

                    // Countdown badge
                    StyledRect {
                        color: win.remaining <= 5 ? Colours.palette.m3errorContainer : Colours.palette.m3secondaryContainer
                        radius: Tokens.rounding.full
                        implicitWidth: timerText.implicitWidth + 14
                        implicitHeight: timerText.implicitHeight + 4

                        StyledText {
                            id: timerText
                            anchors.centerIn: parent
                            text: `${win.remaining}s`
                            font: Tokens.font.label.small
                            color: win.remaining <= 5 ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
                        }
                    }

                    // Collapse toggle button
                    StyledRect {
                        id: collapseBtn

                        implicitWidth: 28
                        implicitHeight: 28
                        radius: Tokens.rounding.full
                        color: btnMouse.containsMouse ? Colours.tPalette.m3surfaceContainerHigh : "transparent"

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: win.collapsed ? "expand_more" : "expand_less"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.collapsed = !win.collapsed
                        }
                    }
                }

                // Collapsible body
                Column {
                    id: bodyCol

                    width: parent.width
                    spacing: 10
                    visible: !win.collapsed

                    // Progress bar
                    StyledRect {
                        width: parent.width
                        implicitHeight: 2
                        color: Colours.palette.m3surfaceVariant
                        radius: Tokens.rounding.full

                        StyledRect {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * win.progress
                            color: win.remaining <= 5 ? Colours.palette.m3error : Colours.palette.m3primary
                            radius: Tokens.rounding.full

                            Behavior on width {
                                Anim { type: Anim.FastSpatial }
                            }
                        }
                    }

                    // Accounts List
                    Column {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: win.accounts

                            delegate: StyledRect {
                                id: accItem

                                required property var modelData
                                readonly property bool isCopied: win.copiedAccount === modelData.name

                                width: parent.width
                                implicitHeight: 44
                                radius: Tokens.rounding.medium
                                color: hoverArea.containsMouse ? Colours.tPalette.m3surfaceContainerHigh : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    StyledText {
                                        text: accItem.modelData.name
                                        font: Tokens.font.body.medium
                                        color: Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text: accItem.isCopied ? "Скопировано!" : accItem.modelData.code
                                        font: Tokens.font.mono.medium
                                        color: accItem.isCopied ? Colours.palette.m3secondary : Colours.palette.m3primary
                                    }

                                    MaterialIcon {
                                        text: accItem.isCopied ? "check" : "content_copy"
                                        color: accItem.isCopied ? Colours.palette.m3secondary : Colours.palette.m3onSurfaceVariant
                                        fontStyle: Tokens.font.icon.small
                                    }
                                }

                                MouseArea {
                                    id: hoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.copiedAccount = accItem.modelData.name;
                                        copyResetTimer.restart();
                                        Quickshell.execDetached(["python3", Paths.config + "/scripts/2fa.py", "copy", accItem.modelData.name]);
                                    }
                                }
                            }
                        }
                    }

                    // Footer hint
                    RowLayout {
                        width: parent.width
                        spacing: 6

                        MaterialIcon {
                            text: "add_circle"
                            color: Colours.palette.m3outline
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            text: "Добавить в ~/.config/caelestia/2fa.json"
                            font: Tokens.font.label.small
                            color: Colours.palette.m3outline
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
