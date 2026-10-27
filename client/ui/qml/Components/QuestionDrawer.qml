pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

import "../Controls2"
import "../Controls2/TextTypes"

import "../Config"

DrawerType2 {
    id: root

    property string headerText
    property string descriptionText
    property string yesButtonText
    property string noButtonText

    property var yesButtonFunction
    property var noButtonFunction

    // Confirmation sheets are modal for the TV remote. The global focus
    // controller otherwise keeps moving across the page behind the sheet.
    property var focusBeforeOpen: null

    function moveConfirmationFocus(forward) {
        if (!SettingsController.isOnTv() || !root.isExpandedStateActive())
            return
        var buttons = noButton.visible && noButton.enabled
                ? [noButton, yesButton] : [yesButton]
        if (!buttons.length)
            return
        var index = buttons.findIndex(function(button) { return button.activeFocus })
        var next = index < 0 ? 0
                : (index + (forward ? 1 : buttons.length - 1)) % buttons.length
        buttons[next].forceActiveFocus(Qt.TabFocusReason)
    }

    function cancelConfirmation() {
        if (!root.isExpandedStateActive())
            return
        if (root.noButtonFunction && typeof root.noButtonFunction === "function")
            root.noButtonFunction()
        else
            root.closeTriggered()
    }

    onAboutToShow: {
        if (SettingsController.isOnTv() && root.Window.window)
            focusBeforeOpen = root.Window.window.activeFocusItem
    }

    onOpened: {
        if (SettingsController.isOnTv()) {
            Qt.callLater(function() {
                if (!root.isExpandedStateActive())
                    return
                // Start on Cancel: signing out/deleting an account must not be
                // accidentally confirmed by pressing OK a second time.
                var initial = noButton.visible && noButton.enabled ? noButton : yesButton
                initial.forceActiveFocus(Qt.TabFocusReason)
            })
        }
    }

    onClosed: {
        if (SettingsController.isOnTv()) {
            Qt.callLater(function() {
                var previous = root.focusBeforeOpen
                root.focusBeforeOpen = null
                if (root.isCollapsedStateActive() && previous
                        && previous.visible && previous.enabled)
                    FocusController.setFocusItem(previous)
            })
        } else {
            focusBeforeOpen = null
        }
    }

    // Consume Back/Escape inside the modal instead of forwarding it to the
    // page underneath (where it can close a screen instead of the dialog).
    Keys.onBackPressed: function(event) {
        if (!root.isExpandedStateActive()) return
        root.cancelConfirmation()
        event.accepted = true
    }
    Keys.onEscapePressed: function(event) {
        if (!root.isExpandedStateActive()) return
        root.cancelConfirmation()
        event.accepted = true
    }

    expandedStateContent: ColumnLayout {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        spacing: 8

        onImplicitHeightChanged: {
            root.expandedHeight = content.implicitHeight + 32 + PageController.safeAreaBottomMargin
        }

        Header2TextType {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.rightMargin: 16
            Layout.leftMargin: 16

            text: root.headerText
        }

        ParagraphTextType {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.rightMargin: 16
            Layout.leftMargin: 16

            text: root.descriptionText
        }

        BasicButtonType {
            id: yesButton
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.rightMargin: 16
            Layout.leftMargin: 16

            text: root.yesButtonText
            navigationHandler: SettingsController.isOnTv() ? root.moveConfirmationFocus : null
            borderFocusedColor: SettingsController.isOnTv() ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.paleGray
            borderFocusedWidth: SettingsController.isOnTv() ? 3 : 1
            // On TV make the affirmative text readable against the light button.
            textColor: SettingsController.isOnTv() ? AmneziaStyle.color.tcInk : AmneziaStyle.color.midnightBlack

            clickedFunc: function() {
                if (root.yesButtonFunction && typeof root.yesButtonFunction === "function") {
                    root.yesButtonFunction()
                }
            }
        }

        BasicButtonType {
            id: noButton
            Layout.fillWidth: true
            Layout.rightMargin: 16
            Layout.leftMargin: 16

            defaultColor: AmneziaStyle.color.transparent
            hoveredColor: AmneziaStyle.color.translucentWhite
            pressedColor: AmneziaStyle.color.sheerWhite
            disabledColor: AmneziaStyle.color.mutedGray
            textColor: AmneziaStyle.color.paleGray
            borderWidth: 1

            visible: root.noButtonText !== ""

            text: root.noButtonText
            navigationHandler: SettingsController.isOnTv() ? root.moveConfirmationFocus : null
            borderFocusedColor: SettingsController.isOnTv() ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.paleGray
            borderFocusedWidth: SettingsController.isOnTv() ? 3 : 1

            clickedFunc: function() {
                if (root.noButtonFunction && typeof root.noButtonFunction === "function") {
                    root.noButtonFunction()
                }
            }
        }
    }
}
