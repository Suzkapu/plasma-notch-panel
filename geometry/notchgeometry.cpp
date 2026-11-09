// SPDX-License-Identifier: GPL-3.0-or-later
#include <KWindowEffects>
#include <LayerShellQt/Window>
#include <Plasma/Applet>
#include <Plasma/Theme>
#include <PlasmaQuick/AppletQuickItem>

#include <QGuiApplication>
#include <QLineF>
#include <QPainter>
#include <QPainterPath>
#include <QPointer>
#include <QQmlEngine>
#include <QQmlExtensionPlugin>
#include <QQuickPaintedItem>
#include <QQuickWindow>
#include <QTimer>
#include <QRegion>
#include <QVariant>
#include <QtWaylandClient/private/qwaylandwindow_p.h>

#include <algorithm>

// One path supplies both the visual mask and Plasma's blur region.
class NotchMask : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(bool vertical MEMBER m_vertical NOTIFY shapeChanged)
    Q_PROPERTY(bool opposite MEMBER m_opposite NOTIFY shapeChanged)
    Q_PROPERTY(qreal barDepth MEMBER m_barDepth NOTIFY shapeChanged)
    Q_PROPERTY(qreal notchDepth MEMBER m_notchDepth NOTIFY shapeChanged)
    Q_PROPERTY(qreal sectionCenter MEMBER m_center NOTIFY shapeChanged)
    Q_PROPERTY(qreal sectionLength MEMBER m_sectionLength NOTIFY shapeChanged)
    Q_PROPERTY(qreal spacerThickness MEMBER m_spacerThickness NOTIFY shapeChanged)
    Q_PROPERTY(QVariantList spacerSpans MEMBER m_spacerSpans NOTIFY shapeChanged)
    Q_PROPERTY(QVariant nativeMask MEMBER m_nativeMask NOTIFY shapeChanged)
    Q_PROPERTY(QVariant region READ region NOTIFY regionChanged)
    Q_PROPERTY(bool themeEffectsEnabled MEMBER m_themeEffectsEnabled NOTIFY themeEffectsChanged)
    Q_PROPERTY(QPointF frameOrigin MEMBER m_frameOrigin NOTIFY themeEffectsChanged)
    Q_PROPERTY(int baseSurfaceDepth MEMBER m_baseSurfaceDepth NOTIFY surfaceChanged)
    Q_PROPERTY(int extraSurfaceDepth MEMBER m_extraSurfaceDepth NOTIFY surfaceChanged)
    Q_PROPERTY(bool canExtend READ canExtend NOTIFY surfaceAvailabilityChanged)

public:
    explicit NotchMask(QQuickItem *parent = nullptr)
        : QQuickPaintedItem(parent)
    {
        connect(this, &NotchMask::shapeChanged, this, &NotchMask::rebuild);
        m_effectUpdate.setSingleShot(true);
        connect(&m_effectUpdate, &QTimer::timeout, this, &NotchMask::applyThemeEffects);
        connect(this, &NotchMask::regionChanged, this, &NotchMask::scheduleThemeEffects);
        connect(this, &NotchMask::themeEffectsChanged, this, &NotchMask::scheduleThemeEffects);
        connect(&m_theme, &Plasma::Theme::themeChanged, this, &NotchMask::scheduleThemeEffects);

        m_surfaceUpdate.setSingleShot(true);
        connect(&m_surfaceUpdate, &QTimer::timeout, this, &NotchMask::resizeSurface);
        connect(this, &QQuickItem::windowChanged, this, &NotchMask::attachSurface);
        connect(this, &NotchMask::surfaceChanged, this, &NotchMask::scheduleSurfaceResize);
        connect(this, &NotchMask::shapeChanged, this, &NotchMask::scheduleSurfaceResize);
    }

    ~NotchMask() override
    {
        m_extraSurfaceDepth = 0;
        resizeSurface();
    }

    bool canExtend() const
    {
        return m_layer != nullptr;
    }

    QVariant region() const
    {
        return QVariant::fromValue(m_region);
    }

    Q_INVOKABLE void scheduleThemeEffects()
    {
        if (m_themeEffectsEnabled)
            m_effectUpdate.start(0);
    }

    void paint(QPainter *painter) override
    {
        painter->setRenderHint(QPainter::Antialiasing);
        painter->fillPath(m_path, Qt::white);
    }

