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
import QtQml.Models
import QtQuick.Window


import VLC.MainInterface
import VLC.Style
import VLC.Playlist
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Util

T.ToolBar {
    id: root

    Accessible.name: qsTr("Local top bar")
    AccessibleCompat.id: "localTopbar"

    property bool useAcrylic: true

    // For now, used for d&d functionality
    // Not strictly necessary to set
    property Item plListView

    property bool _showCSD: MainCtx.clientSideDecoration
        && !(MainCtx.intfMainWindow.visibility === Window.FullScreen)
        && !MainCtx.hasToolbarMenu

    //whether the navigation pannel is actually visible or not
    property alias navigationVisible: navigationVisibilty.checked
    property alias playqueueVisible: playlistBtn.checked

    property alias navigationButton: navigationVisibilty

    signal toggleNavigationVisibility()
    signal togglePlayqueueVisibility()

    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                             implicitContentWidth + leftPadding + rightPadding + (_showCSD ? csdButtons.implicitWidth : 0))

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    background:  Widgets.AcrylicBackground {
        enabled: root.useAcrylic
        tintColor: theme.bg.primary
    }

    contentItem: Item {

        implicitHeight: VLCStyle.globalToolbar_height
        implicitWidth: navigationButtons.implicitWidth
                     + playqueueButtonsTop.implicitWidth
                     + VLCStyle.margin_xsmall * 2

        Item {
            id: navigationButtons

            implicitWidth: navigationButtonsRow.implicitWidth

            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                leftMargin: VLCStyle.margin_xsmall
            }

            Navigation.parentItem: root

            Row {
                id: navigationButtonsRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.margin_normal

                Navigation.parentItem: root
                Navigation.rightItem: playqueueButtonsTop

                // redesign: the same start as the player's top bar (Figma): the cone, the VLC menu, a
                // divider and the folder name: the folder of what plays (a click opens the player),
                // or the library page shown when nothing plays. Back/forward live in the page header.
                Widgets.BannerCone {
                    id: logo

                    anchors.verticalCenter: parent.verticalCenter
                    color: theme.accent
                }

                Widgets.IconToolButton {
                    id: menuBtn

                    anchors.verticalCenter: parent.verticalCenter

                    font.pixelSize: VLCStyle.icon_banner
                    text: VLCIcons.more
                    description: qsTr("Menu")
                    width: VLCStyle.bannerButton_width
                    height: VLCStyle.bannerButton_height
                    checked: globalMenu.shown

                    onClicked: globalMenu.popup(this.mapToGlobal(0, height))

                    Menus.QmlGlobalMenu {
                        id: globalMenu
                        ctx: MainCtx
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.border
                    height: VLCStyle.dp(20, VLCStyle.scale)
                    color: theme.separator
                }

                T.AbstractButton {
                    id: folderBtn

                    anchors.verticalCenter: parent.verticalCenter

                    readonly property string folderName: {
                        const url = Player.isStarted && Player.url ? Player.url.toString() : ""
                        if (url.startsWith("file://")) {
                            const parts = decodeURIComponent(url.replace(/\/+$/, "")).split("/")
                            if (parts.length > 1 && parts[parts.length - 2] !== "")
                                return parts[parts.length - 2]
                        }
                        switch (History.viewPath[0] ?? "") {
                        case "video": return qsTr("Videos")
                        case "music": return qsTr("Music")
                        case "network": return qsTr("Network")
                        case "playlists": return qsTr("Playlists")
                        default: return qsTr("Home")
                        }
                    }

                    text: folderName
                    enabled: Player.isStarted

                    Accessible.name: Player.isStarted ? qsTr("Open the player (%1)").arg(folderName) : folderName

                    implicitWidth: folderRow.implicitWidth + leftPadding + rightPadding
                    implicitHeight: VLCStyle.bannerButton_height

                    leftPadding: VLCStyle.margin_xxsmall
                    rightPadding: VLCStyle.margin_xsmall

                    background: Rectangle {
                        radius: VLCStyle.button_radius
                        color: folderBtn.hovered ? Qt.alpha(theme.fg.primary, 0.08) : "transparent"
                    }

                    contentItem: Row {
                        id: folderRow

                        spacing: VLCStyle.margin_xsmall

                        Widgets.IconLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: VLCIcons.ic_fluent_folder_open_24_regular
                            font.pixelSize: VLCStyle.icon_banner
                            color: folderBtn.hovered ? theme.fg.primary : theme.fg.secondary
                        }

                        T.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: folderBtn.text
                            color: folderBtn.hovered ? theme.fg.primary : theme.fg.secondary
                            font.family: VLCStyle.fontFamily
                            font.pixelSize: VLCStyle.fontSize_large
                            elide: Text.ElideRight
                        }
                    }

                    onClicked: History.push(["player"])
                }

                Widgets.IconToolButton {
                    id: navigationVisibilty

                    focus: true

                    // redesign: the sidebar expands and collapses by itself (MainDisplay
                    // pannelVisiblity.stopped), so this button no longer does it: it shows the
                    // library card beside the video, which lives in the player, so it opens the
                    // player with the card shown. Hidden while nothing plays.
                    // redesign: only the player has the switcher; the library sidebar is always shown
                    visible: false

                    text: ""
                    description: qsTr("Library beside the video")

                    Widgets.SidebarGlyph {
                        anchors.centerIn: parent
                        color: navigationVisibilty.color
                    }

                    AccessibleCompat.id: "sidebarToggleButton"

                    font.pixelSize: VLCStyle.icon_banner
                    height: VLCStyle.bannerButton_height
                    width: VLCStyle.bannerButton_width

                    onClicked: {
                        MainCtx.libraryPanel.visible = true
                        History.push(["player"])
                    }

                    Navigation.parentItem: navigationButtons
                    Navigation.rightItem: historyBack
                }

                Widgets.IconToolButton {
                    id: historyBack

                    font.pixelSize: VLCStyle.icon_banner
                    text: VLCIcons.back
                    description: qsTr("Previous")

                    AccessibleCompat.id: "historyBackButton"

                    height: VLCStyle.bannerButton_height
                    width: VLCStyle.bannerButton_width

                    onClicked: History.previous()
                    enabled: !History.previousEmpty
                    visible: false

                    onEnabledChanged: {
                        if (historyBack.activeFocus)
                            navigationVisibilty.focus = true
                    }

                    Navigation.parentItem: navigationButtons
                    Navigation.leftItem: navigationVisibilty
                    Navigation.rightItem: playlistBtn
                }

            }
        }

        Item {
            id: playqueueButtonsTop

            implicitWidth: playqueueButtonsTopRow.implicitWidth

            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                //put the buttons below the CSD if we have enough space
                rightMargin: VLCStyle.margin_xsmall
                    + ((root._showCSD && root.topPadding < csdButtons.height)
                        ? Math.max(csdButtons.width - root.rightPadding, 0)
                        : 0)
            }

            Navigation.parentItem: root

            Row {
                id: playqueueButtonsTopRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.margin_normal

                Navigation.parentItem: root
                Navigation.leftItem: navigationButtons

                PlaylistPane.PlaylistToggleButton {
                    id: playlistBtn

                    visible: false

                    plListView: root.plListView

                    Navigation.parentItem: playqueueButtonsTop
                    Navigation.leftItem: historyBack

                    onClicked:  root.togglePlayqueueVisibility()
                }

            }
        }

        TextMetrics {
            id: titleMetrics
            font: centerTitle.font
            text: centerTitle.text
        }

        T.Label {
            id: centerTitle

            anchors.centerIn: parent
            width: Math.min(Math.ceil(titleMetrics.advanceWidth) + 1, parent.width / 2)

            text: Player.isStarted ? (Player.title !== "" ? Player.title : Player.name)
                                   : qsTr("VLC Media Player")
            color: theme.fg.secondary
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_large
            elide: Text.ElideRight
        }

        Loader {
            z: -1

            anchors.fill: parent
            active: root._showCSD
            sourceComponent: Widgets.CSDTitlebarTapNDrapHandler {
            }
        }
    }

    Loader {
        id: csdButtons

        //csd button are
        parent:  root
        anchors {
            right: parent.right
            top: parent.top
        }

        height: VLCStyle.globalToolbar_height
        active: root._showCSD
        source: VLCStyle.palette.hasCSDImage
                  ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
                  : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"
    }
}
