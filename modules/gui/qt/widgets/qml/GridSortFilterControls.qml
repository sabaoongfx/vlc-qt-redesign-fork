import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Menus

NavigableRow {
    id: root

    spacing: VLCStyle.margin_normal
    enabled: gridListBtn.visible || sortControl.visible || searchBox.visible

    property SortMenu sortMenu: null
    required property SortCtx sort
    required property SearchCtx search


    SortControl {
        id: sortControl

        visible: root.sort.available
        enabled: visible
        width: VLCStyle.bannerButton_width
        height: VLCStyle.bannerButton_height
        font.pixelSize: VLCStyle.icon_banner
        description: qsTr("Sort")

        model: root.sort.model

        menu: root.sortMenu

        sortKey:  root.sort.criteria
        sortOrder: root.sort.order

        onSortSelected: (key) => {
            root.sort.criteria = key
        }
        onSortOrderSelected: (type) => {
            root.sort.order = type
        }
    }

    //TODO: visible value of root.sort.available and MainCtx.hasGridListMode is initialised correctly but on first load still shows up
    IconToolButton {
        id: gridListBtn

        visible: MainCtx.hasGridListMode

        enabled: visible
        width: VLCStyle.bannerButton_width
        height: VLCStyle.bannerButton_height
        font.pixelSize: VLCStyle.icon_banner
        text: MainCtx.gridView ? VLCIcons.list : VLCIcons.grid
        description: qsTr("List/Grid")
        onClicked: MainCtx.gridView = !MainCtx.gridView
    }

    // redesign: always-visible search field (Figma library header) instead of the
    // icon that expands into a popup
    FocusScope {
        id: searchBox

        visible: root.search.available

        width: VLCStyle.dp(324, VLCStyle.scale)
        height: VLCStyle.dp(34, VLCStyle.scale)
        anchors.verticalCenter: parent.verticalCenter

        property alias searchPattern: searchField.text

        function expandAndFocus() {
            searchField.forceActiveFocus(Qt.OtherFocusReason)
        }

        Accessible.role: Accessible.EditableText
        Accessible.name: qsTr("Search")

        readonly property ColorContext colorContext: ColorContext {
            id: searchTheme
            colorSet: ColorContext.TextField
            focused: searchField.activeFocus
        }

        Rectangle {
            anchors.fill: parent
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: VLCStyle.figmaColors(searchTheme.palette?.isDark ?? true).search
            border.width: searchField.activeFocus ? VLCStyle.border : 0
            border.color: searchTheme.accent
        }

        IconLabel {
            id: searchIcon

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.margin_small
            anchors.verticalCenter: parent.verticalCenter

            text: VLCIcons.search
            font.pixelSize: VLCStyle.icon_normal
            color: searchTheme.fg.secondary
        }

        T.TextField {
            id: searchField

            anchors.left: searchIcon.right
            anchors.leftMargin: VLCStyle.margin_xsmall
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.margin_xsmall
            anchors.verticalCenter: parent.verticalCenter

            focus: true

            // the Templates TextField does not draw its placeholder
            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: searchField.text === "" && !searchField.activeFocus
                text: qsTr("Search")
                color: searchTheme.fg.secondary
                font: searchField.font
            }
            color: searchTheme.fg.primary
            selectionColor: searchTheme.accent
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_large
            verticalAlignment: TextInput.AlignVCenter

            background: null

            Keys.onEscapePressed: (event) => {
                if (text !== "") {
                    text = ""
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }
        }

        Binding {
            target: root.search
            property: "pattern"
            value: searchBox.searchPattern
        }

        Connections {
            target: root.search
            function onAskShow() {
                searchBox.expandAndFocus()
            }
        }
    }
}
