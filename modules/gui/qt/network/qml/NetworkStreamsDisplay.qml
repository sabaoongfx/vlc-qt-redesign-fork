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
// saved, and a field to add more. A saved stream plays with a click.
Widgets.PageExt {
    id: root

    title: qsTr("Network")

    hasGridListMode: false
    isSearchable: urlListDisplay.active

    // Asks the parent to show the device browser (local network, UPnP, SMB...)
    signal showBrowse(int reason)

    // the buttons take their colours from here: without a context at the root of the page they had no
    // palette and were not drawn at all (CI screenshot lib-browse, 2026-10-28)
    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    function setCurrentItemFocus(reason) {
        addButton.forceActiveFocus(reason)
    }

    // Saves the addresses the dialog returned
    function addAddresses(urls) {
        if (urlListDisplay.status === Loader.Ready)
            urls.forEach(url => urlListDisplay.item.model.add(url))
        else
            MainPlaylistController.append(urls, false)
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        ColumnLayout {
            anchors.fill: parent

            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.margin_normal
                Layout.bottomMargin: VLCStyle.margin_normal
                Layout.leftMargin: root.leftPadding
                Layout.rightMargin: root.rightPadding

                spacing: VLCStyle.margin_xsmall

                Widgets.DialogButton {
                    id: addButton

                    focus: true
                    activeFocusOnTab: true

                    text: qsTr("Add stream")
                    primary: true

                    enabled: dialogLoader.status === Loader.Ready

                    onClicked: dialogLoader.item.open()
                }

                Item {
                    Layout.fillWidth: true
                }

                Widgets.DialogButton {
                    text: qsTr("Browse devices")

                    activeFocusOnTab: true

                    onClicked: root.showBrowse(Qt.MouseFocusReason)
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: urlListDisplay

                    anchors.fill: parent

                    active: MainCtx.mediaLibraryAvailable
                    source: "qrc:///qt/qml/VLC/MediaLibrary/UrlListDisplay.qml"

                    onLoaded: {
                        item.leftPadding = Qt.binding(() => root.leftPadding)
                        item.rightPadding = Qt.binding(() => root.rightPadding)

                        item.displayMarginEnd = Qt.binding(() => root.displayMarginEnd)

                        item.fadingEdge.enableBeginningFade = Qt.binding(() => root.enableBeginningFade)
                        item.fadingEdge.enableEndFade = Qt.binding(() => root.enableEndFade)

                        item.Navigation.upItem = addButton
                        item.Navigation.parentItem = root

                        item.searchPattern = Qt.binding(() => root.search.pattern)
                    }
                }

                // the list hides itself while it has no stream
                Widgets.LabelExt {
                    anchors.centerIn: parent

                    visible: !(urlListDisplay.item?.visible ?? false)

                    text: qsTr("No saved streams yet\nUse Add stream to save a network address")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: VLCStyle.fontSize_large
                    color: VLCStyle.figmaColors(theme.palette?.isDark ?? true).hint
                }
            }
        }
    }

    // The Figma "Open network stream" dialog (in the media library module, so loaded by url)
    Loader {
        id: dialogLoader

        source: "qrc:///qt/qml/VLC/MediaLibrary/NetworkStreamDialog.qml"

        onLoaded: item.saved.connect(root.addAddresses)
    }
}
