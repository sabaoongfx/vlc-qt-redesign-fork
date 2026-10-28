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

// Figma "Open network stream": a modal card with a Network URL box (one address per line)
// and an optional playlist name. Save keeps the addresses as saved streams; with a name the
// addresses are also put in a new playlist of that name.
T.Popup {
    id: root

    // Emitted by Save, with the addresses (one per line, empty lines dropped)
    signal saved(var urls)

    readonly property var urls: urlField.text.split("\n").map(line => line.trim()).filter(line => line !== "")

    readonly property var _colors: VLCStyle.figmaColors(theme.palette.isDark)

    parent: T.Overlay.overlay
    anchors.centerIn: T.Overlay.overlay

    width: Math.min(VLCStyle.dp(1048, VLCStyle.scale), (parent?.width ?? 0) - VLCStyle.margin_large * 2)
    height: Math.min(VLCStyle.dp(630, VLCStyle.scale), (parent?.height ?? 0) - VLCStyle.margin_large * 2)

    modal: true
    focus: true
    padding: 0
    closePolicy: T.Popup.CloseOnEscape

    onOpened: urlField.forceActiveFocus()

    onClosed: {
        urlField.text = ""
        nameField.text = ""
    }

    function save() {
        if (urls.length === 0)
            return

        if (nameField.text.trim() !== "")
            playlistModel.create(nameField.text.trim(), urls)

        saved(urls)
        close()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    MLPlaylistListModel {
        id: playlistModel

        ml: MediaLib
    }

    T.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    background: Rectangle {
        radius: VLCStyle.dp(12, VLCStyle.scale)
        color: root._colors.previewEdge
        clip: true
    }

    contentItem: ColumnLayout {
        spacing: 0

        Widgets.DialogTitleBand {
            Layout.fillWidth: true

            title: qsTr("Open Network Stream")

            onCloseRequested: root.close()
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.topMargin: VLCStyle.dp(24, VLCStyle.scale)

            spacing: VLCStyle.margin_xsmall

            Widgets.LabelExt {
                text: qsTr("Network URL")
                font.pixelSize: VLCStyle.fontSize_large
                color: theme.fg.primary
            }

            Widgets.LabelExt {
                text: qsTr("You can enter multiple links to load.")
                font.pixelSize: VLCStyle.fontSize_normal
                color: root._colors.hint
            }

            // The address box
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: VLCStyle.margin_xsmall
                Layout.minimumHeight: VLCStyle.dp(80, VLCStyle.scale)

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root._colors.field
                border.width: urlField.activeFocus ? VLCStyle.border : 0
                border.color: theme.accent

                Flickable {
                    id: urlFlick

                    anchors.fill: parent
                    anchors.margins: VLCStyle.margin_xsmall

                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    contentWidth: width
                    contentHeight: urlField.implicitHeight

                    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                    T.TextArea.flickable: T.TextArea {
                        id: urlField

                        wrapMode: TextEdit.WrapAnywhere
                        selectByMouse: true
                        color: theme.fg.primary
                        selectionColor: theme.accent
                        font.pixelSize: VLCStyle.fontSize_normal
                        font.family: VLCStyle.fontFamily
                        leftPadding: VLCStyle.margin_xsmall
                        topPadding: VLCStyle.margin_xxsmall

                        Accessible.name: qsTr("Network URL")

                        // typed letters must not run the global shortcuts
                        onActiveFocusChanged: MainCtx.useGlobalShortcuts = !activeFocus

                        Text {
                            x: urlField.leftPadding
                            y: urlField.topPadding

                            visible: urlField.text.length === 0
                            text: qsTr("e.g., https://www.example.com/stream.avi")
                            color: root._colors.tabIcon
                            font: urlField.font
                        }
                    }
                }
            }

            RowLayout {
                Layout.topMargin: VLCStyle.margin_normal

                spacing: VLCStyle.margin_xxsmall

                Widgets.LabelExt {
                    text: qsTr("Playlist Name")
                    font.pixelSize: VLCStyle.fontSize_large
                    color: theme.fg.primary
                }

                Widgets.LabelExt {
                    text: qsTr("(optional)")
                    font.pixelSize: VLCStyle.fontSize_large
                    color: root._colors.hint
                }
            }

            Widgets.LabelExt {
                text: qsTr("The playlist will be saved and displayed with this title.")
                font.pixelSize: VLCStyle.fontSize_normal
                color: root._colors.hint
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)
                Layout.topMargin: VLCStyle.margin_xsmall

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root._colors.field
                border.width: nameField.activeFocus ? VLCStyle.border : 0
                border.color: theme.accent

                T.TextField {
                    id: nameField

                    anchors.fill: parent
                    anchors.leftMargin: VLCStyle.margin_small
                    anchors.rightMargin: VLCStyle.margin_small

                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    color: theme.fg.primary
                    selectionColor: theme.accent
                    font.pixelSize: VLCStyle.fontSize_normal
                    font.family: VLCStyle.fontFamily

                    Accessible.name: qsTr("Playlist Name")

                    onActiveFocusChanged: MainCtx.useGlobalShortcuts = !activeFocus

                    onAccepted: root.save()

                    Text {
                        anchors.fill: parent

                        visible: nameField.text.length === 0
                        text: qsTr("e.g., Favorite TV Channels")
                        color: root._colors.tabIcon
                        font: nameField.font
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        // Cancel and Save
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.topMargin: VLCStyle.margin_normal

            Widgets.DialogButton {
                text: qsTr("Cancel")

                onClicked: root.close()
            }

            Item {
                Layout.fillWidth: true
            }

            Widgets.DialogButton {
                text: qsTr("Save")
                primary: true
                enabled: root.urls.length > 0

                onClicked: root.save()
            }
        }
    }
}
