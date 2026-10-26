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
import QtQuick.Layouts
import QtQuick.Window


import VLC.MainInterface
import VLC.Style
import VLC.PlayerControls
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Util

FocusScope{
    id: root

    // Properties

    required property int textWidth

    // For now, used for d&d functionality
    // Not strictly necessary to set
    property Item plListView

    property int reservedHeight: 0

    property int topMargin: 0
    property int sideMargin: 0

    property string title

    property bool showCSD: false
    property bool showToolbar: false
    property bool pinControls: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Private

    property bool _showTopBar: (pinControls === false || showToolbar === false)

    property bool _showCenterText: (pinControls && showToolbar === false && showCSD)

    readonly property int _sideMargin: VLCStyle.margin_small + sideMargin

    // Aliases

    property alias resumeVisible: resumeDialog.shown

    property alias playlistVisible: playlistButton.checked

    // Signals

    signal togglePlaylistVisibility()
    signal requestLockUnlockAutoHide(bool lock)
    signal backRequested()

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Player topbar")
    AccessibleCompat.id: "playerTopBar"

    // Events

    Component.onCompleted: _layout()

    onShowCSDChanged: _layout()
    onPinControlsChanged: _layout()
    onShowToolbarChanged: _layout()
    onTopMarginChanged: _layout()
    onSideMarginChanged: _layout()

    on_ShowTopBarChanged: _layout()
    on_ShowCenterTextChanged: _layout()

    // Functions

    // FIXME: Imperative layouting in QML is stupid, this needs to be gone.
    function _layoutLine(c1, c2, offset)
    {
        let c1Height = c1?.implicitHeight ?? 0
        let c2Height = c2?.implicitHeight ?? 0

        if (c2 === csdDecorations) {
            //csdDecorations.implicitHeight gets overwritten when the height is set,
            //VLCStyle.icon_normal is its initial value
            c2Height = VLCStyle.icon_normal
        }

        const lineHeight = Math.max(c1Height, c2Height)

        if (c1) {
            c1.height = lineHeight
            c1.anchors.topMargin = offset
        }

        if (c2) {
            c2.height = lineHeight
            c2.anchors.topMargin = offset
        }
        return lineHeight
    }

    // FIXME: Imperative layouting in QML is stupid, this needs to be gone.
    //FIXME: if CSD will be weirdly placed if application safe-area are used,
    //nota that if you need a safe area (kiosk mode), you probably don't need CSD
    function _layout() {
        let offset = topMargin

        if (_showCenterText) {
            //place everything on one line
            //csdDecorations.implicitHeight gets overwritten when the height is set,
            //VLCStyle.icon_normal is its initial value
            // redesign: the Figma player top bar is 40px, like the library one
            const lineHeight = Math.max(logoOrResume.implicitHeight, playlistGroup.implicitHeight, VLCStyle.icon_normal,
                                        VLCStyle.globalToolbar_height)

            centerTitleText.y = 0
            centerTitleText.height = lineHeight

            csdDecorations.height  = lineHeight

            logoOrResume.height =  lineHeight

            playlistGroup.height = lineHeight
            playlistGroup.anchors.topMargin = 0
            playlistGroup.extraRightMargin = Qt.binding(function() { return width - csdDecorations.x })


            implicitHeight = lineHeight
            offset += lineHeight

        } else {
            playlistGroup.extraRightMargin = 0

            let left = undefined
            let right = undefined
            let logoPlaced = false

            if (showToolbar) {
                left = menubar
            }

            if (showCSD) {
                right = csdDecorations
                if (!left) {
                    left = logoOrResume
                    logoPlaced = true
                }
            }

            if (!!left || !!right) {
                offset += _layoutLine(left, right, offset)

                if (showCSD) {
                    tapNDrag.height = offset
                }
            }

            if (!logoPlaced) {
                left = logoOrResume
            } else {
                left = undefined
            }

            if (_showTopBar)
                right = playlistGroup
            else
                right = undefined

            offset += _layoutLine(left, right, offset)
        }

        implicitHeight = offset
        reservedHeight = offset
    }

    // Children

    //drag and dbl click the titlebar in CSD mode
    Loader {
        id: tapNDrag

        anchors.fill: parent
        active: root.showCSD
        source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"

        Connections {
            target: tapNDrag.item
            enabled: tapNDrag.status === Loader.Ready
            function onCsdMenuVisibleChanged() {
                root.requestLockUnlockAutoHide(tapNDrag.item.csdMenuVisible)
            }
        }
    }

    // Components -
    Menus.Menubar {
        id: menubar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: root.sideMargin
        anchors.right: root.showCSD ? csdDecorations.left : parent.right


        visible: root.showToolbar
        enabled: root.showToolbar

        onHoveredChanged: menu => root.requestLockUnlockAutoHide(hovered)
        onMenuOpenedChanged: menu => root.requestLockUnlockAutoHide(menuOpened)
        onImplicitHeightChanged: root._layout()
    }

    Item {
        id: logoOrResume

        anchors.left: root.left
        anchors.top: root.top
        anchors.leftMargin:  root._sideMargin

        // redesign: the resume prompt is a floating card below the bar (resumeToast), the bar
        // keeps its cone, menu and folder crumb
        implicitWidth: logoGroup.implicitWidth

        implicitHeight: _showTopBar ? logoGroup.implicitHeight : 0

        onImplicitHeightChanged: root._layout()

        Item {
            id: logoGroup

            anchors.fill: parent

            visible: root._showTopBar

            implicitHeight: VLCStyle.icon_banner + VLCStyle.margin_xxsmall * 2
            implicitWidth: logoRow.implicitWidth

            // redesign: Figma player top bar, cone, menu, divider and a folder crumb that returns to
            // the library; there is no back arrow in the player
            Row {
                id: logoRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.margin_xsmall

                Widgets.BannerCone {
                    id: logo

                    anchors.verticalCenter: parent.verticalCenter

                    color: theme.accent
                }

                Widgets.IconToolButton {
                    id: menuSelector

                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.showToolbar
                    enabled: visible
                    focus: visible
                    font.pixelSize: VLCStyle.icon_banner

                    width: VLCStyle.bannerButton_width
                    height: VLCStyle.bannerButton_height

                    text: VLCIcons.more
                    description: qsTr("Menu")

                    AccessibleCompat.id: "topBarMenuButton"

                    checked: contextMenu.shown

                    // redesign: Figma Icon Wrapper, a 30x32 box with a 4px radius around the
                    // 24px icon, kept while the menu is open; drawn outside the item so the bar
                    // layout does not move
                    leftInset: -VLCStyle.dp(3, VLCStyle.scale)
                    rightInset: -VLCStyle.dp(3, VLCStyle.scale)
                    topInset: -VLCStyle.dp(4, VLCStyle.scale)
                    bottomInset: -VLCStyle.dp(4, VLCStyle.scale)
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    backgroundColor: (hovered || checked) ? VLCStyle.figmaColors(colorContext.palette.isDark).iconHover
                                                          : "transparent"
                    color: checked ? colorContext.fg.secondary : colorContext.fg.primary

                    Navigation.parentItem: root
                    Navigation.rightItem: backBtn

                    onClicked: contextMenu.popup(this.mapToGlobal(0, height))

                    onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

                    Menus.QmlGlobalMenu {
                        id: contextMenu

                        ctx: MainCtx

                        onAboutToShow: root.requestLockUnlockAutoHide(true)
                        onAboutToHide: root.requestLockUnlockAutoHide(false)
                    }

                    Connections {
                        target: root

                        function onForceUnlock() {
                            contextMenu.close()
                        }
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.border
                    height: VLCStyle.dp(20, VLCStyle.scale)
                    color: theme.separator
                }

                T.AbstractButton {
                    id: backBtn

                    anchors.verticalCenter: parent.verticalCenter

                    // name of the folder holding the current media, the library otherwise
                    readonly property string folderName: {
                        const url = Player.url ? Player.url.toString() : ""
                        if (!url.startsWith("file://"))
                            return qsTr("Library")
                        const parts = decodeURIComponent(url.replace(/\/+$/, "")).split("/")
                        return (parts.length > 1 && parts[parts.length - 2] !== "") ? parts[parts.length - 2]
                                                                                     : qsTr("Library")
                    }

                    text: folderName

                    objectName: "IconToolButton"
                    Accessible.name: qsTr("Back to %1").arg(folderName)
                    AccessibleCompat.id: "topBarBackButton"

                    focus: true

                    implicitWidth: crumbRow.implicitWidth + leftPadding + rightPadding
                    implicitHeight: VLCStyle.bannerButton_height

                    leftPadding: VLCStyle.margin_xxsmall
                    rightPadding: VLCStyle.margin_xsmall

                    background: Rectangle {
                        radius: VLCStyle.button_radius
                        color: backBtn.hovered ? Qt.alpha(theme.fg.primary, 0.08) : Qt.alpha(theme.fg.primary, 0)
                        border.width: VLCStyle.focus_border
                        border.color: backBtn.visualFocus ? theme.visualFocus : Qt.alpha(theme.visualFocus, 0)
                    }

                    contentItem: Row {
                        id: crumbRow

                        spacing: VLCStyle.margin_xsmall

                        Widgets.IconLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: VLCIcons.ic_fluent_folder_open_24_regular
                            font.pixelSize: VLCStyle.icon_banner
                            color: backBtn.hovered ? theme.fg.primary : theme.fg.secondary
                        }

                        T.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: backBtn.text
                            color: backBtn.hovered ? theme.fg.primary : theme.fg.secondary
                            font.family: VLCStyle.fontFamily
                            font.pixelSize: VLCStyle.fontSize_large
                            elide: Text.ElideRight
                        }
                    }

                    Navigation.parentItem: root
                    Navigation.leftItem: menuSelector.visible ? menuSelector : null
                    Navigation.rightItem: fullscreenBtn

                    onClicked: root.backRequested()

                    onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
                }
            }
        }

    }

    // redesign: the resume prompt as a floating card centred below the top bar
    Rectangle {
        id: resumeToast

        parent: root.parent
        z: 3
        visible: resumeDialog.shown

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.y + root.height + VLCStyle.margin_small

        width: resumeDialog.implicitWidth + VLCStyle.margin_normal * 2
        height: resumeDialog.implicitHeight + VLCStyle.margin_xsmall + VLCStyle.margin_small
        radius: VLCStyle.dp(8, VLCStyle.scale)
        color: theme.bg.primary
        border.width: VLCStyle.border
        border.color: theme.separator

            ResumeDialog {
                id: resumeDialog

                x: VLCStyle.margin_normal
                y: VLCStyle.margin_xxsmall

                maxWidth: Math.min(root.width - VLCStyle.margin_xxlarge * 2, VLCStyle.dp(620, VLCStyle.scale))

                colorContext.palette: theme.palette

                Navigation.parentItem: rootPlayer

                onHidden: {
                    if (activeFocus) {
                        backBtn.forceActiveFocus()
                    }
                }

                onVisibleChanged: {
                    root.requestLockUnlockAutoHide(visible)
                }
            }
    }

    //FIXME use the the right class
    T.Label {
        id: centerTitleText

        readonly property int _leftLimit: logoOrResume.x + logoOrResume.width
        readonly property int _rightLimit: playlistGroup.x
        readonly property int _availableWidth: _rightLimit - _leftLimit
        readonly property int _centerX: ((root.width - centerTitleText.implicitWidth) / 2)
        readonly property bool _alignHCenter: _centerX > _leftLimit
                                              && _centerX + centerTitleText.implicitWidth < _rightLimit

        // redesign: the prototype keeps a small centered title in the top bar,
        // in every layout, instead of the large title below the logo
        anchors.verticalCenter: _showCenterText ? undefined : logoOrResume.verticalCenter

        visible: (_showCenterText || root._showTopBar)

        enabled: visible

        width: Math.min(centerTitleText._availableWidth, centerTitleText.implicitWidth)

        leftPadding: VLCStyle.margin_small
        rightPadding: VLCStyle.margin_small

        text: root.title
        color: theme.fg.secondary
        font.family: VLCStyle.fontFamily
        font.pixelSize: VLCStyle.fontSize_large
        font.weight: Font.Normal
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter

        on_AlignHCenterChanged: _layout()
        Component.onCompleted: _layout()

        function _layout() {
            if (_alignHCenter) {
                centerTitleText.x = 0
                centerTitleText.anchors.horizontalCenter = root.horizontalCenter
            } else {
                centerTitleText.anchors.horizontalCenter = undefined
                centerTitleText.x = Qt.binding(function() { return centerTitleText._leftLimit })
            }
        }
    }

    //FIXME use the the right class
    T.Label {
        id: leftTitleText

        anchors.left: parent.left
        anchors.top: logoOrResume.bottom
        anchors.leftMargin: root._sideMargin

        width: root.textWidth - VLCStyle.margin_normal

        visible: !root.pinControls && !centerTitleText.visible

        enabled: visible

        topPadding: VLCStyle.margin_large
        leftPadding: logo.x

        text: root.title
        horizontalAlignment: Text.AlignLeft
        color: theme.fg.primary
        font.weight: Font.DemiBold
        font.pixelSize: VLCStyle.dp(18, VLCStyle.scale)
        elide: Text.ElideRight
    }

    Loader {
        id: csdDecorations

        anchors.top: parent.top
        anchors.right: parent.right

        focus: false
        height: VLCStyle.icon_normal
        active: root.showCSD
        enabled: root.showCSD
        visible: root.showCSD
        source:  VLCStyle.palette.hasCSDImage
            ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
            : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"

        Connections {
            target: csdDecorations.item
            enabled: csdDecorations.status === Loader.Ready
            function onButtonHoveredChanged() { root.requestLockUnlockAutoHide(csdDecorations.item.buttonHovered) }
        }
    }

    Row {
        id: playlistGroup

        property int extraRightMargin: 0

        focus: true
        spacing: VLCStyle.margin_xxsmall

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: root._sideMargin + extraRightMargin

        visible: root._showTopBar

        Widgets.IconToolButton {
            id: fullscreenBtn

            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: VLCStyle.icon_banner

            width: VLCStyle.bannerButton_width
            height: VLCStyle.bannerButton_height

            text: Player.fullscreen ? VLCIcons.defullscreen : VLCIcons.fullscreen
            description: qsTr("Fullscreen")

            Navigation.parentItem: root
            Navigation.leftItem: backBtn

            onClicked: Player.fullscreen = !Player.fullscreen

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }

        PlaylistPane.PlaylistToggleButton {
            id: playlistButton

            anchors.verticalCenter: parent.verticalCenter
            objectName: ControlListModel.PLAYLIST_BUTTON
            font.pixelSize: VLCStyle.icon_banner
            text: VLCIcons.playlist
            description: qsTr("Play Queue")

            AccessibleCompat.id: "topBarPlayqueueButton"

            // redesign: the play queue button lives at the end of the bottom bar
            visible: false

            focus: root.showToolbar

            width: VLCStyle.bannerButton_width
            height: VLCStyle.bannerButton_height

            plListView: root.plListView
            
            Navigation.parentItem: root
            Navigation.leftItem: menuSelector.visible ? menuSelector : backBtn

            onClicked: togglePlaylistVisibility()

            Accessible.onToggleAction:togglePlaylistVisibility()

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }
    }
}
