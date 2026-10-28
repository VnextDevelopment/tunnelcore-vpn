import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

import "TextTypes"
import "../Config"

Item {
    id: root

    property string text
    property string textColor: AmneziaStyle.color.paleGray
    property string textDisabledColor: AmneziaStyle.color.mutedGray
    property int textMaximumLineCount: 2
    property int textElide: Qt.ElideRight

    property string descriptionText
    property string descriptionTextColor: AmneziaStyle.color.mutedGray
    property string descriptionTextDisabledColor: AmneziaStyle.color.charcoalGray

    property string headerText
    property string headerBackButtonImage

    property var rootButtonClickedFunction
    property string rootButtonImage: "qrc:/images/controls/chevron-down.svg"
    property string rootButtonImageColor: AmneziaStyle.color.paleGray
    property string rootButtonBackgroundColor: AmneziaStyle.color.onyxBlack
    property string rootButtonBackgroundHoveredColor: AmneziaStyle.color.onyxBlack
    property string rootButtonBackgroundPressedColor: AmneziaStyle.color.onyxBlack

    property string borderFocusedColor: SettingsController.isOnTv() ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.paleGray
    property int borderFocusedWidth: SettingsController.isOnTv() ? 3 : 1

    property string rootButtonHoveredBorderColor: AmneziaStyle.color.charcoalGray
    property string rootButtonDefaultBorderColor: AmneziaStyle.color.slateGray
    property string rootButtonPressedBorderColor: AmneziaStyle.color.paleGray

    property int rootButtonTextLeftMargins: 16
    property int rootButtonTextTopMargin: 16
    property int rootButtonTextBottomMargin: 16

    property real drawerHeight: 0.9
    property bool fitContent: false
    property Item drawerParent
    property Component listView

    // Optional theme for dropdown sheets. Defaults preserve the existing dark UI.
    property color drawerBackgroundColor: AmneziaStyle.color.onyxBlack
    property color drawerBorderColor: AmneziaStyle.color.slateGray
    property color drawerHeaderColor: AmneziaStyle.color.paleGray
    property color drawerBackButtonColor: AmneziaStyle.color.paleGray

    signal openTriggered
    signal closeTriggered
    // Fired after the drawer content Loader has had a chance to instantiate.
    // Consumers must not reach into listView's separate Component scope by id.
    signal popupOpened
    signal popupClosed

    readonly property bool popupIsOpen: menu.isOpened
    property var popupBackItem: null

    readonly property bool isFocusable: true

    Keys.onTabPressed: {
        FocusController.nextKeyTabItem()
    }

    Keys.onBacktabPressed: {
        FocusController.previousKeyTabItem()
    }

    Keys.onUpPressed: {
        FocusController.nextKeyUpItem()
    }
    
    Keys.onDownPressed: {
        FocusController.nextKeyDownItem()
    }
    
    Keys.onLeftPressed: {
        FocusController.nextKeyLeftItem()
    }

    Keys.onRightPressed: {
        FocusController.nextKeyRightItem()
    }

    Connections {
        target: Qt.application

        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive) {
                if (!menu.isClosed) {
                    menu.closeTriggered()
                }
            }
        }
    }

    implicitWidth: rootButtonContent.implicitWidth
    implicitHeight: rootButtonContent.implicitHeight

    onOpenTriggered: {
        menu.openTriggered()
    }

    onCloseTriggered: {
        menu.closeTriggered()
    }

    Keys.onEnterPressed: {
        if (menu.isClosed) {
            menu.openTriggered()
        }
    }

    Keys.onReturnPressed: {
        if (menu.isClosed) {
            menu.openTriggered()
        }
    }

    Rectangle {
        id: focusBorder

        color: AmneziaStyle.color.transparent
        border.color: root.activeFocus ? root.borderFocusedColor : AmneziaStyle.color.transparent
        border.width: root.activeFocus ? root.borderFocusedWidth : 0
        anchors.fill: rootButtonContent
        radius: 16


        Rectangle {
            id: rootButtonBackground

            anchors.fill: focusBorder
            anchors.margins: root.activeFocus ? 2 : 0
            radius: root.activeFocus ? 14 : 16

            color: {
                if (root.enabled) {
                    if (root.pressed) {
                        return root.rootButtonBackgroundPressedColor
                    }
                    return root.hovered ? root.rootButtonBackgroundHoveredColor : root.rootButtonBackgroundColor
                } else {
                    return AmneziaStyle.color.transparent
                }
            }

            border.color: rootButtonDefaultBorderColor
            border.width: 1

            Behavior on border.color {
                PropertyAnimation { duration: 200 }
            }

            Behavior on color {
                PropertyAnimation { duration: 200 }
            }
        }
    }

    RowLayout {
        id: rootButtonContent
        anchors.fill: parent

        spacing: 0

        ColumnLayout {
            Layout.leftMargin: rootButtonTextLeftMargins
            Layout.topMargin: rootButtonTextTopMargin
            Layout.bottomMargin: rootButtonTextBottomMargin

            LabelTextType {
                Layout.fillWidth: true

                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter

                visible: root.descriptionText !== ""

                color: root.enabled ? root.descriptionTextColor : root.descriptionTextDisabledColor
                text: root.descriptionText
            }

            ButtonTextType {
                id: buttonText
                Layout.fillWidth: true

                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter

                color: root.enabled ? root.textColor : root.textDisabledColor
                text: root.text
                maximumLineCount: root.textMaximumLineCount
                elide: root.textElide
            }
        }

        ImageButtonType {
            Layout.rightMargin: 16

            implicitWidth: 40
            implicitHeight: 40

            hoverEnabled: false
            image: rootButtonImage
            imageColor: rootButtonImageColor
        }
    }

    MouseArea {
        anchors.fill: rootButtonContent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: root.enabled ? true : false

        onClicked: {
            if (rootButtonClickedFunction && typeof rootButtonClickedFunction === "function") {
                rootButtonClickedFunction()
            } else {
                menu.openTriggered()
            }
        }
    }

    DrawerType2 {
        id: menu

        onOpened: Qt.callLater(function() {
            if (menu.isOpened) root.popupOpened()
        })
        onClosed: Qt.callLater(function() {
            if (menu.isClosed) root.popupClosed()
        })
        defaultColor: root.drawerBackgroundColor
        borderColor: root.drawerBorderColor

        parent: drawerParent
        // Reparented sheets must stay above later page siblings (lists and
        // bottom input bars), otherwise those items intercept search taps.
        z: isClosed ? 0 : 100 + depthIndex

        anchors.fill: parent
        property real measuredContentHeight: 0
        expandedHeight: (root.fitContent && measuredContentHeight > 0)
            ? Math.min(measuredContentHeight, drawerParent.height * root.drawerHeight)
            : drawerParent.height * root.drawerHeight

        expandedStateContent: Item {
            id: container
            implicitHeight: menu.expandedHeight

            property real fitHeight: backButton.implicitHeight + titleLabel.implicitHeight
                                     + (listViewLoader.item ? listViewLoader.item.contentHeight : 0) + 48
            onFitHeightChanged: menu.measuredContentHeight = fitHeight
            Component.onCompleted: menu.measuredContentHeight = fitHeight

            ColumnLayout {
                id: header

                anchors.fill: parent
                anchors.topMargin: 16

                BackButtonType {
                    id: backButton
                    Component.onCompleted: root.popupBackItem = backButton.focusButton
                    Component.onDestruction: {
                        if (root.popupBackItem === backButton.focusButton)
                            root.popupBackItem = null
                    }
                    backButtonImage: root.headerBackButtonImage
                    imageColor: root.drawerBackButtonColor
                    backButtonFunction: function() { menu.closeTriggered() }
                }

                Header2Type {
                    id: titleLabel
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 16
                    Layout.fillWidth: true

                    headerText: root.headerText
                    headerColor: root.drawerHeaderColor
                }

                Loader {
                    id: listViewLoader
                    sourceComponent: root.listView

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                }
            }
        }
    }
}
