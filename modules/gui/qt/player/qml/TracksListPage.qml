
/*****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
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


import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Dialogs

RowLayout {
    id: root

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.View
    }

    //FIXME make TrackMenuController a proper type (see TrackMenu)
    required property QtObject trackMenuController

    // redesign: docked right panel with tabs instead of three columns
    property int currentTab: 0
    property int preferredWidth: VLCStyle.dp(400, VLCStyle.scale)

    spacing: 0

    focus: true

    onActiveFocusChanged: if (activeFocus) playbackBtn.forceActiveFocus()

    Widgets.ButtonExt {
        id: playbackBtn

        text: qsTr("%1x").arg(+Player.rate.toFixed(2))
        color: theme.fg.primary // redesign: the stock colour rendered invisible here

        onPressed: {
            trackMenuController.requestPlaybackSpeedPage()
        }

        T.ToolTip.visible: (hovered || visualFocus)
        T.ToolTip.text: qsTr("Playback Speed")
        T.ToolTip.delay: VLCStyle.delayToolTipAppear

        Navigation.parentItem: root
        Navigation.rightItem: row

        Layout.alignment: Qt.AlignTop | Qt.AlignLeft
        Layout.margins: VLCStyle.margin_large
    }

    ColumnLayout {
        Layout.fillHeight: true
        Layout.fillWidth: true

        spacing: 0

        Row {
            id: tabBar

            Layout.topMargin: VLCStyle.margin_large
            Layout.leftMargin: VLCStyle.margin_large
            spacing: VLCStyle.margin_xsmall

            Repeater {
                model: [qsTr("Subtitles"), qsTr("Audio"), qsTr("Video")]

                delegate: T.AbstractButton {
                    id: tab

                    required property int index
                    required property string modelData

                    readonly property bool current: root.currentTab === index

                    implicitWidth: tabLabel.implicitWidth + VLCStyle.margin_normal * 2
                    implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

                    text: modelData
                    onClicked: root.currentTab = index

                    contentItem: Text {
                        id: tabLabel

                        text: tab.text
                        font.pixelSize: VLCStyle.fontSize_large
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: tab.current ? theme.accent : (tab.hovered ? theme.fg.primary : theme.fg.secondary)
                    }

                    background: Rectangle {
                        radius: VLCStyle.button_radius
                        color: tab.current ? Qt.alpha(theme.accent, 0.16)
                                           : (tab.hovered ? Qt.alpha(theme.fg.primary, 0.08) : "transparent")
                    }
                }
            }
        }

    Widgets.NavigableRow {
        id: row

        Layout.fillHeight: true
        Layout.fillWidth: true

        Navigation.leftItem: playbackBtn

        TrackColumn {
            tabIndex: 0
            title: qsTr("Subtitle")
            tracksModel: Player.subtitleTracks
            menuIcon: VLCIcons.expand
            menuText: qsTr("Menu")
            onMenuAction: (menuPos)  => {
                menuSubtitle.popup(menuPos)
            }
        }

        TrackColumn {
            tabIndex: 1
            title: qsTr("Audio")
            tracksModel: Player.audioTracks
            menuIcon: VLCIcons.expand
            menuText: qsTr("Menu")
            onMenuAction: (menuPos)  => {
                menuAudio.popup(menuPos)
            }
        }

        TrackColumn {
            tabIndex: 2
            title: qsTr("Video Tracks")
            tracksModel: Player.videoTracks
            menuIcon: VLCIcons.add
            menuText: qsTr("Add")
            onMenuAction: (menuPos) => {
                DialogsProvider.loadVideoFile()
            }
        }
    }
    }

    // redesign: inline delay control shown at the bottom of the Subtitles / Audio tabs
    component DelayRow: RowLayout {
        id: delayRow

        property bool audio: false

        readonly property int delayMS: audio ? Player.audioDelayMS : Player.subtitleDelayMS

        function setDelay(value) {
            if (audio)
                Player.audioDelayMS = value
            else
                Player.subtitleDelayMS = value
        }

        function textFrom(value, locale) {
            return qsTr("%1 ms").arg(Number(value).toLocaleString(locale, 'f', 0))
        }

        function valueFrom(text, locale) {
            return Number.fromLocaleString(locale, text.substring(0, text.length - 3))
        }

        spacing: VLCStyle.margin_xsmall

        Widgets.MenuCaption {
            Layout.fillWidth: true

            text: qsTr("Delay") // the tab already says which track type
            color: theme.fg.primary
        }

        Widgets.SpinBoxExt {
            id: delaySpin

            property bool update: false

            Layout.preferredWidth: VLCStyle.dp(112, VLCStyle.scale)

            stepSize: 50
            from: -10000
            to: 10000

            textFromValue: delayRow.textFrom
            valueFromText: delayRow.valueFrom

            Component.onCompleted: {
                value = delayRow.delayMS
                update = true
            }

            onValueChanged: {
                if (update)
                    delayRow.setDelay(value)
            }

            Connections {
                target: delayRow

                function onDelayMSChanged() {
                    delaySpin.update = false
                    delaySpin.value = delayRow.delayMS
                    delaySpin.update = true
                }
            }
        }

        T.AbstractButton {
            id: resetBtn

            implicitWidth: resetLabel.implicitWidth + VLCStyle.margin_normal * 2
            implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

            text: qsTr("Reset")

            onClicked: delayRow.setDelay(0)

            contentItem: Text {
                id: resetLabel

                text: resetBtn.text
                font.pixelSize: VLCStyle.fontSize_normal
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: resetBtn.hovered ? theme.accent : theme.fg.primary
            }

            background: Rectangle {
                radius: VLCStyle.button_radius
                color: resetBtn.hovered ? Qt.alpha(theme.fg.primary, 0.1) : "transparent"
                border.width: 1
                border.color: theme.border
            }
        }
    }

    component TrackColumn: T.Container {
        // wrap the contentItem i.e Column into Container
        // so that we can get focusReason, also Container
        // is a FocusScope
        id: tracksListContainer

        implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                 implicitContentHeight + topPadding + bottomPadding)

        required property int tabIndex
        required property string title
        required property var tracksModel
        required property string menuIcon
        required property string menuText

        signal menuAction(point position)

        focus: true

        visible: root.currentTab === tabIndex
        width: row.width
        height: row.height

        onActiveFocusChanged: if (activeFocus) tracksList.forceActiveFocus(focusReason)

        // this is required to initialize attached Navigation property
        Navigation.parentItem: row

        contentItem: Column {
            anchors.fill: parent

            focus: true

            Accessible.role: Accessible.Pane
            Accessible.name: tracksListContainer.title

            Item {
                // keep it inside so "Column" doesn't mess with it
               Rectangle {
                   id: separator

                   x: 0
                   y: 0
                   width: VLCStyle.margin_xxxsmall

                   height: tracksListContainer.height
                   color: theme.border
               }
            }

            Row {
                id: titleHeader

                width: tracksListContainer.width
                height: implicitHeight

                padding: VLCStyle.margin_xsmall

                topPadding: VLCStyle.margin_large
                leftPadding: VLCStyle.margin_xxlarge + separator.width

                focus: true

                clip: true

                Widgets.SubtitleLabel {
                    id: titleText

                    width: parent.width - button.width - parent.leftPadding
                           - parent.rightPadding

                    text: tracksListContainer.title
                    color: theme.fg.primary
                    font.weight: Font.Light // redesign: light section headers (prototype .hsec-h)
                }

                Widgets.IconTrackButton {
                    id: button

                    font.pixelSize: VLCStyle.icon_track

                    focus: true

                    description: tracksListContainer.menuText
                    text: tracksListContainer.menuIcon

                    Navigation.parentItem: tracksListContainer
                    Navigation.downItem: tracksList

                    onClicked: {
                        tracksListContainer.menuAction(mapToGlobal(0, height))
                    }
                }
            }

            Widgets.ListViewExt {
                id: tracksList

                model: tracksListContainer.tracksModel
                width: tracksListContainer.width
                height: tracksListContainer.height - titleHeader.height - delayFooter.height
                leftMargin: separator.width
                focus: true
                clip: !fadingEdge.implicitClipping && (height < contentHeight)

                fadingEdge.backgroundColor: theme.bg.primary

                Accessible.role: Accessible.List
                Accessible.name: qsTr("Track list")

                Navigation.parentItem: tracksListContainer
                Navigation.upItem: button
                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                delegate: Widgets.CheckedDelegate {
                    readonly property bool isModelChecked: model.checked
                    clip: true

                    focus: true
                    text: model.display
                    width: tracksListContainer.width - VLCStyle.margin_xxxsmall
                    height: VLCStyle.dp(40, VLCStyle.scale)
                    opacity: hovered || activeFocus || checked ? 1 : .6
                    font.weight: Font.Normal // redesign: no weight jump on hover

                    onIsModelCheckedChanged: {
                        if (model.checked !== checked)
                            checked = model.checked
                    }

                    onCheckedChanged: {
                        if (model.checked !== checked)
                            model.checked = checked
                    }

                    onClicked: {
                        tracksList.currentIndex = index
                        tracksList.setCurrentItemFocus(Qt.MouseFocusReason)
                    }

                    Navigation.parentItem: tracksList
                }
            }

            Item {
                id: delayFooter

                // subtitle (0) and audio (1) tabs only
                visible: tracksListContainer.tabIndex < 2
                width: tracksListContainer.width
                height: visible ? delayInline.implicitHeight + VLCStyle.margin_large * 2 : 0

                DelayRow {
                    id: delayInline

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: VLCStyle.margin_large
                    anchors.rightMargin: VLCStyle.margin_large
                    anchors.verticalCenter: parent.verticalCenter

                    audio: tracksListContainer.tabIndex === 1
                }
            }
        }
    }

    QmlSubtitleMenu {
        id: menuSubtitle

        player: Player
        ctx: MainCtx

        onTriggered: {
            if (action === QmlSubtitleMenu.Open) {
                DialogsProvider.loadSubtitlesFile()
            }
            else if (action === QmlSubtitleMenu.Synchronize) {
                trackMenuController.requestSubtitlePage()
            }
            else if (action === QmlSubtitleMenu.Download) {
                Player.openVLsub()
            }
        }
    }

    QmlAudioMenu {
        id: menuAudio

        ctx: MainCtx

        onTriggered: {
            if (action === QmlSubtitleMenu.Open) {
                DialogsProvider.loadAudioFile()
            }
            else if (action === QmlSubtitleMenu.Synchronize) {
                trackMenuController.requestAudioPage()
            }
        }
    }
}
