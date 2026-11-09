// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "NotchGeometry" as Geometry

Kirigami.FormLayout {
    id: page
    readonly property var panelView: typeof plasmoid === "undefined" ? null : Geometry.PanelLookup.viewForApplet(plasmoid)
    readonly property int panelDepth: panelView?.thickness ?? 0
    property alias cfg_notchDepth: depth.value
    property alias cfg_minNotchLength: lengthControl.value
    property alias cfg_growOnOverflow: grow.checked
    property alias cfg_hideSpacerBackgrounds: hideSpacers.checked
    property alias cfg_spacerThickness: spacerThickness.value

    Controls.SpinBox {
        id: depth
        Kirigami.FormData.label: i18n("Notch depth (px):")
        from: Math.max(1, page.panelDepth)
        to: Math.max(from, 160)
        editable: true
    }

    Controls.SpinBox {
        id: lengthControl
        Kirigami.FormData.label: i18n("Notch length (px):")
        from: 0
        to: 1800
        editable: true
    }

    Controls.Label {
        text: i18n("Use 0 to fit the contents automatically.")
        wrapMode: Text.WordWrap
        Layout.preferredWidth: 330
        Layout.maximumWidth: 330
    }

    Controls.CheckBox {
        id: grow
        enabled: lengthControl.value > 0
        text: i18n("Grow notch if the widgets don’t fit")
    }

    Controls.CheckBox {
        id: hideSpacers
        text: i18n("Hide backgrounds behind panel spacers")
    }

    Controls.SpinBox {
        id: spacerThickness
        Kirigami.FormData.label: i18n("Spacer thickness (px):")
        enabled: hideSpacers.checked
        from: 0
        to: page.panelDepth > 0 ? page.panelDepth : 160
        editable: true
    }
}
