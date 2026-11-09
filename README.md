# Notch Panel for Plasma 6 on Wayland

<img src="assets/notch-panel-icon.png" alt="Notch Panel icon" width="112" height="112">

Notch Panel adds a deeper section to an existing KDE Plasma panel. Give your task manager or other widgets more room while the launcher, system tray, and clock stay at the panel’s regular size. The notch follows the active Plasma theme and opacity settings, works on all four screen edges, and supports floating panels.

## Install from a downloaded file

1. Download the `notch-panel-….plasmoid` and `notch-end.plasmoid` files from [GitHub Releases](../../releases).
2. In Plasma’s edit mode, open **Add Widgets → Get New Widgets → Install Widget From Local File** and select the first downloaded file. Repeat for the second file.
3. Add both widgets to the panel using the setup steps below.

The prebuilt start widget targets x86-64 Arch Linux. Its native helper needs a compatible Plasma stack and the Qt version in the filename. Check the release’s `notch-panel-build-info.txt` for the exact build packages, or [build both widgets locally](CONTRIBUTING.md#build-and-install) for a different setup.

## Set up the notch

1. Right-click your panel and enter Plasma’s edit mode.
2. Add the **Notch Panel** and **Notch End** widgets. In edit mode, they appear as **Notch start** and **Notch end**.
3. Drag the two markers around the widgets you want in the deeper section. Only the widgets between the markers go in the notch. To center it, put an expanding **Panel Spacer** outside each marker.

   ```text
   Launcher | Spacer | Notch start | Icons-only Task Manager | Notch end | Spacer | System Tray | Clock
   ```

4. Open **Configure Notch Panel** from the start marker. Set **Notch depth** higher than the regular panel thickness to make the section deeper. Leave **Notch length** at **0** to fit the widgets automatically.
5. Exit edit mode. The markers disappear and the notch takes their place around the selected widgets. To move widgets in or out later, return to edit mode.

## Adjust the shape

- Set a nonzero **Notch length** for a specific length along the panel. Enable **Grow notch if the widgets don’t fit** to let it expand, or clear it to shrink the widgets to fit.
- Enable **Hide backgrounds behind panel spacers** for rounded gaps. Set **Spacer thickness** to **0 px** for a full gap or raise it to leave a thin strip of panel.

Plasma controls the area reserved for maximized windows. If it reserves only the regular panel thickness, the deeper notch can overlap a maximized window.
