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
import QtQuick.Window
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQml.Models


import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Playlist
import VLC.Dialogs
import VLC.Style

T.Pane {
    id: root

    property var model: PlaylistListModel {
        playlist: MainPlaylistController.playlist
    }
    readonly property ListSelectionModel selectionModel: listView?.selectionModel ?? null

    property bool useAcrylic: true

    // redesign: Figma "Queue": the player's card has a tab bar Queue | Bookmarks | Chapters instead of the
    // "Play Queue" title (the Bookmarks and Chapters pages are given by the player as urls: the Playlist module cannot import the
    // player or the media library).
    // The library's own queue panel keeps the title (tabs: false).
    property bool tabs: false
    property real tabRadius: 0
    property int currentTab: 0 // 0 Queue, 1 Bookmarks, 2 Chapters
    property url bookmarksPage
    property url chaptersPage
    readonly property bool _queueTab: !tabs || currentTab === 0

    readonly property real minimumWidth: contentItem.Layout.minimumWidth +
                                         leftPadding +
                                         rightPadding +
                                         2 * (VLCStyle.margin_xsmall)

    readonly property ListView listView: contentItem.listView

    property alias contextMenu: contextMenu

    property alias dragItem: dragItem

    property alias isDropAcceptableFunc: listView.isDropAcceptableFunc
    property alias acceptDropFunc: listView.acceptDropFunc

    property alias view: listView

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    verticalPadding: VLCStyle.margin_normal

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Play Queue")
    AccessibleCompat.id: "playqueuePane"

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View

        focused: root.activeFocus
        hovered: root.hovered
        enabled: root.enabled
    }

    Widgets.DragItem {
        id: dragItem

        view: root.listView

        onRequestData: (indexes, resolve, reject) => {
            resolve(indexes.map((index) => {
                const item = root.model.itemAt(index)
                return {
                    "title": item.title,
                    "cover": (!!item.artwork && item.artwork.toString() !== "") ? item.artwork : VLCStyle.noArtAlbumCover,
                    "url": item.url
                }
            }))
        }

        onRequestInputItems: (indexes, data, resolve, reject) => {
            resolve(root.model.getItemsForIndexes((indexes?.length > 0) ? indexes : root.selectionModel.selectedIndexesFlat))
        }
    }

    PlaylistContextMenu {
        id: contextMenu
        model: root.model
        proxyModel: (root.contentItem?.listView?.model instanceof AbstractProxyModel) ? root.contentItem.listView.model
                                                                                        : null
        selectionModel: root.selectionModel
        controler: MainPlaylistController
        ctx: MainCtx

        onJumpToCurrentPlaying: listView.positionViewAtIndex( MainPlaylistController.currentIndex, ItemView.Center)
    }

    background: Widgets.AcrylicBackground {
        enabled: root.useAcrylic
        tintColor: theme.bg.primary
    }

    contentItem: ColumnLayout {
        spacing: VLCStyle.margin_xxsmall

        Layout.minimumWidth: Math.min(Math.max(noContentInfoColumn.implicitWidth,
                                               titleRowLayout.implicitWidth ),
                                      /* Minimum width should not be too large, we rely on elision otherwise: */
                                      Window.width / 3) + (headerColumn.Layout.leftMargin + headerColumn.Layout.rightMargin)

        readonly property ListView listView: listView

        // Figma Queue: a 50px #090909 bar over the card's width, the current tab has a 2px accent underline
        Rectangle {
            id: tabBar

            readonly property var figma: VLCStyle.figmaColors(theme.palette.isDark)

            visible: root.tabs
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? VLCStyle.dp(50, VLCStyle.scale) : 0
            Layout.leftMargin: -root.leftPadding
            Layout.rightMargin: -root.rightPadding
            radius: root.tabRadius
            color: figma.bar

            // square the bottom corners (only the top ones follow the card)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.max(0, parent.height - parent.radius)
                color: parent.color
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                QueueTab { text: qsTr("Queue"); iconName: "queue"; tabIndex: 0 }
                QueueTab { text: qsTr("Bookmarks"); iconName: "bookmark"; tabIndex: 1 }
                QueueTab { text: qsTr("Chapters"); iconName: "chapters"; tabIndex: 2 }
            }
        }

        Column {
            id: headerColumn

            visible: root._queueTab
            Layout.fillHeight: false
            Layout.fillWidth: true
            Layout.topMargin: root.tabs ? VLCStyle.dp(13, VLCStyle.scale) : 0
            Layout.leftMargin: root.tabs ? VLCStyle.dp(24, VLCStyle.scale) : VLCStyle.margin_normal
            Layout.rightMargin: root.tabs ? VLCStyle.dp(24, VLCStyle.scale) : VLCStyle.margin_normal

            spacing: VLCStyle.margin_xxxsmall

            RowLayout {
                id: titleRowLayout

                anchors.left: parent.left
                anchors.right: parent.right

                spacing: VLCStyle.margin_normal

                // with the tabs: the count and duration at the left of the buttons (Figma Bookmarks: "2 Bookmarks")
                Text {
                    Layout.fillWidth: true
                    visible: root.tabs
                    text: queueSummary.text
                    elide: Text.ElideRight
                    color: tabBar.figma.hint
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_large
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                Widgets.SubtitleLabel {
                    id: titleLabel

                    visible: !root.tabs
                    Layout.fillWidth: true

                    text: qsTr("Play Queue")
                    color: theme.fg.primary
                    font.weight: Font.DemiBold
                    font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                }

                Widgets.SortControl {
                    id: sort

                    font.pixelSize: VLCStyle.icon_banner

                    description : qsTr("Sort")

                    AccessibleCompat.id: "playqueueSort"

                    enabled: MainPlaylistController.count > 1

                    checked: MainPlaylistController.sortKey !== PlaylistController.SORT_KEY_NONE

                    popupAbove: false

                    model: MainPlaylistController.sortKeyTitleList

                    onSortSelected: key => {
                        MainPlaylistController.sortKey = key
                    }

                    onSortOrderSelected: type => {
                        if (type === Qt.AscendingOrder)
                            MainPlaylistController.sortOrder = PlaylistController.SORT_ORDER_ASC
                        else if (type === Qt.DescendingOrder)
                            MainPlaylistController.sortOrder = PlaylistController.SORT_ORDER_DESC

                        MainPlaylistController.sort()
                    }

                    sortOrder: {
                        if (MainPlaylistController.sortOrder === PlaylistController.SORT_ORDER_ASC) {
                            Qt.AscendingOrder
                        }
                        else if (MainPlaylistController.sortOrder === PlaylistController.SORT_ORDER_DESC) {
                            Qt.DescendingOrder
                        }
                    }

                    sortKey: MainPlaylistController.sortKey

                    Navigation.parentItem: root
                    Navigation.rightItem: searchBox
                    Navigation.downItem: listView
                }

                Widgets.SearchBox {
                    id: searchBox

                    enabled: MainPlaylistController.count > 1

                    toggleButton.font.pixelSize: VLCStyle.icon_banner

                    popBelow: true

                    displayRegexToggleButton: true
                    displayCaseSensitiveToggleButton: true

                    popup.width: Math.max(popup.implicitWidth, root.contentItem?.width * 0.6)
                    popup.topPadding: VLCStyle.margin_xxsmall

                    Navigation.parentItem: root
                    Navigation.leftItem: sort
                    Navigation.rightItem: addButton
                    Navigation.downItem: listView

                    Connections {
                        target: contextMenu

                        function onDiscardedFilteredOutItems() {
                            searchBox.retract()
                        }
                    }
                }

                // redesign: add files to the queue, like the mini player's Queue card (user request); the
                // system file picker, the files join the queue without interrupting playback
                Widgets.IconToolButton {
                    id: addButton

                    text: VLCIcons.add
                    description: qsTr("Add to the queue")
                    font.pixelSize: VLCStyle.icon_banner

                    AccessibleCompat.id: "playqueueAdd"

                    onClicked: DialogsProvider.simpleOpenDialog(false)

                    Navigation.parentItem: root
                    Navigation.leftItem: searchBox
                    Navigation.downItem: listView
                }
            }

            Widgets.CaptionLabel {
                id: queueSummary

                color: theme.fg.secondary
                visible: listView.count !== 0 && !root.tabs
                text: {
                    if (listView.count <= 0)
                        return "" // Not visible otherwise

                    let duration
                    const model = listView.model
                    if (model instanceof PlaylistListModel) {
                        duration = model.duration
                    } else {
                        // Proxy model, we need to use `QAbstractItemModel` api:

                        duration = []
                        for (let i = 0; i < listView.count; ++i) {
                            const itemDuration = model.data(model.index(i, 0), PlaylistListModel.DurationRole)
                            console.assert(itemDuration !== undefined && itemDuration !== null) // typeof `vlcDuration`
                            duration.push(itemDuration)
                        }
                        duration = duration[0].sum(duration)
                    }

                    return qsTr("%1 elements, %2").arg(listView.count).arg(duration.formatLong())
                }
            }
        }

        Item {
            // Spacer

            visible: root._queueTab
            implicitHeight: VLCStyle.margin_xsmall
        }

        RowLayout {
            visible: root._queueTab && listView.count !== 0

            Layout.fillHeight: false
            Layout.leftMargin: VLCStyle.margin_normal
            Layout.rightMargin: Math.max(listView.T.ScrollBar.vertical.width, VLCStyle.margin_normal)

            spacing: VLCStyle.margin_large

            Widgets.IconLabel {
                // play queue cover column
                Layout.preferredWidth: VLCStyle.icon_playlistArt

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: VLCIcons.album_cover
                font.pixelSize: VLCStyle.icon_playlistHeader

                color: theme.fg.secondary

                Accessible.role: Accessible.ColumnHeader
                Accessible.name: qsTr("Cover")
                Accessible.ignored: false
            }

            //Use Text here as we're redefining its Accessible.role
            Text {
                Layout.fillWidth: true

                elide: Text.ElideRight
                font.pixelSize: VLCStyle.fontSize_normal
                textFormat: Text.PlainText

                verticalAlignment: Text.AlignVCenter
                text: qsTr("Title")
                color: theme.fg.secondary

                Accessible.role: Accessible.ColumnHeader
                Accessible.name: text
            }

            Widgets.IconLabel {
                Layout.preferredWidth: durationMetric.width

                text: VLCIcons.time
                color: theme.fg.secondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: VLCStyle.icon_playlistHeader

                Accessible.role: Accessible.ColumnHeader
                Accessible.name: qsTr("Duration")
                Accessible.ignored: false

                TextMetrics {
                    id: durationMetric

                    font.weight: Font.DemiBold
                    font.pixelSize: VLCStyle.fontSize_normal
                    text: "00:00"
                }
            }
        }

        // the Bookmarks and Chapters tabs (pages of the player, see Player.qml)
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.tabs && root.currentTab === 1
            active: visible
            source: root.bookmarksPage
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.tabs && root.currentTab === 2
            active: visible
            source: root.chaptersPage
        }

        Widgets.ListViewExt {
            id: listView

            visible: root._queueTab
            Layout.fillWidth: true
            Layout.fillHeight: true

            selectionModel: ListSelectionModel {
                model: listView.model
            }

            focus: true

            clip: !fadingEdge.implicitClipping && (height < contentHeight)

            model: proxyModel ?? root.model

            onWidthChanged: {
                if (searchBox.expanded) {
                    if (width < searchBox.textField.width)
                        searchBox.retract()
                }
            }

            property QtSortFilterProxyModel proxyModel

            function adjustFiltering() {
                // Once text changes, we switch to the proxy model.
                // We do not switch back to the source model after that.
                if (!proxyModel) {
                    proxyModel = proxyModelComponent.createObject(listView)
                }

                if (searchBox.regexButtonToggled)
                    proxyModel.setFilterRegularExpression(searchBox.searchPattern)
                else
                    proxyModel.setFilterFixedString(searchBox.searchPattern)
            }

            Component {
                id: proxyModelComponent

                QtSortFilterProxyModel {
                    filterRole: PlaylistListModel.FilterRole

                    sourceModel: root.model

                    filterCaseSensitivity: searchBox.caseSensitiveButtonToggled ? Qt.CaseSensitive
                                                                                : Qt.CaseInsensitive
                }
            }

            fadingEdge.backgroundColor: (root.background && (root.background.color.a >= 1.0)) ? root.background.color
                                                                                              : Qt.alpha(root.background.color, 0.0)

            function mappedSelectedIndexes() : var {
                let mappedSelectedIndexes

                if (!listView.selectionModel)
                    return [] // unlikely

                const selectedIndexes = listView.selectionModel.selectedIndexesFlat
                if (listView.proxyModel && listView.model === listView.proxyModel) {
                    mappedSelectedIndexes = []
                    for (let i = 0; i < selectedIndexes.length; ++i) {
                        const mappedIndex = listView.model.mapToSource(listView.model.index(selectedIndexes[i], 0))
                        mappedSelectedIndexes.push(mappedIndex.row)
                    }
                } else {
                    mappedSelectedIndexes = selectedIndexes
                }

                return mappedSelectedIndexes
            }

            isDropAcceptableFunc: function(drop, index) {
                if (drop.source === dragItem)
                    return Helpers.itemsMovable(listView.mappedSelectedIndexes(), index)
                else if (Helpers.isValidInstanceOf(drop.source, Widgets.DragItem))
                    return true
                else if (drop.hasUrls)
                    return true
                else
                    return false
            }

            acceptDropFunc: function(index, drop) {
                const item = drop.source;

                // NOTE: Move implementation.
                if (dragItem === item) {
                    root.model.moveItemsPre(listView.mappedSelectedIndexes(), index);
                    listView.forceActiveFocus();
                // NOTE: Dropping medialibrary content into the queue.
                } else if (Helpers.isValidInstanceOf(item, Widgets.DragItem)) {
                    return item.getSelectedInputItem().then((inputItems) => {
                            if (!Helpers.isArray(inputItems) || inputItems.length === 0) {
                                console.warn("can't convert items to input items");
                                return
                            }
                            MainPlaylistController.insert(index, inputItems, false)
                        }).then(() => { listView.forceActiveFocus(); })
                // NOTE: Dropping an external item (i.e. filesystem) into the queue.
                } else if (drop.hasUrls) {
                    const urlList = [];

                    for (let url in drop.urls)
                        urlList.push(drop.urls[url]);

                    MainPlaylistController.insert(index, urlList, false);

                    // NOTE This is required otherwise backend may handle the drop as well yielding double addition.
                    drop.accept(Qt.IgnoreAction);
                    listView.forceActiveFocus();
                }

                return Promise.resolve()
            }

            property int shiftIndex: -1

            onShowContextMenu: (globalPos) => {
                contextMenu.popup(-1, globalPos)
            }

            Behavior on contentY {
                id: contentYBehavior

                enabled: false

                // NOTE: Usage of `SmoothedAnimation` is intentional here.
                SmoothedAnimation {
                    duration: VLCStyle.duration_veryLong
                    easing.type: Easing.InOutSine
                }
            }

            Component.onCompleted: {
                // WARNING: Tracking the current item and not the current index is intentional here.
                MainPlaylistController.currentItemChanged.connect(listView, () => {
                    // FIXME: Qt does not provide the `contentY` with `positionViewAtIndex()` for us
                    //        to animate. For that reason, we capture the new `contentY`, adjust
                    //        `contentY` to it is old value then enable the animation and set `contentY`
                    //        to its new value.
                    const oldContentY = listView.contentY
                    listView.positionViewAtIndex(MainPlaylistController.currentIndex, ListView.Contain)
                    const newContentY = listView.contentY
                    if (Math.abs(oldContentY - newContentY) >= Number.EPSILON) {
                        contentYBehavior.enabled = false
                        listView.contentY = oldContentY
                        contentYBehavior.enabled = true
                        listView.contentY = newContentY
                        contentYBehavior.enabled = false
                    }
                })

                searchBox.searchPatternChanged.connect(listView, listView.adjustFiltering)
                searchBox.regexButtonToggledChanged.connect(listView, listView.adjustFiltering)
            }

            Connections {
                target: listView.model

                function onRowsInserted() {
                    if (listView.currentIndex === -1)
                        listView.currentIndex = 0
                }

                function onModelReset() {
                    if (listView.currentIndex === -1 && listView.count > 0)
                        listView.currentIndex = 0
                }
            }

            delegate: PlaylistDelegate {
                id: delegate

                width: listView.contentWidth
                rightPadding: Math.max(listView.T.ScrollBar.vertical.width, VLCStyle.margin_normal)

                contextMenu: root.contextMenu

                dragItem: root.dragItem

                isDropAcceptable: listView.isDropAcceptableFunc
                acceptDrop: listView.acceptDropFunc

                onContainsDragChanged: listView.updateItemContainsDrag(this, containsDrag)

                onIsCurrentChanged: {
                    if (isCurrent)
                        listView.fadingEdge.excludeItem = delegate
                    else if (listView.fadingEdge.excludeItem === delegate)
                        listView.fadingEdge.excludeItem = null
                }

                Component.onCompleted: {
                    listView.delegateInstantiated(delegate)
                }
            }

            Keys.onDeletePressed: {
                let items

                const selectedIndexes = selectionModel.selectedIndexesFlat
                if (listView.proxyModel && listView.model === listView.proxyModel) {
                    items = []
                    for (let i = 0; i < selectedIndexes.length; ++i) {
                        const mappedIndex = listView.proxyModel.mapToSource(listView.proxyModel.index(selectedIndexes[i], 0))
                        items.push(mappedIndex.row)
                    }
                } else {
                    items = selectedIndexes
                }

                if (items.length > 0)
                    root.model.removeItems(items)
            }

            Navigation.parentItem: root
            Navigation.upItem: sort

            onActionAtIndex: (index) => {
                if (index < 0)
                    return

                MainPlaylistController.goTo(index, true)
            }

            Column {
                id: noContentInfoColumn

                anchors.centerIn: parent

                visible: false
                enabled: visible

                opacity: (listView.activeFocus) ? 1.0 : 0.4

                Binding on visible {
                    delayed: true
                    value: (listView.count === 0 && !listView.footerItem.firstItemIndicatorVisible)
                }

                Widgets.IconLabel {
                    id: label

                    anchors.horizontalCenter: parent.horizontalCenter

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    text: VLCIcons.playlist

                    color: theme.fg.primary

                    font.pixelSize: VLCStyle.dp(48, VLCStyle.scale)
                }

                T.Label {
                    anchors.topMargin: VLCStyle.margin_xlarge

                    anchors.horizontalCenter: parent.horizontalCenter

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    text: (listView.proxyModel &&
                           listView.model === listView.proxyModel &&
                           listView.count !== root.model.count) ? qsTr("No results")
                                                                : qsTr("No content yet")

                    color: label.color

                    font.pixelSize: VLCStyle.fontSize_xxlarge
                }

                T.Label {
                    anchors.topMargin: VLCStyle.margin_normal

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    text: qsTr("Drag & Drop some content here!")
                    visible: (listView.proxyModel && listView.model === listView.proxyModel) ? (listView.count === root.model.count)
                                                                                             : true

                    color: label.color

                    font.pixelSize: VLCStyle.fontSize_large
                }
            }
        }
    }

    Keys.priority: Keys.AfterItem
    Keys.forwardTo: listView
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)

    // one tab of the bar: the Figma icon (grey, its accent part dim accent while current) and the label,
    // centred in a third of the bar, with the accent underline under them while current
    component QueueTab : T.AbstractButton {
        id: tab

        required property string iconName
        required property int tabIndex
        readonly property bool current: root.currentTab === tabIndex
        readonly property var figma: VLCStyle.figmaColors(theme.palette.isDark)

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1

        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        Accessible.role: Accessible.PageTab
        Accessible.name: text

        onClicked: root.currentTab = tabIndex

        background: null

        contentItem: Item {
            Row {
                id: tabContent

                anchors.centerIn: parent
                spacing: VLCStyle.dp(8, VLCStyle.scale)

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(24, VLCStyle.scale)
                    height: width
                    sourceSize: Qt.size(width * 2, height * 2)
                    source: SVGColorImage.colorize("qrc:///queue/" + tab.iconName + ".svg")
                                         .color1(tab.current ? tab.figma.hint : tab.figma.tabIcon)
                                         .accent(tab.current ? Qt.darker(theme.accent, 1.25) : tab.figma.tabIcon)
                                         .uri()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.text
                    color: (tab.current || tab.hovered) ? tab.figma.label : tab.figma.hint
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_large
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: tabContent.width + VLCStyle.dp(26, VLCStyle.scale)
                height: VLCStyle.dp(2, VLCStyle.scale)
                visible: tab.current
                color: theme.accent
            }
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    component PlaylistToggleButton : Widgets.IconToolButton {
        id: playlistBtn

        focus: true

        font.pixelSize: VLCStyle.icon_banner
        text: VLCIcons.playlist
        description: qsTr("Play queue")

        AccessibleCompat.id: "playqueueToggle"

        width: VLCStyle.bannerButton_width
        height: VLCStyle.bannerButton_height
        //highlighted: MainCtx.playlistVisible

        property Item plListView

        DropArea {
            anchors.fill: parent

            onContainsDragChanged: {
                if (containsDrag) {
                    _timer.restart()

                    if (playlistBtn.plListView)
                        MainCtx.setCursor(Qt.DragCopyCursor)
                } else {
                    _timer.stop()

                    if (playlistBtn.plListView)
                        MainCtx.restoreCursor()
                }
            }

            onEntered: (drag) => {
                const plListView = playlistBtn.plListView
                if (plListView) {
                    console.assert(plListView.isDropAcceptableFunc)
                    console.assert(plListView.model)
                    if (plListView.isDropAcceptableFunc(drag, plListView.model.count)) {
                        drag.accept()
                    } else {
                        drag.accepted = false
                    }
                } else {
                    drag.accepted = false
                }
            }

            onDropped: (drop) => {
                const plListView = playlistBtn.plListView
                if (plListView) {
                    console.assert(plListView.acceptDropFunc)
                    plListView.acceptDropFunc(plListView.model.count, drop)
                }
            }

            Timer {
                id: _timer
                interval: VLCStyle.duration_humanMoment

                onTriggered: {
                    MainCtx.playqueuePanel.visible = true
                }
            }
        }
    }
}
