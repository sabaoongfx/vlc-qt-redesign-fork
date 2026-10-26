/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import VLC.Player
import VLC.Playlist
import VLC.Util

T.Control {
    id: root

    // Properties

    property bool paintOnly: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.ToolButton

        enabled: root.enabled || root.paintOnly
        focused: root.activeFocus
        hovered: root.cursorInside
        pressed: mouseArea.containsPress
    }

    property bool _keyOkPressed: false

    // Aliases

    property alias cursorInside: mouseArea.cursorInside

    // Settings

    implicitWidth: implicitBackgroundWidth + leftInset + rightInset
    implicitHeight: implicitBackgroundHeight + topInset + bottomInset

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Play/Pause")
    AccessibleCompat.id: "playButton"
    Accessible.checkable: true
    Accessible.checked: Player.playingState !== Player.PLAYING_STATE_PAUSED
                        && Player.playingState !== Player.PLAYING_STATE_STOPPED
    Accessible.onPressAction: MainPlaylistController.togglePlayPause()
    Accessible.onToggleAction: MainPlaylistController.togglePlayPause()

    // Tooltip

    T.ToolTip.visible: (hovered || visualFocus)
    T.ToolTip.delay: VLCStyle.delayToolTipAppear
    T.ToolTip.text: root.Accessible.name

    // States

    states: [
        State {
            name: "hovered"
            when: cursorInside

            PropertyChanges {
                target: hoverShadow
                opacity: 1.0
            }
        }
    ]

    transitions: Transition {
        from: ""; to: "*"
        reversible: true
        NumberAnimation {
            properties: "opacity"
            easing.type: Easing.InOutSine
            duration: VLCStyle.duration_veryShort
        }
    }

    // Keys

    Keys.onPressed: (event) => {
        if (KeyHelper.matchOk(event) ) {
            if (!event.isAutoRepeat) {
                _keyOkPressed = true
                keyHoldTimer.restart()
            }
            event.accepted = true
        }
        Navigation.defaultKeyAction(event)
    }

    Keys.onReleased: (event) => {
        if (KeyHelper.matchOk(event)) {
            if (!event.isAutoRepeat) {
                _keyOkPressed = false
                keyHoldTimer.stop()
                if (Player.playingState !== Player.PLAYING_STATE_STOPPED)
                    MainPlaylistController.togglePlayPause()
            }
            event.accepted = true
        }
    }

    // Functions

    function _pressAndHoldAction() {
        _keyOkPressed = false
        MainPlaylistController.stop()
    }

    // Children

    Timer {
        id: keyHoldTimer

        interval: mouseArea.pressAndHoldInterval
        repeat: false

        Component.onCompleted: {
            triggered.connect(_pressAndHoldAction)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent

        hoverEnabled: true

        readonly property bool cursorInside: {
            if (!containsMouse)
                return false

            // redesign: the button is a rounded rectangle, not a circle
            return true
        }

        onPressed: (mouse) => {
            if (!cursorInside) {
                mouse.accepted = false
                return
            }

            // redesign: no press effect (no shrink, no growing circle)
            root.forceActiveFocus(Qt.MouseFocusReason)
        }

        onClicked: (mouse) => {
            MainPlaylistController.togglePlayPause()
            mouse.accepted = true
        }

        onPressAndHold: (mouse) => {
            if (!cursorInside) {
                mouse.accepted = false
                return
            }

            _pressAndHoldAction()
            mouse.accepted = true
        }
    }

    contentItem: T.Label {
        text: {
            const state = Player.playingState

            if (!paintOnly
                    && state !== Player.PLAYING_STATE_PAUSED
                    && state !== Player.PLAYING_STATE_STOPPED)
                return VLCIcons.pause_filled
            else
                return VLCIcons.play_filled
        }

        // redesign: dark glyph on the accent fill (prototype --on-accent), from the palette
        color: accentTheme.fg.primary

        ColorContext {
            id: accentTheme
            colorSet: ColorContext.ButtonAccent
        }

        font.pixelSize: Math.round(parent.height * 0.82) // redesign: Figma glyph is about half the pill height

        font.family: VLCIcons.fontFamily
        font.hintingPreference: Font.PreferNoHinting
        renderType: Text.CurveRendering // redesign: smooth like the Figma glyph, see IconLabel

        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter

        Accessible.ignored: true

        DelayedBehavior on color {
            delayedEnabled: theme.initialized

            ColorAnimation {
                duration: VLCStyle.duration_veryShort
                easing.type: Easing.InOutSine
            }
        }
    }

    background: Item {
        implicitWidth: VLCStyle.dp(54, VLCStyle.scale) // redesign: Figma play pill 54x28, 6px radius
        implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

        Widgets.AnimatedBackground {
            anchors.fill: parent
            anchors.margins: -border.width * 4

            radius: VLCStyle.button_radius
            border.pixelAligned: false

            enabled: theme.initialized

            border.color: root.visualFocus ? theme.visualFocus : Qt.alpha(theme.visualFocus, 0.0)
        }

        Rectangle {
            anchors.fill: parent

            radius: VLCStyle.button_radius

            color: theme.accent

            Widgets.RoundedRectangleShadow {
                id: hoverShadow

                visible: opacity > 0
                opacity: 0

                blurRadius: VLCStyle.dp(9, VLCStyle.scale)
                yOffset: VLCStyle.dp(4, VLCStyle.scale)

                color: theme.accent.alpha(0.29)
            }
        }
    }
}
