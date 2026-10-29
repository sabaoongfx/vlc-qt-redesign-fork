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
import VLC.MediaLibrary

import VLC.Widgets as Widgets
import VLC.Style

// The Videos page as a folder tree. The first level lists the folders the user added,
// a folder lists its subfolders and then its own videos. With audio set it is the Music page:
// the folders that hold music, and the songs of a folder. The address line in the header
// is the path from the first level, History (back / forward) walks the same steps.
Widgets.PageLoader {
    id: root

    // Properties

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0

    property bool enableBeginningFade: true
    property bool enableEndFade: true

    // History hands it to every page of the path (PageLoader); the folder page uses it
    property int initialIndex: 0

    // the Music page (MusicDisplay)
    property bool audio: false

    // Settings

    pageModel: [{
        name: "base",
        default: true,
        component: componentLevel
    }, {
        name: "folder",
        component: componentLevel
    }]

    // Functions

    // trail: [{ id, title }, ...], the folders from the first level down to the one shown
    function showFolder(trail, reason) {
        if (trail.length === 0) {
            History.push([...root.pagePrefix, "base"], {}, reason)
            return
        }

        const last = trail[trail.length - 1]

        History.push([...root.pagePrefix, "folder"],
                     { parentId: last.id, title: last.title, trail: trail }, reason)
    }

    // Children

    Component {
        id: componentLevel

        VideoFolderLevel {
            audio: root.audio

            displayMarginBeginning: root.displayMarginBeginning
            displayMarginEnd: root.displayMarginEnd

            enableBeginningFade: root.enableBeginningFade
            enableEndFade: root.enableEndFade

            onCurrentIndexChanged: History.viewProp.initialIndex = currentIndex

            onShowFolder: (trail, reason) => root.showFolder(trail, reason)
        }
    }

    // A page of the tree, the content of one folder
    component VideoFolderLevel : Widgets.PageExt {
        id: level

        // NOTE: This is used to determine which folder is shown, unset on the first level.
        property alias parentId: tree.parentId

        // The folders from the first level down to this one.
        property var trail: []

        property alias currentIndex: videoAll.currentIndex

        // History gives it back when the page is shown again (PageLoader assigns it; it was
        // missing: "Cannot assign to non-existent property", CI run 6)
        property int initialIndex: 0

        // the music tree: folders that hold songs, and their songs
        property bool audio: false

        readonly property string rootTitle: audio ? qsTr("Music") : qsTr("Videos")

        signal showFolder(var trail, int reason)

        title: trail.length > 0 ? trail[trail.length - 1].title : rootTitle

        crumbs: [rootTitle, ...trail.map(folder => folder.title)]

        // The first crumb is the first level, the others are the folders of the trail.
        onCrumbClicked: (index) => level.showFolder(level.trail.slice(0, index), Qt.MouseFocusReason)

        VideoAll {
            id: videoAll

            anchors.fill: parent

            focus: true

            audio: level.audio

            // square covers in the music list, 16:9 for videos
            listCoverWidth: level.audio ? VLCStyle.trackListAlbumCover_width : VLCStyle.listAlbumCover_width
            listCoverHeight: level.audio ? VLCStyle.trackListAlbumCover_heigth : VLCStyle.listAlbumCover_height

            displayMarginBeginning: level.displayMarginBeginning
            displayMarginEnd: level.displayMarginEnd
            enableBeginningFade: level.enableBeginningFade
            enableEndFade: level.enableEndFade

            model: MLVideoFolderTreeModel {
                id: tree

                ml: MediaLib
                audio: level.audio

                searchPattern: level.search.pattern
                sortOrder: level.sort.order
                sortCriteria: level.sort.criteria
            }

            contextMenu: MLContextMenu { model: tree; showPlayAsAudioAction: !level.audio }

            sectionProperty: {
                switch (tree.sortCriteria) {
                case "title":
                    return "group_title_first_symbol"
                default:
                    return ""
                }
            }

            gridLabels: function (item) {
                if (!item)
                    return ""

                if (item.isVideo)
                    return videoAll.getLabel(item)

                return []
            }

            showGroupCountColumn: true

            emptyLabel: emptyComponent

            function openFolder(object, reason) {
                // counted for Home "Frequently Visited Folders" in the player's library card
                MediaLib.recordVisit("folder", object.id, object.title)
                level.showFolder([...level.trail, { id: object.id, title: object.title }], reason)
            }

            // VideoAll events reimplementation

            function onAction(indexes) {
                const object = tree.getDataAt(indexes[0])

                if (object.isVideo) {
                    tree.addAndPlay(indexes)
                    MainCtx.playerView = true

                    return
                }

                openFolder(object, Qt.TabFocusReason)
            }

            function onDoubleClick(object) {
                if (object.isVideo) {
                    MediaLib.addAndPlay(object.id)
                    MainCtx.playerView = true

                    return
                }

                openFolder(object, Qt.MouseFocusReason)
            }

            function isInfoExpandPanelAvailable(modelIndexData) {
                return modelIndexData.isVideo
            }
        }

        Component {
            id: emptyComponent

            Widgets.EmptyLabelButton {
                coverWidth : VLCStyle.dp(level.audio ? 114 : 182, VLCStyle.scale)
                coverHeight: VLCStyle.dp(114, VLCStyle.scale)

                focus: true

                text: level.audio
                      ? (level.trail.length > 0 ? qsTr("This folder has no music")
                                                : qsTr("No music found\nPlease try adding sources"))
                      : (level.trail.length > 0 ? qsTr("This folder has no videos")
                                                : qsTr("No video found\nPlease try adding sources"))

                cover: level.audio ? VLCStyle.noArtAlbumCover : VLCStyle.noArtVideoCover
            }
        }
    }
}
