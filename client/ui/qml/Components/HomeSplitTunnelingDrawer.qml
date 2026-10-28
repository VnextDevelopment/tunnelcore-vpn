import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"

DrawerType2 {
    id: root

    defaultColor: AmneziaStyle.color.tcBackground
    borderColor: AmneziaStyle.color.tcStroke
    anchors.fill: parent
    expandedHeight: parent.height * 0.9

    // This is the HOME screen's split-tunneling sheet, not the separate
    // PageSettingsSplitTunneling page. Its controls must receive remote focus
    // when the sheet opens; otherwise D-pad events navigate the tabs behind it.
    readonly property bool remoteNavigationScope: SettingsController.isOnTv() && root.isOpened
    property var focusBeforeOpen: null
    property bool navigatingToSettings: false
    // expandedStateContent is a separate QML Component scope; register its
    // instantiated controls instead of referring to private component ids.
    property var splitServerItem: null
    property var splitSitesItem: null

    function focusableRows() {
        var rows = [root.splitServerItem, root.splitSitesItem]
        return rows.filter(function(item) { return item && item.visible && item.enabled })
    }

    function navigateRemote(forward) {
        if (!root.remoteNavigationScope)
            return false
        var rows = focusableRows()
        if (!rows.length)
            return true
        var current = rows.findIndex(function(item) { return item.activeFocus })
        var next = current < 0 ? 0 : (current + (forward ? 1 : rows.length - 1)) % rows.length
        rows[next].forceActiveFocus(Qt.TabFocusReason)
        return true // never navigate underlying tab/page while sheet is open
    }

    function goToSplitSettings() {
        root.navigatingToSettings = true
        root.closeTriggered()
        PageController.goToPage(PageEnum.PageSettingsSplitTunneling)
    }

    onAboutToShow: {
        navigatingToSettings = false
        if (SettingsController.isOnTv() && root.Window.window)
            focusBeforeOpen = root.Window.window.activeFocusItem
    }

    onOpened: {
        if (SettingsController.isOnTv())
            Qt.callLater(function() {
                if (!root.isOpened)
                    return
                var rows = focusableRows()
                if (rows.length)
                    rows[0].forceActiveFocus(Qt.TabFocusReason)
            })
    }

    onClosed: {
        if (SettingsController.isOnTv() && !root.navigatingToSettings) {
            Qt.callLater(function() {
                var previous = root.focusBeforeOpen
                root.focusBeforeOpen = null
                if (root.isClosed && previous && previous.visible && previous.enabled)
                    FocusController.setFocusItem(previous)
            })
        } else {
            focusBeforeOpen = null
        }
    }

    Keys.onBackPressed: function(event) {
        if (!root.isOpened) return
        root.closeTriggered()
        event.accepted = true
    }
    Keys.onEscapePressed: function(event) {
        if (!root.isOpened) return
        root.closeTriggered()
        event.accepted = true
    }

    expandedStateContent: ColumnLayout {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Header2Type {
            Layout.fillWidth: true
            Layout.topMargin: 24
            Layout.rightMargin: 16
            Layout.leftMargin: 16
            Layout.bottomMargin: 16

            headerText: qsTr("Split tunneling")
            headerColor: AmneziaStyle.color.tcInk
            descriptionColor: AmneziaStyle.color.tcMuted
            descriptionText: qsTr("Allows you to select which sites you want to access through the VPN")
        }

        LabelWithButtonType {
            id: splitTunnelingSwitch
            objectName: "homeSplitServerRow"
            Component.onCompleted: root.splitServerItem = splitTunnelingSwitch
            Component.onDestruction: {
                if (root.splitServerItem === splitTunnelingSwitch) root.splitServerItem = null
            }
            isFocusable: SettingsController.isOnTv()
            rightButton.isFocusable: !SettingsController.isOnTv()
            rightButton.focusPolicy: SettingsController.isOnTv() ? Qt.NoFocus : Qt.StrongFocus
            borderFocusedColor: AmneziaStyle.color.tcBlue
            borderFocusedWidth: SettingsController.isOnTv() ? 3 : 1
            Keys.onPressed: function(event) {
                if (SettingsController.isOnTv() && root.isOpened
                        && (event.key === Qt.Key_Select || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Return)) {
                    root.goToSplitSettings()
                    event.accepted = true
                }
            }
            textColor: AmneziaStyle.color.tcInk
            descriptionColor: AmneziaStyle.color.tcMuted
            rightImageColor: AmneziaStyle.color.tcBlue
            Layout.fillWidth: true
            Layout.topMargin: 16

            visible: ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling

            text: qsTr("Split tunneling on the server")
            descriptionText: qsTr("Enabled \nCan't be disabled for current server")
            rightImageSource: "qrc:/images/controls/chevron-right.svg"

            clickedFunction: root.goToSplitSettings
        }

        DividerType {
            visible: ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling
        }

        LabelWithButtonType {
            id: siteBasedSplitTunnelingSwitch
            objectName: "homeSplitSitesRow"
            Component.onCompleted: root.splitSitesItem = siteBasedSplitTunnelingSwitch
            Component.onDestruction: {
                if (root.splitSitesItem === siteBasedSplitTunnelingSwitch) root.splitSitesItem = null
            }
            isFocusable: SettingsController.isOnTv()
            rightButton.isFocusable: !SettingsController.isOnTv()
            rightButton.focusPolicy: SettingsController.isOnTv() ? Qt.NoFocus : Qt.StrongFocus
            borderFocusedColor: AmneziaStyle.color.tcBlue
            borderFocusedWidth: SettingsController.isOnTv() ? 3 : 1
            Keys.onPressed: function(event) {
                if (SettingsController.isOnTv() && root.isOpened
                        && (event.key === Qt.Key_Select || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Return)) {
                    root.goToSplitSettings()
                    event.accepted = true
                }
            }
            textColor: AmneziaStyle.color.tcInk
            descriptionColor: AmneziaStyle.color.tcMuted
            rightImageColor: AmneziaStyle.color.tcBlue
            Layout.fillWidth: true
            Layout.topMargin: 16

            text: qsTr("Site-based split tunneling")
            descriptionText: enabled && IpSplitTunnelingController.isSplitTunnelingEnabled ? qsTr("Enabled") : qsTr("Disabled")
            rightImageSource: "qrc:/images/controls/chevron-right.svg"

            clickedFunction: root.goToSplitSettings
        }

    }
}
