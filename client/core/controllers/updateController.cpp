#include "updateController.h"

#include <QCryptographicHash>
#include <QDesktopServices>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSharedPointer>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QUrl>
#include <QUrlQuery>
#include <QVersionNumber>

#include "amneziaApplication.h"
#include "logger.h"
#include "core/utils/appUiConfig.h"
#include "core/utils/selfhosted/scriptsRegistry.h"
#include "version.h"

#if defined(Q_OS_ANDROID)
    #include "platforms/android/android_controller.h"
#endif

namespace
{
    Logger logger("UpdateController");

    // This first-party HTTPS endpoint returns metadata for TunnelCore releases only.
    const QUrl kUpdatesEndpoint(QStringLiteral("https://vnextdev.com/api/tunnelcore/updates"));

#if defined(Q_OS_WINDOWS)
    const QLatin1String kInstallerRemoteFileNamePattern("TunnelCoreVPN_%1_windows_x64.exe");
    const QString kInstallerLocalPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/TunnelCoreVPN_installer.exe";
#elif defined(Q_OS_MACOS) && !defined(MACOS_NE)
    const QLatin1String kInstallerRemoteFileNamePattern("TunnelCoreVPN_%1_macos_x64.pkg");
    const QString kInstallerLocalPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/TunnelCoreVPN.pkg";
#elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    const QLatin1String kInstallerRemoteFileNamePattern("TunnelCoreVPN_%1_linux_x64.run");
    const QString kInstallerLocalPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/TunnelCoreVPN.run";
#endif

    QString platformChannel()
    {
#if defined(Q_OS_ANDROID)
        return AndroidController::instance()->isPlay() ? QStringLiteral("android-play") : QStringLiteral("android-apk");
#elif defined(Q_OS_IOS)
        return QStringLiteral("ios");
#elif defined(MACOS_NE)
        return QStringLiteral("macos-store");
#elif defined(Q_OS_MACOS)
        return QStringLiteral("macos");
#elif defined(Q_OS_WINDOWS)
        return QStringLiteral("windows");
#else
        return QStringLiteral("linux");
#endif
    }

    bool validVersion(const QString &version)
    {
        static const QRegularExpression pattern(QStringLiteral(R"(^\d+\.\d+\.\d+(?:\.\d+)?$)"));
        return pattern.match(version).hasMatch();
    }

    bool tunnelCoreReleasePage(const QUrl &url)
    {
        return url.scheme() == QLatin1String("https")
            && url.host() == QLatin1String("github.com")
            && url.path().startsWith(QLatin1String("/VnextDevelopment/tunnelcore-vpn/releases/tag/"))
            && url.query().isEmpty() && url.fragment().isEmpty();
    }

    QStringList stringListFromJsonValue(const QJsonValue &value)
    {
        QStringList result;
        for (const QJsonValue &item : value.toArray()) {
            const QString text = item.toString();
            if (!text.isEmpty()) {
                result.append(text);
            }
        }
        return result;
    }
}

UpdateController::UpdateController(SecureAppSettingsRepository *appSettingsRepository, QObject *parent)
    : QObject(parent), m_appSettingsRepository(appSettingsRepository)
{
}

QString UpdateController::getVersion() const { return m_version; }
QString UpdateController::getReleaseDate() const { return m_releaseDate; }
QString UpdateController::getDescription() const { return m_description; }
QStringList UpdateController::getTags() const { return m_tags; }
QStringList UpdateController::getNewFeatures() const { return m_newFeatures; }
QStringList UpdateController::getImprovements() const { return m_improvements; }
QStringList UpdateController::getBugFixes() const { return m_bugFixes; }
UpdateState::State UpdateController::getUpdateState() const { return m_updateState; }
bool UpdateController::isMandatory() const { return m_mandatory; }

bool UpdateController::isStoreUpdate() const
{
#if defined(Q_OS_IOS) || defined(MACOS_NE)
    return true;
#elif defined(Q_OS_ANDROID)
    return AndroidController::instance()->isPlay();
#else
    return false;
#endif
}

