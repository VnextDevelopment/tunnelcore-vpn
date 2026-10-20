import QtQuick
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
            textColor: AmneziaStyle.color.tcInk
            descriptionColor: AmneziaStyle.color.tcMuted
            rightImageColor: AmneziaStyle.color.tcBlue
            Layout.fillWidth: true
            Layout.topMargin: 16

            visible: ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling

            text: qsTr("Split tunneling on the server")
            descriptionText: qsTr("Enabled \nCan't be disabled for current server")
            rightImageSource: "qrc:/images/controls/chevron-right.svg"

            clickedFunction: function() {
                PageController.goToPage(PageEnum.PageSettingsSplitTunneling)
                root.closeTriggered()
            }
        }

        DividerType {
            visible: ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling
        }

        LabelWithButtonType {
            id: siteBasedSplitTunnelingSwitch
            textColor: AmneziaStyle.color.tcInk
            descriptionColor: AmneziaStyle.color.tcMuted
            rightImageColor: AmneziaStyle.color.tcBlue
            Layout.fillWidth: true
            Layout.topMargin: 16

            text: qsTr("Site-based split tunneling")
            descriptionText: enabled && IpSplitTunnelingController.isSplitTunnelingEnabled ? qsTr("Enabled") : qsTr("Disabled")
            rightImageSource: "qrc:/images/controls/chevron-right.svg"

            clickedFunction: function() {
                PageController.goToPage(PageEnum.PageSettingsSplitTunneling)
                root.closeTriggered()
            }
        }

    }
}
