
/*****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
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
import QtQuick.Templates as T


import VLC.Util
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Network
import VLC.MainInterface

T.Pane {
    id: root

    signal browse(var tree, int reason)
    signal homeButtonClicked(int reason)

    // Network* model
    required property BaseModel providerModel
    property var path: providerModel?.path ?? []

    property alias sort: gridSortFilter.sort
    property alias search: gridSortFilter.search

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    topPadding: VLCStyle.layoutTitle_top_padding
    bottomPadding: VLCStyle.layoutTitle_bottom_padding

    // FIXME: `GridItem`'s background extends beyond its
    //        bounding rect, violating the hypothetical
    //        clip test (see 7e6b23db).
    bottomInset: MainCtx.gridView ? VLCStyle.gridItemSelectedBorder : undefined

    height: implicitHeight
    implicitHeight: layout.implicitHeight + topPadding + bottomPadding
    implicitWidth: layout.implicitWidth + leftPadding + rightPadding

    focus: medialibraryBtn.visible
    Navigation.navigable: medialibraryBtn.visible

    property alias networkAddressbar: networkAddressbar

    background: Rectangle {
        color: theme.bg.primary

        // redesign: hairline under the page header, inside the content margins (prototype `.lib-head`)
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.leftPadding
            anchors.rightMargin: root.rightPadding
            height: VLCStyle.border
            color: theme.separator
        }
    }

    // redesign: same header as the library pages (Figma): back/forward, the folder path as crumbs,
    // the item count, sort / view / search, then add to (or remove from) the media library
    RowLayout {
        id: layout

        anchors.fill: parent

        spacing: VLCStyle.margin_xsmall

        Widgets.IconToolButton {
            id: historyBack

            text: VLCIcons.back
            description: qsTr("Back")
            font.pixelSize: VLCStyle.icon_banner
            Layout.preferredWidth: VLCStyle.bannerButton_width
            Layout.preferredHeight: VLCStyle.bannerButton_height

            enabled: !History.previousEmpty
            onClicked: History.previous(Qt.MouseFocusReason)

            Navigation.parentItem: root
            Navigation.rightItem: historyForward
        }

        Widgets.IconToolButton {
            id: historyForward

            text: VLCIcons.back
            rotation: 180 // no forward glyph in the icon font
            description: qsTr("Forward")
            font.pixelSize: VLCStyle.icon_banner
            Layout.preferredWidth: VLCStyle.bannerButton_width
            Layout.preferredHeight: VLCStyle.bannerButton_height

            enabled: !History.nextEmpty
            onClicked: History.next(Qt.MouseFocusReason)

            Navigation.parentItem: root
            Navigation.leftItem: historyBack
            Navigation.rightItem: networkAddressbar
        }

        NetworkAddressbar {
            id: networkAddressbar

            Layout.fillWidth: true
            Layout.fillHeight: true

            background: null

            path: root.path

            Navigation.parentItem: root
            Navigation.leftItem: historyForward
            Navigation.rightItem: gridSortFilter

            onHomeButtonClicked: reason => root.homeButtonClicked(reason)

            onBrowse:  (tree, reason) => root.browse(tree, reason)
        }

        Widgets.LabelExt {
            readonly property var _count: root.providerModel?.count

            visible: (_count !== undefined && _count !== null)
            text: qsTr("%1 items").arg(_count ?? 0)
            font.pixelSize: VLCStyle.fontSize_large
            color: theme.fg.secondary
            Layout.rightMargin: VLCStyle.margin_small
        }

        Widgets.GridSortFilterControls {
            id: gridSortFilter

            Navigation.parentItem: root
            Navigation.leftItem: networkAddressbar
            Navigation.rightItem: medialibraryBtn
        }

        Widgets.IconToolButton {
            id: medialibraryBtn

            AccessibleCompat.id: "browseIndexButton"

            focus: true

            font.pixelSize: VLCStyle.icon_banner
            Layout.preferredWidth: VLCStyle.bannerButton_width
            Layout.preferredHeight: VLCStyle.bannerButton_height

            text: root.providerModel.indexed ? VLCIcons.medialibrary_remove : VLCIcons.medialibrary_add

            description: root.providerModel.indexed
                  ? qsTr("Remove from medialibrary")
                  : qsTr("Add to medialibrary")

            visible: root.providerModel.canBeIndexed ?? false

            onClicked: root.providerModel.indexed = !root.providerModel.indexed

            Navigation.parentItem: root
            Navigation.leftItem: gridSortFilter
        }
    }
}
