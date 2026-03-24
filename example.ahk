#Include task-switcher.ahk
Suspend(true)


/**
 * Personal note:
 * I like to enact Suspend when loading auto-execute stuff and disable it after. I do this in most of my scripts.
 * That way if a hotkey is triggered too quickly after starting/reloading a script, the hotkey doesn't try to activate something before it's initialized completely and throw an error.
 */


;============================================================================================
; @Setup
;============================================================================================
; @example of changing options without modifying the class directly
; see @options near beginning of TaskSwitcher class for all options you can modify
TaskSwitcher({
    colors: {
        row: 0xDD111111,
        panel: 0xDD111111,
        topbar: 0xDD111111,
        rowHighlight: 0xDDFFFFFF,
        searchBar: 0xDD333333,
        closeButton: 0x00000000,
        closeButtonHoverHighlight: 0xFFFFFFFF,
        closeButtonXHoverHighlight: 0xFFFF0000,
        rowDivider: 0x88FFFFFF,
    },

    alwaysHighlightFirst: true,
    escapePriority: true,
    closeButtonSize: 40,
    menuWidth: 1500,
    rowHeight: 60,
    iconSize: 50,
    maxVisibleRows: 15,
    partitionWidth: 3,
    rowDividerHeight: 2,
    defaultPanelSizePercent: 0.6,
    allowResize: true,
    coordinates: 'Recenter',
})

; move cursor to center of activated window
TaskSwitcher.OnWindowActivate((window) {
    WinGetPos(&x, &y, &w, &h, window.hwnd)
    centerX := x + (w // 2)
    centerY := y + (h // 2)
    DllCall('SetCursorPos', 'Int', centerX, 'Int', centerY)
})

; alternate example
; TaskSwitcher.OnWindowActivate((window) {
;     list := ''
;     for prop, value in window.OwnProps() {
;         list .= Format('Name: {} - Value: {}`n', prop, value)
;     }

;     ToolTip(list)
;     SetTimer(ToolTip, -3000)
; })

; moves cursor to center of menu when opened
TaskSwitcher.OnMenuOpen((menu) {
    menu.GetPos(&x, &y, &w, &h)
    MouseMove(x + (w // 2), y + (h // 2))
})

Suspend(false)

/**
 * @Hotkeys
 * Pick your poison
 */
; Simple toggle hotkey
$F1::TaskSwitcher.ToggleMenu()

; Simple open and close hotkeys
$F2::TaskSwitcher.OpenMenu()
$F3::TaskSwitcher.CloseMenu()

; Left and right control keys pressed together
$<^RCtrl::TaskSwitcher.ToggleMenuSorted()
$>^LCtrl::TaskSwitcher.ToggleMenuSorted()

; Hotkey setup to replace AltTab behavior
TaskSwitcher.AltTabReplacement()

; Toggles the AltTabReplacement hotkeys created from above. 'On' and 'Off' are also both valid parameters.
$F4::TaskSwitcher.AltTabReplacement('Toggle')


#HotIf TaskSwitcher.isActive
+=::TaskSwitcher.TogglePanelVisibility()
#HotIf