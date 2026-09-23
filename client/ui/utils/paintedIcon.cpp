#include "paintedIcon.h"

#include <QFile>
#include <QPainter>
#include <QQuickWindow>
#include <QSvgRenderer>

PaintedIcon::PaintedIcon(QQuickItem *parent) : QQuickPaintedItem(parent)
{
    setRenderTarget(QQuickPaintedItem::Image);
    setOpaquePainting(false);
    setAntialiasing(true);
    setImplicitSize(24, 24);
}

void PaintedIcon::setSource(const QUrl &source)
{
    if (m_source == source)
        return;
    m_source = source;
    m_svg.clear();
    m_image = {};
    QString path;
    if (source.scheme() == "qrc")
        path = ":" + source.path();
    else if (source.isLocalFile())
        path = source.toLocalFile();
    // Icons are bundled/local assets; never fetch URLs from the painter.
    if (!path.isEmpty()) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly)) {
            const auto data = file.readAll();
            QSvgRenderer svg(data);
            if (svg.isValid()) {
                m_svg = data;
                setImplicitSize(svg.defaultSize().width(), svg.defaultSize().height());
            } else {
                m_image.loadFromData(data);
                if (!m_image.isNull())
                    setImplicitSize(m_image.width(), m_image.height());
            }
        }
    }
    emit sourceChanged();
    update();
}

void PaintedIcon::setTint(const QString &tint)
{
    if (m_tint == tint)
        return;
    m_tint = tint;
    emit tintChanged();
    update();
}

void PaintedIcon::paint(QPainter *painter)
{
    if (width() <= 0 || height() <= 0 || (m_svg.isEmpty() && m_image.isNull()))
        return;
    const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1;
    QImage pixels(QSize(qCeil(width() * dpr), qCeil(height() * dpr)),
                  QImage::Format_ARGB32_Premultiplied);
    pixels.setDevicePixelRatio(dpr);
    pixels.fill(Qt::transparent);
    QPainter raster(&pixels);
    raster.setRenderHint(QPainter::Antialiasing);
    raster.setRenderHint(QPainter::SmoothPixmapTransform);
    QSizeF size(implicitWidth(), implicitHeight());
    size.scale(boundingRect().size(), Qt::KeepAspectRatio);
    const QRectF target((width() - size.width()) / 2, (height() - size.height()) / 2,
                        size.width(), size.height());
    if (!m_svg.isEmpty()) {
        QSvgRenderer svg(m_svg);
        svg.render(&raster, target);
    } else {
        raster.drawImage(target, m_image);
    }
    const QColor color(m_tint);
    if (color.isValid()) {
        raster.setCompositionMode(QPainter::CompositionMode_SourceIn);
        raster.fillRect(boundingRect(), color);
    }
    raster.end();
    painter->drawImage(QPointF(0, 0), pixels);
}
