#pragma once

#include <QHostAddress>
#include <QJsonArray>
#include <QJsonObject>
#include <QPair>
#include <QStringList>

namespace TunnelCoreDns {
inline bool validIPv4(const QString &text)
{
    const QHostAddress ip(text);
    return ip.protocol() == QAbstractSocket::IPv4Protocol
           && ip.toString() == text && ip.toIPv4Address() != 0
           && !ip.isLoopback() && !ip.isMulticast()
           && ip.toIPv4Address() != 0xffffffffu;
}

inline bool privateIPv4(const QString &text)
{
    if (!validIPv4(text))
        return false;
    const quint32 n = QHostAddress(text).toIPv4Address();
    return (n & 0xff000000u) == 0x0a000000u
        || (n & 0xfff00000u) == 0xac100000u
        || (n & 0xffff0000u) == 0xc0a80000u;
}

inline QStringList parseServers(const QString &text)
{
    QStringList result;
    for (const auto &part : text.split(QLatin1Char(','))) {
        const auto address = part.trimmed();
        if (validIPv4(address) && !result.contains(address))
            result.append(address);
        if (result.size() == 2)
            break;
    }
    return result;
}

inline QStringList policyServers(const QJsonObject &policy)
{
    if (!policy.value("available").isBool() || !policy.value("available").toBool()
        || policy.value("recommended").toString() != QStringLiteral("tunnelcore")
        || !policy.value("servers").isArray())
        return {};
    const auto servers = policy.value("servers").toArray();
    if (servers.isEmpty() || servers.size() > 2)
        return {};
    QStringList result;
    for (const auto &value : servers) {
        const auto ip = value.toString();
        if (!privateIPv4(ip) || result.contains(ip))
            return {};
        result.append(ip);
    }
    return result;
}

inline bool validMode(const QString &mode)
{
    return mode == "auto" || mode == "cloudflare" || mode == "google"
           || mode == "quad9" || mode == "custom";
}

inline QPair<QString, QString> choose(const QString &mode, const QStringList &managed,
                                     const QPair<QString, QString> &original,
                                     const QString &primary, const QString &secondary)
{
    if (mode == "cloudflare")
        return {QStringLiteral("1.1.1.1"), QStringLiteral("1.0.0.1")};
    if (mode == "google")
        return {QStringLiteral("8.8.8.8"), QStringLiteral("8.8.4.4")};
    if (mode == "quad9")
        return {QStringLiteral("9.9.9.9"), QStringLiteral("149.112.112.112")};
    if (mode == "custom" && validIPv4(primary)
        && (secondary.isEmpty() || validIPv4(secondary)))
        return {primary, secondary == primary ? QString() : secondary};
    if (mode == "auto" && !managed.isEmpty())
        return {managed.first(), managed.value(1)};
    return original;
}
}
