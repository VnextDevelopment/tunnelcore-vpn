#pragma once

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QPair>
#include <QVariantList>
#include <functional>
#include <utility>

class QNetworkReply;

struct TunnelCoreSessionStorage
{
    std::function<QPair<QByteArray, QString>()> load;
    std::function<void(const QByteArray &, const QString &)> save;
    std::function<void()> clear;
};

class TunnelCoreController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString username READ username NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QVariantList subscriptions READ subscriptions NOTIFY changed)
    Q_PROPERTY(QVariantList configs READ configs NOTIFY changed)

public:
    explicit TunnelCoreController(QObject *parent = nullptr, QNetworkAccessManager *network = nullptr,
                                  TunnelCoreSessionStorage sessionStorage = {});
    bool authenticated() const { return !m_token.isEmpty(); }
    bool busy() const { return m_busy; }
    QString username() const { return m_username; }
    QString error() const { return m_error; }
    QVariantList subscriptions() const { return m_subscriptions; }
    QVariantList configs() const { return m_configs; }

    Q_INVOKABLE void loginCode(const QString &code);
    // Legacy login methods remain available during the server transition, but the
    // TunnelCore UI uses one-time Telegram codes.
    Q_INVOKABLE void login(const QString &username, const QString &password);
    Q_INVOKABLE void loginEmail(const QString &email, const QString &password);
    Q_INVOKABLE void clearError();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void selectConfig(int index);

signals:
    void changed();
    void signedIn();
    void configReady(const QString &data);

private:
    void authenticate(const QString &path, const QJsonObject &credentials);
    void request(const QString &path, const QJsonObject &body,
                 std::function<void(const QJsonObject &)> success, bool post = false,
                 std::function<void(int, const QJsonObject &)> failure = {});
    void deliverConfig(const QString &data);
    void fail(const QString &message);
    QNetworkAccessManager *m_network;
    QPointer<QNetworkReply> m_reply;
    QByteArray m_token;
    QString m_username;
    QString m_error;
    QVariantList m_subscriptions;
    QVariantList m_configs;
    TunnelCoreSessionStorage m_sessionStorage;
    bool m_busy = false;
    unsigned int m_generation = 0;
};
