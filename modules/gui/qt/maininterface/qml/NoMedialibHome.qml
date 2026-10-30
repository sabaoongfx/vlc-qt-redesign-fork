/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Window

import VLC.MainInterface
import VLC.Util
import VLC.Style

FocusScope {
    id: root

    property var pagePrefix: [] // behave like a Page

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Home View")


    // redesign: empty start screen as in the prototype, a dim cone and a hint instead of a big button

    // Used by the media library HomePage (cone + Open File row); keep it even though
    // this start screen no longer shows it.
    component ConeNButtons: FocusScope {
        id: coneNButtons

        property int orientation: Qt.Vertical

        property real spacing: VLCStyle.margin_large

        implicitWidth: orientation === Qt.Vertical ? Math.max(cone.implicitWidth, button.implicitWidth)
                                                   : cone.implicitWidth + spacing + button.implicitWidth
        implicitHeight: orientation === Qt.Vertical ? cone.implicitHeight + spacing + button.implicitHeight
                                                    : cone.implicitHeight

        states: [
            State {
                name: "vertical"
                AnchorChanges {
                    target: cone

                    anchors.left: undefined
                    anchors.horizontalCenter: coneNButtons.horizontalCenter
                }
                AnchorChanges {
                    target: button

                    anchors.left: undefined
                    anchors.verticalCenter: undefined
                    anchors.top: cone.bottom
                    anchors.horizontalCenter: coneNButtons.horizontalCenter
                }
                PropertyChanges {
                    target: button

                    anchors.topMargin: coneNButtons.spacing
                }
            },
            State {
                name: "horizontal"
                AnchorChanges {
                    target: cone

                    anchors.horizontalCenter: undefined
                    anchors.left: coneNButtons.left
                }
                AnchorChanges {
                    target: button

                    anchors.top: undefined
                    anchors.horizontalCenter: undefined
                    anchors.left: cone.right
                    anchors.verticalCenter: coneNButtons.verticalCenter
                }
                PropertyChanges {
                    target: button

                    anchors.leftMargin: coneNButtons.spacing
                }
            }
        ]

        state: orientation === Qt.Vertical ? "vertical" : "horizontal"


        Image {
            id: cone

            property real _eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)

            sourceSize: Qt.size(0, orientation === Qt.Vertical ? VLCStyle.colWidth(1)
                                                               : button.implicitHeight * 1.618 * _eDPR) // 1.618 = golden ratio approximation

            source: MainCtx.useXmasCone() ? "qrc:///logo/vlc48-xmas.png" // TODO: new xmas cone designs
                                          : "qrc:///misc/cone.svg"

            Connections {
                target: MainCtx

                function onIntfDevicePixelRatioChanged() {
                    // Update the DPR:
                    // Normally, this is not done, as we display the images at the size we
                    // want, and we don't want to re-load all images on DPR change. But
                    // in this case we depend on the implicit size, so we should re-load
                    // the image with the updated DPR:
                    cone._eDPR = MainCtx.effectiveDevicePixelRatio(cone.Window.window)
                }
            }
        }

        OpenFileSplitButton {
            id: button

            focus: true

            Navigation.parentItem: coneNButtons
        }
    }

    component KeyChip: Rectangle {
        property alias text: chipLabel.text

        implicitWidth: chipLabel.implicitWidth + VLCStyle.margin_xsmall * 2
        implicitHeight: chipLabel.implicitHeight + 2

        radius: VLCStyle.dp(4, VLCStyle.scale)
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(theme.fg.secondary, 0.35)

        Text {
            id: chipLabel

            anchors.centerIn: parent

            color: theme.fg.secondary
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_small
        }
    }

    Image {
        id: cone

        property real _eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -VLCStyle.margin_large

        opacity: 0.22

        sourceSize: Qt.size(0, Math.min(root.height * 0.5, VLCStyle.colWidth(1) * 2) * _eDPR)

        source: MainCtx.useXmasCone() ? "qrc:///logo/vlc48-xmas.png"
                                      : "qrc:///misc/cone.svg"
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: VLCStyle.margin_large

        spacing: VLCStyle.margin_xxsmall

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Drop a video or music file here, or press")
            color: theme.fg.secondary
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_normal
        }
        // Qt maps Ctrl to Cmd on macOS: show it the Mac way there (⌘O, no plus)
        KeyChip { text: Qt.platform.os === "osx" ? "⌘" : "Ctrl"; anchors.verticalCenter: parent.verticalCenter }
        Text {
            visible: Qt.platform.os !== "osx"
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            color: theme.fg.secondary
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_normal
        }
        KeyChip { text: "O"; anchors.verticalCenter: parent.verticalCenter }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("to open one.")
            color: theme.fg.secondary
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_normal
        }
    }
}
