# Task Switcher
> Options are not compatible with previous version.

Jump to:
- [Description](#description)
- [Dependencies](#dependencies)
- [Features](#features)
- [How to Use](#how-to-use)
- [Methods](#methods)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Customization](#customization)
- [Additional Information](#additional-information)
- [Known Issues](#known-issues)


___


> ##### **Disclaimer:** ~~AI was used for most of the graphics-related things as I am not familiar enough with the GDI+ api.~~ Since the initial upload, I've learned how to use GDI+ enough to get by and the refactored UI was all done by me. AI still had a hand in certain methods I never would have been able to figure out on my own, such as pretty much everything related to the icons and getting application product names.


---


### Description:
A replacement for Windows `Alt+Tab` with a visual window switcher. Instead of cycling through a small window preview, this displays all open windows in a list where you can search, preview, and select the window you want.

The script is meant to be a faster means of activating open programs. It gives you a list of all open windows instead of some ever-changing preview with too many images to quickly discern what you want. If there are more programs open than the `maxRowVisible` property, the window becomes scrollable. You can navigate and activate a window using keyboard keys or the mouse.

You can type to search through the open programs and get to what you need even faster. Search/filter windows by title or name.
> **Note:** The name criteria varies: First it looks for a custom name if one is passed to `OverrideWindowNames()`. If the user hasn't passed one, then it checks for a product name. Finally, if one isn't found, it uses the exe name.


### Dependencies:
- AHK v2.1 alpha-23 (currently in alpha but very stable in my 2+ years experience using it)
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
| **Keyboard Navigation** | `Up/Down` arrow keys to move between windows, Enter to select, `Escape` to close. |
| **Row Numbers** | Press `1-9` or `0` to quickly select a window by number. |
| **Sorted Windows** | Option to show windows alphabetically instead of by recent use (default). |
| **Multi-monitor Support** | Open the switcher on a specific monitor. |
| **Mouse Support** | Click or scroll to navigate. Hovering over a window shows it in the preview. |
| **List/Panel Resizing** | Drag the partition between the list and panel to resize. |
| **Auto Colors** | Colors can be set to `Auto` to automatically adjust based on background. |

## How to Use

First go to the [Dependencies](#dependencies) section to make sure you have everything. Be sure to alter the path to the GDI+ library you downloaded (`Gdip_All.ahk`) in version of `task-switcher.ahk` so it points to the correct destination:

```AutoHotkey
| Inside task-switcher.ahk script

#Include ..\..\lib\Gdip_All.ahk     ; change this path
```

Make an `#Import` call to the path of `task-switcher.ahk` with the wildcard parameter (make sure the path is quoted):

```AutoHotkey
| Inside your personal script

#Import 'path\to\task-switcher.ahk' {*}
```

Then call it from a hotkey. The end result in your script should look similar to:

```AutoHotkey
| Inside your personal script

#Requires AutoHotkey v2.0
#SingleInstance
#Import 'path\to\task-switcher.ahk' {*}

$>^LCtrl::TaskSwitcher.ToggleMenu()
$<^RCtrl::TaskSwitcher.ToggleMenu()
```

Or use the built-in `Alt+Tab` replacement:

```AutoHotkey
TaskSwitcher.AltTabReplacement('On')
```

This makes `Alt+Tab` open the switcher as long as Alt remains pressed down. While the switcher is open, `Alt+Tab` cycles through windows.

> **Note:** Hotkeys pressed while the menu is open (especially relevant to the Niche methods and `CloseMenu()`), require the keyboard hook to work.

*\*See the `example.ahk` file for more hotkey examples and setup examples.*


## Methods
### Necessary:
```AutoHotkey
TaskSwitcher.ToggleMenu()                   ; Open or close
; or
TaskSwitcher.OpenMenu()                     ; Open the switcher
TaskSwitcher.CloseMenu()                    ; Close the switcher
; or
TaskSwitcher.AltTabReplacement()            ; Enable/Disable alt-tab hotkeys for the TaskSwitcher (values: 'On', 'Off', 'Toggle')
```

### Optional:
```AutoHotkey
TaskSwitcher.OnWindowActivate(Callback)     ; Run user code when window is activated
TaskSwitcher.OnMenuOpen(Callback)           ; Run user code when menu opens
TaskSwitcher.DisableAltEscape()             ; Disable Alt+Escape cycling through windows
TaskSwitcher.DisableCtrlAltTab()            ; Disable vanilla alt-tab toggle behavior
TaskSwitcher.OverrideWindowNames(exe, name, exe2, name2, ...) ; Custom names for windows
```

### Niche:
```AutoHotkey
TaskSwitcher.ActivateWindow()               ; Switch to selected window
TaskSwitcher.ActivateWindowAndCloseMenu()   ; Switch to selected window and close menu
TaskSwitcher.HighlightNextWindow()          ; Navigate down
TaskSwitcher.HighlightPreviousWindow()      ; Navigate up
TaskSwitcher.HighlightFirstRow()            ; Jump to first window
TaskSwitcher.HighlightLastRow()             ; Jump to last window
TaskSwitcher.TogglePanelVisibility()        ; Show/hide info panel
```

## Keyboard Shortcuts

- **Arrow Up/Down** — Navigate windows in list
- **Home/End** — Jump to first/last window in list
- **1-9, 0** — Select window in list by row number (if `showRowNumbers: true`)
- **Enter** — Switch to keyboard-selected window
- **Escape** — Close switcher (or clear search if `escapePriority: false`)
- **Backspace** — Delete character from search
- **Ctrl+Backspace** — Clear entire search
- **Tab** — Toggle panel
- **Delete** — Close keyboard-selected window
- **Mouse Wheel** — Scroll through list
- **Middle-Click** — Close window the mouse cursor is over
- **Arrow Left/Right** — Cycle through panel tabs

## Customization

You can customize the switcher by passing options during the auto-execute section of your script. Colors come in one of two color object literals: text colors and UI colors.

```ahk
TaskSwitcher({
    textColors: {
        row: 0xFF00FF00,
    },

    colors: {
        row: 'Auto',
    },


    menuWidth: 1200,
    rowHeight: 80,
    maxVisibleRows: 8,
    ...
})
```

> **Note:** The script makes little effort to ensure everything looks nice. For example, if you set `iconSize: 300` or `rowHeight: 10`, you're not going to have a good time. Use your best judgment and at your own discretion.


### All Customizable Options

<details>
<summary><strong>Size, Positioning, & Spacing</strong></summary>

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `marginX` | Integer | 12 | Left/right padding between certain UI elements |
| `marginY` | Integer | 12 | Top/bottom padding between certain UI elements |
| `menuWidth` | Integer | 1000 | Width of the entire switcher in pixels |
| `rowHeight` | Integer | 75 | Height of each window row |
| `maxVisibleRows` | Integer | 12 | How many rows show before scrolling |
| `iconSize` | Integer | 32 | Size of window icons |
| `closeButtonSize` | Integer | 24 | Size of close button |
| `rowDividerHeight` | Integer | 1 | Thickness of line between rows |
| `partitionWidth` | Integer | 2 | Thickness of the list/panel divider |
| `defaultPanelSizePercent` | Float | 0.5 | Initial size of info panel (0.0-1.0) |
| `scrollPixelOffset` | Float | 0.5 | Initial size of info panel (0.0-1.0) |
| `scrollPixelOffset` | Integer | 40 | How many pixels to scroll per wheel tick |
| `monitorToDisplayOn` | Integer | Primary | Which monitor to open on |
| `coordinates` | String/Object | 'Center' | Where to open: 'Center', 'Recenter', 'Mouse', or {x: xPos, y: yPos} |

</details>

<details>
<summary><strong>Behavior</strong></summary>

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `scrollSmoothingValue` | Float | 0.35 | Lower = smoother, higher = snappier |
| `wrapRowNavigation` | Boolean | true | Loop to start/end when navigating with keyboard |
| `alwaysHighlightFirstRow` | Boolean | true | Auto-select first row when filtering |
| `showCloseButtonsOnAllRows` | Boolean | false | Show X button on all rows, or only hovered row |
| `escapePriority` | Boolean | false | When true, `Escape` always closes the menu immediately. When false, `Escape` will cancel any interaction with clicked UI elements and clear the search field (if applicable), requiring a second press to close the menu |
| `rememberPanelState` | Boolean | true | Whether the panel visibility is remembered between menu showings |
| `fullLengthDividers` | Boolean | false | Divider lines span full width or just the content |
| `fullLengthPartition` | Boolean | true | Partition line spans full height or just content |
| `allowResize` | Boolean | false | When false, menu is a static size that fits `maxVisibleRows`. When true, menu resizes to fit all open windows, up to the `maxVisibleRows` value |
| `closeOnOutsideClick` | Boolean | true | Clicking outside closes the switcher |
| `clickPassthrough` | Boolean | false | Allow clicks outside to pass through to windows behind |
| `showRowNumbers` | Boolean | true | Enable row numbers 1-9, 0 for quick selection |
| `allowMouseToUpdatePanel` | Boolean | true | Panel updates when hovering windows with the mouse |
| `showPanelDuringFiltering` | Boolean | false | When false, panel is hidden while typing (filtering windows) |

</details>

<details>
<summary><strong>UI Colors</strong></summary>
The `colors` object property for UI elements contains the following properties:

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `row` | Hex | 0xFF333333 | Background of window rows |
| `rowHighlight` | 'Auto'/Hex/Array | 'Auto' | Color of rows highlighted with the keyboard |
| `rowHoverHighlight` | 'Auto'/Hex/Array | 'Auto' | Color of row when mouse hovers over row |
| `rowClickHighlight` | 'Auto'/Hex/Array | 'Auto' | Color of row when row is clicked |
| `rowDivider` | 'Auto'/Hex | 'Auto' | Color of divider lines between rows |
| `partition` | 'Auto'/Hex | 'Auto' | Color of divider line between list and panel when panel is visible |
| `searchBar` | 'Auto'/Hex | 'Auto' | Background color of the search bar |
| `topBar` | Hex | row | Background of section behind the search bar |
| `closeButton` | 'Auto'/Hex | 'Auto' | Close button background color |
| `closeButtonHoverHighlight` | 'Auto'/Hex | 'Auto' | Close button color on mouse hover |
| `closeButtonX` | 'Auto'/Hex | 'Auto' | Color of X on close button |
| `closeButtonXHoverHighlight` | 'Auto'/Hex | 'Auto' | Color of X on close button on mouse hover |
| `panel` | 'Auto'/Hex | 'Auto' | Panel background color |
| `panelIcon` | 'Auto'/Hex | 'Auto' | Panel toggle button background |
| `panelIconLines` | 'Auto'/Hex | 'Auto' | Panel toggle button lines color |
| `panelTabActive` | 'Auto'/Hex | 'Auto' | Panel tab active color |
| `panelTabInActive` | 'Auto'/Hex | 'Auto' | Panel tab natural state (unselected) color |
| `panelTabHoverHighlight` | 'Auto'/Hex | 'Auto' | Panel tab color on mouse hover |
| `panelTabClickHighlight` | 'Auto'/Hex | 'Auto' | Panel tab color when clicked with mouse |
</details>

<details>
<summary><strong>Text Colors</strong></summary>
The `textColors` object property for displayed text contains the following properties:

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `row` | 'Auto'/Hex | 'Auto' | Text color in rows |
| `rowHightlight` | 'Auto'/Hex | 'Auto' | Text color in rows that are highlighted with the keyboard |
| `rowHoverHighlight` | 'Auto'/Hex | 'Auto' | Text color in rows when highlighted by mouse hover |
| `rowClickHighlight` | 'Auto'/Hex | 'Auto' | Text color in rows that are highlighted when clicked with the mouse |
| `searchBar` | 'Auto'/Hex | 'Auto' | Search bar typed text color |
| `placeholder` | 'Auto'/Hex | 'Auto' | Search bar placeholder text color |
| `panelHeader` | 'Auto'/Hex | 'Auto' | Section headers in information panel |
| `panelBody` | 'Auto'/Hex | 'Auto' | Body text in information panel |
| `panelTab` | 'Auto'/Hex | 'Auto' | Panel tab text color |

</details>

&nbsp;

> **Color Format:** Use `0xAARRGGBB` format for colors (e.g. `0xFF00FF00` is opaque green). Set to `"Auto"` to have a contrasting color automatically determined. The only color option where this is different is `colors.row` which is the dominant menu color; which when set to `Auto`, will determine a light or dark color based on the system theme light/dark mode.

**Gradients:** `colors.rowHighlight`, `colors.rowHoverHighlight`, and `colors.rowClickHighlight` can be arrays of 2+ colors for a gradient effect:
```ahk
colors: {
    rowHighlight: [0xFF1E1E1E, 0xFF3D3D3D]
}
```
&nbsp;

## Additional Information

- Use `OverrideWindowNames()` if a window name is incorrect or missing. For the life of me, I could not properly retrieve the name for Steam, so this is what I use to display "Steam" instead of "steamwebhelper".
- The info panel shows a live preview unless the window is minimized (preview not available for minimized windows).
- The switcher respects virtual desktops on Windows 10+.

## Known Issues
- When using recent sorting order, always-on-top windows always show up first. No way around this without potentially complex window tracking.