void UpdateController::setUpdateState(UpdateState::State state)
{
    if (m_updateState == state) return;
    m_updateState = state;
    emit updateStateChanged();
}

bool UpdateController::isUpdateCheckRunning() const { return m_updateCheckRunning; }

void UpdateController::setUpdateCheckRunning(bool running)
{
    if (m_updateCheckRunning == running) return;
    m_updateCheckRunning = running;
    emit updateCheckRunningChanged();
}

void UpdateController::checkForUpdates()
{
    if (m_updateCheckRunning) return;
    setUpdateCheckRunning(true);

    QUrl url(kUpdatesEndpoint);
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("platform"), platformChannel());
    query.addQueryItem(QStringLiteral("version"), QString::fromLatin1(APP_VERSION));
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setTransferTimeout(12000);
    request.setRawHeader("Accept", "application/json");
    // Do not allow an intermediary to redirect update metadata to an arbitrary host.
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::SameOriginRedirectPolicy);

    auto *reply = amnApp->networkManager()->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        setUpdateCheckRunning(false);
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || status != 200) {
            logger.warning() << "TunnelCore update check failed:" << status << reply->errorString();
            reply->deleteLater();
            emit updateCheckFailed();
            return;
        }

        QJsonParseError jsonError;
        const QJsonDocument document = QJsonDocument::fromJson(reply->readAll(), &jsonError);
        reply->deleteLater();
        if (jsonError.error != QJsonParseError::NoError || !document.isObject()) {
            emit updateCheckFailed();
            return;
        }

        const QJsonObject data = document.object();
        if (!data.value(QStringLiteral("updateAvailable")).toBool()) {
            setUpdateState(UpdateState::State::Idle);
            emit updateNotFound();
            return;
        }

        const QString version = data.value(QStringLiteral("updateVersion")).toString();
        if (!validVersion(version) || QVersionNumber::compare(QVersionNumber::fromString(version),
                                                               QVersionNumber::fromString(QString::fromLatin1(APP_VERSION))) <= 0) {
            emit updateNotFound();
            return;
        }

        const QUrl releasePage(data.value(QStringLiteral("releasePageUrl")).toString());
        if (isStoreUpdate()) {
#if defined(Q_OS_ANDROID)
            if (releasePage.scheme() != QLatin1String("https") ||
                releasePage.host() != QLatin1String("play.google.com")) {
                emit updateCheckFailed();
                return;
            }
#else
            if (releasePage.scheme() != QLatin1String("https") ||
                releasePage.host() != QLatin1String("apps.apple.com")) {
                emit updateCheckFailed();
                return;
            }
#endif
        } else if (!tunnelCoreReleasePage(releasePage)) {
            emit updateCheckFailed();
            return;
        }

        const QString downloadUrl = data.value(QStringLiteral("downloadUrl")).toString();
        const QString sha256 = data.value(QStringLiteral("sha256")).toString().toLower();
        const qint64 size = static_cast<qint64>(data.value(QStringLiteral("downloadSize")).toDouble());
#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS) && !defined(MACOS_NE)
        // The installer is never launched unless it is a branded asset with a SHA-256 digest.
        const QUrl installerUrl(downloadUrl);
        const QString expectedName = QString(kInstallerRemoteFileNamePattern).arg(version);
        const QRegularExpression hashPattern(QStringLiteral("^[0-9a-f]{64}$"));
        if (installerUrl.scheme() != QLatin1String("https") ||
            installerUrl.host() != QLatin1String("github.com") ||
            !installerUrl.path().startsWith(QLatin1String("/VnextDevelopment/tunnelcore-vpn/releases/download/")) ||
            !installerUrl.path().endsWith(QLatin1String("/") + expectedName) ||
            !installerUrl.query().isEmpty() || !installerUrl.fragment().isEmpty() ||
            !hashPattern.match(sha256).hasMatch() || size < 1 || size > 850000000) {
            logger.error() << "Invalid TunnelCore installer metadata";
            emit updateCheckFailed();
            return;
        }
