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

// redesign: the Figma "Subtitles" frames (player side panel): underline tabs Playback / Video /
// Audio / Subtitles, sections of label + control rows, a footer opening the advanced settings.
// Only controls backed by the player are shown.
FocusScope {
    id: root

    //FIXME make TrackMenuController a proper type (see TrackMenu)
    required property QtObject trackMenuController

    property int currentTab: 3
    property int preferredWidth: VLCStyle.dp(400, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    // Figma frame colours (dark) and their light-theme counterparts
    readonly property bool _dark: theme.palette?.isDark ?? true
    readonly property color barColor: _dark ? "#090909" : "#BDBDBC"     // tab bar, footer
    readonly property color sectionColor: _dark ? "#0E0E0E" : "#D2D2D1" // section blocks
    readonly property color gapColor: _dark ? "#191919" : "#C1C1C0"     // between sections
    readonly property color fieldColor: _dark ? "#090909" : "#E9E9E8"   // value fields
    readonly property color labelColor: _dark ? "#8F8F8F" : "#4A4A4A"
    readonly property color textColor: _dark ? "#E3E3E3" : "#151515"

    implicitWidth: preferredWidth
    focus: true

    Rectangle {
        anchors.fill: parent
        color: root.gapColor
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- tab bar ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(50, VLCStyle.scale)
            color: root.barColor

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: VLCStyle.margin_xsmall
                anchors.rightMargin: VLCStyle.margin_xsmall
                spacing: 0

                Repeater {
                    model: [
                        { label: qsTr("Playback"), icon: VLCIcons.play },
                        { label: qsTr("Video"), icon: VLCIcons.topbar_video },
                        { label: qsTr("Audio"), icon: VLCIcons.visualization },
                        { label: qsTr("Subtitles"), icon: VLCIcons.audiosub }
                    ]

                    delegate: T.AbstractButton {
                        id: tab

                        required property int index
                        required property var modelData

                        readonly property bool current: root.currentTab === index
                        readonly property color tint: (current || hovered) ? root.textColor : root.labelColor

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        text: modelData.label
                        Accessible.name: modelData.label
                        onClicked: root.currentTab = index

                        background: Item {
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - VLCStyle.margin_xsmall
                                height: VLCStyle.dp(2, VLCStyle.scale)
                                color: theme.accent
                                visible: tab.current
                            }
                        }

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: VLCStyle.dp(6, VLCStyle.scale)

                                Widgets.IconLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                    color: tab.current ? theme.accent : tab.tint
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.text
                                    color: tab.tint
                                    font.family: VLCStyle.fontFamily
                                    font.pixelSize: VLCStyle.fontSize_normal
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- pages ----
        Flickable {
            id: pageFlick

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            contentWidth: width
            contentHeight: pages.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            ColumnLayout {
                id: pages

                width: pageFlick.width
                spacing: 0

                // Playback
                Section {
                    visible: root.currentTab === 0
                    title: ""

                    ValueRow {
                        label: qsTr("Speed")
                        value: qsTr("%1x").arg(+Player.rate.toFixed(2))
                        editable: true
                        onEdited: (text) => {
                            const v = parseFloat(text)
                            if (!isNaN(v))
                                Player.rate = Math.max(0.25, Math.min(4, v))
                        }
                    }

                    RangeSlider {
                        from: 0.25
                        to: 2
                        stepSize: 0.05
                        value: Player.rate
                        labels: ["0.25", "0.5", "0.75", "1", "1.25", "1.5", "1.75", "2"]
                        onMoved: (value) => { Player.rate = value }
                    }

                    ComboRow {
                        visible: Player.hasAudioVisualization
                        label: qsTr("Audio Visualizer")
                        choices: Player.audioVisualization
                    }
                }

                // Video
                Section {
                    visible: root.currentTab === 1
                    title: qsTr("Defaults")

                    ComboRow { label: qsTr("Video Track"); choices: Player.videoTracks }
                    ComboRow { label: qsTr("Zoom"); choices: Player.zoom }
                    ComboRow { label: qsTr("Aspect Ratio"); choices: Player.aspectRatio }
                    ComboRow { label: qsTr("Crop"); choices: Player.crop }
                    ComboRow { label: qsTr("Fit"); choices: Player.fit }
                    ComboRow { label: qsTr("Deinterlace"); choices: Player.deinterlace }
                }

                Section {
                    visible: root.currentTab === 1
                    title: qsTr("Filters")

                    ExpandRow {
                        label: qsTr("Essential")
                        onClicked: DialogsProvider.extendedDialog()
                    }
                }

                // Audio
                Section {
                    visible: root.currentTab === 2
                    title: qsTr("Defaults")

                    ComboRow { label: qsTr("Audio Track"); choices: Player.audioTracks }
                    ComboRow { label: qsTr("Stereo Mode"); choices: Player.audioStereoMode }
                    ComboRow { label: qsTr("Mix Mode"); choices: Player.audioMixMode }
                }

                Section {
                    visible: root.currentTab === 2
                    title: qsTr("Synchronization")

                    DelayRow { audio: true }
                }

                Section {
                    visible: root.currentTab === 2
                    title: qsTr("Filters")

                    ExpandRow {
                        label: qsTr("Equalizer")
                        onClicked: DialogsProvider.extendedDialog()
                    }
                }

                // Subtitles
                Section {
                    visible: root.currentTab === 3
                    title: qsTr("Defaults")

                    ComboRow { label: qsTr("Subtitle Track"); choices: Player.subtitleTracks }

                    LinkRow {
                        text: qsTr("Add subtitle file…")
                        onClicked: DialogsProvider.loadSubtitlesFile()
                    }
                }

                Section {
                    visible: root.currentTab === 3
                    title: qsTr("Synchronization")

                    DelayRow { audio: false }

                    ValueRow {
                        label: qsTr("Subtitle Speed")
                        value: qsTr("%1 fps").arg(Player.subtitleFPS.toFixed(3))
                        editable: true
                        onEdited: (text) => {
                            const v = parseFloat(text)
                            if (!isNaN(v))
                                Player.subtitleFPS = Math.max(0.1, Math.min(10, v))
                        }
                    }

                    RangeSlider {
                        from: 0.1
                        to: 10
                        stepSize: 0.05
                        value: Player.subtitleFPS
                        onMoved: (value) => { Player.subtitleFPS = value }
                    }
                }
            }
        }

        // ---- footer ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(64, VLCStyle.scale)
            color: root.barColor

            T.AbstractButton {
                id: advanced

                anchors.centerIn: parent
                implicitWidth: advancedRow.implicitWidth + VLCStyle.margin_normal * 2
                implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

                onClicked: DialogsProvider.extendedDialog()

                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: advanced.hovered ? root.gapColor : "transparent"
                }

                contentItem: Item {
                    Row {
                        id: advancedRow

                        anchors.centerIn: parent
                        spacing: VLCStyle.margin_xsmall

                        Widgets.IconLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: VLCIcons.settings
                            font.pixelSize: VLCStyle.dp(18, VLCStyle.scale)
                            color: root.labelColor
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Open Advanced Settings")
                            color: root.labelColor
                            font.family: VLCStyle.fontFamily
                            font.pixelSize: VLCStyle.fontSize_large
                        }
                    }
                }
            }
        }
    }

    // ---- building blocks ----

    // a section block: optional title, rows, separated from the next one by the gap colour
    component Section: Rectangle {
        id: section

        property string title
        default property alias content: sectionColumn.data

        Layout.fillWidth: true
        Layout.bottomMargin: visible ? VLCStyle.dp(8, VLCStyle.scale) : 0
        implicitHeight: sectionColumn.implicitHeight + VLCStyle.margin_normal * 2
        color: root.sectionColor

        ColumnLayout {
            id: sectionColumn

            anchors.fill: parent
            anchors.margins: VLCStyle.margin_normal
            anchors.leftMargin: VLCStyle.margin_large
            spacing: VLCStyle.margin_small

            Text {
                visible: section.title !== ""
                text: section.title
                color: root.textColor
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_xlarge
                Layout.bottomMargin: VLCStyle.margin_xxsmall
            }
        }
    }

    component RowLabel: Text {
        color: root.labelColor
        font.family: VLCStyle.fontFamily
        font.pixelSize: VLCStyle.fontSize_large
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    // label + value field (optionally editable)
    component ValueRow: RowLayout {
        id: valueRow

        property string label
        property string value
        property bool editable: false

        signal edited(string text)

        Layout.fillWidth: true
        spacing: VLCStyle.margin_small

        RowLabel { text: valueRow.label }

        Rectangle {
            Layout.preferredWidth: VLCStyle.dp(136, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: root.fieldColor

            TextInput {
                id: valueInput

                anchors.fill: parent
                anchors.leftMargin: VLCStyle.margin_small
                anchors.rightMargin: VLCStyle.margin_small
                verticalAlignment: TextInput.AlignVCenter
                readOnly: !valueRow.editable
                text: valueRow.value
                color: root.textColor
                selectionColor: theme.accent
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_large
                onEditingFinished: {
                    if (valueRow.editable)
                        valueRow.edited(text)
                    valueInput.text = Qt.binding(() => valueRow.value)
                }
            }
        }
    }

    // label + dropdown of a choice model (tracks or player options with a checked role)
    component ComboRow: RowLayout {
        id: comboRow

        property string label
        property var choices

        Layout.fillWidth: true
        spacing: VLCStyle.margin_small

        RowLabel { text: comboRow.label }

        Widgets.ComboBoxExt {
            id: combo

            Layout.preferredWidth: VLCStyle.dp(218, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(44, VLCStyle.scale)

            model: comboRow.choices
            textRole: "display"
            displayText: (count === 0) ? qsTr("None") : currentText

            // follow the checked entry
            Repeater {
                id: checkedTracker

                model: comboRow.choices
                delegate: Item {
                    required property int index
                    required property var model
                    readonly property bool isChecked: !!model.checked
                    onIsCheckedChanged: if (isChecked) combo.currentIndex = index
                    Component.onCompleted: if (isChecked) combo.currentIndex = index
                }
            }

            onActivated: (index) => {
                const item = checkedTracker.itemAt(index)
                if (item)
                    item.model.checked = true
            }
        }
    }

    // Figma slider: dim accent fill on a dark track, narrow accent handle, tick labels below
    component RangeSlider: ColumnLayout {
        id: range

        property real from: 0
        property real to: 1
        property real stepSize: 0
        property real value: 0
        property var labels: []

        signal moved(real value)

        Layout.fillWidth: true
        spacing: VLCStyle.margin_xxsmall

        T.Slider {
            id: slider

            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(24, VLCStyle.scale)

            from: range.from
            to: range.to
            stepSize: range.stepSize
            value: range.value
            onMoved: range.moved(slider.value)

            background: Rectangle {
                x: slider.leftPadding
                y: (slider.height - height) / 2
                width: slider.availableWidth
                height: VLCStyle.dp(16, VLCStyle.scale)
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: root.fieldColor

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: Qt.alpha(theme.accent, 0.3)
                }

                Repeater {
                    model: Math.max(range.labels.length - 2, 0)
                    delegate: Rectangle {
                        required property int index
                        x: (index + 1) * parent.width / (range.labels.length - 1)
                        y: VLCStyle.dp(5, VLCStyle.scale)
                        width: 1
                        height: parent.height - y * 2
                        color: Qt.alpha(root.labelColor, 0.6)
                    }
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: (slider.height - height) / 2
                width: VLCStyle.dp(7, VLCStyle.scale)
                height: VLCStyle.dp(22, VLCStyle.scale)
                radius: VLCStyle.dp(3, VLCStyle.scale)
                color: theme.accent
            }
        }

        Item {
            visible: range.labels.length > 0
            Layout.fillWidth: true
            implicitHeight: VLCStyle.fontHeight_small

            Repeater {
                model: range.labels
                delegate: Text {
                    required property int index
                    required property string modelData
                    x: index * (parent.width - width) / Math.max(range.labels.length - 1, 1)
                    text: modelData
                    color: root.labelColor
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_small
                }
            }
        }
    }

    // delay field + slider (-10 s .. +10 s)
    component DelayRow: ColumnLayout {
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

        Layout.fillWidth: true
        spacing: VLCStyle.margin_small

        ValueRow {
            label: delay.audio ? qsTr("Audio Track Delay") : qsTr("Subtitle Track Delay")
            value: qsTr("%1 s").arg((delay.delayMS / 1000).toFixed(3))
            editable: true
            onEdited: (text) => {
                const v = parseFloat(text)
                if (!isNaN(v))
                    delay.setDelay(v * 1000)
            }
        }

        RangeSlider {
            from: -10000
            to: 10000
            stepSize: 50
            value: delay.delayMS
            labels: ["-10 s", "0 s", "+10 s"]
            onMoved: (value) => delay.setDelay(value)
        }
    }

    // "Expand Settings" row: opens the full effects dialog
    component ExpandRow: ColumnLayout {
        id: expand

        property string label
        signal clicked()

        Layout.fillWidth: true
        spacing: VLCStyle.margin_xsmall

        RowLabel { text: expand.label }

        T.AbstractButton {
            id: expandBtn

            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(46, VLCStyle.scale)

            onClicked: expand.clicked()

            background: Rectangle {
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: expandBtn.hovered ? root.gapColor : root.fieldColor
            }

            contentItem: RowLayout {
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: VLCStyle.margin_normal
                    text: qsTr("Expand Settings")
                    color: root.textColor
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_large
                }

                Widgets.IconLabel {
                    Layout.rightMargin: VLCStyle.margin_normal
                    text: VLCIcons.ic_fluent_chevron_right_24
                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                    color: root.labelColor
                }
            }
        }
    }

    component LinkRow: T.AbstractButton {
        id: link

        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: link.hovered ? root.gapColor : "transparent"
        }

        contentItem: Row {
            spacing: VLCStyle.margin_xsmall

            Widgets.IconLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: VLCIcons.add
                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                color: root.labelColor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: link.text
                color: root.textColor
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_large
            }
        }
    }
}
