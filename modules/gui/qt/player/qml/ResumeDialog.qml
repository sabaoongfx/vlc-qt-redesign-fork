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
import QtQuick.Layouts
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

FocusScope {
    id: resumePanel

    property int maxWidth

    // The place where the media was left, in seconds; negative while unknown
    property real watchedTill: -1

    implicitHeight: row.implicitHeight
    // redesign: fit the content (shown as a floating card), never wider than maxWidth
    implicitWidth: Math.min(maxWidth, row.implicitWidth)

    baselineOffset: label.baselineOffset

    visible: false
    enabled: visible

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Resume dialog")

    signal hidden()

    // redesign: explicit state, `visible` reads false while the floating card around it is hidden
    property bool shown: false

    function _hms(seconds) {
        const pad = (n) => String(Math.floor(n)).padStart(2, "0")
        return pad(seconds / 3600) + ":" + pad((seconds % 3600) / 60) + ":" + pad(seconds % 60)
    }

    // The saved position is a fraction of the length in the media library
    function _queryWatchedTill() {
        watchedTill = -1

        if (!MainCtx.mediaLibraryAvailable || !Player.url)
            return

        MainCtx.mediaLibrary.mediaProgress(Player.url, (progress) => {
            const length = Player.length.toSeconds()

            if (progress > 0 && length > 0)
                resumePanel.watchedTill = progress * length
        })
    }

    function showResumePanel ()
    {
        resumePanel.shown = true
        resumePanel.visible = true
        _queryWatchedTill()
        continueBtn.forceActiveFocus()
        resumeTimeout.start()
    }

    function hideResumePanel() {
        resumeTimeout.stop()
        resumePanel.shown = false
        resumePanel.visible = false
        Player.acknowledgeRestoreCallback()
        hidden()
    }

    Timer {
        id: resumeTimeout
        interval: 10000
        onTriggered: {
            resumePanel.shown = false
            resumePanel.visible = false
            hidden()
        }
    }

    Connections {
        target: Player
        function onCanRestorePlaybackChanged() {
            if (Player.canRestorePlayback) {
                showResumePanel()
            } else {
                hideResumePanel()
            }
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }


    Component.onCompleted: {
        if (Player.canRestorePlayback) {
            showResumePanel()
        }
    }

    Navigation.cancelAction: function() {
        hideResumePanel()
    }

    // redesign: Figma "continue watching" card: "You already watched till 00:00:02", an accent
    // "Continue Watching" button and a close button
    Row {
        id: row

        spacing: VLCStyle.margin_normal

        //FIXME use the right xxxLabel class
        T.Label {
            id: label

            anchors.verticalCenter: parent.verticalCenter

            color: theme.fg.primary
            font.pixelSize: VLCStyle.fontSize_normal
            textFormat: Text.StyledText
            elide: Text.ElideRight

            text: (resumePanel.watchedTill >= 0)
                  ? qsTr("You already watched till <b>%1</b>").arg(resumePanel._hms(resumePanel.watchedTill))
                  : qsTr("You already watched this")
        }

        Rectangle {
            id: continueBtn

            anchors.verticalCenter: parent.verticalCenter

            width: continueLabel.implicitWidth + VLCStyle.margin_normal * 2
            height: VLCStyle.dp(34, VLCStyle.scale)
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: theme.accent
            border.width: activeFocus ? VLCStyle.border : 0
            border.color: theme.fg.primary

            focus: true
            activeFocusOnTab: true

            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Continue Watching")
            Accessible.onPressAction: continueBtn.activate()

            AccessibleCompat.id: "resumeContinueButton"

            function activate() {
                Player.restorePlaybackPos()
                resumePanel.hideResumePanel()
            }

            T.Label {
                id: continueLabel

                anchors.centerIn: parent

                text: qsTr("Continue Watching")
                color: "#1A0E02" // dark text on the accent, like the other accent buttons
                font.pixelSize: VLCStyle.fontSize_normal
                font.bold: true
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: continueBtn.activate()
            }

            Navigation.parentItem: resumePanel
            Navigation.rightItem: closeBtn
            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => {
                if (KeyHelper.matchOk(event))
                    continueBtn.activate()
                else
                    continueBtn.Navigation.defaultKeyAction(event)
            }
        }

        Widgets.IconToolButton {
            id: closeBtn

            anchors.verticalCenter: parent.verticalCenter

            text: VLCIcons.close
            description: qsTr("Dismiss")
            font.pixelSize: VLCStyle.icon_banner
            width: VLCStyle.dp(34, VLCStyle.scale)
            height: VLCStyle.dp(34, VLCStyle.scale)

            AccessibleCompat.id: "resumeDismissButton"

            onClicked: resumePanel.hideResumePanel()

            Navigation.parentItem: resumePanel
            Navigation.leftItem: continueBtn
            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => closeBtn.Navigation.defaultKeyAction(event)
        }
    }
}
