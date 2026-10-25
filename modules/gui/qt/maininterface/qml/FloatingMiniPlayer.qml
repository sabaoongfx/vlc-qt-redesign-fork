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

    background: Rectangle {
        radius: VLCStyle.dp(12, VLCStyle.scale)
        color: theme.bg.primary
        border.width: VLCStyle.border
        border.color: theme.separator

        Widgets.DefaultShadow { }
    }

    contentItem: Column {
        spacing: VLCStyle.margin_xsmall

        Rectangle {
            id: preview

            width: parent.width
            height: Math.round(width * 9 / 16)
            radius: VLCStyle.dp(8, VLCStyle.scale)
            color: theme.palette.isDark ? "#2A2927" : "#2D2B29"
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

        SliderBar {
            width: parent.width
            barHeight: VLCStyle.dp(12, VLCStyle.scale)
            fieldStyle: true

            Accessible.name: qsTr("Progress")

            enabled: Player.playingState === Player.PLAYING_STATE_PLAYING
                     || Player.playingState === Player.PLAYING_STATE_PAUSED
        }

        T.Label {
            width: parent.width
            topPadding: VLCStyle.margin_xxsmall
            leftPadding: VLCStyle.margin_xxsmall

            text: Player.title !== "" ? Player.title : Player.name
            color: theme.fg.primary
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_xlarge
            elide: Text.ElideRight

            TapHandler {
                onTapped: MainCtx.playerView = true
            }
        }

        Item {
            width: parent.width
            height: VLCStyle.bannerButton_height

            Row {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.margin_xxsmall
                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.margin_normal

                Row {
                    visible: root.folderName !== ""
                    spacing: VLCStyle.margin_xsmall

                    Widgets.IconLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: VLCIcons.ic_fluent_folder_open_24_regular
                        font.pixelSize: VLCStyle.icon_normal
                        color: theme.fg.secondary
                    }

                    T.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.folderName
                        color: theme.fg.secondary
                        font.family: VLCStyle.fontFamily
                        font.pixelSize: VLCStyle.fontSize_large
                    }
                }

                Row {
                    visible: Player.artist !== ""
                    spacing: VLCStyle.margin_xsmall

                    Widgets.IconLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: VLCIcons.topbar_music
                        font.pixelSize: VLCStyle.icon_normal
                        color: theme.fg.secondary
                    }

                    T.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Player.artist
                        color: theme.fg.secondary
                        font.family: VLCStyle.fontFamily
                        font.pixelSize: VLCStyle.fontSize_large
                    }
                }
            }

            Widgets.IconToolButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                text: VLCIcons.playlist
                description: qsTr("Play Queue")
                font.pixelSize: VLCStyle.icon_banner
                width: VLCStyle.bannerButton_width
                height: VLCStyle.bannerButton_height

                onClicked: root.togglePlayqueue()
            }
        }
    }
}
