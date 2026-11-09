// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQml.Models
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "NotchGeometry" as Geometry
import org.kde.plasma.components as PlasmaComponents

// Plasma's widget entry point: https://develop.kde.org/docs/plasma/widget/setup/
PlasmoidItem {
    id: notch

    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {
        Rectangle {
            anchors.centerIn: parent
            visible: notch.editing
            rotation: notch.vertical ? 90 : 0
            width: 78
            height: 25
            radius: 5
            color: "#145f85"
            PlasmaComponents.Label {
                anchors.centerIn: parent
                color: "white"
                text: i18n("Notch start")
            }
        }
    }

    // The native thickness is the shallow bar and the minimum notch depth.
    readonly property int panelDepth: panelView?.thickness ?? 0
    readonly property int targetWidgetDepth: Math.max(panelDepth, Math.min(160, Plasmoid.configuration.notchDepth ?? 64))
    readonly property int notchLength: Plasmoid.configuration.minNotchLength ?? 0
    readonly property bool shrinkToFit: notchLength > 0 && !(Plasmoid.configuration.growOnOverflow ?? true)
    readonly property int sectionPadding: 12
    readonly property int fitUnits: shrinkToFit
        ? notchWidgets.reduce((sum, item) => sum + sizingUnits(item), 0) : 0
    readonly property real fitBudget: Math.max(0, notchLength - sectionPadding
        - Math.max(0, notchWidgets.length - 1) * (vertical ? (grid?.rowSpacing ?? 0) : (grid?.columnSpacing ?? 0)))
    readonly property int fitUnitSize: fitUnits ? Math.max(1, Math.floor(fitBudget / fitUnits)) : targetWidgetDepth
    readonly property int fittedWidgetDepth: Math.min(targetWidgetDepth, fitUnitSize)
    readonly property int requestedDepth: Math.max(panelDepth, fittedWidgetDepth)
    readonly property int fixedCrossPadding: vertical
        ? (panel?.fixedLeftFloatingPadding ?? 0) + (panel?.fixedRightFloatingPadding ?? 0)
        : (panel?.fixedTopFloatingPadding ?? 0) + (panel?.fixedBottomFloatingPadding ?? 0)
    readonly property int depth: extraDepth > 0 ? Math.min(panelDepth + extraDepth,
        Math.max(panelDepth, (vertical ? panel.width : panel.height) - fixedCrossPadding)) : panelDepth
    readonly property int extension: Math.max(0, depth - panelDepth)
    readonly property int edge: Plasmoid.location
    readonly property bool vertical: edge === PlasmaCore.Types.LeftEdge || edge === PlasmaCore.Types.RightEdge
    readonly property bool opposite: edge === PlasmaCore.Types.BottomEdge || edge === PlasmaCore.Types.RightEdge
    readonly property bool atScreenEdge: vertical || edge === PlasmaCore.Types.TopEdge || edge === PlasmaCore.Types.BottomEdge
    readonly property int sideAlignment: vertical
        ? (opposite ? Qt.AlignRight : Qt.AlignLeft)
        : (opposite ? Qt.AlignBottom : Qt.AlignTop)
    readonly property Item grid: ancestor(item => item instanceof GridLayout)
    readonly property Item panel: ancestor(item => item.containment?.plasmoid === Plasmoid.containment)
    // Mirror the native SVG bounds and opacity blend, including Plasma's floating animation.
    // https://github.com/KDE/plasma-desktop/blob/v6.8.2/desktoppackage/contents/views/Panel.qml
    readonly property point frameOrigin: panel?.floatingTranslucentItemOffset ?? Qt.point(0, 0)
    readonly property real frameWidth: vertical ? depth : Math.max(0,
        (panel?.width ?? 0) - (panel?.leftFloatingPadding ?? 0) - (panel?.rightFloatingPadding ?? 0))
    readonly property real frameHeight: vertical ? Math.max(0,
        (panel?.height ?? 0) - (panel?.topFloatingPadding ?? 0) - (panel?.bottomFloatingPadding ?? 0)) : depth
    readonly property bool floatingFrame: (panel?.floatingness ?? 0) !== 0
    readonly property real solidOpacity: panel?.panelOpacity ?? 0
    readonly property var appletSlots: Array.from(grid?.children ?? []).filter(item => item.applet?.plasmoid?.pluginName)
    // Plasma's model index is independent of the item positions being resized.
    readonly property var orderedSlots: appletSlots.slice().sort((a, b) => a.appletIndex - b.appletIndex)
    readonly property bool hideSpacerBackgrounds: Plasmoid.configuration.hideSpacerBackgrounds ?? false
    readonly property var spacerSlots: appletSlots.filter(item =>
        item.applet.plasmoid.pluginName === "org.kde.plasma.panelspacer")
    readonly property bool hasSpacerCutouts: hideSpacerBackgrounds
        && spacerSlots.some(item => item.visible && extent(item) > 0)
    readonly property real layoutOrigin: {
        if (!grid || !panel)
            return 0;

        const parentOrigin = grid.parent.mapToItem(panel, 0, 0);
        return along(grid) + (vertical ? parentOrigin.y - frameOrigin.y : parentOrigin.x - frameOrigin.x);
    }
    readonly property Item slot: appletSlots.find(item => item.applet === notch) ?? null
    readonly property int startIndex: orderedSlots.indexOf(slot)
    readonly property int endIndex: orderedSlots.findIndex((item, index) =>
        index > startIndex && item.applet.plasmoid.pluginName === "local.plasma.notchend")
    readonly property var notchWidgets: endIndex > startIndex && startIndex >= 0
        ? orderedSlots.slice(startIndex + 1, endIndex) : []
    readonly property var panelView: Window.window
    readonly property bool editing: (Plasmoid.containment?.corona?.editMode ?? false)
        || (panelView?.userConfiguring ?? false)
    readonly property bool active: !editing && !editSettle.running
        && panel !== null && panelView !== null && slot !== null
        && shape.canExtend && panelDepth > 0 && atScreenEdge
        && ((notchWidgets.length > 0 && (requestedDepth > panelDepth || shrinkToFit)) || hasSpacerCutouts)
    readonly property int extraDepth: active && notchWidgets.length > 0 ? requestedDepth - panelDepth : 0

    onEditingChanged: {
        if (editing)
            editSettle.stop();
        else
            editSettle.restart();
    }

    Timer {
        id: editSettle
        interval: 180
    }

    readonly property real sectionStart: notchWidgets.length
        ? Math.min(...notchWidgets.map(item => along(item))) : along(slot)
    readonly property real sectionEnd: notchWidgets.length
        ? Math.max(...notchWidgets.map(item => along(item) + extent(item))) : sectionStart
    readonly property int markerLength: editing ? 88 : 0

    Layout.minimumWidth: vertical ? -1 : markerLength
    Layout.preferredWidth: vertical ? -1 : markerLength
    Layout.maximumWidth: vertical ? Infinity : markerLength
    Layout.minimumHeight: vertical ? markerLength : -1
    Layout.preferredHeight: vertical ? markerLength : -1
    Layout.maximumHeight: vertical ? markerLength : Infinity

    function along(item) {
        return item ? (vertical ? item.y : item.x) : 0;
    }

    function extent(item) {
        return item ? (vertical ? item.height : item.width) : 0;
    }

    // Use the native task model rather than geometry, which depends on the fitted size.
    // https://github.com/KDE/plasma-desktop/blob/v6.8.2/applets/taskmanager/qml/main.qml
    function sizingUnits(wrapper) {
        const applet = wrapper.applet;
        const count = Math.max(1, applet.tasksModel?.count ?? 1);
        return applet.plasmoid.pluginName === "org.kde.plasma.taskmanager" ? count * 3 : count;
    }

    function normalMargin(wrapper, side, thickness) {
        // Use the same theme margins and small-panel cap as Plasma's AppletContainer.
        const cap = Math.floor(Math.max(1, thickness - Kirigami.Units.iconSizes.smallMedium) / 2);
        return Math.min(cap, wrapper.getMargins?.(side) ?? 0);
    }

    function ancestor(matches) {
        for (let item = parent; item; item = item.parent) {
            if (matches(item))
                return item;
        }
        return null;
    }

    // Select the Breeze frame whose indicator faces the physical screen edge.
    // Breeze names its variants by the opposite edge, with no prefix for south.
    // https://github.com/KDE/plasma-desktop/blob/v6.8.2/applets/taskmanager/qml/Task.qml
    function collectTaskFrames(item, frames) {
        if (!item)
            return;

        if (item.basePrefix !== undefined && item.imagePath === "widgets/tasks" && item.parent?.inPopup === false) {
            frames.push(item);
            return;
        }

        for (const child of Array.from(item.children))
            collectTaskFrames(child, frames);
    }

    Instantiator {
        model: {
            const frames = [];
            if (!notch.active)
                return frames;
            for (const item of notch.appletSlots) {
                const plugin = item.applet.plasmoid.pluginName;
                if (plugin === "org.kde.plasma.icontasks" || plugin === "org.kde.plasma.taskmanager")
                    notch.collectTaskFrames(item.applet, frames);
            }
            return frames;
        }
        delegate: Binding {
            required property Item modelData
            target: modelData
            property: "prefix"
            value: {
                const edgePrefix = notch.vertical ? (notch.opposite ? "west-" : "east-")
                    : (notch.opposite ? "north-" : "");
                const state = modelData.basePrefix;
                const prefixes = state ? [edgePrefix + state, state] : [""];
                if (modelData.isHovered)
                    prefixes.unshift(edgePrefix + "hover", "hover");
                return prefixes;
            }
            when: notch.active
        }
    }

    Instantiator {
        model: notch.appletSlots.filter(item => {
            const plugin = item.applet.plasmoid.pluginName;
            return item !== notch.slot
                && plugin !== "local.plasma.notchend"
                && plugin !== "org.kde.plasma.panelspacer"
                && plugin !== "org.kde.plasma.marginsseparator";
        })

        delegate: Item {
            id: widgetSizing
            required property Item modelData
            readonly property bool inNotch: notch.notchWidgets.includes(modelData)
            readonly property int frameDepth: inNotch ? Math.min(notch.depth, notch.fittedWidgetDepth) : notch.panelDepth
            readonly property bool limitLength: inNotch && notch.shrinkToFit
            readonly property int lengthLimit: notch.fitUnitSize * notch.sizingUnits(modelData)
            readonly property int nearMargin: notch.normalMargin(modelData, notch.vertical ? "left" : "top", frameDepth)
            readonly property int farMargin: notch.normalMargin(modelData, notch.vertical ? "right" : "bottom", frameDepth)
            readonly property int widgetDepth: Math.max(1, frameDepth - nearMargin - farMargin)
            readonly property int extraMargin: inNotch ? Math.floor((notch.depth - frameDepth) / 2) : 0
            readonly property bool sizeCrossAxis: notch.active && (notch.extension > 0 || limitLength)

            Binding {
                target: widgetSizing.modelData.Layout
                property: "alignment"
                value: notch.sideAlignment
                when: widgetSizing.sizeCrossAxis
            }

            Instantiator {
                model: ["minimumWidth", "preferredWidth", "maximumWidth", "leftMargin", "rightMargin",
                        "minimumHeight", "preferredHeight", "maximumHeight", "topMargin", "bottomMargin"]

                delegate: Binding {
                    required property int index
                    required property string modelData
                    target: widgetSizing.modelData.Layout
                    property: modelData
                    readonly property bool crossAxis: notch.vertical === (index < 5)
                    readonly property bool marginProperty: modelData.endsWith("Margin")
                    value: {
                        if (!crossAxis) {
                            const nativeSize = widgetSizing.modelData.applet.Layout[modelData];
                            return nativeSize > 0 ? Math.min(nativeSize, widgetSizing.lengthLimit) : widgetSizing.lengthLimit;
                        }
                        if (!marginProperty)
                            return widgetSizing.widgetDepth;

                        const farEdge = modelData === "rightMargin" || modelData === "bottomMargin";
                        const margin = farEdge ? widgetSizing.farMargin : widgetSizing.nearMargin;
                        return margin + (farEdge === notch.opposite ? widgetSizing.extraMargin : 0);
                    }
                    when: crossAxis ? widgetSizing.sizeCrossAxis
                        : notch.active && widgetSizing.limitLength && !marginProperty
                }
            }
        }
    }

    // Stretch the native widget layout only after the compositor sizes the surface.
    Binding {
        target: notch.panel?.containment ?? null
        property: "anchors.bottomMargin"
        value: -notch.extension
        when: notch.active && !notch.vertical && notch.extension > 0
    }

    Binding {
        target: notch.panel?.containment ?? null
        property: "anchors.rightMargin"
        value: -notch.extension
        when: notch.active && notch.vertical && notch.extension > 0
    }

    Geometry.NotchMask {
        id: shape

        parent: notch.panel ?? notch
        width: notch.active ? notch.frameWidth : 0
        height: notch.active ? notch.frameHeight : 0
        themeEffectsEnabled: notch.active
        baseSurfaceDepth: notch.panelDepth + notch.fixedCrossPadding
        extraSurfaceDepth: notch.extraDepth
        frameOrigin: notch.frameOrigin
        vertical: notch.vertical
        opposite: notch.opposite
        barDepth: notch.panelDepth
        notchDepth: notch.depth
        nativeMask: !notch.active ? null : (notch.solidOpacity === 1 ? solidFrame.mask : translucentFrame.mask)
        sectionLength: notch.shrinkToFit ? notch.notchLength
            : Math.max(56, notch.notchLength, notch.sectionEnd - notch.sectionStart + notch.sectionPadding)
        sectionCenter: notch.active ? (notch.sectionStart + notch.sectionEnd) / 2 + notch.layoutOrigin : 0
        spacerThickness: Plasmoid.configuration.spacerThickness ?? 0
        spacerSpans: notch.active && notch.hasSpacerCutouts
            ? notch.spacerSlots.filter(item => item.visible && notch.extent(item) > 0).map(item =>
                Qt.point(notch.along(item) + notch.layoutOrigin, notch.extent(item)))
            : []
    }

    ShaderEffectSource {
        id: maskTexture

        sourceItem: shape
        hideSource: true
        visible: false
    }

    // Plasma's NoBackground hint removes the rectangular compositor shadow.
    // Our replacement frames still use the same Plasma theme SVGs.
    // https://github.com/KDE/plasma-workspace/blob/v6.8.2/shell/panelview.cpp
    Binding {
        target: Plasmoid.containment
        property: "backgroundHints"
        value: PlasmaCore.Types.NoBackground
        when: notch.active
    }

    Binding {
        target: notch.panel
        property: "panelMask"
        value: shape.region
        when: notch.active
    }

    Connections {
        target: notch.active ? notch.panelView : null
        function onBackgroundHintsChanged() { shape.scheduleThemeEffects(); }
        function onVisibleChanged() { shape.scheduleThemeEffects(); }
        function onXChanged() { shape.scheduleThemeEffects(); }
        function onYChanged() { shape.scheduleThemeEffects(); }
    }

    Connections {
        target: notch.active ? notch.panel : null
        function onFloatingnessChanged() { shape.scheduleThemeEffects(); }
    }

    // Reproduce the borders of the native frame. PanelView uses NoBorder
    // while the replacement is active to suppress its rectangular shadow.
    function frameBorders() {
        const screen = panelView?.screenGeometry;
        let borders = KSvg.FrameSvg.AllBorders;
        if (floatingFrame || !screen)
            return borders;

        const x = panelView.x + frameOrigin.x;
        const y = panelView.y + frameOrigin.y;
        if (edge === PlasmaCore.Types.TopEdge || y <= screen.y)
            borders &= ~KSvg.FrameSvg.TopBorder;
        if (edge === PlasmaCore.Types.BottomEdge || y + frameHeight >= screen.y + screen.height)
            borders &= ~KSvg.FrameSvg.BottomBorder;
        if (edge === PlasmaCore.Types.LeftEdge || x <= screen.x)
            borders &= ~KSvg.FrameSvg.LeftBorder;
        if (edge === PlasmaCore.Types.RightEdge || x + frameWidth >= screen.x + screen.width)
            borders &= ~KSvg.FrameSvg.RightBorder;
        return borders;
    }

    Item {
        id: frameLayer

        parent: notch.panel ?? notch
        x: notch.frameOrigin.x
        y: notch.frameOrigin.y
        width: notch.frameWidth
        height: notch.frameHeight
        visible: notch.active
        z: -1
        readonly property int borders: notch.frameBorders()

        KSvg.FrameSvgItem {
            id: translucentFrame
            anchors.fill: parent
            visible: false
            imagePath: "widgets/panel-background"
            enabledBorders: frameLayer.borders
        }

        KSvg.FrameSvgItem {
            id: solidFrame
            anchors.fill: parent
            visible: false
            imagePath: "solid/widgets/panel-background"
            enabledBorders: frameLayer.borders
        }

        ShaderEffectSource {
            id: translucentTexture
            sourceItem: translucentFrame
            visible: false
        }

        ShaderEffectSource {
            id: solidTexture
            sourceItem: solidFrame
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            visible: notch.solidOpacity !== 1
            source: translucentTexture
            maskEnabled: true
            maskSource: maskTexture
            autoPaddingEnabled: false
        }

        MultiEffect {
            anchors.fill: parent
            visible: notch.solidOpacity !== 0
            opacity: notch.solidOpacity
            source: solidTexture
            maskEnabled: true
            maskSource: maskTexture
            autoPaddingEnabled: false
        }
    }
}
