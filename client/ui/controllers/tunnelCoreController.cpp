#include "tunnelCoreController.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QLocale>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QOperatingSystemVersion>

namespace {
const QString apiBase = QStringLiteral("https://tlsdmd.isgood.host/api/vpn/v1/");
constexpr qint64 maxResponseSize = 2 * 1024 * 1024;
constexpr qsizetype maxLoggedResponseSize = 2048;
}

TunnelCoreController::TunnelCoreController(QObject *parent, QNetworkAccessManager *network,
                                           TunnelCoreSessionStorage sessionStorage)
    : QObject(parent),
      m_network(network ? network : new QNetworkAccessManager(this)),
      m_sessionStorage(std::move(sessionStorage))
{
    if (m_sessionStorage.loadGeoRoutingCountry)
        m_geoRoutingCountry = m_sessionStorage.loadGeoRoutingCountry().trimmed().toUpper();
    if (!m_sessionStorage.load)
        return;

    const auto session = m_sessionStorage.load();
    const auto &[token, username, emailAccount, telegramLinked] = session;
    if (token.isEmpty() || token.contains('\r') || token.contains('\n') || username.isEmpty()) {
        if (m_sessionStorage.clear)
            m_sessionStorage.clear();
        return;
    }

    m_token = token;
    m_username = username;
    m_emailAccount = emailAccount;
    m_telegramLinked = telegramLinked;
    refresh();
}

void TunnelCoreController::saveSession()
{
    if (m_sessionStorage.save)
        m_sessionStorage.save(m_token, m_username, m_emailAccount, m_telegramLinked);
}

void TunnelCoreController::fail(const QString &message)
{
    m_busy = false;
    m_pendingConfigId = 0;
    m_error = message;
    emit changed();
}

void TunnelCoreController::clearError()
{
    m_error.clear();
    emit changed();
}

