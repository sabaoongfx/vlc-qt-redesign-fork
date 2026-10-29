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
import VLC.Widgets as Widgets
import VLC.Style

// redesign: shows and hides the library menu beside the video (the icon rail and its card,
// Figma "Player - customize-8"), like the switcher in the top bar
Widgets.IconToolButton {
    id: libraryBtn

    text: " " // the glyph is drawn below; IconToolButton wants some text
    description: qsTr("Library")

    Widgets.SidebarGlyph {
        anchors.centerIn: parent
        open: libraryBtn.checked
        color: libraryBtn.color
        size: libraryBtn.font.pixelSize
    }

    onClicked: MainCtx.libraryPanel.visible = !MainCtx.libraryPanel.visible

    checked: MainCtx.libraryPanel.visible

    // grey; the glyph shows the state (wide bar: the menu is shown)
    color: colorContext.fg.primary

    AccessibleCompat.id: "libraryButton"
}
