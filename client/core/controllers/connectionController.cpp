#include "connectionController.h"

#include <QJsonDocument>
#include <QRegularExpression>
#include <algorithm>

#include "core/configurators/configuratorBase.h"
#include "core/utils/protocolEnum.h"
#include "core/protocols/protocolUtils.h"
#include "core/utils/constants/configKeys.h"
#include "core/utils/payloadSender.h"
#include "core/utils/utilities.h"
#include "core/utils/serverConfigUtils.h"
#include "core/utils/tunnelCoreObfuscation.h"
#include "version.h"
#include "core/utils/containerEnum.h"
#include "core/utils/containers/containerUtils.h"
#include "core/utils/protocolEnum.h"
#include "core/models/containerConfig.h"
#include "core/models/protocolConfig.h"

using namespace amnezia;
using namespace ProtocolUtils;

namespace
{
const QString tunnelCoreManagedProfileId = QStringLiteral("tunnelcore-vpn");

void replaceAwgNativeParameter(QString &nativeConfig, const QString &key, const QString &value)
{
    if (nativeConfig.isEmpty() || value.isEmpty())
        return;

    const QRegularExpression expression(
        QStringLiteral("(?im)^\\s*%1\\s*=.*$").arg(QRegularExpression::escape(key)));
    auto match = expression.match(nativeConfig);
    const auto replacement = QStringLiteral("%1 = %2").arg(key, value);
    if (match.hasMatch()) {
        nativeConfig.replace(expression, replacement);
        return;
    }

    const QRegularExpression peerSection(QStringLiteral("(?im)^\\s*\\[Peer\\]\\s*$"));
    match = peerSection.match(nativeConfig);
    if (match.hasMatch()) {
        nativeConfig.insert(match.capturedStart(), replacement + QLatin1Char('\n'));
    } else {
        if (!nativeConfig.endsWith(QLatin1Char('\n')))
            nativeConfig.append(QLatin1Char('\n'));
        nativeConfig.append(replacement + QLatin1Char('\n'));
    }
}

void removeAwgNativeParameter(QString &nativeConfig, const QString &key)
{
    if (nativeConfig.isEmpty())
        return;

    const QRegularExpression expression(
        QStringLiteral("(?im)^[ \\t]*%1[ \\t]*=[^\\r\\n]*(?:\\r?\\n|$)")
            .arg(QRegularExpression::escape(key)));
    nativeConfig.remove(expression);
}

template <typename Config>
bool hasDeprecatedDefaultJunk(const Config &config)
{
    return config.specialJunk1.trimmed() == QLatin1String(protocols::awg::defaultSpecialJunk1)
            && config.specialJunk2.trimmed().isEmpty()
            && config.specialJunk3.trimmed().isEmpty()
            && config.specialJunk4.trimmed().isEmpty()
            && config.specialJunk5.trimmed().isEmpty();
}

bool migrateDeprecatedSelfHostedAwgJunk(ContainerConfig &containerConfig)
{
    auto *awg = containerConfig.getAwgProtocolConfig();
    if (!awg)
        return false;

    bool migrated = false;
    if (hasDeprecatedDefaultJunk(awg->serverConfig)) {
        awg->serverConfig.specialJunk1.clear();
        migrated = true;
    }

    if (awg->clientConfig.has_value() && hasDeprecatedDefaultJunk(awg->clientConfig.value())) {
        auto &client = awg->clientConfig.value();
        client.specialJunk1.clear();
        removeAwgNativeParameter(client.nativeConfig, QStringLiteral("I1"));
        migrated = true;
    }

    return migrated;
}

bool applyTunnelCoreManagedAwg31Base(ContainerConfig &containerConfig)
{
    auto *awg = containerConfig.getAwgProtocolConfig();
    if (!awg || !awg->clientConfig.has_value())
        return false;

    auto &client = awg->clientConfig.value();
    const auto setParameter = [&client](QString &field, const QString &key, const QString &value) {
        field = value;
        replaceAwgNativeParameter(client.nativeConfig, key, value);
    };

    setParameter(client.junkPacketCount, QStringLiteral("Jc"), QStringLiteral("6"));
    setParameter(client.junkPacketMinSize, QStringLiteral("Jmin"), QStringLiteral("10"));
    setParameter(client.junkPacketMaxSize, QStringLiteral("Jmax"), QStringLiteral("50"));
    setParameter(client.initPacketJunkSize, QStringLiteral("S1"), QStringLiteral("12"));
    setParameter(client.responsePacketJunkSize, QStringLiteral("S2"), QStringLiteral("12"));
    setParameter(client.cookieReplyPacketJunkSize, QStringLiteral("S3"), QStringLiteral("12"));
    setParameter(client.transportPacketJunkSize, QStringLiteral("S4"), QStringLiteral("12"));
    setParameter(client.initPacketMagicHeader, QStringLiteral("H1"), QStringLiteral("1"));
    setParameter(client.responsePacketMagicHeader, QStringLiteral("H2"), QStringLiteral("2"));
    setParameter(client.underloadPacketMagicHeader, QStringLiteral("H3"), QStringLiteral("3"));
    setParameter(client.transportPacketMagicHeader, QStringLiteral("H4"), QStringLiteral("4"));

    client.contentPaddingAddition.clear();
    removeAwgNativeParameter(client.nativeConfig, QStringLiteral("ContentPaddingAddition"));
    setParameter(client.rekeyAfterTime, QStringLiteral("RekeyAfterTime"), QStringLiteral("100-120"));
    setParameter(client.rekeyTimeout, QStringLiteral("RekeyTimeout"), QStringLiteral("3-7"));
    setParameter(client.rejectAfterTime, QStringLiteral("RejectAfterTime"), QStringLiteral("150-180"));
    setParameter(client.keepaliveTimeout, QStringLiteral("KeepaliveTimeout"), QStringLiteral("5-15"));
    setParameter(client.maxHandshakeAttempts, QStringLiteral("MaxHandshakeAttempts"), QStringLiteral("15-20"));
    setParameter(client.randomTrailers, QStringLiteral("RandomTrailers"), QStringLiteral("on"));
    setParameter(client.disableCookies, QStringLiteral("DisableCookies"), QStringLiteral("on"));

    return true;
}

bool applyTunnelCoreDynamicObfuscation(ContainerConfig &containerConfig, const QString &requestedProfile,
                                       const QString &stableProfileKey)
{
    auto *awg = containerConfig.getAwgProtocolConfig();
    if (!awg || !awg->clientConfig.has_value())
        return false;

    const auto generated = TunnelCoreObfuscation::generate(requestedProfile, stableProfileKey);
    if (generated.packets.size() != 5
        || std::any_of(generated.packets.cbegin(), generated.packets.cend(),
                       [](const QString &packet) { return packet.isEmpty(); })) {
        return false;
    }

    auto &client = awg->clientConfig.value();
    client.specialJunk1 = generated.packets.at(0);
    client.specialJunk2 = generated.packets.at(1);
    client.specialJunk3 = generated.packets.at(2);
    client.specialJunk4 = generated.packets.at(3);
    client.specialJunk5 = generated.packets.at(4);

    replaceAwgNativeParameter(client.nativeConfig, QStringLiteral("I1"), client.specialJunk1);
    replaceAwgNativeParameter(client.nativeConfig, QStringLiteral("I2"), client.specialJunk2);
    replaceAwgNativeParameter(client.nativeConfig, QStringLiteral("I3"), client.specialJunk3);
    replaceAwgNativeParameter(client.nativeConfig, QStringLiteral("I4"), client.specialJunk4);
    replaceAwgNativeParameter(client.nativeConfig, QStringLiteral("I5"), client.specialJunk5);

    qInfo().noquote()
        << "[TunnelCore] generated AWG I1-I5 profile"
        << generated.profile
        << "source"
        << generated.sourceDomain;
    return true;
}
} // namespace

