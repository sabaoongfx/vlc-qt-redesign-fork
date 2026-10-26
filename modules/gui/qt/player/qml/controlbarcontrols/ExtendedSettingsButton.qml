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

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

// redesign: the prototype's player settings button opens the side panel (on its Video tab, where
// the Figma effect cards are) instead of the Effects and Filters window, which stays reachable
// from the panel's Open Advanced Settings
Widgets.IconToolButton {
    id: extdSettingsBtn

    readonly property var _parentItem: {
        if ((typeof rootPlayer !== 'undefined') && (rootPlayer !== null))
            return rootPlayer
        else
            return g_mainDisplay
    }

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)

    text: VLCIcons.effect_filter
    description: qsTr("Extended settings")
    AccessibleCompat.id: "extendedSettingsButton"

    onClicked: {
        if (!panelLoader.item)
            return
        if (panelLoader.item.visible)
            panelLoader.item.close()
        else
            panelLoader.item.openTab(1)
    }

    // accent while its panel is open (Figma active state)
    color: (panelLoader.item && panelLoader.item.visible) ? colorContext.accent : colorContext.fg.primary

    Loader {
        id: panelLoader

        active: !extdSettingsBtn.paintOnly

        sourceComponent: TracksMenu {
            id: panel

            parent: extdSettingsBtn._parentItem

            x: parent.width - width - VLCStyle.dp(10, VLCStyle.scale)
            y: _topBarHeight
            z: 1

            focus: true

            colorContext.palette: extdSettingsBtn.colorContext.palette

            onOpened: {
                extdSettingsBtn.requestLockUnlockAutoHide(true)
                extdSettingsBtn.menuOpened(panel)
            }

            onClosed: {
                extdSettingsBtn.requestLockUnlockAutoHide(false)
                extdSettingsBtn.forceActiveFocus()
                extdSettingsBtn.menuOpened(null)
            }
        }
    }

    function forceUnlock() {
        if (panelLoader.item)
            panelLoader.item.close()
    }
}
