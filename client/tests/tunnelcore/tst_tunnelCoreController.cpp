#include "../../ui/controllers/tunnelCoreController.h"

#include <QNetworkReply>
#include <QQueue>
#include <QSignalSpy>
#include <QTest>
#include <QTimer>
#include <QJsonArray>
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
    static QByteArray countrySelectionResponse()
    {
        return "{\"ok\":true,\"selection\":{\"mode\":\"auto\",\"country\":null,"
               "\"effective_country\":\"DE\",\"config_id\":17,"
               "\"countries\":[{\"code\":\"DE\",\"cities\":[\"Frankfurt\"]},"
               "{\"code\":\"NL\",\"cities\":[\"Amsterdam\"]}]}}";
    }

    static QByteArray geoCountriesResponse()
    {
        return "{\"ok\":true,\"countries\":[\"RU\",\"TR\"],"
               "\"mode\":\"country_direct\",\"default_route\":\"vpn\","
               "\"country_route\":\"direct\"}";
    }

    static QByteArray routingResponse()
    {
        return "{\"ok\":true,\"version\":\"test-routing-v1\",\"platform\":\"all\","
               "\"rules\":[{\"type\":\"domain\",\"value\":\"example.direct\","
               "\"route\":\"direct\",\"priority\":10}],"
               "\"domains\":{\"vpn\":[],\"direct\":[\"example.direct\"]},"
               "\"ip_ranges\":{\"vpn\":[],\"direct\":[]}}";
    }

    static void enqueueLogin(Network &network)
    {
        network.responses.enqueue({"{\"ok\":true,\"access_token\":\"test-token\",\"token_type\":\"Bearer\",\"user\":{\"username\":\"client\"}}"});
        network.responses.enqueue({"{\"ok\":true,\"subscriptions\":[{\"id\":1,\"tariff\":\"VPN\"}]}"});
        network.responses.enqueue({countrySelectionResponse()});
        network.responses.enqueue({geoCountriesResponse()});
        network.responses.enqueue({routingResponse()});
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
        QCOMPARE(network.requests.size(), 6);
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
        QCOMPARE(network.requests.size(), 6);
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
    void emailRegistration()
    {
        Network network;
        network.responses.enqueue({"{\"ok\":true,\"access_token\":\"registered-token\",\"token_type\":\"Bearer\",\"user\":{\"username\":\"client-generated\",\"email\":\"user@example.com\"}}", 201});
        network.responses.enqueue({"{\"ok\":true,\"subscriptions\":[]}"});
        network.responses.enqueue({countrySelectionResponse()});
        network.responses.enqueue({geoCountriesResponse()});
        network.responses.enqueue({routingResponse()});
        network.responses.enqueue({"{\"ok\":true,\"configs\":[]}"});
        TunnelCoreController controller(nullptr, &network);

        controller.registerEmail(" User@Example.COM ", "Strong-pass-2026!");

        QTRY_VERIFY(!controller.busy());
        QVERIFY(controller.authenticated());
        QVERIFY(controller.emailAccount());
        QVERIFY(!controller.telegramLinked());
        QCOMPARE(controller.username(), QString("user@example.com"));
        QCOMPARE(network.requests.first().url().path(), QString("/api/vpn/v1/auth/register/"));
        const auto body = QJsonDocument::fromJson(network.bodies.first()).object();
        QCOMPARE(body.value("email").toString(), QString("user@example.com"));
        QCOMPARE(body.value("password").toString(), QString("Strong-pass-2026!"));
        QVERIFY(!network.requests.first().hasRawHeader("Authorization"));
    }
    void duplicateEmailRegistrationShowsError()
    {
        Network network;
        network.responses.enqueue({"{\"ok\":false,\"error\":\"email_already_registered\"}", 409});
        TunnelCoreController controller(nullptr, &network);

        controller.registerEmail("user@example.com", "Strong-pass-2026!");

        QTRY_VERIFY(!controller.busy());
        QVERIFY(!controller.authenticated());
        QVERIFY(!controller.error().isEmpty());
        QCOMPARE(network.requests.size(), 1);
    }
    void emailAccountCanLinkTelegram()
    {
        Network network;
        enqueueLogin(network);
        TunnelCoreController controller(nullptr, &network);
        controller.loginEmail("user@example.com", "Strong-pass-2026!");
        QTRY_VERIFY(!controller.busy());

        network.responses.enqueue({"{\"ok\":true,\"telegram_id\":777001,\"user\":{\"username\":\"client\",\"email\":\"user@example.com\"}}"});
        network.responses.enqueue({"{\"ok\":true,\"subscriptions\":[]}"});
        network.responses.enqueue({countrySelectionResponse()});
        network.responses.enqueue({geoCountriesResponse()});
        network.responses.enqueue({routingResponse()});
        network.responses.enqueue({"{\"ok\":true,\"configs\":[]}"});
        controller.linkTelegram(" 012345 ");

        QTRY_VERIFY(!controller.busy());
        QVERIFY(controller.telegramLinked());
        QCOMPARE(network.requests[6].url().path(), QString("/api/vpn/v1/auth/telegram/link/"));
        QCOMPARE(network.requests[6].rawHeader("Authorization"), QByteArray("Bearer test-token"));
        const auto body = QJsonDocument::fromJson(network.bodies[6]).object();
        QCOMPARE(body.value("code").toString(), QString("012345"));
    }
    void expiredTelegramCodeKeepsSession()
    {
        Network network;
        enqueueLogin(network);
        TunnelCoreController controller(nullptr, &network);
        controller.loginEmail("user@example.com", "Strong-pass-2026!");
        QTRY_VERIFY(!controller.busy());

        network.responses.enqueue({"{\"ok\":false,\"error\":\"invalid_or_expired_code\"}", 401});
        controller.linkTelegram("012345");

        QTRY_VERIFY(!controller.busy());
        QVERIFY(controller.authenticated());
        QVERIFY(!controller.telegramLinked());
        QVERIFY(!controller.error().isEmpty());
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
        QCOMPARE(config.first().at(1).toString(), QString("VPN"));
        QCOMPARE(network.requests.last().attribute(QNetworkRequest::RedirectPolicyAttribute).toInt(),
                 int(QNetworkRequest::ManualRedirectPolicy));
    }
    void metadataConfigIsFetchedById()
    {
        Network network;
        network.responses.enqueue({"{\"ok\":true,\"access_token\":\"test-token\",\"token_type\":\"Bearer\",\"user\":{\"username\":\"client\"}}"});
        network.responses.enqueue({"{\"ok\":true,\"subscriptions\":[{\"id\":1,\"tariff\":\"VPN\"}]}"});
        network.responses.enqueue({countrySelectionResponse()});
        network.responses.enqueue({geoCountriesResponse()});
        network.responses.enqueue({routingResponse()});
        network.responses.enqueue({"{\"ok\":true,\"configs\":[{\"id\":17,\"name\":\"Germany\",\"protocol\":\"amneziawg\"}]}"});
        network.responses.enqueue({"{\"ok\":true,\"id\":17,\"name\":\"tc42-d1\",\"filename\":\"tc42-d1.conf\",\"protocol\":\"amneziawg\",\"config\":\"[Interface]\\nPrivateKey = app-secret\"}"});
        TunnelCoreController controller(nullptr, &network);
        controller.loginCode("012345");
        QTRY_VERIFY(!controller.busy());

        QSignalSpy config(&controller, &TunnelCoreController::configReady);
        controller.selectConfig(0);

        QTRY_COMPARE(config.size(), 1);
        QCOMPARE(network.requests.size(), 7);
        QCOMPARE(network.requests.last().url().path(), QString("/api/vpn/v1/configs/17/"));
        QCOMPARE(network.requests.last().rawHeader("Authorization"), QByteArray("Bearer test-token"));
        QCOMPARE(config.first().first().toString(), QString("[Interface]\nPrivateKey = app-secret"));
        QCOMPARE(config.first().at(1).toString(), QString("tc42-d1.conf"));
    }
    void metadataConfigDownloadErrorIsShown()
    {
        Network network;
        network.responses.enqueue({"{\"ok\":true,\"access_token\":\"test-token\",\"token_type\":\"Bearer\",\"user\":{\"username\":\"client\"}}"});
        network.responses.enqueue({"{\"ok\":true,\"subscriptions\":[]}"});
        network.responses.enqueue({countrySelectionResponse()});
        network.responses.enqueue({geoCountriesResponse()});
        network.responses.enqueue({routingResponse()});
        network.responses.enqueue({"{\"ok\":true,\"configs\":[{\"id\":17,\"name\":\"Germany\"}]}"});
        network.responses.enqueue({"{\"ok\":false,\"error\":\"config_not_found\"}", 404});
        TunnelCoreController controller(nullptr, &network);
        controller.loginCode("012345");
        QTRY_VERIFY(!controller.busy());

        QSignalSpy config(&controller, &TunnelCoreController::configReady);
        controller.selectConfig(0);

        QTRY_VERIFY(!controller.busy());
        QCOMPARE(config.size(), 0);
        QVERIFY(!controller.error().isEmpty());
    }
    void sessionIsRestoredAndValidated()
    {
        Network network;
        network.responses.enqueue({"{\"ok\":true,\"subscriptions\":[{\"id\":1,\"tariff\":\"VPN\"}]}"});
        network.responses.enqueue({countrySelectionResponse()});
        network.responses.enqueue({geoCountriesResponse()});
        network.responses.enqueue({routingResponse()});
        network.responses.enqueue({"{\"ok\":true,\"configs\":[]}"});
        bool cleared = false;
        TunnelCoreSessionStorage storage;
        storage.load = []() {
            return std::make_tuple(QByteArray("stored-token"), QString("stored-user"), true, true);
        };
        storage.clear = [&cleared]() { cleared = true; };

        TunnelCoreController controller(nullptr, &network, std::move(storage));

        QTRY_VERIFY(!controller.busy());
        QVERIFY(controller.authenticated());
        QCOMPARE(controller.username(), QString("stored-user"));
        QVERIFY(controller.emailAccount());
        QVERIFY(controller.telegramLinked());
        QCOMPARE(network.requests.size(), 5);
        QCOMPARE(network.requests.first().url().path(), QString("/api/vpn/v1/me/"));
        QCOMPARE(network.requests.first().rawHeader("Authorization"), QByteArray("Bearer stored-token"));
        QVERIFY(!cleared);
    }
    void invalidRestoredSessionIsCleared()
    {
        Network network;
        network.responses.enqueue({"{\"ok\":false,\"error\":\"unauthorized\"}", 401});
        bool cleared = false;
        TunnelCoreSessionStorage storage;
        storage.load = []() {
            return std::make_tuple(QByteArray("expired-token"), QString("stored-user"), false, false);
        };
        storage.clear = [&cleared]() { cleared = true; };

        TunnelCoreController controller(nullptr, &network, std::move(storage));

        QTRY_VERIFY(!controller.busy());
        QVERIFY(!controller.authenticated());
        QVERIFY(cleared);
        QVERIFY(!controller.error().isEmpty());
    }
    void successfulLoginIsPersisted()
    {
        Network network;
        enqueueLogin(network);
        QByteArray storedToken;
        QString storedUsername;
        TunnelCoreSessionStorage storage;
        storage.save = [&storedToken, &storedUsername](const QByteArray &token, const QString &username,
                                                       bool, bool) {
            storedToken = token;
            storedUsername = username;
        };

        TunnelCoreController controller(nullptr, &network, std::move(storage));
        controller.loginCode("012345");

        QTRY_VERIFY(!controller.busy());
        QCOMPARE(storedToken, QByteArray("test-token"));
        QCOMPARE(storedUsername, QString("client"));
    }
    void routingRulesAreFetchedAndApplied()
    {
        Network network;
        enqueueLogin(network);
        bool applied = false;
        TunnelCoreSessionStorage storage;
        storage.applyRouting = [&applied](const QJsonObject &routing, QString &) {
            applied = routing.value("version").toString() == "test-routing-v1"
                      && routing.value("rules").isArray();
            return applied;
        };

        TunnelCoreController controller(nullptr, &network, std::move(storage));
        controller.loginCode("012345");
        QTRY_VERIFY(!controller.busy());

        QVERIFY(applied);
        QCOMPARE(network.requests[4].url().path(), QString("/api/vpn/v1/routing/"));
        QVERIFY(!network.requests[4].url().query().isEmpty());
        QCOMPARE(network.requests[4].rawHeader("Authorization"), QByteArray("Bearer test-token"));
    }

    void selectGeoRoutingCountry()
    {
        Network network;
        enqueueLogin(network);
        QJsonObject appliedRouting;
        QString savedCountry;
        TunnelCoreSessionStorage storage;
        storage.applyRouting = [&appliedRouting](const QJsonObject &routing, QString &) {
            appliedRouting = routing;
            return true;
        };
        storage.saveGeoRoutingCountry = [&savedCountry](const QString &country) {
            savedCountry = country;
        };

        TunnelCoreController controller(nullptr, &network, std::move(storage));
        controller.loginCode("012345");
        QTRY_VERIFY(!controller.busy());

        QCOMPARE(controller.geoRoutingCountries().size(), 2);
        QVERIFY(controller.geoRoutingCountry().isEmpty());

        network.responses.enqueue({"{\"ok\":true,\"country\":\"RU\","
                                   "\"mode\":\"country_direct\",\"default_route\":\"vpn\","
                                   "\"country_route\":\"direct\",\"version\":\"ru-v1\","
                                   "\"ipv4\":[\"5.136.0.0/13\",\"31.173.0.0/16\"],"
                                   "\"ipv6\":[\"2a00:1fa0::/32\"],\"source\":\"test\"}"});
        network.responses.enqueue({"{\"ok\":true,\"configs\":[]}"});

        controller.selectGeoRoutingCountry("ru");
        QTRY_VERIFY(!controller.busy());

        QCOMPARE(controller.geoRoutingCountry(), QString("RU"));
        QCOMPARE(savedCountry, QString("RU"));
        QCOMPARE(network.requests[6].url().path(), QString("/api/vpn/v1/routing/countries/RU/"));
        QCOMPARE(network.requests[6].rawHeader("Authorization"), QByteArray("Bearer test-token"));
        QCOMPARE(appliedRouting.value("rules").toArray().size(), 2);
        QCOMPARE(appliedRouting.value("rules").toArray().first().toObject().value("route").toString(),
                 QString("direct"));
        QCOMPARE(network.requests[7].url().path(), QString("/api/vpn/v1/configs/"));
    }

    void selectVpnCountry()
    {
        Network network;
        enqueueLogin(network);
        TunnelCoreController controller(nullptr, &network);
        controller.loginCode("012345");
        QTRY_VERIFY(!controller.busy());

        QCOMPARE(controller.vpnCountryMode(), QString("auto"));
        QCOMPARE(controller.effectiveVpnCountry(), QString("DE"));
        QCOMPARE(controller.vpnCountries().size(), 2);

        network.responses.enqueue({"{\"ok\":true,\"selection\":{\"mode\":\"country\",\"country\":\"NL\","
                                   "\"effective_country\":\"NL\",\"config_id\":18,"
                                   "\"countries\":[{\"code\":\"DE\",\"cities\":[\"Frankfurt\"]},"
                                   "{\"code\":\"NL\",\"cities\":[\"Amsterdam\"]}]},"
                                   "\"migration\":{\"migrated\":1,\"unchanged\":0,\"warnings\":[]}}"});
        network.responses.enqueue({routingResponse()});
        network.responses.enqueue({"{\"ok\":true,\"configs\":[{\"id\":18,\"name\":\"Netherlands\",\"protocol\":\"amneziawg\"}]}"});
        network.responses.enqueue({"{\"ok\":true,\"id\":18,\"name\":\"Netherlands\","
                                   "\"filename\":\"netherlands.conf\",\"protocol\":\"amneziawg\","
                                   "\"config\":\"[Interface]\\nPrivateKey = netherlands-secret\"}"});

        QSignalSpy config(&controller, &TunnelCoreController::configReady);
        controller.selectVpnCountry("nl");
        QTRY_COMPARE(config.size(), 1);

        QCOMPARE(controller.vpnCountryMode(), QString("country"));
        QCOMPARE(controller.selectedVpnCountry(), QString("NL"));
        QCOMPARE(controller.effectiveVpnCountry(), QString("NL"));
        QCOMPARE(controller.configs().size(), 1);
        QCOMPARE(network.requests[6].url().path(), QString("/api/vpn/v1/country-selection/"));
        QCOMPARE(network.requests[6].rawHeader("Authorization"), QByteArray("Bearer test-token"));
        const auto body = QJsonDocument::fromJson(network.bodies[6]).object();
        QCOMPARE(body.value("mode").toString(), QString("country"));
        QCOMPARE(body.value("country").toString(), QString("NL"));
        QCOMPARE(network.requests[8].url().path(), QString("/api/vpn/v1/configs/"));
        QCOMPARE(network.requests[9].url().path(), QString("/api/vpn/v1/configs/18/"));
        QCOMPARE(config.first().first().toString(),
                 QString("[Interface]\nPrivateKey = netherlands-secret"));
        QCOMPARE(config.first().at(1).toString(), QString("netherlands.conf"));
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
