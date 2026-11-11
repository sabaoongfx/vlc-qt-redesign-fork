/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// redesign: "a new version is available" toast, a floating card like the resume prompt
// (ReleaseCheck finds the release once a week). It stays until its close button is pressed;
// the dismissed version does not come back, a newer one does.
Rectangle {
    id: root

    visible: ReleaseCheck.available

    implicitWidth: row.implicitWidth + VLCStyle.margin_normal + VLCStyle.margin_xsmall
    implicitHeight: row.implicitHeight + VLCStyle.margin_small * 2

    radius: VLCStyle.dp(8, VLCStyle.scale)
    color: theme.bg.primary
    border.width: VLCStyle.border
    border.color: theme.separator

    Accessible.role: Accessible.AlertMessage
    Accessible.name: title.text

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.Window
    }

    ColorContext {
        id: accentTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.ButtonAccent
    }

    // swallow clicks so they do not reach the page under the card
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Row {
        id: row

        anchors.left: parent.left
        anchors.leftMargin: VLCStyle.margin_normal
        anchors.verticalCenter: parent.verticalCenter

        spacing: VLCStyle.margin_normal

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: VLCStyle.margin_xxxsmall

            T.Label {
                id: title

                text: qsTr("VLC (juxtopposed) %1 is available").arg(ReleaseCheck.version)
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
                font.family: VLCStyle.fontFamily
                font.weight: Font.DemiBold
            }

            T.Label {
                text: ReleaseCheck.packaged
                      ? qsTr("Your system's updater installs it.")
                      : qsTr("Your settings and library are kept.")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_small
                font.family: VLCStyle.fontFamily
            }
        }

        Rectangle {
            id: actionBtn

            anchors.verticalCenter: parent.verticalCenter

            width: actionLabel.implicitWidth + VLCStyle.margin_normal * 2
            height: VLCStyle.dp(34, VLCStyle.scale)
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: theme.accent
            border.width: activeFocus ? VLCStyle.border : 0
            border.color: theme.fg.primary

            activeFocusOnTab: true

            Accessible.role: Accessible.Button
            Accessible.name: actionLabel.text
            Accessible.onPressAction: ReleaseCheck.openDownload()

            AccessibleCompat.id: "releaseToastAction"

            T.Label {
                id: actionLabel

                anchors.centerIn: parent

                text: ReleaseCheck.packaged ? qsTr("What's new") : qsTr("Download")
                color: accentTheme.fg.primary // dark text on the accent fill, from the palette
                font.pixelSize: VLCStyle.fontSize_normal
                font.family: VLCStyle.fontFamily
                font.bold: true
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: ReleaseCheck.openDownload()
            }

            Keys.onPressed: (event) => {
                if (KeyHelper.matchOk(event)) {
                    ReleaseCheck.openDownload()
                    event.accepted = true
                }
            }
        }

        Widgets.IconToolButton {
            id: closeBtn

            anchors.verticalCenter: parent.verticalCenter

            text: VLCIcons.close
            description: qsTr("Dismiss")
            font.pixelSize: VLCStyle.icon_banner
            width: VLCStyle.dp(34, VLCStyle.scale)
            height: VLCStyle.dp(34, VLCStyle.scale)

            AccessibleCompat.id: "releaseToastDismiss"

            onClicked: ReleaseCheck.dismiss()
        }
    }
}
