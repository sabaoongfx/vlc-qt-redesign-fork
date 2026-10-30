
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
import QtQml.Models

import VLC.MediaLibrary

import VLC.Util
import VLC.Widgets as Widgets
import VLC.Style


Widgets.TableViewExt {
    id: listView_id

    readonly property bool isSearchable: false

    property alias searchPattern: urlModel.searchPattern
    property alias sortOrder: urlModel.sortOrder
    property alias sortCriteria: urlModel.sortCriteria

    visible: urlModel.count > 0
    model: urlModel

    sortModel: [{
        weight: 1,

        model: {
            criteria: "url",

            // redesign: text column titles that line up with the address and the date (the
            // icons sat centred over nothing, user report)
            text: qsTr("Address"),

            isSortable: false,

            showSection: "url"
        }
    }, {
        size: 1,

        model: {
            criteria: "last_played_date",

            text: qsTr("Last played"),

            isSortable: false,

            showSection: "",
            showContextButton: true
        }
    }]

    rowHeight: VLCStyle.listAlbumCover_height + VLCStyle.margin_xxsmall * 2

    rowContextMenu: contextMenu

    onActionForSelection: (selection) => model.addAndPlay( selection )
    onItemDoubleClicked: (index, model) => MediaLib.addAndPlay(model.id)

    onRightClick: (_,_,globalMousePos) => {
        contextMenu.popup(selectionModel.selectedIndexes, globalMousePos)
    }

    MLUrlModel {
        id: urlModel
        ml: MediaLib
    }

    MLContextMenu {
        id: contextMenu

        model: urlModel
    }
}