ConnectionController::ConnectionController(SecureServersRepository* serversRepository,
                                         SecureAppSettingsRepository* appSettingsRepository,
                                         VpnConnection* vpnConnection,
                                         QObject* parent)
    : QObject(parent),
      m_serversRepository(serversRepository),
      m_appSettingsRepository(appSettingsRepository),
      m_vpnConnection(vpnConnection)
{
    connect(m_vpnConnection, &VpnConnection::connectionStateChanged, this, &ConnectionController::connectionStateChanged);
    connect(this, &ConnectionController::openConnectionRequested, m_vpnConnection, &VpnConnection::connectToVpn, Qt::QueuedConnection);
    connect(this, &ConnectionController::closeConnectionRequested, m_vpnConnection, &VpnConnection::disconnectFromVpn, Qt::QueuedConnection);
    connect(this, &ConnectionController::killSwitchModeChangedRequested, m_vpnConnection, &VpnConnection::onKillSwitchModeChanged, Qt::QueuedConnection);
#ifdef Q_OS_ANDROID
    connect(this, &ConnectionController::restoreConnectionRequested, m_vpnConnection, &VpnConnection::restoreConnection, Qt::QueuedConnection);
#endif
}

bool ConnectionController::isConnected() const
{
    return m_vpnConnection && m_vpnConnection->connectionState() == Vpn::ConnectionState::Connected;
}

