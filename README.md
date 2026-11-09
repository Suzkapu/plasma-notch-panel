# Notch Panel for Plasma 6 on Wayland

Notch Panel gives an existing Plasma panel a deeper section with gently sloping shoulders. It follows all four screen edges and uses the active Plasma style’s background and opacity settings. The shallow part of the panel keeps Plasma’s configured thickness. The notch grows inward from it, including when floating.

Build the geometry helper with Qt 6 (including the Wayland client private headers), Plasma, LayerShellQt, and KDE Frameworks development headers, then install both widgets from this directory.

```sh
cmake -S geometry -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
cmake --install build --prefix "$PWD/package/contents/ui/NotchGeometry"
```

The helper supplies the same shape for the themed background and the compositor's blur and contrast regions. The rectangular stock panel shadow is suppressed while the notch is active.

```sh
kpackagetool6 --type Plasma/Applet --install package
kpackagetool6 --type Plasma/Applet --install end-marker
```

Use `--upgrade` for a package that is already installed. Rebuild the helper after a Qt Wayland update because it uses Qt’s private surface API.

1. In Plasma's panel edit mode, add **Notch Panel** and **Notch End**.
2. Drag the widgets you want into the gap between **Notch start** and **Notch end**. They remain native panel widgets and can be rearranged normally.
3. To center the section, place an expanding Plasma Panel Spacer on each side. Plasma distributes the space between the spacers.
4. Open **Configure Notch Panel** from the start marker. **Notch depth** sets the widget size, with the native panel thickness as the minimum depth. **Notch length** is measured along the edge. Use **0** to fit automatically. With a nonzero length, check **Grow notch if the widgets don’t fit** to extend the section, or clear it to shrink the widgets to fit.

5. Enable **Hide backgrounds behind panel spacers** for rounded spacer gaps. **Spacer thickness** controls how much of the bar remains behind spacers. Use **0 px** for a fully transparent gap.

The markers are visible during editing. The notch and its size overrides pause so Plasma can show its native layout and handle moving and resizing widgets. The notch returns when you leave edit mode. Breeze's running-app indicators face the outside edge.

The notch uses the panel item hierarchy in Plasma 6.8. Plasma still controls panel position, length, baseline thickness, visibility, and the area reserved for maximized windows. The extra notch depth can overlap a maximized window in modes that reserve only the normal panel thickness. The companion `apply-notch.js` provides a scripting helper for bracketing a contiguous group of existing widgets by ID.

- [Plasma widget setup](https://develop.kde.org/docs/plasma/widget/setup/)
- [Plasma widget configuration](https://develop.kde.org/docs/plasma/widget/configuration/)
- [Plasma scripting API](https://develop.kde.org/docs/plasma/scripting/api/)
- [KDE panel view source](https://github.com/KDE/plasma-desktop/blob/master/desktoppackage/contents/views/Panel.qml)

To uninstall the widgets, use `kpackagetool6 --type Plasma/Applet --remove` with `local.plasma.notchpanel` and `local.plasma.notchend`.
