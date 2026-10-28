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

// Figma "New playlist": a modal card with the playlist name and a dashed box to drop or choose
// the files of the playlist. (The Figma thumbnail square is not here: playlists have no custom
// cover in the library.)
T.Popup {
    id: root

    // Emitted by Save: the name and the files as urls (can be empty)
    signal saved(string name, var urls)

    property var files: []

    readonly property var _colors: VLCStyle.figmaColors(theme.palette.isDark)

    parent: T.Overlay.overlay
    anchors.centerIn: T.Overlay.overlay

    width: Math.min(VLCStyle.dp(728, VLCStyle.scale), (parent?.width ?? 0) - VLCStyle.margin_large * 2)
    height: Math.min(VLCStyle.dp(590, VLCStyle.scale), (parent?.height ?? 0) - VLCStyle.margin_large * 2)

    modal: true
    focus: true
    padding: 0
    closePolicy: T.Popup.CloseOnEscape

    onOpened: nameField.forceActiveFocus()

    onClosed: {
        nameField.text = ""
        files = []
    }

    function addFiles(urls) {
        // no file twice
        files = [...files, ...urls.filter(url => !files.includes(url))]
    }

    function chooseFiles() {
        addFiles(DialogsProvider.getOpenFileUrls(qsTr("Select Files")))
    }

    function save() {
        if (nameField.text.trim() === "")
            return

        saved(nameField.text.trim(), files)
        close()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    T.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    background: Rectangle {
        radius: VLCStyle.dp(12, VLCStyle.scale)
        color: root._colors.previewEdge
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Title band
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(50, VLCStyle.scale)

            color: root._colors.bar
            topLeftRadius: VLCStyle.dp(12, VLCStyle.scale)
            topRightRadius: VLCStyle.dp(12, VLCStyle.scale)

            Widgets.LabelExt {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter

                text: qsTr("New Playlist")
                font.pixelSize: VLCStyle.fontSize_normal
                color: root._colors.label
            }

            Widgets.IconToolButton {
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(12, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter

                text: VLCIcons.close
                description: qsTr("Close")
                font.pixelSize: VLCStyle.icon_banner
                width: VLCStyle.bannerButton_width
                height: VLCStyle.bannerButton_height

                onClicked: root.close()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.topMargin: VLCStyle.dp(24, VLCStyle.scale)

            spacing: VLCStyle.margin_xsmall

            Widgets.LabelExt {
                text: qsTr("Playlist Details")
                font.pixelSize: VLCStyle.fontSize_large
                color: theme.fg.primary
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

                    Accessible.name: qsTr("Playlist name")

                    // typed letters must not run the global shortcuts
                    onActiveFocusChanged: MainCtx.useGlobalShortcuts = !activeFocus

                    onAccepted: root.save()

                    Text {
                        anchors.fill: parent

                        visible: nameField.text.length === 0
                        text: qsTr("e.g., Favorite Videos")
                        color: root._colors.tabIcon
                        font: nameField.font
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Widgets.LabelExt {
                Layout.topMargin: VLCStyle.margin_normal

                text: qsTr("Select Files")
                font.pixelSize: VLCStyle.fontSize_large
                color: theme.fg.primary
            }

            Widgets.LabelExt {
                text: qsTr("These files will be added to the playlist.")
                font.pixelSize: VLCStyle.fontSize_normal
                color: root._colors.hint
            }

            // The drop box: drop files on it or click it to choose them
            Rectangle {
                id: dropBox

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: VLCStyle.margin_xsmall
                Layout.minimumHeight: VLCStyle.dp(80, VLCStyle.scale)

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root._colors.field

                // Figma draws it dashed; a plain line, as QtQuick has no dashed border without Shapes
                // (not in the Windows Qt build)
                border.width: VLCStyle.border
                border.color: dropArea.containsDrag ? theme.accent : root._colors.line

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Select files")
                Accessible.onPressAction: root.chooseFiles()

                DropArea {
                    id: dropArea

                    anchors.fill: parent

                    keys: ["text/uri-list"]

                    onDropped: (drop) => {
                        if (drop.hasUrls)
                            root.addFiles(drop.urls.map(url => url.toString()))
                    }
                }

                TapHandler {
                    onTapped: root.chooseFiles()
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                // nothing chosen yet: the hint and a + button
                ColumnLayout {
                    anchors.centerIn: parent

                    visible: root.files.length === 0

                    spacing: VLCStyle.margin_small

                    Widgets.LabelExt {
                        Layout.alignment: Qt.AlignHCenter

                        text: qsTr("Drag files into the box or click here to select files.")
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: root._colors.hint
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: VLCStyle.dp(84, VLCStyle.scale)
                        Layout.preferredHeight: VLCStyle.dp(30, VLCStyle.scale)

                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: root._colors.previewCard

                        Widgets.IconLabel {
                            anchors.centerIn: parent

                            text: VLCIcons.add
                            font.pixelSize: VLCStyle.icon_banner
                            color: root._colors.label
                        }
                    }
                }

                // the chosen files
                ListView {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.margin_xsmall

                    visible: root.files.length > 0
                    clip: true

                    model: root.files

                    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                    delegate: T.ItemDelegate {
                        required property int index
                        required property string modelData

                        width: ListView.view.width
                        height: VLCStyle.dp(30, VLCStyle.scale)
                        padding: 0

                        contentItem: RowLayout {
                            Widgets.LabelExt {
                                Layout.fillWidth: true
                                Layout.leftMargin: VLCStyle.margin_xsmall

                                // the file name of the url
                                text: decodeURIComponent(modelData.split("/").pop())
                                textFormat: Text.PlainText
                                elide: Text.ElideMiddle
                                font.pixelSize: VLCStyle.fontSize_normal
                                color: theme.fg.primary
                            }

                            Widgets.IconToolButton {
                                text: VLCIcons.close
                                description: qsTr("Remove")
                                font.pixelSize: VLCStyle.icon_normal
                                Layout.preferredWidth: VLCStyle.dp(28, VLCStyle.scale)
                                Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)

                                onClicked: root.files = root.files.filter((_, i) => i !== index)
                            }
                        }
                    }
                }
            }
        }

        // Cancel and Save
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.topMargin: VLCStyle.margin_normal

            Rectangle {
                Layout.preferredWidth: VLCStyle.dp(100, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root._colors.previewCard

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Cancel")
                Accessible.onPressAction: root.close()

                Widgets.LabelExt {
                    anchors.centerIn: parent

                    text: qsTr("Cancel")
                    font.pixelSize: VLCStyle.fontSize_normal
                    font.weight: Font.DemiBold
                    color: root._colors.previewText
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.close()
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                id: saveButton

                // a name is enough, the files can be added to the playlist later
                readonly property bool active: nameField.text.trim() !== ""

                Layout.preferredWidth: VLCStyle.dp(100, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: active ? theme.accent : root._colors.previewCard
                opacity: active ? 1.0 : 0.5

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Save")
                Accessible.onPressAction: root.save()

                Widgets.LabelExt {
                    anchors.centerIn: parent

                    text: qsTr("Save")
                    font.pixelSize: VLCStyle.fontSize_normal
                    font.weight: Font.DemiBold
                    color: saveButton.active ? "#1A0E02" : root._colors.hint
                }

                HoverHandler {
                    enabled: saveButton.active
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: saveButton.active
                    onTapped: root.save()
                }
            }
        }
    }
}
