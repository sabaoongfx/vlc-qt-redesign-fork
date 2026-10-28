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

import VLC.MainInterface
import VLC.Style
import VLC.Util

// redesign: the dark title band of the Figma dialogs, the title on the left and a close button
Rectangle {
    id: root

    property string title

    signal closeRequested()

    readonly property var _colors: VLCStyle.figmaColors(theme.palette.isDark)

    implicitHeight: VLCStyle.dp(50, VLCStyle.scale)

    color: _colors.bar
    topLeftRadius: VLCStyle.dp(12, VLCStyle.scale)
    topRightRadius: VLCStyle.dp(12, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    LabelExt {
        anchors.left: parent.left
        anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.verticalCenter: parent.verticalCenter

        text: root.title
        font.pixelSize: VLCStyle.fontSize_normal
        color: root._colors.label
    }

    IconToolButton {
        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(12, VLCStyle.scale)
        anchors.verticalCenter: parent.verticalCenter

        text: VLCIcons.close
        description: qsTr("Close")
        font.pixelSize: VLCStyle.icon_banner
        width: VLCStyle.bannerButton_width
        height: VLCStyle.bannerButton_height

        onClicked: root.closeRequested()
    }
}
