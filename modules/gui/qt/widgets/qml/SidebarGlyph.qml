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

// redesign: the sidebar icon (the user's "name=sidebar" SVGs, 24px box): a rounded square with a
// bar on its left, a thin bar while the panel is hidden, a wide one while it is shown. Drawn with
// rectangles: the icon font cannot be rebuilt here.
Item {
    id: root

    property bool open: false
    property color color: "white"
    property real size: VLCStyle.icon_banner

    readonly property real _unit: size / 24

    implicitWidth: size
    implicitHeight: size

    // the frame: x/y 3..21, corner 3, an inner 1.5 stroke
    Rectangle {
        x: 3 * root._unit
        y: 3 * root._unit
        width: 18 * root._unit
        height: 18 * root._unit
        radius: 3 * root._unit
        color: "transparent"
        border.width: Math.max(1, 1.5 * root._unit)
        border.color: root.color
        antialiasing: true
    }

    // the bar: x 6, y 6..18, 2 wide (hidden) or 7 wide (shown)
    Rectangle {
        x: 6 * root._unit
        y: 6 * root._unit
        width: (root.open ? 7 : 2) * root._unit
        height: 12 * root._unit
        radius: 0.5 * root._unit
        color: root.color
        antialiasing: true
    }
}