void ConnectionController::setConnectionState(Vpn::ConnectionState state)
{
    emit connectionStateChanged(state);
}

ErrorCode ConnectionController::defaultContainerForServer(const QString &serverId, DockerContainer &container) const
{
    const auto kind = m_serversRepository->serverKind(serverId);
    switch (kind) {
    case serverConfigUtils::ConfigType::SelfHostedAdmin: {
        const auto cfg = m_serversRepository->selfHostedAdminConfig(serverId);
        if (!cfg.has_value()) {
            return ErrorCode::InternalError;
        }
        container = cfg->defaultContainer;
        return ErrorCode::NoError;
    }
    case serverConfigUtils::ConfigType::SelfHostedUser: {
        const auto cfg = m_serversRepository->selfHostedUserConfig(serverId);
        if (!cfg.has_value()) {
            return ErrorCode::InternalError;
        }
        container = cfg->defaultContainer;
        return ErrorCode::NoError;
    }
    case serverConfigUtils::ConfigType::Native: {
        const auto cfg = m_serversRepository->nativeConfig(serverId);
        if (!cfg.has_value()) {
            return ErrorCode::InternalError;
        }
        container = cfg->defaultContainer;
        return ErrorCode::NoError;
    }
    case serverConfigUtils::ConfigType::AmneziaPremiumV2:
    case serverConfigUtils::ConfigType::AmneziaFreeV3:
    case serverConfigUtils::ConfigType::ExternalPremium: {
        const auto cfg = m_serversRepository->apiV2Config(serverId);
        if (!cfg.has_value()) {
            return ErrorCode::InternalError;
        }
        container = cfg->defaultContainer;
        return ErrorCode::NoError;
    }
    case serverConfigUtils::ConfigType::AmneziaPremiumV1:
    case serverConfigUtils::ConfigType::AmneziaFreeV2:
        return ErrorCode::LegacyApiV1NotSupportedError;
    case serverConfigUtils::ConfigType::Invalid:
    default:
        return ErrorCode::InternalError;
    }
}

ErrorCode ConnectionController::isConnectionSupported(const QString &serverId) const
{
    if (serverId.isEmpty()) {
        return ErrorCode::InternalError;
    }

    if (!isServiceReady()) {
        return ErrorCode::AmneziaServiceNotRunning;
    }

    const serverConfigUtils::ConfigType kind = m_serversRepository->serverKind(serverId);
    if (serverConfigUtils::isLegacyApiSubscription(kind)) {
        return ErrorCode::LegacyApiV1NotSupportedError;
    }

    DockerContainer container = DockerContainer::None;
    const ErrorCode errorCode = defaultContainerForServer(serverId, container);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    if (container == DockerContainer::None) {
        if (serverConfigUtils::isApiV2Subscription(kind)) {
            return ErrorCode::NoError;
        }
        return ErrorCode::NoInstalledContainersError;
    }

    if (ContainerUtils::isUnsupportedContainer(container)) {
        return ErrorCode::LegacyContainerNotSupportedError;
    }

    if (!isContainerSupported(container)) {
        return ErrorCode::NotSupportedOnThisPlatform;
    }

    return ErrorCode::NoError;
}

