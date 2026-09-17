#include "tunnelCoreController.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>

namespace {
const QString apiBase = QStringLiteral("https://tlsdmd.isgood.host/api/vpn/v1/");
constexpr qint64 maxResponseSize = 2 * 1024 * 1024;
}

TunnelCoreController::TunnelCoreController(QObject *parent, QNetworkAccessManager *network)
    : QObject(parent), m_network(network ? network : new QNetworkAccessManager(this)) {}

void TunnelCoreController::fail(const QString &message)
{
    m_busy = false;
    m_error = message;
    emit changed();
}

void TunnelCoreController::clearError()
{
    m_error.clear();
    emit changed();
}

void TunnelCoreController::request(const QString &path, const QJsonObject &body,
                                 std::function<void(const QJsonObject &)> success, bool post)
{
    m_busy = true;
    m_error.clear();
    emit changed();
    QNetworkRequest request { QUrl(apiBase + path) };
    request.setTransferTimeout(30000);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    request.setRawHeader("Accept", "application/json");
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    if (!post)
        request.setRawHeader("Authorization", "Bearer " + m_token);
    auto *reply = post ? m_network->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact))
                       : m_network->get(request);
    m_reply = reply;
    const auto generation = m_generation;
    connect(reply, &QNetworkReply::readyRead, this, [reply]() {
        if (reply->bytesAvailable() > maxResponseSize)
            reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation, post, success]() {
        reply->deleteLater();
        if (generation != m_generation)
            return;
        m_reply.clear();
        const auto status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 401) {
            if (!post)
                logout();
            fail(post ? tr("Неверные данные для входа или пароль.") : tr("Сессия завершена. Войдите снова."));
            return;
        }
        if (post && status == 400) {
            const auto error = QJsonDocument::fromJson(reply->readAll()).object().value("error").toString();
            if (error == "email_and_password_required") {
                fail(tr("Введите корректный email и пароль."));
                return;
            }
            if (error == "username_and_password_required") {
                fail(tr("Сервер не принял данные для входа. Проверьте способ входа и версию API."));
                return;
            }
            fail(tr("Сервер не принял данные для входа."));
            return;
        }
        if (reply->error() != QNetworkReply::NoError || status != 200) {
            fail(tr("Не удалось связаться с TunnelCore. Проверьте подключение и повторите попытку."));
            return;
        }
        QJsonParseError parseError;
        const auto document = QJsonDocument::fromJson(reply->readAll(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()
            || !document.object().value("ok").toBool()) {
            fail(tr("Сервер вернул некорректный ответ."));
            return;
        }
        m_busy = false;
        success(document.object());
        emit changed();
    });
}

void TunnelCoreController::login(const QString &username, const QString &password)
{
    if (m_busy || authenticated())
        return;
    if (username.trimmed().isEmpty() || password.isEmpty()) {
        fail(tr("Введите логин и пароль из бота."));
        return;
    }
    authenticate({{"username", username.trimmed()}, {"password", password}});
}

void TunnelCoreController::loginEmail(const QString &email, const QString &password)
{
    if (m_busy || authenticated())
        return;
    const auto normalizedEmail = email.trimmed().toLower();
    if (normalizedEmail.isEmpty() || password.isEmpty()) {
        fail(tr("Введите email и пароль."));
        return;
    }
    // The server validates the address; do not impose a different email grammar here.
    authenticate({{"email", normalizedEmail}, {"password", password}});
}

void TunnelCoreController::authenticate(const QJsonObject &credentials)
{
    request("auth/login/", credentials,
            [this](const QJsonObject &object) {
        const auto token = object.value("access_token").toString().toLatin1();
        const auto username = object.value("user").toObject().value("username").toString();
        if (token.isEmpty() || token.contains('\r') || token.contains('\n') || username.isEmpty()
            || object.value("token_type").toString().compare("Bearer", Qt::CaseInsensitive) != 0) {
            fail(tr("Сервер вернул некорректный ответ авторизации."));
            return;
        }
        m_token = token;
        m_username = username;
        emit signedIn();
        refresh();
    }, true);
}

void TunnelCoreController::logout()
{
    ++m_generation;
    if (m_reply) {
        m_reply->abort();
        m_reply.clear();
    }
    m_token.clear();
    m_username.clear();
    m_subscriptions.clear();
    m_configs.clear();
    m_error.clear();
    m_busy = false;
    emit changed();
}

void TunnelCoreController::refresh()
{
    if (m_busy || !authenticated())
        return;
    m_configs.clear();
    m_subscriptions.clear();
    request("me/", {}, [this](const QJsonObject &object) {
        if (!object.value("subscriptions").isArray()) {
            fail(tr("Сервер вернул некорректный список подписок."));
            return;
        }
        m_subscriptions = object.value("subscriptions").toArray().toVariantList();
        request("configs/", {}, [this](const QJsonObject &object) {
            if (!object.value("configs").isArray()) {
                fail(tr("Сервер вернул некорректный список конфигураций."));
                return;
            }
            m_configs = object.value("configs").toArray().toVariantList();
        });
    });
}

void TunnelCoreController::selectConfig(int index)
{
    if (m_busy || !authenticated() || index < 0 || index >= m_configs.size())
        return;
    const auto data = m_configs.at(index).toMap().value("config").toString().trimmed();
    if (data.isEmpty()) {
        fail(tr("Конфигурация пока недоступна. Обновите список позже."));
        return;
    }
    const QUrl url(data);
    if (url.scheme() != "https") {
        emit configReady(data);
        return;
    }
    if (url.host().isEmpty() || !url.userInfo().isEmpty()) {
        fail(tr("Сервер вернул некорректную ссылку на конфигурацию."));
        return;
    }
    // Download URLs carry their own one-time token. Never send the account token to a node.
    QNetworkRequest request(url);
    request.setTransferTimeout(30000);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    m_busy = true;
    m_error.clear();
    emit changed();
    auto *reply = m_network->get(request);
    m_reply = reply;
    const auto generation = m_generation;
    connect(reply, &QNetworkReply::readyRead, this, [reply]() {
        if (reply->bytesAvailable() > maxResponseSize)
            reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation]() {
        reply->deleteLater();
        if (generation != m_generation)
            return;
        m_reply.clear();
        if (reply->error() != QNetworkReply::NoError
            || reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() != 200) {
            fail(tr("Не удалось загрузить конфигурацию. Получите новую конфигурацию в боте и обновите список."));
            return;
        }
        m_busy = false;
        emit changed();
        emit configReady(QString::fromUtf8(reply->readAll()));
    });
}
