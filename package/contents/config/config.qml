// SPDX-License-Identifier: GPL-3.0-or-later
import org.kde.plasma.configuration

// https://develop.kde.org/docs/plasma/widget/configuration/
ConfigModel {
    ConfigCategory {
        name: i18n("Notch")
        icon: "preferences-desktop"
        source: "configNotch.qml"
    }
}
