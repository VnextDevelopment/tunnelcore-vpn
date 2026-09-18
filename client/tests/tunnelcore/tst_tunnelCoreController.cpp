#include "../../ui/controllers/tunnelCoreController.h"

#include <QNetworkReply>
#include <QQueue>
#include <QSignalSpy>
#include <QTest>
#include <QTimer>
#include <QJsonDocument>
#include <cstring>

class Reply : public QNetworkReply
{
public:
    Reply(const QNetworkRequest &request, QByteArray body, int status, QObject *parent)
        : QNetworkReply(parent), m_body(body)
    {
        setRequest(request);
        setUrl(request.url());
        setAttribute(QNetworkRequest::HttpStatusCodeAttribute, status);
        open(QIODevice::ReadOnly);
        QTimer::singleShot(0, this, [this]() {
            if (isFinished())
                return;
            setFinished(true);
            emit readyRead();
            emit finished();
        });
    }
    void abort() override
    {
        setError(OperationCanceledError, "cancelled");
        setFinished(true);
        emit finished();
    }
    qint64 bytesAvailable() const override { return m_body.size() + QNetworkReply::bytesAvailable(); }
protected:
    qint64 readData(char *data, qint64 maxSize) override
    {
        const auto size = qMin(maxSize, qint64(m_body.size()));
        if (!size)
            return -1;
        memcpy(data, m_body.constData(), size_t(size));
        m_body.remove(0, size);
        return size;
    }
private:
    QByteArray m_body;
};

class Network : public QNetworkAccessManager
{
public:
    struct Response { QByteArray body; int status = 200; };
    QQueue<Response> responses;
    QList<QNetworkRequest> requests;
    QList<QByteArray> bodies;
protected:
    QNetworkReply *createRequest(Operation, const QNetworkRequest &request, QIODevice *data) override
    {
        requests.append(request);
        bodies.append(data ? data->readAll() : QByteArray());
        const auto response = responses.isEmpty() ? Response {"{}", 500} : responses.dequeue();
        return new Reply(request, response.body, response.status, this);
    }
};


