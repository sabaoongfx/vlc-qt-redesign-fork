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

    function setCurrentItemFocus(reason) {
        addressField.forceActiveFocus(reason)
    }

    // Saves the address, and plays it when asked to
    function addAddress(play) {
        const text = addressField.text.trim()

        if (text === "")
            return

        if (urlListDisplay.status === Loader.Ready) {
            if (play)
                urlListDisplay.item.model.addAndPlay(text)
            else
                urlListDisplay.item.model.add(text)
        } else if (play) {
            MainPlaylistController.append([text], true)
        }

        addressField.text = ""
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

                Widgets.TextFieldExt {
                    id: addressField

                    Layout.fillWidth: true
                    Layout.preferredHeight: VLCStyle.dp(34, VLCStyle.scale)

                    focus: true

                    placeholderText: qsTr("Paste or write a network address (http://, rtsp://, ...)")
                    selectByMouse: true

                    AccessibleCompat.id: "networkAddressField"

                    onAccepted: root.addAddress(false)

                    // typed letters must not run the global shortcuts
                    onActiveFocusChanged: MainCtx.useGlobalShortcuts = !activeFocus
                }

                Widgets.ButtonExt {
                    text: qsTr("Add stream")
                    iconTxt: VLCIcons.add

                    enabled: addressField.text.trim() !== ""

                    onClicked: root.addAddress(false)
                }

                Widgets.ButtonExt {
                    text: qsTr("Play")
                    iconTxt: VLCIcons.play

                    enabled: addressField.text.trim() !== ""

                    onClicked: root.addAddress(true)
                }

                Widgets.ButtonExt {
                    text: qsTr("Browse devices")
                    iconTxt: VLCIcons.topbar_network

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

                        item.Navigation.upItem = addressField
                        item.Navigation.parentItem = root

                        item.searchPattern = Qt.binding(() => root.search.pattern)
                    }
                }

                // the list hides itself while it has no stream
                Widgets.LabelExt {
                    anchors.centerIn: parent

                    visible: !(urlListDisplay.item?.visible ?? false)

                    text: qsTr("No saved streams yet\nAdd a network address above")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: VLCStyle.fontSize_large
                    color: VLCStyle.figmaColors(true).hint
                }
            }
        }
    }
}
