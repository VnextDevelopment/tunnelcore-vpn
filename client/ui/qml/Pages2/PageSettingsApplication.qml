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

                headerText: qsTr("Application")
                headerColor: AmneziaStyle.color.tcInk
            }
        }

        model: 1 // fake model to force the ListView to be created without a model

        delegate: ColumnLayout { // TODO(CyAn84): add DelegateChooser when have migrated to 6.9

            width: listView.width

            SwitcherType {
                id: switcherAllowScreenshots

                visible: GC.isMobile()

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Allow application screenshots")
                textColor: AmneziaStyle.color.tcInk
                descriptionTextColor: AmneziaStyle.color.tcMuted
                checkedIndicatorColor: AmneziaStyle.color.tcBlue
                checkedIndicatorBorderColor: AmneziaStyle.color.tcBlue
                checkedInnerCircleColor: AmneziaStyle.color.tcCard
                defaultIndicatorBorderColor: AmneziaStyle.color.tcStroke
                defaultInnerCircleColor: AmneziaStyle.color.tcMuted

                checked: SettingsController.isScreenshotsEnabled()
                onToggled: function() {
                    if (checked !== SettingsController.isScreenshotsEnabled()) {
                        SettingsController.toggleScreenshotsEnabled(checked)
                    }
                }
            }

            DividerType {
                visible: GC.isMobile()
                color: AmneziaStyle.color.tcStroke
            }

            LabelWithButtonType {
                id: labelWithButtonNotification

                visible: Qt.platform.os === "android" && !SettingsController.isNotificationPermissionGranted

                Layout.fillWidth: true

                text: qsTr("Enable notifications")
                descriptionText: qsTr("Enable notifications to show the VPN state in the status bar")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                textColor: AmneziaStyle.color.tcInk
                descriptionColor: AmneziaStyle.color.tcMuted
                rightImageColor: AmneziaStyle.color.tcBlue

                clickedFunction: function() {
                    SettingsController.requestNotificationPermission()
                }
            }

            DividerType {
                visible: Qt.platform.os === "android" && !SettingsController.isNotificationPermissionGranted
                color: AmneziaStyle.color.tcStroke
            }

            SwitcherType {
                id: switcherAutoStart

                visible: !GC.isMobile()

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Auto start")
                descriptionText: qsTr("Launch the application every time the device is starts")
                textColor: AmneziaStyle.color.tcInk
                descriptionTextColor: AmneziaStyle.color.tcMuted
                checkedIndicatorColor: AmneziaStyle.color.tcBlue
                checkedIndicatorBorderColor: AmneziaStyle.color.tcBlue
                checkedInnerCircleColor: AmneziaStyle.color.tcCard
                defaultIndicatorBorderColor: AmneziaStyle.color.tcStroke
                defaultInnerCircleColor: AmneziaStyle.color.tcMuted

                checked: SettingsController.autoStartEnabled
                onToggled: function() {
                    if (checked !== SettingsController.autoStartEnabled) {
                        SettingsController.toggleAutoStart(checked)
                    }
                }
            }

            DividerType {
                visible: !GC.isMobile()
                color: AmneziaStyle.color.tcStroke
            }

            SwitcherType {
                id: switcherAutoConnect

                visible: !GC.isMobile()

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Auto connect")
                descriptionText: qsTr("Connect to VPN on app start")
                textColor: AmneziaStyle.color.tcInk
                descriptionTextColor: AmneziaStyle.color.tcMuted
                checkedIndicatorColor: AmneziaStyle.color.tcBlue
                checkedIndicatorBorderColor: AmneziaStyle.color.tcBlue
                checkedInnerCircleColor: AmneziaStyle.color.tcCard
                defaultIndicatorBorderColor: AmneziaStyle.color.tcStroke
                defaultInnerCircleColor: AmneziaStyle.color.tcMuted

                checked: SettingsController.isAutoConnectEnabled()
                onToggled: function() {
                    if (checked !== SettingsController.isAutoConnectEnabled()) {
                        SettingsController.toggleAutoConnect(checked)
                    }
                }
            }

            DividerType {
                visible: !GC.isMobile() && !IsMacOsNeBuild
                color: AmneziaStyle.color.tcStroke
            }

            SwitcherType {
                id: switcherStartMinimized

                visible: !GC.isMobile()

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Start minimized")
                descriptionText: qsTr("Launch application minimized (works with autostart option turned on)")
                textColor: AmneziaStyle.color.tcInk
                descriptionTextColor: AmneziaStyle.color.tcMuted
                checkedIndicatorColor: AmneziaStyle.color.tcBlue
                checkedIndicatorBorderColor: AmneziaStyle.color.tcBlue
                checkedInnerCircleColor: AmneziaStyle.color.tcCard
                defaultIndicatorBorderColor: AmneziaStyle.color.tcStroke
                defaultInnerCircleColor: AmneziaStyle.color.tcMuted

                enabled: SettingsController.autoStartEnabled
                opacity: enabled ? 1.0 : 0.5

                checked: SettingsController.autoStartEnabled && SettingsController.startMinimized
                onToggled: function() {
                    if (checked !== SettingsController.startMinimized) {
                        SettingsController.toggleStartMinimized(checked)
                    }
                }
            }

            DividerType {
                visible: !GC.isMobile() && ServersUiController.hasServersFromGatewayApi
                color: AmneziaStyle.color.tcStroke
            }

            SwitcherType {
                id: switcherNewsNotificationEnabled

                visible: ServersUiController.hasServersFromGatewayApi

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("News Notification")
                descriptionText: qsTr("Show a notification icon for unread news")
                textColor: AmneziaStyle.color.tcInk
                descriptionTextColor: AmneziaStyle.color.tcMuted
                checkedIndicatorColor: AmneziaStyle.color.tcBlue
                checkedIndicatorBorderColor: AmneziaStyle.color.tcBlue
                checkedInnerCircleColor: AmneziaStyle.color.tcCard
                defaultIndicatorBorderColor: AmneziaStyle.color.tcStroke
                defaultInnerCircleColor: AmneziaStyle.color.tcMuted

                checked: SettingsController.isNewsNotificationsEnabled()
                onToggled: function() {
                    if (checked !== SettingsController.isNewsNotificationsEnabled()) {
                        SettingsController.toggleNewsNotificationsEnabled(checked)
                    }
                }
            }

            DividerType {
                visible: ServersUiController.hasServersFromGatewayApi
                color: AmneziaStyle.color.tcStroke
            }

            SwitcherType {
                id: switcherAutoUpdateCheck

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Check for updates automatically")
                descriptionText: qsTr("Check for a new app version at startup")
                textColor: AmneziaStyle.color.tcInk
                descriptionTextColor: AmneziaStyle.color.tcMuted
                checkedIndicatorColor: AmneziaStyle.color.tcBlue
                checkedIndicatorBorderColor: AmneziaStyle.color.tcBlue
                checkedInnerCircleColor: AmneziaStyle.color.tcCard
                defaultIndicatorBorderColor: AmneziaStyle.color.tcStroke
                defaultInnerCircleColor: AmneziaStyle.color.tcMuted

                checked: SettingsController.isAutoUpdateCheckEnabled()
                onToggled: function() {
                    if (checked !== SettingsController.isAutoUpdateCheckEnabled()) {
                        SettingsController.toggleAutoUpdateCheckEnabled(checked)
                    }
                }
            }

            DividerType {
                visible: !GC.isMobile()
                color: AmneziaStyle.color.tcStroke
            }
        }

        footer: ColumnLayout {

            width: listView.width

            LabelWithButtonType {
                id: labelWithButtonLanguage

                Layout.fillWidth: true

                text: qsTr("Language")
                descriptionText: LanguageUiController.currentLanguageName
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                textColor: AmneziaStyle.color.tcInk
                descriptionColor: AmneziaStyle.color.tcMuted
                rightImageColor: AmneziaStyle.color.tcBlue

                clickedFunction: function() {
                    selectLanguageDrawer.openTriggered()
                }
            }

            DividerType { color: AmneziaStyle.color.tcStroke }

            LabelWithButtonType {
                id: labelWithButtonLogging

                Layout.fillWidth: true

                text: qsTr("Logging")
                descriptionText: SettingsController.isLoggingEnabled ? qsTr("Enabled") : qsTr("Disabled")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                textColor: AmneziaStyle.color.tcInk
                descriptionColor: AmneziaStyle.color.tcMuted
                rightImageColor: AmneziaStyle.color.tcBlue

                clickedFunction: function() {
                    PageController.goToPage(PageEnum.PageSettingsLogging)
                }
            }

            DividerType { color: AmneziaStyle.color.tcStroke }

            LabelWithButtonType {
                id: labelWithButtonReset
                
                Layout.fillWidth: true

                text: qsTr("Reset settings and remove all data from the application")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                textColor: AmneziaStyle.color.vibrantRed
                rightImageColor: AmneziaStyle.color.vibrantRed

                clickedFunction: function() {
                    var headerText = qsTr("Reset settings and remove all data from the application?")
                    var descriptionText = qsTr("All settings will be reset to default. All installed AmneziaVPN services will still remain on the server.")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        if (ServersUiController.isDefaultServerCurrentlyProcessed() && ConnectionController.isConnected) {
                            PageController.showNotificationMessage(qsTr("Cannot reset settings during active connection"))
                        } else
                        {
                            SettingsController.clearSettings()
                            PageController.goToPageHome()
                        }
                    }
                    var noButtonFunction = function() {
                    }

                    showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            DividerType { color: AmneziaStyle.color.tcStroke }
        }
    }

    SelectLanguageDrawer {
        id: selectLanguageDrawer

        width: root.width
        height: root.height
    }
}
