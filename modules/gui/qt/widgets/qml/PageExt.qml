/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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

import VLC.MainInterface
import VLC.Style
import VLC.Menus
import VLC.Util

T.Page {
    id: root

    //path of the current page loader
    property var pagePrefix: []

    //note that T.Page introduce an intermediate Item, so to access our delegate,
    //we need to use contentChildren[0] rather than contentItem
    readonly property Item _firstChild: contentChildren[0] ?? null

    //indicates whether the subview support grid/list mode
    property bool hasGridListMode: _firstChild?.hasGridListMode ?? false

    property bool isSearchable: _firstChild?.isSearchable ?? false

    property var sortModel: _firstChild?.sortModel ?? null

    // The address line: when not empty, the header shows these names as a clickable path
    // (the last one is the current place) instead of the title.
    property var crumbs: []

    signal crumbClicked(int index)

    // redesign: entries of the header's "..." menu for this page ({ text, icon_svg, action });
    // unset, it is the folder menu
    property var menuEntries: null

    //property is *not* readOnly, a PageLoader may define a localMenuDelegate common for its subviews (music, video)
    property SortMenu sortMenu: null

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0

    property bool enableBeginningFade: true
    property bool enableEndFade: true

    readonly property SearchCtx search: _searchCtx
    readonly property SortCtx sort: _sortCtx


    SearchCtx {
        id: _searchCtx
        available: root.isSearchable
    }

    SortCtx {
        id: _sortCtx

        readonly property string _sortCriteriaKey: ["sortCriteria", ...root.pagePrefix].join("/")
        readonly property string _sortOrderKey:  ["sortOrder", ...root.pagePrefix].join("/")

        available: Helpers.isArray(root.sortModel) && (root.sortModel).length > 0
        model: root.sortModel

        //save & restore setting of the page
        Component.onCompleted: {
            const criteria = MainCtx.settingValue(_sortCriteriaKey, undefined)
            if (criteria !== undefined)
                _sortCtx.criteria = criteria

            const order = MainCtx.settingValue(_sortOrderKey, undefined)
            if (order !== undefined)
                _sortCtx.order = parseInt(order)
        }

        Component.onDestruction: {
            MainCtx.setSettingValue(_sortCriteriaKey, _sortCtx.criteria)
            MainCtx.setSettingValue(_sortOrderKey, _sortCtx.order)
        }
    }

    Binding {
        target: MainCtx
        property: "hasGridListMode";
        value: root.hasGridListMode
    }

    on_FirstChildChanged: {
        if (!_firstChild)
            return
        _firstChild.Navigation.parentItem = root
        _firstChild.Navigation.upItem = root.header
    }

    function positionContentAtBeginning() {
        _firstChild?.positionContentAtBeginning?.()
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding
                             + (implicitHeaderHeight > 0 ? implicitHeaderHeight + spacing : 0)
                             + (implicitFooterHeight > 0 ? implicitFooterHeight + spacing : 0))

    header: DefaultPageHeader {
        text: root.title

        crumbs: root.crumbs
        onCrumbClicked: (index) => root.crumbClicked(index)

        // NOTE: the page width, not the header's own: its padding feeds its implicit width,
        //       and the width of an unsized item follows the implicit one (a binding loop)

        leftPadding: VLCStyle.dynamicAppMargins(root.width) + VLCStyle.layout_left_margin + root.leftPadding
        rightPadding: VLCStyle.dynamicAppMargins(root.width) + VLCStyle.layout_right_margin + root.rightPadding

        sortMenu: root.sortMenu

        search: _searchCtx
        sort: _sortCtx

        Navigation.parentItem: root
        Navigation.downAction: function() {
            if (typeof root.setCurrentItemFocus === "function")
                root.setCurrentItemFocus(Qt.TabFocusReason)
            else if (typeof root._firstChild?.setCurrentItemFocus === "function")
             root._firstChild.setCurrentItemFocus(Qt.TabFocusReason)
            else if (root._firstChild)
                root._firstChild.forceActiveFocus(Qt.TabFocusReason)
        }
    }

    component DefaultPageHeader: T.ToolBar {
        id: defaultPageHeader

        // Properties
        property alias text: label.text

        // the address line; empty: the text instead
        property var crumbs: []

        signal crumbClicked(int index)

        property alias sortMenu: gridSortFilter.sortMenu

        property alias search: gridSortFilter.search
        property alias sort: gridSortFilter.sort

        position: T.ToolBar.Header

        topPadding: VLCStyle.pageHeader_top_padding
        bottomPadding: VLCStyle.pageHeader_bottom_padding

        // FIXME: `GridItem`'s background extends beyond its
        //        bounding rect, violating the hypothetical
        //        clip test (see 7e6b23db).
        bottomInset: (MainCtx.hasGridListMode && MainCtx.gridView) ? VLCStyle.gridItemSelectedBorder : undefined

        // Settings

        implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                 implicitContentHeight + topPadding + bottomPadding)

        Navigation.navigable: gridSortFilter.enabled

        // Children

        readonly property ColorContext colorContext: ColorContext {
            id: theme
            colorSet: ColorContext.View
        }

        background: Rectangle {
            color: theme.bg.primary

        // redesign: hairline under the page header, inside the content margins (prototype `.lib-head`)
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: defaultPageHeader.leftPadding
            anchors.rightMargin: defaultPageHeader.rightPadding
            height: VLCStyle.border
            color: theme.separator
        }
        }

        RowLayout {
            id: row

            anchors.fill: parent

            // redesign: Figma library header, back/forward, the page as a crumb, the item
            // count, then sort / view / search
            spacing: VLCStyle.margin_xsmall

            IconToolButton {
                id: historyBack

                text: VLCIcons.back
                description: qsTr("Back")
                font.pixelSize: VLCStyle.icon_banner
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                enabled: !History.previousEmpty
                onClicked: History.previous(Qt.MouseFocusReason)
            }

            IconToolButton {
                id: historyForward

                text: VLCIcons.back
                rotation: 180 // no forward glyph in the icon font
                description: qsTr("Forward")
                font.pixelSize: VLCStyle.icon_banner
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                enabled: !History.nextEmpty
                onClicked: History.next(Qt.MouseFocusReason)
            }

            // redesign: Figma address line, "Videos > Shows > The Wand", every part but the
            // last takes you back to that folder
            Breadcrumbs {
                id: crumbRow

                visible: (defaultPageHeader.crumbs ?? []).length > 0

                Layout.fillWidth: true
                Layout.leftMargin: VLCStyle.margin_xsmall

                pixelSize: VLCStyle.fontSize_xlarge
                names: (defaultPageHeader.crumbs ?? []).map((text, index) => ({ text: text, depth: index }))

                onCrumbClicked: (depth) => defaultPageHeader.crumbClicked(depth)
            }

            LabelExt {
                id: label

                visible: !crumbRow.visible

                Layout.fillWidth: true
                Layout.leftMargin: VLCStyle.margin_xsmall

                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.pixelSize: VLCStyle.fontSize_xlarge
                color: theme.fg.primary
            }

            LabelExt {
                readonly property var _count: root._firstChild?.model?.count

                visible: (_count !== undefined && _count !== null)
                text: _count === 1 ? qsTr("1 item") : qsTr("%1 items").arg(_count ?? 0)
                font.pixelSize: VLCStyle.fontSize_large
                color: theme.fg.secondary
                Layout.rightMargin: VLCStyle.margin_small
            }

            GridSortFilterControls {
                id: gridSortFilter
                focus: true
                sort: _sortCtx
                search: _searchCtx
                menuEntries: root.menuEntries
                Navigation.parentItem: defaultPageHeader
            }
        }
    }
}
