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
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls
import VLC.Playlist
import VLC.Util

// redesign: the library's floating mini player card (Figma "Miniplayer"): a preview (the PIP
// video, or the cover for audio), a progress field, the title, the folder and artist, and a
// play queue button. It replaces the full-width mini player bar in the library.
T.Control {
    id: root

    // the PIP video is placed over this item by MainDisplay
    readonly property alias previewArea: preview

    // true when the PIP video is shown over the preview
    property bool hasVideo: false

    // the queue list above the card is open (the queue button is drawn in the accent colour)
    property bool queueOpen: false

    signal togglePlayqueue()

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    readonly property string folderName: {
        const url = Player.url ? Player.url.toString() : ""
        if (!url.startsWith("file://"))
            return ""
        const parts = decodeURIComponent(url.replace(/\/+$/, "")).split("/")
        return parts.length > 1 ? parts[parts.length - 2] : ""
    }

    width: VLCStyle.dp(390, VLCStyle.scale)
    padding: VLCStyle.margin_xsmall

    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Mini player")

    // Figma: the card is the secondary window colour with no border, only its shadow
    background: Rectangle {
        radius: VLCStyle.dp(12, VLCStyle.scale)
        color: theme.bg.secondary

        Widgets.DefaultShadow { }
    }

    // Figma: preview, 5px, progress field, then the title and the folder / artist row
    contentItem: Column {
        spacing: 0

        Rectangle {
            id: preview

            width: parent.width
            height: Math.round(width * 9 / 16)
            radius: VLCStyle.dp(8, VLCStyle.scale)
            color: VLCStyle.figmaColors(theme.palette.isDark).preview
            // a 2px dark frame around the picture (MainDisplay insets the PIP video by it)
            border.width: VLCStyle.dp(2, VLCStyle.scale)
            border.color: VLCStyle.figmaColors(theme.palette.isDark).frame
            clip: true

            // audio (or video without the PIP surface): the cover, a play/pause button on hover
            Widgets.ImageExt {
                anchors.fill: parent
                visible: !root.hasVideo
                radius: parent.radius
                fillMode: Image.PreserveAspectCrop
                source: (Player.artwork && Player.artwork.toString() !== "") ? VLCAccessImage.uri(Player.artwork)
                                                                               : VLCStyle.noArtAlbumCover
            }

            HoverHandler {
                id: previewHover
            }

            TapHandler {
                enabled: !root.hasVideo
                onDoubleTapped: MainCtx.playerView = true
            }

            // redesign: the Figma Miniplayer close button, it stops the playback (the card goes away)
            Widgets.IconToolButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: VLCStyle.margin_xsmall

                z: 1
                visible: !root.hasVideo && (cardHover.hovered || hovered)

                width: VLCStyle.bannerButton_width
                height: VLCStyle.bannerButton_height
                font.pixelSize: VLCStyle.icon_normal

                text: VLCIcons.close
                description: qsTr("Close")

                backgroundColor: Qt.alpha(VLCStyle.figmaColors(theme.palette.isDark).frame, 0.7)
                radius: VLCStyle.dp(6, VLCStyle.scale)

                onClicked: MainPlaylistController.stop()
            }

            Widgets.IconButton {
                anchors.centerIn: parent
                visible: !root.hasVideo && (previewHover.hovered || hovered)
                font.pixelSize: VLCStyle.icon_large
                description: qsTr("play/pause")
                text: (Player.playingState !== Player.PLAYING_STATE_PAUSED
                       && Player.playingState !== Player.PLAYING_STATE_STOPPED)
                      ? VLCIcons.pause_filled
                      : VLCIcons.play_filled
                onClicked: MainPlaylistController.togglePlayPause()
            }
        }

        Item {
            width: parent.width
            height: VLCStyle.dp(5, VLCStyle.scale)
        }

        SliderBar {
            width: parent.width
            barHeight: VLCStyle.dp(16, VLCStyle.scale)
            fieldStyle: true
            showHandle: false

            Accessible.name: qsTr("Progress")

            enabled: Player.playingState === Player.PLAYING_STATE_PLAYING
                     || Player.playingState === Player.PLAYING_STATE_PAUSED
        }

        T.Label {
            width: parent.width
            topPadding: VLCStyle.dp(22, VLCStyle.scale)
            leftPadding: VLCStyle.margin_xsmall
            rightPadding: VLCStyle.margin_xsmall

            text: Player.title !== "" ? Player.title : Player.name
            color: theme.fg.secondary
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.dp(17, VLCStyle.scale)
            elide: Text.ElideRight

            TapHandler {
                onTapped: MainCtx.playerView = true
            }
        }

        Item {
            width: parent.width
            height: VLCStyle.dp(48, VLCStyle.scale)

            // the folder and the artist stop before the queue button, long names end in "..."
            // (a long artist ran under the button)
            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
                anchors.right: queueButton.left
                anchors.rightMargin: VLCStyle.margin_xsmall
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: VLCStyle.dp(6, VLCStyle.scale) // Figma: 27px above the card edge
                spacing: VLCStyle.margin_xsmall

                Widgets.IconLabel {
                    visible: root.folderName !== ""
                    text: VLCIcons.ic_fluent_folder_open_24_regular
                    font.pixelSize: VLCStyle.dp(22, VLCStyle.scale)
                    color: theme.fg.secondary
                }

                T.Label {
                    // the folder keeps its name first, up to half the row
                    Layout.maximumWidth: Math.min(implicitWidth, parent.width / 2)
                    Layout.minimumWidth: 0

                    visible: root.folderName !== ""
                    text: root.folderName
                    color: theme.fg.secondary
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_xlarge
                    elide: Text.ElideRight
                }

                Widgets.IconLabel {
                    Layout.leftMargin: root.folderName !== "" ? VLCStyle.margin_normal - VLCStyle.margin_xsmall : 0

                    visible: Player.artist !== ""
                    text: VLCIcons.topbar_music
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.fg.secondary
                }

                T.Label {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    visible: Player.artist !== ""
                    text: Player.artist
                    color: theme.fg.secondary
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_xlarge
                    elide: Text.ElideRight
                    // set, so a right-to-left name (Arabic) stays next to its icon
                    horizontalAlignment: Text.AlignLeft
                }

                Item {
                    // keeps the row on the left when the artist is empty
                    Layout.fillWidth: Player.artist === ""
                }
            }

            Widgets.IconToolButton {
                id: queueButton

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: VLCStyle.dp(6, VLCStyle.scale)

                text: VLCIcons.playlist
                description: qsTr("Play Queue")
                color: root.queueOpen ? theme.accent : colorContext.fg.primary
                font.pixelSize: VLCStyle.icon_banner
                width: VLCStyle.bannerButton_width
                height: VLCStyle.bannerButton_height

                onClicked: root.togglePlayqueue()
            }
        }
    }

    // redesign: the hand cursor over everything clickable, like the prototype
    HoverHandler {
        id: cardHover

        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
    }
}
