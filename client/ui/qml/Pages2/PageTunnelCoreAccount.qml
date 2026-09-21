import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PageEnum 1.0
import Style 1.0

import "../Controls2"
import "../Controls2/TextTypes"

PageType {
    id: root
    property bool emailMode: false
    property bool registrationMode: false
    property string pendingVpnCountry: ""

    function selectVpnCountry(countryCode) {
        if (TunnelCoreController.busy || pendingVpnCountry.length > 0)
            return

        pendingVpnCountry = countryCode
        if (ConnectionController.isConnected || ConnectionController.isConnectionInProgress) {
            ConnectionController.closeConnection()
            return
        }

        pendingVpnCountry = ""
        TunnelCoreController.selectVpnCountry(countryCode)
    }

    function goToConnection() {
        if (TunnelCoreController.busy || pendingVpnCountry.length > 0)
            return

        if (ServersUiController.getServersCount() > 0) {
            PageController.goToPageHome()
        } else if (TunnelCoreController.configs.length > 0) {
            TunnelCoreController.selectConfig(0)
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
        function onConfigReady(data, fileName) {
            if (!root.visible)
                return
            if (ImportController.extractTunnelCoreConfigFromData(data, fileName)) {
                PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
            }
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
        anchors.bottomMargin: PageController.safeAreaBottomMargin + PageController.imeHeight + 16
        contentHeight: content.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: Math.min(scroll.width - 32, 440)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Image {
                source: "qrc:/images/icon.png"
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

                SmallTextType {
                    Layout.fillWidth: true
                    visible: TunnelCoreController.busy || root.pendingVpnCountry.length > 0
                    text: qsTr("Loading data…")
                }
                Repeater {
                    model: TunnelCoreController.subscriptions
                    delegate: SmallTextType {
                        required property var modelData
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: root.localizedTariffName(modelData) + "\n"
                              + qsTr("Until %1").arg(Qt.formatDateTime(new Date(modelData.expires_at), "dd.MM.yyyy"))
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
                        visible: ServersUiController.getServersCount() > 0
                                 || TunnelCoreController.configs.length > 0
                        text: qsTr("Go to connection")
                        enabled: !TunnelCoreController.busy
                                 && root.pendingVpnCountry.length === 0
                        defaultColor: AmneziaStyle.color.goldenApricot
                        hoveredColor: AmneziaStyle.color.goldenApricot
                        clickedFunc: root.goToConnection
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
                    clickedFunc: function() { TunnelCoreController.refresh() }
                }
                BasicButtonType {
                    Layout.fillWidth: true
                    text: qsTr("Sign out")
                    clickedFunc: function() { TunnelCoreController.logout() }
                }
                SmallTextType {
                    Layout.fillWidth: true
                    text: qsTr("Signing out ends the account session. Imported VPN configurations remain on this device.")
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
            BasicButtonType {
                Layout.fillWidth: true
                visible: TunnelCoreController.authenticated
                         && TunnelCoreController.vpnCountries.length === 0
                         && (ServersUiController.getServersCount() > 0
                             || TunnelCoreController.configs.length > 0)
                text: qsTr("Go to connection")
                enabled: !TunnelCoreController.busy
                clickedFunc: root.goToConnection
            }
            BasicButtonType {
                Layout.fillWidth: true
                text: qsTr("Import configuration")
                enabled: !TunnelCoreController.busy
                clickedFunc: function() { PageController.goToPage(PageEnum.PageSetupWizardConfigSource) }
            }
        }
    }
}
