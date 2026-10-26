/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import QtQuick.Controls.Basic
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs


WindowDialog {
    id: root

    // redesign: the Figma "Customize Player" modal is 1048x654
    width: VLCStyle.dp(1048, VLCStyle.scale)
    height: VLCStyle.dp(654, VLCStyle.scale)

    minimumWidth: 825
    minimumHeight: 400

    modal: true
    title: qsTr("Customize Player")

    contentMargins: 0
    standardButtons: DialogButtonBox.NoButton
    color: viewTheme.bg.primary

    signal unload()

    readonly property ColorContext viewTheme: ColorContext {
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    // Figma: header and body text are a mid grey, the hint below the title is dimmer
    readonly property color textColor: viewTheme.fg.secondary
    readonly property color hintColor: Qt.alpha(viewTheme.fg.secondary, 0.7)

    Component.onCompleted: {
        // Save first, in case the dialog is rejected.
        MainCtx.controlbarProfileModel.save(false)
    }

    onAccepted: {
        MainCtx.controlbarProfileModel.save()
        unload()
    }

    onRejected: (byButton) => {
        // Load saved to discard the changes
        MainCtx.controlbarProfileModel.reload()
        unload()
    }

    function newProfile(profileCreatorFunction) {
        console.assert(typeof profileCreatorFunction === 'function')

        const count = MainCtx.controlbarProfileModel.rowCount()
        const npDialog = DialogsProvider.getTextDialog(null,
                                                       qsTr("Profile Name"),
                                                       qsTr("Please enter the new profile name:"),
                                                       qsTr("Profile %1").arg(count + 1))
        if (!npDialog.ok)
            return

        profileCreatorFunction(npDialog.text)
        MainCtx.controlbarProfileModel.selectedProfile = count
    }

    function _markDirty(text) {
        return (text += " *")
    }

    component FooterButton: T.AbstractButton {
        id: footerButton

        property color backgroundColor
        property color textColor

        implicitWidth: Math.max(VLCStyle.dp(100, VLCStyle.scale), implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
        leftPadding: VLCStyle.margin_normal
        rightPadding: VLCStyle.margin_normal

        focusPolicy: Qt.StrongFocus

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: footerButton.backgroundColor
            opacity: footerButton.hovered || footerButton.visualFocus ? 0.85 : 1
            border.width: footerButton.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: footerButton.textColor
        }

        contentItem: Text {
            text: footerButton.text
            color: footerButton.textColor
            font.family: VLCStyle.fontFamily
            font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
    }

    contentComponent: Item {
        MouseArea {
            anchors.fill: parent

            cursorShape: toolbarEditor.dragActive ? Qt.ForbiddenCursor : Qt.ArrowCursor
        }

        ColumnLayout {
            anchors.fill: parent

            spacing: 0

            // header band: title, hint and the profile controls
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(93, VLCStyle.scale)

                color: root.viewTheme.bg.secondary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
                    anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

                    spacing: VLCStyle.margin_xsmall

                    RowLayout {
                        Layout.fillWidth: true

                        spacing: VLCStyle.margin_xxsmall

                        Text {
                            Layout.fillWidth: true

                            text: qsTr("Customize Player")
                            color: root.textColor
                            font.family: VLCStyle.fontFamily
                            font.pixelSize: VLCStyle.fontSize_large
                            elide: Text.ElideRight
                        }

                        Widgets.ComboBoxExt {
                            id: comboBox

                            Layout.minimumWidth: VLCStyle.combobox_width_large
                            Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)

                            // this is not proper way to do it,
                            // but ComboBoxExt does not provide
                            // correct implicit width:
                            implicitWidth: implicitContentWidth
                            font.pixelSize: VLCStyle.fontSize_normal

                            delegate: ItemDelegate {
                                width: comboBox.width
                                leftPadding: comboBox.leftPadding
                                background: Item {}
                                contentItem: Text {
                                    text: model.dirty ? _markDirty(model.name)
                                                      : model.name
                                    color: comboBox.color
                                    font: comboBox.font
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                highlighted: (comboBox.highlightedIndex === index)
                            }

                            displayText: {
                                let text

                                if (!!MainCtx.controlbarProfileModel.currentModel)
                                    text = MainCtx.controlbarProfileModel.currentModel.name
                                else {
                                    text = "N/A"
                                    return text
                                }

                                if (MainCtx.controlbarProfileModel.currentModel.dirty)
                                    return _markDirty(text)
                                else
                                    return text
                            }

                            model: MainCtx.controlbarProfileModel

                            currentIndex: MainCtx.controlbarProfileModel.selectedProfile

                            onCurrentIndexChanged: {
                                MainCtx.controlbarProfileModel.selectedProfile = currentIndex
                            }

                            Accessible.name: qsTr("Profiles")
                        }

                        Widgets.IconToolButton {
                            description: qsTr("Clone the selected profile")
                            text: VLCIcons.ic_fluent_document_copy_24_regular

                            onClicked: {
                                root.newProfile(MainCtx.controlbarProfileModel.cloneSelectedProfile)
                            }
                        }

                        Widgets.IconToolButton {
                            description: qsTr("New profile")
                            text: VLCIcons.ic_fluent_document_add_24_regular

                            onClicked: {
                                root.newProfile(MainCtx.controlbarProfileModel.newProfile)
                            }
                        }

                        Widgets.IconToolButton {
                            description: qsTr("Delete the current profile.\nDeleting all profiles brings back the default styles.")
                            text: VLCIcons.del

                            onClicked: {
                                  MainCtx.controlbarProfileModel.deleteSelectedProfile()
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true

                        text: qsTr("Drag items from the box below into the bars to add them, drag them around to re-order them, and drag them back into the box to remove them from the player.")
                        color: root.hintColor
                        font.family: VLCStyle.fontFamily
                        font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
                        elide: Text.ElideRight
                    }
                }
            }

            // The main context of the toolbareditor dialog:
            ToolbarEditor {
                id: toolbarEditor

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
                Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
                Layout.topMargin: VLCStyle.margin_small
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
                Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
                Layout.topMargin: VLCStyle.margin_small
                Layout.bottomMargin: VLCStyle.dp(18, VLCStyle.scale)

                FooterButton {
                    text: qsTr("Cancel")
                    backgroundColor: root.colorContext.bg.secondary
                    textColor: root.textColor

                    onClicked: root.rejected(true)
                }

                Item {
                    Layout.fillWidth: true
                }

                FooterButton {
                    text: qsTr("Save")
                    // Figma accent-dim #371F06 in the dark theme, like the seek bar fill
                    backgroundColor: root.viewTheme.palette.isDark ? "#371F06" : Qt.alpha(root.viewTheme.accent, 0.2)
                    textColor: root.viewTheme.accent

                    onClicked: root.accepted()
                }
            }
        }
    }
}
