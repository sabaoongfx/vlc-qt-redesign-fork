/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

T.ToolButton {
    id: control

    // Properties

    property bool paintOnly: false

    required property string description

    // redesign: plain icons, no accent tint for the checked state
    property color color: theme.fg.primary

    property color backgroundColor: theme.bg.primary

    property real radius: VLCStyle.button_radius

    // Settings

    padding: 0

    enabled: !paintOnly

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    baselineOffset: contentItem.y + contentItem.baselineOffset

    font.pixelSize: VLCStyle.icon_toolbar
    font.family: VLCIcons.fontFamily
    font.hintingPreference: Font.PreferNoHinting // redesign: passed to the IconLabel, see there

    // Keys

    Keys.priority: Keys.AfterItem

    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    // Accessible

    Accessible.onPressAction: control.clicked()

    Accessible.name: description

    // Tooltip

    T.ToolTip.visible: (hovered || visualFocus)

    T.ToolTip.delay: VLCStyle.delayToolTipAppear

    // redesign: a hotkey shown after the name in the tooltip ("Next (N)"); the accessible name stays the name
    property string shortcut: ""

    T.ToolTip.text: shortcut ? qsTr("%1 (%2)").arg(description).arg(shortcut) : description

    // Events

    Component.onCompleted: console.assert(text !== "", "text is empty")

    // Children

    // redesign: the accent for an active button (the picker or the panel it opens is shown), darkened until it
    // reads 3:1 on the bar behind: the plain accent was 1.4:1 on the light bar of the Day theme (found by the
    // visualizer-day scene). The bar is drawn a little darker than its palette colour (translucent over the
    // stage: #ABAAAA on screen), so the palette colour is asked 3.6:1 to get over 3:1 on screen. In the dark bar
    // it stays the accent.
    readonly property color activeColor: VLCStyle.readableOn(theme.accent, barTheme.bg.primary, 3.6)

    readonly property ColorContext barContext : ColorContext {
        id: barTheme
        colorSet: ColorContext.Window
    }

    readonly property ColorContext colorContext : ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton

        enabled: control.paintOnly || control.enabled
        focused: control.visualFocus
        hovered: control.hovered
        pressed: control.down
    }

    background: Widgets.AnimatedBackground {
        implicitWidth: control.font.pixelSize
        implicitHeight: control.font.pixelSize

        enabled: theme.initialized

        color: control.backgroundColor

        // redesign: no frame around icon buttons, only the keyboard focus ring
        border.color: visualFocus ? theme.visualFocus : "transparent"

        radius: control.radius
    }

    contentItem: Widgets.IconLabel {
        text: control.text

        color: control.color

        DelayedBehavior on color {
            delayedEnabled: theme.initialized

            ColorAnimation {
                duration: VLCStyle.duration_long
            }
        }

        font: control.font
    }

    // redesign: the hand cursor over everything clickable, like the prototype
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        enabled: control.enabled
    }
}
