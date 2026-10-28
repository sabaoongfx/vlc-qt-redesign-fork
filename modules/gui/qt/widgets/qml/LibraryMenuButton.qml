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
import VLC.Dialogs

// redesign: the "..." button on the right of the library search, with the Figma "folder context
// menu": Add File, Add Folder, Resync, Info. (Edit Subtitle / Audio Tracks have no backend.)
IconToolButton {
    id: root

    text: VLCIcons.ellipsis
    description: qsTr("More")

    visible: MainCtx.mediaLibraryAvailable
    enabled: visible

    width: VLCStyle.bannerButton_width
    height: VLCStyle.bannerButton_height
    font.pixelSize: VLCStyle.icon_banner

    onClicked: menu.popup(root.mapToGlobal(0, root.height), [qsTr("Add File"), qsTr("Add Folder"), qsTr("Resync"), qsTr("Info")])

    StringListMenu {
        id: menu

        ctx: MainCtx

        onSelected: (index) => {
            switch (index) {
            case 0:
                DialogsProvider.openFileDialog()
                break
            case 1:
                DialogsProvider.addLibraryFolderDialog()
                break
            case 2:
                MainCtx.mediaLibrary.reload()
                break
            case 3:
                DialogsProvider.mediaInfoDialog()
                break
            }
        }
    }
}
