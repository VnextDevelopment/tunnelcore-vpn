import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import Style 1.0

Button {
    id: root

    property string image

    property string hoveredColor: AmneziaStyle.color.translucentWhite
    property string defaultColor: AmneziaStyle.color.transparent
    property string pressedColor: AmneziaStyle.color.sheerWhite
    property string disableColor: AmneziaStyle.color.slateGray

    property string imageColor: AmneziaStyle.color.mutedGray
    property string disableImageColor: AmneziaStyle.color.slateGray

    property alias backgroundColor: background.color
    property alias backgroundRadius: background.radius

    property string borderFocusedColor: AmneziaStyle.color.paleGray
    property int borderFocusedWidth: 1

    hoverEnabled: true

    // Avoid the broken IconImage tint path on Qt 6.10/Android. Control-icon
    // URLs resolve to pre-rasterized transparent resources, so a plain Image
    // is reliable there.
    icon.source: Qt.platform.os === "android" ? "" : image
    icon.color: root.enabled ? imageColor : disableImageColor

    contentItem: Item {
        readonly property real imageWidth: root.icon.width > 0 ? root.icon.width : 24
        readonly property real imageHeight: root.icon.height > 0 ? root.icon.height : 24

        // A custom contentItem must expose an implicit size. Without it,
        // Button can collapse the icon area to 0x0 (notably on Android).
        implicitWidth: imageWidth
        implicitHeight: imageHeight

        Image {
            id: androidImage
            anchors.centerIn: parent
            width: parent.imageWidth
            height: parent.imageHeight
            visible: Qt.platform.os === "android"
            source: root.image
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
            opacity: root.enabled ? 1.0 : 0.45
        }

        Image {
            id: desktopImageMask
            anchors.centerIn: parent
            width: parent.imageWidth
            height: parent.imageHeight
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
            color: root.enabled ? root.imageColor : root.disableImageColor
        }
    }

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

    Keys.onEnterPressed: root.clicked()
    Keys.onReturnPressed: root.clicked()

    Behavior on icon.color {
        PropertyAnimation { duration: 200 }
    }

    background: Rectangle {
        id: background

        anchors.fill: parent
        border.color: root.activeFocus ? root.borderFocusedColor : AmneziaStyle.color.transparent
        border.width: root.activeFocus ? root.borderFocusedWidth : 0

        color: {
            if (root.enabled) {
                if (root.pressed) {
                    return pressedColor
                }
                return hovered ? hoveredColor : defaultColor
            }
            return defaultColor
        }
        radius: 12
        Behavior on color {
            PropertyAnimation { duration: 200 }
        }
        Behavior on border.color {
            PropertyAnimation { duration: 200 }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: false
        cursorShape: Qt.PointingHandCursor
    }
}
