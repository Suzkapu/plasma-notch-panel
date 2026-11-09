// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents

PlasmoidItem {
    id: marker

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool editing: (Plasmoid.containment?.corona?.editMode ?? false)
        || (Window.window?.userConfiguring ?? false)
    readonly property int markerLength: editing ? 88 : 0

    Layout.minimumWidth: vertical ? -1 : markerLength
    Layout.preferredWidth: vertical ? -1 : markerLength
    Layout.maximumWidth: vertical ? Infinity : markerLength
    Layout.minimumHeight: vertical ? markerLength : -1
    Layout.preferredHeight: vertical ? markerLength : -1
    Layout.maximumHeight: vertical ? markerLength : Infinity

    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {
        Rectangle {
            anchors.centerIn: parent
            visible: marker.editing
            rotation: marker.vertical ? 90 : 0
            width: 78
            height: 25
            radius: 5
            color: "#145f85"
            PlasmaComponents.Label {
                anchors.centerIn: parent
                color: "white"
                text: i18n("Notch end")
            }
        }
    }
}
