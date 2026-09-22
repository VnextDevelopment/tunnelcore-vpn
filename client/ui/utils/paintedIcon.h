#pragma once

#include <QQuickPaintedItem>
#include <QImage>
#include <QUrl>

// Rasterize and tint on the CPU. QQuickPaintedItem uses a dedicated texture,
// avoiding both the Image texture atlas and GraphicalEffects shader masks.
class PaintedIcon : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QString tint READ tint WRITE setTint NOTIFY tintChanged)
public:
    explicit PaintedIcon(QQuickItem *parent = nullptr);
    QUrl source() const { return m_source; }
    QString tint() const { return m_tint; }
    void setSource(const QUrl &source);
    void setTint(const QString &tint);
    void paint(QPainter *painter) override;
signals:
    void sourceChanged();
    void tintChanged();
private:
    QUrl m_source;
    QString m_tint;
    QByteArray m_svg;
    QImage m_image;
};
