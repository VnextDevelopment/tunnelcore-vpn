"""Run with QT_QPA_PLATFORM=offscreen python -m unittest discover -s tests/qml.

Requires PySide6. Loads production auth/dashboard/country layouts and controls;
backend controllers and unrelated icon/context-menu services are stubbed.
This does not emulate Android's native IME.
"""
import os
from pathlib import Path
import re
import shutil
import tempfile
import unittest

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
from PySide6.QtCore import QUrl, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine, QQmlExpression
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest

ROOT = Path(__file__).resolve().parents[2]
QML = ROOT / 'client/ui/qml'


class TvAuthTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QGuiApplication.instance() or QGuiApplication([])
        cls.tmp = tempfile.TemporaryDirectory()
        cls.path = Path(cls.tmp.name)
        shutil.copytree(QML / 'Controls2', cls.path / 'Controls2')
        field = cls.path / 'Controls2/TextFieldWithHeaderType.qml'
        field.write_text(field.read_text().replace('id: textField', 'id: textField\nobjectName: "editor"'))
        (cls.path / 'Components').mkdir()
        shutil.copy(QML / 'Components/QuestionDrawer.qml', cls.path / 'Components/QuestionDrawer.qml')
        home_split = (QML / 'Components/HomeSplitTunnelingDrawer.qml').read_text()
        home_split = home_split.replace('import PageEnum 1.0', '')
        home_split = home_split.replace('PageEnum.PageSettingsSplitTunneling', '42')
        (cls.path / 'Components/HomeSplitTunnelingDrawer.qml').write_text(home_split)
        connect = (QML / 'Components/ConnectButton.qml').read_text()
        for module in ['ConnectionState', 'AppIcons', 'PageEnum']:
            connect = connect.replace('import ' + module + ' 1.0', '')
        (cls.path / 'Components/ConnectButton.qml').write_text(connect)
        (cls.path / 'Components/PaintedIcon.qml').write_text(
            'import QtQuick\nItem { property string source; property string tint }')
        (cls.path / 'Config').mkdir()
        (cls.path / 'Pages2').mkdir()
        (cls.path / 'Controls2/IconImageType.qml').write_text(
            'import QtQuick\nItem { property string source; property string tint }')
        (cls.path / 'Controls2/ContextMenuType.qml').write_text('''import QtQuick
Item { property var textObj; property bool useNativeEditMenu: false
property bool opened: false
function requestNative(position) {} }
''')
        (cls.path / 'Controls2/ImageButtonType.qml').write_text('''import QtQuick.Controls
Button { property string image; property string imageColor; property bool isFocusable: true }
''')
        colors = set()
        for file in (cls.path / 'Controls2').rglob('*.qml'):
            colors.update(re.findall(r'AmneziaStyle.color.(\w+)', file.read_text()))
        source = (QML / 'Pages2/PageTunnelCoreAccount.qml').read_text()
        colors.update(re.findall(r'AmneziaStyle.color.(\w+)', source))
        colors.update(re.findall(r'AmneziaStyle.color.(\w+)', home_split))
        style = cls.path / 'Style'
        style.mkdir()
        (style / 'qmldir').write_text('module Style\nsingleton AmneziaStyle 1.0 AmneziaStyle.qml\n')
        (style / 'AmneziaStyle.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property QtObject color: QtObject {' + '\n'.join(
            f'property color {c}: "#336699"' for c in colors) + '} }')
        # Keep auth, dashboard and countries; omit unrelated profile/drawer services.
        source = source.split('            // Account details and destructive actions', 1)[0] + '\n        }\n    }\n}\n'
        source = source.replace('import PageEnum 1.0', '')
        for ident in ['scroll', 'loginField', 'passwordField', 'confirmPasswordField',
                      'authSubmitButton', 'welcomeSignIn', 'welcomeRegister', 'welcomeCode']:
            source = source.replace('id: ' + ident + '\n', f'id: {ident}\nobjectName: "{ident}"\n')
        (cls.path / 'Pages2/PageTunnelCoreAccount.qml').write_text(source)

    def setUp(self):
        self.engine = QQmlEngine()
        self.engine.addImportPath(str(self.path))
        self.objects = []
        mocks = {
            'TunnelCoreController': '''property bool authenticated: false; property bool busy: false
property string error: ""; property string username: ""; property string vpnCountryMode: "auto"
property string selectedVpnCountry: ""; property int submits: 0
property var vpnCountries: []; property var configs: []; function refresh() {}
property string effectiveVpnCountry: ""; property string selectedProfileKey: "test"
property var subscriptions: []; property var primarySubscription: ({})
property bool subscriptionWarningVisible: false; property bool subscriptionExpired: false
property bool usesAppleBilling: false; property bool externalRenewalLinkAllowed: false
property bool emailAccount: false; property bool telegramLinked: false
property string subscriptionStatusText: ""
function vpnCountryDisplayName(code) { return code }
signal signedIn(); signal configReady(var data, string fileName, int obfuscationMode, string obfuscationProfile)
signal changed()
function clearError() {} function loginCode(code) { submits++ }
function loginEmail(email, password) { submits++ }
function registerEmail(email, password) { submits++ }''',
            'PageController': 'property int imeHeight: 0; property int safeAreaTopMargin: 0; property int safeAreaBottomMargin: 0; property int drawerDepth: 0; property int navigations: 0; function goToPage(page) { navigations++ } signal closeTopDrawer(); function incrementDrawerDepth() { return ++drawerDepth } function decrementDrawerDepth() { drawerDepth-- } function getDrawerDepth() { return drawerDepth } function getInitialPageNavigationBarColor() { return 0xff1c1d21 } function updateNavigationBarColor(color) {}',
            'ConnectionController': 'property bool isConnected: false; property bool isConnectionInProgress: false; signal connectionStateChanged(); signal preparingConfig(); property string connectionStateText: "Disconnected"; property int clicks: 0; function connectButtonClicked() { clicks++ }',
            'ImportController': 'function activateTunnelCoreProfile(key) { return true } signal importFinished(); signal importErrorOccurred(string error, bool goToPageHome)',
            'LanguageUiController': 'function getLineHeightAppend() { return 0 }',
            'FocusController': '''function resetRootObject() {}
function setFocusOnDefaultItem() {}
function setFocusItem(item) { item.forceActiveFocus() }
function nextKeyDownItem() {
    if (typeof testedDrawer !== "undefined" && testedDrawer && testedDrawer.isOpened)
        testedDrawer.navigateRemote(true)
    else testedPage.navigateRemote(true)
}
function nextKeyUpItem() {
    if (typeof testedDrawer !== "undefined" && testedDrawer && testedDrawer.isOpened)
        testedDrawer.navigateRemote(false)
    else testedPage.navigateRemote(false)
}
function pushRootObject(item) {}
function dropRootObject(item) {}''',
            'IpSplitTunnelingController': 'property bool isSplitTunnelingEnabled: false',
            'AppSplitTunnelingController': 'property bool isSplitTunnelingEnabled: false',
            'ServersUiController': 'property bool isDefaultServerDefaultContainerHasSplitTunneling: false',
            'SettingsController': 'function isOnTv() { return true }',
        }
        for name, body in mocks.items():
            comp = QQmlComponent(self.engine)
            comp.setData(('import QtQuick\nQtObject {' + body + '}').encode(), QUrl())
            obj = comp.create()
            self.assertIsNotNone(obj, str(comp.errors()))
            obj.setParent(self.engine)
            self.objects.append(obj)
            self.engine.rootContext().setContextProperty(name, obj)
        self.comp = QQmlComponent(self.engine, QUrl.fromLocalFile(str(self.path / 'Pages2/PageTunnelCoreAccount.qml')))
        self.page = self.comp.create()
        self.assertIsNotNone(self.page, str(self.comp.errors()))
        self.engine.rootContext().setContextProperty("testedPage", self.page)
        self.window = QQuickWindow()
        self.window.resize(960, 540)
        self.page.setParentItem(self.window.contentItem())
        self.page.setWidth(960)
        self.page.setHeight(540)
        self.window.show()
        QTest.qWait(250)

    def tearDown(self):
        self.window.close()
        self.page.setParentItem(None)
        self.page.deleteLater()
        self.app.processEvents()
        del self.comp
        del self.engine

    def item(self, name):
        from PySide6.QtQuick import QQuickItem
        return self.page.findChild(QQuickItem, name)

    def editor(self, name):
        from PySide6.QtQuick import QQuickItem
        return self.item(name).findChild(QQuickItem, "editor")

    def assertInView(self, item):
        scroll = self.item('scroll')
        top = item.mapToItem(scroll, 0, 0).y()
        self.assertGreaterEqual(top, -1)
        self.assertLessEqual(top + item.height(), scroll.height() + 1)

    def test_tv_focus_is_visible_on_welcome_and_auth_inputs(self):
        welcome = self.item('welcomeSignIn')
        welcome.forceActiveFocus()
        QTest.qWait(30)
        self.assertTrue(welcome.hasActiveFocus())
        self.assertEqual(welcome.property('borderFocusedWidth'), 3)
        QTest.keyClick(self.window, Qt.Key_Down)
        register = self.item('welcomeRegister')
        self.assertTrue(register.hasActiveFocus())
        self.assertFalse(welcome.hasActiveFocus())
        self.assertEqual(register.property('borderFocusedWidth'), 3)
        QTest.keyClick(self.window, Qt.Key_Select)
        QTest.qWait(50)
        self.assertFalse(self.page.property('showWelcome'))
        self.assertTrue(self.editor('loginField').hasActiveFocus())
        self.assertEqual(self.item('loginField').property('borderFocusedColor'), '#336699')

    def test_tv_connect_focus_ring_tracks_dpad_navigation(self):
        self.objects[0].setProperty('authenticated', True)
        QTest.qWait(50)
        self.evaluate('focusPageControl()')
        connect = self.item('accountConnectButton')
        ring = connect.findChild(type(connect), 'tvConnectFocusRing')
        self.assertIsNotNone(ring)
        self.assertTrue(ring.isVisible())
        QTest.keyClick(self.window, Qt.Key_Down)
        self.assertFalse(ring.isVisible())
        button = self.item('accountSplitTunnelingButton')
        self.assertTrue(button.hasActiveFocus())
        self.assertEqual(button.property('borderFocusedWidth'), 3)

    def test_tv_confirmation_keeps_dpad_on_modal_and_cancel_restores_focus(self):
        self.objects[0].setProperty('authenticated', True)
        QTest.qWait(60)
        self.evaluate('focusPageControl()')
        previous = self.item('accountConnectButton')
        self.assertTrue(previous.hasActiveFocus())

        comp = QQmlComponent(self.engine, QUrl.fromLocalFile(str(
            self.path / 'Components/QuestionDrawer.qml')))
        drawer = comp.create()
        self.assertIsNotNone(drawer, str(comp.errors()))
        drawer.setParentItem(self.window.contentItem())
        drawer.setWidth(960)
        drawer.setHeight(540)
        drawer.setProperty('headerText', 'Sign out?')
        drawer.setProperty('yesButtonText', 'Sign out')
        drawer.setProperty('noButtonText', 'Cancel')
        # Production main2 closes first, then runs the selected callback.
        self.engine.rootContext().setContextProperty('testQuestionDrawer', drawer)
        self.evaluate('true')  # Keep the same live QML engine for navigation.
        def selected(name):
            obj = drawer.property(name)
            self.assertIsNotNone(obj)
            return obj
        drawer.openTriggered.emit()
        QTest.qWait(100)
        cancel = selected('noButtonItem')
        confirm = selected('yesButtonItem')
        self.assertTrue(cancel.hasActiveFocus())
        QTest.keyClick(self.window, Qt.Key_Down)
        self.assertTrue(confirm.hasActiveFocus())
        QTest.keyClick(self.window, Qt.Key_Up)
        self.assertTrue(cancel.hasActiveFocus())
        QTest.keyClick(self.window, Qt.Key_Back)
        QTest.qWait(100)
        self.assertTrue(drawer.property('isClosed'))
        self.assertTrue(previous.hasActiveFocus())
        drawer.setParentItem(None)
        drawer.deleteLater()

    def test_tv_dropdown_initial_focus_and_center_key(self):
        from PySide6.QtQuick import QQuickItem
        # Let the PageType initial-focus timer finish before opening a modal.
        QTest.qWait(290)
        # Exercise the real DropDownType + DrawerType2 lifecycle, including
        # the delayed creation of a listView Component and remote Key_Select.
        comp = QQmlComponent(self.engine)
        source = """import QtQuick
import QtQuick.Controls
import "Controls2"
Item {
    id: host
    width: 960; height: 540
    DropDownType {
        id: picker
        objectName: "tvDropdownTest"
        width: 320; height: 56
        drawerParent: host
        drawerHeight: 0.8
        text: "Country traffic directly"
        headerText: "Country traffic directly"
        property var testList: null
        onPopupOpened: if (testList) testList.forceActiveFocus(Qt.TabFocusReason)
        listView: Item {
            id: loadedList
            objectName: "tvDropdownLoadedList"
            Component.onCompleted: picker.testList = loadedList
            Component.onDestruction: {
                if (picker.testList === loadedList) picker.testList = null
            }
        }
    }
}
"""
        comp.setData(source.encode(), QUrl.fromLocalFile(str(self.path / 'TvDropdownTest.qml')))
        host = comp.create()
        self.assertIsNotNone(host, str(comp.errors()))
        host.setParentItem(self.window.contentItem())
        dropdown = host.findChild(QQuickItem, 'tvDropdownTest')
        self.assertIsNotNone(dropdown)
        dropdown.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key_Select)
        QTest.qWait(90)
        self.assertTrue(dropdown.property('popupIsOpen'))
        loaded = host.findChild(QQuickItem, 'tvDropdownLoadedList')
        self.assertIsNotNone(loaded)
        self.assertTrue(loaded.hasActiveFocus(),
                        f"popup_ready={dropdown.property('popupReadyNotified')}, "
                        f"content_ready={dropdown.property('popupContentReady')}, "
                        f"active_item={self.window.activeFocusItem()}")
        dropdown.closeTriggered.emit()
        QTest.qWait(75)
        self.assertFalse(dropdown.property('popupIsOpen'))
        host.setParentItem(None)
        host.deleteLater()

    def test_tv_home_split_sheet_keeps_focus_and_opens_settings(self):
        # Real dashboard overlay: its focus must land on an actual Qt Button,
        # not the surrounding Item (which does not activate on remote OK).
        from PySide6.QtQuick import QQuickItem
        self.objects[0].setProperty('authenticated', True)
        QTest.qWait(60)
        self.evaluate('focusPageControl()')
        previous = self.item('accountConnectButton')
        self.assertTrue(previous.hasActiveFocus())

        comp = QQmlComponent(self.engine, QUrl.fromLocalFile(
            str(self.path / 'Components/HomeSplitTunnelingDrawer.qml')))
        drawer = comp.create()
        self.assertIsNotNone(drawer, str(comp.errors()))
        drawer.setParentItem(self.page)
        drawer.setWidth(960)
        drawer.setHeight(540)
        self.engine.rootContext().setContextProperty('testedDrawer', drawer)
        drawer.openTriggered.emit()
        QTest.qWait(100)
        site = drawer.findChild(QQuickItem, 'homeSplitSitesRow')
        server = drawer.findChild(QQuickItem, 'homeSplitServerRow')
        self.assertIsNotNone(site)
        self.assertIsNotNone(server)
        site_button = drawer.findChild(QQuickItem, 'homeSplitSitesChevron')
        server_button = drawer.findChild(QQuickItem, 'homeSplitServerChevron')
        self.assertIsNotNone(site_button)
        self.assertIsNotNone(server_button)
        self.assertTrue(drawer.property('isOpened'))
        self.assertTrue(site_button.hasActiveFocus())  # only visible row
        self.assertFalse(site.hasActiveFocus())  # native button owns OK
        QTest.keyClick(self.window, Qt.Key_Down)
        self.assertTrue(site_button.hasActiveFocus())  # no movement to tabs behind
        self.assertFalse(previous.hasActiveFocus())
        QTest.keyClick(self.window, Qt.Key_Back)
        QTest.qWait(70)
        self.assertTrue(drawer.property('isClosed'))
        self.assertTrue(previous.hasActiveFocus())

        # Two-row case: navigation stays within the overlay.
        self.objects[8].setProperty('isDefaultServerDefaultContainerHasSplitTunneling', True)
        drawer.openTriggered.emit()
        QTest.qWait(80)
        self.assertTrue(server_button.hasActiveFocus())
        QTest.keyClick(self.window, Qt.Key_Down)
        self.assertTrue(site_button.hasActiveFocus())
        QTest.keyClick(self.window, Qt.Key_Up)
        self.assertTrue(server_button.hasActiveFocus())
        QTest.keyClick(self.window, Qt.Key_Down)
        self.assertTrue(site_button.hasActiveFocus())
        before = self.objects[1].property('navigations')
        QTest.keyClick(self.window, Qt.Key_Select)
        QTest.qWait(70)
        self.assertEqual(self.objects[1].property('navigations'), before + 1)
        self.assertTrue(drawer.property('isClosed'))
        drawer.setParentItem(None)
        drawer.deleteLater()

    def test_tv_home_split_sheet_single_item_ok_enters_settings(self):
        from PySide6.QtQuick import QQuickItem
        self.objects[0].setProperty('authenticated', True)
        comp = QQmlComponent(self.engine, QUrl.fromLocalFile(
            str(self.path / 'Components/HomeSplitTunnelingDrawer.qml')))
        drawer = comp.create()
        self.assertIsNotNone(drawer, str(comp.errors()))
        drawer.setParentItem(self.page)
        drawer.setWidth(960)
        drawer.setHeight(540)
        self.engine.rootContext().setContextProperty('testedDrawer', drawer)
        drawer.openTriggered.emit()
        QTest.qWait(100)
        site = drawer.findChild(QQuickItem, 'homeSplitSitesRow')
        self.assertIsNotNone(site)
        site_button = drawer.findChild(QQuickItem, 'homeSplitSitesChevron')
        self.assertIsNotNone(site_button)
        self.assertTrue(site_button.hasActiveFocus())
        before = self.objects[1].property('navigations')
        QTest.keyClick(self.window, Qt.Key_Select)
        QTest.qWait(70)
        self.assertEqual(self.objects[1].property('navigations'), before + 1)
        self.assertTrue(drawer.property('isClosed'))
        drawer.setParentItem(None)
        drawer.deleteLater()

    def test_remote_reaches_inputs_submit_and_cancel(self):
        for email, register in [(False, False), (True, False), (True, True)]:
            with self.subTest(email=email, register=register):
                self.page.setProperty('emailMode', email)
                self.page.setProperty('registrationMode', register)
                self.page.setProperty('showWelcome', False)
                QTest.qWait(200)
                login = self.editor('loginField')
                login.setProperty('text', 'user@example.com' if email else '123456')
                self.editor('passwordField').setProperty('text', 'password')
                self.editor('confirmPasswordField').setProperty('text', 'password')
                login.forceActiveFocus()
                QTest.qWait(200)
                self.assertInView(self.item('loginField'))
                targets = (['passwordField'] if email else []) + (['confirmPasswordField'] if register else [])
                for name in targets + ['authSubmitButton', 'authCancelButton']:
                    QTest.keyClick(self.window, Qt.Key_Down)
                    QTest.qWait(200)
                    target = self.item(name)
                    focus = self.editor(name) if 'Field' in name else target
                    self.assertTrue(focus.hasActiveFocus(), name)
                    self.assertInView(target)
                    if name == 'authSubmitButton':
                        before = self.objects[0].property('submits')
                        QTest.keyClick(self.window, Qt.Key_Select)
                        self.assertEqual(self.objects[0].property('submits'), before + 1)
                QTest.keyClick(self.window, Qt.Key_Select)
                QTest.qWait(200)
                self.assertTrue(self.page.property('showWelcome'))

    def test_disabled_submit_is_skipped_and_up_returns_to_field(self):
        self.page.setProperty('emailMode', False)
        self.page.setProperty('showWelcome', False)
        login = self.editor('loginField')
        login.forceActiveFocus()
        QTest.qWait(200)
        QTest.keyClick(self.window, Qt.Key_Down)
        QTest.qWait(200)
        self.assertTrue(self.item('authCancelButton').hasActiveFocus())
        self.assertInView(self.item('authCancelButton'))
        QTest.keyClick(self.window, Qt.Key_Up)
        QTest.qWait(200)
        self.assertTrue(login.hasActiveFocus())
        self.assertInView(self.item('loginField'))

    def test_large_window_and_keyboard_resize_preserve_button_focus(self):
        self.page.setHeight(900)
        self.window.resize(960, 900)
        self.page.setProperty('showWelcome', False)
        self.editor('loginField').setProperty('text', 'user@example.com')
        self.editor('passwordField').setProperty('text', 'password')
        self.editor('passwordField').forceActiveFocus()
        QTest.qWait(200)
        QTest.keyClick(self.window, Qt.Key_Down)
        QTest.qWait(200)
        self.assertTrue(self.item('authSubmitButton').hasActiveFocus())
        self.assertInView(self.item('authSubmitButton'))
        self.page.setHeight(320)
        self.window.resize(960, 320)
        QTest.qWait(200)
        self.assertInView(self.item('authSubmitButton'))
        QTest.keyClick(self.window, Qt.Key_Down)
        QTest.qWait(200)
        self.assertTrue(self.item('authCancelButton').hasActiveFocus())
        self.assertInView(self.item('authCancelButton'))

    def evaluate(self, expression):
        expr = QQmlExpression(self.engine.rootContext(), self.page, expression)
        value = expr.evaluate()
        self.assertFalse(expr.hasError(), expr.error().toString())
        return value

    def test_dashboard_navigation_scrolls_and_returns_to_menu(self):
        self.objects[0].setProperty('authenticated', True)
        self.page.setHeight(300)
        QTest.qWait(200)
        self.evaluate('focusPageControl()')
        connect = self.item('accountConnectButton')
        self.assertTrue(connect.hasActiveFocus())
        self.assertInView(connect)
        QTest.keyClick(self.window, Qt.Key_Select)
        self.assertEqual(self.objects[2].property('clicks'), 1)
        QTest.keyClick(self.window, Qt.Key_Down)
        split = self.item('accountSplitTunnelingButton')
        self.assertTrue(split.hasActiveFocus())
        self.assertInView(split)
        QTest.keyClick(self.window, Qt.Key_Up)
        self.assertTrue(connect.hasActiveFocus())
        self.assertInView(connect)
        from PySide6.QtTest import QSignalSpy
        menu = QSignalSpy(self.page.remoteMenuRequested)
        QTest.keyClick(self.window, Qt.Key_Up)
        self.assertEqual(menu.count(), 1)
        QTest.keyClick(self.window, Qt.Key_Down)
        QTest.keyClick(self.window, Qt.Key_Down)
        self.assertEqual(menu.count(), 2)

    def test_country_list_includes_offscreen_rows_and_filters(self):
        self.objects[0].setProperty('authenticated', True)
        self.objects[0].setProperty('vpnCountries', [{'code': str(i), 'cities': []} for i in range(15)])
        self.page.setProperty('viewMode', 'countries')
        self.page.setHeight(300)
        QTest.qWait(200)
        self.evaluate('focusPageControl()')
        # Search, Automatic, every country, Refresh: all reachable, even offscreen.
        for _ in range(17):
            QTest.keyClick(self.window, Qt.Key_Down)
            self.assertInView(self.window.activeFocusItem())
        self.assertEqual(self.window.activeFocusItem().property('text'), 'Refresh')
        self.page.setProperty('countryFilter', '14')
        QTest.qWait(100)
        self.evaluate('focusPageControl()')
        QTest.keyClick(self.window, Qt.Key_Down)
        QTest.keyClick(self.window, Qt.Key_Down)
        self.assertEqual(self.window.activeFocusItem().property('text'), '14')
        self.assertInView(self.window.activeFocusItem())

    def test_menu_vertical_key_enters_dashboard(self):
        self.objects[0].setProperty('authenticated', True)
        comp = QQmlComponent(self.engine)
        comp.setData(b'import QtQuick; import "Controls2"; TabImageButtonType { verticalNavigationHandler: testedPage.focusPageControl }',
                     QUrl.fromLocalFile(str(self.path / 'MenuTest.qml')))
        tab = comp.create()
        self.assertIsNotNone(tab, str(comp.errors()))
        tab.setParentItem(self.window.contentItem())
        tab.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key_Up)
        self.assertTrue(self.item('accountConnectButton').hasActiveFocus())
        self.assertInView(self.item('accountConnectButton'))
        tab.setParentItem(None)
        tab.deleteLater()
