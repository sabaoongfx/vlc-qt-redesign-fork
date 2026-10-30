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
// (continue watching), Videos and Music (folder trees), Network
// (saved streams), Playlists and Recent. It keeps its own path, so the library page behind the
// player never moves. A media plays right away, a folder opens in place.
Rectangle {
    id: root

    // "home", "videos", "music", "network", "playlists" or "recent"
    property string section: "videos"

    // The path below the first level of the section: [{ title, kind, id }, ...]. A folder
    // has the kind "folder" and its id.
    property var trail: []

    // The places left by Back, in the order Forward goes through them
    property var _forward: []

    readonly property var _current: trail.length > 0 ? trail[trail.length - 1] : null

    // Videos and Music are folder trees: folders, then the videos (songs) of a folder
    readonly property bool _folderTree: section === "videos" || section === "music"

    // NOTE: the context finds the window palette only once the card is in the window; until then
    //       there is no palette (dark is assumed)
    readonly property var _colors: VLCStyle.figmaColors(theme.palette?.isDark ?? true)

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

    // The row that starts the list ("Add"), none for Home and Recent
    readonly property string _addLabel: {
        switch (section) {
        case "videos":
        case "music": return qsTr("Add")
        case "network": return qsTr("Add Network Stream")
        case "playlists": return qsTr("Create playlist")
        default: return ""
        }
    }

    // Home: the full lists behind a section's chevron that are not library models (frequent
    // folders, playlists, artists) go through this ListModel; _homeList keeps their ids
    readonly property bool _homeListShown: ["folders", "playlists", "artists"].includes(_current?.kind ?? "")
    readonly property var _model: _homeListShown ? homeListModel : modelLoader.item

    // Figma Home frame: the root of Home is a page of sections, not a list
    readonly property bool _homeRoot: section === "home" && !_current

    property var _homeList: []
    property var _frequentFolders: []
    property var _frequentPlaylists: []
    property var _frequentArtists: []

    // Home: the history sections as plain lists, so the sort button can order every section
    // (the history models keep their own order, last played first)
    property var _continueItems: []
    property var _listenItems: []

    // Home in the grid view: two tiles a row
    readonly property real _homeItemWidth: _grid ? Math.floor(homeColumn.width / 2) : homeColumn.width

    function _readModel(model, assign) {
        const count = model.count
        if (count === 0) {
            assign([])
            return
        }
        model.getDataFlat([...Array(count).keys()], (list) => assign(Array.from(list)))
    }

    // Title A-Z / Z-A on Home; without a sort the sections keep their own order
    function _homeSorted(items) {
        if (_sortCriteria === "")
            return items
        const sorted = [...items].sort((a, b) => String(a.title ?? "").localeCompare(String(b.title ?? "")))
        return (_sortOrder === Qt.DescendingOrder) ? sorted.reverse() : sorted
    }

    // The library keeps no visit count for folders and playlists, MediaLib counts the visits;
    // the artists are the ones of the songs in the history
    function refreshHome() {
        _readModel(homeContinue, (list) => root._continueItems = list)
        _readModel(homeListen, (list) => root._listenItems = list)
        _frequentFolders = MediaLib.frequentVisits("folder", 3)
        _frequentPlaylists = MediaLib.frequentVisits("playlist", 3)
        MediaLib.frequentArtists(3, (list) => { root._frequentArtists = list })
    }

    function _fillHomeList(items, kind) {
        _homeList = items
        homeListModel.clear()
        items.forEach((item, idx) => homeListModel.append({ title: item.title, kind: kind, idx: idx }))
    }

    // the pop-out button: the same place in the library window (it leaves the player)
    function popOut() {
        switch (section) {
        case "videos": {
            const folders = trail.filter(place => place.kind === "folder")
            if (folders.length === 0) {
                History.reset(["video"], {}, Qt.MouseFocusReason)
                return
            }
            const last = folders[folders.length - 1]
            History.reset(["video", "folders", "folder"],
                         { parentId: last.id, title: last.title,
                           trail: folders.map(place => ({ id: place.id, title: place.title })) },
                         Qt.MouseFocusReason)
            return
        }
        case "music": {
            const folders = trail.filter(place => place.kind === "folder")
            if (folders.length === 0) {
                History.reset(["music"], {}, Qt.MouseFocusReason)
                return
            }
            const last = folders[folders.length - 1]
            History.reset(["music", "folders", "folder"],
                         { parentId: last.id, title: last.title,
                           trail: folders.map(place => ({ id: place.id, title: place.title })) },
                         Qt.MouseFocusReason)
            return
        }
        case "network":
            History.reset(["network"], {}, Qt.MouseFocusReason)
            return
        case "playlists":
            History.reset(["playlists"], {}, Qt.MouseFocusReason)
            return
        default:
            History.reset(["home"], {}, Qt.MouseFocusReason)
        }
    }

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
            return [...dates, ...titles("title"), ...uris]
        case "network":
            return titles("url")
        case "playlists":
            return titles("name")
        case "home":
            // the sections page; a section opened from it keeps its order
            return _current ? [] : titles("title")
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
        case "playlists": return VLCIcons.playlists
        case "recent": return VLCIcons.history
        default: return VLCIcons.topbar_video
        }
    }

    // MLItemId is a gadget: compare its text form
    function _sameId(a, b) {
        return String(a?.toString?.() ?? a) === String(b?.toString?.() ?? b)
    }

    // Back goes up to the parent and Forward back down the same branch (user request); opening
    // the child Forward would give keeps the rest of that branch
    function open(place) {
        if (_forward.length > 0 && _forward[0].kind === place.kind && _sameId(_forward[0].id, place.id))
            _forward = _forward.slice(1)
        else
            _forward = []
        trail = [...trail, place]
    }

    function goTo(depth) {
        if (depth >= trail.length)
            return
        _forward = [...trail.slice(depth), ..._forward]
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
        const inFolders = _folderTree || _current?.kind === "folder"

        if (item.kind === "homeFolder" || (inFolders && item.isVideo === false)) {
            MediaLib.recordVisit("folder", item.id, item.title)
            open({ title: item.title, kind: "folder", id: item.id })
        } else {
            if (item.kind === "homePlaylist" || (section === "playlists" && !_current))
                MediaLib.recordVisit("playlist", item.id, item.title)
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

        switch (_current?.kind) {
        case "folders":
            _fillHomeList(MediaLib.frequentVisits("folder", 0), "homeFolder")
            break
        case "playlists":
            _fillHomeList(MediaLib.frequentVisits("playlist", 0), "homePlaylist")
            break
        case "artists":
            if (section === "home")
                MediaLib.frequentArtists(50, (list) => root._fillHomeList(list, "homeArtist"))
            break
        }
    }

    on_HomeRootChanged: if (_homeRoot) refreshHome()

    Component.onCompleted: if (_homeRoot) refreshHome()

    // transparent until the palette is there: the card's first frame was a white bar (a
    // Rectangle's default colour) before it turned dark (user report)
    color: theme.palette ? _colors.section : "transparent"
    // Figma: a square column between the rail and the video
    radius: 0
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
            // any section can show a folder (Home's frequent folders)
            if (root._current?.kind === "folder")
                return folderModel

            switch (root.section) {
            case "home":
                switch (root._current?.kind) {
                case "continue": return continueModel
                case "listen": return listenModel
                default: return null // the sections page, or homeListModel
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
            audio: root.section === "music"
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    Component {
        id: folderModel

        MLVideoFolderTreeModel {
            ml: MediaLib
            audio: root.section === "music"
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
        id: listenModel

        MLRecentAudioModel {
            ml: MediaLib
            searchPattern: searchField.text
            sortCriteria: root._sortCriteria
            sortOrder: root._sortOrder
        }
    }

    ListModel {
        id: homeListModel
    }

    // The two first rows of Home, three items each
    MLRecentVideoModel {
        id: homeContinue

        ml: MediaLib
        limit: 3
        searchPattern: searchField.text
    }

    MLRecentAudioModel {
        id: homeListen

        ml: MediaLib
        limit: 3
        searchPattern: searchField.text
    }

    Connections {
        target: homeContinue

        function onCountChanged() { root._readModel(homeContinue, (list) => root._continueItems = list) }
        function onDataChanged() { root._readModel(homeContinue, (list) => root._continueItems = list) }
        function onModelReset() { root._readModel(homeContinue, (list) => root._continueItems = list) }
    }

    Connections {
        target: homeListen

        function onCountChanged() { root._readModel(homeListen, (list) => root._listenItems = list) }
        function onDataChanged() { root._readModel(homeListen, (list) => root._listenItems = list) }
        function onModelReset() { root._readModel(homeListen, (list) => root._listenItems = list) }
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

    // Drag a row or a tile into the play queue: the card is above all for building the queue
    // while watching (user request). The queue takes any DragItem (PlaylistPane.acceptDropFunc).
    // Only library models can be dragged, not Home's pages of sections and frequent places.
    readonly property bool _canDrag: !!root._model?.getDataFlat && !_homeListShown

    property var _dragIndexes: []

    function _drag(index, active) {
        if (active) {
            _dragIndexes = [index]
            dragItem.Drag.active = true
        } else {
            dragItem.Drag.drop()
        }
    }

    MLDragItem {
        id: dragItem

        view: root._grid ? grid : list

        indexes: root._dragIndexes
        indexesFlat: true

        defaultCover: root.section === "music" ? VLCStyle.noArtAlbumCover : VLCStyle.noArtVideoCover

        coverProvider: (index, data) => ({
            artwork: String(data.thumbnail ?? data.small_cover ?? data.cover ?? ""),
            fallback: dragItem.defaultCover
        })
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

    // Figma sidebar card: 20px padding, two 24px header rows 20px apart, the divider 17px below
    // them and the list 20px under the divider, icons 12px apart
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: VLCStyle.dp(20, VLCStyle.scale)
        anchors.bottomMargin: 0

        spacing: 0

        // Address line: back, forward, the path, the menu
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(24, VLCStyle.scale)

            spacing: VLCStyle.dp(12, VLCStyle.scale)

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
                Layout.leftMargin: -VLCStyle.dp(2, VLCStyle.scale) // the row gap is 10 there

                pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                plain: true
                plainColor: root._colors.label
                separatorColor: root._colors.tabIcon

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

            // Figma pop-out: this place in the library window
            Widgets.IconToolButton {
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                font.pixelSize: VLCStyle.icon_banner
                text: VLCIcons.fullscreen
                description: qsTr("Open in the library")

                onClicked: root.popOut()
            }
        }

        // Item count, then sort, list/grid and search (Figma: three icons; the magnifier opens the
        // search field in their place, Escape or leaving it empty closes it)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(24, VLCStyle.scale)

            spacing: VLCStyle.dp(12, VLCStyle.scale)

            Widgets.LabelExt {
                // the Home sections page has no single count
                visible: !root._searchOpen && !root._homeRoot

                text: qsTr("%1 items").arg(root._model?.count ?? 0)
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: root._colors.hint
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

                // Figma: a dot on the icon while the list is not in its own order
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: VLCStyle.dp(4, VLCStyle.scale)

                    visible: root._sortCriteria !== ""

                    width: VLCStyle.dp(6, VLCStyle.scale)
                    height: width
                    radius: width / 2
                    color: theme.accent
                }
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
            Layout.topMargin: VLCStyle.dp(17, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.border

            color: root._colors.line
        }

        Item {
            Layout.preferredHeight: VLCStyle.dp(15, VLCStyle.scale) // + the 5px a 42px row adds above its 32px
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

        // Figma Home: sections of three items with a chevron that opens the whole list
        Flickable {
            id: homeView

            visible: root._homeRoot

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: homeColumn.implicitHeight

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            Column {
                id: homeColumn

                width: homeView.width
                spacing: VLCStyle.margin_xsmall

                HomeSection {
                    card: root
                    title: qsTr("Continue Watching")
                    kind: "continue"
                    shown: homeContinue.count > 0

                    Repeater {
                        model: root._homeSorted(root._continueItems)

                        delegate: PlaceRow {
                            required property var modelData

                            card: root
                            tile: root._grid
                            width: root._homeItemWidth

                            title: modelData.title ?? ""
                            cover: String(modelData.thumbnail ?? "")
                            progress: modelData.progress ?? 0
                            watched: (modelData.playcount ?? 0) > 0

                            onClicked: MediaLib.addAndPlay(modelData.id)
                        }
                    }
                }

                HomeSection {
                    card: root
                    title: qsTr("Listen Again")
                    kind: "listen"
                    shown: homeListen.count > 0

                    Repeater {
                        model: root._homeSorted(root._listenItems)

                        delegate: PlaceRow {
                            required property var modelData

                            card: root
                            tile: root._grid
                            width: root._homeItemWidth

                            title: modelData.title ?? ""
                            cover: String(modelData.cover ?? modelData.small_cover ?? "")
                            glyph: VLCIcons.topbar_music

                            onClicked: MediaLib.addAndPlay(modelData.id)
                        }
                    }
                }

                HomeSection {
                    card: root
                    title: qsTr("Frequently Visited Folders")
                    kind: "folders"
                    shown: root._frequentFolders.length > 0

                    Repeater {
                        model: root._homeSorted(root._frequentFolders)

                        delegate: PlaceRow {
                            required property var modelData

                            card: root
                            tile: root._grid
                            width: root._homeItemWidth

                            title: modelData.title
                            folder: true

                            onClicked: root.activate({ id: modelData.id, title: modelData.title, kind: "homeFolder" })
                        }
                    }
                }

                HomeSection {
                    card: root
                    title: qsTr("Frequently Visited Playlists")
                    kind: "playlists"
                    shown: root._frequentPlaylists.length > 0

                    Repeater {
                        model: root._homeSorted(root._frequentPlaylists)

                        delegate: PlaceRow {
                            required property var modelData

                            card: root
                            tile: root._grid
                            width: root._homeItemWidth

                            title: modelData.title
                            glyph: VLCIcons.playlists

                            onClicked: root.activate({ id: modelData.id, title: modelData.title, kind: "homePlaylist" })
                        }
                    }
                }

                HomeSection {
                    card: root
                    title: qsTr("Frequently Listened Artists")
                    kind: "artists"
                    shown: root._frequentArtists.length > 0

                    Repeater {
                        model: root._homeSorted(root._frequentArtists)

                        delegate: PlaceRow {
                            required property var modelData

                            card: root
                            tile: root._grid
                            width: root._homeItemWidth

                            title: modelData.title
                            glyph: VLCIcons.profile_new

                            onClicked: MediaLib.addAndPlay(modelData.id)
                        }
                    }
                }

                Widgets.LabelExt {
                    width: homeColumn.width
                    topPadding: VLCStyle.margin_large

                    visible: homeContinue.count === 0 && homeListen.count === 0
                             && root._frequentFolders.length === 0 && root._frequentPlaylists.length === 0
                             && root._frequentArtists.length === 0

                    text: qsTr("Nothing played yet")
                    horizontalAlignment: Text.AlignHCenter
                    color: theme.fg.secondary
                }
            }
        }

        ListView {
            id: list

            visible: !root._grid && !root._homeRoot

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: root._model

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            delegate: PlaceRow {
                required property int index
                required property var model

                card: root
                width: ListView.view.width

                // the folder trees have folders (Videos, Music, or a folder opened from Home)
                folder: model.kind === "homeFolder"
                        || ((root._folderTree || root._current?.kind === "folder") && model.isVideo === false)
                title: model.title ?? model.name ?? model.url ?? ""
                cover: String(model.thumbnail ?? model.small_cover ?? model.cover ?? "")
                glyph: model.kind === "homePlaylist" ? VLCIcons.playlists
                     : model.kind === "homeArtist" ? VLCIcons.profile_new
                     : root._rowIcon
                progress: (model.isVideo !== false) ? (model.progress ?? 0) : 0
                watched: (model.isVideo !== false) && (model.playcount ?? 0) > 0

                onClicked: root.activate({
                    id: model.id ?? root._homeList[model.idx]?.id,
                    title: title,
                    kind: model.kind,
                    isVideo: model.isVideo
                })

                CardDragHandler {
                    card: root
                    index: parent.index
                }
            }
        }

        // the same items as tiles (the view button): two columns, the cover and the title under it
        GridView {
            id: grid

            readonly property bool _wide: root.section === "videos" || root.section === "home"
                                          || root.section === "recent"

            visible: root._grid && !root._homeRoot

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

                readonly property bool isFolder: model.kind === "homeFolder"
                    || ((root._folderTree || root._current?.kind === "folder") && model.isVideo === false)
                readonly property string title: model.title ?? model.name ?? model.url ?? ""
                readonly property string cover: String(model.thumbnail ?? model.small_cover ?? model.cover ?? "")

                width: GridView.view.cellWidth
                height: GridView.view.cellHeight

                padding: VLCStyle.margin_xxsmall

                Accessible.role: Accessible.Button
                Accessible.name: title

                onClicked: root.activate({
                    id: model.id ?? root._homeList[model.idx]?.id,
                    title: title,
                    kind: model.kind,
                    isVideo: model.isVideo
                })

                CardDragHandler {
                    card: root
                    index: tile.index
                }

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

                        Image {
                            id: tileImage

                            anchors.fill: parent

                            visible: !tile.isFolder && tile.cover !== ""
                            source: (!tile.isFolder && tile.cover !== "") ? tile.cover : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            clip: true
                            sourceSize.width: VLCStyle.dp(240, VLCStyle.scale)
                            sourceSize.height: VLCStyle.dp(240, VLCStyle.scale)
                        }

                        // rounds the image corners with the colour around the tile
                        Rectangle {
                            readonly property real ring: Math.ceil(parent.radius / 2)

                            visible: tileImage.visible
                            anchors.fill: parent
                            anchors.margins: -ring
                            radius: parent.radius + ring
                            color: "transparent"
                            border.width: ring
                            border.color: tile.hovered ? root._colors.raised : root.color
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

    // A row of the card: the cover (or a glyph, a folder for a folder) and the name. A video
    // that was started has an orange line under its cover, a watched one a dimmer name (Figma).
    // NOTE: an inline component does not see the ids of this file, so `card` is the card.
    component PlaceRow: T.ItemDelegate {
        id: placeRow

        required property Item card

        property string title
        property string cover
        property string glyph
        property bool folder: false
        property real progress: 0
        property bool watched: false

        // the grid view on Home: the cover above the name
        property bool tile: false

        height: tile ? Math.round((width - padding * 2) * 9 / 16) + padding * 2 + VLCStyle.dp(36, VLCStyle.scale)
                     : VLCStyle.dp(42, VLCStyle.scale)
        padding: tile ? VLCStyle.margin_xxsmall : 0

        Accessible.role: Accessible.Button
        Accessible.name: title

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: placeRow.hovered ? placeRow.card._colors.raised : "transparent"
        }

        contentItem: GridLayout {
            columns: placeRow.tile ? 1 : 2
            columnSpacing: VLCStyle.dp(10, VLCStyle.scale)
            rowSpacing: VLCStyle.margin_xxsmall

            Rectangle {
                Layout.fillWidth: placeRow.tile
                Layout.fillHeight: placeRow.tile
                Layout.preferredWidth: placeRow.tile ? -1 : VLCStyle.dp(32, VLCStyle.scale)
                Layout.preferredHeight: placeRow.tile ? -1 : VLCStyle.dp(32, VLCStyle.scale)

                radius: placeRow.tile ? VLCStyle.dp(6, VLCStyle.scale) : 0
                color: placeRow.tile ? placeRow.card._colors.raised : "transparent"

                // NOTE: a plain Image: in the card, ImageExt drew the music covers only once the
                //       row was hovered (user report); its rounding is redone with a ring below
                Image {
                    id: coverImage

                    anchors.fill: parent

                    visible: !placeRow.folder && placeRow.cover !== ""
                    source: (!placeRow.folder && placeRow.cover !== "") ? placeRow.cover : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    clip: true
                    sourceSize.width: VLCStyle.dp(placeRow.tile ? 240 : 64, VLCStyle.scale)
                    sourceSize.height: VLCStyle.dp(placeRow.tile ? 240 : 64, VLCStyle.scale)
                }

                // rounds the tile's image corners with the colour around it
                Rectangle {
                    readonly property real ring: Math.ceil(parent.radius / 2)

                    visible: placeRow.tile && coverImage.visible
                    anchors.fill: parent
                    anchors.margins: -ring
                    radius: parent.radius + ring
                    color: "transparent"
                    border.width: ring
                    border.color: placeRow.hovered ? placeRow.card._colors.raised : placeRow.card.color
                }

                Widgets.IconLabel {
                    anchors.centerIn: parent

                    visible: placeRow.folder || placeRow.cover === ""
                    text: placeRow.folder ? VLCIcons.ic_fluent_folder_open_24_regular
                                          : (placeRow.glyph !== "" ? placeRow.glyph : placeRow.card._rowIcon)
                    font.pixelSize: placeRow.tile ? VLCStyle.icon_large : VLCStyle.icon_banner
                    color: placeRow.card.colorContext.fg.secondary
                }

                // how far it was watched (a watched one shows the whole line)
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom

                    visible: placeRow.progress > 0 || placeRow.watched
                    width: (parent.width - VLCStyle.dp(4, VLCStyle.scale))
                           * (placeRow.watched && placeRow.progress <= 0 ? 1 : Math.min(1, placeRow.progress))
                    height: VLCStyle.dp(3, VLCStyle.scale)
                    color: placeRow.card.colorContext.accent
                }
            }

            Widgets.LabelExt {
                Layout.fillWidth: true

                text: placeRow.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                color: placeRow.watched ? placeRow.card._colors.hint : placeRow.card._colors.title
            }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }

    // A Home section: its name and a chevron that opens the whole list, then up to three rows
    // starts the card's drag (its rows and tiles are buttons: the handler takes the press over)
    component CardDragHandler: DragHandler {
        required property Item card
        required property int index

        enabled: card._canDrag
        target: null

        acceptedDevices: PointerDevice.AllDevices & ~(PointerDevice.TouchScreen)
        grabPermissions: PointerHandler.CanTakeOverFromItems
                         | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                         | PointerHandler.ApprovesTakeOverByAnything

        onActiveChanged: card._drag(index, active)
    }

    component HomeSection: Column {
        id: homeSection

        // the section's items, one a row or two tiles a row (the grid view)
        default property alias items: itemsFlow.data

        required property Item card
        required property string title
        required property string kind
        property bool shown: true

        visible: shown
        width: parent?.width ?? 0

        T.ItemDelegate {
            id: sectionHeader

            width: parent.width
            height: VLCStyle.dp(40, VLCStyle.scale)
            padding: 0

            Accessible.role: Accessible.Button
            Accessible.name: homeSection.title

            onClicked: homeSection.card.open({ title: homeSection.title, kind: homeSection.kind })

            contentItem: RowLayout {
                Widgets.LabelExt {
                    Layout.fillWidth: true

                    text: homeSection.title
                    font.pixelSize: VLCStyle.fontSize_large
                    color: homeSection.card.colorContext.fg.primary
                }

                Widgets.IconLabel {
                    text: VLCIcons.ic_fluent_chevron_right_24
                    font.pixelSize: VLCStyle.icon_normal
                    color: sectionHeader.hovered ? homeSection.card.colorContext.fg.primary
                                                 : homeSection.card.colorContext.fg.secondary
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }

        Flow {
            id: itemsFlow

            width: parent.width
        }
    }
}
