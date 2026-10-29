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
import VLC.Playlist as Playlist

// redesign: the "..." button of the library headers opens the Figma "folder context menu":
// Add File, Add Folder, Edit Subtitle Tracks, Edit Audio Tracks, Resync, Info. The VLC menu
// (Media, Playback, ..., Help) is the "..." of the top bar.
IconToolButton {
    id: root

    // the tracks and Info act on the media in the play queue
    readonly property bool _hasMedia: !Playlist.MainPlaylistController.empty

    // Add File opens the system file picker (Ctrl+O), not VLC's Open Media window
    readonly property var _entries: [
        { text: qsTr("Add File"),             icon_svg: ":/menu/add.svg",               action: () => DialogsProvider.simpleOpenDialog() },
        { text: qsTr("Add Folder"),           icon_svg: ":/menu/redesign-folder.svg",   action: () => DialogsProvider.addLibraryFolderDialog() },
        { text: qsTr("Edit Subtitle Tracks"), icon_svg: ":/menu/redesign-subtitle.svg", action: () => DialogsProvider.loadSubtitlesFile(), media: true },
        { text: qsTr("Edit Audio Tracks"),    icon_svg: ":/menu/redesign-audio.svg",    action: () => DialogsProvider.loadAudioFile(), media: true },
        { text: qsTr("Resync"),               icon_svg: ":/menu/sync.svg",              action: () => MainCtx.mediaLibrary?.reload(), library: true },
        { text: qsTr("Info"),                 icon_svg: ":/menu/info.svg",              action: () => DialogsProvider.mediaInfoDialog(), media: true }
    ]

    // a page's own entries ({ text, icon_svg, action }), in place of the folder menu (Network:
    // Add Stream)
    property var entries: null

    property var _shown: []

    text: VLCIcons.ellipsis
    description: qsTr("More")

    width: VLCStyle.bannerButton_width
    height: VLCStyle.bannerButton_height
    font.pixelSize: VLCStyle.icon_banner

    onClicked: {
        _shown = (root.entries ?? _entries).filter((entry) => (!entry.media || root._hasMedia)
                                            && (!entry.library || MainCtx.mediaLibraryAvailable))
        menu.popup(root.mapToGlobal(0, root.height),
                   _shown.map((entry) => ({ text: entry.text, icon_svg: entry.icon_svg })))
    }

    StringListMenu {
        id: menu

        ctx: MainCtx

        onSelected: (index) => root._shown[index]?.action()
    }
}
