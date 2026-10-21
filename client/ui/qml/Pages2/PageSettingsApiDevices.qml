import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QtCore

import SortFilterProxyModel 0.2

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    Rectangle {
        anchors.fill: parent
        color: AmneziaStyle.color.tcBackground
    }

    ListViewType {
        id: listView

        anchors.fill: parent
        anchors.topMargin: 20 + PageController.safeAreaTopMargin
        anchors.bottomMargin: 24

        model: ApiDevicesModel

        header: ColumnLayout {
            width: listView.width

            BackButtonType {
                id: backButton
            }

            BaseHeaderType {
                id: header

                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                headerText: qsTr("Active Devices")
                headerColor: AmneziaStyle.color.tcInk
                descriptionText: qsTr("Manage currently connected devices")
            }

            WarningType {
                Layout.topMargin: 16
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.fillWidth: true

                textString: qsTr("You can find the identifier on the Support tab or, for older versions of the app, "
                                 + "by tapping '+' and then the three dots at the top of the page.")

                iconPath: "qrc:/images/controls/alert-circle.svg"
            }
        }

        delegate: Item {
            width: listView.width
            height: deviceCard.implicitHeight + 12

            Rectangle {
                id: deviceCard
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 4
                implicitHeight: deviceRow.implicitHeight + 8
                radius: 20
                color: AmneziaStyle.color.tcCard
                border.width: 1
                border.color: AmneziaStyle.color.tcStroke

            LabelWithButtonType {
                id: deviceRow
                anchors.fill: parent
                anchors.margins: 4
                textColor: AmneziaStyle.color.tcInk
                descriptionColor: AmneziaStyle.color.tcMuted
                rightImageColor: AmneziaStyle.color.tcBlue

                text: osVersion + (isCurrentDevice ? qsTr(" (current device)") : "")
                descriptionText: qsTr("Support tag: ") + "\n" + supportTag + "\n" + qsTr("Last updated: ") + lastUpdate
                rightImageSource: "qrc:/images/controls/trash.svg"

                clickedFunction: function() {
                    if (isCurrentDevice && ServersUiController.isDefaultServerCurrentlyProcessed() && ConnectionController.isConnected) {
                        PageController.showNotificationMessage(qsTr("Cannot unlink device during active connection"))
                        return
                    }

                    var headerText = qsTr("Are you sure you want to unlink this device?")
                    var descriptionText = qsTr("This will unlink the device from your subscription. You can reconnect it anytime by pressing \"Reload API config\" in subscription settings on device.")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        var serverId = ServersUiController.processedServerId
                        Qt.callLater(deactivateExternalDevice, serverId, supportTag, countryCode)
                    }
                    var noButtonFunction = function() {
                    }

                    showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }
            }
        }
    }

    function deactivateExternalDevice(serverId, supportTag, countryCode) {
        PageController.showBusyIndicator(true)
        if (SubscriptionUiController.deactivateExternalDevice(serverId, supportTag, countryCode)) {
            SubscriptionUiController.getAccountInfo(serverId, true)
        }
        PageController.showBusyIndicator(false)
    }
}
