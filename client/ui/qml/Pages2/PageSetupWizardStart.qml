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
    enableTimer: (SettingsController.isOnTv()) ? false : true

    Flickable {
        id: content

        anchors.top: parent.top
        anchors.bottom: startButton.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 32 + PageController.safeAreaTopMargin
        anchors.bottomMargin: 24
        contentHeight: Math.max(height, branding.implicitHeight)
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: branding

            width: content.width
            y: Math.max(0, (content.height - implicitHeight) / 2)
            spacing: 16

            Image {
                source: "qrc:/images/icon.png"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 160
                Layout.preferredHeight: 160
                Layout.maximumWidth: 160
                Layout.maximumHeight: 160
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Header2TextType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                text: "TunnelCore VPN"
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    BasicButtonType {
        id: startButton
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16 + PageController.safeAreaBottomMargin
        anchors.leftMargin: 16
        anchors.rightMargin: 16

        text: qsTr("Let's get started")

        clickedFunc: function() {
            PageController.goToPage(PageEnum.PageSetupWizardConfigSource)
        }
    }

    Timer {
        interval: 250
        running: SettingsController.isOnTv()
        repeat: true
        onTriggered: {
            startButton.forceActiveFocus()
            if (startButton.activeFocus) {
                running = false
            }
        }
    }

    onVisibleChanged: {
        if (visible && SettingsController.isOnTv()) {
            startButton.forceActiveFocus()
        }
    }
}
