import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"

PageType {
    id: root

    Connections {
        target: ApiNewsController
        function onFetchNewsFinished() {
            PageController.showBusyIndicator(false)
        }
        
        function onErrorOccurred(errorCode, showError) {
            if (showError) {
                PageController.showErrorMessage(errorCode)
                PageController.closePage()
                PageController.showBusyIndicator(false)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: AmneziaStyle.color.tcBackground
    }

    ListViewType {
        id: listView

        anchors.fill: parent

        header: ColumnLayout {
            width: listView.width

            BaseHeaderType {
                id: header
                Layout.fillWidth: true
                Layout.topMargin: 24 + PageController.safeAreaTopMargin
                Layout.bottomMargin: 16
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                headerText: qsTr("Settings")
                headerColor: AmneziaStyle.color.tcInk
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 16
                implicitHeight: profileSummary.implicitHeight + 36
                visible: TunnelCoreController.authenticated
                radius: 22
                color: AmneziaStyle.color.tcSurfaceBlue
                border.color: AmneziaStyle.color.tcStroke
                border.width: 1

                ColumnLayout {
                    id: profileSummary
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: TunnelCoreController.username
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        color: AmneziaStyle.color.tcInk
                        elide: Text.ElideMiddle
                    }

                    Text {
                        Layout.fillWidth: true
                        text: TunnelCoreController.subscriptionStatusText
                        font.pixelSize: 14
                        color: AmneziaStyle.color.tcMuted
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        model: settingsEntries

        delegate: Item {
            width: listView.width
            height: isVisible ? 84 : 0
            visible: isVisible

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 4
                height: 76
                radius: 18
                color: AmneziaStyle.color.tcCard
                border.width: 1
                border.color: AmneziaStyle.color.tcStroke

                LabelWithButtonType {
                    anchors.fill: parent
                    text: title
                    textColor: AmneziaStyle.color.tcInk
                    descriptionColor: AmneziaStyle.color.tcMuted
                    rightImageColor: AmneziaStyle.color.tcBlue
                    leftImageColor: AmneziaStyle.color.tcBlue
                    rightImageSource: "qrc:/images/controls/chevron-right.svg"
                    leftImageSource: leftImagePath
                    clickedFunction: clickedHandler
                }
            }
        }

        footer: ColumnLayout {
            width: listView.width

            LabelWithButtonType {
                id: close

                visible: GC.isDesktop()
                Layout.fillWidth: true

                text: qsTr("Close application")
                textColor: AmneziaStyle.color.tcInk
                leftImageColor: AmneziaStyle.color.tcBlue
                leftImageSource: "qrc:/images/controls/x-circle.svg"
                isLeftImageHoverEnabled: false

                clickedFunction: function() {
                    PageController.closeApplication()
                }
            }

            DividerType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                visible: GC.isDesktop()
            }
        }
    }

    property list<QtObject> settingsEntries: [
        tunnelCoreAccount,
        connection,
        application,
        news,
        backup,
        about,
        devConsole
    ]

    QtObject {
        id: tunnelCoreAccount
        property string title: qsTr("TunnelCore account")
        readonly property string leftImagePath: "qrc:/images/controls/server.svg"
        property bool isVisible: true
        readonly property var clickedHandler: function() {
            PageController.goToPage(PageEnum.PageTunnelCoreAccount)
        }
    }

    QtObject {
        id: servers

        property string title: qsTr("Servers")
        readonly property string leftImagePath: "qrc:/images/controls/server.svg"
        property bool isVisible: true
        readonly property var clickedHandler: function() {
            PageController.goToPage(PageEnum.PageSettingsServersList)
        }
    }

    QtObject {
        id: connection

        property string title: qsTr("Connection")
        readonly property string leftImagePath: "qrc:/images/controls/radio.svg"
        property bool isVisible: true
        readonly property var clickedHandler: function() {
            PageController.goToPage(PageEnum.PageSettingsConnection)
        }
    }

    QtObject {
        id: application

        property string title: qsTr("Application")
        readonly property string leftImagePath: "qrc:/images/controls/app.svg"
        property bool isVisible: true
        readonly property var clickedHandler: function() {
            PageController.goToPage(PageEnum.PageSettingsApplication)
        }
    }

    QtObject {
        id: news

        property string title: qsTr("News & Notifications")
        readonly property string leftImagePath: NewsModel.hasUnread && SettingsController.isNewsNotificationsEnabled() ? "qrc:/images/controls/news-unread.svg" : "qrc:/images/controls/news.svg"
        property bool isVisible: ServersUiController.hasServersFromGatewayApi
        readonly property var clickedHandler: function() {
            if (!ServersUiController.hasServersFromGatewayApi) {
                return;
            }
            PageController.showBusyIndicator(true)
            ApiNewsController.fetchNews(true)
            PageController.goToPage(PageEnum.PageSettingsNewsNotifications)
        }
    }

    QtObject {
        id: backup

        property string title: qsTr("Backup")
        readonly property string leftImagePath: "qrc:/images/controls/save.svg"
        property bool isVisible: true
        readonly property var clickedHandler: function() {
            PageController.goToPage(PageEnum.PageSettingsBackup)
        }
    }

    QtObject {
        id: about

        property string title: qsTr("About TunnelCore VPN")
        readonly property string leftImagePath: "qrc:/images/controls/info.svg"
        property bool isVisible: true
        readonly property var clickedHandler: function() {
            PageController.goToPage(PageEnum.PageSettingsAbout)
        }
    }

    QtObject {
        id: devConsole

        property string title: qsTr("Dev console")
        readonly property string leftImagePath: "qrc:/images/controls/bug.svg"
        property bool isVisible: SettingsController.isDevModeEnabled
        readonly property var clickedHandler: function() {
            PageController.goToPage(PageEnum.PageDevMenu)
        }
    }
}