#endif

        m_version = version;
        m_releaseDate = data.value(QStringLiteral("releaseDate")).toString();
        m_description = data.value(QStringLiteral("updateDescription")).toString();
        m_tags = stringListFromJsonValue(data.value(QStringLiteral("updateTags")));
        m_newFeatures = stringListFromJsonValue(data.value(QStringLiteral("newFeatures")));
        m_improvements = stringListFromJsonValue(data.value(QStringLiteral("improvements")));
        m_bugFixes = stringListFromJsonValue(data.value(QStringLiteral("bugFixes")));
        m_downloadUrl = downloadUrl;
        m_expectedSha256 = sha256;
        m_expectedSize = size;
        m_releasePageUrl = releasePage.toString();
        m_mandatory = data.value(QStringLiteral("mandatory")).toBool();

        setUpdateState(UpdateState::State::Idle);
        logger.info() << "TunnelCore update available:" << version;
        emit updateFound();
    });
}

void UpdateController::openStorePage() const
{
    QUrl url(m_releasePageUrl);
#if defined(Q_OS_IOS) || defined(MACOS_NE)
    if (url.scheme() != QLatin1String("https") || url.host() != QLatin1String("apps.apple.com"))
        url = QUrl(QLatin1String(APP_IOS_STORE_URL_FALLBACK));
    if (url.scheme() == QLatin1String("https") && url.host() == QLatin1String("apps.apple.com"))
        QDesktopServices::openUrl(url);
    else
        logger.warning() << "TunnelCore App Store listing is not configured";
#elif defined(Q_OS_ANDROID)
    if (url.scheme() != QLatin1String("https") || url.host() != QLatin1String("play.google.com"))
        url = QUrl(QStringLiteral("https://play.google.com/store/apps/details?id=%1").arg(QLatin1String(APP_ANDROID_PACKAGE)));
    QDesktopServices::openUrl(url);
#endif
}

void UpdateController::startUpdate()
{
    if (isStoreUpdate()) {
        openStorePage();
        return;
    }
#if defined(Q_OS_ANDROID)
    // Android APK sideloads use the signed APK from the branded GitHub release.
    const QUrl url(m_releasePageUrl);
    if (tunnelCoreReleasePage(url))
        QDesktopServices::openUrl(url);
    else
        setUpdateState(UpdateState::State::DownloadError);
#elif !defined(Q_OS_IOS) && !defined(MACOS_NE)
    downloadInstaller();
#endif
}

QString UpdateController::composeDownloadUrl() const
{
#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS) && !defined(MACOS_NE)
    return m_downloadUrl;
#else
    return QString();
#endif
}

void UpdateController::downloadInstaller()
{
#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS) && !defined(MACOS_NE)
    if (m_updateState == UpdateState::State::Downloading) return;

    const QUrl url(composeDownloadUrl());
    if (url.isEmpty() || m_expectedSha256.size() != 64 || m_expectedSize < 1) {
        setUpdateState(UpdateState::State::DownloadError);
        return;
    }

    auto file = QSharedPointer<QSaveFile>::create(kInstallerLocalPath);
    if (!file->open(QIODevice::WriteOnly)) {
        logger.error() << "Cannot create installer:" << file->errorString();
        setUpdateState(UpdateState::State::DownloadError);
        return;
    }

    auto digest = QSharedPointer<QCryptographicHash>::create(QCryptographicHash::Sha256);
    auto bytesWritten = QSharedPointer<qint64>::create(0);
    setUpdateState(UpdateState::State::Downloading);

    QNetworkRequest request(url);
    request.setTransferTimeout(60000);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setMaximumRedirectsAllowed(5);
    auto *reply = amnApp->networkManager()->get(request);

    // Stream to disk: never buffer an unbounded installer in application memory.
    auto drain = [reply, file, digest, bytesWritten, this]() {
        while (reply->bytesAvailable() > 0) {
            const QByteArray chunk = reply->read(64 * 1024);
            if (chunk.isEmpty()) break;
            *bytesWritten += chunk.size();
            if (*bytesWritten > m_expectedSize || file->write(chunk) != chunk.size()) {
                reply->abort();
                return;
            }
            digest->addData(chunk);
        }
    };
    connect(reply, &QNetworkReply::readyRead, this, drain);
    connect(reply, &QNetworkReply::finished, this, [this, reply, file, digest, bytesWritten, drain]() {
        drain();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const bool valid = reply->error() == QNetworkReply::NoError && status == 200 &&
                           *bytesWritten == m_expectedSize &&
                           QString::fromLatin1(digest->result().toHex()) == m_expectedSha256;
        reply->deleteLater();
        if (!valid || !file->commit()) {
            logger.error() << "TunnelCore installer download/verification failed:" << status;
            file->cancelWriting();
            setUpdateState(UpdateState::State::DownloadError);
            return;
        }
        setUpdateState(UpdateState::State::ReadyToInstall);
    });
#endif
}

