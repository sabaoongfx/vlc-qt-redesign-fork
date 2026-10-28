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

// redesign: the Cancel / Save pill of the Figma dialogs. A primary button is the accent colour
// while it is enabled and dim otherwise.
Rectangle {
    id: root

    property string text

    property bool primary: false

    signal clicked()

    readonly property var _colors: VLCStyle.figmaColors(theme.palette.isDark)

    readonly property bool _accent: primary && enabled

    implicitWidth: Math.max(VLCStyle.dp(100, VLCStyle.scale), label.implicitWidth + VLCStyle.margin_normal * 2)
    implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

    radius: VLCStyle.dp(6, VLCStyle.scale)
    color: _accent ? theme.accent : _colors.previewCard
    opacity: (primary && !enabled) ? 0.5 : 1.0

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) root.clicked()

    // the palette is given, not looked up through the parents: on the Network page the stock buttons
    // found none and were not drawn (CI screenshots, 2026-10-28); VLC's own dialogs do the same
    readonly property ColorContext colorContext: ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    // the text colour on the accent fill comes from the palette
    ColorContext {
        id: accentTheme
        palette: VLCStyle.palette
        colorSet: ColorContext.ButtonAccent
    }

    LabelExt {
        id: label

        anchors.centerIn: parent

        text: root.text
        font.pixelSize: VLCStyle.fontSize_normal
        font.weight: Font.DemiBold
        color: root._accent ? accentTheme.fg.primary : (root.primary ? root._colors.hint : root._colors.previewText)
    }

    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
