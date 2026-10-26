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

    // Figma frame colours (VLCStyle.figmaDark / figmaDay)
    readonly property bool _dark: theme.palette?.isDark ?? true
    readonly property var _figma: VLCStyle.figmaColors(_dark)
    readonly property color barColor: _figma.bar
    readonly property color sectionColor: _figma.section
    readonly property color gapColor: _figma.raised
    readonly property color lineColor: _figma.line
    readonly property color fieldColor: _figma.field
    readonly property color labelColor: _figma.hint
    readonly property color valueColor: _figma.label
    readonly property color headingColor: _figma.title
    readonly property color iconColor: _figma.tabIcon

    implicitWidth: preferredWidth
    focus: true

    // the equalizer, compressor and video filter cards
    EffectsController {
        id: effects
        ctx: MainCtx
    }
    readonly property int _rev: effects.revision

    // the adjust filter is on while one of its values is off neutral
    function setAdjust(option, value) {
        effects.setVideoValue(option, value)
        const neutral = { hue: 0, brightness: 1, contrast: 1, saturation: 1, gamma: 1 }
        let changed = false
        for (const o in neutral)
            changed = changed || Math.abs(Number(effects.videoValue(o)) - neutral[o]) > 0.001
        effects.setVideoFilterEnabled("adjust", changed)
    }

    // Figma: the whole panel is the section colour, 2px lines divide the sections
    Rectangle {
        anchors.fill: parent
        color: root.sectionColor
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- tab bar ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(50, VLCStyle.scale)
            color: root.barColor

            // Figma: tabs sized to their content, underline 8px wider than the content on
            // each side, 14px from the panel edges, the rest of the width spread between them
            Row {
                id: tabRow

                readonly property real tabsWidth: {
                    let w = 0
                    for (let i = 0; i < tabRepeater.count; ++i)
                        w += tabRepeater.itemAt(i)?.implicitWidth ?? 0
                    return w
                }

                anchors.fill: parent
                anchors.leftMargin: VLCStyle.dp(14, VLCStyle.scale)
                anchors.rightMargin: VLCStyle.dp(14, VLCStyle.scale)
                spacing: Math.max(0, (width - tabsWidth) / Math.max(tabRepeater.count - 1, 1))

                Repeater {
                    id: tabRepeater

                    model: [
                        { label: qsTr("Playback"), icon: VLCIcons.play },
                        { label: qsTr("Video"), icon: VLCIcons.topbar_video },
                        { label: qsTr("Audio"), icon: VLCIcons.visualization },
                        { label: qsTr("Subtitles"), icon: VLCIcons.audiosub }
                    ]

                    delegate: T.AbstractButton {
                        HoverHandler { cursorShape: Qt.PointingHandCursor } // redesign: hand cursor, like the prototype
                        id: tab

                        required property int index
                        required property var modelData

                        readonly property bool current: root.currentTab === index
                        readonly property color tint: (current || hovered) ? root.valueColor : root.labelColor

                        height: tabRow.height
                        implicitWidth: implicitContentWidth + leftPadding + rightPadding
                        leftPadding: VLCStyle.margin_xsmall
                        rightPadding: VLCStyle.margin_xsmall

                        text: modelData.label
                        Accessible.name: modelData.label
                        onClicked: root.currentTab = index

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
                            implicitWidth: tabContent.implicitWidth

                            Row {
                                id: tabContent

                                anchors.centerIn: parent
                                spacing: VLCStyle.dp(10, VLCStyle.scale)

                                Widgets.IconLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                    color: tab.current ? theme.accent : (tab.hovered ? root.valueColor : root.iconColor)
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
                        accessibleName: qsTr("Speed")
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

                    EffectCard {
                        label: qsTr("Essential")

                        EffectSlider {
                            label: qsTr("Hue"); from: -180; to: 180; stepSize: 1
                            value: (root._rev, Number(effects.videoValue("hue")))
                            valueText: Math.round(value) + "°"
                            onMoved: (v) => root.setAdjust("hue", v)
                        }
                        EffectSlider {
                            label: qsTr("Brightness"); from: 0; to: 2; stepSize: 0.01
                            value: (root._rev, Number(effects.videoValue("brightness")))
                            onMoved: (v) => root.setAdjust("brightness", v)
                        }
                        EffectSlider {
                            label: qsTr("Contrast"); from: 0; to: 2; stepSize: 0.01
                            value: (root._rev, Number(effects.videoValue("contrast")))
                            onMoved: (v) => root.setAdjust("contrast", v)
                        }
                        EffectSlider {
                            label: qsTr("Saturation"); from: 0; to: 3; stepSize: 0.01
                            value: (root._rev, Number(effects.videoValue("saturation")))
                            onMoved: (v) => root.setAdjust("saturation", v)
                        }
                        EffectSlider {
                            label: qsTr("Gamma"); from: 0.01; to: 10; stepSize: 0.01
                            value: (root._rev, Number(effects.videoValue("gamma")))
                            onMoved: (v) => root.setAdjust("gamma", v)
                        }
                        // the next three are off at 0
                        EffectSlider {
                            label: qsTr("Sharpen Sigma"); from: 0; to: 2; stepSize: 0.01
                            value: (root._rev, effects.videoFilterEnabled("sharpen") ? Number(effects.videoValue("sharpen-sigma")) : 0)
                            onMoved: (v) => {
                                effects.setVideoValue("sharpen-sigma", v)
                                effects.setVideoFilterEnabled("sharpen", v > 0)
                            }
                        }
                        EffectSlider {
                            label: qsTr("Banding Removal Radius"); from: 0; to: 32; stepSize: 1
                            value: (root._rev, effects.videoFilterEnabled("gradfun") ? Number(effects.videoValue("gradfun-radius")) : 0)
                            valueText: value < 4 ? qsTr("Off") : Math.round(value)
                            onMoved: (v) => {
                                if (v >= 4)
                                    effects.setVideoValue("gradfun-radius", Math.round(v))
                                effects.setVideoFilterEnabled("gradfun", v >= 4)
                            }
                        }
                        EffectSlider {
                            label: qsTr("Film Grain Variance"); from: 0; to: 10; stepSize: 0.1
                            value: (root._rev, effects.videoFilterEnabled("grain") ? Number(effects.videoValue("grain-variance")) : 0)
                            onMoved: (v) => {
                                effects.setVideoValue("grain-variance", v)
                                effects.setVideoFilterEnabled("grain", v > 0)
                            }
                        }
                    }

                    EffectCard {
                        label: qsTr("Colors")

                        ColorToggleRow {
                            label: qsTr("Color Extraction")
                            filter: "extract"
                            option: "extract-component"
                        }

                        CardLine {}

                        ColorToggleRow {
                            id: threshold
                            label: qsTr("Color Threshold")
                            filter: "colorthres"
                            option: "colorthres-color"
                        }
                        EffectSlider {
                            label: qsTr("Saturation"); from: 0; to: 255; stepSize: 1
                            active: threshold.on
                            value: (root._rev, Number(effects.videoValue("colorthres-saturationthres")))
                            valueText: Math.round(value)
                            onMoved: (v) => effects.setVideoValue("colorthres-saturationthres", Math.round(v))
                        }
                        EffectSlider {
                            label: qsTr("Similarity"); from: 0; to: 255; stepSize: 1
                            active: threshold.on
                            value: (root._rev, Number(effects.videoValue("colorthres-similaritythres")))
                            valueText: Math.round(value)
                            onMoved: (v) => effects.setVideoValue("colorthres-similaritythres", Math.round(v))
                        }

                        CardLine {}

                        FilterToggleRow { label: qsTr("Negate Colors"); filter: "invert" }
                        FilterToggleRow { label: qsTr("Posterize"); filter: "posterize" }

                        CardLine {}

                        FilterToggleRow { id: gradient; label: qsTr("Gradient"); filter: "gradient" }
                        CardCombo {
                            enabled: gradient.on
                            model: [qsTr("Gradient"), qsTr("Edge"), qsTr("Hough")]
                            readonly property var modes: ["gradient", "edge", "hough"]
                            currentIndex: (root._rev, Math.max(0, modes.indexOf(String(effects.videoValue("gradient-mode")))))
                            onActivated: (i) => effects.setVideoValue("gradient-mode", modes[i])
                        }
                        OptionToggleRow { label: qsTr("Color"); option: "gradient-color"; enabled: gradient.on }
                        OptionToggleRow { label: qsTr("Cartoon"); option: "gradient-cartoon"; enabled: gradient.on }

                        CardLine {}

                        EffectSlider {
                            label: qsTr("Sepia Intensity"); from: 0; to: 255; stepSize: 1
                            value: (root._rev, effects.videoFilterEnabled("sepia") ? Number(effects.videoValue("sepia-intensity")) : 0)
                            valueText: Math.round(value)
                            onMoved: (v) => {
                                effects.setVideoValue("sepia-intensity", Math.round(v))
                                effects.setVideoFilterEnabled("sepia", v > 0)
                            }
                        }
                    }

                    EffectCard {
                        label: qsTr("Crop")

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: VLCStyle.margin_xsmall
                            rowSpacing: VLCStyle.margin_xsmall

                            CropField { id: cropTop; side: "top"; label: qsTr("Top"); onEdited: (v) => { if (linkTB.checked) cropBottom.apply(v) } }
                            CropField { id: cropBottom; side: "bottom"; label: qsTr("Bottom"); onEdited: (v) => { if (linkTB.checked) cropTop.apply(v) } }
                            LinkToggle { id: linkTB; accessibleName: qsTr("Same top and bottom") }
                            CropField { id: cropLeft; side: "left"; label: qsTr("Left"); onEdited: (v) => { if (linkLR.checked) cropRight.apply(v) } }
                            CropField { id: cropRight; side: "right"; label: qsTr("Right"); onEdited: (v) => { if (linkLR.checked) cropLeft.apply(v) } }
                            LinkToggle { id: linkLR; accessibleName: qsTr("Same left and right") }
                        }
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

                    EffectCard {
                        label: qsTr("Equalizer")

                        // Figma EQ presets: None (the equalizer off) and VLC's presets
                        CardCombo {
                            model: effects.equalizerPresetNames
                            currentIndex: (root._rev, effects.equalizerPreset())
                            onActivated: (i) => effects.setEqualizerPreset(i)
                        }

                        EffectSlider {
                            label: qsTr("Preamp"); from: -20; to: 20; stepSize: 0.1; field: true
                            active: (root._rev, effects.audioFilterEnabled("equalizer"))
                            value: (root._rev, effects.audioValue("equalizer-preamp"))
                            valueText: value.toFixed(1) + " dB"
                            onMoved: (v) => {
                                effects.setAudioValue("equalizer-preamp", v)
                                effects.setAudioFilterEnabled("equalizer", true)
                            }
                        }

                        Repeater {
                            model: effects.equalizerBandNames
                            delegate: EffectSlider {
                                required property int index
                                required property string modelData
                                label: modelData; from: -20; to: 20; stepSize: 0.1; field: true
                                active: (root._rev, effects.audioFilterEnabled("equalizer"))
                                value: (root._rev, effects.equalizerBands()[index] ?? 0)
                                valueText: value.toFixed(1) + " dB"
                                onMoved: (v) => effects.setEqualizerBand(index, v)
                            }
                        }
                    }

                    EffectCard {
                        label: qsTr("Compressor")

                        FilterToggleRow { id: compressor; label: qsTr("Enable"); filter: "compressor"; audio: true }

                        Repeater {
                            // the dialog's ranges (Compressor in extended_panels.cpp)
                            model: [
                                { option: "compressor-rms-peak", label: qsTr("RMS / Peak"), from: 0, to: 1, step: 0.01, unit: "", digits: 2 },
                                { option: "compressor-attack", label: qsTr("Attack"), from: 1.5, to: 400, step: 0.5, unit: " ms", digits: 1 },
                                { option: "compressor-release", label: qsTr("Release"), from: 2, to: 800, step: 1, unit: " ms", digits: 1 },
                                { option: "compressor-threshold", label: qsTr("Threshold"), from: -30, to: 0, step: 0.1, unit: " dB", digits: 1 },
                                { option: "compressor-ratio", label: qsTr("Ratio"), from: 1, to: 20, step: 0.1, unit: " : 1", digits: 1 },
                                { option: "compressor-knee", label: qsTr("Knee Radius"), from: 1, to: 10, step: 0.1, unit: " dB", digits: 1 },
                                { option: "compressor-makeup-gain", label: qsTr("Makeup Gain"), from: 0, to: 24, step: 0.1, unit: " dB", digits: 1 }
                            ]
                            delegate: EffectSlider {
                                required property var modelData
                                label: modelData.label; from: modelData.from; to: modelData.to; stepSize: modelData.step
                                active: compressor.on
                                value: (root._rev, effects.audioValue(modelData.option))
                                valueText: value.toFixed(modelData.digits) + modelData.unit
                                onMoved: (v) => effects.setAudioValue(modelData.option, v)
                            }
                        }
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
                        accessibleName: qsTr("Subtitle Speed")
                        onMoved: (value) => { Player.subtitleFPS = value }
                    }
                }
            }
        }

        // ---- footer ---- (Figma: on the panel colour under a 1px line)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(64, VLCStyle.scale)
            color: root.sectionColor

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: VLCStyle.dp(1, VLCStyle.scale)
                color: root.lineColor
            }

            T.AbstractButton {
                HoverHandler { cursorShape: Qt.PointingHandCursor } // redesign: hand cursor, like the prototype
                id: advanced

                anchors.centerIn: parent
                implicitWidth: advancedRow.implicitWidth + VLCStyle.margin_normal * 2
                implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

                onClicked: DialogsProvider.extendedDialog()

                Accessible.name: qsTr("Open Advanced Settings")

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
        // Figma: sections are divided by a 1px line, 20px above the title, 18px below the last row
        implicitHeight: sectionColumn.implicitHeight + VLCStyle.dp(38, VLCStyle.scale) + separator.height
        color: root.sectionColor

        Rectangle {
            id: separator

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: VLCStyle.dp(1, VLCStyle.scale)
            color: root.lineColor
        }

        ColumnLayout {
            id: sectionColumn

            anchors.fill: parent
            anchors.topMargin: VLCStyle.dp(20, VLCStyle.scale)
            anchors.leftMargin: VLCStyle.margin_large
            anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
            anchors.bottomMargin: VLCStyle.dp(18, VLCStyle.scale) + separator.height
            // Figma: rows 20px apart
            spacing: VLCStyle.dp(20, VLCStyle.scale)

            Text {
                visible: section.title !== ""
                text: section.title
                color: root.headingColor
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_xlarge
                Layout.bottomMargin: -VLCStyle.dp(4, VLCStyle.scale)
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

        // Figma: 138x34, radius 5, a 2px outline
        Rectangle {
            Layout.preferredWidth: VLCStyle.dp(138, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(34, VLCStyle.scale)
            radius: VLCStyle.dp(5, VLCStyle.scale)
            color: root.fieldColor
            border.color: root.gapColor
            border.width: VLCStyle.dp(2, VLCStyle.scale)

            TextInput {
                id: valueInput

                Accessible.name: valueRow.label

                anchors.fill: parent
                anchors.leftMargin: VLCStyle.margin_small
                anchors.rightMargin: VLCStyle.margin_small
                verticalAlignment: TextInput.AlignVCenter
                readOnly: !valueRow.editable
                text: valueRow.value
                color: root.valueColor
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

            Layout.preferredWidth: VLCStyle.dp(220, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(48, VLCStyle.scale)

            // Figma Dropdown: #191919 inside a 2px #090909 ring (radius 6), 14px #8F8F8F text
            // 18px from the left edge, a 12px chevron 21px from the right one
            bgColor: root._figma.dropdown
            borderColor: root.fieldColor
            color: root.valueColor
            labelPixelSize: VLCStyle.fontSize_large
            indicatorPixelSize: VLCStyle.dp(36, VLCStyle.scale)
            leftPadding: VLCStyle.dp(18, VLCStyle.scale)
            rightPadding: VLCStyle.dp(18, VLCStyle.scale)
            indicatorRightMargin: VLCStyle.dp(8, VLCStyle.scale)

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
        property string accessibleName
        // a filter that is off: grey fill and handle (Figma Video - Colors)
        property bool active: true

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

            Accessible.name: range.accessibleName

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
                    color: range.active ? Qt.alpha(theme.accent, 0.3) : root.gapColor
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
                color: range.active ? theme.accent : root.iconColor
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
            accessibleName: delay.audio ? qsTr("Audio Track Delay") : qsTr("Subtitle Track Delay")
            onMoved: (value) => delay.setDelay(value)
        }
    }

    component LinkRow: T.AbstractButton {
        id: link

        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

        Accessible.name: text

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
                color: root.valueColor
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_large
            }
        }
    }

    // ---- effect cards (Figma "06 Player side panels") ----

    // "Expand Settings" opens the card in place, "Collapse Settings" closes it
    component EffectCard: ColumnLayout {
        id: card

        property string label
        property bool expanded: false
        default property alias content: cardColumn.data

        Layout.fillWidth: true
        spacing: VLCStyle.margin_xsmall

        RowLabel { text: card.label }

        T.AbstractButton {
            id: cardButton

            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(48, VLCStyle.scale)

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            Accessible.name: (card.expanded ? qsTr("Collapse %1") : qsTr("Expand %1")).arg(card.label)

            onClicked: card.expanded = !card.expanded

            // Figma: the closed row is a field, the open card's header sits on the card
            background: Rectangle {
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: card.expanded ? root._figma.previewCard
                                     : (cardButton.hovered ? root.gapColor : root.fieldColor)
                // the open card continues below the header
                Rectangle {
                    visible: card.expanded
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.radius
                    color: parent.color
                }
            }

            contentItem: RowLayout {
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: VLCStyle.margin_normal
                    text: card.expanded ? qsTr("Collapse Settings") : qsTr("Expand Settings")
                    color: root.labelColor
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_large
                }

                Widgets.IconLabel {
                    Layout.rightMargin: VLCStyle.margin_normal
                    text: card.expanded ? VLCIcons.ic_fluent_chevron_down_24 : VLCIcons.ic_fluent_chevron_right_24
                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                    color: root.labelColor
                }
            }
        }

        Rectangle {
            visible: card.expanded
            Layout.fillWidth: true
            Layout.topMargin: -card.spacing
            implicitHeight: cardColumn.implicitHeight + VLCStyle.margin_normal
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: root._figma.previewCard

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.radius
                color: parent.color
            }

            ColumnLayout {
                id: cardColumn

                anchors.fill: parent
                anchors.leftMargin: VLCStyle.margin_normal
                anchors.rightMargin: VLCStyle.margin_normal
                anchors.bottomMargin: VLCStyle.margin_normal
                spacing: VLCStyle.margin_small
            }
        }
    }

    // a 1px line across the card between groups of rows
    component CardLine: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: -VLCStyle.margin_normal
        Layout.rightMargin: -VLCStyle.margin_normal
        Layout.topMargin: VLCStyle.margin_xxsmall
        Layout.bottomMargin: VLCStyle.margin_xxsmall
        implicitHeight: VLCStyle.dp(1, VLCStyle.scale)
        color: root._figma.previewEdge
    }

    // label and value over a slider; the value in a field (the equalizer) or as text
    component EffectSlider: ColumnLayout {
        id: effectSlider

        property string label
        property real from: 0
        property real to: 1
        property real stepSize: 0
        property real value: 0
        property string valueText: value.toFixed(stepSize >= 1 ? 0 : (stepSize >= 0.1 ? 1 : 2))
        property bool field: false
        property bool active: true

        signal moved(real value)

        Layout.fillWidth: true
        spacing: VLCStyle.margin_xxsmall

        RowLayout {
            Layout.fillWidth: true

            RowLabel { text: effectSlider.label }

            Text {
                visible: !effectSlider.field
                text: effectSlider.valueText
                color: root.labelColor
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_normal
            }

            Rectangle {
                visible: effectSlider.field
                Layout.preferredWidth: VLCStyle.dp(110, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(26, VLCStyle.scale)
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: root.fieldColor

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: VLCStyle.margin_xsmall
                    verticalAlignment: Text.AlignVCenter
                    text: effectSlider.valueText
                    color: root.valueColor
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_normal
                }
            }
        }

        RangeSlider {
            from: effectSlider.from
            to: effectSlider.to
            stepSize: effectSlider.stepSize
            value: effectSlider.value
            active: effectSlider.active
            accessibleName: effectSlider.label
            onMoved: (v) => effectSlider.moved(v)
        }
    }

    // the Figma toggle: a knob and OFF on the field colour, the accent knob and ON when on
    component ToggleSwitch: T.AbstractButton {
        id: toggle

        checkable: true
        implicitWidth: VLCStyle.dp(68, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
        opacity: enabled ? 1 : 0.5

        HoverHandler { cursorShape: Qt.PointingHandCursor; enabled: toggle.enabled }

        background: Rectangle {
            radius: VLCStyle.dp(5, VLCStyle.scale)
            color: root.fieldColor

            Rectangle {
                // the half that is not the knob
                x: toggle.checked ? VLCStyle.dp(2, VLCStyle.scale) : parent.width / 2
                y: VLCStyle.dp(2, VLCStyle.scale)
                width: parent.width / 2 - VLCStyle.dp(2, VLCStyle.scale)
                height: parent.height - VLCStyle.dp(4, VLCStyle.scale)
                radius: VLCStyle.dp(3, VLCStyle.scale)
                color: toggle.checked ? VLCStyle.accentDim(theme.accent, root._dark) : root.gapColor

                Text {
                    anchors.centerIn: parent
                    text: toggle.checked ? qsTr("ON") : qsTr("OFF")
                    color: toggle.checked ? theme.accent : root.iconColor
                    font.family: VLCStyle.fontFamily
                    font.pixelSize: VLCStyle.fontSize_small
                }
            }

            Rectangle {
                x: toggle.checked ? parent.width / 2 : VLCStyle.dp(2, VLCStyle.scale)
                y: VLCStyle.dp(2, VLCStyle.scale)
                width: parent.width / 2 - VLCStyle.dp(2, VLCStyle.scale)
                height: parent.height - VLCStyle.dp(4, VLCStyle.scale)
                radius: VLCStyle.dp(3, VLCStyle.scale)
                color: toggle.checked ? theme.accent : root.iconColor
            }
        }
    }

    // a row with a toggle bound to a video (or audio) filter of the chain
    component FilterToggleRow: RowLayout {
        id: filterRow

        property string label
        property string filter
        property bool audio: false
        readonly property bool on: (root._rev, audio ? effects.audioFilterEnabled(filter)
                                                     : effects.videoFilterEnabled(filter))

        Layout.fillWidth: true

        RowLabel { text: filterRow.label }

        ToggleSwitch {
            checked: filterRow.on
            Accessible.name: filterRow.label
            onToggled: filterRow.audio ? effects.setAudioFilterEnabled(filterRow.filter, checked)
                                       : effects.setVideoFilterEnabled(filterRow.filter, checked)
        }
    }

    // a row with a toggle bound to a boolean filter option
    component OptionToggleRow: RowLayout {
        id: optionRow

        property string label
        property string option

        Layout.fillWidth: true
        opacity: enabled ? 1 : 0.5

        RowLabel { text: optionRow.label }

        ToggleSwitch {
            checked: (root._rev, !!effects.videoValue(optionRow.option))
            Accessible.name: optionRow.label
            onToggled: effects.setVideoValue(optionRow.option, checked)
        }
    }

    // a filter toggle with its colour as a hex field and a swatch (extract, colorthres)
    component ColorToggleRow: RowLayout {
        id: colorRow

        property string label
        property string filter
        property string option
        readonly property bool on: (root._rev, effects.videoFilterEnabled(filter))
        readonly property string hex: (root._rev, "#" + ("000000" + Number(effects.videoValue(option)).toString(16).toUpperCase()).slice(-6))

        Layout.fillWidth: true
        spacing: VLCStyle.margin_xsmall

        RowLabel { text: colorRow.label }

        Rectangle {
            Layout.preferredWidth: VLCStyle.dp(115, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(32, VLCStyle.scale)
            radius: VLCStyle.dp(5, VLCStyle.scale)
            color: root.fieldColor

            TextInput {
                id: hexInput

                anchors.fill: parent
                anchors.leftMargin: VLCStyle.margin_small
                anchors.rightMargin: swatch.width + VLCStyle.margin_small
                verticalAlignment: TextInput.AlignVCenter
                text: colorRow.hex
                color: root.valueColor
                selectionColor: theme.accent
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_normal
                Accessible.name: qsTr("%1 colour").arg(colorRow.label)
                onEditingFinished: {
                    const v = parseInt(text.replace("#", ""), 16)
                    if (!isNaN(v))
                        effects.setVideoValue(colorRow.option, Math.max(1, Math.min(0xFFFFFF, v)))
                    text = Qt.binding(() => colorRow.hex)
                }
            }

            Rectangle {
                id: swatch
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(6, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(20, VLCStyle.scale)
                height: width
                radius: VLCStyle.dp(2, VLCStyle.scale)
                color: colorRow.hex
            }
        }

        ToggleSwitch {
            checked: colorRow.on
            Accessible.name: colorRow.label
            onToggled: effects.setVideoFilterEnabled(colorRow.filter, checked)
        }
    }

    // a dropdown on the card (equalizer presets, gradient mode)
    component CardCombo: Widgets.ComboBoxExt {
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(40, VLCStyle.scale)
        opacity: enabled ? 1 : 0.5

        bgColor: root.fieldColor
        borderColor: root.fieldColor
        color: root.valueColor
        labelPixelSize: VLCStyle.fontSize_large
        indicatorPixelSize: VLCStyle.dp(36, VLCStyle.scale)
        leftPadding: VLCStyle.margin_normal
        rightPadding: VLCStyle.margin_normal
        indicatorRightMargin: VLCStyle.dp(8, VLCStyle.scale)
    }

    // a crop side in pixels: "Top  0 px" on the field colour
    component CropField: Rectangle {
        id: cropField

        property string side
        property string label
        signal edited(int value)

        function apply(v) {
            effects.setCrop(side, v)
        }

        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
        radius: VLCStyle.dp(5, VLCStyle.scale)
        color: root.fieldColor

        Text {
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.margin_small
            anchors.verticalCenter: parent.verticalCenter
            text: cropField.label
            color: root.labelColor
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.fontSize_normal
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.margin_small
            anchors.verticalCenter: parent.verticalCenter
            spacing: VLCStyle.margin_xxxsmall

            TextInput {
                id: cropInput
                width: VLCStyle.dp(32, VLCStyle.scale)
                horizontalAlignment: TextInput.AlignRight
                text: (root._rev, effects.crop(cropField.side))
                validator: IntValidator { bottom: 0; top: 10000 }
                color: root.valueColor
                selectionColor: theme.accent
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_normal
                Accessible.name: qsTr("Crop %1").arg(cropField.label)
                onEditingFinished: {
                    const v = parseInt(text)
                    if (!isNaN(v)) {
                        cropField.apply(v)
                        cropField.edited(v)
                    }
                    text = Qt.binding(() => (root._rev, effects.crop(cropField.side)))
                }
            }

            Text {
                text: qsTr("px")
                color: root.iconColor
                font.family: VLCStyle.fontFamily
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }
    }

    // keeps two opposite crop sides the same (the Figma link icon)
    component LinkToggle: T.AbstractButton {
        id: link

        property string accessibleName

        checkable: true
        implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
        Accessible.name: accessibleName

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        contentItem: Canvas {
            readonly property color ink: link.checked ? theme.accent : root.valueColor
            onInkChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = ink
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                const cy = height / 2, r = 3.5
                // two open links facing each other
                ctx.beginPath()
                ctx.moveTo(width / 2 - 2, cy - r); ctx.lineTo(width / 2 - 6, cy - r)
                ctx.arc(width / 2 - 6, cy, r, -Math.PI / 2, Math.PI / 2, true)
                ctx.lineTo(width / 2 - 2, cy + r)
                ctx.moveTo(width / 2 + 2, cy - r); ctx.lineTo(width / 2 + 6, cy - r)
                ctx.arc(width / 2 + 6, cy, r, -Math.PI / 2, Math.PI / 2, false)
                ctx.lineTo(width / 2 + 2, cy + r)
                ctx.stroke()
            }
        }
    }
}
