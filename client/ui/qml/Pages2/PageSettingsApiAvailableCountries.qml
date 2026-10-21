import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

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

    property var processedServer
    property bool subscriptionExpired: false
    property bool subscriptionExpiringSoon: false
    property bool isSubscriptionRenewalAvailable: false
    property bool isInAppPurchase: false

    function updateSubscriptionState() {
        root.subscriptionExpired = ServersUiController.isServerSubscriptionExpired(ServersUiController.processedServerId)
        root.subscriptionExpiringSoon = ServersUiController.isServerSubscriptionExpiringSoon(ServersUiController.processedServerId)
        root.isSubscriptionRenewalAvailable = ApiAccountInfoModel.data("isSubscriptionRenewalAvailable")
        root.isInAppPurchase = ApiAccountInfoModel.data("isInAppPurchase")
    }

    function selectConnectionCountry(countryIndex, countryCode, countryName) {
        if (countryIndex === ApiCountryModel.currentIndex) {
            return
        }

        PageController.showBusyIndicator(true)
        SubscriptionUiController.updateServiceFromGateway(ServersUiController.processedServerId, countryCode, countryName)
        PageController.showBusyIndicator(false)
    }

    Component.onCompleted: {
        root.updateSubscriptionState()
    }

    Connections {
        target: ServersUiController

        function onProcessedServerIdChanged() {
            root.processedServer = proxyServersModel.get(0)
            root.updateSubscriptionState()
        }
    }

    Connections {
        target: ServersModel

        function onModelReset() {
            root.processedServer = proxyServersModel.get(0)
        }
    }

    Connections {
        target: ApiAccountInfoModel

        function onModelReset() {
            root.updateSubscriptionState()
        }
    }

    SortFilterProxyModel {
        id: proxyServersModel
        objectName: "proxyServersModel"

        sourceModel: ServersModel
        filters: [
            ValueFilter {
                roleName: "serverId"
                value: ServersUiController.processedServerId
            }
        ]

        Component.onCompleted: {
            root.processedServer = proxyServersModel.get(0)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: AmneziaStyle.color.tcBackground
    }

    ListViewType {
        id: menuContent

        anchors.fill: parent

        model: ApiCountryModel

        currentIndex: ApiCountryModel.currentIndex

        ButtonGroup {
            id: containersRadioButtonGroup
        }

        header: ColumnLayout {
            width: menuContent.width

            spacing: 4

            BackButtonType {
                id: backButton
                objectName: "backButton"

                Layout.topMargin: 20 + PageController.safeAreaTopMargin
            }

            HeaderTypeWithButton {
                id: headerContent
                objectName: "headerContent"

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: root.subscriptionExpired || root.subscriptionExpiringSoon ? 0 : 4

                actionButtonImage: "qrc:/images/controls/settings.svg"

                headerText: root.processedServer.name
                headerColor: AmneziaStyle.color.tcInk

                actionButtonFunction: function() {
                    PageController.showBusyIndicator(true)
                    let result = SubscriptionUiController.getAccountInfo(ServersUiController.processedServerId, false)
                    PageController.showBusyIndicator(false)
                    if (!result) {
                        return
                    }

                    PageController.goToPage(PageEnum.PageSettingsApiServerInfo)
                }
            }

            ParagraphTextType {
                visible: root.subscriptionExpired || root.subscriptionExpiringSoon

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 12

                text: root.subscriptionExpired ? qsTr("Subscription expired") : qsTr("Subscription expiring soon")
                color: root.subscriptionExpired ? AmneziaStyle.color.vibrantRed : AmneziaStyle.color.goldenApricot
            }

            BasicButtonType {
                visible: (root.subscriptionExpired || root.subscriptionExpiringSoon)
                    && root.isSubscriptionRenewalAvailable && !root.isInAppPurchase

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 28
                Layout.bottomMargin: 0

                defaultColor: AmneziaStyle.color.tcBlue
                hoveredColor: "#318DF9"
                pressedColor: "#0C62C9"
                textColor: "#FFFFFF"

                text: qsTr("Renew subscription")

                clickedFunc: function() {
                    SubscriptionUiController.getRenewalLink(ServersUiController.processedServerId)
                }
            }

            ParagraphTextType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: (root.subscriptionExpired || root.subscriptionExpiringSoon) ? 12 : 4
                Layout.bottomMargin: 8

                text: qsTr("Location for connection")
                color: AmneziaStyle.color.mutedGray
            }
        }

        delegate: ColumnLayout {
            id: content

            width: menuContent.width
            height: content.implicitHeight

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.topMargin: 6
                implicitHeight: 72
                radius: 18
                color: index === ApiCountryModel.currentIndex
                       ? AmneziaStyle.color.tcSurfaceBlue : AmneziaStyle.color.tcCard
                border.width: 1
                border.color: index === ApiCountryModel.currentIndex
                              ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.tcStroke

            RowLayout {
                anchors.fill: parent
                VerticalRadioButton {
                    id: containerRadioButton

                    Layout.fillWidth: true
                    Layout.leftMargin: 16

                    text: countryName
                    textColor: AmneziaStyle.color.tcInk
                    selectedTextColor: AmneziaStyle.color.tcBlue
                    descriptionColor: AmneziaStyle.color.tcMuted
                    hoveredColor: AmneziaStyle.color.tcSurfaceBlue
                    selectedColor: AmneziaStyle.color.tcSurfaceBlue

                    ButtonGroup.group: containersRadioButtonGroup

                    imageSource: "qrc:/images/controls/download.svg"

                    checked: index === ApiCountryModel.currentIndex
                    checkable: !ConnectionController.isConnected

                    onClicked: {
                        if (ConnectionController.isConnectionInProgress) {
                            PageController.showNotificationMessage(qsTr("Unable change server location while trying to make an active connection"))
                            return
                        }
                        if (ConnectionController.isConnected) {
                            PageController.showNotificationMessage(qsTr("Unable change server location while there is an active connection"))
                            return
                        }

                        root.selectConnectionCountry(index, countryCode, countryName)
                    }

                    Keys.onEnterPressed: {
                        if (checkable) {
                            checked = true
                        }
                        containerRadioButton.clicked()
                    }
                    Keys.onReturnPressed: {
                        if (checkable) {
                            checked = true
                        }
                        containerRadioButton.clicked()
                    }
                }

                Image {
                    Layout.rightMargin: 32
                    Layout.alignment: Qt.AlignRight

                    source: countryImageCode !== "" ? "qrc:/countriesFlags/images/flagKit/" + countryImageCode + ".svg" : ""
                }
            }

            }
            DividerType {
                visible: false
                Layout.fillWidth: true
            }
        }
    }
}
