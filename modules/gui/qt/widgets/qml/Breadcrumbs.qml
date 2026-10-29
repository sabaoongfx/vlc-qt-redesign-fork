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
// clickable and tells which place it leads to.
RowLayout {
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

    spacing: VLCStyle.margin_xxxsmall

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    Repeater {
        model: root.names

        delegate: RowLayout {
            id: crumb

            required property int index
            required property var modelData

            readonly property bool isLast: index === root.names.length - 1

            // each name takes its text width and shrinks (elides) only when the row is too narrow;
            // a maximum bound to the row's own implicit width lagged and cut names short
            // ("Mu... > Violet Ho..." in the CI artist page)
            Layout.minimumWidth: 0

            spacing: VLCStyle.margin_xxxsmall

            Rectangle {
                Layout.minimumWidth: 0
                Layout.preferredHeight: label.implicitHeight + VLCStyle.margin_xxsmall * 2
                Layout.preferredWidth: label.implicitWidth + VLCStyle.margin_xsmall

                radius: VLCStyle.button_radius
                color: (!crumb.isLast && hover.hovered) ? Qt.alpha(theme.fg.primary, 0.08) : "transparent"

                Accessible.role: Accessible.Button
                Accessible.name: crumb.modelData.text
                Accessible.onPressAction: if (!crumb.isLast) root.crumbClicked(crumb.modelData.depth)

                LabelExt {
                    id: label

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
                visible: !crumb.isLast && root.plain
                text: "\u25B6"
                font.pixelSize: VLCStyle.dp(8, VLCStyle.scale)
                color: root.separatorColor
                verticalAlignment: Text.AlignVCenter
            }

            IconLabel {
                visible: !crumb.isLast && !root.plain
                text: VLCIcons.breadcrumb_sep
                font.pixelSize: VLCStyle.icon_small
                color: Qt.alpha(theme.fg.secondary, 0.6)
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // takes the rest of the row, so the names stay on the left and whatever follows the
    // address line in the parent row is pushed to its right end
    Item {
        Layout.fillWidth: true
    }
}