ErrorCode ConnectionController::prepareConnection(const QString &serverId,
                                                 QJsonObject& vpnConfiguration,
                                                 DockerContainer& container)
{
    ContainerConfig containerConfigModel;
    QPair<QString, QString> dns;
    QString hostName;
    QString description;
    int configVersion = 0;
    bool isApiConfig = false;

    const auto kind = m_serversRepository->serverKind(serverId);
    const QString primaryDns = m_appSettingsRepository->primaryDns();
    const QString secondaryDns = m_appSettingsRepository->secondaryDns();
    switch (kind) {
    case serverConfigUtils::ConfigType::SelfHostedAdmin: {
        auto cfg = m_serversRepository->selfHostedAdminConfig(serverId);
        if (!cfg.has_value()) return ErrorCode::InternalError;
        container = cfg->defaultContainer;
        containerConfigModel = cfg->containerConfig(container);
        if (ContainerUtils::isAwgContainer(container)
            && migrateDeprecatedSelfHostedAwgJunk(containerConfigModel)) {
            cfg->updateContainerConfig(container, containerConfigModel);
            m_serversRepository->editServer(serverId, cfg->toJson(), kind);
            qInfo() << "[TunnelCore] removed deprecated default AWG I1 from self-hosted admin config";
        }
        dns = cfg->getDnsPair(m_appSettingsRepository->useAmneziaDns(), primaryDns, secondaryDns);
        hostName = cfg->hostName;
        description = cfg->description;
        break;
    }
    case serverConfigUtils::ConfigType::SelfHostedUser: {
        auto cfg = m_serversRepository->selfHostedUserConfig(serverId);
        if (!cfg.has_value()) return ErrorCode::InternalError;
        container = cfg->defaultContainer;
        containerConfigModel = cfg->containerConfig(container);
        if (ContainerUtils::isAwgContainer(container)
            && migrateDeprecatedSelfHostedAwgJunk(containerConfigModel)) {
            cfg->updateContainerConfig(container, containerConfigModel);
            m_serversRepository->editServer(serverId, cfg->toJson(), kind);
            qInfo() << "[TunnelCore] removed deprecated default AWG I1 from self-hosted user config";
        }
        dns = cfg->getDnsPair(primaryDns, secondaryDns);
        hostName = cfg->hostName;
        description = cfg->description;
        break;
    }
    case serverConfigUtils::ConfigType::Native: {
        const auto cfg = m_serversRepository->nativeConfig(serverId);
        if (!cfg.has_value()) return ErrorCode::InternalError;
        container = cfg->defaultContainer;
        containerConfigModel = cfg->containerConfig(container);

        if (cfg->managedProfileId == tunnelCoreManagedProfileId
            && ContainerUtils::isAwgContainer(container)) {
            if (!applyTunnelCoreManagedAwg31Base(containerConfigModel)) {
                qWarning() << "[TunnelCore] failed to apply managed AWG 3.1 base parameters";
            }

            if (cfg->managedObfuscationMode.compare(
                    QStringLiteral("client_dynamic"), Qt::CaseInsensitive) == 0) {
                if (!applyTunnelCoreDynamicObfuscation(
                        containerConfigModel,
                        cfg->managedObfuscationProfile,
                        cfg->managedProfileKey)) {
                    qWarning() << "[TunnelCore] failed to generate dynamic AWG I1-I5; using static fallback";
                }
            }
        }

        dns = cfg->getDnsPair(primaryDns, secondaryDns);
        hostName = cfg->hostName;
        description = cfg->description;
        break;
    }
    case serverConfigUtils::ConfigType::AmneziaPremiumV2:
    case serverConfigUtils::ConfigType::AmneziaFreeV3:
    case serverConfigUtils::ConfigType::ExternalPremium: {
        const auto cfg = m_serversRepository->apiV2Config(serverId);
        if (!cfg.has_value()) return ErrorCode::InternalError;
        container = cfg->defaultContainer;
        containerConfigModel = cfg->containerConfig(container);
        dns = cfg->getDnsPair(primaryDns, secondaryDns);
        hostName = cfg->hostName;
        description = cfg->description;
        configVersion = serverConfigUtils::ConfigSource::AmneziaGateway;
        isApiConfig = true;
        break;
    }
    case serverConfigUtils::ConfigType::AmneziaPremiumV1:
    case serverConfigUtils::ConfigType::AmneziaFreeV2:
        return ErrorCode::InternalError;
    case serverConfigUtils::ConfigType::Invalid:
    default:
        return ErrorCode::InternalError;
    }

    vpnConfiguration = createConnectionConfiguration(dns, isApiConfig, hostName, description, configVersion,
                                                     containerConfigModel, container);

    return ErrorCode::NoError;
}

