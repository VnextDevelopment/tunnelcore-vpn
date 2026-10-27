import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

TabButton {
    id: root

    property string hoveredColor: AmneziaStyle.color.richBrown
    property string defaultColor: AmneziaStyle.color.paleGray
    property string selectedColor: AmneziaStyle.color.goldenApricot

    property string image
    property string caption: ""

    property var horizontalNavigationHandler: null
    property var verticalNavigationHandler: null
    property bool isSelected: false

	property bool isFocusable: true

    Keys.onTabPressed: {
        FocusController.nextKeyTabItem()
    }

    Keys.onBacktabPressed: {
        FocusController.previousKeyTabItem()
    }

    Keys.onUpPressed: {
        if (root.verticalNavigationHandler) root.verticalNavigationHandler()
        else FocusController.nextKeyUpItem()
    }
    
    Keys.onDownPressed: {
        if (root.verticalNavigationHandler) root.verticalNavigationHandler()
        else FocusController.nextKeyDownItem()
    }
    
    Keys.onLeftPressed: {
        if (root.horizontalNavigationHandler) root.horizontalNavigationHandler(false)
        else FocusController.nextKeyLeftItem()
    }

    Keys.onRightPressed: {
        if (root.horizontalNavigationHandler) root.horizontalNavigationHandler(true)
        else FocusController.nextKeyRightItem()
    }
    
    property string borderFocusedColor: SettingsController.isOnTv() ? AmneziaStyle.color.tcBlue : AmneziaStyle.color.paleGray
    property int borderFocusedWidth: SettingsController.isOnTv() ? 3 : 1

    property var clickedFunc

    hoverEnabled: true

    implicitHeight: caption.length > 0 ? 56 : 44
    icon.source: ""
    contentItem: ColumnLayout {
        spacing: 2

        IconImageType {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.icon.width > 0 ? root.icon.width : 24
            Layout.preferredHeight: root.icon.height > 0 ? root.icon.height : 24
            source: root.image
            tint: root.isSelected ? root.selectedColor : root.defaultColor
        }
        Text {
            Layout.fillWidth: true
            visible: root.caption.length > 0
            text: root.caption
            font.family: "PT Root UI VF"
            font.pixelSize: 11
            font.weight: root.isSelected ? Font.DemiBold : Font.Normal
            color: root.isSelected ? root.selectedColor : root.defaultColor
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
    }

    background: Rectangle {
        id: background
        anchors.fill: parent
        color: AmneziaStyle.color.transparent
        radius: 10

        border.color: root.activeFocus ? root.borderFocusedColor : AmneziaStyle.color.transparent
        border.width: root.activeFocus ? root.borderFocusedWidth : 0

    }

    MouseArea {
        anchors.fill: background
        cursorShape: Qt.PointingHandCursor
        enabled: false
    }
    
    Keys.onEnterPressed: {
        if (root.clickedFunc && typeof root.clickedFunc === "function") {
            root.clickedFunc()
        }
    }

    Keys.onReturnPressed: {
        if (root.clickedFunc && typeof root.clickedFunc === "function") {
            root.clickedFunc()
        }
    }

    onClicked: {
        if (root.clickedFunc && typeof root.clickedFunc === "function") {
            root.clickedFunc()
        }
    }
}