void TunnelCoreController::request(const QString &path, const QJsonObject &body,
                                 std::function<void(const QJsonObject &)> success, bool post,
                                 std::function<void(int, const QJsonObject &)> failure,
                                 bool authenticatedRequest)
{
    m_busy = true;
    m_error.clear();
    emit changed();
    QNetworkRequest request { QUrl(apiBase + path) };
    request.setTransferTimeout(30000);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    request.setRawHeader("Accept", "application/json");
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    if (!post || authenticatedRequest)
        request.setRawHeader("Authorization", "Bearer " + m_token);

    const auto requestUrl = request.url().toString(QUrl::FullyEncoded);
    const auto method = post ? QStringLiteral("POST") : QStringLiteral("GET");
    qInfo().noquote() << "[TunnelCore API] request" << method << requestUrl;

    auto *reply = post ? m_network->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact))
                       : m_network->get(request);
    m_reply = reply;
    const auto generation = m_generation;
    connect(reply, &QNetworkReply::readyRead, this, [reply]() {
        if (reply->bytesAvailable() > maxResponseSize)
            reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, generation, post, success, failure, requestUrl, method]() {
        reply->deleteLater();
        if (generation != m_generation)
            return;
        m_reply.clear();

        const auto status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto responseBody = reply->readAll();
        const bool successfulStatus = status >= 200 && status < 300;
        if (reply->error() != QNetworkReply::NoError || !successfulStatus) {
            const auto wwwAuthenticate = reply->rawHeader("WWW-Authenticate");
            qWarning().noquote()
                << "[TunnelCore API] response"
                << method
                << requestUrl
                << "status=" << status
                << "qtError=" << static_cast<int>(reply->error())
                << "error=" << reply->errorString()
                << "www-authenticate="
                << (wwwAuthenticate.isEmpty() ? QStringLiteral("<none>")
                                              : QString::fromLatin1(wwwAuthenticate));
            if (!responseBody.isEmpty()) {
                qWarning().noquote()
                    << "[TunnelCore API] error body="
                    << QString::fromUtf8(responseBody.left(maxLoggedResponseSize));
            }
        }

        if (!successfulStatus && failure && status > 0) {
            m_busy = false;
            const auto errorObject = QJsonDocument::fromJson(responseBody).object();
            failure(status, errorObject);
            return;
        }
        if (status == 401) {
            if (!post)
                logout();
            fail(post ? tr("The login details or password are incorrect.") : tr("Your session has ended. Sign in again."));
            return;
        }
        if (post && status == 400) {
            const auto error = QJsonDocument::fromJson(responseBody).object().value("error").toString();
            if (error == "email_and_password_required") {
                fail(tr("Enter a valid email and password."));
                return;
            }
            if (error == "username_and_password_required") {
                fail(tr("The server rejected the login details. Check the sign-in method and API version."));
                return;
            }
            fail(tr("The server rejected the login details."));
            return;
        }
        if (reply->error() != QNetworkReply::NoError || !successfulStatus) {
            fail(tr("Could not connect to TunnelCore. Check your connection and try again."));
            return;
        }
        QJsonParseError parseError;
        const auto document = QJsonDocument::fromJson(responseBody, &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()
            || !document.object().value("ok").toBool()) {
            fail(tr("The server returned an invalid response."));
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
        fail(tr("Enter the username and password from the bot."));
        return;
    }
    authenticate("auth/login/", {{"username", username.trimmed()}, {"password", password}});
}

void TunnelCoreController::loginCode(const QString &code)
{
    if (m_busy || authenticated())
        return;
    const auto normalizedCode = code.trimmed();
    bool isNumber = false;
    normalizedCode.toUInt(&isNumber);
    if (normalizedCode.size() != 6 || !isNumber) {
        fail(tr("Enter the six-digit code from the bot."));
        return;
    }
    authenticate("auth/code/exchange/", {{"code", normalizedCode}});
}

void TunnelCoreController::loginEmail(const QString &email, const QString &password)
{
    if (m_busy || authenticated())
        return;
    const auto normalizedEmail = email.trimmed().toLower();
    if (normalizedEmail.isEmpty() || password.isEmpty()) {
        fail(tr("Enter your email and password."));
        return;
    }
    // The server validates the address; do not impose a different email grammar here.
    authenticate("auth/login/", {{"email", normalizedEmail}, {"password", password}}, true);
}

void TunnelCoreController::registerEmail(const QString &email, const QString &password)
{
    if (m_busy || authenticated())
        return;
    const auto normalizedEmail = email.trimmed().toLower();
    if (normalizedEmail.isEmpty() || password.isEmpty()) {
        fail(tr("Enter your email and password."));
        return;
    }
    authenticate("auth/register/", {{"email", normalizedEmail}, {"password", password}}, true);
}

void TunnelCoreController::linkTelegram(const QString &code)
{
    if (m_busy || !authenticated() || !m_emailAccount)
        return;
    const auto normalizedCode = code.trimmed();
    bool isNumber = false;
    normalizedCode.toUInt(&isNumber);
    if (normalizedCode.size() != 6 || !isNumber) {
        fail(tr("Enter the six-digit code from the bot."));
        return;
    }

    request("auth/telegram/link/", {{"code", normalizedCode}}, [this](const QJsonObject &) {
        m_telegramLinked = true;
        saveSession();
        refresh();
    }, true, [this](int status, const QJsonObject &object) {
        const auto apiError = object.value("error").toString();
        if (status == 401 && apiError == "invalid_or_expired_code") {
            fail(tr("The Telegram code is invalid or has expired. Request a new code in the bot."));
        } else if (status == 401 && apiError == "unauthorized") {
            logout();
            fail(tr("Your session has ended. Sign in again."));
        } else if (status == 403 && apiError == "email_account_required") {
            fail(tr("Telegram can only be linked to an email account."));
        } else if (status == 409 && apiError == "telegram_link_not_found") {
            fail(tr("No Telegram account was found for this code."));
        } else if (status == 409 && apiError == "telegram_account_already_linked") {
            fail(tr("This Telegram account is already linked to another email account."));
        } else {
            fail(tr("Could not link the Telegram account. Try again."));
        }
    }, true);
}

void TunnelCoreController::authenticate(const QString &path, const QJsonObject &credentials, bool emailAccount)
{
    request(path, credentials,
            [this, emailAccount](const QJsonObject &object) {
        const auto token = object.value("access_token").toString().toLatin1();
        const auto user = object.value("user").toObject();
        const auto accountUsername = user.value("username").toString();
        const auto email = user.value("email").toString();
        const auto username = emailAccount && !email.isEmpty() ? email : accountUsername;
        if (token.isEmpty() || token.contains('\r') || token.contains('\n') || username.isEmpty()
            || object.value("token_type").toString().compare("Bearer", Qt::CaseInsensitive) != 0) {
            fail(tr("The server returned an invalid authentication response."));
            return;
        }
        m_token = token;
        m_username = username;
        m_emailAccount = emailAccount;
        m_telegramLinked = false;
        saveSession();
        emit signedIn();
        refresh();
    }, true, [this, path](int status, const QJsonObject &object) {
        const auto apiError = object.value("error").toString();
        if (path == "auth/register/") {
            if (status == 409 && apiError == "email_already_registered") {
                fail(tr("An account with this email already exists. Sign in instead."));
            } else if (status == 400 && apiError == "password_invalid") {
                fail(tr("The password does not meet the security requirements."));
            } else if (status == 400 && apiError == "email_and_password_required") {
                fail(tr("Enter a valid email and password."));
            } else {
                fail(tr("Could not create the account. Try again."));
            }
            return;
        }
        if (status == 400 && apiError == "email_and_password_required") {
            fail(tr("Enter a valid email and password."));
        } else if (status == 400 && apiError == "username_and_password_required") {
            fail(tr("The server rejected the login details. Check the sign-in method and API version."));
        } else if (status == 401) {
            fail(tr("The login details or password are incorrect."));
        } else {
            fail(tr("Could not connect to TunnelCore. Check your connection and try again."));
        }
    });
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
    m_vpnCountries.clear();
    m_vpnCountryMode = QStringLiteral("auto");
    m_selectedVpnCountry.clear();
    m_effectiveVpnCountry.clear();
    m_pendingConfigId = 0;
    m_error.clear();
    m_selectedConfigId = 0;
    m_busy = false;
    m_emailAccount = false;
    m_telegramLinked = false;
    if (m_sessionStorage.clear)
        m_sessionStorage.clear();
    emit changed();
}

bool TunnelCoreController::applyVpnCountrySelection(const QJsonObject &object)
{
    const auto selectionValue = object.value("selection");
    if (!selectionValue.isObject())
        return false;

    const auto selection = selectionValue.toObject();
    const auto countriesValue = selection.value("countries");
    if (!countriesValue.isArray())
        return false;

    const auto mode = selection.value("mode").toString().trimmed().toLower();
    if (mode != "auto" && mode != "country")
        return false;

    m_vpnCountries = countriesValue.toArray().toVariantList();
    m_vpnCountryMode = mode;
    m_selectedVpnCountry = selection.value("country").toString().trimmed().toUpper();
    m_effectiveVpnCountry = selection.value("effective_country").toString().trimmed().toUpper();
    m_selectedConfigId = selection.value("config_id").toVariant().toLongLong();
    return true;
}

void TunnelCoreController::refreshConfigs()
{
    request("configs/", {}, [this](const QJsonObject &object) {
        if (!object.value("configs").isArray()) {
            fail(tr("The server returned an invalid configuration list."));
            return;
        }
        m_configs = object.value("configs").toArray().toVariantList();

        if (m_pendingConfigId <= 0)
            return;

        const auto configId = std::exchange(m_pendingConfigId, 0);
        for (qsizetype index = 0; index < m_configs.size(); ++index) {
            bool validId = false;
            const auto listedId = m_configs.at(index).toMap().value("id").toLongLong(&validId);
            if (validId && listedId == configId) {
                selectConfig(index);
                return;
            }
        }

        fail(tr("The server returned invalid configuration data."));
    });
}

QString TunnelCoreController::routingPlatform() const
{
#if defined(Q_OS_ANDROID)
    return QStringLiteral("android");
#elif defined(Q_OS_IOS)
    return QStringLiteral("ios");
#elif defined(Q_OS_WIN)
    return QStringLiteral("windows");
#elif defined(Q_OS_MACOS)
    return QStringLiteral("macos");
#elif defined(Q_OS_LINUX)
    return QStringLiteral("linux");
#else
    return QStringLiteral("all");
#endif
}

void TunnelCoreController::refreshGeoRoutingCountries()
{
    request("routing/countries/", {}, [this](const QJsonObject &object) {
        const auto countriesValue = object.value("countries");
        if (!countriesValue.isArray()) {
            fail(tr("The server returned an invalid split-tunneling country list."));
            return;
        }

        QVariantList countries;
        for (const auto &value : countriesValue.toArray()) {
            const auto code = value.toString().trimmed().toUpper();
            if (code.size() != 2)
                continue;
            QVariantMap item;
            item.insert(QStringLiteral("code"), code);
            item.insert(QStringLiteral("name"), vpnCountryDisplayName(code));
            countries.append(item);
        }
        m_geoRoutingCountries = countries;

        if (!m_geoRoutingCountry.isEmpty()) {
            bool available = false;
            for (const auto &item : m_geoRoutingCountries) {
                if (item.toMap().value(QStringLiteral("code")).toString() == m_geoRoutingCountry) {
                    available = true;
                    break;
                }
            }
            if (!available) {
                m_geoRoutingCountry.clear();
                if (m_sessionStorage.saveGeoRoutingCountry)
                    m_sessionStorage.saveGeoRoutingCountry({});
            }
        }

        refreshRouting();
    }, false, [this](int status, const QJsonObject &) {
        if (status == 404) {
            m_geoRoutingCountries.clear();
            m_geoRoutingCountry.clear();
            refreshRouting();
            return;
        }
        if (status == 401) {
            logout();
            fail(tr("Your session has ended. Sign in again."));
            return;
        }
        fail(tr("Could not load the split-tunneling country list."));
    });
}

void TunnelCoreController::refreshRouting()
{
    const auto applyAndContinue = [this](const QJsonObject &routing) {
        if (m_sessionStorage.applyRouting) {
            QString errorMessage;
            if (!m_sessionStorage.applyRouting(routing, errorMessage)) {
                fail(errorMessage.isEmpty()
                         ? tr("Could not apply the VPN routing rules.")
                         : errorMessage);
                return;
            }
        }
        refreshConfigs();
    };

    if (!m_geoRoutingCountry.isEmpty()) {
        const auto path = QStringLiteral("routing/countries/%1/").arg(m_geoRoutingCountry);
        request(path, {}, [this, applyAndContinue](const QJsonObject &object) {
            if (object.value("mode").toString() != QStringLiteral("country_direct")
                || object.value("default_route").toString() != QStringLiteral("vpn")
                || object.value("country_route").toString() != QStringLiteral("direct")
                || !object.value("ipv4").isArray()) {
                fail(tr("The server returned invalid country routing data."));
                return;
            }

            QJsonArray rules;
            for (const auto &value : object.value("ipv4").toArray()) {
                const auto subnet = value.toString().trimmed();
                if (subnet.isEmpty())
                    continue;
                rules.append(QJsonObject{
                    {QStringLiteral("type"), QStringLiteral("ip")},
                    {QStringLiteral("value"), subnet},
                    {QStringLiteral("route"), QStringLiteral("direct")},
                    {QStringLiteral("priority"), 0},
                });
            }

            QJsonObject routing{
                {QStringLiteral("ok"), true},
                {QStringLiteral("version"), object.value("version")},
                {QStringLiteral("platform"), routingPlatform()},
                {QStringLiteral("rules"), rules},
            };
            qInfo() << "[TunnelCore routing] applying GeoIP direct country"
                    << m_geoRoutingCountry << "IPv4 routes=" << rules.size()
                    << "IPv6 routes kept inside VPN="
                    << object.value("ipv6").toArray().size();
            applyAndContinue(routing);
        }, false, [this](int status, const QJsonObject &object) {
            const auto apiError = object.value("error").toString();
            if (status == 401) {
                logout();
                fail(tr("Your session has ended. Sign in again."));
            } else if (status == 404 || apiError == "country_disabled") {
                fail(tr("This split-tunneling country is no longer available."));
            } else if (status == 503 || apiError == "geoip_unavailable") {
                fail(tr("Country routing data is temporarily unavailable."));
            } else {
                fail(tr("Could not load country routing data."));
            }
        });
        return;
    }

    const auto path = QStringLiteral("routing/?platform=%1").arg(routingPlatform());
    request(path, {}, applyAndContinue, false, [this](int status, const QJsonObject &) {
        if (status == 404) {
            // Compatibility with servers that have not deployed server-managed routing yet.
            refreshConfigs();
            return;
        }
        if (status == 401) {
            logout();
            fail(tr("Your session has ended. Sign in again."));
            return;
        }
        fail(tr("Could not load the VPN routing rules."));
    });
}

void TunnelCoreController::refresh()
{
    if (m_busy || !authenticated())
        return;
    m_configs.clear();
    m_subscriptions.clear();
    request("me/", {}, [this](const QJsonObject &object) {
        if (!object.value("subscriptions").isArray()) {
            fail(tr("The server returned an invalid subscription list."));
            return;
        }
        m_subscriptions = object.value("subscriptions").toArray().toVariantList();
        request("country-selection/", {}, [this](const QJsonObject &countryObject) {
            if (!applyVpnCountrySelection(countryObject)) {
                fail(tr("The server returned an invalid VPN country list."));
                return;
            }
            refreshGeoRoutingCountries();
        }, false, [this](int status, const QJsonObject &) {
            if (status == 404) {
                // Compatibility with servers that have not deployed country selection yet.
                m_vpnCountries.clear();
                m_vpnCountryMode = QStringLiteral("auto");
                m_selectedVpnCountry.clear();
                m_effectiveVpnCountry.clear();
                m_selectedConfigId = 0;
                refreshGeoRoutingCountries();
                return;
            }
            if (status == 401) {
                logout();
                fail(tr("Your session has ended. Sign in again."));
                return;
            }
            fail(tr("Could not load the VPN country list."));
        });
    });
}

QString TunnelCoreController::vpnCountryDisplayName(const QString &countryCode) const
{
    const auto code = countryCode.trimmed().toUpper();
    if (code.isEmpty())
        return {};
    const auto territory = QLocale::codeToTerritory(code);
    if (territory == QLocale::AnyTerritory)
        return code;
    const auto name = QLocale().territoryToString(territory);
    return name.isEmpty() ? code : name;
}

void TunnelCoreController::selectGeoRoutingCountry(const QString &countryCode)
{
    if (m_busy || !authenticated())
        return;

    const auto normalized = countryCode.trimmed().toUpper();
    if (normalized == m_geoRoutingCountry)
        return;

    if (!normalized.isEmpty()) {
        bool available = false;
        for (const auto &item : m_geoRoutingCountries) {
            if (item.toMap().value(QStringLiteral("code")).toString() == normalized) {
                available = true;
                break;
            }
        }
        if (!available) {
            fail(tr("The selected split-tunneling country is unavailable."));
            return;
        }
    }

    m_geoRoutingCountry = normalized;
    if (m_sessionStorage.saveGeoRoutingCountry)
        m_sessionStorage.saveGeoRoutingCountry(m_geoRoutingCountry);
    emit changed();
    refreshRouting();
}

void TunnelCoreController::selectVpnCountry(const QString &countryCode)
{
    if (m_busy || !authenticated())
        return;

    const auto normalized = countryCode.trimmed().toUpper();
    const bool autoMode = normalized.isEmpty() || normalized == "AUTO";
    if ((autoMode && m_vpnCountryMode == "auto")
        || (!autoMode && m_vpnCountryMode == "country" && m_selectedVpnCountry == normalized)) {
        return;
    }

    QJsonObject body;
    if (autoMode) {
        body.insert("mode", "auto");
    } else {
        body.insert("mode", "country");
        body.insert("country", normalized);
    }

    request("country-selection/", body, [this](const QJsonObject &object) {
        if (!applyVpnCountrySelection(object)) {
            fail(tr("The server returned invalid VPN country data."));
            return;
        }

        bool validConfigId = false;
        const auto configId = object.value("selection").toObject().value("config_id")
                                  .toVariant().toLongLong(&validConfigId);
        m_pendingConfigId = validConfigId && configId > 0 ? configId : 0;
        m_configs.clear();
        refreshRouting();
    }, true, [this](int status, const QJsonObject &object) {
        const auto apiError = object.value("error").toString();
        if (status == 401) {
            logout();
            fail(tr("Your session has ended. Sign in again."));
        } else if (status == 409 || apiError == "country_unavailable") {
            fail(tr("This VPN country is temporarily unavailable. Choose another country or Automatic."));
        } else if (status == 502 || apiError == "peer_migration_failed") {
            fail(tr("Could not move your VPN connection to the selected country. Try again later."));
        } else if (status == 400 || apiError == "invalid_country_code") {
            fail(tr("The selected VPN country is invalid."));
        } else {
            fail(tr("Could not change the VPN country. Try again."));
        }
    }, true);
}

QString TunnelCoreController::selectedProfileKey() const
{
    if (!authenticated() || m_selectedConfigId <= 0 || m_effectiveVpnCountry.isEmpty())
        return {};
    return QString::fromUtf8(QJsonDocument(QJsonArray {
        m_username, QString::number(m_selectedConfigId), m_effectiveVpnCountry
    }).toJson(QJsonDocument::Compact));
}

void TunnelCoreController::selectCurrentConfig()
{
    if (m_busy || !authenticated())
        return;
    for (qsizetype i = 0; i < m_configs.size(); ++i) {
        if (m_selectedConfigId > 0
            && m_configs.at(i).toMap().value("id").toLongLong() == m_selectedConfigId) {
            selectConfig(i);
            return;
        }
    }
    // Legacy API without country-selection metadata is unambiguous only when
    // it offers a single configuration. Never pick an unrelated first server.
    if (m_selectedConfigId <= 0 && m_configs.size() == 1) {
        selectConfig(0);
        return;
    }
    fail(tr("No configuration is available for the selected VPN location. Refresh and try again."));
}

void TunnelCoreController::selectConfig(int index)
{
    if (m_busy || !authenticated() || index < 0 || index >= m_configs.size())
        return;
    const auto config = m_configs.at(index).toMap();
    const auto data = config.value("config").toString().trimmed();
    const auto listedFileName = config.value("filename").toString().trimmed();
    const auto listedName = config.value("name").toString().trimmed();
    const auto suggestedFileName = !listedFileName.isEmpty() ? listedFileName : listedName;
    if (!data.isEmpty()) {
        // Compatibility with servers that still return the configuration or
        // its one-time download URL directly in the list response.
        deliverConfig(data, suggestedFileName);
        return;
    }

    bool validId = false;
    const auto configId = config.value("id").toLongLong(&validId);
    if (!validId || configId <= 0) {
        fail(tr("The server returned invalid configuration data."));
        return;
    }

    request(QStringLiteral("configs/%1/").arg(configId), {},
            [this, suggestedFileName](const QJsonObject &object) {
        const auto downloadedConfig = object.value("config").toString().trimmed();
        if (downloadedConfig.isEmpty()) {
            fail(tr("The server returned an empty VPN configuration."));
            return;
        }
        auto fileName = object.value("filename").toString().trimmed();
        if (fileName.isEmpty())
            fileName = object.value("name").toString().trimmed();
        if (fileName.isEmpty())
            fileName = suggestedFileName;
        deliverConfig(downloadedConfig, fileName);
    }, false, [this](int status, const QJsonObject &object) {
        const auto apiError = object.value("error").toString();
        if (status == 401) {
            logout();
            fail(tr("Your session has ended. Sign in again."));
        } else if (status == 404 || apiError == "config_not_found") {
            fail(tr("This configuration has already been retrieved or is no longer available. Refresh the list."));
        } else if (status == 502 || apiError == "config_unavailable") {
            fail(tr("Could not retrieve the configuration from the VPN server. Try again later."));
        } else {
            fail(tr("Could not download the VPN configuration."));
        }
    });
}

void TunnelCoreController::deliverConfig(const QString &data, const QString &fileName)
{
    const QUrl url(data);
    if (url.scheme() != "https") {
        emit configReady(data, fileName);
        return;
    }
    if (url.host().isEmpty() || !url.userInfo().isEmpty()) {
        fail(tr("The server returned an invalid configuration URL."));
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
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation, fileName]() {
        reply->deleteLater();
        if (generation != m_generation)
            return;
        m_reply.clear();
        if (reply->error() != QNetworkReply::NoError
            || reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() != 200) {
            fail(tr("Could not download the configuration. Get a new configuration from the bot and refresh the list."));
            return;
        }
        m_busy = false;
        emit changed();
        emit configReady(QString::fromUtf8(reply->readAll()), fileName);
    });
}
