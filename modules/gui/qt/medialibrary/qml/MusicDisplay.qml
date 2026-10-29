/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import QtQuick.Layouts

import VLC.MainInterface
import VLC.MediaLibrary

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util


Widgets.PageLoader {
    // History hands its properties to every page of the path (PageLoader assigns them;
    // a missing one is a "Cannot assign to non-existent property" warning)
    property var artistId: undefined
    property int initialAlbumIndex: 0

    id: root

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Music view")
    AccessibleCompat.id: "musicDisplay"

    // redesign: Music is a folder tree like Videos (user request): the folders that hold music,
    // a folder's subfolders and its songs. The artist, album, track and genre pages are no longer
    // reached from here.
    pageModel: [{
            displayText: qsTr("Music"),
            name: "folders",
            default: true,
            component: musicFolders
        }
    ]

    Component {
        id: musicFolders

        VideoFolderTreeDisplay {
            audio: true
        }
    }

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0

    property bool enableBeginningFade: true
    property bool enableEndFade: true

    // redesign: History hands it to every page of the path (PageLoader)
    property int initialIndex: 0

    onCurrentItemChanged: {
        if (currentItem) {
            if (currentItem.displayMarginBeginning !== undefined)
                currentItem.displayMarginBeginning = Qt.binding(() => { return root.displayMarginBeginning })

            if (currentItem.displayMarginEnd !== undefined)
                currentItem.displayMarginEnd = Qt.binding(() => { return root.displayMarginEnd })

            if (currentItem.enableBeginningFade !== undefined)
                currentItem.enableBeginningFade = Qt.binding(() => { return root.enableBeginningFade })

            if (currentItem.enableEndFade !== undefined)
                currentItem.enableEndFade = Qt.binding(() => { return root.enableEndFade })
        }
    }

    function loadIndex(index) {
        const pageName = root.pageModel[index].name
        if (root.isDefaulLoadedForPath([pageName]))
            return
        History.push([...root.pagePrefix, pageName])
    }
}
