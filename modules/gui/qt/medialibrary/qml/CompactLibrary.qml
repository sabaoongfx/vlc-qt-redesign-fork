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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.MediaLibrary

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

// The folder tree of the video library as a card beside the video in the player (Figma
// "Player - customize-8"): address line, item count, search and a list of the folders and
// videos of the current folder. It keeps its own path, so it never moves the library page
// behind the player. A video plays right away, a folder opens in place.
Rectangle {
    id: root

    // The folders from the first level down to the one shown: [{ id, title }, ...]
    property var trail: []

    // The folders left by Back, in the order Forward goes through them
    property var _forward: []

    readonly property var _model: trail.length > 0 ? folderModel : rootModel

    readonly property var _colors: VLCStyle.figmaColors(theme.palette.isDark)

    function open(folder) {
        _forward = []
        trail = [...trail, folder]
    }

    function goTo(depth) {
        _forward = []
        trail = trail.slice(0, depth)
    }

    function back() {
        if (trail.length === 0)
            return

        _forward = [trail[trail.length - 1], ..._forward]
        trail = trail.slice(0, trail.length - 1)
    }

    function forward() {
        if (_forward.length === 0)
            return

        const next = _forward[0]
        _forward = _forward.slice(1)
        trail = [...trail, next]
    }

    color: _colors.section
    radius: VLCStyle.dp(8, VLCStyle.scale)
    clip: true

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Library")

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    MLVideoFolderTreeModel {
        id: rootModel

        ml: MediaLib

        searchPattern: searchField.text
    }

    MLVideoFolderTreeModel {
        id: folderModel

        ml: MediaLib

        searchPattern: searchField.text
    }

    // NOTE: the folder model shows the first level until a folder is given.
    Binding {
        target: folderModel
        property: "parentId"
        value: root.trail[root.trail.length - 1]?.id
        when: root.trail.length > 0
        restoreMode: Binding.RestoreNone
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: VLCStyle.margin_normal
        anchors.bottomMargin: 0

        spacing: VLCStyle.margin_xsmall

        // Address line: back, forward, the path
        RowLayout {
            Layout.fillWidth: true

            spacing: VLCStyle.margin_xxsmall

            Widgets.IconToolButton {
                text: VLCIcons.back
                description: qsTr("Back")
                font.pixelSize: VLCStyle.icon_banner
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                enabled: root.trail.length > 0
                onClicked: root.back()
            }

            Widgets.IconToolButton {
                text: VLCIcons.back
                rotation: 180 // no forward glyph in the icon font
                description: qsTr("Forward")
                font.pixelSize: VLCStyle.icon_banner
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height

                enabled: root._forward.length > 0
                onClicked: root.forward()
            }

            // A long path keeps its last two folders, "... > The Wand > S01"; depth is the length
            // of the trail a name leads to
            Repeater {
                id: crumbs

                readonly property var names: {
                    const all = [{ text: qsTr("Videos"), depth: 0 },
                                 ...root.trail.map((folder, i) => ({ text: folder.title, depth: i + 1 }))]
                    return all.length > 3 ? [{ text: "…", depth: all[all.length - 3].depth }, ...all.slice(all.length - 2)]
                                          : all
                }

                model: names

                delegate: RowLayout {
                    id: crumb

                    required property int index
                    required property var modelData

                    readonly property bool isLast: index === crumbs.names.length - 1

                    Layout.fillWidth: isLast
                    Layout.maximumWidth: implicitWidth
                    Layout.minimumWidth: 0

                    spacing: VLCStyle.margin_xxxsmall

                    Widgets.LabelExt {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0

                        text: crumb.modelData.text
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.pixelSize: VLCStyle.fontSize_large
                        font.weight: crumb.isLast ? Font.DemiBold : Font.Normal
                        color: crumb.isLast ? theme.fg.primary : theme.fg.secondary

                        Accessible.role: Accessible.Button
                        Accessible.name: crumb.modelData.text
                        Accessible.onPressAction: if (!crumb.isLast) root.goTo(crumb.modelData.depth)

                        HoverHandler {
                            enabled: !crumb.isLast
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            enabled: !crumb.isLast
                            onTapped: root.goTo(crumb.modelData.depth)
                        }
                    }

                    Widgets.IconLabel {
                        visible: !crumb.isLast
                        text: VLCIcons.breadcrumb_sep
                        font.pixelSize: VLCStyle.icon_small
                        color: Qt.alpha(theme.fg.secondary, 0.6)
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // Item count and search
        RowLayout {
            Layout.fillWidth: true

            spacing: VLCStyle.margin_xsmall

            Widgets.LabelExt {
                text: qsTr("%1 items").arg(root._model.count)
                font.pixelSize: VLCStyle.fontSize_normal
                color: theme.fg.secondary
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: VLCStyle.dp(150, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(30, VLCStyle.scale)

                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root._colors.search

                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Search")

                TapHandler {
                    onTapped: searchField.forceActiveFocus(Qt.MouseFocusReason)
                }

                Widgets.IconLabel {
                    id: searchIcon

                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.margin_xsmall
                    anchors.verticalCenter: parent.verticalCenter

                    text: VLCIcons.search
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.fg.secondary
                }

                T.TextField {
                    id: searchField

                    anchors.left: searchIcon.right
                    anchors.leftMargin: VLCStyle.margin_xsmall
                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.margin_xsmall
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.fg.primary
                    selectionColor: theme.accent
                    font.pixelSize: VLCStyle.fontSize_normal
                    font.family: VLCStyle.fontFamily

                    Accessible.name: qsTr("Search")

                    Text {
                        anchors.fill: parent

                        visible: searchField.text.length === 0
                        text: qsTr("Search")
                        color: theme.fg.secondary
                        opacity: 0.6
                        font: searchField.font
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // the folder context menu, on the right of the search
            Widgets.LibraryMenuButton {
                Layout.preferredWidth: VLCStyle.bannerButton_width
                Layout.preferredHeight: VLCStyle.bannerButton_height
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.border

            color: root._colors.line
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: root._model

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            delegate: T.ItemDelegate {
                id: row

                required property int index
                required property var model

                readonly property bool isVideo: model.isVideo === true

                width: ListView.view.width
                height: VLCStyle.dp(42, VLCStyle.scale)

                padding: 0

                Accessible.role: Accessible.Button
                Accessible.name: model.title ?? ""

                onClicked: {
                    if (isVideo) {
                        MediaLib.addAndPlay(model.id)
                    } else {
                        root.open({ id: model.id, title: model.title })
                    }
                }

                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: row.hovered ? root._colors.raised : "transparent"
                }

                contentItem: RowLayout {
                    spacing: VLCStyle.margin_xsmall

                    // the cover of a video, a folder glyph for a folder
                    Item {
                        Layout.preferredWidth: VLCStyle.dp(32, VLCStyle.scale)
                        Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
                        Layout.leftMargin: VLCStyle.margin_xxsmall

                        Image {
                            anchors.fill: parent

                            visible: row.isVideo
                            source: row.isVideo ? (row.model.thumbnail ?? "") : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: VLCStyle.dp(64, VLCStyle.scale)
                            sourceSize.height: VLCStyle.dp(64, VLCStyle.scale)
                        }

                        Widgets.IconLabel {
                            anchors.centerIn: parent

                            visible: !row.isVideo
                            text: VLCIcons.ic_fluent_folder_open_24_regular
                            font.pixelSize: VLCStyle.icon_banner
                            color: theme.fg.secondary
                        }
                    }

                    Widgets.LabelExt {
                        Layout.fillWidth: true

                        text: row.model.title ?? ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: theme.fg.primary
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