void UpdateController::installUpdate()
{
#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS) && !defined(MACOS_NE)
    if (m_updateState != UpdateState::State::ReadyToInstall) {
        logger.error() << "Installer is not downloaded yet";
        return;
    }

    #if defined(Q_OS_WINDOWS)
    runWindowsInstaller(kInstallerLocalPath);
    #elif defined(Q_OS_MACOS) && !defined(MACOS_NE)
    runMacInstaller(kInstallerLocalPath);
    #elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    runLinuxInstaller(kInstallerLocalPath);
    #endif
#endif
}

#if defined(Q_OS_WINDOWS)
int UpdateController::runWindowsInstaller(const QString &installerPath)
{
    qint64 pid;
    bool success = QProcess::startDetached(installerPath, QStringList(), QString(), &pid);

    if (success) {
        logger.info() << "Installation process started with PID:" << pid;
    } else {
        logger.error() << "Failed to start installation process";
        return -1;
    }

    return 0;
}
#endif

#if defined(Q_OS_MACOS) && !defined(MACOS_NE)
int UpdateController::runMacInstaller(const QString &installerPath)
{
    // Create temporary directory for extraction
    QTemporaryDir extractDir;
    extractDir.setAutoRemove(false);
    if (!extractDir.isValid()) {
        logger.error() << "Failed to create temporary directory";
        return -1;
    }
    logger.info() << "Temporary directory created:" << extractDir.path();

    // Create script file in the temporary directory
    QString scriptPath = extractDir.path() + "/mac_installer.sh";
    QFile scriptFile(scriptPath);
    if (!scriptFile.open(QIODevice::WriteOnly)) {
        logger.error() << "Failed to create script file";
        return -1;
    }

    // Get script content from registry
    QString scriptContent = amnezia::scriptData(amnezia::ClientScriptType::mac_installer);
    if (scriptContent.isEmpty()) {
        logger.error() << "macOS installer script content is empty";
        scriptFile.close();
        return -1;
    }

    scriptFile.write(scriptContent.toUtf8());
    scriptFile.close();
    logger.info() << "Script file created:" << scriptPath;

    // Make script executable
    QFile::setPermissions(scriptPath, QFile::permissions(scriptPath) | QFile::ExeUser);

    // Start detached process
    qint64 pid;
    bool success =
            QProcess::startDetached("/bin/bash", QStringList() << scriptPath << extractDir.path() << installerPath, extractDir.path(), &pid);

    if (success) {
        logger.info() << "Installation process started with PID:" << pid;
    } else {
        logger.error() << "Failed to start installation process";
        return -1;
    }

    return 0;
}
#endif

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
int UpdateController::runLinuxInstaller(const QString &installerPath)
{
    QFile::setPermissions(installerPath, QFile::permissions(installerPath) | QFile::ExeUser);

    qint64 pid;
    bool success = QProcess::startDetached(installerPath, QStringList(), QString(), &pid);

    if (success) {
        logger.info() << "Installation process started with PID:" << pid;
    } else {
        logger.error() << "Failed to start installation process";
        return -1;
    }

    return 0;
}
#endif
