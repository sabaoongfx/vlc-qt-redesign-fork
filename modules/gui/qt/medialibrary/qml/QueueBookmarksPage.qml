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

import VLC.Style
import VLC.Player
import VLC.MainInterface

// redesign: the queue panel's Bookmarks tab (Figma "Queue"): "N Bookmarks" with - (remove the selected one) and
// + (add one at the current time), then a row per bookmark, 44px high: its name at the left, its time
// HH:MM:SS:mmm at the right. A click on a row selects it and seeks there, a double click renames it.
// Bookmarks are kept by the media library: a file outside it has none (the page says so, + is off).
Item {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }
    readonly property var figma: VLCStyle.figmaColors(theme.palette.isDark)

    readonly property bool available: bookmarkLoader.item?.available ?? false
    readonly property int count: list.count
    property int selectedRow: -1

    function fmt(ms) {
        const pad = (n, w) => String(n).padStart(w, "0")
        return pad(Math.floor(ms / 3600000), 2) + ":" + pad(Math.floor(ms / 60000) % 60, 2) + ":"
             + pad(Math.floor(ms / 1000) % 60, 2) + ":" + pad(ms % 1000, 3)
    }

    onCountChanged: if (selectedRow >= count) selectedRow = -1

    // the model needs the media library; without it (--no-media-library) the page is only the hint
    Loader {
        id: bookmarkLoader

        active: MainCtx.mediaLibraryAvailable
        source: "qrc:///qt/qml/VLC/MediaLibrary/QueueBookmarkModel.qml"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            // Figma: the - and + strokes are centred 36px apart, the + 20px (a stroke's half width + 6) from the edge
            Layout.topMargin: VLCStyle.dp(13, VLCStyle.scale)
            Layout.leftMargin: VLCStyle.dp(24, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
            spacing: VLCStyle.dp(12, VLCStyle.scale)

            Text {
                Layout.fillWidth: true
                text: root.count === 1 ? qsTr("1 Bookmark") : qsTr("%1 Bookmarks").arg(root.count)
                elide: Text.ElideRight
                color: root.figma.hint
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_large

                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }

            HeaderButton {
                description: qsTr("Remove bookmark")
                plus: false
                enabled: root.available && root.selectedRow >= 0
                onClicked: {
                    bookmarkLoader.item.removeRow(root.selectedRow)
                    root.selectedRow = -1
                }
            }

            HeaderButton {
                description: qsTr("Add bookmark")
                plus: true
                enabled: root.available
                onClicked: bookmarkLoader.item.add()
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: VLCStyle.dp(11, VLCStyle.scale)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: bookmarkLoader.item

            T.ScrollBar.vertical: T.ScrollBar { }

            Accessible.role: Accessible.List
            Accessible.name: qsTr("Bookmarks")

            delegate: Item {
                id: row

                required property int index
                required property string name
                required property real timeMs

                property bool editing: false

                width: list.width
                height: VLCStyle.dp(44, VLCStyle.scale)

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                    anchors.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: root.selectedRow === row.index ? root.figma.dropdown : root.figma.raised
                    visible: root.selectedRow === row.index || hover.hovered
                }

                Text {
                    x: VLCStyle.dp(20, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    width: clock.x - x - VLCStyle.margin_small
                    visible: !row.editing
                    elide: Text.ElideRight
                    text: row.name
                    color: root.figma.title
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_large

                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                TextInput {
                    id: editor

                    x: VLCStyle.dp(20, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    width: clock.x - x - VLCStyle.margin_small
                    visible: row.editing
                    text: row.name
                    color: theme.fg.primary
                    selectionColor: theme.accent
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_large
                    clip: true

                    onAccepted: {
                        if (text !== "")
                            row.name = text
                        row.editing = false
                    }
                    Keys.onEscapePressed: row.editing = false
                    onActiveFocusChanged: if (!activeFocus) row.editing = false
                    onVisibleChanged: if (visible) { forceActiveFocus(); selectAll() }
                }

                Text {
                    id: clock

                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.dp(24, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.fmt(row.timeMs)
                    color: root.figma.hint
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_large

                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        root.selectedRow = row.index
                        bookmarkLoader.item.select(bookmarkLoader.item.index(row.index, 0))
                    }
                    onDoubleTapped: row.editing = true
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - VLCStyle.dp(48, VLCStyle.scale)
        visible: !root.available
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: qsTr("Bookmarks are kept by the library: add this file's folder to the library to use them.")
        color: root.figma.hint
        font.family: VLCStyle.fontFamily
        font.pixelSize: VLCStyle.fontSize_large

        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }

    // the - and + of the header: two 1.5px strokes, 14px long (Figma)
    component HeaderButton : T.AbstractButton {
        id: button

        required property bool plus
        property string description

        implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
        implicitHeight: implicitWidth
        hoverEnabled: true
        opacity: enabled ? 1 : 0.4

        Accessible.role: Accessible.Button
        Accessible.name: description

        background: null
        contentItem: Item {
            Rectangle {
                anchors.centerIn: parent
                width: VLCStyle.dp(14, VLCStyle.scale)
                height: VLCStyle.dp(1.5, VLCStyle.scale)
                radius: height / 2
                color: button.hovered ? root.figma.label : root.figma.hint
            }

            Rectangle {
                anchors.centerIn: parent
                visible: button.plus
                width: VLCStyle.dp(1.5, VLCStyle.scale)
                height: VLCStyle.dp(14, VLCStyle.scale)
                radius: width / 2
                color: button.hovered ? root.figma.label : root.figma.hint
            }
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
}
