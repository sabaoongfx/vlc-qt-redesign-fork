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

import VLC.Style
import VLC.Player

// redesign: the queue panel's Chapters tab (Figma "Queue-1"): a row per chapter, 44px high: its number in the
// accent colour, its name, its start time HH:MM:SS at the right; a click seeks to the chapter.
ListView {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }
    readonly property var figma: VLCStyle.figmaColors(theme.palette.isDark)

    function hms(seconds) {
        const pad = (n) => (n < 10 ? "0" : "") + n
        return pad(Math.floor(seconds / 3600)) + ":" + pad(Math.floor(seconds / 60) % 60) + ":" + pad(seconds % 60)
    }

    topMargin: VLCStyle.dp(12, VLCStyle.scale)
    bottomMargin: VLCStyle.margin_normal
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: Player.chapters

    T.ScrollBar.vertical: T.ScrollBar { }

    Accessible.role: Accessible.List
    Accessible.name: qsTr("Chapters")

    delegate: Item {
        id: row

        required property int index
        required property string display
        required property var time
        required property bool checked

        width: root.width
        height: VLCStyle.dp(44, VLCStyle.scale)

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
            anchors.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root.figma.raised
            visible: hover.hovered
        }

        Text {
            id: number

            x: VLCStyle.dp(24, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            text: row.index + 1
            color: theme.accent
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_large
            font.weight: Font.DemiBold

            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        Text {
            x: VLCStyle.dp(68, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: clock.x - x - VLCStyle.margin_small
            elide: Text.ElideRight
            // VLC puts a space in front of the name of a matroska chapter
            text: row.display.trim()
            // the chapter playing now is a little brighter than the rest
            color: row.checked ? theme.fg.primary : root.figma.title
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_large

            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        Text {
            id: clock

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(24, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            // to the nearest second: a chapter at 23.999 s (matroska timestamps are in 1 ms steps) is 00:00:24
            text: root.hms(Math.round(row.time.toMilliseconds() / 1000))
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
            onTapped: Player.chapters.selectChapter(row.index)
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.count === 0
        text: qsTr("This video has no chapters")
        color: root.figma.hint
        font.family: VLCStyle.fontFamily
        font.pixelSize: VLCStyle.fontSize_large

        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
}
