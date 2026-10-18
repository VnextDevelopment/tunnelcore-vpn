pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PageEnum 1.0
import Style 1.0

import "../Controls2"
import "../Controls2/TextTypes"
import "../Components"

PageType {
    id: root
    property bool emailMode: false
    property bool registrationMode: false
    property string pendingVpnCountry: ""
    property bool connectAfterImport: false
    property bool importingProfile: false

    // The account page is inside PageStart's IME-adjusted StackView.
    // Bring the focused input into view when the keyboard reduces its height.
    function keepFocusedInputVisible() {
        if (!root.visible || TunnelCoreController.authenticated || scroll.height <= 0)
            return

        var focusedField = null
        if (loginField.textField.activeFocus)
            focusedField = loginField
        else if (passwordField.visible && passwordField.textField.activeFocus)
            focusedField = passwordField
        else if (confirmPasswordField.visible && confirmPasswordField.textField.activeFocus)
            focusedField = confirmPasswordField

        if (!focusedField)
            return

        var fieldTop = focusedField.mapToItem(content, 0, 0).y
        var fieldBottom = fieldTop + focusedField.height
        var margin = 16
        var targetY = scroll.contentY
        if (fieldBottom + margin > scroll.contentY + scroll.height)
            targetY = fieldBottom + margin - scroll.height
        else if (fieldTop - margin < scroll.contentY)
            targetY = fieldTop - margin

        scroll.contentY = Math.max(0, Math.min(targetY,
                                              Math.max(0, scroll.contentHeight - scroll.height)))
    }

    function selectVpnCountry(countryCode) {
        if (TunnelCoreController.busy || pendingVpnCountry.length > 0 || importingProfile)
            return

        if ((countryCode === "AUTO" && TunnelCoreController.vpnCountryMode === "auto")
                || (TunnelCoreController.vpnCountryMode === "country"
                    && countryCode === TunnelCoreController.selectedVpnCountry))
            return

        pendingVpnCountry = countryCode
        if (ConnectionController.isConnected || ConnectionController.isConnectionInProgress) {
            ConnectionController.closeConnection()
            return
        }

        pendingVpnCountry = ""
        TunnelCoreController.selectVpnCountry(countryCode)
    }

    function connectSelectedLocation() {
        if (TunnelCoreController.busy || pendingVpnCountry.length > 0 || importingProfile)
            return

        if (ConnectionController.isConnected || ConnectionController.isConnectionInProgress) {
            ConnectionController.connectButtonClicked()
            return
        }
        if (ImportController.activateTunnelCoreProfile(TunnelCoreController.selectedProfileKey)) {
            ConnectionController.connectButtonClicked()
        } else {
            connectAfterImport = true
            TunnelCoreController.selectCurrentConfig()
        }
    }

    function localizedTariffName(subscription) {
        const tariffCode = subscription.tariff_code ? String(subscription.tariff_code) : ""
        const tariffName = subscription.tariff ? String(subscription.tariff) : ""
        // Older API versions return only the Russian database label. Keep the
        // fallback until all deployed servers include the stable tariff code.
        const compactName = tariffName.replace(/\s/g, "")

        if (tariffCode === "trial-vpn-24h" || compactName === "ПробныйVPN—24часа")
            return qsTr("Trial VPN — 24 hours")
        if (tariffCode === "vpn-month" || compactName === "VPN—1месяц")
            return qsTr("VPN — 1 month")
        if (tariffCode === "vpn-year" || compactName === "VPN—1год")
            return qsTr("VPN — 1 year")

        return tariffName
    }

    function selectMode(email) {
        if (TunnelCoreController.busy || emailMode === email)
            return
        emailMode = email
        registrationMode = false
        loginField.textField.text = ""
        passwordField.textField.text = ""
        confirmPasswordField.textField.text = ""
        TunnelCoreController.clearError()
    }

    function submit() {
        if (!TunnelCoreController.busy) {
            if (emailMode) {
                if (registrationMode
                        && passwordField.textField.text !== confirmPasswordField.textField.text) {
                    confirmPasswordField.textField.forceActiveFocus()
                    return
                }
                if (registrationMode)
                    TunnelCoreController.registerEmail(loginField.textField.text, passwordField.textField.text)
                else
                    TunnelCoreController.loginEmail(loginField.textField.text, passwordField.textField.text)
            } else {
                TunnelCoreController.loginCode(loginField.textField.text)
            }
        }
    }

    Connections {
        target: TunnelCoreController
        function onSignedIn() {
            loginField.textField.text = ""
            passwordField.textField.text = ""
            confirmPasswordField.textField.text = ""
            Qt.inputMethod.hide()
        }
        function onConfigReady(data, fileName, obfuscationMode, obfuscationProfile) {
            if (!root.visible)
                return
            root.importingProfile = true
            ImportController.importTunnelCoreConfig(
                data,
                fileName,
                TunnelCoreController.selectedProfileKey,
                obfuscationMode,
                obfuscationProfile)
        }
        function onChanged() {
            if (TunnelCoreController.error.length > 0 || !TunnelCoreController.authenticated)
                root.connectAfterImport = false
        }
    }

    Connections {
        target: ImportController
        function onImportFinished() {
            if (!root.importingProfile)
                return
            root.importingProfile = false
            if (root.connectAfterImport) {
                root.connectAfterImport = false
                ConnectionController.connectButtonClicked()
            }
        }
        function onImportErrorOccurred(error, goToPageHome) {
            root.importingProfile = false
            root.connectAfterImport = false
        }
    }

    Connections {
        target: ConnectionController
        function onConnectionStateChanged() {
            if (root.pendingVpnCountry.length === 0
                    || ConnectionController.isConnected
                    || ConnectionController.isConnectionInProgress) {
                return
            }

            const countryCode = root.pendingVpnCountry
            root.pendingVpnCountry = ""
            TunnelCoreController.selectVpnCountry(countryCode)
        }
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.topMargin: PageController.safeAreaTopMargin + 24
        // PageStart already reserves the IME inset in the StackView height.
        // Adding imeHeight again clips these fields behind the keyboard.
        anchors.bottomMargin: PageController.safeAreaBottomMargin + 16
        contentHeight: content.implicitHeight + 24
        onHeightChanged: Qt.callLater(root.keepFocusedInputVisible)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: Math.min(scroll.width - 32, 440)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Image {
                source: "qrc:/images/icon.png"
                visible: !TunnelCoreController.authenticated
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 88
                Layout.preferredHeight: 88
                fillMode: Image.PreserveAspectFit
            }
            Header2TextType {
                Layout.fillWidth: true
                text: "TunnelCore VPN"
                horizontalAlignment: Text.AlignHCenter
            }
            SmallTextType {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: TunnelCoreController.authenticated ? TunnelCoreController.username : qsTr("Sign in to your account")
                horizontalAlignment: Text.AlignHCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: !TunnelCoreController.authenticated
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    BasicButtonType {
                        Layout.fillWidth: true
                        text: qsTr("Bot code")
                        enabled: !TunnelCoreController.busy
                        defaultColor: root.emailMode ? AmneziaStyle.color.charcoalGray : AmneziaStyle.color.paleGray
                        clickedFunc: function() { root.selectMode(false) }
                    }
                    BasicButtonType {
                        Layout.fillWidth: true
                        text: "Email"
                        enabled: !TunnelCoreController.busy
                        defaultColor: root.emailMode ? AmneziaStyle.color.paleGray : AmneziaStyle.color.charcoalGray
                        clickedFunc: function() { root.selectMode(true) }
                    }
                }
                SmallTextType {
                    Layout.fillWidth: true
                    text: root.emailMode
                          ? (root.registrationMode
                             ? qsTr("Create a TunnelCore account with your email and password.")
                             : qsTr("Enter the email and password for your TunnelCore account."))
                          : qsTr("Enter the six-digit code from the TunnelCore bot.")
                }
                BasicButtonType {
                    Layout.fillWidth: true
                    visible: root.emailMode
                    text: root.registrationMode
                          ? qsTr("Already have an account? Sign in")
                          : qsTr("Create account")
                    enabled: !TunnelCoreController.busy
                    defaultColor: AmneziaStyle.color.transparent
                    textColor: AmneziaStyle.color.goldenApricot
                    clickedFunc: function() {
                        root.registrationMode = !root.registrationMode
                        passwordField.textField.text = ""
                        confirmPasswordField.textField.text = ""
                        TunnelCoreController.clearError()
                    }
                }
                TextFieldWithHeaderType {
                    id: loginField
                    textField.onActiveFocusChanged: {
                        if (loginField.textField.activeFocus)
                            Qt.callLater(root.keepFocusedInputVisible)
                    }
                    Layout.fillWidth: true
                    enabled: !TunnelCoreController.busy
                    headerText: root.emailMode ? qsTr("Email") : qsTr("Bot code")
                    textField.placeholderText: root.emailMode ? "name@example.com" : "000000"
                    textField.maximumLength: root.emailMode ? 320 : 6
                    textField.inputMethodHints: root.emailMode
                                                ? Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                                                  | Qt.ImhSensitiveData | Qt.ImhEmailCharactersOnly
                                                : Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                    textField.onAccepted: {
                        if (root.emailMode)
                            passwordField.textField.forceActiveFocus()
                        else
                            root.submit()
                    }
                }
                TextFieldWithHeaderType {
                    id: passwordField
                    textField.onActiveFocusChanged: {
                        if (passwordField.textField.activeFocus)
                            Qt.callLater(root.keepFocusedInputVisible)
                    }
                    Layout.fillWidth: true
                    visible: root.emailMode
                    enabled: !TunnelCoreController.busy
                    headerText: qsTr("Password")
                    textField.echoMode: TextInput.Password
                    textField.maximumLength: 1024
                    textField.onAccepted: root.submit()
                }
                TextFieldWithHeaderType {
                    id: confirmPasswordField
                    textField.onActiveFocusChanged: {
                        if (confirmPasswordField.textField.activeFocus)
                            Qt.callLater(root.keepFocusedInputVisible)
                    }
                    Layout.fillWidth: true
                    visible: root.emailMode && root.registrationMode
                    enabled: !TunnelCoreController.busy
                    headerText: qsTr("Confirm password")
                    textField.echoMode: TextInput.Password
                    textField.maximumLength: 1024
                    textField.onAccepted: root.submit()
                }
                SmallTextType {
                    Layout.fillWidth: true
                    visible: root.emailMode && root.registrationMode
                             && confirmPasswordField.textField.text.length > 0
                             && passwordField.textField.text !== confirmPasswordField.textField.text
                    text: qsTr("Passwords do not match.")
                    color: AmneziaStyle.color.vibrantRed
                }
                BasicButtonType {
                    Layout.fillWidth: true
                    text: TunnelCoreController.busy
                          ? (root.registrationMode ? qsTr("Creating account…") : qsTr("Signing in…"))
                          : (root.registrationMode ? qsTr("Create account") : qsTr("Sign in"))
                    enabled: !TunnelCoreController.busy
                             && (root.emailMode
                                 ? loginField.textField.text.trim().length > 0
                                   && passwordField.textField.text.length > 0
                                   && (!root.registrationMode
                                       || passwordField.textField.text === confirmPasswordField.textField.text)
                                 : loginField.textField.text.trim().length === 6)
                    clickedFunc: root.submit
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: TunnelCoreController.authenticated
                spacing: 16

                ConnectButton {
                    objectName: "accountConnectButton"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 16
                    Layout.bottomMargin: 16
                    enabled: !TunnelCoreController.busy && !root.importingProfile
                             && root.pendingVpnCountry.length === 0
                    clickedFunc: root.connectSelectedLocation
                }
                BasicButtonType {
                    objectName: "accountSplitTunnelingButton"
                    enabled: !TunnelCoreController.busy && !root.importingProfile
                             && root.pendingVpnCountry.length === 0
                    Layout.fillWidth: true
                    readonly property bool splitEnabled: IpSplitTunnelingController.isSplitTunnelingEnabled
                            || AppSplitTunnelingController.isSplitTunnelingEnabled
                            || ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling
                    text: splitEnabled ? qsTranslate("PageHome", "Split tunneling enabled")
                                       : qsTranslate("PageHome", "Split tunneling disabled")
                    leftImageSource: "qrc:/images/controls/split-tunneling.svg"
                    rightImageSource: "qrc:/images/controls/chevron-down.svg"
                    defaultColor: AmneziaStyle.color.charcoalGray
                    textColor: AmneziaStyle.color.paleGray
                    clickedFunc: function() { splitTunnelingDrawer.openTriggered() }
                }

                SmallTextType {
                    Layout.fillWidth: true
                    visible: TunnelCoreController.busy || root.pendingVpnCountry.length > 0
                    text: qsTr("Loading data…")
                }
                LabelWithButtonType {
                    Layout.fillWidth: true
                    visible: TunnelCoreController.subscriptions.length > 0
                    text: root.localizedTariffName(TunnelCoreController.primarySubscription)
                    descriptionText: qsTr("Until %1").arg(Qt.formatDateTime(
                                         new Date(TunnelCoreController.primarySubscription.expires_at),
                                         "dd.MM.yyyy"))
                    rightImageSource: "qrc:/images/controls/chevron-right.svg"
                    clickedFunction: function() { subscriptionsDrawer.openTriggered() }
                }

                Rectangle {
                    id: accountSubscriptionWarning
                    Layout.fillWidth: true
                    implicitHeight: subscriptionWarningContent.implicitHeight + 32
                    radius: 16
                    visible: TunnelCoreController.subscriptionWarningVisible
                    color: AmneziaStyle.color.translucentWhite
                    border.width: 1
                    border.color: TunnelCoreController.subscriptionExpired
                                  ? AmneziaStyle.color.vibrantRed
                                  : AmneziaStyle.color.accentWarning

                    ColumnLayout {
                        id: subscriptionWarningContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 10

                        Header2TextType {
                            Layout.fillWidth: true
                            text: TunnelCoreController.subscriptionExpired
                                  ? qsTr("VPN subscription inactive")
                                  : qsTr("VPN subscription expires soon")
                        }
                        SmallTextType {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: TunnelCoreController.subscriptionStatusText
                            color: AmneziaStyle.color.paleGray
                        }
                        BasicButtonType {
                            Layout.fillWidth: true
                            visible: TunnelCoreController.usesAppleBilling
                                     || TunnelCoreController.externalRenewalLinkAllowed
                            text: TunnelCoreController.usesAppleBilling
                                  ? qsTr("Renew in App Store")
                                  : (TunnelCoreController.emailAccount && !TunnelCoreController.telegramLinked
                                     ? qsTr("Link Telegram to renew")
                                     : qsTr("Renew in Telegram"))
                            enabled: !TunnelCoreController.busy
                            defaultColor: TunnelCoreController.subscriptionExpired
                                          ? AmneziaStyle.color.vibrantRed
                                          : AmneziaStyle.color.accentWarning
                            hoveredColor: defaultColor
                            clickedFunc: function() { TunnelCoreController.renewSubscription() }
                        }
                        SmallTextType {
                            Layout.fillWidth: true
                            visible: !TunnelCoreController.usesAppleBilling
                                     && !TunnelCoreController.externalRenewalLinkAllowed
                            textFormat: Text.PlainText
                            text: qsTr("Renew your TunnelCore subscription outside the app. Telegram users can use @tunnelcoree_bot. After renewal, return here and tap Refresh.")
                            color: AmneziaStyle.color.paleGray
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: TunnelCoreController.vpnCountries.length > 0
                    spacing: 8

                    Header2TextType {
                        Layout.fillWidth: true
                        text: qsTr("VPN location")
                    }
                    SmallTextType {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: TunnelCoreController.vpnCountryMode === "auto"
                              ? (TunnelCoreController.effectiveVpnCountry.length > 0
                                 ? qsTr("Automatic — %1").arg(
                                       TunnelCoreController.vpnCountryDisplayName(
                                           TunnelCoreController.effectiveVpnCountry))
                                 : qsTr("Automatic"))
                              : qsTr("Selected: %1").arg(
                                    TunnelCoreController.vpnCountryDisplayName(
                                        TunnelCoreController.selectedVpnCountry))
                    }
                    SmallTextType {
                        Layout.fillWidth: true
                        text: qsTr("Automatic selects an available VPN server. Choosing a country moves your VPN access to that country.")
                    }
                    BasicButtonType {
                        Layout.fillWidth: true
                        readonly property bool isSelected: TunnelCoreController.vpnCountryMode === "auto"
                        text: qsTr("Automatic")
                        enabled: !TunnelCoreController.busy && root.pendingVpnCountry.length === 0
                        defaultColor: isSelected ? AmneziaStyle.color.goldenApricot
                                                 : AmneziaStyle.color.paleGray
                        hoveredColor: isSelected ? AmneziaStyle.color.goldenApricot
                                                 : AmneziaStyle.color.lightGray
                        clickedFunc: function() { root.selectVpnCountry("AUTO") }
                    }
                    Repeater {
                        model: TunnelCoreController.vpnCountries
                        delegate: BasicButtonType {
                            required property var modelData
                            Layout.fillWidth: true
                            readonly property string countryCode: modelData.code ? String(modelData.code) : ""
                            readonly property string cities: modelData.cities && modelData.cities.length > 0
                                                             ? modelData.cities.join(", ") : ""
                            readonly property bool isSelected: TunnelCoreController.vpnCountryMode === "country"
                                                               && TunnelCoreController.selectedVpnCountry === countryCode
                            text: TunnelCoreController.vpnCountryDisplayName(countryCode)
                                  + (cities.length > 0 ? " · " + cities : "")
                            buttonTextLabel.elide: Text.ElideRight
                            enabled: !TunnelCoreController.busy && root.pendingVpnCountry.length === 0
                            defaultColor: isSelected ? AmneziaStyle.color.goldenApricot
                                                     : AmneziaStyle.color.paleGray
                            hoveredColor: isSelected ? AmneziaStyle.color.goldenApricot
                                                     : AmneziaStyle.color.lightGray
                            clickedFunc: function() {
                                root.selectVpnCountry(countryCode)
                            }
                        }
                    }
                }
                SmallTextType {
                    Layout.fillWidth: true
                    visible: !TunnelCoreController.busy && !TunnelCoreController.error
                             && TunnelCoreController.configs.length === 0
                    text: qsTr("No VPN configurations are available. Check your subscription in the bot and refresh the list.")
                }
                BasicButtonType {
                    Layout.fillWidth: true
                    text: qsTr("Refresh")
                    enabled: !TunnelCoreController.busy && root.pendingVpnCountry.length === 0
                             && !ConnectionController.isConnected && !ConnectionController.isConnectionInProgress
                    clickedFunc: function() { TunnelCoreController.refresh() }
                }
                DividerType {
                    Layout.fillWidth: true
                    Layout.topMargin: 28
                }
                Header2TextType {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    text: qsTr("Account")
                }
                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    text: qsTr("Sign out of account")
                    enabled: !TunnelCoreController.busy && !root.importingProfile
                             && root.pendingVpnCountry.length === 0
                    defaultColor: AmneziaStyle.color.transparent
                    hoveredColor: AmneziaStyle.color.translucentWhite
                    pressedColor: AmneziaStyle.color.translucentWhite
                    borderColor: AmneziaStyle.color.vibrantRed
                    borderWidth: 1
                    textColor: AmneziaStyle.color.vibrantRed
                    clickedFunc: function() {
                        showQuestionDrawer(
                            qsTr("Sign out of TunnelCore VPN?"),
                            qsTr("This ends the account session on this device. Imported VPN configurations remain on the device."),
                            qsTr("Sign out"),
                            qsTr("Cancel"),
                            function() {
                                if (ConnectionController.isConnected || ConnectionController.isConnectionInProgress)
                                    ConnectionController.closeConnection()
                                TunnelCoreController.logout()
                            },
                            function() {}
                        )
                    }
                }
                SmallTextType {
                    Layout.fillWidth: true
                    text: qsTr("Signing out ends the account session. Imported VPN configurations remain on this device.")
                    color: AmneziaStyle.color.mutedGray
                }
                BasicButtonType {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    text: qsTr("Sign out on all devices")
                    enabled: !TunnelCoreController.busy && !root.importingProfile
                             && root.pendingVpnCountry.length === 0
                    defaultColor: AmneziaStyle.color.vibrantRed
                    hoveredColor: AmneziaStyle.color.vibrantRed
                    pressedColor: AmneziaStyle.color.vibrantRed
                    textColor: AmneziaStyle.color.paleGray
                    clickedFunc: function() {
                        showQuestionDrawer(
                            qsTr("Sign out on all devices?"),
                            qsTr("All TunnelCore VPN sessions and registered VPN devices will be revoked. You will need to sign in again on every device."),
                            qsTr("Sign out everywhere"),
                            qsTr("Cancel"),
                            function() {
                                if (ConnectionController.isConnected || ConnectionController.isConnectionInProgress)
                                    ConnectionController.closeConnection()
                                TunnelCoreController.logoutAll()
                            },
                            function() {}
                        )
                    }
                }
                SmallTextType {
                    Layout.fillWidth: true
                    text: qsTr("Use this if a device was lost, replaced, or you need to reset all device slots.")
                    color: AmneziaStyle.color.mutedGray
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: TunnelCoreController.emailAccount
                    spacing: 12

                    Header2TextType {
                        Layout.fillWidth: true
                        text: qsTr("Link Telegram")
                    }
                    SmallTextType {
                        Layout.fillWidth: true
                        visible: !TunnelCoreController.telegramLinked
                        text: qsTr("Request a six-digit code in the TunnelCore bot and enter it here. Your Telegram subscriptions and payments will be transferred to this account.")
                    }
                    TextFieldWithHeaderType {
                        id: telegramCodeField
                        Layout.fillWidth: true
                        visible: !TunnelCoreController.telegramLinked
                        enabled: !TunnelCoreController.busy
                        headerText: qsTr("Telegram code")
                        textField.placeholderText: "000000"
                        textField.maximumLength: 6
                        textField.inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText
                        textField.onAccepted: TunnelCoreController.linkTelegram(telegramCodeField.textField.text)
                    }
                    BasicButtonType {
                        Layout.fillWidth: true
                        visible: !TunnelCoreController.telegramLinked
                        enabled: !TunnelCoreController.busy
                                 && telegramCodeField.textField.text.trim().length === 6
                        text: qsTr("Link Telegram")
                        clickedFunc: function() {
                            TunnelCoreController.linkTelegram(telegramCodeField.textField.text)
                        }
                    }
                    SmallTextType {
                        Layout.fillWidth: true
                        visible: TunnelCoreController.telegramLinked
                        text: qsTr("Telegram is linked to this account.")
                        color: AmneziaStyle.color.goldenApricot
                    }
                }
            }

            SmallTextType {
                Layout.fillWidth: true
                visible: TunnelCoreController.error.length > 0
                text: TunnelCoreController.error
                textFormat: Text.PlainText
                color: AmneziaStyle.color.vibrantRed
            }

            SmallTextType {
                id: privacyPolicyLink
                objectName: "tunnelCorePrivacyPolicyLink"

                Layout.fillWidth: true
                Layout.topMargin: 8
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.RichText
                color: AmneziaStyle.color.mutedGray
                text: "<a href=\"https://vnextdev.com/tunnelcore/privacy\" style=\"color: "
                      + AmneziaStyle.color.goldenApricotString + ";\">"
                      + qsTr("Privacy Policy") + "</a> · <a href=\"https://vnextdev.com/tunnelcore/privacy#account-deletion\" style=\"color: "
                      + AmneziaStyle.color.goldenApricotString + ";\">"
                      + qsTr("Request account deletion") + "</a>"

                onLinkActivated: function(link) {
                    Qt.openUrlExternally(link)
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }
        }
    }
    HomeSplitTunnelingDrawer {
        id: splitTunnelingDrawer
        parent: root
    }

    DrawerType2 {
        id: subscriptionsDrawer
        objectName: "subscriptionsDrawer"
        parent: root
        anchors.fill: parent
        expandedHeight: root.height * 0.8

        expandedStateContent: Item {
            implicitHeight: subscriptionsDrawer.expandedHeight

            ColumnLayout {
                id: subscriptionsDrawerHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 16

                BackButtonType {
                    Layout.fillWidth: true
                    backButtonFunction: function() { subscriptionsDrawer.closeTriggered() }
                }

                Header2Type {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    headerText: qsTr("Subscriptions")
                }
            }

            ListViewType {
                id: subscriptionsList
                anchors.top: subscriptionsDrawerHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 8
                clip: true
                model: TunnelCoreController.subscriptions

                delegate: ColumnLayout {
                    id: subscriptionDelegate
                    required property var modelData
                    width: subscriptionsList.width
                    spacing: 0

                    LabelWithButtonType {
                        Layout.fillWidth: true
                        enabled: false
                        textDisabledColor: AmneziaStyle.color.paleGray
                        descriptionDisabledColor: AmneziaStyle.color.mutedGray
                        text: root.localizedTariffName(subscriptionDelegate.modelData)
                        descriptionText: qsTr("Until %1").arg(Qt.formatDateTime(
                                             new Date(subscriptionDelegate.modelData.expires_at),
                                             "dd.MM.yyyy"))
                    }

                    DividerType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                    }
                }
            }
        }
    }
}
