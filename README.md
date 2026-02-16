# Task Switcher
Options are not compatible with previous version.

Jump to:
- [Description](#description)
- [Dependencies](#dependencies)
- [Features](#features)
- [How to Use](#how-to-use)
- [Methods](#methods)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Customization](#customization)
- [Additional Information](#additional-information)
- [Bugs](#bugs)

___


> ##### **Disclaimer:** ~~AI was used for most of the graphics-related things as I am not familiar enough with the GDI+ api.~~ Since the initial upload, I've learned how to use GDI+ enough to get by and the refactored UI was all done by me. AI still had a hand in certain methods I never would have been able to figure out on my own, such as pretty much everything related to the icons and getting application product names.


---


### Description:
A replacement for Windows Alt+Tab with a visual window switcher. Instead of cycling through a small preview, this displays all open windows in a larger interface where you can search, preview, and select the window you want.

The script is meant to be a faster means of activating open programs. It gives you a list of all open windows instead of some ever-changing preview with too many images to quickly discern what you want. If there are more programs open than the maxRowVisible property, the window becomes scrollable. You can navigate and activate a window using keyboard keys or the mouse.

You can type to search through the open programs and get to what you need even faster. Search/filter windows by title or name.
> **Note:** The name criteria varies: First it looks for a custom name if one is passed to `OverrideWindowNames()`. If the user hasn't passed one, then it checks for a product name. Finally, if one isn't found, it uses the exe name.


### Dependencies:
- AHK v2.1 (currently in alpha but very stable in my 2+ years experience using it)
- [Gdip_All.ahk](https://github.com/buliasz/AHKv2-Gdip/blob/master/Gdip_All.ahk) Just be sure to change the path when you `#Include` it.


---


##### Example image using default options (not pretty because the colors are auto-determined):
![img](https://github.com/CrashGit/task-switcher/blob/refactor/default-example.png)

##### Example image using customization options in the example file:
![img](https://github.com/CrashGit/task-switcher/blob/refactor/customized-example.png)

##### Example image using customizations options haphazardly:
![img](https://github.com/CrashGit/task-switcher/blob/refactor/customized-example2.png)


## Features

| Feature | Description |
|---------|-------------|
| **Search** | Type to filter windows by title or name. Case-insensitive. |
| **Window Preview** | See a live thumbnail of the selected window before switching to it. |
| **Window Info Panel** | View metadata about the window: HWND, PID, dimensions, transparency, always-on-top status, etc. |
| **Close Windows** | Close a window directly from the switcher (middle-click on a row, click the X button, or press `Delete`). |
| **Keyboard Navigation** | `Up/Down` arrow keys to move between windows, Enter to select, Escape to close. |
| **Row Numbers** | Press 1-9 or 0 to quickly select a window by number. |
| **Sorted Windows** | Option to show windows alphabetically instead of by recent use (default). |
| **Multi-monitor Support** | Open the switcher on a specific monitor. |
| **Mouse Support** | Click or scroll to navigate. Hovering over a window shows it in the preview. |
| **List/Panel Resizing** | Drag the partition between the list and panel to resize. |
| **Icon Caching** | Icons are cached for faster performance on repeated opens. |
| **Auto Colors** | Colors can be set to "Auto" to automatically adjust based on background. |

## How to Use

First make sure to alter the dependency path (or remove, if you `#Include` the dependency path in another file) to the GDI+ dependency library `Gdip_All.ahk` so it points to the correct destination:

```AutoHotkey
| Inside task switcher.ahk script

#Include ..\..\lib\Gdip_All.ahk     ; change this path
```

Then call it from a hotkey:

```AutoHotkey
#Requires AutoHotkey v2.0
#SingleInstance
#Include path\to\TaskSwitcher.ahk

$>^LCtrl::TaskSwitcher.ToggleMenu()
$<^RCtrl::TaskSwitcher.ToggleMenu()
```

Or use the built-in Alt+Tab replacement:

```AutoHotkey
TaskSwitcher.AltTabReplacement('On')
```

This makes Alt+Tab open the switcher as long as Alt remains press down. While the switcher is open, Alt+Tab cycles through windows.

> **Note:** Hotkeys pressed while the menu is open (especially relevant to the Niche methods and `CloseMenu()`), require the keyboard hook to work.

*\*See the `example.ahk` file for more examples of various things.*


## Methods
### Necessary:
```AutoHotkey
TaskSwitcher.ToggleMenu()               ; Open or close
; or
TaskSwitcher.OpenMenu()                 ; Open the switcher
TaskSwitcher.CloseMenu()                ; Close the switcher
```

### Optional:
```AutoHotkey
TaskSwitcher.OnWindowActivate(Callback) ; Run user code when window is activated
TaskSwitcher.OnMenuOpen(Callback)       ; Run user code when menu opens
TaskSwitcher.OverrideWindowNames(exe, name, exe2, name2, ...) ; Custom names for windows
```

### Niche:
```AutoHotkey
TaskSwitcher.ActivateWindow()           ; Switch to selected window
TaskSwitcher.SelectNextWindow()         ; Navigate down
TaskSwitcher.SelectPreviousWindow()     ; Navigate up
TaskSwitcher.SelectFirstRow()           ; Jump to first window
TaskSwitcher.SelectLastRow()            ; Jump to last window
TaskSwitcher.TogglePanel()              ; Show/hide info panel
```

## Keyboard Shortcuts

- **Arrow Up/Down** — Navigate windows in list
- **Home/End** — Jump to first/last window in list
- **1-9, 0** — Select window in list by row number (if `rowNumbers: true`)
- **Enter** — Switch to keyboard-selected window
- **Escape** — Close switcher (or clear search if `escapeAlwaysClose: false`)
- **Backspace** — Delete character from search
- **Ctrl+Backspace** — Clear entire search
- **Tab** — Toggle panel
- **Delete** — Close keyboard-selected window
- **Mouse Wheel** — Scroll through list
- **Middle-Click** — Close window the mouse cursor is over
- **Arrow Left/Right** — Cycle through panel tabs

## Customization

You can customize the switcher by passing options:

```ahk
TaskSwitcher({
    mainColor: 0xFF1E1E1E,
    menuWidth: 1200,
    rowHeight: 80,
    ...
})
```

> **Note:** The script makes little effort to ensure everything looks nice. For example, if you set `iconSize: 300` or `rowHeight: 10`, you're not going to have a good time. Use your best judgement and use at your own discretion.


### All Customizable Options

<details>
<summary><strong>Size & Spacing</strong></summary>

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `menuWidth` | Integer | 1000 | Width of the entire switcher in pixels |
| `rowHeight` | Integer | 75 | Height of each window row |
| `marginX` | Integer | 12 | Left/right padding |
| `marginY` | Integer | 12 | Top/bottom padding |
| `maxVisibleRows` | Integer | 12 | How many rows show before scrolling |
| `iconSize` | Integer | 32 | Size of window icons |
| `closeButtonSize` | Integer | 24 | Size of close button |
| `rowDividerHeight` | Integer | 1 | Thickness of line between rows |
| `partitionWidth` | Integer | 2 | Thickness of the list/panel divider |
| `defaultPanelSizePercent` | Float | 0.5 | Initial size of info panel (0.0-1.0) |

</details>

<details>
<summary><strong>Behavior</strong></summary>

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `monitor` | Integer | Primary | Which monitor to open on |
| `coordinates` | String/Object | 'Center' | Where to open: 'Center', 'Recenter', 'Mouse', or {x, y} |
| `wrapRowSelection` | Boolean | true | Loop to start/end when navigating |
| `alwaysHighlightFirstRow` | Boolean | true | Auto-select first row when filtering |
| `showAllCloseButtons` | Boolean | false | Show X button on all rows, or only hovered row |
| `escapeAlwaysClose` | Boolean | false | When false, escape will prioritize clearing the search field, requiring a second press to close the menu |
| `showPanelOnOpen` | Boolean | true | Show the panel on initial opening |
| `preventResize` | Boolean | true | Menu always shows max visible rows |
| `closeOnOutsideClick` | Boolean | true | Clicking outside closes the switcher |
| `clickPassthrough` | Boolean | false | Allow clicks outside to pass through to windows behind |
| `rowNumbers` | Boolean | true | Enable row numbers 1-9, 0 for quick selection |
| `mouseRowHoverUpdatesPanel` | Boolean | true | Preview updates when hovering with mouse |
| `fullLengthDividers` | Boolean | false | Divider lines span full width or just the content |
| `fullLengthPartition` | Boolean | true | Partition line spans full height or just content |

</details>

<details>
<summary><strong>Colors</strong></summary>

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `mainColor` | Hex | 0xFF333333 | Background of window rows |
| `rowTextColor` | 'Auto'/Hex | 'Auto' | Text color in rows |
| `rowSelectedColor` | 'Auto'/Hex/Array | 'Auto' | Highlight color of selected row |
| `mouseRowHoverBackgroundColor` | 'Auto'/Hex/Array | 'Auto' | Color when mouse hovers over row |
| `mouseRowSelectedBackgroundColor` | 'Auto'/Hex/Array | 'Auto' | Color when row is clicked |
| `rowDividerColor` | 'Auto'/Hex | 'Auto' | Divider line color |
| `topBarColor` | Hex | mainColor | Background of section behind the search bar |
| `searchBackgroundColor` | 'Auto'/Hex | 'Auto' | Search box background |
| `searchTextColor` | 'Auto'/Hex | 'Auto' | Typed text color |
| `placeholderTextColor` | 'Auto'/Hex | 'Auto' | Placeholder text color |
| `closeBackgroundColor` | 'Auto'/Hex | 'Auto' | Close button background |
| `closeHoverBackgroundColor` | 'Auto'/Hex | 'Auto' | Close button on hover |
| `closeXColor` | 'Auto'/Hex | 'Auto' | X icon color |
| `closeXHoverColor` | 'Auto'/Hex | 'Auto' | X icon on hover |
| `panelBackgroundColor` | 'Auto'/Hex | 'Auto' | Info panel background |
| `panelHeaderTextColor` | 'Auto'/Hex | 'Auto' | Section headers in panel |
| `panelBodyTextColor` | 'Auto'/Hex | 'Auto' | Body text in panel |
| `panelIconBackgroundColor` | 'Auto'/Hex | 'Auto' | Panel toggle button background |
| `panelIconLinesColor` | 'Auto'/Hex | 'Auto' | Panel toggle button icon |
| `partitionColor` | 'Auto'/Hex | 'Auto' | Divider line between list and panel |
| `panelTabTextColor` | 'Auto'/Hex | 'Auto' | Panel tab text color |
| `panelTabActiveColor` | 'Auto'/Hex | 'Auto' | Panel tab active color |
| `panelTabInActiveColor` | 'Auto'/Hex | 'Auto' | Panel tab natural state color |
| `panelTabHoverColor` | 'Auto'/Hex | 'Auto' | Panel tab mouse hover color |
| `panelTabSelectedColor` | 'Auto'/Hex | 'Auto' | Panel tab mouse-clicked color |
</details>

<details>
<summary><strong>Scrolling</strong></summary>

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `scrollSmoothness` | Float | 0.35 | Lower = smoother, higher = snappier |
| `scrollPixelOffset` | Integer | 40 | How many pixels to scroll per wheel tick |
</details>

&nbsp;

> **Color Format:** Use `0xAARRGGBB` format for colors (e.g. `0xFF00FF00` is opaque green). Set to `"Auto"` to have a contrasting color automatically determined. The only color option where this is different is mainColor which is the dominant menu color; which when set to `Auto`, will determine a light or dark color based on the system theme light/dark mode.

**Gradients:** `rowSelectedColor`, `mouseRowHoverBackgroundColor`, and `mouseRowSelectedBackgroundColor` can be arrays of 2-3 colors for a gradient effect:
```ahk
rowSelectedColor: [0xFF1E1E1E, 0xFF3D3D3D]
```
&nbsp;

## Additional Information

- Use `OverrideWindowNames()` if a window name is incorrect or missing. For the life of me, I could not properly retrieve the name for Steam so this is what I use to display Steam instead of steamwebhelper.
- The info panel shows a live preview unless the window is minimized (preview not available for minimized windows).
- The switcher respects virtual desktops on Windows 10+.
- When using recent sorting order, always-on-top windows always show up first. No way around this without potentially complex window tracking.


## Bugs

- When under heavy load (such as playing a game), there's a chance that closing the menu doesn't stop the InputHook. This causes stuff you typed to show up in the search bar when you re-open the menu. Minor issue. Use Ctrl+Backspace or re-open the menu to clear the search bar.