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
import QtQml.Models

import VLC.MainInterface
import VLC.MediaLibrary

import VLC.Widgets as Widgets
import VLC.Style

Widgets.PageLoader {
    // History hands its properties to every page of the path (PageLoader assigns them;
    // a missing one is a "Cannot assign to non-existent property" warning)
    property int initialIndex: 0

    id: root

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0
    property bool enableBeginningFade: true
    property bool enableEndFade: true

    // redesign: Back and Forward go up to the list of playlists and back down into the playlist
    // last opened (user request), not through the visit history
    property var _lastList: null

    function _showList(list, reason) {
        History.push([...root.pagePrefix, "list"], { parentId: list.id, title: list.title }, reason)
    }

    //---------------------------------------------------------------------------------------------
    // Settings
    //---------------------------------------------------------------------------------------------

    pageModel: [{
        name: "all",
        default: true,
        component: componentAll
    }, {
        name: "list",
        component: componentList
    }]

    //---------------------------------------------------------------------------------------------
    // Childs
    //---------------------------------------------------------------------------------------------

    Component {
        id: componentAll

        Widgets.PageExt {
            id: playlistPage

            // History hands its initialIndex back to this page (the list below sets it)
            property int initialIndex: 0

            title: qsTr("Playlists")

            treeNavigation: true
            canGoDown: !!root._lastList
            onGoDown: (reason) => root._showList(root._lastList, reason)

            PlaylistMediaList {
                id: playlistView

                anchors.fill: parent

                focus: true

                isMusic: false

                searchPattern: playlistPage.search.pattern
                sortOrder: playlistPage.sort.order
                sortCriteria: playlistPage.sort.criteria

                displayMarginBeginning: root.displayMarginBeginning
                displayMarginEnd: root.displayMarginEnd

                enableBeginningFade: root.enableBeginningFade
                enableEndFade: root.enableEndFade

                onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex

                onShowList: (model, reason) => root._showList({ id: model.id, title: model.name }, reason)
            }
        }

    }

    Component {
        id: componentList

        PlaylistMediaDisplay {
            id: playlist

            isMusic: false

            // the address line "Playlists > name"; Back goes up to the list of playlists
            crumbs: [qsTr("Playlists"), title]
            onCrumbClicked: (index) => { if (index === 0) goUp(Qt.MouseFocusReason) }

            treeNavigation: true
            canGoUp: true
            onGoUp: (reason) => History.push([...root.pagePrefix, "all"], {}, reason)

            // also when the page is reused for another playlist (PageLoader sets parentId and
            // title again, one after the other)
            function _remember() { root._lastList = { id: parentId, title: title } }
            Component.onCompleted: _remember()
            onParentIdChanged: _remember()
            onTitleChanged: _remember()

            searchPattern: playlist.search.pattern
            sortOrder: playlist.sort.order
            sortCriteria: playlist.sort.criteria

            displayMarginBeginning: root.displayMarginBeginning
            displayMarginEnd: root.displayMarginEnd

            enableBeginningFade: root.enableBeginningFade
            enableEndFade: root.enableEndFade

            onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex
        }
    }
}
