"""Run with QT_QPA_PLATFORM=offscreen python -m unittest discover -s tests/qml.

Requires PySide6. Loads the production auth layout and input/button controls;
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
from PySide6.QtQml import QQmlComponent, QQmlEngine
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
Button { property string image; property string imageColor }
''')
        colors = set()
        for file in (cls.path / 'Controls2').rglob('*.qml'):
            colors.update(re.findall(r'AmneziaStyle.color.(\w+)', file.read_text()))
        source = (QML / 'Pages2/PageTunnelCoreAccount.qml').read_text()
        colors.update(re.findall(r'AmneziaStyle.color.(\w+)', source))
        style = cls.path / 'Style'
        style.mkdir()
        (style / 'qmldir').write_text('module Style\nsingleton AmneziaStyle 1.0 AmneziaStyle.qml\n')
        (style / 'AmneziaStyle.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property QtObject color: QtObject {' + '\n'.join(
            f'property color {c}: "#336699"' for c in colors) + '} }')
        # Isolate the actual auth subtree, leaving its functions and handlers intact.
        source = source.split('            ColumnLayout {\n                Layout.fillWidth: true\n                visible: TunnelCoreController.authenticated', 1)[0] + '\n        }\n    }\n}\n'
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
signal signedIn(); signal configReady(var data, string fileName, int obfuscationMode, string obfuscationProfile)
signal changed()
function clearError() {} function loginCode(code) { submits++ }
function loginEmail(email, password) { submits++ }
function registerEmail(email, password) { submits++ }''',
            'PageController': 'property int imeHeight: 0; property int safeAreaTopMargin: 0; property int safeAreaBottomMargin: 0',
            'ConnectionController': 'property bool isConnected: false; property bool isConnectionInProgress: false; signal connectionStateChanged()',
            'ImportController': 'signal importFinished(); signal importErrorOccurred(string error, bool goToPageHome)',
            'LanguageUiController': 'function getLineHeightAppend() { return 0 }',
            'FocusController': 'function resetRootObject() {} function setFocusOnDefaultItem() {}',
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
