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

    function selectMode(email) {
        if (TunnelCoreController.busy || emailMode === email)
            return
        emailMode = email
        loginField.textField.text = ""
        passwordField.textField.text = ""
        TunnelCoreController.clearError()
    }

    function submit() {
        if (!TunnelCoreController.busy) {
            if (emailMode)
                TunnelCoreController.loginEmail(loginField.textField.text, passwordField.textField.text)
            else
                TunnelCoreController.loginCode(loginField.textField.text)
        }
    }

    Connections {
        target: TunnelCoreController
        function onSignedIn() {
            loginField.textField.text = ""
            passwordField.textField.text = ""
            Qt.inputMethod.hide()
        }
        function onConfigReady(data, fileName) {
            if (!root.visible)
                return
            if (ImportController.extractConfigFromData(data, fileName)) {
                PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
            }
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
                text: TunnelCoreController.authenticated ? TunnelCoreController.username : qsTr("Войдите в свой аккаунт")
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
                        text: qsTr("Из бота")
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
                          ? qsTr("Введите email и пароль вашего аккаунта TunnelCore.")
                          : qsTr("Введите шестизначный код, полученный в боте TunnelCore.")
                }
                TextFieldWithHeaderType {
                    id: loginField
                    Layout.fillWidth: true
                    enabled: !TunnelCoreController.busy
                    headerText: root.emailMode ? qsTr("Email") : qsTr("Код из бота")
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
                    headerText: qsTr("Пароль")
                    textField.echoMode: TextInput.Password
                    textField.maximumLength: 1024
                    textField.onAccepted: root.submit()
                }
                BasicButtonType {
                    Layout.fillWidth: true
                    text: TunnelCoreController.busy ? qsTr("Входим…") : qsTr("Войти")
                    enabled: !TunnelCoreController.busy
                             && (root.emailMode
                                 ? loginField.textField.text.trim().length > 0
                                   && passwordField.textField.text.length > 0
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
                    visible: TunnelCoreController.busy
                    text: qsTr("Загружаем данные…")
                }
                Repeater {
                    model: TunnelCoreController.subscriptions
                    delegate: SmallTextType {
                        required property var modelData
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: modelData.tariff + "\n" + qsTr("До %1").arg(Qt.formatDateTime(new Date(modelData.expires_at), "dd.MM.yyyy"))
                    }
                }
                SmallTextType {
                    Layout.fillWidth: true
                    visible: !TunnelCoreController.busy && !TunnelCoreController.error
                             && TunnelCoreController.configs.length === 0
                    text: qsTr("Нет доступных VPN-конфигураций. Проверьте подписку в боте и обновите список.")
                }
                Repeater {
                    model: TunnelCoreController.configs
                    delegate: BasicButtonType {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        text: modelData.name
                        buttonTextLabel.elide: Text.ElideRight
                        buttonTextLabel.width: Math.min(implicitWidth, root.width - 96)
                        enabled: !TunnelCoreController.busy
                        clickedFunc: function() { TunnelCoreController.selectConfig(index) }
                    }
                }
                BasicButtonType {
                    Layout.fillWidth: true
                    text: qsTr("Обновить")
                    enabled: !TunnelCoreController.busy
                    clickedFunc: function() { TunnelCoreController.refresh() }
                }
                BasicButtonType {
                    Layout.fillWidth: true
                    text: qsTr("Выйти из аккаунта")
                    clickedFunc: function() { TunnelCoreController.logout() }
                }
                SmallTextType {
                    Layout.fillWidth: true
                    text: qsTr("Выход завершает сессию аккаунта. Импортированные VPN-конфигурации остаются на устройстве.")
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
                visible: ServersUiController.getServersCount() > 0
                text: qsTr("К подключению")
                clickedFunc: function() { PageController.goToPageHome() }
            }
            BasicButtonType {
                Layout.fillWidth: true
                text: qsTr("Импорт конфигурации")
                enabled: !TunnelCoreController.busy
                clickedFunc: function() { PageController.goToPage(PageEnum.PageSetupWizardConfigSource) }
            }
        }
    }
}