Q_SIGNALS:
    void shapeChanged();
    void regionChanged();
    void themeEffectsChanged();
    void surfaceChanged();
    void surfaceAvailabilityChanged();

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override
    {
        QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
        if (newGeometry.size() != oldGeometry.size())
            rebuild();
    }

private:
    void attachSurface(QQuickWindow *view)
    {
        const bool wasAvailable = canExtend();
        if (m_layer)
            disconnect(m_layer, nullptr, this, nullptr);

        m_layer = view && QGuiApplication::platformName().startsWith(QStringLiteral("wayland"))
            ? LayerShellQt::Window::get(view) : nullptr;
        if (wasAvailable != canExtend())
            Q_EMIT surfaceAvailabilityChanged();

        if (m_layer) {
            connect(m_layer, &LayerShellQt::Window::desiredSizeChanged, this, &NotchMask::scheduleSurfaceResize);
            scheduleSurfaceResize();
        }
    }

    void scheduleSurfaceResize()
    {
        if (m_layer && !m_settingSurfaceSize)
            m_surfaceUpdate.start(0);
    }

    // Plasma's preferred size is based on its configured thickness. Keep that
    // setting (and its exclusive zone), and grow just the Wayland buffer inward.
    void resizeSurface()
    {
        if (!m_layer || m_baseSurfaceDepth <= 0 || (!m_extendedSurface && m_extraSurfaceDepth <= 0))
            return;

        QSize size = m_layer->desiredSize();
        if (size.isEmpty())
            return;

        const int depth = m_baseSurfaceDepth + m_extraSurfaceDepth;
        if (m_vertical)
            size.setWidth(depth);
        else
            size.setHeight(depth);

        m_extendedSurface = m_extraSurfaceDepth > 0;
        if (size == m_layer->desiredSize())
            return;

        m_settingSurfaceSize = true;
        m_layer->setDesiredSize(size);
        m_settingSurfaceSize = false;

        // Layer-shell applies size changes on commit. A panel occluded by
        // Dodge Windows can remain mapped without being exposed for rendering.
        if (auto *view = window()) {
            if (view->isExposed()) {
                view->update();
            } else if (auto *waylandWindow = dynamic_cast<QtWaylandClient::QWaylandWindow *>(view->handle())) {
                waylandWindow->commit();
            }
        }
    }

    void applyThemeEffects()
    {
        if (!m_themeEffectsEnabled || !window() || m_region.isEmpty())
            return;

        const QRegion area = m_region.translated(m_frameOrigin.toPoint());
        window()->setMask(area);
        KWindowEffects::enableBlurBehind(window(), m_theme.blurBehindEnabled(), area);
        KWindowEffects::enableBackgroundContrast(window(), m_theme.backgroundContrastEnabled(),
            m_theme.backgroundContrast(), m_theme.backgroundIntensity(), m_theme.backgroundSaturation(), area);
    }

    struct SpacerSpan {
        qreal start;
        qreal end;
        qreal startShoulder;
        qreal endShoulder;
    };

    QList<SpacerSpan> spacerSpans(qreal length) const
    {
        QList<QPointF> spans;
        for (const auto &value : m_spacerSpans)
            spans.append(value.toPointF());
        std::sort(spans.begin(), spans.end(), [](const QPointF &a, const QPointF &b) {
            return a.x() < b.x();
        });

        QList<SpacerSpan> result;
        for (qsizetype i = 0; i < spans.size(); ++i) {
            const qreal first = spans[i].x();
            qreal last = first + spans[i].y();
            while (i + 1 < spans.size() && spans[i + 1].x() <= last + 1) {
                ++i;
                last = std::max(last, spans[i].x() + spans[i].y());
            }

            const qreal start = std::max(0.0, first);
            const qreal end = std::min(length, last);
            if (end > start) {
                const qreal shoulder = std::min(96.0, (end - start) * 0.4);
                result.append({start, end, shoulder, shoulder});
            }
        }
        return result;
    }

    QPainterPath taperSpacers(const QPainterPath &edge, qreal length, qreal spacerThickness,
                             const QLineF &notchPlateau, const QList<SpacerSpan> &spans) const
    {
        // The inner edge is monotonic along the panel. Taper its local depth
        // so the spacer curves meet both the bar and the notch tangentially.
        const QPolygonF contour = edge.toSubpathPolygons().value(0);
        if (contour.size() < 2)
            return edge;

        QPainterPath tapered(QPointF(0, 0));
        auto next = contour.cbegin();
        const auto appendContour = [&](qreal limit, bool inSpacer) {
            while (next != contour.cend() && next->x() <= limit) {
                const qreal depth = next->y();
                tapered.lineTo(next->x(), inSpacer ? std::min(depth, spacerThickness) : depth);
                ++next;
            }
        };
        const auto appendShoulder = [&](qreal from, qreal to, bool rising) {
            const qreal anchor = rising ? to : from;
            // When the spacer meets the flat notch, ease directly into it.
            // Tapering the old notch shoulder again creates a steep inner bend.
            const bool meetsNotch = !notchPlateau.isNull()
                && anchor >= notchPlateau.x1() && anchor <= notchPlateau.x2();
            const int steps = std::max(1, qCeil(to - from));
            for (int i = 0; i <= steps; ++i) {
                const qreal t = qreal(i) / steps;
                const qreal x = from + (to - from) * t;
                while (next != contour.cend() - 1 && (next == contour.cbegin() || next->x() <= x))
                    ++next;
                const QPointF &previous = *(next - 1);
                const qreal span = next->x() - previous.x();
                const qreal fraction = span > 0 ? (x - previous.x()) / span : 1;
                const qreal depth = meetsNotch ? notchPlateau.y1()
                    : previous.y() + (next->y() - previous.y()) * fraction;
                const qreal eased = t * t * (3 - 2 * t);
                const qreal remaining = std::min(depth, spacerThickness);
                tapered.lineTo(x, remaining + (depth - remaining) * (rising ? eased : 1 - eased));
            }
        };

        for (const auto &span : spans) {
            if (span.start > 0) {
                appendContour(span.start, false);
                appendShoulder(span.start, span.start + span.startShoulder, false);
            }
            if (span.end >= length) {
                appendContour(length, true);
                return tapered;
            }
            appendContour(span.end - span.endShoulder, true);
            appendShoulder(span.end - span.endShoulder, span.end, true);
        }

        appendContour(length, false);
        return tapered;
    }

    void rebuild()
    {
        const qreal length = m_vertical ? height() : width();
        const qreal thickness = m_vertical ? width() : height();
        QPainterPath path;

        if (length > 0 && thickness > 0) {
            const qreal bar = std::clamp(m_barDepth, 0.0, thickness);
            const qreal depth = std::clamp(m_notchDepth, bar, thickness);
            const qreal radius = std::min({7.0, bar, length / 2});
            const qreal half = m_sectionLength / 2;
            qreal start = std::max(radius, m_center - half);
            qreal end = std::min(length - radius, m_center + half);
            const bool hasNotch = depth > bar && end > start;
            auto spans = spacerSpans(length);

            if (hasNotch) {
                // Include small layout gaps between the notch and its spacers.
                constexpr qreal joinTolerance = 12;
                SpacerSpan *left = nullptr;
                SpacerSpan *right = nullptr;
                for (auto &span : spans) {
                    if (span.start <= start && span.end <= m_center && span.end >= start - joinTolerance)
                        left = &span;
                    if (!right && span.end >= end && span.start >= m_center && span.start <= end + joinTolerance)
                        right = &span;
                }
                if (left && right) {
                    const qreal shoulder = std::min(left->endShoulder, right->startShoulder);
                    left->endShoulder = shoulder;
                    right->startShoulder = shoulder;
                    start = std::max(radius, std::min(start, left->end));
                    end = std::min(length - radius, std::max(end, right->start));
                }
            }

            const qreal shoulder = std::min({50.0, start - radius, length - radius - end});
            const qreal before = start - shoulder;
            const qreal after = end + shoulder;
            const QLineF notchPlateau = hasNotch ? QLineF(start, depth, end, depth) : QLineF();
            QPainterPath innerEdge(QPointF(0, bar - radius));
            innerEdge.quadTo(0, bar, radius, bar);
            if (!notchPlateau.isNull()) {
                innerEdge.lineTo(before, bar);
                innerEdge.cubicTo(before + (start - before) * 0.45, bar,
                                  start - (start - before) * 0.45, depth, start, depth);
                innerEdge.lineTo(end, depth);
                innerEdge.cubicTo(end + (after - end) * 0.45, depth,
                                  after - (after - end) * 0.45, bar, after, bar);
            }
            innerEdge.lineTo(length - radius, bar);
            innerEdge.quadTo(length, bar, length, bar - radius);

            path.moveTo(length, 0);
            path.lineTo(0, 0);
            if (spans.isEmpty())
                path.connectPath(innerEdge);
            else
                path.connectPath(taperSpacers(innerEdge, length, std::clamp(m_spacerThickness, 0.0, bar),
                                              notchPlateau, spans));
            path.closeSubpath();

            // The path is drawn along the panel, with depth measured inward.
            if (m_vertical)
                path = QTransform(0, 1, m_opposite ? -1 : 1, 0, m_opposite ? width() : 0, 0).map(path);
            else if (m_opposite)
                path = QTransform(1, 0, 0, -1, 0, height()).map(path);
        }

        m_path = path;
        QRegion region(path.toFillPolygon().toPolygon());
        const auto native = m_nativeMask.value<QRegion>();
        if (!native.isEmpty())
            region &= native;
        if (region != m_region) {
            m_region = region;
            Q_EMIT regionChanged();
        }
        update();
    }

    bool m_vertical = false;
    bool m_opposite = false;
    qreal m_barDepth = 32;
    qreal m_notchDepth = 64;
    qreal m_center = 0;
    qreal m_sectionLength = 0;
    qreal m_spacerThickness = 0;
    QVariantList m_spacerSpans;
    QVariant m_nativeMask;
    QPainterPath m_path;
    QRegion m_region;
    bool m_themeEffectsEnabled = false;
    QPointF m_frameOrigin;
    Plasma::Theme m_theme;
    QTimer m_effectUpdate;
    QTimer m_surfaceUpdate;
    QPointer<LayerShellQt::Window> m_layer;
    int m_baseSurfaceDepth = 0;
    int m_extraSurfaceDepth = 0;
    bool m_extendedSurface = false;
    bool m_settingSurfaceSize = false;
};

// The settings dialog has a different window and QML engine from the panel.
class PanelLookup : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    Q_INVOKABLE QQuickWindow *viewForApplet(QObject *object) const
    {
        auto *applet = qobject_cast<Plasma::Applet *>(object);
        auto *item = applet ? PlasmaQuick::AppletQuickItem::itemForApplet(applet) : nullptr;
        auto *view = item ? item->window() : nullptr;
        if (view)
            QQmlEngine::setObjectOwnership(view, QQmlEngine::CppOwnership);
        return view;
    }
};

class NotchGeometryPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<NotchMask>(uri, 1, 0, "NotchMask");
        qmlRegisterSingletonType<PanelLookup>(uri, 1, 0, "PanelLookup",
            [](QQmlEngine *, QJSEngine *) -> QObject * { return new PanelLookup; });
    }
};

#include "notchgeometry.moc"
