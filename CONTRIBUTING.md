# Contributing

## Build and install

Use a KDE Plasma 6.8 Wayland session to test the widget. The geometry helper needs a C++17 compiler, CMake 3.22 or newer, Qt 6 Quick and QML development files, Qt Wayland client private headers, Plasma and PlasmaQuick development files, LayerShellQt, and the KDE Frameworks development files listed in [geometry/CMakeLists.txt](geometry/CMakeLists.txt).

Run these commands from the repository root.

```sh
cmake -S geometry -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
cmake --install build --prefix "$PWD/package/contents/ui/NotchGeometry"

kpackagetool6 --type Plasma/Applet --install package
kpackagetool6 --type Plasma/Applet --install end-marker
```

Use `--upgrade` in place of `--install` for widgets you already have installed. If Plasma Shell has already loaded the geometry helper, restart it after installing a rebuilt copy. Rebuild the helper after a Qt Wayland update because it uses Qt’s private surface API.

Follow [the panel setup steps](README.md#set-up-the-notch) to try the widgets. The [apply-notch.js](apply-notch.js) helper can also bracket a contiguous group of existing widgets by ID through Plasma’s scripting interface.

## Package for local-file installation

With the build dependencies installed, run `bash scripts/package-plasmoids.sh` from the repository root. It builds the helper, creates two `.plasmoid` files in `build/dist/`, and checks that KPackage can install both files and QML can load the packaged helper.

GitHub Actions builds the packages on x86-64 Arch Linux and uploads them as workflow artifacts. Pushing a `v*` tag also prepares a draft GitHub release with the packages and build versions attached. Tags such as `v0.1.0` are marked as prereleases. Review and publish the draft to make the files available under Releases.

The start widget includes a compiled Qt helper. KDE’s [C++ widget guide](https://develop.kde.org/docs/plasma/widget/c-api/) explains the Store’s limits for widgets that require compilation. Check whether the Store accepts the prebuilt helper and can handle its platform requirements before offering it there.

## Uninstall

```sh
kpackagetool6 --type Plasma/Applet --remove local.plasma.notchpanel
kpackagetool6 --type Plasma/Applet --remove local.plasma.notchend
```

## References

- [Plasma widget setup](https://develop.kde.org/docs/plasma/widget/setup/)
- [Plasma widget configuration](https://develop.kde.org/docs/plasma/widget/configuration/)
- [Plasma scripting API](https://develop.kde.org/docs/plasma/scripting/api/)
- [KDE panel view source](https://github.com/KDE/plasma-desktop/blob/master/desktoppackage/contents/views/Panel.qml)
