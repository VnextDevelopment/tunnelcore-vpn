import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Config"
import "../Controls2/TextTypes"
import "../Components"

PageType {
    id: root

    Rectangle {
        anchors.fill: parent
        color: AmneziaStyle.color.tcBackground
    }

    Connections {
        target: UpdateController

        function onUpdateNotFound() {
            PageController.showNotificationMessage(qsTr("You have the latest version of AmneziaVPN").replace("AmneziaVPN", "TunnelCore VPN"))
        }

        function onUpdateCheckFailed() {
            PageController.showNotificationMessage(qsTr("Failed to check for updates"))
        }
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
        anchors.right: parent.right
        anchors.left: parent.left

        header: ColumnLayout {
            width: listView.width

            IconImageType {
                source: "qrc:/images/icon.png"
                tint: ""
                Layout.alignment: Qt.AlignCenter
                Layout.topMargin: 24
                Layout.preferredWidth: 144
                Layout.preferredHeight: 144
            }

            Header2TextType {
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: "TunnelCore VPN"
                color: AmneziaStyle.color.tcInk
                horizontalAlignment: Text.AlignHCenter
            }

            ParagraphTextType {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Open-source VPN client")
                color: AmneziaStyle.color.tcMuted
            }

            ParagraphTextType {
                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Contacts")
                color: AmneziaStyle.color.tcInk
            }
        }

        model: contacts

        delegate: ColumnLayout {
            width: listView.width

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.topMargin: 6

                text: title
                descriptionText: description
                leftImageSource: imageSource
                textColor: AmneziaStyle.color.tcInk
                descriptionColor: AmneziaStyle.color.tcMuted
                leftImageColor: AmneziaStyle.color.tcBlue

                clickedFunction: handler
            }

            DividerType { color: AmneziaStyle.color.tcStroke }
        }

        footer: ColumnLayout {
            width: listView.width

            CaptionTextType {
                Layout.fillWidth: true
                Layout.topMargin: 40

                horizontalAlignment: Text.AlignHCenter

                text: qsTr("Software version: %1").arg(SettingsController.getAppVersion())
                color: AmneziaStyle.color.tcMuted

                MouseArea {
                    property int clickCount: 0
                    anchors.fill: parent
                    onClicked: {
                        if (clickCount > 10) {
                            SettingsController.enableDevMode()
                        } else {
                            clickCount++
                        }
                    }
                }
            }

            BasicButtonType {
                id: checkUpdatesButton

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                Layout.bottomMargin: 16
                implicitHeight: 48

                defaultColor: AmneziaStyle.color.tcCard
                hoveredColor: AmneziaStyle.color.tcSurfaceBlue
                pressedColor: AmneziaStyle.color.tcStroke
                disabledColor: AmneziaStyle.color.tcBackground
                textColor: AmneziaStyle.color.tcBlue
                borderWidth: 1
                borderColor: AmneziaStyle.color.tcBlue

                enabled: !UpdateController.isCheckRunning

                text: UpdateController.isCheckRunning ? qsTr("Checking...") : qsTr("Check for updates")

                clickedFunc: function() {
                    UpdateController.checkForUpdates()
                }
            }
        }
    }
    
    property list<QtObject> contacts: [
        github
    ]

    QtObject {
        id: github

        readonly property string title: qsTr("GitHub")
        readonly property string description: qsTr("Discover the source code")
        readonly property string imageSource: "qrc:/images/controls/github.svg"
        readonly property var handler: function() {
            Qt.openUrlExternally("https://github.com/VnextDevelopment/tunnelcore-vpn")
        }
    }
}
