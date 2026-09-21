import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import Style 1.0

TabButton {
    id: root

    property string hoveredColor: AmneziaStyle.color.richBrown
    property string defaultColor: AmneziaStyle.color.paleGray
    property string selectedColor: AmneziaStyle.color.goldenApricot

    property string image

    property bool isSelected: false

	property bool isFocusable: true

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
    
    property string borderFocusedColor: AmneziaStyle.color.paleGray
    property int borderFocusedWidth: 1

    property var clickedFunc

    hoverEnabled: true

    // Qt 6.10's Android IconImage colorization renders transparent SVG pixels
    // as an opaque rectangle on some graphics backends.  Keep the regular
    // tinted control icon on desktop and render the SVG directly on Android.
    icon.source: Qt.platform.os === "android" ? "" : image
    icon.color: isSelected ? selectedColor : defaultColor

    contentItem: Item {
        // Keep the tab's implicit geometry non-zero after replacing the
        // style-provided IconImage with a custom Android-safe renderer.
        implicitWidth: 24
        implicitHeight: 24

        Image {
            id: androidImage
            anchors.centerIn: parent
            width: 24
            height: 24
            visible: Qt.platform.os === "android"
            source: root.image
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
            opacity: root.isSelected ? 1.0 : 0.72
        }

        Image {
            id: desktopImageMask
            anchors.centerIn: parent
            width: 24
            height: 24
            visible: false
            source: root.image
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
        }

        ColorOverlay {
            anchors.fill: desktopImageMask
            visible: Qt.platform.os !== "android"
            source: desktopImageMask
            color: root.isSelected ? root.selectedColor : root.defaultColor
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