ErrorCode ConnectionController::openConnection(const QString &serverId)
{
    QJsonObject vpnConfiguration;
    DockerContainer container;

    ErrorCode errorCode = prepareConnection(serverId, vpnConfiguration, container);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    const auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (apiV2.has_value() && !apiV2->sendPayload.isEmpty()) {
        PayloadSender::sendAll(apiV2->sendPayload);
    }

    emit openConnectionRequested(serverId, container, vpnConfiguration);
    return ErrorCode::NoError;
}

void ConnectionController::closeConnection()
{
    if (m_vpnConnection) {
        emit closeConnectionRequested();
    }
}

#ifdef Q_OS_ANDROID
void ConnectionController::restoreConnection()
{
    if (m_vpnConnection) {
        emit restoreConnectionRequested();
    }
}
#endif

void ConnectionController::onKillSwitchModeChanged(bool enabled)
{
    if (m_vpnConnection) {
        emit killSwitchModeChangedRequested(enabled);
    }
}

ErrorCode ConnectionController::lastConnectionError() const
{
    return m_vpnConnection->lastError();
}

QJsonObject ConnectionController::createConnectionConfiguration(const QPair<QString, QString> &dns,
                                                              bool isApiConfig,
                                                              const QString &hostName,
                                                              const QString &description,
                                                              int configVersion,
                                                              const ContainerConfig &containerConfig,
                                                              DockerContainer container)
{
    QJsonObject vpnConfiguration {};

    if (ContainerUtils::containerService(container) == ServiceType::Other) {
        return vpnConfiguration;
    }

    Proto proto = ContainerUtils::defaultProtocol(container);

    ConnectionSettings connectionSettings = {
        { dns.first, dns.second },
        isApiConfig,
        {
            m_appSettingsRepository->isSitesSplitTunnelingEnabled(),
            m_appSettingsRepository->routeMode()
        }
    };

    auto configurator = ConfiguratorBase::create(proto, nullptr);
    ProtocolConfig processedConfig = configurator->processConfigWithLocalSettings(connectionSettings,
                                                                                  containerConfig.protocolConfig);

    QJsonObject vpnConfigData = processedConfig.getClientConfigJson();
    if (ContainerUtils::isAwgContainer(container) || container == DockerContainer::WireGuard) {
        if (vpnConfigData[configKey::mtu].toString().isEmpty()) {
            vpnConfigData[configKey::mtu] =
                    ContainerUtils::isAwgContainer(container) ? protocols::awg::defaultMtu :
                    protocols::wireguard::defaultMtu;
        }
    }

    vpnConfiguration.insert(ProtocolUtils::key_proto_config_data(proto), vpnConfigData);
    vpnConfiguration[configKey::vpnProto] = ProtocolUtils::protoToString(proto);

    vpnConfiguration[configKey::dns1] = dns.first;
    vpnConfiguration[configKey::dns2] = dns.second;

    vpnConfiguration[configKey::hostName] = hostName;
    vpnConfiguration[configKey::description] = description;
    vpnConfiguration[configKey::configVersion] = configVersion;

    return vpnConfiguration;
}

bool ConnectionController::isServiceReady() const
{
#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS) && !defined(MACOS_NE)
    return Utils::processIsRunning(Utils::executable(SERVICE_NAME, false), true);
#else
    return true;
#endif
}

bool ConnectionController::isContainerSupported(DockerContainer container) const
{
    return ContainerUtils::isSupportedByCurrentPlatform(container);
}
