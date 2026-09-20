#pragma once

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QPair>
#include <QVariantList>
#include <functional>
#include <tuple>
#include <utility>

class QNetworkReply;

struct TunnelCoreSessionStorage
{
    std::function<std::tuple<QByteArray, QString, bool, bool>()> load;
    std::function<void(const QByteArray &, const QString &, bool, bool)> save;
    std::function<void()> clear;
    std::function<bool(const QJsonObject &, QString &)> applyRouting;
    std::function<QString()> loadGeoRoutingCountry;
    std::function<void(const QString &)> saveGeoRoutingCountry;
};

class TunnelCoreController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString username READ username NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(bool emailAccount READ emailAccount NOTIFY changed)
    Q_PROPERTY(bool telegramLinked READ telegramLinked NOTIFY changed)
    Q_PROPERTY(QVariantList subscriptions READ subscriptions NOTIFY changed)
    Q_PROPERTY(QVariantList configs READ configs NOTIFY changed)
    Q_PROPERTY(QVariantList vpnCountries READ vpnCountries NOTIFY changed)
    Q_PROPERTY(QString vpnCountryMode READ vpnCountryMode NOTIFY changed)
    Q_PROPERTY(QString selectedVpnCountry READ selectedVpnCountry NOTIFY changed)
    Q_PROPERTY(QString effectiveVpnCountry READ effectiveVpnCountry NOTIFY changed)
    Q_PROPERTY(QVariantList geoRoutingCountries READ geoRoutingCountries NOTIFY changed)
    Q_PROPERTY(QString geoRoutingCountry READ geoRoutingCountry NOTIFY changed)

public:
    explicit TunnelCoreController(QObject *parent = nullptr, QNetworkAccessManager *network = nullptr,
                                  TunnelCoreSessionStorage sessionStorage = {});
    bool authenticated() const { return !m_token.isEmpty(); }
    bool busy() const { return m_busy; }
    QString username() const { return m_username; }
    QString error() const { return m_error; }
    bool emailAccount() const { return m_emailAccount; }
    bool telegramLinked() const { return m_telegramLinked; }
    QVariantList subscriptions() const { return m_subscriptions; }
    QVariantList configs() const { return m_configs; }
    QVariantList vpnCountries() const { return m_vpnCountries; }
    QString vpnCountryMode() const { return m_vpnCountryMode; }
    QString selectedVpnCountry() const { return m_selectedVpnCountry; }
    QString effectiveVpnCountry() const { return m_effectiveVpnCountry; }
    QVariantList geoRoutingCountries() const { return m_geoRoutingCountries; }
    QString geoRoutingCountry() const { return m_geoRoutingCountry; }

    Q_INVOKABLE void loginCode(const QString &code);
    // Legacy login methods remain available during the server transition, but the
    // TunnelCore UI uses one-time Telegram codes.
    Q_INVOKABLE void login(const QString &username, const QString &password);
    Q_INVOKABLE void loginEmail(const QString &email, const QString &password);
    Q_INVOKABLE void registerEmail(const QString &email, const QString &password);
    Q_INVOKABLE void linkTelegram(const QString &code);
    Q_INVOKABLE void clearError();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void selectConfig(int index);
    Q_INVOKABLE void selectVpnCountry(const QString &countryCode);
    Q_INVOKABLE QString vpnCountryDisplayName(const QString &countryCode) const;
    Q_INVOKABLE void selectGeoRoutingCountry(const QString &countryCode);

signals:
    void changed();
    void signedIn();
    void configReady(const QString &data, const QString &fileName);

private:
    void authenticate(const QString &path, const QJsonObject &credentials, bool emailAccount = false);
    void request(const QString &path, const QJsonObject &body,
                 std::function<void(const QJsonObject &)> success, bool post = false,
                 std::function<void(int, const QJsonObject &)> failure = {},
                 bool authenticatedRequest = false);
    void saveSession();
    bool applyVpnCountrySelection(const QJsonObject &object);
    void refreshConfigs();
    void refreshRouting();
    void refreshGeoRoutingCountries();
    QString routingPlatform() const;
    void deliverConfig(const QString &data, const QString &fileName = {});
    void fail(const QString &message);
    QNetworkAccessManager *m_network;
    QPointer<QNetworkReply> m_reply;
    QByteArray m_token;
    QString m_username;
    QString m_error;
    QVariantList m_subscriptions;
    QVariantList m_configs;
    QVariantList m_vpnCountries;
    QString m_vpnCountryMode = QStringLiteral("auto");
    QString m_selectedVpnCountry;
    QString m_effectiveVpnCountry;
    qint64 m_pendingConfigId = 0;
    QVariantList m_geoRoutingCountries;
    QString m_geoRoutingCountry;
    TunnelCoreSessionStorage m_sessionStorage;
    bool m_busy = false;
    bool m_emailAccount = false;
    bool m_telegramLinked = false;
    unsigned int m_generation = 0;
};
