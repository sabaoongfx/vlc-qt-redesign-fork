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
import VLC.Style
import VLC.Util

// redesign: the Figma address line, "Videos > Shows > The Wand". Every name but the last one is
// clickable and tells which place it leads to. When the names do not fit, the first ones fold into
// a "..." (Figma "... > The Wand > S01") that leads one level above the first name shown, and the
// last name ends in "..." if it is still too long.
Item {
    id: root

    // [{ text, depth }, ...]; depth is given back by crumbClicked
    property var names: []

    property int pixelSize: VLCStyle.fontSize_large

    // The library card style (Figma sidebar): every name regular in one colour, the separators a
    // small dim triangle. Off: the last name semibold and brighter, an icon separator.
    property bool plain: false
    property color plainColor: theme.fg.secondary
    property color separatorColor: theme.fg.secondary

    signal crumbClicked(int depth)

    readonly property int _spacing: VLCStyle.margin_xxxsmall

    // a name's box: its text and the hover padding
    function _nameWidth(text, last) {
        const metrics = (last && !plain) ? boldMetrics : regularMetrics
        return Math.ceil(metrics.advanceWidth(text)) + VLCStyle.margin_xsmall
    }

    readonly property real _separatorWidth: (plain ? plainSeparator.implicitWidth : iconSeparator.implicitWidth)
                                            + _spacing * 2

    // the names shown, from the end back as long as they fit, with the "..." in front of them
    readonly property var _shown: {
        const all = names ?? []
        const count = all.length
        if (count === 0)
            return []

        const available = width
        let total = _nameWidth(all[count - 1].text, true)
        let first = count - 1

        while (first > 0) {
            const next = total + _separatorWidth + _nameWidth(all[first - 1].text, false)
            // keep room for the "..." while names are still left out
            const fold = (first - 1 > 0) ? _separatorWidth + _nameWidth("…", false) : 0
            if (next + fold > available)
                break
            total = next
            first--
        }

        const shown = all.slice(first).map((name, i) => ({ text: name.text, depth: name.depth,
                                                           last: first + i === count - 1 }))
        if (first > 0)
            shown.unshift({ text: "…", depth: all[first - 1].depth, last: false })
        return shown
    }

    implicitWidth: 0 // takes the width it is given, never pushes what follows it in the row
    implicitHeight: probe.implicitHeight + VLCStyle.margin_xxsmall * 2

    Layout.minimumWidth: 0

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    FontMetrics {
        id: regularMetrics
        font.family: VLCStyle.fontFamily
        font.pixelSize: root.pixelSize
    }

    FontMetrics {
        id: boldMetrics
        font.family: VLCStyle.fontFamily
        font.pixelSize: root.pixelSize
        font.weight: Font.DemiBold
    }

    // measured only, never shown
    LabelExt {
        id: probe
        visible: false
        text: "Ag"
        font.pixelSize: root.pixelSize
    }

    LabelExt {
        id: plainSeparator
        visible: false
        text: "▶"
        font.pixelSize: VLCStyle.dp(8, VLCStyle.scale)
    }

    IconLabel {
        id: iconSeparator
        visible: false
        text: VLCIcons.breadcrumb_sep
        font.pixelSize: VLCStyle.icon_small
    }

    Row {
        id: row

        height: parent.height
        spacing: root._spacing
        clip: true
        width: parent.width

        Repeater {
            model: root._shown

            delegate: Row {
                id: crumb

                required property int index
                required property var modelData

                readonly property bool isLast: modelData.last

                height: row.height
                spacing: root._spacing

                Rectangle {
                    // the last name gets what is left of the row and elides in it
                    width: crumb.isLast ? Math.max(0, Math.min(root._nameWidth(crumb.modelData.text, true),
                                                               row.width - crumb.x))
                                        : root._nameWidth(crumb.modelData.text, false)
                    height: parent.height

                    radius: VLCStyle.button_radius
                    color: (!crumb.isLast && hover.hovered) ? Qt.alpha(theme.fg.primary, 0.08) : "transparent"

                    Accessible.role: Accessible.Button
                    Accessible.name: crumb.modelData.text === "…" ? qsTr("Previous folders") : crumb.modelData.text
                    Accessible.onPressAction: if (!crumb.isLast) root.crumbClicked(crumb.modelData.depth)

                    LabelExt {
                        anchors.fill: parent
                        anchors.leftMargin: VLCStyle.margin_xxsmall
                        anchors.rightMargin: VLCStyle.margin_xxsmall

                        text: crumb.modelData.text
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: root.pixelSize
                        font.weight: (crumb.isLast && !root.plain) ? Font.DemiBold : Font.Normal
                        color: root.plain ? root.plainColor : (crumb.isLast ? theme.fg.primary : theme.fg.secondary)
                    }

                    HoverHandler {
                        id: hover

                        enabled: !crumb.isLast
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: !crumb.isLast
                        onTapped: root.crumbClicked(crumb.modelData.depth)
                    }
                }

                LabelExt {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !crumb.isLast && root.plain
                    text: "▶"
                    font.pixelSize: VLCStyle.dp(8, VLCStyle.scale)
                    color: root.separatorColor
                }

                IconLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !crumb.isLast && !root.plain
                    text: VLCIcons.breadcrumb_sep
                    font.pixelSize: VLCStyle.icon_small
                    color: Qt.alpha(theme.fg.secondary, 0.6)
                }
            }
        }
    }
}
