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
    // The tabs reuse the real account controller and the same VPN session.
    // Separate sections avoid one excessively long mixed-purpose page.
    property string viewMode: "home" // home | countries | subscription | profile
    property bool showWelcome: true
    property bool emailMode: true
    property bool registrationMode: false
    property string pendingVpnCountry: ""
    property bool connectAfterImport: false
    property bool importingProfile: false
    property string countryFilter: ""

    // The account page is inside PageStart's IME-adjusted StackView.
    // Bring the focused input into view when the keyboard reduces its height.
    function keepFocusedInputVisible() {
        if (!root.visible || scroll.height <= 0)
            return

        var focusedField = null
        if (TunnelCoreController.authenticated) {
            if (vpnCountrySearch.visible && vpnCountrySearch.textField.activeFocus)
                focusedField = vpnCountrySearch
        } else if (loginField.textField.activeFocus) {
            focusedField = loginField
        } else if (passwordField.visible && passwordField.textField.activeFocus) {
            focusedField = passwordField
        } else if (confirmPasswordField.visible && confirmPasswordField.textField.activeFocus) {
            focusedField = confirmPasswordField
        }

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
            root.viewMode = "home"
            root.showWelcome = false
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

    Rectangle {
        anchors.fill: parent
        color: AmneziaStyle.color.tcBackground
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
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                fillMode: Image.PreserveAspectFit
            }
            Header2TextType {
                Layout.fillWidth: true
                text: "TunnelCore VPN"
                color: AmneziaStyle.color.tcInk
                font.pixelSize: 29
                horizontalAlignment: Text.AlignHCenter
            }
            SmallTextType {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: TunnelCoreController.authenticated ? TunnelCoreController.username : qsTr("Sign in to your account")
                color: AmneziaStyle.color.tcMuted
                horizontalAlignment: Text.AlignHCenter
            }

            // Lightweight native onboarding. All actions lead to the real
            // email / bot-code forms; no hypothetical proxy mode is exposed.
            Rectangle {
                Layout.fillWidth: true
                visible: !TunnelCoreController.authenticated && root.showWelcome
                implicitHeight: welcomeContent.implicitHeight + 48
                radius: 28
                color: AmneziaStyle.color.tcCard
                border.color: AmneziaStyle.color.tcStroke
                border.width: 1

                ColumnLayout {
                    id: welcomeContent
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 24
                    spacing: 18

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("TunnelCore VPN")
                        color: AmneziaStyle.color.tcInk
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Sign in to your account")
                        color: AmneziaStyle.color.tcMuted
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: 20
                        color: AmneziaStyle.color.tcSurfaceBlue
                        border.color: AmneziaStyle.color.tcStroke
                        border.width: 1
                        implicitHeight: welcomeFeatures.implicitHeight + 24

                        ColumnLayout {
                            id: welcomeFeatures
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 12
                            spacing: 12

                            Repeater {
                                model: [
                                    { title: "VPN", icon: "qrc:/images/controls/globe-2.svg" },
                                    { title: qsTr("VPN location"), icon: "qrc:/images/controls/server.svg" },
                                    { title: qsTr("Split tunneling"), icon: "qrc:/images/controls/split-tunneling.svg" }
                                ]
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 12
                                    IconImageType {
                                        source: modelData.icon
                                        tint: AmneziaStyle.color.tcBlue
                                        implicitWidth: 24
                                        implicitHeight: 24
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        color: AmneziaStyle.color.tcInk
                                        font.pixelSize: 16
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                    BasicButtonType {
                        Layout.fillWidth: true
                        text: qsTr("Sign in")
                        defaultColor: AmneziaStyle.color.tcBlue
                        hoveredColor: "#328BF9"
                        textColor: "#FFFFFF"
                        clickedFunc: function() {
                            root.emailMode = true
                            root.registrationMode = false
                            root.showWelcome = false
                        }
                    }
                    BasicButtonType {
                        Layout.fillWidth: true
                        text: qsTr("Create account")
                        defaultColor: AmneziaStyle.color.tcCard
                        hoveredColor: AmneziaStyle.color.tcSurfaceBlue
                        textColor: AmneziaStyle.color.tcBlue
                        borderWidth: 1
                        borderColor: AmneziaStyle.color.tcBlue
                        clickedFunc: function() {
                            root.emailMode = true
                            root.registrationMode = true
                            root.showWelcome = false
                        }
                    }
                    BasicButtonType {
                        Layout.fillWidth: true
                        text: qsTr("Bot code")
                        defaultColor: AmneziaStyle.color.tcSurfaceBlue
                        hoveredColor: AmneziaStyle.color.tcCard
                        textColor: AmneziaStyle.color.tcBlue
                        clickedFunc: function() {
                            root.emailMode = false
                            root.registrationMode = false
                            root.showWelcome = false
                        }
                    }
                }
            }

            Rectangle {
                id: authCard
                Layout.fillWidth: true
                implicitHeight: authContent.implicitHeight + 48
                visible: !TunnelCoreController.authenticated && !root.showWelcome
                radius: 28
                color: AmneziaStyle.color.tcCard
                border.width: 1
                border.color: AmneziaStyle.color.tcStroke

                ColumnLayout {
                    id: authContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 16

                    Header2TextType {
                        Layout.fillWidth: true
                        text: root.registrationMode ? qsTr("Create account") : qsTr("Sign in")
                        color: AmneziaStyle.color.tcInk
                        horizontalAlignment: Text.AlignHCenter
                    }

                RowLayout {
                    Layout.fillWidth: true
                    BasicButtonType {
                        Layout.fillWidth: true
                        text: qsTr("Bot code")
                        enabled: !TunnelCoreController.busy
                        defaultColor: root.emailMode ? AmneziaStyle.color.tcCard : AmneziaStyle.color.tcSurfaceBlue
                        hoveredColor: AmneziaStyle.color.tcSurfaceBlue
                        textColor: root.emailMode ? AmneziaStyle.color.tcMuted : AmneziaStyle.color.tcBlue
                        borderColor: AmneziaStyle.color.tcStroke
                        borderWidth: 1
                        clickedFunc: function() { root.selectMode(false) }
                    }
                    BasicButtonType {
                        Layout.fillWidth: true
                        text: "Email"
                        enabled: !TunnelCoreController.busy
                        defaultColor: root.emailMode ? AmneziaStyle.color.tcSurfaceBlue : AmneziaStyle.color.tcCard
                        hoveredColor: AmneziaStyle.color.tcSurfaceBlue
                        textColor: root.emailMode ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.tcMuted
                        borderColor: AmneziaStyle.color.tcStroke
                        borderWidth: 1
                        clickedFunc: function() { root.selectMode(true) }
                    }
                }
                SmallTextType {
                    color: AmneziaStyle.color.tcMuted
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
                    textColor: AmneziaStyle.color.tcBlue
                    clickedFunc: function() {
                        root.registrationMode = !root.registrationMode
                        passwordField.textField.text = ""
                        confirmPasswordField.textField.text = ""
                        TunnelCoreController.clearError()
                    }
                }
                TextFieldWithHeaderType {
                    id: loginField
                    backgroundColor: AmneziaStyle.color.tcCard
                    backgroundDisabledColor: AmneziaStyle.color.tcCard
                    headerTextColor: AmneziaStyle.color.tcMuted
                    textFieldTextColor: AmneziaStyle.color.tcInk
                    borderColor: AmneziaStyle.color.tcStroke
                    borderFocusedColor: AmneziaStyle.color.tcBlue
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
                    backgroundColor: AmneziaStyle.color.tcCard
                    backgroundDisabledColor: AmneziaStyle.color.tcCard
                    headerTextColor: AmneziaStyle.color.tcMuted
                    textFieldTextColor: AmneziaStyle.color.tcInk
                    borderColor: AmneziaStyle.color.tcStroke
                    borderFocusedColor: AmneziaStyle.color.tcBlue
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
                    backgroundColor: AmneziaStyle.color.tcCard
                    backgroundDisabledColor: AmneziaStyle.color.tcCard
                    headerTextColor: AmneziaStyle.color.tcMuted
                    textFieldTextColor: AmneziaStyle.color.tcInk
                    borderColor: AmneziaStyle.color.tcStroke
                    borderFocusedColor: AmneziaStyle.color.tcBlue
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
                    defaultColor: AmneziaStyle.color.tcBlue
                    hoveredColor: "#328BF9"
                    pressedColor: "#0C62C9"
                    disabledColor: "#A8C5E7"
                    textColor: "#FFFFFF"
                    clickedFunc: root.submit
                }
                BasicButtonType {
                    objectName: "accountDeletionWebsiteGuest"
                    Layout.fillWidth: true
                    text: qsTr("Account deletion information")
                    enabled: !TunnelCoreController.busy
                    defaultColor: AmneziaStyle.color.transparent
                    textColor: AmneziaStyle.color.tcBlue
                    clickedFunc: function() {
                        Qt.openUrlExternally("https://vnextdev.com/tunnelcore/delete-account")
                    }
                }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: TunnelCoreController.authenticated && root.viewMode === "home"
                spacing: 16

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: heroContent.implicitHeight + 40
                    color: AmneziaStyle.color.tcCard
                    radius: 28
                    border.color: AmneziaStyle.color.tcStroke
                    border.width: 1

                    ColumnLayout {
                        id: heroContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 20
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: "TunnelCore VPN"
                            color: AmneziaStyle.color.tcInk
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                        }
                        ConnectButton {
                            objectName: "accountConnectButton"
                            tunnelCoreMode: true
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            Layout.bottomMargin: 4
                            enabled: !TunnelCoreController.busy && !root.importingProfile
                                     && root.pendingVpnCountry.length === 0
                            clickedFunc: root.connectSelectedLocation
                        }
                        Text {
                            Layout.fillWidth: true
                            text: ConnectionController.connectionStateText
                            color: AmneziaStyle.color.tcInk
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            text: TunnelCoreController.vpnCountryMode === "auto"
                                  ? (TunnelCoreController.effectiveVpnCountry.length > 0
                                     ? TunnelCoreController.vpnCountryDisplayName(TunnelCoreController.effectiveVpnCountry)
                                     : qsTr("Automatic"))
                                  : TunnelCoreController.vpnCountryDisplayName(TunnelCoreController.selectedVpnCountry)
                            color: AmneziaStyle.color.tcMuted
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }
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
                    defaultColor: AmneziaStyle.color.tcCard
                    hoveredColor: AmneziaStyle.color.tcSurfaceBlue
                    borderWidth: 1
                    borderColor: AmneziaStyle.color.tcStroke
                    textColor: AmneziaStyle.color.tcInk
                    clickedFunc: function() { splitTunnelingDrawer.openTriggered() }
                }

                SmallTextType {
                    color: AmneziaStyle.color.tcMuted
                    Layout.fillWidth: true
                    visible: TunnelCoreController.busy || root.pendingVpnCountry.length > 0
                    text: qsTr("Loading data…")
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: subscriptionLabel.implicitHeight + 12
                    visible: TunnelCoreController.subscriptions.length > 0
                    radius: 20
                    color: AmneziaStyle.color.tcSurfaceBlue
                    border.width: 1
                    border.color: AmneziaStyle.color.tcStroke

                LabelWithButtonType {
                        id: subscriptionLabel
                        anchors.fill: parent
                        anchors.margins: 6
                    textColor: AmneziaStyle.color.tcInk
                    descriptionColor: AmneziaStyle.color.tcMuted
                    rightImageColor: AmneziaStyle.color.tcBlue
                    text: root.localizedTariffName(TunnelCoreController.primarySubscription)
                    descriptionText: qsTr("Until %1").arg(Qt.formatDateTime(
                                         new Date(TunnelCoreController.primarySubscription.expires_at),
                                         "dd.MM.yyyy"))
                    rightImageSource: "qrc:/images/controls/chevron-right.svg"
                    clickedFunction: function() { subscriptionsDrawer.openTriggered() }
                }
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
                    color: AmneziaStyle.color.tcInk
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
            }

            // Live VPN country list. Only locations received from the API are displayed.
            ColumnLayout {
                Layout.fillWidth: true
                visible: TunnelCoreController.authenticated && root.viewMode === "countries"
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: TunnelCoreController.vpnCountries.length > 0
                    spacing: 8

                    Header2TextType {
                    color: AmneziaStyle.color.tcInk
                        Layout.fillWidth: true
                        text: qsTr("VPN location")
                    }
                    SmallTextType {
                    color: AmneziaStyle.color.tcMuted
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
                    color: AmneziaStyle.color.tcMuted
                        Layout.fillWidth: true
                        text: qsTr("Automatic selects an available VPN server. Choosing a country moves your VPN access to that country.")
                    }
                    TextFieldWithHeaderType {
                        id: vpnCountrySearch
                        Layout.fillWidth: true
                        visible: TunnelCoreController.vpnCountries.length > 4
                        enabled: !TunnelCoreController.busy
                        headerText: qsTranslate("PageShare", "Search")
                        textField.placeholderText: qsTr("VPN location")
                        textField.inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                        backgroundColor: AmneziaStyle.color.tcCard
                        textFieldTextColor: AmneziaStyle.color.tcInk
                        headerTextColor: AmneziaStyle.color.tcMuted
                        borderColor: AmneziaStyle.color.tcStroke
                        borderFocusedColor: AmneziaStyle.color.tcBlue
                        textField.onTextChanged: root.countryFilter = vpnCountrySearch.textField.text.trim().toLowerCase()
                        textField.onActiveFocusChanged: {
                            if (vpnCountrySearch.textField.activeFocus)
                                Qt.callLater(root.keepFocusedInputVisible)
                        }
                    }
                    BasicButtonType {
                        Layout.fillWidth: true
                        readonly property bool isSelected: TunnelCoreController.vpnCountryMode === "auto"
                        text: qsTr("Automatic")
                        enabled: !TunnelCoreController.busy && root.pendingVpnCountry.length === 0
                        defaultColor: isSelected ? AmneziaStyle.color.tcSurfaceBlue
                                                 : AmneziaStyle.color.tcCard
                        hoveredColor: AmneziaStyle.color.tcSurfaceBlue
                        borderColor: isSelected ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.tcStroke
                        borderWidth: 1
                        textColor: isSelected ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.tcInk
                        clickedFunc: function() { root.selectVpnCountry("AUTO") }
                    }
                    Repeater {
                        model: TunnelCoreController.vpnCountries
                        delegate: BasicButtonType {
                            required property var modelData
                            Layout.fillWidth: true
                            readonly property string countryCode: modelData.code ? String(modelData.code) : ""
                            visible: root.countryFilter.length === 0
                                     || (TunnelCoreController.vpnCountryDisplayName(countryCode) + " " + cities)
                                           .toLowerCase().includes(root.countryFilter)
                            readonly property string cities: modelData.cities && modelData.cities.length > 0
                                                             ? modelData.cities.join(", ") : ""
                            readonly property bool isSelected: TunnelCoreController.vpnCountryMode === "country"
                                                               && TunnelCoreController.selectedVpnCountry === countryCode
                            text: TunnelCoreController.vpnCountryDisplayName(countryCode)
                                  + (cities.length > 0 ? " · " + cities : "")
                            buttonTextLabel.elide: Text.ElideRight
                            enabled: !TunnelCoreController.busy && root.pendingVpnCountry.length === 0
                            defaultColor: isSelected ? AmneziaStyle.color.tcSurfaceBlue
                                                 : AmneziaStyle.color.tcCard
                            hoveredColor: AmneziaStyle.color.tcSurfaceBlue
                            borderColor: isSelected ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.tcStroke
                            borderWidth: 1
                            textColor: isSelected ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.tcInk
                            clickedFunc: function() {
                                root.selectVpnCountry(countryCode)
                            }
                        }
                    }
                }
                SmallTextType {
                    color: AmneziaStyle.color.tcMuted
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
            }

            // Account details and destructive actions are intentionally kept away
            // from the main connect control.
            ColumnLayout {
                Layout.fillWidth: true
                visible: TunnelCoreController.authenticated && root.viewMode === "profile"
                spacing: 16

                Header2TextType {
                    color: AmneziaStyle.color.tcInk
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    text: qsTr("Account")
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: usernameValue.implicitHeight + 32
                    radius: 20
                    color: AmneziaStyle.color.tcSurfaceBlue
                    border.color: AmneziaStyle.color.tcStroke
                    border.width: 1
                    Text {
                        id: usernameValue
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        color: AmneziaStyle.color.tcInk
                        text: TunnelCoreController.username
                        elide: Text.ElideMiddle
                    }
                }
                BasicButtonType {
                    Layout.fillWidth: true
                    text: qsTranslate("PageSettings", "Settings")
                    defaultColor: AmneziaStyle.color.tcCard
                    hoveredColor: AmneziaStyle.color.tcSurfaceBlue
                    textColor: AmneziaStyle.color.tcInk
                    borderColor: AmneziaStyle.color.tcStroke
                    borderWidth: 1
                    clickedFunc: function() { PageController.goToPage(PageEnum.PageSettings) }
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
                    color: AmneziaStyle.color.tcInk
                        Layout.fillWidth: true
                        text: qsTr("Link Telegram")
                    }
                    SmallTextType {
                    color: AmneziaStyle.color.tcMuted
                        Layout.fillWidth: true
                        visible: !TunnelCoreController.telegramLinked
                        text: qsTr("Request a six-digit code in the TunnelCore bot and enter it here. Your Telegram subscriptions and payments will be transferred to this account.")
                    }
                    TextFieldWithHeaderType {
                        id: telegramCodeField
                    backgroundColor: AmneziaStyle.color.tcCard
                    backgroundDisabledColor: AmneziaStyle.color.tcCard
                    headerTextColor: AmneziaStyle.color.tcMuted
                    textFieldTextColor: AmneziaStyle.color.tcInk
                    borderColor: AmneziaStyle.color.tcStroke
                    borderFocusedColor: AmneziaStyle.color.tcBlue
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
                        color: AmneziaStyle.color.tcBlue
                    }
                }
                DividerType {
                    Layout.fillWidth: true
                    Layout.topMargin: 20
                }
                Header2TextType {
                    color: AmneziaStyle.color.tcInk
                    Layout.fillWidth: true
                    text: qsTr("Delete account")
                }
                SmallTextType {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: qsTr("Request permanent deletion of your TunnelCore VPN account and associated data. Subscriptions billed by other providers must be cancelled separately.")
                    color: AmneziaStyle.color.mutedGray
                }
                SmallTextType {
                    Layout.fillWidth: true
                    visible: TunnelCoreController.accountDeletionRequested
                    textFormat: Text.PlainText
                    text: qsTr("Your account deletion request has been received. Support will process it and confirm the result.")
                    color: AmneziaStyle.color.tcBlue
                }
                BasicButtonType {
                    objectName: "accountDeletionRequestButton"
                    Layout.fillWidth: true
                    visible: !TunnelCoreController.accountDeletionRequested
                    enabled: !TunnelCoreController.busy && !root.importingProfile
                             && root.pendingVpnCountry.length === 0
                    text: qsTr("Request account deletion")
                    defaultColor: AmneziaStyle.color.transparent
                    hoveredColor: AmneziaStyle.color.translucentWhite
                    pressedColor: AmneziaStyle.color.translucentWhite
                    borderColor: AmneziaStyle.color.vibrantRed
                    borderWidth: 1
                    textColor: AmneziaStyle.color.vibrantRed
                    clickedFunc: function() {
                        showQuestionDrawer(
                            qsTr("Request permanent account deletion?"),
                            qsTr("We will permanently delete your account and associated data after processing your request, except information we must retain by law. Your VPN access will end. This action cannot be undone."),
                            qsTr("Send deletion request"),
                            qsTr("Cancel"),
                            function() { TunnelCoreController.requestAccountDeletion() },
                            function() {}
                        )
                    }
                }
                BasicButtonType {
                    objectName: "accountDeletionWebsiteButton"
                    Layout.fillWidth: true
                    text: qsTr("Account deletion information")
                    defaultColor: AmneziaStyle.color.transparent
                    textColor: AmneziaStyle.color.tcBlue
                    clickedFunc: function() {
                        Qt.openUrlExternally("https://vnextdev.com/tunnelcore/delete-account")
                    }
                }
            }

            // Subscriptions are read-only data from the real TunnelCore API.
            // Purchasing remains platform-specific (Apple IAP / external link).
            ColumnLayout {
                Layout.fillWidth: true
                visible: TunnelCoreController.authenticated && root.viewMode === "subscription"
                spacing: 16

                Header2TextType {
                    Layout.fillWidth: true
                    text: qsTr("Subscriptions")
                    color: AmneziaStyle.color.tcInk
                }
                Rectangle {
                    Layout.fillWidth: true
                    radius: 24
                    color: AmneziaStyle.color.tcCard
                    border.color: AmneziaStyle.color.tcStroke
                    border.width: 1
                    implicitHeight: subscriptionPanel.implicitHeight + 40

                    ColumnLayout {
                        id: subscriptionPanel
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 20
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            color: AmneziaStyle.color.tcInk
                            font.pixelSize: 19
                            font.weight: Font.DemiBold
                            text: TunnelCoreController.subscriptions.length > 0
                                  ? root.localizedTariffName(TunnelCoreController.primarySubscription)
                                  : qsTr("VPN subscription inactive")
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            color: AmneziaStyle.color.tcMuted
                            font.pixelSize: 14
                            text: TunnelCoreController.subscriptionStatusText
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: TunnelCoreController.subscriptions.length > 0
                            color: AmneziaStyle.color.tcMuted
                            font.pixelSize: 14
                            text: qsTr("Until %1").arg(Qt.formatDateTime(
                                      new Date(TunnelCoreController.primarySubscription.expires_at), "dd.MM.yyyy"))
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: TunnelCoreController.subscriptions.length > 0
                            color: AmneziaStyle.color.tcBlue
                            font.pixelSize: 14
                            text: qsTr("Days remaining: %1").arg(TunnelCoreController.subscriptionDaysRemaining)
                        }
                        BasicButtonType {
                            Layout.fillWidth: true
                            text: qsTr("Subscriptions")
                            defaultColor: AmneziaStyle.color.tcSurfaceBlue
                            hoveredColor: "#DCEEFF"
                            textColor: AmneziaStyle.color.tcBlue
                            clickedFunc: function() { subscriptionsDrawer.openTriggered() }
                        }
                        BasicButtonType {
                            Layout.fillWidth: true
                            visible: TunnelCoreController.usesAppleBilling
                                     || TunnelCoreController.externalRenewalLinkAllowed
                            enabled: !TunnelCoreController.busy
                            text: TunnelCoreController.usesAppleBilling
                                  ? qsTr("Renew in App Store")
                                  : (TunnelCoreController.emailAccount && !TunnelCoreController.telegramLinked
                                     ? qsTr("Link Telegram to renew")
                                     : qsTr("Renew in Telegram"))
                            defaultColor: AmneziaStyle.color.tcBlue
                            hoveredColor: "#328BF9"
                            textColor: "#FFFFFF"
                            clickedFunc: function() { TunnelCoreController.renewSubscription() }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: !TunnelCoreController.usesAppleBilling
                                     && !TunnelCoreController.externalRenewalLinkAllowed
                            color: AmneziaStyle.color.tcMuted
                            font.pixelSize: 14
                            text: qsTr("Renew your TunnelCore subscription outside the app. Telegram users can use @tunnelcoree_bot. After renewal, return here and tap Refresh.")
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                        }
                        BasicButtonType {
                            Layout.fillWidth: true
                            text: qsTr("Refresh")
                            enabled: !TunnelCoreController.busy
                                     && !ConnectionController.isConnected
                                     && !ConnectionController.isConnectionInProgress
                            defaultColor: AmneziaStyle.color.tcCard
                            textColor: AmneziaStyle.color.tcInk
                            borderColor: AmneziaStyle.color.tcStroke
                            borderWidth: 1
                            clickedFunc: function() { TunnelCoreController.refresh() }
                        }
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
                      + AmneziaStyle.color.tcBlueString + ";\">"
                      + qsTr("Privacy Policy") + "</a> · <a href=\"https://vnextdev.com/tunnelcore/privacy#account-deletion\" style=\"color: "
                      + AmneziaStyle.color.tcBlueString + ";\">"
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
        defaultColor: AmneziaStyle.color.tcBackground
        borderColor: AmneziaStyle.color.tcStroke
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
                    headerColor: AmneziaStyle.color.tcInk
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
                    textColor: AmneziaStyle.color.tcInk
                    descriptionColor: AmneziaStyle.color.tcMuted
                    rightImageColor: AmneziaStyle.color.tcBlue
                        Layout.fillWidth: true
                        enabled: false
                        textDisabledColor: AmneziaStyle.color.tcInk
                        descriptionDisabledColor: AmneziaStyle.color.tcMuted
                        text: root.localizedTariffName(subscriptionDelegate.modelData)
                        descriptionText: qsTr("Until %1").arg(Qt.formatDateTime(
                                             new Date(subscriptionDelegate.modelData.expires_at),
                                             "dd.MM.yyyy"))
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        height: 1
                        color: AmneziaStyle.color.tcStroke
                    }
                }
            }
        }
    }
}
