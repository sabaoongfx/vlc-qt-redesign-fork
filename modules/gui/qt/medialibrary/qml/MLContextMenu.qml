
/*****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
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
import QtQml

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Dialogs

import VLC.Util

// @brief - a generic ML context menu
NativeMenu {
    id: root

    // Properties

    required property MLBaseModel model

    property string idDataRole: "id"
    property string albumIdDataRole: "album_id"

    property bool showPlayAsAudioAction: false

    // redesign: Play opens the video player, like a click on a video (menus of video pages offer
    // "Play as audio", so they are the video ones); it stayed on the library with the mini player
    property bool openPlayerOnPlay: showPlayAsAudioAction

    // This is only applicable when the model is `MLAudioModel`:
    property bool showPlayAsAlbumAction: implicitShowPlayAsAlbumAction
    property bool implicitShowPlayAsAlbumAction: !showPlayAsAudioAction

    // Signals

    signal showMediaInformation(int index)


    // required by TableViewExt
    property var tableView_popup: function (index/* reserved for future */, selectedIndexes, globalPos) {
        return popup(selectedIndexes, globalPos)
    }

    // Settings

    // redesign: the Figma "file context menu" (names, order and duotone icons). Kept from VLC:
    // Play as audio/album, Enqueue as album, the audio/video-only playlist, Remove from list,
    // Delete, Information and Delete File From System. Not built: Go to Source, Add Subtitle
    // Tracks and Add Audio Tracks (no library backend).
    actions: [{
            "text": qsTr("Play"),
            "icon": ":/menu/redesign-play.svg",
            "action": addAndPlay
        }, {
            "text": qsTr("Play as audio"),
            "action": playAsAudio,
            "visible": root.showPlayAsAudioAction
        }, {
            "text": qsTr("Play as album"),
            "action": playAsAlbum,
            "visible": root.showPlayAsAlbumAction &&
                       (root.model instanceof MLAudioModel)
        }, {
            "text": qsTr("Mark as Watched"),
            "icon": ":/menu/redesign-watched.svg",
            "action": markSeen,
            "visible": _showSeen
        }, {
            "text": qsTr("Mark as Unwatched"),
            "icon": ":/menu/redesign-watched.svg",
            "action": markUnseen,
            "visible": _showUnseen
        }, {
            "text": qsTr("Favorite"),
            "icon": ":/menu/redesign-favorite.svg",
            "action": addFavorite,
            "visible": _showAddFavorite
        }, {
            "text": qsTr("Remove from Favorites"),
            "icon": ":/menu/redesign-favorite.svg",
            "action": removeFavorite,
            "visible": _showRemoveFavorite
        }, {
            "text": qsTr("Stream"),
            "icon": ":/menu/redesign-stream.svg",
            "action": function(dataList) { MediaLib.streamMedia(_mlIDList(dataList), true) },
            "visible": _singleMedia
        }, {
            "text": qsTr("Convert"),
            "icon": ":/menu/redesign-convert.svg",
            "action": function(dataList) { MediaLib.streamMedia(_mlIDList(dataList), false) },
            "visible": _singleMedia
        }, {
            "text": qsTr("Add to Queue"),
            "icon": ":/menu/redesign-queue.svg",
            "action": enqueue
        }, {
            "text": qsTr("Enqueue as album"),
            "action": enqueueAsAlbum,
            "visible": root.showPlayAsAlbumAction &&
                       (root.model instanceof MLAudioModel)
        }, {
            "text": qsTr("Add to Playlist"),
            "icon": ":/menu/redesign-addplaylist.svg",
            "action": addToAPlaylist
        }, {
            "text": (root.showPlayAsAudioAction ? qsTr("Add to a video-only playlist") : qsTr("Add to an audio-only playlist")),
            "action": (root.showPlayAsAudioAction ? root.addToVideoOnlyPlaylist : root.addToAudioOnlyPlaylist)
        }, {
            "text": Qt.platform.os === "windows" ? qsTr("Show in File Explorer")
                  : Qt.platform.os === "osx" ? qsTr("Show in Finder")
                  : qsTr("Show in File Manager"),
            "icon": ":/menu/redesign-explorer.svg",
            "action": openContainingFolder,
            "visible": _openContainingFolder
        }, {
            "text": qsTr("Remove from list"),
            "action": removeFromHistory,
            "visible": _removeFromHistory
        }, {
            "text": qsTr("Delete"),
            "action": deleteStream,
            "visible": _deleteStream
        }, {
            "text": qsTr("Information"),
            "action": _signalShowInformation,
            "visible": showInformationAvailable
        },{
            "text": qsTr("Delete File From System"),
            "action": deleteFileFromSource,
            "visible": _deleteFileFromSource
        },{
            // "&&": a single "&" marks a mnemonic in a QMenu
            "text": qsTr("Properties && Metadata"),
            "icon": ":/menu/redesign-info.svg",
            "action": function(dataList, options, indexes) {
                DialogsProvider.mediaInfoDialog(dataList[0][idDataRole])
            },
            "visible": _singleMedia
        }
    ]

    // Events

    onRequestData: (requestID, indexes) => {
        model.getData(indexes, function (data) {
            setData(requestID, data)
        })
    }

    // Functions

    function addAndPlay(dataList, options, indexes) {
        model.ml.addAndPlay(_mlIDList(dataList), _playerOptions(options))
        if (root.openPlayerOnPlay)
            MainCtx.playerView = true
    }

    function playAsAudio(dataList, options, indexes) {
        model.ml.addAndPlay(_mlIDList(dataList), _playerOptions(options, ":no-video"))
    }

    function playAsAlbum(dataList, options, indexes) {
        model.ml.addAndPlay(_mlIDList(dataList, root.albumIdDataRole), _playerOptions(options))
    }

    function enqueue(dataList, options, indexes) {
        model.ml.addToPlaylist(_mlIDList(dataList), _playerOptions(options))
    }

    function enqueueAsAlbum(dataList, options, indexes) {
        model.ml.addToPlaylist(_mlIDList(dataList, root.albumIdDataRole), _playerOptions(options))
    }

    function addToAudioOnlyPlaylist(dataList, options, indexes) {
        addToAPlaylist(dataList, options, indexes, MLPlaylistListModel.PLAYLIST_TYPE_AUDIO_ONLY)
    }

    function addToVideoOnlyPlaylist(dataList, options, indexes) {
        addToAPlaylist(dataList, options, indexes, MLPlaylistListModel.PLAYLIST_TYPE_VIDEO_ONLY)
    }

    function addToAPlaylist(dataList, options, indexes, type) {
        if (type === undefined)
            type = MLPlaylistListModel.PLAYLIST_TYPE_ALL

        DialogsProvider.playlistsDialog(_mlIDList(dataList), type)
    }

    function addFavorite(dataList, options, indexes) {
        model.setMediaIsFavorite(indexes[0], true)
    }

    function removeFavorite(dataList, options, indexes) {
        model.setMediaIsFavorite(indexes[0], false)
    }

    function markSeen(dataList, options, indexes) {
        model.setItemPlayed(indexes[0], true)
    }

    function markUnseen(dataList, options, indexes) {
        model.setItemPlayed(indexes[0], false)
    }

    function removeFromHistory(dataList, options, indexes) {
        // redesign: an added folder on the Videos page leaves the library the same way
        if (model instanceof MLVideoFolderTreeModel)
            model.removeFolder(indexes[0])
        else
            model.removeFromHistory(indexes[0])
    }

    function openContainingFolder(dataList, options, indexes) {
        const parentDir = model.getParentURL(indexes[0]);

        Qt.openUrlExternally(parentDir)
    }

    function deleteStream(dataList, options, indexes) {
        model.deleteStream(dataList[0][idDataRole])
    }

    function deleteFileFromSource(dataList, options, indexes) {
        let confirm = DialogsProvider.questionDialog(qsTr("Are you sure you want to delete this file?"));
        
        if (confirm) {
            model.deleteFileFromSource(indexes[0]);
            console.log("File Deleted !!");
        }
    }

    function showInformationAvailable(dataList, options, indexes) {
        return indexes.length === 1
                && Helpers.isInteger(options?.["information"] ?? null)
    }

    // Private

    function _checkRole(dataList, role, expected) {
        if (dataList.length !== 1)
            return false

        if (!(role in dataList[0]))
            return false

        return (dataList[0][role] === expected)
    }

    function _showAddFavorite(dataList, options, indexes) {
        return _checkRole(dataList, "isFavorite", false)
    }

    function _showRemoveFavorite(dataList, options, indexes) {
        return _checkRole(dataList, "isFavorite", true)
    }

    function _showSeen(dataList, options, indexes) {
        return _checkRole(dataList, "isNew", true)
    }

    function _showUnseen(dataList, options, indexes) {
        return _checkRole(dataList, "isNew", false)
    }

    function _removeFromHistory(dataList, options, indexes) {
        if (dataList.length !== 1)
            return false

        if (model instanceof MLVideoFolderTreeModel)
            return model.canRemoveFolder(indexes[0])

        return (model instanceof MLRecentVideoModel)
    }

    // one media (not a folder or a group, whose ids have a parent type)
    function _singleMedia(dataList, options, indexes) {
        return (dataList.length === 1)
                && !(dataList[0][idDataRole].hasParent())
    }

    function _openContainingFolder(dataList, options, indexes) {
        return _checkRole(dataList, "isLocal", true)
    }

    function _deleteStream(dataList,options, indexes) {
        return _checkRole(dataList, "isDeletable", true)
    }

    function _deleteFileFromSource(dataList, options, indexes) {
        return  _checkRole(dataList, "isDeletableFile", true)
    }

    function _signalShowInformation(dataList, options) {
        const index = options?.["information"] ?? null
        console.assert(Helpers.isInteger(index))
        showMediaInformation(index)
    }

    function _playerOptions(options, extraOptions) {
        const playerOpts = options?.["player-options"] ?? []
        return playerOpts.concat(extraOptions)
    }

    function _mlIDList(dataList, role = root.idDataRole) {
        const idList = []
        for (let i in dataList) {
            console.assert(dataList[i][role] !== undefined)
            idList.push(dataList[i][role])
        }

        return idList
    }
}
