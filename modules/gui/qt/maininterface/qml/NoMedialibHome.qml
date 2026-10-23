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
        KeyChip { text: "Ctrl"; anchors.verticalCenter: parent.verticalCenter }
        Text {
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
