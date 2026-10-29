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
import VLC.Menus
import VLC.Dialogs

// The icon rail left of the video (Figma "sidebar" frames): Home, Videos, Music, Network,
// Playlists, Recent and Add. It picks what the library card beside the video shows; the active
// one is drawn filled in the accent colour.
Item {
    id: root

    // "home", "videos", "music", "network", "playlists" or "recent"; empty: none picked yet
    property string section: ""

    // The card is shown
    property bool open: false

    // Asks to show the section, a click on the active one again hides the card
    signal selected(string section)

    readonly property var entries: [
        { name: "home", icon: VLCIcons.home, filled: VLCIcons.home_filled, label: qsTr("Home") },
        { name: "videos", icon: VLCIcons.topbar_video, filled: VLCIcons.topbar_video_filled, label: qsTr("Videos") },
        { name: "music", icon: VLCIcons.topbar_music, filled: VLCIcons.topbar_music_filled, label: qsTr("Music") },
        { name: "network", icon: VLCIcons.topbar_network, filled: VLCIcons.topbar_network_filled, label: qsTr("Network") },
        { name: "playlists", icon: VLCIcons.playlists, filled: VLCIcons.playlists, label: qsTr("Playlists") },
        { name: "recent", icon: VLCIcons.history, filled: VLCIcons.history, label: qsTr("Recent") }
    ]

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Figma sidebar rail: 8px padding, 30x32 icon boxes 14px apart (46px pitch)
    Column {
        anchors.top: parent.top
        anchors.topMargin: VLCStyle.dp(8, VLCStyle.scale)
        anchors.horizontalCenter: parent.horizontalCenter

        spacing: VLCStyle.dp(14, VLCStyle.scale)

        Repeater {
            model: root.entries

            delegate: Widgets.IconToolButton {
                required property var modelData

                readonly property bool active: root.open && root.section === modelData.name

                text: active ? modelData.filled : modelData.icon
                description: modelData.label
                font.pixelSize: VLCStyle.icon_banner
                width: VLCStyle.dp(30, VLCStyle.scale)
                height: VLCStyle.dp(32, VLCStyle.scale)

                color: active ? theme.accent : theme.fg.primary

                onClicked: root.selected(modelData.name)
            }
        }

        // Add item: file, folder or network stream
        Widgets.IconToolButton {
            text: VLCIcons.add
            description: qsTr("Add item")
            font.pixelSize: VLCStyle.icon_banner
            width: VLCStyle.dp(30, VLCStyle.scale)
            height: VLCStyle.dp(32, VLCStyle.scale)

            onClicked: addMenu.popup(mapToGlobal(width, 0), [qsTr("Add File"), qsTr("Add Folder"), qsTr("Add Network Stream")])

            StringListMenu {
                id: addMenu

                ctx: MainCtx

                onSelected: (index) => {
                    switch (index) {
                    case 0:
                        DialogsProvider.simpleOpenDialog() // the system file picker
                        break
                    case 1:
                        DialogsProvider.addLibraryFolderDialog()
                        break
                    case 2:
                        DialogsProvider.openNetDialog()
                        break
                    }
                }
            }
        }
    }
}
