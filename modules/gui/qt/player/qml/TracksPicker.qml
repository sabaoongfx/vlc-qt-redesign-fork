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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Dialogs

// redesign: the Figma "Languages and tracks" picker (Video / Audio / Subtitles): the media's tracks
// with a tick on the current one, the loaded subtitle files, the output devices, and a button
// opening the full side panel on the same tab
T.Popup {
    id: root

    // 0 Video, 1 Audio, 2 Subtitles
    property int currentTab: 2

    // the full side panel's tab for this picker's tab (TracksMenu: 1 Video, 2 Audio, 3 Subtitles)
    signal preferencesRequested(int panelTab)

    // a press outside closes the popup before its button gets the click (see TracksMenu.toggle)
    property double _closedAt: 0

    function toggle(tab) {
        if (visible)
            close()
        else if (Date.now() - _closedAt > 300) {
            if (tab !== undefined)
                currentTab = tab
            open()
        }
    }

    Connections {
        target: root
        function onClosed() { root._closedAt = Date.now() }
    }

    // Figma: 400x524, in the player's panel area above the bottom bar, right side
    readonly property bool _inPanelArea: root.parent?.panelArea !== undefined
    width: VLCStyle.dp(400, VLCStyle.scale)
    height: Math.min(VLCStyle.dp(524, VLCStyle.scale), _inPanelArea ? parent.panelArea.height : parent.height)
    x: _inPanelArea ? parent.panelArea.x + parent.panelArea.width - width : parent.width - width
    y: _inPanelArea ? parent.panelArea.y + parent.panelArea.height - height : parent.height - height

    padding: 0
    focus: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    readonly property var _figma: VLCStyle.figmaColors(theme.palette?.isDark ?? true)
    readonly property real _radius: VLCStyle.dp(10, VLCStyle.scale)
    readonly property real _rowHeight: VLCStyle.dp(44, VLCStyle.scale)

    background: Rectangle {
        radius: root._radius
        // Figma: the section colour at 95% over a blur; solid here (no blur behind a popup, the video
        // showed through)
        color: root._figma.section
    }

    contentItem: Item {
        // a popup's content is not parented to the popup: without its own context the scroll bar
        // had no palette and drew in the placeholder magenta (TracksMenu does the same)
        readonly property ColorContext colorContext: ColorContext {
            colorSet: theme.colorSet
            palette: theme.palette
        }

        // ---- tab bar ----
        Rectangle {
            id: tabBar

            width: parent.width
            height: VLCStyle.dp(50, VLCStyle.scale)
            topLeftRadius: root._radius
            topRightRadius: root._radius
            color: root._figma.bar

            // Figma: three equal tabs 14px from the edges, 17px apart, the underline across the tab
            Row {
                x: VLCStyle.dp(14, VLCStyle.scale)
                height: parent.height
                spacing: VLCStyle.dp(17, VLCStyle.scale)

                Repeater {
                    model: [
                        { label: qsTr("Video"), icon: VLCIcons.topbar_video },
                        { label: qsTr("Audio"), icon: VLCIcons.visualization },
                        { label: qsTr("Subtitles"), icon: VLCIcons.audiosub }
                    ]

                    delegate: T.AbstractButton {
                        id: tab

                        required property int index
                        required property var modelData

                        readonly property bool current: root.currentTab === index

                        width: (tabBar.width - VLCStyle.dp(14 * 2 + 17 * 2, VLCStyle.scale)) / 3
                        height: parent.height

                        text: modelData.label
                        Accessible.name: modelData.label
                        onClicked: root.currentTab = index

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        background: Item {
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: VLCStyle.dp(2, VLCStyle.scale)
                                color: theme.accent
                                visible: tab.current
                            }
                        }

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: VLCStyle.dp(10, VLCStyle.scale)

                                Widgets.IconLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                    color: tab.current ? theme.accent
                                                       : (tab.hovered ? root._figma.label : root._figma.tabIcon)
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.text
                                    color: (tab.current || tab.hovered) ? root._figma.label : root._figma.hint
                                    font.family: VLCStyle.fontFamily
                                    font.pixelSize: VLCStyle.fontSize_normal
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- lists ----
        Flickable {
            id: flick

            anchors.top: tabBar.bottom
            anchors.bottom: footer.top
            anchors.bottomMargin: VLCStyle.dp(8, VLCStyle.scale)
            width: parent.width

            clip: true
            contentWidth: width
            contentHeight: lists.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            Column {
                id: lists

                width: flick.width

                // Video and Audio: the media's tracks; Subtitles: the media's, then the loaded files
                TrackSection {
                    title: qsTr("Embedded Tracks")
                    tracks: [Player.videoTracks, Player.audioTracks, Player.subtitleTracks][root.currentTab]
                    external: false
                    showNone: true
                }

                // Figma Audio: a 1px line, then the output devices with a refresh button
                Item {
                    width: parent.width
                    height: VLCStyle.dp(14, VLCStyle.scale)
                    visible: root.currentTab !== 0

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: VLCStyle.dp(1, VLCStyle.scale)
                        width: parent.width
                        height: VLCStyle.dp(1, VLCStyle.scale)
                        color: root._figma.line
                        visible: root.currentTab === 1
                    }
                }

                SectionHeading {
                    visible: root.currentTab === 1
                    text: qsTr("Output Device")

                    HeadingButton {
                        glyph: VLCIcons.ic_fluent_arrow_sync_24_regular
                        description: qsTr("Refresh output devices")
                        onClicked: Player.audioDevices.refresh()
                    }
                }

                Repeater {
                    model: root.currentTab === 1 ? Player.audioDevices : null

                    delegate: TrackRow {
                        required property var model

                        // the devices by name only, not the output's "Default" entry
                        visible: !model.isDefault

                        text: model.display
                        ticked: model.checked
                        onClicked: model.checked = true
                    }
                }

                TrackSection {
                    visible: root.currentTab === 2
                    title: qsTr("External Tracks")
                    tracks: Player.subtitleTracks
                    external: true
                    showNone: false

                    HeadingButton {
                        glyph: VLCIcons.edit
                        description: qsTr("Subtitle settings")
                        onClicked: {
                            root.close()
                            root.preferencesRequested(3)
                        }
                    }

                    HeadingButton {
                        glyph: VLCIcons.add
                        description: qsTr("Add subtitle file")
                        onClicked: {
                            root.close()
                            DialogsProvider.loadSubtitlesFile()
                        }
                    }
                }
            }
        }

        // ---- footer ---- (Figma: a 360x32 field-coloured button 20px above the bottom)
        T.AbstractButton {
            id: footer

            x: VLCStyle.dp(20, VLCStyle.scale)
            y: parent.height - height - VLCStyle.dp(20, VLCStyle.scale)
            width: parent.width - 2 * x
            height: VLCStyle.dp(32, VLCStyle.scale)

            text: qsTr("Show Preferences")
            Accessible.name: text

            onClicked: {
                root.close()
                root.preferencesRequested(root.currentTab + 1)
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }

            background: Rectangle {
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: footer.hovered ? root._figma.raised : root._figma.bar
            }

            contentItem: Text {
                text: footer.text
                color: footer.hovered ? root._figma.label : root._figma.hint
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_normal
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // a section title (Figma: 14px grey at x 28, centred 31px into its 56px row), buttons on the right
    component SectionHeading: Item {
        id: heading

        property alias text: label.text
        default property alias buttons: buttonRow.data

        width: parent?.width ?? 0
        height: VLCStyle.dp(56, VLCStyle.scale)

        Text {
            id: label

            x: VLCStyle.dp(28, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: VLCStyle.dp(3, VLCStyle.scale)
            color: root._figma.hint
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_normal
        }

        Row {
            id: buttonRow

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(24, VLCStyle.scale)
            anchors.verticalCenter: label.verticalCenter
            spacing: VLCStyle.dp(14, VLCStyle.scale)
        }
    }

    // a 30px icon button in a heading (Figma: 14-20px grey strokes)
    component HeadingButton: T.AbstractButton {
        id: button

        property string glyph
        property string description

        width: VLCStyle.dp(30, VLCStyle.scale)
        height: VLCStyle.dp(30, VLCStyle.scale)

        Accessible.name: description

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        background: Rectangle {
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: button.hovered ? root._figma.iconHover : "transparent"
        }

        contentItem: Widgets.IconLabel {
            text: button.glyph
            font.pixelSize: VLCStyle.dp(20, VLCStyle.scale)
            color: button.hovered ? root._figma.label : root._figma.hint
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    // a heading and the tracks of one model, the embedded or the external ones, "None" first
    component TrackSection: Column {
        id: section

        property string title
        property var tracks: null
        property bool external: false
        property bool showNone: false
        default property alias buttons: heading.buttons

        width: parent?.width ?? 0

        // "None" is ticked when no track of the model is selected, embedded or loaded
        property int _selected: {
            let n = 0
            for (let i = 0; i < trackRepeater.count; ++i)
                if (trackRepeater.itemAt(i)?.selected)
                    ++n
            return n
        }

        SectionHeading {
            id: heading
            text: section.title
        }

        TrackRow {
            visible: section.showNone
            text: qsTr("None")
            ticked: section._selected === 0
            onClicked: {
                for (let i = 0; i < trackRepeater.count; ++i)
                    trackRepeater.itemAt(i)?.deselect()
            }
        }

        Repeater {
            id: trackRepeater

            model: section.tracks

            delegate: TrackRow {
                required property var model

                // the embedded list and the external list split one model
                readonly property bool selected: model.checked

                visible: model.external === section.external
                text: model.display
                ticked: visible && selected
                onClicked: model.checked = true

                function deselect() {
                    if (model.checked)
                        model.checked = false
                }
            }
        }
    }

    // a 44px row, the label at x 62, an accent tick at x 29 on the current one
    component TrackRow: T.AbstractButton {
        id: row

        property bool ticked: false

        width: parent?.width ?? 0
        height: visible ? root._rowHeight : 0

        Accessible.role: Accessible.RadioButton
        Accessible.name: text
        Accessible.checked: ticked

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        background: Rectangle {
            color: row.hovered ? root._figma.iconHover : "transparent"
        }

        contentItem: Item {
            Widgets.IconLabel {
                x: VLCStyle.dp(28, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                visible: row.ticked
                text: VLCIcons.check
                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                color: theme.accent
            }

            Text {
                x: VLCStyle.dp(62, VLCStyle.scale)
                width: parent.width - x - VLCStyle.dp(20, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                text: row.text
                elide: Text.ElideRight
                color: row.hovered ? root._figma.label : root._figma.title
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }
    }
}