class TunnelCoreTests : public QObject
{
    Q_OBJECT
    static void enqueueLogin(Network &network)
    {
        network.responses.enqueue({"{\"ok\":true,\"access_token\":\"test-token\",\"token_type\":\"Bearer\",\"user\":{\"username\":\"client\"}}"});
        network.responses.enqueue({"{\"ok\":true,\"subscriptions\":[{\"id\":1,\"tariff\":\"VPN\"}]}"});
        network.responses.enqueue({"{\"ok\":true,\"configs\":[{\"name\":\"VPN\",\"config\":\"https://node.example/config/one-time\"}]}"});
    }
private slots:
    void codeLogin()
    {
        Network network;
        enqueueLogin(network);
        TunnelCoreController controller(nullptr, &network);
        QSignalSpy signedIn(&controller, &TunnelCoreController::signedIn);
        controller.loginCode(" 012345 ");
        QTRY_VERIFY(!controller.busy());
        QVERIFY(controller.authenticated());
        QCOMPARE(signedIn.size(), 1);
        QCOMPARE(network.requests.size(), 3);
        QCOMPARE(network.requests[0].url().path(), QString("/api/vpn/v1/auth/code/exchange/"));
        const auto body = QJsonDocument::fromJson(network.bodies[0]).object();
        QCOMPARE(body.value("code").toString(), QString("012345"));
        QCOMPARE(body.size(), 1);
        QVERIFY(!network.requests[0].hasRawHeader("Authorization"));
    }
    void codeLoginRequiresSixDigits()
    {
        Network network;
        TunnelCoreController controller(nullptr, &network);
        controller.loginCode("12345");
        QVERIFY(!controller.error().isEmpty());
        controller.loginCode("12345a");
        QVERIFY(!controller.error().isEmpty());
        QVERIFY(network.requests.isEmpty());
        QVERIFY(!controller.busy());
    }
    void emailLogin()
    {
        Network network;
        enqueueLogin(network);
        TunnelCoreController controller(nullptr, &network);
        QSignalSpy signedIn(&controller, &TunnelCoreController::signedIn);
        controller.loginEmail(" User@Example.COM ", " password ");
        // Repeated submissions while the request is running must not create another login.
        controller.loginEmail("other@example.com", "other-password");
        QTRY_VERIFY(!controller.busy());
        QVERIFY(controller.authenticated());
        QCOMPARE(signedIn.size(), 1);
        QCOMPARE(network.requests.size(), 3);
        QCOMPARE(network.requests[0].url().path(), QString("/api/vpn/v1/auth/login/"));
        const auto body = QJsonDocument::fromJson(network.bodies[0]).object();
        QCOMPARE(body.value("email").toString(), QString("user@example.com"));
        QCOMPARE(body.value("password").toString(), QString(" password "));
        QVERIFY(!body.contains("username"));
        QVERIFY(!network.requests[0].hasRawHeader("Authorization"));
        QCOMPARE(network.requests[1].rawHeader("Authorization"), QByteArray("Bearer test-token"));
        QCOMPARE(controller.configs().size(), 1);
    }
    void emailLoginErrors_data()
    {
        QTest::addColumn<int>("status");
        QTest::addColumn<QByteArray>("body");
        QTest::newRow("invalid-email") << 400 << QByteArray("{\"ok\":false,\"error\":\"email_and_password_required\"}");
        QTest::newRow("old-api") << 400 << QByteArray("{\"ok\":false,\"error\":\"username_and_password_required\"}");
        QTest::newRow("wrong-password") << 401 << QByteArray("{\"ok\":false,\"error\":\"invalid_credentials\"}");
    }
    void emailLoginErrors()
    {
        QFETCH(int, status);
        QFETCH(QByteArray, body);
        Network network;
        network.responses.enqueue({body, status});
        TunnelCoreController controller(nullptr, &network);
        QSignalSpy signedIn(&controller, &TunnelCoreController::signedIn);
        controller.loginEmail("invalid-address", "wrong-password");
        QTRY_VERIFY(!controller.busy());
        QVERIFY(!controller.authenticated());
        QCOMPARE(signedIn.size(), 0);
        QVERIFY(!controller.error().isEmpty());
        QCOMPARE(network.requests.size(), 1);
        controller.clearError();
        QVERIFY(controller.error().isEmpty());
    }
    void emailLoginRequiresFields()
    {
        Network network;
        TunnelCoreController controller(nullptr, &network);
        controller.loginEmail("   ", "password");
        QVERIFY(!controller.error().isEmpty());
        controller.loginEmail("user@example.com", "");
        QVERIFY(!controller.error().isEmpty());
        QVERIFY(network.requests.isEmpty());
        QVERIFY(!controller.busy());
    }
    void loginAndDownload()
    {
        Network network;
        enqueueLogin(network);
        TunnelCoreController controller(nullptr, &network);
        controller.login(" client ", " password ");
        QTRY_VERIFY(!controller.busy());
        QVERIFY(controller.authenticated());
        QCOMPARE(controller.subscriptions().size(), 1);
        QCOMPARE(controller.configs().size(), 1);
        QCOMPARE(network.requests[0].url().path(), QString("/api/vpn/v1/auth/login/"));
        const auto body = QJsonDocument::fromJson(network.bodies[0]).object();
        QCOMPARE(body.value("username").toString(), QString("client"));
        QCOMPARE(body.value("password").toString(), QString(" password "));
        QVERIFY(!network.requests[0].hasRawHeader("Authorization"));
        QCOMPARE(network.requests[1].rawHeader("Authorization"), QByteArray("Bearer test-token"));
        network.responses.enqueue({"[Interface]\nPrivateKey = example"});
        QSignalSpy config(&controller, &TunnelCoreController::configReady);
        controller.selectConfig(0);
        QTRY_COMPARE(config.size(), 1);
        QVERIFY(!network.requests.last().hasRawHeader("Authorization"));
        QCOMPARE(network.requests.last().attribute(QNetworkRequest::RedirectPolicyAttribute).toInt(),
                 int(QNetworkRequest::ManualRedirectPolicy));
    }
    void wrongPassword()
    {
        Network network;
        network.responses.enqueue({"{\"ok\":false,\"error\":\"invalid_credentials\"}", 401});
        TunnelCoreController controller(nullptr, &network);
        controller.login("client", "wrong");
        QTRY_VERIFY(!controller.busy());
        QVERIFY(!controller.authenticated());
        QVERIFY(!controller.error().isEmpty());
        QCOMPARE(network.requests.size(), 1);
    }
    void expiredSession()
    {
        Network network;
        enqueueLogin(network);
        TunnelCoreController controller(nullptr, &network);
        controller.login("client", "password");
        QTRY_VERIFY(!controller.busy());
        network.responses.enqueue({"{\"ok\":false,\"error\":\"unauthorized\"}", 401});
        controller.refresh();
        QTRY_VERIFY(!controller.busy());
        QVERIFY(!controller.authenticated());
        QVERIFY(controller.configs().isEmpty());
        QVERIFY(!controller.error().isEmpty());
    }
    void logoutCancelsLogin()
    {
        Network network;
        enqueueLogin(network);
        TunnelCoreController controller(nullptr, &network);
        QSignalSpy signedIn(&controller, &TunnelCoreController::signedIn);
        controller.login("client", "password");
        controller.logout();
        QTest::qWait(10);
        QVERIFY(!controller.authenticated());
        QVERIFY(!controller.busy());
        QCOMPARE(signedIn.size(), 0);
    }
    void malformedResponse()
    {
        Network network;
        network.responses.enqueue({"<html>error</html>"});
        TunnelCoreController controller(nullptr, &network);
        controller.login("client", "password");
        QTRY_VERIFY(!controller.busy());
        QVERIFY(!controller.authenticated());
        QVERIFY(!controller.error().isEmpty());
    }
};

QTEST_GUILESS_MAIN(TunnelCoreTests)
#include "tst_tunnelCoreController.moc"
