/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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

import VLC.MediaLibrary
import VLC.Dialogs
import VLC.Menus
import VLC.MainInterface

Item {
    ShortcutExt{ sequence:"Ctrl+B"; onActivated: DialogsProvider.bookmarksDialog() }
    // redesign: U shows or hides the library menu beside the video (user request; U is free in
    // VLC's default hotkeys, L is loop); text fields keep the letter (ShortcutOverride)
    ShortcutExt{ sequence:"U"; onActivated: MainCtx.libraryPanel.visible = !MainCtx.libraryPanel.visible }

    MLRecentMediaModel {
        id: recentModel
        limit: 10
        ml: MediaLib
    }

    //build all the shortcuts everytime, it seems that they can't be added/removed dynamically
    Repeater {
        model: 10

        Item {
            ShortcutExt {
                sequence: "Ctrl+" + ((index + 1) % 10)
                onActivated:  {
                    if (index < recentModel.count)
                    {

                        const trackId = recentModel.data(recentModel.index(index, 0), MLRecentMediaModel.MEDIA_ID)
                        if (!!trackId)
                            MediaLib.addAndPlay([trackId])
                    }
                }
            }
        }
    }
}
