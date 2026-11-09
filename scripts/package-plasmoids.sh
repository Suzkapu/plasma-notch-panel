#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
output="$PWD/build/dist"
mkdir -p "$output"
work="$(mktemp -d "$PWD/build/package.XXXXXX")"
trap 'rm -rf "$work"' EXIT

qt_version="$(pkg-config --modversion Qt6WaylandClient)"
panel_package="notch-panel-$(uname -m)-qt${qt_version}.plasmoid"
end_package=notch-end.plasmoid

cp -R package end-marker "$work/"
cmake -S geometry -B "$work/geometry" -DCMAKE_BUILD_TYPE=Release
cmake --build "$work/geometry" --parallel
cmake --install "$work/geometry" --prefix "$work/package/contents/ui/NotchGeometry"

archive_widget() {
    local package="$1"
    local archive="$2"
    cp LICENSE "$work/$package/"
    (
        cd "$work/$package"
        cmake -E tar cf "$work/$archive" --format=zip metadata.json contents LICENSE
    )
}

archive_widget package "$panel_package"
archive_widget end-marker "$end_package"

# Exercise the same package type as Plasma's local-file installer in a temporary profile.
export XDG_DATA_HOME="$work/data"
export XDG_CONFIG_HOME="$work/config"
export XDG_CACHE_HOME="$work/cache"
export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND=software

kpackagetool6 --type Plasma/Applet --install "$work/$panel_package"
kpackagetool6 --type Plasma/Applet --install "$work/$end_package"

plasmoids="$XDG_DATA_HOME/plasma/plasmoids"
test -f "$plasmoids/local.plasma.notchend/contents/ui/main.qml"
probe="$plasmoids/local.plasma.notchpanel/contents/ui/check-geometry.qml"
cat > "$probe" <<'QML'
import QtQuick
import "NotchGeometry" as Geometry

Geometry.NotchMask {
    width: 200
    height: 40
    Component.onCompleted: Qt.callLater(Qt.quit)
}
QML
timeout 20 "$(pkg-config --variable=bindir Qt6Core)/qmlscene" "$probe"

mv "$work/$panel_package" "$work/$end_package" "$output/"
printf 'Packages written to %s\n' "$output"
