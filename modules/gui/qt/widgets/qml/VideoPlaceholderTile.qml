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

import VLC.Style

// redesign: the picture of a video without a thumbnail: a dark tinted tile with a video icon, as in the prototype
// (.thumb.is-gen), not the light grey upstream placeholder that glared in the dark theme (user screenshots, grid
// cards and list rows). The tint comes from the title so tiles in a row differ.
Rectangle {
    id: root

    property string title
    property bool dark: true

    readonly property real hue: {
        const s = root.title
        let h = 0
        for (let i = 0; i < s.length; ++i)
            h = (h * 31 + s.charCodeAt(i)) % 360
        return h / 360
    }

    color: dark ? Qt.hsla(hue, 0.22, 0.16, 1) : Qt.hsla(hue, 0.22, 0.88, 1) // lint: allow qml-colour (hue hashed from the title, the prototype's generated tile)

    IconLabel {
        anchors.centerIn: parent

        text: VLCIcons.topbar_video
        font.pixelSize: Math.round(parent.height * 0.3)
        color: root.dark ? Qt.hsla(root.hue, 0.30, 0.55, 1) : Qt.hsla(root.hue, 0.30, 0.45, 1) // lint: allow qml-colour (same tile)
    }
}
