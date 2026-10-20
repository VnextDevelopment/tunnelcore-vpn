import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

import ConnectionState 1.0
import PageEnum 1.0
import Style 1.0

Button {
    id: root

    property string defaultButtonColor: AmneziaStyle.color.paleGray
    property string progressButtonColor: AmneziaStyle.color.paleGray
    property string connectedButtonColor: AmneziaStyle.color.goldenApricot
    property bool buttonActiveFocus: activeFocus && (Qt.platform.os !== "android" || SettingsController.isOnTv())

    // Enable the new dashboard treatment without altering legacy callers.
    property bool tunnelCoreMode: false

    property bool isFocusable: true
    property var clickedFunc: function() { ConnectionController.connectButtonClicked() }
    
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
        
    implicitWidth: 190
    implicitHeight: 190

    text: ConnectionController.connectionStateText

    Connections {
        target: ConnectionController

        function onPreparingConfig() {
            PageController.showNotificationMessage(qsTr("Unable to disconnect during configuration preparation"))
        }
    }

//    enabled: !ConnectionController.isConnectionInProgress

    background: Item {
        implicitWidth: parent.width
        implicitHeight: parent.height
        transformOrigin: Item.Center

        Rectangle {
            id: tunnelCoreCircle
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - 12
            height: width
            radius: width / 2
            visible: root.tunnelCoreMode
            border.color: "#D0E9FF"
            border.width: 7
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: ConnectionController.isConnected ? "#08BC9E" : "#1CDBE0"
                }
                GradientStop {
                    position: 1
                    color: ConnectionController.isConnected ? "#1478F9" : "#1478F9"
                }
            }

            // Uses a platform glyph rather than a raster screenshot; the
            // control remains accessible, reactive and DPI independent.
            Text {
                anchors.centerIn: parent
                text: "\u23FB"
                color: "white"
                font.pixelSize: 76
                font.weight: Font.Light
                font.family: "Arial"
            }

            SequentialAnimation on opacity {
                running: root.tunnelCoreMode && ConnectionController.isConnectionInProgress
                loops: Animation.Infinite
                NumberAnimation { to: 0.62; duration: 550 }
                NumberAnimation { to: 1.0; duration: 550 }
            }
        }

        Shape {
            id: backgroundCircle
            visible: !root.tunnelCoreMode
            width: parent.implicitWidth
            height: parent.implicitHeight
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            layer.enabled: true
            layer.samples: 4
            layer.smooth: true
            layer.effect: DropShadow {
                anchors.fill: backgroundCircle
                horizontalOffset: 0
                verticalOffset: 0
                radius: 10
                samples: 25
                color: root.buttonActiveFocus ? AmneziaStyle.color.paleGray : AmneziaStyle.color.goldenApricot
                source: backgroundCircle
            }

            ShapePath {
                fillColor: AmneziaStyle.color.transparent
                strokeColor: AmneziaStyle.color.paleGray
                strokeWidth: root.buttonActiveFocus ? 1 : 0
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: backgroundCircle.width / 2
                    centerY: backgroundCircle.height / 2
                    radiusX: 94
                    radiusY: 94
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: AmneziaStyle.color.transparent
                strokeColor: {
                    if (ConnectionController.isConnectionInProgress) {
                        return AmneziaStyle.color.darkCharcoal
                    } else if (ConnectionController.isConnected) {
                        return connectedButtonColor
                    } else {
                        return defaultButtonColor
                    }
                }
                strokeWidth: root.buttonActiveFocus ? 2 : 3
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: backgroundCircle.width / 2
                    centerY: backgroundCircle.height / 2
                    radiusX: 93 - (root.buttonActiveFocus ? 2 : 0)
                    radiusY: 93 - (root.buttonActiveFocus ? 2 : 0)
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            MouseArea {
                anchors.fill: parent

                cursorShape: Qt.PointingHandCursor
                enabled: false
            }
        }

        Shape {
            id: shape
            width: parent.implicitWidth
            height: parent.implicitHeight
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            layer.enabled: true
            layer.samples: 4

            visible: ConnectionController.isConnectionInProgress && !root.tunnelCoreMode

            ShapePath {
                fillColor: AmneziaStyle.color.transparent
                strokeColor: AmneziaStyle.color.paleGray
                strokeWidth: 3
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: shape.width / 2
                    centerY: shape.height / 2
                    radiusX: 93
                    radiusY: 93
                    startAngle: 245
                    sweepAngle: -180
                }
            }

            RotationAnimator {
                target: shape
                running: ConnectionController.isConnectionInProgress
                from: 0
                to: 360
                loops: Animation.Infinite
                duration: 1000
            }
        }
    }

    contentItem: Text {
        height: 24

        font.family: "PT Root UI VF"
        font.weight: 700
        font.pixelSize: 20

        color: ConnectionController.isConnected ? connectedButtonColor : defaultButtonColor
        text: root.tunnelCoreMode ? "" : root.text

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    onClicked: {
        root.clickedFunc()
    }

    Keys.onEnterPressed: this.clicked()
    Keys.onReturnPressed: this.clicked()
}
