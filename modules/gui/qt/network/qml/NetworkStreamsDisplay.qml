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

import VLC.MainInterface
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Playlist

// The Network page (the video "I Redesigned VLC After 25 Years"): the network streams the user
// saved. Add Stream is in the header's "..." menu; a saved stream plays with a click.
Widgets.PageExt {
    id: root

    title: qsTr("Network")

    // History hands it to every page of the path (PageLoader)
    property int initialIndex: 0

    hasGridListMode: false
    isSearchable: urlListDisplay.active

    // the side margins of the content, the same as the page header's (PageExt), so the buttons and
    // the list line up with the header instead of touching the sidebar and the window edge
    readonly property real _leftMargin: VLCStyle.dynamicAppMargins(width) + VLCStyle.layout_left_margin
    readonly property real _rightMargin: VLCStyle.dynamicAppMargins(width) + VLCStyle.layout_right_margin

    // No saved stream: a line of text in the middle of the page
    readonly property bool _empty: !(urlListDisplay.item?.visible ?? false)

    // the header's "..." menu (user request: no orange button, no Browse devices)
    menuEntries: [{
        text: qsTr("Add Stream"),
        icon_svg: ":/menu/redesign-network.svg",
        action: () => dialogLoader.item?.open()
    }]

    // the buttons take their colours from here: without a context at the root of the page they had no
    // palette and were not drawn at all (CI screenshot lib-browse, 2026-10-28)
    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    function setCurrentItemFocus(reason) {
        urlListDisplay.forceActiveFocus(reason)
    }

    // Saves the addresses the dialog returned
    function addAddresses(urls) {
        if (urlListDisplay.status === Loader.Ready)
            urls.forEach(url => urlListDisplay.item.model.add(url))
        else
            MainPlaylistController.append(urls, false)
    }

    FocusScope {
        id: content

        anchors.fill: parent
        focus: true

        // the list starts a margin below the page header line: its column titles touched the
        // button bar above them (user report)
        Item {
            anchors.fill: parent
            anchors.topMargin: VLCStyle.margin_normal

            Loader {
                id: urlListDisplay

                anchors.fill: parent

                focus: true
                active: MainCtx.mediaLibraryAvailable
                source: "qrc:///qt/qml/VLC/MediaLibrary/UrlListDisplay.qml"

                onLoaded: {
                    item.leftPadding = Qt.binding(() => root._leftMargin + root.leftPadding)
                    item.rightPadding = Qt.binding(() => root._rightMargin + root.rightPadding)

                    item.displayMarginEnd = Qt.binding(() => root.displayMarginEnd)

                    item.fadingEdge.enableBeginningFade = Qt.binding(() => root.enableBeginningFade)
                    item.fadingEdge.enableEndFade = Qt.binding(() => root.enableEndFade)

                    item.Navigation.parentItem = root

                    item.searchPattern = Qt.binding(() => root.search.pattern)
                }
            }
        }

        // the list hides itself while it has no stream
        Widgets.LabelExt {
            id: emptyText

            anchors.centerIn: parent

            visible: root._empty

            text: qsTr("No saved streams yet\nAdd one with Add Stream in the \u22EF menu")
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: VLCStyle.fontSize_large
            color: VLCStyle.figmaColors(theme.palette?.isDark ?? true).hint
        }
    }

    // The Figma "Open network stream" dialog (in the media library module, so loaded by url)
    Loader {
        id: dialogLoader

        source: "qrc:///qt/qml/VLC/MediaLibrary/NetworkStreamDialog.qml"

        onLoaded: item.saved.connect(root.addAddresses)
    }
}
