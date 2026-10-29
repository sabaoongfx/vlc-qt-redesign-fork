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

import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.MainInterface

T.ProgressBar {
    id: control

    // redesign: prototype `.seek` field, a tall rounded well with an inset dim fill and an accent bar handle
    property bool fieldStyle: false
    // redesign: the mini player card's progress field has no handle (Figma "Miniplayer")
    property bool showHandle: true
    // redesign: the Figma music player seek bar (Player - Music), thin bars in the field, accent up
    // to the position and grey after it, instead of the filled bar. Only with fieldStyle.
    property bool waveform: false
    readonly property real _fieldInset: VLCStyle.dp(2, VLCStyle.scale)
    readonly property bool _waveformShown: waveform && fieldStyle

    readonly property real _hoveredScalingFactor: fieldStyle ? 1 : 1.8
    property int barHeight: VLCStyle.dp(5, VLCStyle.scale)
    readonly property real _scaledBarHeight: control.barHeight * _hoveredScalingFactor
    readonly property real _scaledY: (-control.barHeight / 2) * (control._hoveredScalingFactor - 1)

    property bool _isSeekPointsShown: true
    readonly property int _seekPointsDistance: VLCStyle.dp(2, VLCStyle.scale)
    readonly property int _seekPointsRadius: VLCStyle.dp(0.5, VLCStyle.scale)
    readonly property real _scaledSeekPointsRadius: _seekPointsRadius * _hoveredScalingFactor

    property bool _currentChapterHovered: false
    property real _tooltipPosition: (Widgets.PointingToolTipAttached.instance?.pos.x ?? 0.0) / width

    property color backgroundColor: theme.bg.primary
    property real touchHandlerMargin: VLCStyle.touchHandlerMargin

    Keys.onRightPressed: Player.jumpFwd()
    Keys.onLeftPressed: Player.jumpBwd()

    Accessible.onIncreaseAction: Player.jumpFwd()
    Accessible.onDecreaseAction: Player.jumpBwd()

    function showChapterMarks() {
        _isSeekPointsShown = true
        seekpointTimer.restart()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider

        enabled: control.enabled
        focused: control.visualFocus
        hovered: hoverHandler.hovered
    }

    Timer {
        id: seekpointTimer
        running: Player.hasChapters && !hoverHandler.hovered && _isSeekPointsShown
        interval: 3000
        onTriggered: control._isSeekPointsShown = false
    }

    // the preview card shows the time itself
    Widgets.PointingToolTipAttached.visible: (hoverHandler.hovered || control.visualFocus || dragHandler.active)
                                             && !previewCard.visible

    Widgets.PointingToolTipAttached.text: {
        if (!Widgets.PointingToolTipAttached.instance?.visible)
            return ""

        let _text

        const length = Player.length
        if (hoverHandler.hovered)
            _text = length.scale(Widgets.PointingToolTipAttached.instance.pos.x / control.width)
        else
            _text = Player.time

        _text = _text.formatHMS(length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)

        if (Player.hasChapters)
            _text += " - " + Player.chapters.getNameAtPosition(control._tooltipPosition)

        return _text
    }

    Widgets.PointingToolTipAttached.pos: Qt.point(hoverHandler.hovered ? Helpers.clamp(hoverHandler.point.position.x, 0, control.availableWidth)
                                                                       : (control.visualPosition * control.width), 0)

    FSM {
        id: fsm
        signal playerUpdatePosition(real position)
        signal pressControl(real position, bool forcePrecise)
        signal releaseControl(real position, bool forcePrecise)
        signal moveControl(real position, bool forcePrecise)
        signal inputChanged()

        //each signal is associated to a key, when a signal is received,
        //transitions of active state for the given key are evaluated
        signalMap: ({
            "playerUpdatePosition": fsm.playerUpdatePosition,
            "pressControl": fsm.pressControl,
            "releaseControl": fsm.releaseControl,
            "moveControl": fsm.moveControl,
            "inputChanged": fsm.inputChanged
        })

        initialState: fsmReleased

        function _setPositionFromValue(position) {
            control.value = position
        }

        function _seekToPosition(position, threshold, forcePrecise) {
            position = Helpers.clamp(position, 0., 1.)
            control.value = position
            if (!forcePrecise) {
                const chapter = Player.chapters.getClosestChapterFromPos(position, threshold)
                if (chapter !== -1) {
                    Player.chapters.selectChapter(chapter)
                    return
                }
            }
            Player.position = position
        }

        FSMState {
            id: fsmReleased

            transitions: ({
                "playerUpdatePosition": {
                    action: (position) => {
                        control.value = position
                    }
                },
                "pressControl": {
                    action: (position, forcePrecise) => {
                        control.forceActiveFocus()
                        fsm._seekToPosition(position, VLCStyle.dp(4, VLCStyle.scale) / control.width, forcePrecise)
                    },
                    target: fsmHeld
                }
            })
        }

        FSMState  {
            id: fsmHeld

            transitions: ({
                "moveControl": {
                    action: (position, forcePrecise) => {
                        fsm._seekToPosition(position, VLCStyle.dp(2, VLCStyle.scale) / control.width, forcePrecise)
                    }
                },
                "releaseControl": {
                    target: fsmReleased
                },
                "inputChanged": {
                    target: fsmHeldWrongInput
                }
            })
        }

        FSMState  {
            id: fsmHeldWrongInput

            function enter() {
                fsm._setPositionFromValue(Player.position)
            }

            transitions: ({
                "playerUpdatePosition": {
                    action: fsm._setPositionFromValue
                },
                "releaseControl": {
                    target: fsmReleased
                }
            })
        }
    }

    Connections {
        target: Player
        function onPositionChanged() {  fsm.playerUpdatePosition(Player.position) }
        function onInputChanged() {  fsm.inputChanged() }
    }

    Component.onCompleted: value = Player.position

    implicitHeight: control.barHeight
    height: implicitHeight

    padding: 0

    //we use our own HoverHandler
    hoverEnabled: false

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: () => {
            if (hovered) {
                if(Player.hasChapters)
                    control._isSeekPointsShown = true
            } else {
                if(Player.hasChapters)
                    seekpointTimer.restart()
            }
        }
    }

    contentItem: Item {
        implicitHeight: control.implicitHeight
        implicitWidth: control.implicitWidth

        //placing the TapHandler directly in the Control doesn't work with 6.2
        TapHandler {
            acceptedButtons: Qt.LeftButton

            gesturePolicy: TapHandler.WithinBounds

            // Make it easier to tap with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0.0

            onPressedChanged: {
                if (pressed) {
                    fsm.pressControl(point.position.x / control.width, point.modifiers === Qt.ShiftModifier)
                } else {
                    // NOTE: Point is still valid at this point.
                    fsm.releaseControl(point.position.x / control.width, point.modifiers === Qt.ShiftModifier)
                }
            }
        }

        DragHandler {
            id: dragHandler
            acceptedButtons: Qt.LeftButton

            // Make it easier to drag with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0

            target: null
            dragThreshold: 0
            grabPermissions: PointerHandler.CanTakeOverFromAnything

            property bool filterEvents: false

            function moveControl() {
                fsm.moveControl(dragHandler.centroid.position.x / control.width,
                                dragHandler.centroid.modifiers === Qt.ShiftModifier)
            }

            onActiveChanged: {
                if (active) {
                    filterEvents = false
                    fsm.pressControl(centroid.position.x / control.width, centroid.modifiers === Qt.ShiftModifier)
                } else {
                    fsm.releaseControl( centroid.position.x / control.width, centroid.modifiers === Qt.ShiftModifier)
                }
            }

            onCentroidChanged: {
                // FIXME: Qt 6.5 use xAxis.onActiveValueChanged in the DragHandler
                if (filterEvents) {
                    Qt.callLater(dragHandler.moveControl)
                } else {
                    dragHandler.moveControl()
                    filterEvents = true
                }
            }
        }

        WheelHandler {
            orientation: Qt.Vertical | Qt.Horizontal

            acceptedDevices: PointerDevice.AllDevices

            onWheel: (wheel) => {
                wheelToVLC.qmlWheelEvent(wheel)
                wheel.accepted = true
            }
        }

        WheelToVLCConverter {
            id: wheelToVLC

            function handleVertical(steps: int) {
                if (steps > 0)
                    Player.jumpFwd()
                else
                    Player.jumpBwd()
            }

            function handleHorizontal(steps: int) {
                if (steps > 0)
                    Player.jumpBwd()
                else
                    Player.jumpFwd()
            }

            Component.onCompleted: {
                wheelUpDown.connect(wheelToVLC, wheelToVLC.handleVertical)
                wheelLeftRight.connect(wheelToVLC, wheelToVLC.handleHorizontal)
            }
        }
    }

    background: Item {
        width: control.availableWidth
        implicitHeight: control.implicitHeight
        height: implicitHeight

        Rectangle {
            id: sliderRect
            // redesign: the field style keeps its well and inset fill with chapters too (the chapter
            // segments were a full accent fill edge to edge); chapters are breaks in the fill
            visible: control.fieldStyle || !Player.hasChapters
            color: control.fieldStyle ? VLCStyle.figmaColors(theme.palette.isDark).track : control.backgroundColor
            anchors.fill: parent
            radius: control.fieldStyle ? VLCStyle.dp(6, VLCStyle.scale) : implicitHeight
        }

        Repeater {
            id: seekpointsRptr

            anchors.left: parent.left
            anchors.right: parent.right
            height: control.barHeight
            visible: Player.hasChapters && !control.fieldStyle

            model: Player.chapters
            Item {
                // the delegates are parented to the Repeater's parent: its visible does not reach them
                visible: seekpointsRptr.visible
                Rectangle {
                    id: seekpointsRect
                    readonly property real startPosition: model.startPosition ??  0.0
                    readonly property real endPosition: model.endPosition ?? 1.0

                    readonly property int _currentChapter: {
                        if (control.visualPosition < seekpointsRect.startPosition)
                            return 1
                        else if (control.visualPosition > seekpointsRect.endPosition)
                            return -1
                        return 0
                    }
                    on_CurrentChapterChanged: {
                        if(_hovered)
                            control._currentChapterHovered = _currentChapter === 0
                    }

                    readonly property bool _hovered: hoverHandler.hovered &&
                                            (hoverHandler.point.position.x > x && hoverHandler.point.position.x < x+width)

                    color: _currentChapter < 0 ? theme.fg.primary : control.backgroundColor
                    width: sliderRect.width * seekpointsRect.endPosition - x - control._seekPointsDistance
                    x: sliderRect.width * seekpointsRect.startPosition

                    Rectangle {
                        id: progressRepRect
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: parent.radius

                        width: sliderRect.width * control.visualPosition - parent.x - control._seekPointsDistance
                        visible: parent._currentChapter === 0
                        color: theme.fg.primary

                        // We use dynamic mutability group because time interpolation
                        // may induce rapid change:
                        // TODO: Do not use `Binding` when minimum Qt is 6.12:
                        Binding {
                            target: progressRepRect
                            property: "mutabilityGroup"
                            when: (progressRepRect.mutabilityGroup !== undefined)
                            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                                          : Item.StaticMutabilityGroup
                        }
                    }
                }

                transitions: [
                    Transition {
                        to: "*"
                        SequentialAnimation{
                            PropertyAction { targets: control; property: "_currentChapterHovered" }
                            NumberAnimation {
                                targets: [seekpointsRect, progressRepRect]; properties: "height, y, radius"
                                duration: VLCStyle.duration_short; easing.type: Easing.InSine
                            }
                        }
                    }
                ]

                states:[
                    State {
                        name: "visible"
                        PropertyChanges {
                            target: control;
                            _currentChapterHovered: seekpointsRect._currentChapter === 0 ? false : control._currentChapterHovered
                        }
                        PropertyChanges { target: seekpointsRect; height: control.barHeight }
                        PropertyChanges { target: seekpointsRect; y: 0 }
                        PropertyChanges { target: seekpointsRect; radius: control._seekPointsRadius }
                    },
                    State {
                        name: "visibleLarge"
                        PropertyChanges {
                            target: control;
                            _currentChapterHovered: seekpointsRect._currentChapter === 0 ? true : control._currentChapterHovered
                        }
                        PropertyChanges { target: seekpointsRect; height: control._scaledBarHeight }
                        PropertyChanges { target: seekpointsRect; y: control._scaledY }
                        PropertyChanges { target: seekpointsRect; radius: control._scaledSeekPointsRadius }
                    }
                ]

                state: (seekpointsRect._hovered || (seekpointsRect._currentChapter === 0 && fsm._state === fsm.fsmHeld))
                       ? "visibleLarge"
                       : "visible"
            }
        }

        Rectangle {
            id: progressRect
            x: control.fieldStyle ? control._fieldInset : 0
            y: control.fieldStyle ? control._fieldInset : 0
            width: control.fieldStyle ? Math.max(0, control.visualPosition * parent.width - control._fieldInset)
                                      : control.visualPosition * parent.width
            // redesign: the Figma accent-dim
            color: control.fieldStyle ? VLCStyle.accentDim(theme.accent, theme.palette.isDark) : theme.fg.primary
            height: control.fieldStyle ? control.barHeight - control._fieldInset * 2 : control.barHeight
            radius: control.fieldStyle ? VLCStyle.dp(4, VLCStyle.scale) : control._seekPointsRadius
            visible: (control.fieldStyle || !Player.hasChapters) && !control._waveformShown

            // We use dynamic mutability group because time interpolation
            // may induce rapid change:
            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: progressRect
                property: "mutabilityGroup"
                when: (progressRect.mutabilityGroup !== undefined)
                value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                              : Item.StaticMutabilityGroup
            }
        }

        // redesign: the music seek bar. The bar heights are a fixed pattern picked from the title (the
        // player has no waveform of the audio), the same for a song every time it plays.
        Item {
            id: waveformBars

            x: control._fieldInset * 3
            y: control._fieldInset * 2
            width: parent.width - control._fieldInset * 6
            height: control.barHeight - control._fieldInset * 4

            visible: control._waveformShown

            readonly property real step: VLCStyle.dp(4, VLCStyle.scale)

            readonly property int seed: {
                const text = Player.title + Player.name
                let hash = 7
                for (let i = 0; i < text.length; i++)
                    hash = (hash * 31 + text.charCodeAt(i)) % 2147483647
                return hash
            }

            Repeater {
                model: control._waveformShown ? Math.max(0, Math.floor(waveformBars.width / waveformBars.step)) : 0

                delegate: Rectangle {
                    required property int index

                    // 0.2 .. 1, a pseudo random value per bar
                    readonly property real level: {
                        const v = Math.sin((index + 1) * 12.9898 + waveformBars.seed * 0.0001 * 78.233) * 43758.5453
                        return 0.2 + 0.8 * (v - Math.floor(v))
                    }

                    x: index * waveformBars.step
                    width: VLCStyle.dp(1.5, VLCStyle.scale)
                    height: Math.max(width, Math.round(waveformBars.height * level))
                    y: Math.round((waveformBars.height - height) / 2)
                    radius: width / 2

                    color: (x / waveformBars.width) <= control.visualPosition ? theme.accent
                                                                               : VLCStyle.figmaColors(theme.palette.isDark).hint
                }
            }
        }

        // redesign: field style, chapter starts as 2px breaks across the inset fill
        Repeater {
            model: (control.fieldStyle && Player.hasChapters && !control._waveformShown) ? Player.chapters : 0

            delegate: Rectangle {
                required property var model

                readonly property real startPosition: model.startPosition ?? 0.0

                visible: startPosition > 0
                x: Math.round(startPosition * parent.width) - width / 2
                y: control._fieldInset
                width: control._seekPointsDistance
                height: control.barHeight - control._fieldInset * 2
                // a gap in the played fill; ahead of it a grey mark (the field colour did not show there)
                color: (startPosition <= control.visualPosition) ? VLCStyle.figmaColors(theme.palette.isDark).track
                                                                 : VLCStyle.figmaColors(theme.palette.isDark).tabIcon
            }
        }

        Rectangle {
            id: bufferRect
            property int bufferAnimWidth: VLCStyle.dp(100, VLCStyle.scale)
            property int bufferAnimPosition: 0
            property int bufferFrames: 1000
            property alias animateLoading: loadingAnim.running
            property bool display: false
            property bool buffering: Player.buffering > 0 && Player.buffering < 1

            // redesign: the loading bar is for the first load only. A seek (the 10 s buttons, a click on
            // the bar) empties the buffer again, and the bouncing bar then flashed over the seek bar.
            property bool loaded: false

            // the bar is also made while something already plays (the player opened mid-file)
            Component.onCompleted: loaded = (Player.buffering >= 1)

            Connections {
                target: Player

                function onInputChanged() {
                    bufferRect.loaded = false
                }

                function onBufferingChanged() {
                    if (Player.buffering >= 1)
                        bufferRect.loaded = true
                }
            }

            height: control.barHeight
            opacity: 0.4
            color: theme.fg.neutral //FIXME buffer color ?
            radius: control.barHeight

            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: bufferRect
                property: "mutabilityGroup"
                when: bufferRect.mutabilityGroup !== undefined
                value: bufferRect.buffering ? Item.DynamicMutabilityGroup
                                            : Item.StaticMutabilityGroup
            }

            Timer {
                id: bufferingTimer
                interval: VLCStyle.duration_humanMoment
                repeat: false
                running: false
                onTriggered: {
                    bufferRect.display = true
                }
            }

            onBufferingChanged: {
                if(buffering)
                {
                    bufferingTimer.start()
                }
                else
                {
                    bufferingTimer.stop()
                    bufferRect.display = false
                }
            }

            states: [
                State {
                    name: "hidden"
                    when: !control.visible
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    // redesign: nothing loaded (e.g. after the end of playback): no bouncing
                    // loading bar
                    name: "idle"
                    when: control.visible && !Player.isStarted
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "buffering not started"
                    when: control.visible && Player.buffering === 0 && !bufferRect.loaded
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: true
                        x: (bufferAnimPosition / bufferFrames) * (parent.width - bufferAnimWidth)
                        animateLoading: true
                    }
                },
                State {
                    name: "time to start playing known"
                    when: control.visible && bufferRect.display && !bufferRect.loaded
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: true
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "playing from buffer"
                    when: control.visible && !bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                }
            ]

            SequentialAnimation on bufferAnimPosition {
                id: loadingAnim
                running: bufferRect.animateLoading
                loops: Animation.Infinite
                PropertyAnimation {
                    from: 0.0
                    to: bufferRect.bufferFrames
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
                PropertyAnimation {
                    from: bufferRect.bufferFrames
                    to: 0.0
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
            }
        }
    }

    Rectangle {
        id: sliderHandle

        property int _size: control.barHeight * 3

        x: control.fieldStyle ? Math.min(Math.max(control.visualPosition * control.availableWidth - width / 2, control._fieldInset),
                                         control.availableWidth - width - control._fieldInset)
                              : (control.visualPosition * control.availableWidth) - width / 2
        y: (control.barHeight - height) / 2

        implicitWidth: control.fieldStyle ? VLCStyle.dp(8, VLCStyle.scale) : sliderHandle._size
        implicitHeight: control.fieldStyle ? control.barHeight - control._fieldInset * 2 : sliderHandle._size
        // redesign: a narrow accent bar instead of a round knob
        // redesign: the field-style handle keeps its 8px bar shape; the hover animations below
        // drive implicitWidth/Height (up to 3x the bar height) and turned it into a large square
        width: control.fieldStyle ? VLCStyle.dp(8, VLCStyle.scale) : implicitWidth * 0.3
        height: control.fieldStyle ? control.barHeight - control._fieldInset * 2 : implicitHeight
        radius: control.fieldStyle ? VLCStyle.dp(4, VLCStyle.scale) : VLCStyle.dp(3, VLCStyle.scale)
        color: theme.accent
        opacity: control.showHandle ? 1 : 0 // visible is driven by the hover states below

        // We use dynamic mutability group because time interpolation
        // may induce rapid change:
        // TODO: Do not use `Binding` when minimum Qt is 6.12:
        Binding {
            target: sliderHandle
            property: "mutabilityGroup"
            when: (sliderHandle.mutabilityGroup !== undefined)
            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                          : Item.StaticMutabilityGroup
        }

        transitions: [
            Transition {
                to: "hidden"
                SequentialAnimation {
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: 0
                        duration: VLCStyle.duration_short; easing.type: Easing.OutSine
                    }
                    PropertyAction { target: sliderHandle; property: "visible"; value: false; }
                }
            },
            Transition {
                to: "visible"
                SequentialAnimation {
                    PropertyAction { target: sliderHandle; property: "visible"; value: true; }
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: sliderHandle._size
                        duration: VLCStyle.duration_short; easing.type: Easing.InSine
                    }
                }
            },
            Transition {
                to: "visibleLarge"
                SequentialAnimation {
                    PropertyAction { target: sliderHandle; property: "visible"; value: true; }
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: sliderHandle._size * (0.8 * control._hoveredScalingFactor)
                        duration: VLCStyle.duration_short; easing.type: Easing.InSine
                    }
                }
            }
        ]

        // redesign: the field-style handle is always shown (Figma player bar)
        state: (control.fieldStyle || hoverHandler.hovered || control.visualFocus)
               ? ((control._currentChapterHovered || (Player.hasChapters && fsm._state === fsm.fsmHeld)) ? "visibleLarge" : "visible")
               : "hidden"
    }

    // redesign: the prototype's seek preview, a card with the frame under the cursor and its time
    readonly property real _hoverPosition: hoverHandler.hovered ? Helpers.clamp(hoverHandler.point.position.x / control.width, 0, 1)
                                                                : -1
    readonly property bool _previewWanted: hoverHandler.hovered && Player.isStarted && (Player.videoTracks.count > 0)

    on_HoverPositionChanged: {
        if (_previewWanted)
            seekPreview.request(_hoverPosition)
    }

    SeekPreview {
        id: seekPreview
        ctx: MainCtx
    }

    Rectangle {
        id: previewCard

        readonly property var _figma: VLCStyle.figmaColors(theme.palette.isDark)
        readonly property real _pad: VLCStyle.dp(5, VLCStyle.scale)

        visible: control._previewWanted && seekPreview.source !== ""
        z: 10

        width: VLCStyle.dp(156, VLCStyle.scale)
        height: _pad + previewFrame.height + VLCStyle.dp(6, VLCStyle.scale) + previewTime.implicitHeight + VLCStyle.dp(8, VLCStyle.scale)

        // centred on the cursor, kept over the bar, 10px above it
        x: Helpers.clamp(control._hoverPosition * control.width, width / 2, control.width - width / 2) - width / 2
        y: -height - VLCStyle.dp(10, VLCStyle.scale)

        radius: VLCStyle.dp(10, VLCStyle.scale)
        color: _figma.previewCard
        border.color: _figma.previewEdge
        border.width: VLCStyle.dp(1, VLCStyle.scale)

        Widgets.ImageExt {
            id: previewFrame

            x: previewCard._pad
            y: previewCard._pad
            width: parent.width - 2 * previewCard._pad
            height: VLCStyle.dp(82, VLCStyle.scale)

            radius: VLCStyle.dp(6, VLCStyle.scale)
            backgroundColor: "black"
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
            source: seekPreview.source
        }

        Text {
            id: previewTime

            anchors.horizontalCenter: parent.horizontalCenter
            y: previewFrame.y + previewFrame.height + VLCStyle.dp(6, VLCStyle.scale)

            text: control._hoverPosition < 0 ? ""
                                             : Player.length.scale(control._hoverPosition).formatHMS(Player.length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)
            color: previewCard._figma.previewText
            font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
            font.family: VLCStyle.fontFamily
        }
    }

    // redesign: the hand cursor over everything clickable, like the prototype
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        enabled: control.enabled
    }
}
