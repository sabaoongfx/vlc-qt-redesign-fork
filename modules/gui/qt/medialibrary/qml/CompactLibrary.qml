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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.MediaLibrary

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.Dialogs

// The library as a card beside the video in the player (Figma "sidebar" frames): address line,
// item count, search and a list. What the list shows follows the rail on its left: Home
// (continue watching), Videos (the folder tree), Music (songs, albums, artists, genres), Network
// (saved streams), Playlists and Recent. It keeps its own path, so the library page behind the
// player never moves. A media plays right away, a folder opens in place.
Rectangle {
    id: root

    // "home", "videos", "music", "network", "playlists" or "recent"
    property string section: "videos"

    // The path below the first level of the section: [{ title, kind, id }, ...]. A folder
    // has the kind "folder" and its id, the music kinds are "songs", "albums", "artists", "genres".
    property var trail: []

    // The places left by Back, in the order Forward goes through them
    property var _forward: []

    readonly property var _current: trail.length > 0 ? trail[trail.length - 1] : null

    readonly property var _colors: VLCStyle.figmaColors(theme.palette.isDark)

    readonly property string _rootTitle: {
        switch (section) {
        case "home": return qsTr("Home")
        case "music": return qsTr("Music")
        case "network": return qsTr("Network")
        case "playlists": return qsTr("Playlists")
        case "recent": return qsTr("Recent")
        default: return qsTr("Videos")
        }
    }

    // The row that starts the list ("Add"), none for Home, Recent and the music lists
    readonly property string _addLabel: {
        switch (section) {
        case "videos": return qsTr("Add")
        case "music": return _current ? "" : qsTr("Add")
        case "network": return qsTr("Add Network Stream")
        case "playlists": return qsTr("Create playlist")
        default: return ""
        }
    }

    readonly property var _model: modelLoader.item

    // Figma card header: sort, list/grid and a magnifier that opens the search field
    property string _sortCriteria: ""
    property int _sortOrder: Qt.AscendingOrder
    property bool _grid: false
    property bool _searchOpen: false

    // The Figma "Sorting Options" entries that apply to what the card shows (none for Home,
    // Recent and the music menu, which keep their own order)
    readonly property var _sortModel: {
        const titles = (key) => [
            { text: qsTr("Title A-Z"), criteria: key, order: Qt.AscendingOrder },
            { text: qsTr("Title Z-A"), criteria: key, order: Qt.DescendingOrder }
        ]
        const dates = [
            { text: qsTr("Newest First"), criteria: "insertion", order: Qt.DescendingOrder },
            { text: qsTr("Oldest First"), criteria: "insertion", order: Qt.AscendingOrder }
        ]
        const uris = [
            { text: qsTr("URI Ascending"),  criteria: "filename", order: Qt.AscendingOrder },
            { text: qsTr("URI Descending"), criteria: "filename", order: Qt.DescendingOrder }
        ]

        switch (section) {
        case "videos":
            return [
                { text: qsTr("Unwatched First"), criteria: "playcount", order: Qt.AscendingOrder },
                { text: qsTr("Watched First"),   criteria: "playcount", order: Qt.DescendingOrder },
                ...dates, ...titles("title"), ...uris
            ]
        case "music":
            switch (_current?.kind) {
            case "songs":
                return [
                    ...dates, ...titles("title"),
                    { text: qsTr("Artist A-Z"), criteria: "main_artist", order: Qt.AscendingOrder },
                    { text: qsTr("Artist Z-A"), criteria: "main_artist", order: Qt.DescendingOrder },
                    { text: qsTr("Album A-Z"),  criteria: "album_title", order: Qt.AscendingOrder },
                    { text: qsTr("Album Z-A"),  criteria: "album_title", order: Qt.DescendingOrder },
                    { text: qsTr("Track Number Ascending"),  criteria: "track_number", order: Qt.AscendingOrder },
                    { text: qsTr("Track Number Descending"), criteria: "track_number", order: Qt.DescendingOrder },
                    ...uris,
                    { text: qsTr("Disc Number Ascending"),  criteria: "disc_number", order: Qt.AscendingOrder },
                    { text: qsTr("Disc Number Descending"), criteria: "disc_number", order: Qt.DescendingOrder }
                ]
            case "albums":
                return titles("title")
            case "artists":
            case "genres":
                return titles("name")
            default:
                return []
            }
        case "network":
            return titles("url")
        case "playlists":
            return titles("name")
        default:
            return []
        }
    }

    function closeSearch() {
        searchField.text = ""
        _searchOpen = false
    }

    // The glyph of the rows that have no cover
    readonly property string _rowIcon: {
        switch (section) {
        case "music": return VLCIcons.topbar_music
        case "network": return VLCIcons.topbar_network
        case "playlists": return VLCIcons.playlist
        case "recent": return VLCIcons.history
        default: return VLCIcons.topbar_video
        }
    }

    function open(place) {
        _forward = []
        trail = [...trail, place]
    }

    function goTo(depth) {
        _forward = []
        trail = trail.slice(0, depth)
    }

    function back() {
        if (trail.length === 0)
            return

        _forward = [trail[trail.length - 1], ..._forward]
        trail = trail.slice(0, trail.length - 1)
    }

    function forward() {
        if (_forward.length === 0)
            return

        const next = _forward[0]
        _forward = _forward.slice(1)
        trail = [...trail, next]
    }

    // The "Add" row
    function add() {
        switch (section) {
        case "network":
            streamDialog.open()
            break
        case "playlists":
            playlistDialog.open()
            break
        default:
            DialogsProvider.addLibraryFolderDialog()
        }
    }

    // A click on a row
    function activate(item) {
        if (section === "videos" && item.isVideo === false) {
            open({ title: item.title, kind: "folder", id: item.id })
        } else if (section === "music" && !_current) {
            open({ title: item.title, kind: item.kind })
        } else {
            MediaLib.addAndPlay(item.id)
        }
    }

    onSectionChanged: {
        trail = []
        _forward = []
        closeSearch()
        _sortCriteria = ""
        _sortOrder = Qt.AscendingOrder
    }

    // a sort key of one list means nothing to the next one
    onTrailChanged: {
        _sortCriteria = ""
        _sortOrder = Qt.AscendingOrder
    }

    color: _colors.section
    radius: VLCStyle.dp(8, VLCStyle.scale)
    clip: true

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Library")

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    // The model of what is shown, created only while it is shown
    Loader {
        id: modelLoader

        sourceComponent: {
            switch (root.section) {
            case "home": return continueModel
            case "music":
                switch (root._current?.kind) {
                case "songs": return songsModel
                case "albums": return albumsModel
                case "artists": return artistsModel
                case "genres": return genresModel
                default: return musicMenuModel
                }
            case "network": return urlsModel
            case "playlists": return playlistsModel
            case "recent": return recentModel
            default: return root._current ? folderModel : rootFolderModel
            }
        }
    }

    Component {
        id: rootFolderModel

        MLVideoFolderTreeModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    Component {
        id: folderModel

        MLVideoFolderTreeModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
            parentId: root._current?.id
        }
    }

    Component {
        id: continueModel

        MLRecentVideoModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    Component {
        id: songsModel

        MLAudioModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    Component {
        id: albumsModel

        MLAlbumModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    Component {
        id: artistsModel

        MLArtistModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    Component {
        id: genresModel

        MLGenreModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    Component {
        id: urlsModel

        MLUrlModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    Component {
        id: playlistsModel

        MLPlaylistListModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    Component {
        id: recentModel

        MLRecentMediaModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    Component {
        id: musicMenuModel

        ListModel {
            ListElement { title: qsTr("Songs"); kind: "songs" }
            ListElement { title: qsTr("Albums"); kind: "albums" }
            ListElement { title: qsTr("Artists"); kind: "artists" }
            ListElement { title: qsTr("Genres"); kind: "genres" }
        }
    }

    // Figma "Open network stream" and "New playlist", for the Add row of Network and Playlists
    NetworkStreamDialog {
        id: streamDialog

        onSaved: (urls) => {
            urls.forEach(url => urlAdder.add(url))
        }
    }

    // saves the addresses of the stream dialog
    MLUrlModel {
        id: urlAdder

        ml: MediaLib
    }

    NewPlaylistDialog {
        id: playlistDialog

        onSaved: (name, urls) => playlistCreator.create(name, urls)
    }

    MLPlaylistListModel {
        id: playlistCreator

        ml: MediaLib
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: VLCStyle.margin_normal
        anchors.bottomMargin: 0

        spacing: VLCStyle.margin_xsmall

        // Address line: back, forward, the path, the menu
        RowLayout {
            Layout.fillWidth: true

            spacing: VLCStyle.margin_xxsmall

            Widgets.IconToolButton {
                text: VLCIcons.back
                description: qsTr("Back")
                font.pixelSize: VLCStyle.icon_banner
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                enabled: root.trail.length > 0
                onClicked: root.back()
            }

            Widgets.IconToolButton {
                text: VLCIcons.back
                rotation: 180 // no forward glyph in the icon font
                description: qsTr("Forward")
                font.pixelSize: VLCStyle.icon_banner
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                enabled: root._forward.length > 0
                onClicked: root.forward()
            }

            // A long path keeps its last two names, "... > Shows > The Wand"; depth is the length
            // of the trail a name leads to
            Widgets.Breadcrumbs {
                Layout.fillWidth: true

                names: {
                    const all = [{ text: root._rootTitle, depth: 0 },
                                 ...root.trail.map((place, i) => ({ text: place.title, depth: i + 1 }))]
                    return all.length > 3 ? [{ text: "…", depth: all[all.length - 3].depth }, ...all.slice(all.length - 2)]
                                          : all
                }

                onCrumbClicked: (depth) => root.goTo(depth)
            }

            // the folder context menu
            Widgets.LibraryMenuButton {
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height
            }
        }

        // Item count, then sort, list/grid and search (Figma: three icons; the magnifier opens the
        // search field in their place, Escape or leaving it empty closes it)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(30, VLCStyle.scale)

            spacing: VLCStyle.margin_xxsmall

            Widgets.LabelExt {
                visible: !root._searchOpen

                text: qsTr("%1 items").arg(root._model?.count ?? 0)
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.secondary
            }

            Item {
                visible: !root._searchOpen
                Layout.fillWidth: true
            }

            Widgets.SortControl {
                visible: !root._searchOpen && root._sortModel.length > 0

                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                font.pixelSize: VLCStyle.icon_banner
                description: qsTr("Sort")

                popupAbove: false

                model: root._sortModel
                sortKey: root._sortCriteria
                sortOrder: root._sortOrder

                onSortSelected: (key) => root._sortCriteria = key
                onSortOrderSelected: (type) => root._sortOrder = type
            }

            Widgets.IconToolButton {
                visible: !root._searchOpen

                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                font.pixelSize: VLCStyle.icon_banner
                text: root._grid ? VLCIcons.list : VLCIcons.grid
                description: root._grid ? qsTr("List View") : qsTr("Grid View")

                onClicked: root._grid = !root._grid
            }

            Widgets.IconToolButton {
                visible: !root._searchOpen

                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                font.pixelSize: VLCStyle.icon_banner
                text: VLCIcons.search
                description: qsTr("Search")

                onClicked: {
                    root._searchOpen = true
                    searchField.forceActiveFocus(Qt.MouseFocusReason)
                }
            }

            Rectangle {
                visible: root._searchOpen

                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(30, VLCStyle.scale)

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root._colors.search

                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Search")

                TapHandler {
                    onTapped: searchField.forceActiveFocus(Qt.MouseFocusReason)
                }

                Widgets.IconLabel {
                    id: searchIcon

                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.margin_xsmall
                    anchors.verticalCenter: parent.verticalCenter

                    text: VLCIcons.search
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.fg.secondary
                }

                T.TextField {
                    id: searchField

                    anchors.left: searchIcon.right
                    anchors.leftMargin: VLCStyle.margin_xsmall
                    anchors.right: closeSearchButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.fg.primary
                    selectionColor: theme.accent
                    font.pixelSize: VLCStyle.fontSize_normal
                    font.family: VLCStyle.fontFamily

                    Accessible.name: qsTr("Search")

                    // typed letters must not run the global shortcuts; an empty field closes
                    // when it loses the focus
                    onActiveFocusChanged: {
                        MainCtx.useGlobalShortcuts = !activeFocus
                        if (!activeFocus && text === "")
                            root._searchOpen = false
                    }

                    Keys.onEscapePressed: root.closeSearch()

                    Text {
                        anchors.fill: parent

                        visible: searchField.text.length === 0
                        text: qsTr("Search")
                        color: theme.fg.secondary
                        opacity: 0.6
                        font: searchField.font
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Widgets.IconToolButton {
                    id: closeSearchButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    width: VLCStyle.dp(28, VLCStyle.scale)
                    height: VLCStyle.dp(28, VLCStyle.scale)

                    font.pixelSize: VLCStyle.icon_small
                    text: VLCIcons.close
                    description: qsTr("Close the search")

                    onClicked: root.closeSearch()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.border

            color: root._colors.line
        }

        // The "Add" row
        T.ItemDelegate {
            id: addRow

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(42, VLCStyle.scale)

            visible: root._addLabel !== ""
            padding: 0

            Accessible.role: Accessible.Button
            Accessible.name: root._addLabel

            onClicked: root.add()

            background: Rectangle {
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: addRow.hovered ? root._colors.raised : "transparent"
            }

            contentItem: RowLayout {
                spacing: VLCStyle.margin_xsmall

                Widgets.IconLabel {
                    Layout.preferredWidth: VLCStyle.dp(32, VLCStyle.scale)
                    Layout.leftMargin: VLCStyle.margin_xxsmall

                    horizontalAlignment: Text.AlignHCenter
                    text: VLCIcons.add
                    font.pixelSize: VLCStyle.icon_banner
                    color: theme.fg.secondary
                }

                Widgets.LabelExt {
                    Layout.fillWidth: true

                    text: root._addLabel
                    font.pixelSize: VLCStyle.fontSize_normal
                    color: theme.fg.secondary
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }

        ListView {
            id: list

            visible: !root._grid

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: root._model

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            delegate: T.ItemDelegate {
                id: row

                required property int index
                required property var model

                // only the folder tree has folders, everything else plays or opens
                readonly property bool isFolder: root.section === "videos" && model.isVideo === false
                readonly property string title: model.title ?? model.name ?? model.url ?? ""
                readonly property string cover: String(model.thumbnail ?? model.small_cover ?? model.cover ?? "")

                width: ListView.view.width
                height: VLCStyle.dp(42, VLCStyle.scale)

                padding: 0

                Accessible.role: Accessible.Button
                Accessible.name: title

                onClicked: root.activate({
                    id: model.id,
                    title: title,
                    kind: model.kind,
                    isVideo: model.isVideo
                })

                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: row.hovered ? root._colors.raised : "transparent"
                }

                contentItem: RowLayout {
                    spacing: VLCStyle.margin_xsmall

                    // the cover when there is one, else a glyph (a folder for a folder)
                    Item {
                        Layout.preferredWidth: VLCStyle.dp(32, VLCStyle.scale)
                        Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
                        Layout.leftMargin: VLCStyle.margin_xxsmall

                        Image {
                            anchors.fill: parent

                            visible: !row.isFolder && row.cover !== ""
                            source: visible ? row.cover : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: VLCStyle.dp(64, VLCStyle.scale)
                            sourceSize.height: VLCStyle.dp(64, VLCStyle.scale)
                        }

                        Widgets.IconLabel {
                            anchors.centerIn: parent

                            visible: row.isFolder || row.cover === ""
                            text: row.isFolder ? VLCIcons.ic_fluent_folder_open_24_regular : root._rowIcon
                            font.pixelSize: VLCStyle.icon_banner
                            color: theme.fg.secondary
                        }
                    }

                    Widgets.LabelExt {
                        Layout.fillWidth: true

                        text: row.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: theme.fg.primary
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        // the same items as tiles (the view button): two columns, the cover and the title under it
        GridView {
            id: grid

            readonly property bool _wide: root.section === "videos" || root.section === "home"
                                          || root.section === "recent"

            visible: root._grid

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: root._grid ? root._model : null

            cellWidth: Math.floor(width / 2)
            cellHeight: Math.round(cellWidth * (_wide ? 9 / 16 : 1)) + VLCStyle.dp(36, VLCStyle.scale)

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            delegate: T.ItemDelegate {
                id: tile

                required property int index
                required property var model

                readonly property bool isFolder: root.section === "videos" && model.isVideo === false
                readonly property string title: model.title ?? model.name ?? model.url ?? ""
                readonly property string cover: String(model.thumbnail ?? model.small_cover ?? model.cover ?? "")

                width: GridView.view.cellWidth
                height: GridView.view.cellHeight

                padding: VLCStyle.margin_xxsmall

                Accessible.role: Accessible.Button
                Accessible.name: title

                onClicked: root.activate({
                    id: model.id,
                    title: title,
                    kind: model.kind,
                    isVideo: model.isVideo
                })

                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: tile.hovered ? root._colors.raised : "transparent"
                }

                contentItem: ColumnLayout {
                    spacing: VLCStyle.margin_xxsmall

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        radius: VLCStyle.dp(6, VLCStyle.scale)
                        color: root._colors.raised

                        Widgets.ImageExt {
                            anchors.fill: parent

                            visible: !tile.isFolder && tile.cover !== ""
                            radius: parent.radius
                            source: visible ? tile.cover : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: VLCStyle.dp(240, VLCStyle.scale)
                        }

                        Widgets.IconLabel {
                            anchors.centerIn: parent

                            visible: tile.isFolder || tile.cover === ""
                            text: tile.isFolder ? VLCIcons.ic_fluent_folder_open_24_regular : root._rowIcon
                            font.pixelSize: VLCStyle.icon_large
                            color: theme.fg.secondary
                        }
                    }

                    Widgets.LabelExt {
                        Layout.fillWidth: true

                        text: tile.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: theme.fg.primary
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
