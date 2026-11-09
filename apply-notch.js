// Run through Plasma's evaluateScript after installing both packages.
// Example: applyNotch(panelId, firstWidgetId, lastWidgetId);
function applyNotch(panelId, firstWidgetId, lastWidgetId = firstWidgetId) {
    const panel = panelById(panelId);
    const first = panel?.widgetById(firstWidgetId);
    const last = panel?.widgetById(lastWidgetId);
    if (!first || !last || first.index > last.index)
        throw new Error("Expected a contiguous range of widgets in panel " + panelId);

    const startPlugin = "local.plasma.notchpanel";
    const endPlugin = "local.plasma.notchend";
    if (panel.widgets(startPlugin).length || panel.widgets(endPlugin).length)
        throw new Error("The panel already has a notch marker");

    const firstIndex = first.index;
    panel.addWidget(startPlugin).index = firstIndex;
    panel.addWidget(endPlugin).index = last.index + 1;
}
