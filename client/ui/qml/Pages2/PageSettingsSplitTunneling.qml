import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QtCore

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    property var isServerFromTelegramApi: ServersUiController.isServerFromApi(ServersUiController.defaultServerId)
    
    property bool pageEnabled
    readonly property bool tvMode: SettingsController.isOnTv()
    // Give the TV remote a logical focus order independent of what is
    // currently visible inside the vertically scrollable header.
    readonly property bool remoteNavigationScope: tvMode

    function inside(item, container) {
        for (var current = item; current; current = current.parent)
            if (current === container) return true
        return false
    }

    function scrollHeaderTo(item) {
        if (!root.tvMode || !item || !root.inside(item, header))
            return
        var top = item.mapToItem(header, 0, 0).y
        var bottom = top + item.height
        var y = tvHeaderViewport.contentY
        if (bottom + 12 > y + tvHeaderViewport.height)
            y = bottom + 12 - tvHeaderViewport.height
        if (top - 12 < y)
            y = top - 12
        tvHeaderViewport.contentY = Math.max(0, Math.min(y,
                Math.max(0, tvHeaderViewport.contentHeight - tvHeaderViewport.height)))
    }

    function focusSite(index) {
        if (listView.count === 0)
            return
        index = Math.max(0, Math.min(index, listView.count - 1))
        listView.currentIndex = index
        listView.positionViewAtIndex(index, ListView.Contain)
        Qt.callLater(function() {
            if (!root.visible || !root.tvMode || !listView.enabled)
                return
            var row = listView.itemAtIndex(index)
            if (row && row.remoteSiteAction)
                row.remoteSiteAction.forceActiveFocus(Qt.TabFocusReason)
            else
                listView.forceActiveFocus(Qt.TabFocusReason)
        })
    }

    function navigateRemote(forward) {
        if (!root.tvMode || moreActionsDrawer.isOpened || importSitesDrawer.isOpened)
            return false
        var focused = root.Window.window ? root.Window.window.activeFocusItem : null
        var controls = [backButton.focusButton, headerSwitch.switcher,
                        countryBypassSelector, selector]
        if (listView.count > 0 && listView.enabled)
            controls.push(listView)
        controls.push(searchField.textField, addSiteButtonImage)
        controls = controls.filter(function(item) {
            return item && item.visible && item.enabled
        })
        var current = controls.findIndex(function(item) {
            return focused && root.inside(focused, item)
        })
        // Country/mode picker and other drawers handle their own D-pad focus.
        if (current < 0)
            return false
        if (controls[current] === listView && listView.count > 0) {
            var nextSite = listView.currentIndex + (forward ? 1 : -1)
            if (nextSite >= 0 && nextSite < listView.count) {
                root.focusSite(nextSite)
                return true
            }
        }
        var next = current + (forward ? 1 : -1)
        if (next < 0 || next >= controls.length)
            return false
        var target = controls[next]
        if (target === listView)
            root.focusSite(forward ? 0 : listView.count - 1)
        else {
            FocusController.setFocusItem(target)
            root.scrollHeaderTo(target)
        }
        return true
    }

    ListModel {
        id: geoCountriesListModel
    }

    Component.onCompleted: {
        updateGeoCountriesModel()

        if (ConnectionController.isConnected) {
            PageController.showNotificationMessage(qsTr("Cannot change split tunneling settings during active connection"))
            root.pageEnabled = false
        } else if (ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling) {
            PageController.showNotificationMessage(qsTr("Default server does not support split tunneling function"))
            root.pageEnabled = false
        } else {
            root.pageEnabled = true
        }
    }

    Connections {
        target: IpSplitTunnelingController

        function onFinished(message) {
            PageController.showNotificationMessage(message)
        }

        function onErrorOccurred(errorMessage) {
            PageController.showErrorMessage(errorMessage)
        }
    }

    Connections {
        target: TunnelCoreController

        function onChanged() {
            updateGeoCountriesModel()
        }
    }

    QtObject {
        id: routeMode
        property int allSites: 0
        property int onlyForwardSites: 1
        property int allExceptSites: 2
    }

    property list<QtObject> routeModesModel: [
        onlyForwardSites,
        allExceptSites
    ]

    QtObject {
        id: onlyForwardSites
        property string name: qsTr("Only the sites listed here will be accessed through the VPN")
        property int type: routeMode.onlyForwardSites
    }
    QtObject {
        id: allExceptSites
        property string name: qsTr("Addresses from the list should not be accessed via VPN")
        property int type: routeMode.allExceptSites
    }

    function getRouteModesModelIndex() {
        var currentRouteMode = IpSplitTunnelingController.routeMode
        if ((routeMode.onlyForwardSites === currentRouteMode) || (routeMode.allSites === currentRouteMode)) {
            return 0
        } else if (routeMode.allExceptSites === currentRouteMode) {
            return 1
        }
    }

    function updateGeoCountriesModel() {
        geoCountriesListModel.clear()
        geoCountriesListModel.append({ "name": qsTr("Standard rules"), "code": "" })
        var countries = TunnelCoreController.geoRoutingCountries
        for (var i = 0; i < countries.length; ++i) {
            geoCountriesListModel.append({
                "name": countries[i].name + " (" + countries[i].code + ")",
                "code": countries[i].code
            })
        }
    }

    function geoCountryModelIndex() {
        var selected = TunnelCoreController.geoRoutingCountry
        var countries = TunnelCoreController.geoRoutingCountries
        if (!selected || selected.length === 0)
            return 0
        for (var i = 0; i < countries.length; ++i) {
            if (countries[i].code === selected)
                return i + 1
        }
        return 0
    }

    function geoCountryText() {
        var index = geoCountryModelIndex()
        if (index >= 0 && index < geoCountriesListModel.count)
            return geoCountriesListModel.get(index).name
        return qsTr("Standard rules")
    }

    function escapeRegExp(value) {
        return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    }

    Rectangle {
        anchors.fill: parent
        color: AmneziaStyle.color.tcBackground
    }

    // Previously the header was fixed above a ListView of sites. On Android
    // TV the country and mode controls could extend below the viewport and
    // could never be reached with the remote. Keep the sites list separate,
    // but give the entire header a real, bounded scrollable viewport.
    Flickable {
        id: tvHeaderViewport
        objectName: "splitTunnelingHeaderViewport"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.tvMode
                ? Math.min(header.implicitHeight, Math.max(120,
                    root.height - (addSiteButton.implicitHeight + 48) - 120))
                : header.implicitHeight
        contentWidth: width
        contentHeight: header.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.tvMode
        clip: root.tvMode

    ColumnLayout {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        BackButtonType {
            id: backButton
            imageColor: AmneziaStyle.color.tcInk
        }

        HeaderTypeWithSwitcher {
            id: headerSwitch
            headerColor: AmneziaStyle.color.tcInk
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            headerText: qsTr("Split tunneling")

            enabled: root.pageEnabled
            showSwitcher: true
            switcher {
                checked: IpSplitTunnelingController.isSplitTunnelingEnabled
                enabled: root.pageEnabled
            }
            switcherFunction: function(checked) {
                IpSplitTunnelingController.toggleSplitTunneling(checked)
                selector.text = root.routeModesModel[getRouteModesModelIndex()].name
            }
        }

        DropDownType {
            textColor: AmneziaStyle.color.tcInk
            rootButtonImageColor: AmneziaStyle.color.tcBlue
            rootButtonBackgroundColor: AmneziaStyle.color.tcCard
            rootButtonBackgroundHoveredColor: AmneziaStyle.color.tcSurfaceBlue
            rootButtonBackgroundPressedColor: AmneziaStyle.color.tcSurfaceBlue
            rootButtonDefaultBorderColor: AmneziaStyle.color.tcStroke
            drawerBackgroundColor: AmneziaStyle.color.tcCard
            drawerBorderColor: AmneziaStyle.color.tcStroke
            drawerHeaderColor: AmneziaStyle.color.tcInk
            drawerBackButtonColor: AmneziaStyle.color.tcInk
            id: countryBypassSelector

            Layout.fillWidth: true
            Layout.topMargin: 24
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            // Keep the search box and matching country rows visible when
            // the Android IME reduces the available page height.
            drawerHeight: (Qt.inputMethod.visible || PageController.imeHeight > 0) ? 0.95 : 0.7
            drawerParent: root

            onOpenTriggered: {
                countrySearchInput.clear()
                Qt.callLater(function() { geoCountriesList.positionViewAtBeginning() })
            }

            visible: TunnelCoreController.authenticated
                     && TunnelCoreController.geoRoutingCountries.length > 0
            enabled: root.pageEnabled && !TunnelCoreController.busy

            headerText: qsTr("Country traffic directly")
            text: root.geoCountryText()

            listView: Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.bottomMargin: 12
                    spacing: 12

                    // Let the TextField receive touch presses directly; the card's
                    // passive handler also supports taps on its label and padding.
                    Rectangle {
                        id: countrySearchBox
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        implicitHeight: 80
                        radius: 16
                        color: AmneziaStyle.color.tcBackground
                        border.width: 1
                        border.color: countrySearchInput.activeFocus
                                      ? AmneziaStyle.color.tcBlue
                                      : AmneziaStyle.color.tcStroke

                        // Support tapping anywhere in the search card, including
                        // the label / padding, without requiring a tiny text target.
                        TapHandler {
                            onTapped: countrySearchInput.showKeyboard()
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 16
                                Layout.rightMargin: 8
                                spacing: 4

                                LabelTextType {
                                    Layout.fillWidth: true
                                    text: qsTr("Search")
                                    color: AmneziaStyle.color.tcMuted

                                }

                                TextField {
                                    id: countrySearchInput
                                    objectName: "splitTunnelingCountrySearchInput"
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    focusPolicy: Qt.StrongFocus
                                    activeFocusOnPress: true
                                    color: AmneziaStyle.color.tcInk
                                    placeholderText: qsTr("Search")
                                    placeholderTextColor: AmneziaStyle.color.tcMuted
                                    selectionColor: AmneziaStyle.color.tcBlue
                                    selectedTextColor: AmneziaStyle.color.tcCard
                                    font.pixelSize: 16
                                    font.family: "PT Root UI VF"
                                    inputMethodHints: Qt.ImhNoAutoUppercase
                                    background: Item {}

                                    property bool androidImeRequestPending: false

                                    function scheduleAndroidKeyboard() {
                                        if (androidImeRequestPending || Qt.platform.os !== "android")
                                            return
                                        androidImeRequestPending = true
                                        Qt.callLater(function() {
                                            androidImeRequestPending = false
                                            requestAndroidKeyboard()
                                        })
                                    }

                                    function requestAndroidKeyboard() {
                                        if (Qt.platform.os !== "android" || !activeFocus || !visible)
                                            return
                                        Qt.inputMethod.show()
                                        SystemController.requestSoftKeyboard()
                                    }

                                    function showKeyboard() {
                                        forceActiveFocus(Qt.MouseFocusReason)
                                        scheduleAndroidKeyboard()
                                    }

                                    onActiveFocusChanged: {
                                        if (activeFocus)
                                            scheduleAndroidKeyboard()
                                    }

                                    // Filtering must start at the first match,
                                    // even if the old list was scrolled down.
                                    onTextChanged: geoCountriesList.positionViewAtBeginning()

                                }
                            }

                            BasicButtonType {
                                Layout.preferredWidth: 80
                                Layout.fillHeight: true
                                implicitHeight: countrySearchBox.implicitHeight
                                focusPolicy: Qt.NoFocus
                                defaultColor: AmneziaStyle.color.tcSurfaceBlue
                                hoveredColor: AmneziaStyle.color.tcCard
                                pressedColor: AmneziaStyle.color.tcStroke
                                textColor: AmneziaStyle.color.tcBlue
                                squareLeftSide: true
                                leftImageSource: countrySearchInput.text.length > 0
                                                 ? "qrc:/images/controls/close.svg"
                                                 : "qrc:/images/controls/search.svg"
                                clickedFunc: function() {
                                    if (countrySearchInput.text.length > 0)
                                        countrySearchInput.clear()
                                    countrySearchInput.showKeyboard()
                                }
                            }
                        }
                    }

                    Connections {
                        target: countryBypassSelector

                        function onCloseTriggered() {
                            // Do not leave the soft keyboard covering the
                            // split tunneling page after dismissing the picker.
                            countrySearchInput.focus = false
                            Qt.inputMethod.hide()
                        }
                    }

                    // The search stays fixed; only this bounded results
                    // viewport scrolls. The shared radio list binds height
                    // to contentHeight, so it cannot reliably scroll here.
                    Item {
                        id: countryResultsViewport
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 0
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        clip: true

                        ListViewType {
                            id: geoCountriesList
                            objectName: "splitTunnelingCountryList"
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.VerticalFlick
                            keyNavigationEnabled: true
                            ScrollBar.vertical: ScrollBarType {
                                policy: ScrollBar.AsNeeded
                            }

                            model: SortFilterProxyModel {
                                id: filteredGeoCountriesModel
                                sourceModel: geoCountriesListModel
                                filters: RegExpFilter {
                                    roleName: "name"
                                    pattern: ".*" + root.escapeRegExp(countrySearchInput.text.trim()) + ".*"
                                    caseSensitivity: Qt.CaseInsensitive
                                }
                            }

                            delegate: ItemDelegate {
                                id: countryRow
                                width: geoCountriesList.width
                                implicitHeight: 60
                                leftPadding: 16
                                rightPadding: 16
                                topPadding: 8
                                bottomPadding: 8

                                readonly property string countryName: model.name
                                readonly property string countryCode: model.code
                                readonly property bool countrySelected:
                                    countryCode === TunnelCoreController.geoRoutingCountry

                                background: Rectangle {
                                    radius: 12
                                    color: countryRow.countrySelected || countryRow.down
                                           ? AmneziaStyle.color.tcSurfaceBlue
                                           : AmneziaStyle.color.tcCard
                                }

                                contentItem: RowLayout {
                                    spacing: 8

                                    ParagraphTextType {
                                        Layout.fillWidth: true
                                        text: countryRow.countryName
                                        color: AmneziaStyle.color.tcInk
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                    }

                                    IconImageType {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        source: "qrc:/images/controls/check.svg"
                                        tint: AmneziaStyle.color.tcBlue
                                        visible: countryRow.countrySelected
                                    }
                                }

                                onClicked: {
                                    // Select by code, never by a stale index
                                    // in the live-filtered view.
                                    countryBypassSelector.closeTriggered()
                                    TunnelCoreController.selectGeoRoutingCountry(countryRow.countryCode)
                                }
                            }
                        }

                        LabelTextType {
                            anchors.centerIn: parent
                            visible: geoCountriesList.count === 0
                            text: qsTr("No countries found")
                            color: AmneziaStyle.color.tcMuted
                        }
                    }

                    Connections {
                        target: TunnelCoreController
                        function onChanged() {
                            countryBypassSelector.text = root.geoCountryText()
                        }
                    }
                }
            }
        }

        ParagraphTextType {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            visible: countryBypassSelector.visible
            text: TunnelCoreController.geoRoutingCountry.length > 0
                  ? qsTr("Traffic to the selected country's IPv4 networks goes directly. All other traffic stays inside the VPN. IPv6 remains inside the VPN.")
                  : qsTr("Choose a country to send its IPv4 networks directly while keeping all other traffic inside the VPN.")
            color: AmneziaStyle.color.tcMuted
            maximumLineCount: 4
        }

        DropDownType {
            textColor: AmneziaStyle.color.tcInk
            rootButtonImageColor: AmneziaStyle.color.tcBlue
            rootButtonBackgroundColor: AmneziaStyle.color.tcCard
            rootButtonBackgroundHoveredColor: AmneziaStyle.color.tcSurfaceBlue
            rootButtonBackgroundPressedColor: AmneziaStyle.color.tcSurfaceBlue
            rootButtonDefaultBorderColor: AmneziaStyle.color.tcStroke
            drawerBackgroundColor: AmneziaStyle.color.tcCard
            drawerBorderColor: AmneziaStyle.color.tcStroke
            drawerHeaderColor: AmneziaStyle.color.tcInk
            drawerBackButtonColor: AmneziaStyle.color.tcInk
            id: selector

            Layout.fillWidth: true
            Layout.topMargin: 32
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            drawerHeight: 0.4375
            drawerParent: root

            enabled: root.pageEnabled

            headerText: qsTr("Mode")

            listView: ListViewWithRadioButtonType {
                rootWidth: root.width
                textColor: AmneziaStyle.color.tcInk
                itemColor: AmneziaStyle.color.tcCard
                itemHoveredColor: AmneziaStyle.color.tcSurfaceBlue
                itemSelectedColor: AmneziaStyle.color.tcSurfaceBlue

                model: root.routeModesModel

                selectedIndex: getRouteModesModelIndex()

                clickedFunction: function() {
                    selector.text = selectedText
                    selector.closeTriggered()
                    if (IpSplitTunnelingController.routeMode !== root.routeModesModel[selectedIndex].type) {
                        IpSplitTunnelingController.routeMode = root.routeModesModel[selectedIndex].type
                    }
                }

                Component.onCompleted: {
                    if (root.routeModesModel[selectedIndex].type === IpSplitTunnelingController.routeMode) {
                        selector.text = selectedText
                    } else {
                        selector.text = root.routeModesModel[0].name
                    }
                }

                Connections {
                    target: IpSplitTunnelingController
                    function onRouteModeChanged() {
                        selectedIndex = getRouteModesModelIndex()
                    }
                }
            }
        }
    }
    } // tvHeaderViewport

    ListViewType {
        id: listView

        ScrollBar.vertical: ScrollBarType { policy: ScrollBar.AlwaysOn }

        anchors.top: tvHeaderViewport.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: addSiteButton.implicitHeight + 48 + (searchField.textField.activeFocus ? 0 : PageController.imeHeight)

        width: parent.width

        enabled: root.pageEnabled
        clip: true
        keyNavigationEnabled: true

        model: SortFilterProxyModel {
            id: proxyIpSplitTunnelingModel
            sourceModel: IpSplitTunnelingModel
            filters: [
                AnyOf {
                    RegExpFilter {
                        roleName: "url"
                        pattern: ".*" + searchField.textField.text + ".*"
                        caseSensitivity: Qt.CaseInsensitive
                    }
                    RegExpFilter {
                        roleName: "ip"
                        pattern: ".*" + searchField.textField.text + ".*"
                        caseSensitivity: Qt.CaseInsensitive
                    }
                }
            ]
        }

        delegate: ColumnLayout {
            width: listView.width
            property alias remoteSiteAction: site.rightButton

            LabelWithButtonType {
            textColor: AmneziaStyle.color.tcInk
            descriptionColor: AmneziaStyle.color.tcMuted
                id: site
                Layout.fillWidth: true

                text: url
                descriptionText: ip
                rightImageSource: "qrc:/images/controls/trash.svg"
                rightImageColor: AmneziaStyle.color.tcBlue

                // Highlight the whole row when its delete action has TV focus.
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: 14
                    border.color: root.tvMode && site.rightButton.activeFocus
                                  ? AmneziaStyle.color.tcBlue : "transparent"
                    border.width: root.tvMode && site.rightButton.activeFocus ? 3 : 0
                }

                clickedFunction: function() {
                    var headerText = qsTr("Remove ") + url + "?"
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        IpSplitTunnelingController.removeSite(proxyIpSplitTunnelingModel.mapToSource(index))
                        if (!GC.isMobile()) {
                            site.rightButton.forceActiveFocus()
                        }
                    }
                    var noButtonFunction = function() {
                        if (!GC.isMobile()) {
                            site.rightButton.forceActiveFocus()
                        }
                    }

                    showQuestionDrawer(headerText, "", yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            DividerType { color: AmneziaStyle.color.tcStroke }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        
        height: addSiteButton.implicitHeight + 48
        
        color: AmneziaStyle.color.tcBackground
        
        RowLayout {
            id: addSiteButton

            enabled: root.pageEnabled

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 24
            anchors.rightMargin: 16
            anchors.leftMargin: 16
            anchors.bottomMargin: 24

            TextFieldWithHeaderType {
            backgroundColor: AmneziaStyle.color.tcCard
            textFieldTextColor: AmneziaStyle.color.tcInk
            borderColor: AmneziaStyle.color.tcStroke
            borderFocusedColor: AmneziaStyle.color.tcBlue
            headerTextColor: AmneziaStyle.color.tcMuted
                id: searchField

                Layout.fillWidth: true
                requestAndroidIme: true
                rightButtonClickedOnEnter: true

                textField.placeholderText: qsTr("website or IP")
                buttonImageSource: "qrc:/images/controls/plus.svg"

                clickedFunc: function() {
                    PageController.showBusyIndicator(true)
                    IpSplitTunnelingController.addSite(textField.text)
                    textField.text = ""
                    PageController.showBusyIndicator(false)
                }
            }

            ImageButtonType {
                id: addSiteButtonImage
                implicitWidth: 56
                implicitHeight: 56

                image: "qrc:/images/controls/more-vertical.svg"
                imageColor: AmneziaStyle.color.tcBlue

                onClicked: function () {
                    moreActionsDrawer.openTriggered()
                }

                Keys.onReturnPressed: addSiteButtonImage.clicked()
                Keys.onEnterPressed: addSiteButtonImage.clicked()
            }
        }
    }

    DrawerType2 {
        id: moreActionsDrawer

        anchors.fill: parent
        // The action labels use tcInk: their surface must be light as well.
        defaultColor: AmneziaStyle.color.tcCard
        borderColor: AmneziaStyle.color.tcStroke
        expandedHeight: parent.height * 0.4375

        expandedStateContent: ColumnLayout {
            id: moreActionsDrawerContent

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            Header2Type {
                Layout.fillWidth: true
                Layout.margins: 16

                headerText: qsTr("Additional options")
                headerColor: AmneziaStyle.color.tcInk
            }

            LabelWithButtonType {
            textColor: AmneziaStyle.color.tcInk
            descriptionColor: AmneziaStyle.color.tcMuted
            rightImageColor: AmneziaStyle.color.tcBlue
                id: importSitesButton
                Layout.fillWidth: true

                text: qsTr("Import")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    importSitesDrawer.openTriggered()
                }
            }

            DividerType { color: AmneziaStyle.color.tcStroke }

            LabelWithButtonType {
            textColor: AmneziaStyle.color.tcInk
            descriptionColor: AmneziaStyle.color.tcMuted
            rightImageColor: AmneziaStyle.color.tcBlue
                id: exportSitesButton
                Layout.fillWidth: true
                text: qsTr("Save site list")

                clickedFunction: function() {
                    var fileName = ""
                    if (GC.isMobile()) {
                        fileName = "amnezia_sites.json"
                    } else {
                        fileName = SystemController.getFileName(qsTr("Save sites"),
                                                                qsTr("Sites files (*.json)"),
                                                                StandardPaths.standardLocations(StandardPaths.DocumentsLocation) + "/amnezia_sites",
                                                                true,
                                                                ".json")
                    }
                    if (fileName !== "") {
                        PageController.showBusyIndicator(true)
                        IpSplitTunnelingController.exportSites(fileName)
                        moreActionsDrawer.closeTriggered()
                        PageController.showBusyIndicator(false)
                    }
                }
            }

            DividerType { color: AmneziaStyle.color.tcStroke }
            
            LabelWithButtonType {
            textColor: AmneziaStyle.color.tcInk
            descriptionColor: AmneziaStyle.color.tcMuted
            rightImageColor: AmneziaStyle.color.tcBlue
                id: clearSitesButton
                Layout.fillWidth: true

                text: qsTr("Clear site list")

                clickedFunction: function() {
                    var headerText = qsTr("Clear site list?")
                    var descriptionText = qsTr("All sites will be removed from list.")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        PageController.showBusyIndicator(true)
                        IpSplitTunnelingController.removeSites()
                        PageController.showBusyIndicator(false)
                    }
                    var noButtonFunction = function() {
                        
                    }

                    showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            DividerType { color: AmneziaStyle.color.tcStroke }
        }
    }

    DrawerType2 {
        id: importSitesDrawer

        anchors.fill: parent
        defaultColor: AmneziaStyle.color.tcCard
        borderColor: AmneziaStyle.color.tcStroke
        expandedHeight: parent.height * 0.4375

        expandedStateContent: Item {
            implicitHeight: importSitesDrawer.expandedHeight

            BackButtonType {
                id: importSitesDrawerBackButton
                imageColor: AmneziaStyle.color.tcInk

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 16

                backButtonFunction: function() {
                    importSitesDrawer.closeTriggered()
                }
                
                onFocusChanged: {
                    if (this.activeFocus) {
                        importSitesDrawerListView.positionViewAtBeginning()
                    }
                }
            }

            ListViewType {
                id: importSitesDrawerListView

                anchors.top: importSitesDrawerBackButton.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                header: ColumnLayout {
                    width: importSitesDrawerListView.width

                    Header2Type {
                        Layout.fillWidth: true
                        Layout.margins: 16

                        headerText: qsTr("Import a list of sites")
                        headerColor: AmneziaStyle.color.tcInk
                    }
                }

                model: importOptions

                delegate: ColumnLayout {
                    width: importSitesDrawerListView.width

                    LabelWithButtonType {
            textColor: AmneziaStyle.color.tcInk
            descriptionColor: AmneziaStyle.color.tcMuted
            rightImageColor: AmneziaStyle.color.tcBlue
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16

                        text: title

                        clickedFunction: function() {
                            clickedHandler()
                        }
                    }

                    DividerType { color: AmneziaStyle.color.tcStroke }
                }
            }
        }
    }

    property list<QtObject> importOptions: [
        replaceOption,
        addOption,
    ]

    QtObject {
        id: replaceOption

        readonly property string title: qsTr("Replace site list")
        readonly property var clickedHandler: function() {
            var fileName = SystemController.getFileName(qsTr("Open sites file"),
                                                        qsTr("Sites files (*.json)"))
            if (fileName !== "") {
                root.importSites(fileName, true)
            }
        }
    }

    QtObject {
        id: addOption

        readonly property string title: qsTr("Add imported sites to existing ones")
        readonly property var clickedHandler: function() {
            var fileName = SystemController.getFileName(qsTr("Open sites file"),
                                                        qsTr("Sites files (*.json)"))
            if (fileName !== "") {
                root.importSites(fileName, false)
            }
        }
    }

    function importSites(fileName, replaceExistingSites) {
        PageController.showBusyIndicator(true)
        IpSplitTunnelingController.importSites(fileName, replaceExistingSites)
        PageController.showBusyIndicator(false)
        importSitesDrawer.closeTriggered()
        moreActionsDrawer.closeTriggered()
    }
}
