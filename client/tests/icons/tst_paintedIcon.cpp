#include "../../ui/utils/paintedIcon.h"
#include "../../ui/utils/pageEnum.h"
#include <QPainter>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QTest>
#include <QFile>
#include <QJSEngine>

class IconTests : public QObject
{
    Q_OBJECT
private slots:
    void accountConnectionFlow()
    {
        QFile file(QString(CLIENT_DIR) + "/ui/qml/Pages2/PageTunnelCoreAccount.qml");
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QString source = QString::fromUtf8(file.readAll());
        QJSEngine engine;
        auto evaluate = [&](const QString &script) {
            const auto result = engine.evaluate(script);
            if (result.isError())
                qWarning() << result.toString();
            return result;
        };
        evaluate(R"(
            var pendingVpnCountry = '', importingProfile = false, connectAfterImport = false;
            var connects = 0, downloads = 0, closes = 0, selected = '';
            var ConnectionController = {
                isConnected: false, isConnectionInProgress: false,
                connectButtonClicked: function() { ++connects; },
                closeConnection: function() { ++closes; }
            };
            var TunnelCoreController = {
                busy: false, vpnCountryMode: 'country', selectedVpnCountry: 'DE',
                selectedProfileKey: 'account-DE',
                selectCurrentConfig: function() { ++downloads; },
                selectVpnCountry: function(code) { selected = code; }
            };
            var available = true;
            var ImportController = { activateTunnelCoreProfile: function(key) {
                return available && key === 'account-DE';
            }};
        )");
        // Execute the actual page functions, not copies of their implementation.
        for (const QString name : {QString("selectVpnCountry"), QString("connectSelectedLocation")}) {
            const auto start = source.indexOf("function " + name + "(");
            QVERIFY(start >= 0);
            auto end = source.indexOf('{', start);
            int depth = 1;
            while (depth && ++end < source.size()) {
                if (source[end] == '{') ++depth;
                if (source[end] == '}') --depth;
            }
            QVERIFY(!evaluate(source.mid(start, end - start + 1)).isError());
        }
        evaluate("connectSelectedLocation()");
        QCOMPARE(evaluate("connects").toInt(), 1);
        QCOMPARE(evaluate("downloads").toInt(), 0);
        evaluate("available = false; connectSelectedLocation()");
        QCOMPARE(evaluate("connects").toInt(), 1);
        QCOMPARE(evaluate("downloads").toInt(), 1);
        QVERIFY(evaluate("connectAfterImport").toBool());
        evaluate("TunnelCoreController.busy = true; connectSelectedLocation()");
        QCOMPARE(evaluate("downloads").toInt(), 1);
        evaluate("TunnelCoreController.busy = false; selectVpnCountry('FR')");
        QCOMPARE(evaluate("selected").toString(), QString("FR"));
        QCOMPARE(evaluate("connects").toInt(), 1); // Selection never connects.
        evaluate("ConnectionController.isConnected = true; selectVpnCountry('DE')");
        QCOMPARE(evaluate("closes").toInt(), 0); // Same country stays connected.
        evaluate("selectVpnCountry('NL')");
        QCOMPARE(evaluate("closes").toInt(), 1);
        QCOMPARE(evaluate("pendingVpnCountry").toString(), QString("NL"));
        QCOMPARE(evaluate("selected").toString(), QString("FR")); // Wait for disconnect.
    }
    void alphaAndTint_data()
    {
        QTest::addColumn<QString>("name");
        QTest::addColumn<int>("pixels");
        for (const auto &name : {"home", "settings", "chevron-down", "check"})
            for (int size : {24, 72})
                QTest::newRow(qPrintable(QString("%1-%2").arg(name).arg(size))) << QString(name) << size;
    }
    void alphaAndTint()
    {
        QFETCH(QString, name);
        QFETCH(int, pixels);
        PaintedIcon icon;
        icon.setSource(QUrl("qrc:/images/controls/" + name + ".svg"));
        icon.setWidth(pixels);
        icon.setHeight(pixels);
        icon.setTint("#ff8800");
        QImage image(pixels, pixels, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter painter(&image);
        icon.paint(&painter);
        painter.end();
        int transparent = 0, foreground = 0;
        for (int y = 0; y < pixels; ++y)
            for (int x = 0; x < pixels; ++x) {
                const auto c = image.pixelColor(x, y);
                transparent += c.alpha() == 0;
                if (c.alpha() > 240) {
                    ++foreground;
                    QCOMPARE(c.red(), 255);
                    QVERIFY(qAbs(c.green() - 136) <= 1);
                    QCOMPARE(c.blue(), 0);
                }
            }
        QVERIFY(transparent > pixels * pixels / 3);
        QVERIFY(foreground > 0);
        QCOMPARE(image.pixelColor(0, 0).alpha(), 0);
    }
    void controlsLoad()
    {
        qmlRegisterType<PaintedIcon>("AppIcons", 1, 0, "PaintedIcon");
        QQmlEngine engine;
        engine.addImportPath(QString(CLIENT_DIR) + "/ui/qml/Modules");
        for (const auto &name : {"ImageButtonType", "TabImageButtonType", "BasicButtonType",
                                 "CheckBoxType", "LabelWithButtonType", "WarningType",
                                 "CardWithIconsType", "CaptchaDialogType"}) {
            QQmlComponent component(&engine, QUrl::fromLocalFile(
                QString(CLIENT_DIR) + "/ui/qml/Controls2/" + name + ".qml"));
            QScopedPointer<QObject> object(component.create());
            QVERIFY2(object, qPrintable(component.errorString()));
        }
    }
    void accountPageLoads()
    {
        qmlRegisterType<PaintedIcon>("AppIcons", 1, 0, "PaintedIcon");
        qmlRegisterUncreatableMetaObject(PageLoader::staticMetaObject, "PageEnum", 1, 0, "PageEnum", "Enum");
        qmlRegisterUncreatableType<QObject>("ConnectionState", 1, 0, "ConnectionState", "Test stub");
        QQmlEngine engine;
        engine.addImportPath(QString(CLIENT_DIR) + "/ui/qml/Modules");
        QQmlComponent component(&engine, QUrl::fromLocalFile(
            QString(CLIENT_DIR) + "/ui/qml/Pages2/PageTunnelCoreAccount.qml"));
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        QVERIFY(object->findChild<QObject *>("accountConnectButton"));
        QVERIFY(object->findChild<QObject *>("accountSplitTunnelingButton"));
    }
};
QTEST_MAIN(IconTests)
#include "tst_paintedIcon.moc"
