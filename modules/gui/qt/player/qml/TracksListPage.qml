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
import QtQuick.Templates as T
import QtQuick.Layouts


import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Dialogs

// redesign: the Figma / prototype right options panel: a tab row (Subtitles, Audio, Video,
// Playback) with a close button, then rounded cards (TRACK, TIMING) on the panel background.
FocusScope {
    id: root

    //FIXME make TrackMenuController a proper type (see TrackMenu)
    required property QtObject trackMenuController

    property int currentTab: 0
    property int preferredWidth: VLCStyle.dp(390, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    // prototype tokens: --side (panel), --card, --field
    readonly property bool _dark: theme.palette?.isDark ?? true
    readonly property color cardColor: _dark ? "#1B1B1B" : "#B9B9B8"
    readonly property color fieldColor: _dark ? "#090909" : "#DEDEDE"

    implicitWidth: preferredWidth
    focus: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: VLCStyle.margin_xsmall
        spacing: VLCStyle.margin_xsmall

        // tab row
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(40, VLCStyle.scale)
            radius: VLCStyle.dp(8, VLCStyle.scale)
            color: root.cardColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: VLCStyle.margin_xxsmall
                spacing: VLCStyle.margin_xxsmall

                Repeater {
                    model: [
                        { label: qsTr("Subtitles"), icon: VLCIcons.audiosub },
                        { label: qsTr("Audio"), icon: VLCIcons.visualization },
                        { label: qsTr("Video"), icon: VLCIcons.tv },
                        { label: qsTr("Playback"), icon: VLCIcons.play }
                    ]

                    delegate: T.AbstractButton {
                        id: tab

                        required property int index
                        required property var modelData

                        readonly property bool current: root.currentTab === index

                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        text: modelData.label
                        Accessible.name: modelData.label

                        onClicked: root.currentTab = index

                        background: Rectangle {
                            radius: VLCStyle.dp(6, VLCStyle.scale)
                            color: tab.current ? Qt.alpha(theme.accent, 0.18)
                                               : (tab.hovered ? Qt.alpha(theme.fg.primary, 0.06) : "transparent")
                        }

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: VLCStyle.margin_xsmall

                                Widgets.IconLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    font.pixelSize: VLCStyle.icon_normal * 0.75
                                    color: tab.current ? theme.accent : theme.fg.secondary
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: tab.current
                                    text: tab.text
                                    color: theme.accent
                                    font.family: VLCStyle.fontFamily
                                    font.pixelSize: VLCStyle.fontSize_normal
                                }
                            }
                        }
                    }
                }

                Widgets.IconToolButton {
                    Layout.alignment: Qt.AlignVCenter
                    text: VLCIcons.close
                    description: qsTr("Close")
                    font.pixelSize: VLCStyle.icon_normal * 0.75
                    width: VLCStyle.bannerButton_width
                    height: VLCStyle.bannerButton_height
                    onClicked: root.trackMenuController.requestClose()
                }
            }
        }

        // Subtitles / Audio / Video: track card and (subtitles, audio) timing card
        Repeater {
            model: [
                { tracks: Player.subtitleTracks, title: qsTr("Subtitle track"), add: qsTr("Add subtitles…") },
                { tracks: Player.audioTracks, title: qsTr("Audio track"), add: qsTr("Add audio track…") },
                { tracks: Player.videoTracks, title: qsTr("Video track"), add: qsTr("Add video track…") }
            ]

            delegate: ColumnLayout {
                required property int index
                required property var modelData

                visible: root.currentTab === index
                Layout.fillWidth: true
                spacing: VLCStyle.margin_xsmall

                Card {
                    title: qsTr("Track")

                    Caption { text: modelData.title }

                    TrackCombo {
                        Layout.fillWidth: true
                        tracksModel: modelData.tracks
                    }

                    LinkButton {
                        text: modelData.add
                        iconText: VLCIcons.add
                        onClicked: {
                            if (index === 0)
                                DialogsProvider.loadSubtitlesFile()
                            else if (index === 1)
                                DialogsProvider.loadAudioFile()
                            else
                                DialogsProvider.loadVideoFile()
                        }
                    }
                }

                Card {
                    visible: index < 2
                    title: qsTr("Timing")

                    DelayEditor {
                        Layout.fillWidth: true
                        audio: index === 1
                    }
                }
            }
        }

        // Playback: speed
        Card {
            visible: root.currentTab === 3
            title: qsTr("Playback")

            RowLayout {
                Layout.fillWidth: true
                Caption { text: qsTr("Playback speed"); Layout.fillWidth: true }
                Caption { text: qsTr("%1×").arg(Player.rate.toFixed(2)); color: theme.fg.primary }
            }

            FieldSlider {
                Layout.fillWidth: true
                from: 0.25
                to: 4
                stepSize: 0.05
                value: Player.rate
                onMoved: Player.rate = value
            }

            LinkButton {
                text: qsTr("More speed settings…")
                iconText: VLCIcons.settings
                onClicked: root.trackMenuController.requestPlaybackSpeedPage()
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ---- building blocks ----

    component Card: Rectangle {
        id: card

        property string title
        default property alias content: cardColumn.data

        Layout.fillWidth: true
        implicitHeight: cardColumn.implicitHeight + VLCStyle.margin_normal * 2
        radius: VLCStyle.dp(8, VLCStyle.scale)
        color: root.cardColor

        ColumnLayout {
            id: cardColumn

            anchors.fill: parent
            anchors.margins: VLCStyle.margin_normal
            spacing: VLCStyle.margin_xsmall

            Text {
                text: card.title.toUpperCase()
                color: Qt.alpha(theme.fg.secondary, 0.8)
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_small
                font.letterSpacing: 1
            }
        }
    }

    component Caption: Text {
        color: theme.fg.secondary
        font.family: VLCStyle.fontFamily
        font.pixelSize: VLCStyle.fontSize_normal
        elide: Text.ElideRight
    }

    component LinkButton: T.AbstractButton {
        id: link

        property string iconText

        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: link.hovered ? Qt.alpha(theme.fg.primary, 0.06) : "transparent"
        }

        contentItem: Row {
            spacing: VLCStyle.margin_xsmall
            leftPadding: VLCStyle.margin_xsmall

            Widgets.IconLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: link.iconText
                font.pixelSize: VLCStyle.icon_normal * 0.66
                color: theme.fg.secondary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: link.text
                color: theme.fg.primary
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }
    }

    // field slider: dark well, dim accent fill, tick marks, narrow accent handle (prototype)
    component FieldSlider: T.Slider {
        id: fs

        implicitHeight: VLCStyle.dp(24, VLCStyle.scale)

        background: Rectangle {
            x: fs.leftPadding
            y: (fs.height - height) / 2
            width: fs.availableWidth
            height: VLCStyle.dp(14, VLCStyle.scale)
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: root.fieldColor

            Rectangle {
                width: fs.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: Qt.alpha(theme.accent, 0.3)
            }

            Repeater {
                model: 7
                delegate: Rectangle {
                    required property int index
                    x: (index + 1) * parent.width / 8
                    y: VLCStyle.dp(4, VLCStyle.scale)
                    width: 1
                    height: parent.height - y * 2
                    color: Qt.alpha(theme.fg.primary, 0.18)
                }
            }
        }

        handle: Rectangle {
            x: fs.leftPadding + fs.visualPosition * (fs.availableWidth - width)
            y: (fs.height - height) / 2
            width: VLCStyle.dp(6, VLCStyle.scale)
            height: VLCStyle.dp(20, VLCStyle.scale)
            radius: VLCStyle.dp(3, VLCStyle.scale)
            color: theme.accent
        }
    }

    // dropdown of the tracks of one kind; the checked track is the current one
    component TrackCombo: Widgets.ComboBoxExt {
        id: combo

        property var tracksModel

        model: tracksModel
        textRole: "display"
        displayText: (count === 0) ? qsTr("None") : currentText

        // follow the checked track
        Repeater {
            id: checkedTracker
            model: combo.tracksModel
            delegate: Item {
                required property int index
                required property bool checked
                required property var model
                onCheckedChanged: if (checked) combo.currentIndex = index
                Component.onCompleted: if (checked) combo.currentIndex = index
            }
        }

        onActivated: (index) => {
            const item = checkedTracker.itemAt(index)
            if (item)
                item.model.checked = true
        }
    }

    component DelayEditor: ColumnLayout {
        id: delay

        property bool audio: false
        readonly property int delayMS: audio ? Player.audioDelayMS : Player.subtitleDelayMS

        function setDelay(ms) {
            ms = Math.max(-10000, Math.min(10000, Math.round(ms)))
            if (audio)
                Player.audioDelayMS = ms
            else
                Player.subtitleDelayMS = ms
        }

        spacing: VLCStyle.margin_xsmall

        RowLayout {
            Layout.fillWidth: true

            Caption {
                Layout.fillWidth: true
                text: delay.audio ? qsTr("Audio delay") : qsTr("Subtitle delay")
            }

            Caption {
                text: qsTr("%1 s").arg((delay.delayMS / 1000).toFixed(1))
                color: theme.fg.primary
            }
        }

        FieldSlider {
            Layout.fillWidth: true
            from: -5000
            to: 5000
            stepSize: 50
            value: delay.delayMS
            onMoved: delay.setDelay(value)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VLCStyle.margin_xxsmall

            Repeater {
                model: [-500, -100, 100, 500]

                delegate: T.AbstractButton {
                    id: step

                    required property int modelData

                    Layout.fillWidth: true
                    implicitHeight: VLCStyle.dp(30, VLCStyle.scale)

                    text: (modelData > 0 ? "+" : "−") + (Math.abs(modelData) / 1000).toFixed(1) + " s"
                    onClicked: delay.setDelay(delay.delayMS + modelData)

                    background: Rectangle {
                        radius: VLCStyle.dp(6, VLCStyle.scale)
                        color: step.hovered ? Qt.alpha(theme.fg.primary, 0.1) : Qt.alpha(theme.fg.primary, 0.04)
                    }

                    contentItem: Text {
                        text: step.text
                        color: theme.fg.secondary
                        font.family: VLCStyle.fontFamily
                        font.pixelSize: VLCStyle.fontSize_small
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        LinkButton {
            text: qsTr("Reset")
            iconText: VLCIcons.history
            visible: delay.delayMS !== 0
            onClicked: delay.setDelay(0)
        }
    }
}
