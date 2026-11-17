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
    readonly property bool managedDns: TunnelCoreController.authenticated
    property string selectedMode: SettingsController.tunnelCoreDnsMode

    BackButtonType {
        id: backButton

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        onFocusChanged: {
            if (this.activeFocus) {
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

        property var isServerFromApi: ServersUiController.isDefaultServerFromApi

        enabled: root.managedDns || !isServerFromApi

        Component.onCompleted: {
            if (isServerFromApi && !root.managedDns) {
                PageController.showNotificationMessage(qsTr("Default server does not support custom DNS"))
            }
        }

        header: ColumnLayout {
            width: listView.width
            spacing: 16

            BaseHeaderType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("DNS servers")
            }

            ParagraphTextType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                
                text: root.managedDns
                      ? qsTr("Changes apply the next time you connect. Automatic mode uses TunnelCore DNS when available, otherwise the VPN profile DNS.")
                      : qsTr("If AmneziaDNS is not used or installed")
            }
        }

        model: 1 // fake model to force the ListView to be created without a model

        delegate: ColumnLayout {
            width: listView.width
            spacing: 16

            Repeater {
                model: root.managedDns ? [
                    { key: "auto", label: qsTr("TunnelCore DNS (automatic)") },
                    { key: "cloudflare", label: "Cloudflare" },
                    { key: "google", label: "Google" },
                    { key: "quad9", label: "Quad9" },
                    { key: "custom", label: qsTr("Custom DNS") }
                ] : []

                delegate: BasicButtonType {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    text: (root.selectedMode === modelData.key ? "✓  " : "") + modelData.label
                    defaultColor: root.selectedMode === modelData.key
                                  ? AmneziaStyle.color.tcSurfaceBlue : AmneziaStyle.color.tcCard
                    textColor: AmneziaStyle.color.tcInk
                    borderColor: root.selectedMode === modelData.key
                                 ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.tcStroke
                    borderWidth: 1
                    clickedFunc: function() {
                        root.selectedMode = modelData.key
                        if (modelData.key !== "custom")
                            SettingsController.tunnelCoreDnsMode = modelData.key
                    }
                }
            }

            TextFieldWithHeaderType {
                id: primaryDns
                visible: !root.managedDns || root.selectedMode === "custom"

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("Primary DNS")

                textField.text: SettingsController.primaryDns
                textField.validator: RegularExpressionValidator {
                    regularExpression: InstallController.ipAddressRegExp()
                }
            }

            TextFieldWithHeaderType {
                id: secondaryDns
                visible: !root.managedDns || root.selectedMode === "custom"

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("Secondary DNS")

                textField.text: SettingsController.secondaryDns
                textField.validator: RegularExpressionValidator {
                    regularExpression: InstallController.ipAddressRegExp()
                }
            }

            BasicButtonType {
                id: restoreDefaultButton
                visible: !root.managedDns

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                disabledColor: AmneziaStyle.color.mutedGray
                textColor: AmneziaStyle.color.paleGray
                borderWidth: 1

                text: qsTr("Restore default")

                clickedFunc: function() {
                    var headerText = qsTr("Restore default DNS settings?")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        SettingsController.primaryDns = "1.1.1.1"
                        primaryDns.textField.text = SettingsController.primaryDns
                        SettingsController.secondaryDns = "1.0.0.1"
                        secondaryDns.textField.text = SettingsController.secondaryDns
                        PageController.showNotificationMessage(qsTr("Settings have been reset"))
                    }
                    var noButtonFunction = function() {
                    }

                    showQuestionDrawer(headerText, "", yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            BasicButtonType {
                id: saveButton
                visible: !root.managedDns || root.selectedMode === "custom"

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Save")

                clickedFunc: function() {
                    if (root.managedDns) {
                        if (!SettingsController.saveTunnelCoreCustomDns(
                                primaryDns.textField.text, secondaryDns.textField.text)) {
                            PageController.showNotificationMessage(qsTr("Enter a valid IPv4 DNS address"))
                            return
                        }
                        PageController.showNotificationMessage(qsTr("Settings saved"))
                        return
                    }
                    if (primaryDns.textField.text === "") {
                        primaryDns.errorText = qsTr("Primary DNS cannot be empty")
                        return
                    }
                    primaryDns.errorText = ""
                    secondaryDns.errorText = ""

                    if (primaryDns.textField.text !== SettingsController.primaryDns) {
                        SettingsController.primaryDns = primaryDns.textField.text
                    }
                    if (secondaryDns.textField.text !== SettingsController.secondaryDns) {
                        SettingsController.secondaryDns = secondaryDns.textField.text
                    }
                    PageController.showNotificationMessage(qsTr("Settings saved"))
                }
            }
        }
    }
}
