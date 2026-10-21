import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Config"

PageType {
    id: root

    Rectangle {
        anchors.fill: parent
        color: AmneziaStyle.color.tcBackground
    }

    BackButtonType {
        id: backButton

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + PageController.safeAreaTopMargin
        imageColor: AmneziaStyle.color.tcInk

        onActiveFocusChanged: {
            if(backButton.enabled && backButton.activeFocus) {
                listView.positionViewAtBeginning()
            }
        }
    }

    ListViewType {
        id: listView

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        header: ColumnLayout {

            width: listView.width

            BaseHeaderType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("Connection")
                headerColor: AmneziaStyle.color.tcInk
            }
        }

        model: 1 // fake model to force the ListView to be created without a model

        delegate: ColumnLayout { // TODO(CyAn84): add DelegateChooser when have migrated to 6.9

            width: listView.width

            SwitcherType {
                id: amneziaDnsSwitch

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Use AmneziaDNS")
                descriptionText: qsTr("If AmneziaDNS is installed on the server")
                textColor: AmneziaStyle.color.tcInk
                descriptionTextColor: AmneziaStyle.color.tcMuted
                checkedIndicatorColor: AmneziaStyle.color.tcBlue
                checkedIndicatorBorderColor: AmneziaStyle.color.tcBlue
                checkedInnerCircleColor: AmneziaStyle.color.tcCard
                defaultIndicatorBorderColor: AmneziaStyle.color.tcStroke
                defaultInnerCircleColor: AmneziaStyle.color.tcMuted

                checked: SettingsController.isAmneziaDnsEnabled()
                onToggled: function() {
                    if (checked !== SettingsController.isAmneziaDnsEnabled()) {
                        SettingsController.toggleAmneziaDns(checked)
                    }
                }
            }

            DividerType { color: AmneziaStyle.color.tcStroke }

            LabelWithButtonType {
                id: dnsServersButton

                Layout.fillWidth: true

                text: qsTr("DNS servers")
                descriptionText: qsTr("When AmneziaDNS is not used or installed")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                textColor: AmneziaStyle.color.tcInk
                descriptionColor: AmneziaStyle.color.tcMuted
                rightImageColor: AmneziaStyle.color.tcBlue

                clickedFunction: function() {
                    PageController.goToPage(PageEnum.PageSettingsDns)
                }
            }

            DividerType { color: AmneziaStyle.color.tcStroke }

            LabelWithButtonType {
                id: splitTunnelingButton

                Layout.fillWidth: true

                text: qsTr("Site-based split tunneling")
                descriptionText: qsTr("Allows you to select which sites you want to access through the VPN")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                textColor: AmneziaStyle.color.tcInk
                descriptionColor: AmneziaStyle.color.tcMuted
                rightImageColor: AmneziaStyle.color.tcBlue

                clickedFunction: function() {
                    PageController.goToPage(PageEnum.PageSettingsSplitTunneling)
                }
            }

            DividerType { color: AmneziaStyle.color.tcStroke }

        }

        footer: ColumnLayout { // TODO(CyAn84): move to delegate,add DelegateChooser when have migrated to 6.9

            width: listView.width

            LabelWithButtonType {
                id: killSwitchButton
                visible: !GC.isMobile()

                Layout.fillWidth: true

                text: qsTr("KillSwitch")
                descriptionText: qsTr("Blocks network connections without VPN")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                textColor: AmneziaStyle.color.tcInk
                descriptionColor: AmneziaStyle.color.tcMuted
                rightImageColor: AmneziaStyle.color.tcBlue

                clickedFunction: function() {
                    PageController.goToPage(PageEnum.PageSettingsKillSwitch)
                }
            }

            DividerType {
                visible: GC.isDesktop()
                color: AmneziaStyle.color.tcStroke
            }
        }
    }
}
