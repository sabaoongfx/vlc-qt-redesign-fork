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
import VLC.Menus

// redesign: the "..." button on the right of the library search. It replaces the cone and menu
// button that were on the left of the library top bar, so it opens the same VLC menu (Media with
// Open File..., Playback, Audio, Video, Subtitle, Tools, View, Help).
IconToolButton {
    id: root

    text: VLCIcons.ellipsis
    description: qsTr("More")

    width: VLCStyle.bannerButton_width
    height: VLCStyle.bannerButton_height
    font.pixelSize: VLCStyle.icon_banner

    checked: menu.shown

    onClicked: menu.popup(root.mapToGlobal(0, root.height))

    QmlGlobalMenu {
        id: menu

        ctx: MainCtx
    }
}
