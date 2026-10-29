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
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Dialogs
import VLC.Util

// redesign: the queue list above the floating mini player (Figma "Miniplayer" with the queue
// open): a "Queue" header, the item count and total duration, sort / clear / add, then the items
// with their durations. A click on an item plays it.
Rectangle {
    id: root

    readonly property var _colors: VLCStyle.figmaColors(theme.palette.isDark)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    implicitHeight: Math.min(VLCStyle.dp(380, VLCStyle.scale),
                             VLCStyle.dp(50, VLCStyle.scale) + VLCStyle.dp(56, VLCStyle.scale)
                             + list.contentHeight + VLCStyle.margin_small)

    radius: VLCStyle.dp(12, VLCStyle.scale)
    color: theme.bg.secondary
    clip: true

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Queue")

    PlaylistListModel {
        id: queueModel

        playlist: MainPlaylistController.playlist
    }

    Widgets.DefaultShadow { }

    ColumnLayout {
        anchors.fill: parent

        spacing: 0

        // Header band. clip only cuts to the square box, not the card's rounded corners, so the
        // band is rounded itself on top; a square strip fills its bottom corners.
        Rectangle {
            id: headerBand

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(50, VLCStyle.scale)

            radius: root.radius
            color: root._colors.bar

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                height: headerBand.radius
                color: headerBand.color
            }

            Widgets.LabelExt {
                anchors.centerIn: parent

                text: qsTr("Queue")
                font.pixelSize: VLCStyle.fontSize_large
                color: root._colors.label
            }
        }

        // Count and duration, sort, clear, add
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(56, VLCStyle.scale)
            Layout.leftMargin: VLCStyle.margin_normal
            Layout.rightMargin: VLCStyle.margin_xsmall

            spacing: VLCStyle.margin_xxsmall

            Widgets.LabelExt {
                Layout.fillWidth: true

                text: qsTr("%1 items - %2").arg(queueModel.count).arg(queueModel.duration.formatShort())
                font.pixelSize: VLCStyle.fontSize_normal
                color: root._colors.hint
            }

            Widgets.SortControl {
                font.pixelSize: VLCStyle.icon_banner
                description: qsTr("Sort")

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

                sortOrder: (MainPlaylistController.sortOrder === PlaylistController.SORT_ORDER_DESC)
                           ? Qt.DescendingOrder : Qt.AscendingOrder

                sortKey: MainPlaylistController.sortKey
            }

            // clear the queue
            Widgets.IconToolButton {
                text: VLCIcons.remove
                description: qsTr("Clear the queue")
                font.pixelSize: VLCStyle.icon_banner
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                enabled: MainPlaylistController.count > 0
                onClicked: MainPlaylistController.clear()
            }

            // add files to the queue
            Widgets.IconToolButton {
                text: VLCIcons.add
                description: qsTr("Add to the queue")
                font.pixelSize: VLCStyle.icon_banner
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                // the system file picker; the files join the queue without interrupting playback
                onClicked: DialogsProvider.simpleOpenDialog(false)
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: VLCStyle.margin_xsmall
            Layout.rightMargin: VLCStyle.margin_xsmall
            Layout.bottomMargin: VLCStyle.margin_small

            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: queueModel

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            delegate: T.ItemDelegate {
                id: row

                required property int index
                required property var model

                width: ListView.view.width
                height: VLCStyle.dp(40, VLCStyle.scale)
                padding: 0

                Accessible.role: Accessible.Button
                Accessible.name: model.title ?? ""

                onClicked: MainPlaylistController.goTo(index, true)

                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: row.hovered ? root._colors.raised : "transparent"
                }

                contentItem: RowLayout {
                    spacing: VLCStyle.margin_xsmall

                    // the drag handle of the Figma row
                    Column {
                        Layout.leftMargin: VLCStyle.margin_xsmall
                        Layout.preferredWidth: VLCStyle.dp(12, VLCStyle.scale)

                        spacing: VLCStyle.dp(3, VLCStyle.scale)

                        Repeater {
                            model: 2

                            delegate: Rectangle {
                                width: VLCStyle.dp(12, VLCStyle.scale)
                                height: VLCStyle.dp(1.5, VLCStyle.scale)
                                color: root._colors.hint
                            }
                        }
                    }

                    Widgets.LabelExt {
                        Layout.fillWidth: true

                        text: row.model.title ?? ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.pixelSize: VLCStyle.fontSize_normal
                        // the playing item is accent coloured
                        color: row.model.isCurrent ? theme.accent : theme.fg.primary
                    }

                    Widgets.LabelExt {
                        Layout.rightMargin: VLCStyle.margin_xsmall

                        text: row.model.duration ? row.model.duration.formatShort() : ""
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: root._colors.hint
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
