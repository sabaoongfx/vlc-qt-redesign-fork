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
import VLC.MainInterface
import VLC.MediaLibrary

import VLC.Style
import VLC.Widgets as Widgets

Widgets.PageExt {
    id: root

    title: qsTr("Tracks")

    hasGridListMode: false
    isSearchable: tracklistdisplay_id.isSearchable

    property alias model: tracklistdisplay_id.model
    property alias selectionModel: tracklistdisplay_id.selectionModel

    // Figma Sorting Options. The Disc Number entries are left out: the media library has no disc sort criterion.
    property var sortModel: [
        { text: qsTr("Newest First"),             criteria: "insertion",    order: Qt.DescendingOrder },
        { text: qsTr("Oldest First"),             criteria: "insertion",    order: Qt.AscendingOrder  },
        { text: qsTr("Title A-Z"),                criteria: "title",        order: Qt.AscendingOrder  },
        { text: qsTr("Title Z-A"),                criteria: "title",        order: Qt.DescendingOrder },
        { text: qsTr("Artist A-Z"),               criteria: "main_artist",  order: Qt.AscendingOrder  },
        { text: qsTr("Artist Z-A"),               criteria: "main_artist",  order: Qt.DescendingOrder },
        { text: qsTr("Album A-Z"),                criteria: "album_title",  order: Qt.AscendingOrder  },
        { text: qsTr("Album Z-A"),                criteria: "album_title",  order: Qt.DescendingOrder },
        { text: qsTr("Track Number Ascending"),   criteria: "track_number", order: Qt.AscendingOrder  },
        { text: qsTr("Track Number Descending"),  criteria: "track_number", order: Qt.DescendingOrder },
        { text: qsTr("URI Ascending"),            criteria: "filename",     order: Qt.AscendingOrder  },
        { text: qsTr("URI Descending"),           criteria: "filename",     order: Qt.DescendingOrder }
    ]

    function setCurrentItemFocus(reason) {
        tracklistdisplay_id.setCurrentItemFocus(reason);
    }

    function positionContentAtBeginning() {
        tracklistdisplay_id.positionViewAtBeginningAnimated()
    }

    FocusScope {

        anchors.fill: parent

        focus: true

        // Aliases

        property alias leftPadding: tracklistdisplay_id.leftPadding
        property alias rightPadding: tracklistdisplay_id.rightPadding

        MusicTrackListDisplay {
            id: tracklistdisplay_id

            anchors.fill: parent

            visible: model.count > 0
            focus: model.count > 0

            searchPattern: root.search.pattern
            sortOrder: root.sort.order
            sortCriteria: root.sort.criteria

            Navigation.parentItem: root
            Navigation.upItem: root.header

            Navigation.cancelAction: function() {
                if (tracklistdisplay_id.currentIndex <= 0)
                    root.Navigation.defaultNavigationCancel()
                else
                    tracklistdisplay_id.currentIndex = 0;
            }


            displayMarginBeginning: root.displayMarginBeginning
            displayMarginEnd: root.displayMarginEnd

            fadingEdge.enableEndFade: root.enableEndFade
            fadingEdge.enableBeginningFade: root.enableBeginningFade
        }

        Widgets.EmptyLabelButton {
            anchors.centerIn: parent
            visible: !tracklistdisplay_id.model.loading && (tracklistdisplay_id.model.count <= 0)
            focus: visible
            text: qsTr("No tracks found\nPlease try adding sources")
            Navigation.parentItem: root
            cover: VLCStyle.noArtAlbumCover
        }
    }
}
