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


import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

// redesign: the audio button opens the Figma tracks picker on its Audio tab (the audio tracks and the
// output devices; user request 2026-11-13: it had its own small menu), the subtitles button the same
// picker on Subtitles. Show Preferences opens the full side panel on the same tab.
Widgets.IconToolButton {
    id: root

    // Properties

    readonly property var _parentItem: {
        if ((typeof rootPlayer !== 'undefined') && (rootPlayer !== null))
            return rootPlayer
        else
            return g_mainDisplay
    }


    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)

    // Settings

    text: VLCIcons.visualization

    description: qsTr("Audio tracks and output")

    AccessibleCompat.id: "audioButton"

    // accent while the picker or the panel it opened is shown
    color: ((pickerLoader.item && pickerLoader.item.visible) || (panelLoader.item && panelLoader.item.visible))
           ? colorContext.accent : colorContext.fg.primary

    // Events

    onClicked: {
        if (panelLoader.item?.visible)
            panelLoader.item.close()
        else if (Date.now() - (panelLoader.item?._closedAt ?? 0) > 300)
            pickerLoader.item?.toggle(1)
    }

    // Children

    Loader {
        id: pickerLoader

        active: !root.paintOnly

        sourceComponent: TracksPicker {
            id: picker

            parent: root._parentItem
            z: 1

            colorContext.palette: root.colorContext.palette

            onPreferencesRequested: (panelTab) => panelLoader.item?.openTab(panelTab)

            onOpened: {
                MainCtx.playqueuePanel.visible = false
                root.requestLockUnlockAutoHide(true)
                root.menuOpened(picker)
            }

            onClosed: {
                root.requestLockUnlockAutoHide(false)
                root.forceActiveFocus()
                root.menuOpened(null)
            }
        }
    }

    Loader {
        id: panelLoader

        active: !root.paintOnly

        sourceComponent: TracksMenu {
            id: panel

            parent: root._parentItem

            // the tracks panel, as opened by the languages and tracks button
            // redesign: TracksMenu places itself (right side, below the top bar)
            z: 1

            focus: true

            colorContext.palette: root.colorContext.palette

            onOpened: {
                root.requestLockUnlockAutoHide(true)
                root.menuOpened(panel)
            }

            onClosed: {
                root.requestLockUnlockAutoHide(false)
                root.forceActiveFocus()
                root.menuOpened(null)
            }
        }
    }

    function forceUnlock() {
        // also called while the bar is torn down, after the loader
        pickerLoader?.item?.close()
        panelLoader?.item?.close()
    }
}
