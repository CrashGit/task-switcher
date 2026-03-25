#Requires AutoHotkey v2.0-a
#SingleInstance


;============================================================================================
; @Dependencies
;============================================================================================
#Include ..\..\lib\Gdip_All.ahk


;============================================================================================
; @Auto_Execute
;============================================================================================
pToken := Gdip_Startup()
OnExit((*) {
    TaskSwitcher.__Cleanup()
    Gdip_Shutdown(pToken)
})
TraySetIcon('shell32.dll', 90)


;============================================================================================
; @TaskSwitcher
;============================================================================================
export class TaskSwitcher {
    /**
     * @DevNote
     * Note - Options that go through Gdip_TextToGraphics require ARGB format as a string (e.g. 'FF00FF00' is an opaque green)
     *        while other color options use a 0xARGB (hex) number (e.g. 0xFF00FF00 is opaque green).
     *        I have made it so all explicit colors passed use 0xARGB. The appropriate options are converted to their naturally-accepted format.
     */

    /**
     * @OPTIONS
     * Colors can be set to 'Auto'
     *
     * When set to Auto, all colors use the background they're on to determine their color.
     * The exception to this is colors.row as it is the dominant color and is decided on your Windows light/dark theme.
     * However, some colors like texts and the panel icon lines will be set to black or white to ensure high constrast.
     * The other colors will be set to a brighter/darker version of the color they're on to be thematic while offering some contrast.
     *
     * Some color options support an array of colors that will dictate a gradient.
     * If only two colors are supplied, the gradient is not a 50%-50% split. This is because if the second color starts blending too soon, it can affect visibility of the text.
     * No considerations are done if more than two colors are supplied, you must use your own judgement if the text visibility is good enough for you.
     * Colors that support gradients are: colors.rowHighlight, colors.rowHoverHighlight, and colors.rowClickHighlight
     */
     static colors := {
                ; keyboard selection
                row                         : 'Auto',
                rowHighlight                : 'Auto',

                ; mouse selection
                rowHoverHighlight           : 'Auto',
                rowClickHighlight           : 'Auto',

                ; separation
                rowDivider                  : 'Auto',
                partition                   : 'Auto',

                ; search
                topBar                      : 'Auto',
                searchBar                   : 'Auto',

                ; close buttons
                closeButton                 : 'Auto',
                closeButtonHoverHighlight   : 'Auto',
                closeButtonX                : 'Auto',
                closeButtonXHoverHighlight  : 'Auto',

                ; panel
                panel                       : 'Auto',

                ; panel icon
                panelIcon                   : 'Auto',
                panelIconLines              : 'Auto',

                ; panel tabs
                panelTabActive              : 'Auto',
                panelTabInactive            : 'Auto',
                panelTabHoverHighlight      : 'Auto',
                panelTabClickHighlight      : 'Auto',
           },

           textColors := {
                row                         : 'Auto',
                rowHighlight                : 'Auto',
                rowHoverHighlight           : 'Auto',
                rowClickHighlight           : 'Auto',
                placeholder                 : 'Auto',
                searchBar                   : 'Auto',
                panelHeader                 : 'Auto',
                panelBody                   : 'Auto',
                panelTab                    : 'Auto',
           },

           ; dimensions, positions, and spacing
           marginX                          := 12,
           marginY                          := 12,
           menuWidth                        := 1000,
           rowHeight                        := 75,
           maxVisibleRows                   := 12,
           iconSize                         := 32,
           rowDividerHeight                 := 1,
           closeButtonSize                  := 24,
           partitionWidth                   := 2,
           defaultPanelSizePercent          := 0.5,                 ; 0.0-1.0 float
           scrollPixelOffset                := 40,
           monitorToDisplayOn               := MonitorGetPrimary(), ; any valid number that represents a monitor you have (can use MonitorGetCount() to find out the the max)

           ; behavior
           scrollSmoothingValue             := 0.35,                ; higher values make it feel snappier and less smooth
           wrapRowNavigation                := true,
           alwaysHighlightFirstRow          := true,
           showCloseButtonsOnAllRows        := false,
           escapePriority                   := false,
           rememberPanelState               := false,
           fullLengthDividers               := false,
           fullLengthPartition              := true,
           allowResize                      := false,
           closeOnOutsideClick              := true,
           clickPassthrough                 := true,
           showRowNumbers                   := true,
           allowMouseToUpdatePanel          := true,                ; whether mousing over a row will update the panel or if the panel should require keyboard navigation to update
           showPanelDuringFiltering         := false,               ; true may result in a(n) funky/incomplete display if allowResize = true


        /**
          * @coordinates
          * 4 valid values: 'Center', 'Recenter', 'Mouse', {x: xPos, y: yPos}
          * Center - Centers the UI in the middle of your primary monitor.
          * Recenter - Same as center except when you type to filter windows, the smaller list (when allowResize = true) will continue to keep the UI centered.
          * Mouse - UI spawns wherever the mouse is.
          * {x: xPos, y: yPos} - Custom coordinates object.
         */
           coordinates := 'Center'


    ; @END_OF_OPTIONS --------------------------------


    static isActive => WinActive('ahk_id' this.Menu.Hwnd)
    static isOpen => (DetectHiddenWindows(false), WinExist('ahk_id' this.Menu.Hwnd))
    static IsUnderMouse => (MouseGetPos(,, &win), win = TaskSwitcher.Menu.Hwnd)

    static ToggleMenuSorted(options?) {
        if this.isOpen {
            this.CloseMenu()
            return
        }

        this.__OpenMenu(options?, true)
    }

    static ToggleMenu(options?) {
        if this.isOpen {
            this.CloseMenu()
            return
        }

        this.__OpenMenu(options?, false)
    }

    static OpenMenuSorted(options?) {
        if this.isOpen {
            return
        }

        this.__OpenMenu(options?, true)
    }

    static OpenMenu(options?) {
        if this.isOpen {
            return
        }

        this.__OpenMenu(options?, false)
    }

    static CloseMenu() {
        if !this.isOpen {
            return
        }

        Critical(50)
        DllCall('ReleaseCapture')

        this._ih.Stop()
        this.Menu.Hide()

        OnMessage(0x200, this._OnMouseMove, 0)
        OnMessage(0x20A, this._OnMouseWheel, 0)
        OnMessage(0x2A3, this._OnMouseLeave, 0)
        OnMessage(0x201, this._OnLeftClick, 0)
        OnMessage(0x202, this._OnLeftClickRelease, 0)
        OnMessage(0x207, this._OnMiddleClick, 0)
        OnMessage(0x208, this._OnMiddleClickRelease, 0)

        this._lastUsedDevice := 'keyboard'
        this._lastPreviewHwnd := 0
        this._lastPressedKey := ''
        this._windowRects := []
        this._hoveredOver := 0
        this._hoveredCloseButton := 0
        this._clicked := {item: '', index: 0}
        this._mouseLeft := true
        this._userIsTyping := false
        this._tempDisablePanel := false                 ; needs to come before this._searchText reset
        this._searchText := this._placeholderSearchText
        this._scrollOffset := 0
        this._targetScrollOffset := 0
        if this.rememberPanelState {
            this._showPanel := this.rememberPanelState
        }
        Critical('Off')
    }

    static ActivateWindowAndCloseMenu(highlightedRow := this._highlightedRow) {
        this.CloseMenu()
        this.ActivateWindow(highlightedRow)
    }

    static ActivateWindow(highlightedRow := this._highlightedRow) {
        if !this._windowList.Has(highlightedRow) {
            return
        }

        window := this._windowList[highlightedRow]
        if this.__ActivateWindow(window) {
            this._onWindowActivate(window)
        }
    }

    static OnWindowActivate(Callback) {
        this._onWindowActivate := (_, params*) => Callback(params*)
    }

    static OnMenuOpen(Callback) {
        this._onMenuOpen := (_, params*) => Callback(params*)
    }

    ; pass 'Off' if you ever want to disable those hotkeys after already being active
    ; pass 'Toggle' if you want to toggle the state
    static AltTabReplacement(state := 'On') {
        static altTabHotkeysEnabled := false,
               previousState := state

        if state = 'Toggle' {
            state := previousState = 'On' ? 'Off' : 'On'
        }

        HotIf((*) => !TaskSwitcher.isOpen)
        Hotkey('!Tab', (*) {
            altTabHotkeysEnabled := true
            TaskSwitcher.OpenMenu({index: 2})
        }, state)


        HotIf((*) => altTabHotkeysEnabled && TaskSwitcher.isActive)
        Hotkey('!Tab', (*) => TaskSwitcher.HighlightNextRow(), state)
        Hotkey('+!Tab', (*) => TaskSwitcher.HighlightPreviousRow(), state)
        Hotkey('*!Escape', (*) {
            TaskSwitcher.CloseMenu()
            altTabHotkeysEnabled := false
        }, state)


        HotIf((*) => altTabHotkeysEnabled)
        Hotkey('~*Alt up', (*) {
            ; prevents alt key release from closing window if it wasn't opened with alt-tab method
            ; this is in case anyone uses hotkeys that allow something like alt+up/down to navigate, the menu will not close when releasing alt
            if TaskSwitcher.isActive {
                TaskSwitcher.ActivateWindowAndCloseMenu()
            } else if TaskSwitcher.isOpen {
                TaskSwitcher.CloseMenu()
            } else if this.isOpen && WinWaitActive(this.Menu.Hwnd,, 2) {   ; in the process of opening
                if altTabHotkeysEnabled {
                    this.CloseMenu()
                }
            }
            altTabHotkeysEnabled := false   ; keep at bottom. otherwise, if last condition fails, var will be reset before failing condition and !Tab could potentially be triggered again by accident by the user
        }, state)
        HotIf()

        previousState := state
    }

    static DisableAltEscape() {
        Hotkey('*!Escape', (*) => 0)
    }

    static DisableCtrlAltTab() {
        Hotkey('!^Tab', (*) => 0)
    }

    static HighlightPreviousRow() {
        if this._highlightedRow > 1 {
            this._highlightedRow -= 1
        } else if this.wrapRowNavigation {
            this._highlightedRow := this._windowList.Length
        } else {
            return  ; returns if no changes were made
        }

        this.__BufferUIUpdateOnNavigation()
    }

    static HighlightNextRow() {
        if this._highlightedRow < this._windowList.Length {
            this._highlightedRow += 1
        } else if this.wrapRowNavigation {
            this._highlightedRow := 1
        } else {
            return  ; returns if no changes were made
        }

        this.__BufferUIUpdateOnNavigation()
    }

    static HighlightFirstRow() {
        if this._highlightedRow != 1 {
            this._highlightedRow := 1
            this.__BufferUIUpdateOnNavigation()
        }
    }

    static HighlightLastRow() {
        last := this._windowList.Length
        if this._highlightedRow != last {
            this._highlightedRow := last
            this.__BufferUIUpdateOnNavigation()
        }
    }

    static __BufferUIUpdateOnNavigation() {
        /**
         * I have hotkeys that send {Up} and {Down} multiple times to make navigation easier.
         * This code is an attempt to minimize issues that came with quickly-repeated navigation events.
         */
        SetTimer(() {
            this.__KeepHighlightedRowVisible()
            UI.DrawMenu(() {
                UI.UpdateWindowList()
                UI.UpdatePanel()
            })
        }, -30)
    }

    static TogglePanelVisibility() {
        if this._userIsTyping {
            return
        }

        this._showPanel ^= 1
        UI.DrawMenu(() {
            UI.UpdateWindowList()
            UI.UpdatePanel()
        })
    }


    /**
     * Allows custom name overrides. This exists because I couldn't find Steam's actual DisplayName/ProductName.
     * Expects an even-amount of parameters as if you were passing them to a Map(key, value).
     * First parameter pairing  = executable name (excludes .exe)
     * Second parameter pairing = the name you want the window to have
     * @example
     * TaskSwitcher.OverrideWindowNames('steamhelper', 'Steam')
     */
    static OverrideWindowNames(exe_name_pairs*) {
        this.nameOverrides.Set(exe_name_pairs*)
    }

    static Call(options := {}) {
        if colors := options.DeleteProp('colors') {
            CopyOptionsFromObject(colors, 'colors')
        }

        if textColors := options.DeleteProp('textColors') {
            CopyOptionsFromObject(textColors, 'textColors')
        }

        CopyOptionsFromObject(options)

        if this.closeOnOutsideClick {
            passthrough := this.clickPassthrough ? '~' : ''

            ; closes task switcher if click happens outside the menu
            HotIf((*) => TaskSwitcher.isOpen && !TaskSwitcher.IsUnderMouse)

            for button in ['LButton', 'RButton', 'MButton', 'XButton1', 'XButton2'] {
                ; applies passthrough and wildcard modifiers if applicable
                key := Format('{}*{}', passthrough, button)
                Hotkey(key, (*) => this.CloseMenu())
            }
            HotIf()
        }

        if this.showRowNumbers {
            HotIf((key) => TaskSwitcher.isOpen && this._windowList.Has(SubStr(key, -1)) && !GetKeyState('Shift'))

            loop 9 {
                Hotkey('*' A_Index, (key) => this.ActivateWindowAndCloseMenu(SubStr(key, -1)))
                Hotkey('*' A_Index, (key) {
                    numberPressed := SubStr(key, -1)
                    this.ActivateWindowAndCloseMenu(numberPressed)  ; pass number pressed as index
                })
            }

            HotIf((*) => TaskSwitcher.isOpen && this._windowList.Has(10)) && !GetKeyState('Shift')
            Hotkey('*0', (*) => this.ActivateWindowAndCloseMenu(10))
            HotIf()
        }

        VariousPropertiesSetup()
        ColorSetup()
        SearchBarDimensions()
        PanelIconDimensions()

        this.__InitTopBar()
        this.__InitSearchBar()
        this.__InitPanelIcon()
        this.__InitWindowList()
        this.__InitPanel()
        this.__InitWindow()

        this.DeleteProp('Call')
        return

        ; auxiliary setup initialization -----------------------------
        CopyOptionsFromObject(options, propName := '') {
            property := propName ? this.%propName% : this

            for option, color in options.OwnProps() {
                if !property.HasOwnProp(option) {
                    throw Error(option ' option doesn`'t exist. Make sure you spelled it correctly.')
                }
                property.%option% := color
            }
        }

        ColorSetup() {
            EnsureColorHasAlphaAndDefaultValue()
            EnsureTextColorsAreFormatted()

            /**
             * Color Functions
             */
            EnsureTextColorsAreFormatted() {
                for name, textColor in this.textColors.OwnProps() {
                    try this.textColors.%name% := Format('{:08X}', textColor) ; 0xARGB to string
                    catch {
                        throw Error('The color: ' textColor '`nis incorrect for option: ' name)
                    }
                }
            }

            EnsureColorHasAlphaAndDefaultValue() {
                ; colors that depend on others when using 'Auto' must come after the dependent color
                textColorDependencies := OrderedMap(
                ;   color property                  ; dependent color
                    'row',                          () => GetContrastingColor(this.colors.row),
                    'rowHighlight',                 () => GetContrastingColorFromPossibleArray(this.colors.rowHighlight),
                    'rowHoverHighlight',            () => GetContrastingColorFromPossibleArray(this.colors.rowHoverHighlight),
                    'rowClickHighlight',            () => GetContrastingColorFromPossibleArray(this.colors.rowClickHighlight),
                    'placeholder',                  () => GetAutoAdjustedColor(this.colors.searchBar, 80),
                    'searchBar',                    () => GetContrastingColor(this.colors.searchBar),
                    'panelHeader',                  () => GetContrastingColor(this.colors.panel),
                    'panelBody',                    () => GetContrastingColor(this.colors.panel),
                    'panelTab',                     () => GetContrastingColor(this.colors.panelTabInactive),
                )

                colorDependencies := OrderedMap(
                ;   color property                  ; dependent color
                    'row',                          () => this.__GetUserThemeColor() ? 0xFFFFFFFF : 0xFF1E1E1E,
                    'rowHighlight',                 () => GetAutoAdjustedColorOfPossibleArray(this.colors.row, 40),
                    'rowHoverHighlight',            () => GetAutoAdjustedColorOfPossibleArray(this.colors.row, 80),
                    'rowClickHighlight',            () => GetAutoAdjustedColorOfPossibleArray(this.colors.rowHoverHighlight),
                    'rowDivider',                   () => GetAutoAdjustedColor(this.colors.row, 80),
                    'panel',                        () => this.colors.row,
                    'topBar',                       () => this.colors.row,
                    'partition',                    () => GetAutoAdjustedColor(this.colors.panel),
                    'searchBar',                    () => GetAutoAdjustedColor(this.colors.topBar, 40),
                    'closeButton',                  () => GetAutoAdjustedColor(this.colors.row),
                    'closeButtonHoverHighlight',    () => GetAutoAdjustedColor(this.colors.row),
                    'closeButtonX',                 () => GetContrastingColor(this.colors.closeButton),
                    'closeButtonXHoverHighlight',   () => GetAutoAdjustedColor(this.colors.closeButtonHoverHighlight),
                    'panelIcon',                    () => GetAutoAdjustedColor(this.colors.topBar),
                    'panelIconLines',               () => GetContrastingColor(this.colors.panelIcon),
                    'panelTabInactive',             () => GetAutoAdjustedColor(this.colors.panel),
                    'panelTabHoverHighlight',       () => GetAutoAdjustedColor(this.colors.panelTabInactive),
                    'panelTabClickHighlight',       () => GetAutoAdjustedColor(this.colors.panelTabHoverHighlight, 20),
                    'panelTabActive',               () => GetAutoAdjustedColor(this.colors.panelTabClickHighlight),
                )


                AssignColors(colorDependencies, this.colors)
                AssignColors(textColorDependencies, this.textColors)

                /**
                 * @param {OrderedMap} dependencyList the source of colors
                 * @param {Object} property the color object property to inherit new colors from dependencyList
                 */
                AssignColors(dependencyList, property) {
                    for name, GetColor in dependencyList {
                        color := property.%name%

                        if color = 'Auto' {
                            property.%name% := GetColor()
                        } else if color is Array {
                            for index, gradientColor in color {
                                property.%name%[index] := gradientColor | 0x01000000
                            }
                        } else {
                            property.%name% := color | 0x01000000
                        }
                    }
                }

                ; supporting color functions
                GetAutoAdjustedColor(color, offset := 60) {
                    return this.__ColorBrightnessAutoAdjust(color, offset) | 0x01000000
                }

                GetContrastingColor(color) {
                    return this.__GetContrastingColor(color)
                }

                GetAutoAdjustedColorOfPossibleArray(color, offset := 60) {
                    if color is Array {
                        color := color[1]
                    }
                    return GetAutoAdjustedColor(color, offset)
                }

                GetContrastingColorFromPossibleArray(color) {
                    if color is Array {
                        middleIndex := Ceil(color.Length // 2)
                        color := color[middleIndex]
                    }
                    return GetContrastingColor(color)
                }
            }
        }

        VariousPropertiesSetup() {
            if this.showPanelDuringFiltering {
                this.DefineProp('_searchText', {
                    Get: (self) => self._private_searchText,
                    Set: (self, value) => self._private_searchText := value
                })
            }

            this._topBarHeight   := this._searchBarHeight + (this.marginY * 2)
            this._showPanel      := true
            this._searchText     := this._placeholderSearchText
            this._rowNumberWidth := this.showRowNumbers ? 30 : 0
            this._titleX         := (this.iconSize + (2 * this.marginX)) + this._rowNumberWidth
            this._rowWithDivider := this.rowHeight + this.rowDividerHeight

            ; thought I might need this for something—currently un-useful
            ; this._private_highlightedRow := 1
            ; this._previousHighlightedRow := 1
            ; this.DefineProp('_highlightedRow', {
            ;     Get: (self) => self._private_highlightedRow,
            ;     Set: (self, value) {
            ;         if self._private_highlightedRow != value {
            ;             self._previousHighlightedRow := self._private_highlightedRow
            ;             self._private_highlightedRow := value
            ;         }
            ;     }
            ; })

            if this.allowResize {
                this.__RefreshWindowList()
                this.__CalculateTotalHeight()
            } else {    ; initialize *something* as the menu height
                PreventResizeMenuHeightSetup()
            }

            this._lastWindowListUIHeight := this._lastWindowUIHeight := this._lockedHeight := this._menuHeight

            minWidthInPixels := this.menuWidth * 0.2
            maxWidthInPixels := this.menuWidth * 0.8
            this._minResizableWidth := minWidthInPixels

            partitionPos := this.menuWidth * (1 - this.defaultPanelSizePercent)
            this._partitionPos := Max(minWidthInPixels, Min(maxWidthInPixels, partitionPos))

            PreventResizeMenuHeightSetup() {
                contentHeight := this._rowWithDivider * this.maxVisibleRows - this.rowDividerHeight
                this._menuHeight := contentHeight + this._topBarHeight
            }
        }

        SearchBarDimensions() {
            height := this._searchBarHeight
            x1 := this.marginX
            y1 := this._topBarHeight - this.marginY - height

            this._searchBarRect := {
                x1: x1,
                y1: y1,
                x2: x1 + this.menuWidth - (2 * height + (this.marginX * 2)),
                y2: y1 + height,
                h: height,
                r: 8,
                ContainsPoint: (self, x, y) {
                    return x >= self.x1 && x <= self.x2 && y >= self.y1 && y <= self.y2
                }
            }
        }

        PanelIconDimensions() {
            panelIconBackgroundSize := this._searchBarRect.h
            panelIconBackgroundX := this.menuWidth - this.marginX - panelIconBackgroundSize
            panelIconBackgroundY := this._searchBarRect.y1
            panelLineSpacing := panelIconBackgroundSize // 7

            this._panelIcon := {

                ; panel icon background
                bg: {
                    x1: panelIconBackgroundX,
                    y1: panelIconBackgroundY,
                    x2: panelIconBackgroundX + panelIconBackgroundSize,
                    y2: panelIconBackgroundY + panelIconBackgroundSize,
                    size: panelIconBackgroundSize,
                    ContainsPoint: (self, x, y) {
                        return x >= self.x1 && x <= self.x2 && y >= self.y1 && y <= self.y2
                    }
                },

                ; panel icon lines
                line: {
                    x: panelIconBackgroundSize * 0.1,
                    y: (panelIconBackgroundSize / 2) - ((panelLineSpacing * 5) / 2),
                    w: panelIconBackgroundSize * 0.8,     ; lines take up 8/10 of the background size
                    h: panelLineSpacing,
                    spacing: panelLineSpacing
                }
            }
        }
    }


    /**
     * @Private_Methods
     */


    static __FirstDraw() {
        this.__CalculateTotalHeight()      ; necessary for certain this._highlightedRow starting values when this.__ScrollTohighlightedRow() is called
        this.__KeepHighlightedRowVisible()
        UI.DrawMenu(() {
            UI.UpdateSearchBar()
            UI.UpdatePanelIcon()
            UI.UpdateWindowList()
            UI.UpdatePanel()
        })

        switch this.coordinates {
        case 'Center', 'Recenter':
            MonitorGetWorkArea(this.monitorToDisplayOn, &left, &top, &right, &bottom)
            this._x := left + (right - left - this.menuWidth) / 2
            this._y := top + (bottom - top - this._menuHeight) / 2
        case 'Mouse':
            MouseGetPos(&this._x, &this._y)
        default:
            this._x := this.coordinates.x
            this._y := this.coordinates.y
        }
    }

    static __OpenMenu(options := {}, sortedWindows := false) {
        static _ := () {
            this.HasOwnProp('Call') && this()
            return unset
        }() ?? unset

        Critical(50)
        this._sortedWindows := sortedWindows
        OnMessage(0x200, this._OnMouseMove)
        OnMessage(0x20A, this._OnMouseWheel)
        OnMessage(0x2A3, this._OnMouseLeave)
        OnMessage(0x201, this._OnLeftClick)
        OnMessage(0x202, this._OnLeftClickRelease)
        OnMessage(0x207, this._OnMiddleClick)
        OnMessage(0x208, this._OnMiddleClickRelease)

        startingIndex := options.index ?? 1

        this.__RefreshWindowList(options)
        this._highlightedRow := Min(Max(1, startingIndex), this._windowList.Length)
        this.__FirstDraw()
        this.Menu.Show('w' this.menuWidth ' h' this._menuHeight)
        this._ih.Start()
        this._onMenuOpen(this.Menu)
        Critical('Off')
    }

    static __CloseWindow(highlightedRow := this._highlightedRow) {
        if !this._windowList.Has(highlightedRow) {
            this.__RefreshWindowList()
            this.__ApplySearchFilter()
            this.__RedrawWindowList()
            return
        }

        window := this._windowList[highlightedRow]
        this._ih.Stop()

        WinClose(window.hwnd)
        if !WinWaitClose(window.hwnd,, 3) {
            return
        }

        this._ih.Start()

        ; helps when window list shifts when window is closed and the bottom of a scrollable list is visible
        switch this._windowList.Length {
        case 1 + this.maxVisibleRows:
            this._scrollOffset := 0
            this._targetScrollOffset := 0
        case 1:
            this._searchText := this._placeholderSearchText
        default:
            rowHeight := this.rowHeight + this.rowDividerHeight
            this._scrollOffset := Max(0, this._scrollOffset - rowHeight)
        }

        this.__RefreshWindowList()
        this.__ApplySearchFilter()
        this.__RedrawWindowList('override')
    }

    static __CalculateTotalHeight() {
        if !this.allowResize {
            return this._lockedHeight
        }

        totalRows := this._windowList.Length

        if totalRows > this.maxVisibleRows {
            ; show partial row to indicate scrollability
            visibleRows := this.maxVisibleRows - 0.5
            totalDividers := Floor(visibleRows)
            contentHeight := Round(visibleRows * this.rowHeight + (totalDividers * this.rowDividerHeight))
        } else {
            totalDividers := Max(0, totalRows - 1)
            contentHeight := (totalRows * this.rowHeight) + (totalDividers * this.rowDividerHeight)
        }

        totalHeight := this._topBarHeight + contentHeight
        return this._menuHeight := totalHeight
    }

    static __OnMouseMove(wParam, lParam, msg, hwnd) {
        static tme := TrackMouseLeave(hwnd)
        static lastX := -1, lastY := -1

        this.__GetMouseCoordsFromStruct(lParam, &x, &y)
        if x = lastX && y = lastY {
            return
        }

        lastX := x, lastY := y

        if this._mouseLeft {
            this._mouseLeft := false
            DllCall('user32.dll\TrackMouseEvent', 'Ptr', tme)
        }

        if this._clicked.item = 'partition' {
            this.__OnPartitionMove(x)
            return
        } else if this.__PointIsOnPartition(x, y) {
            DllCall('SetCursor', 'Ptr', DllCall('LoadCursor', 'Ptr', 0, 'Ptr', 32646))
            return
        }

        if UI._isDrawing {
            return
        }

        if this._clicked.item {
            return
        }

        mouseOverWindowList := this.__PointIsOnWindowList(x, y)
        this._canScroll := mouseOverWindowList

        if mouseOverWindowList {
            this._hoveredPanelTab := ''
            this._canScroll := true

            if this.__UpdateMouseHoverState(x, y) {
                this._lastUsedDevice := 'mouse'
                UI.DrawMenu(() {
                    UI.UpdateWindowList()
                    if this.allowMouseToUpdatePanel {
                        UI.UpdatePanel()
                    }
                })
            }
            return
        }

        this._canScroll := false
        this._hoveredCloseButton := 0
        if this._hoveredOver {
            this._hoveredOver := 0
            UI.DrawMenu(() {
                UI.UpdateWindowList()
            })
        }

        oldHoveredTab := this._hoveredPanelTab

        if this._showPanel && this.__PointIsOnPanel(x, y) {
            panelRelativeX := x - this._partitionPos
            panelRelativeY := y - this._topBarHeight

            for rect in this._panelTabRects {
                if rect.ContainsPoint(panelRelativeX, panelRelativeY) {
                    this._hoveredPanelTab := rect.tab
                    hoveredTab := true
                    break
                }
            }
        }

        if !IsSet(hoveredTab) {
            this._hoveredPanelTab := ''
        }

        if oldHoveredTab != this._hoveredPanelTab {
            UI.DrawMenu(() => UI.UpdatePanel())
        }

        TrackMouseLeave(hwnd) {
            TME_LEAVE := 0x00000002
            size := A_PtrSize = 8 ? 24 : 16     ; TRACKMOUSEEVENT struct size

            tme := Buffer(size, 0)
            NumPut('UInt', size,        tme, 0) ; cbSize
            NumPut('UInt', TME_LEAVE,   tme, 4) ; dwFlags
            NumPut('Ptr',  hwnd,        tme, 8) ; hwndTrack
            NumPut('UInt', 0,           tme, A_PtrSize = 8 ? 16 : 12)
            return tme
        }
    }

    static __UpdatePanelPreview(window, panelX, startY, panelWidth, panelHeight) {
        static props := Buffer(48, 0)

        if !WinExist(window.hwnd) {
            Panel := UI._sections['Panel'].graphics
            x := panelX + this.marginX
            y := startY + this.marginY
            Gdip_TextToGraphics(Panel, "Window closed", 'x' x ' y' y ' s16 cFFC0C0C0', 'Arial', panelWidth - (this.marginX * 2), 30)
            this.__RefreshWindowList()
            this.__ApplySearchFilter()
            this.__RedrawWindowList()
            return
        }

        ; if window is minimized, the live preview is shortened but enlarged version of the toolbar which is not what we want
        if WinGetMinMax(window.hwnd) = -1 {
            Panel := UI._sections['Panel'].graphics
            availableWidth := panelWidth - (this.marginX * 2)
            availableHeight := panelHeight - (this.marginY * 2)

            x := panelX + this.marginX
            y := startY + this.marginY + (availableHeight / 2) - 8

            options := 'x' x ' y' y ' s24 cFFC0C0C0 Center Bold'
            Gdip_TextToGraphics(Panel, 'Preview not available', options, 'Arial', availableWidth, availableHeight)
            this.__CleanupThumbnail()
            return
        }

        ; check if different window is trying to be shown than previous window
        if this._lastPreviewHwnd != window.hwnd {
            this.__CleanupThumbnail()
            this._lastPreviewHwnd := window.hwnd

            thumbnail := 0
            try {
                result := DllCall('dwmapi\DwmRegisterThumbnail',
                    'Ptr', this.Menu.Hwnd,
                    'Ptr', window.hwnd,
                    'Ptr*', &thumbnail)
            } catch {
                MsgBox('Preview failed')
            }

            if result = 0 {
                this._thumbnail := thumbnail
            } else {
                return
            }
        }

        try WinGetPos(,, &winW, &winH, 'ahk_id ' window.hwnd)   ; get window dimensions for preview
        catch {
            return
        }

        margin := this.marginX
        maxWidth := panelWidth - (margin * 2)
        maxHeight := panelHeight - (margin * 2)

        sourceAspect := winW / winH

        destWidth := Min(maxWidth, Round(maxHeight * sourceAspect))
        destHeight := Min(maxHeight, Round(destWidth / sourceAspect))

        destX := this._partitionPos + margin + (maxWidth - destWidth) / 2
        destY := this._topBarHeight + startY + margin + (maxHeight - destHeight) / 2

        NumPut(
            'UInt', 0x1F,
            'Int', destX,
            'Int', destY,
            'Int', destX + destWidth,
            'Int', destY + destHeight,
            'Int', 0,
            'Int', 0,
            'Int', winW,
            'Int', winH,
            'UChar', 255,
            'Int', 1,
            'Int', 1,
            props, 0)

        try {
            DllCall('dwmapi\DwmUpdateThumbnailProperties', 'Ptr', this._thumbnail, 'Ptr', props)
        } catch {
            MsgBox('DLL update thumbnail properties failed')
        }
    }


    static __UpdatePanelInfo(window, panelX, startY, panelWidth, panelHeight) {
        if !WinExist(window.hwnd) {
            Panel := UI._sections['Panel'].graphics
            x := panelX + this.marginX
            y := startY + this.marginY
            Gdip_TextToGraphics(Panel, "Window closed", 'x' x ' y' y ' s16 cFFC0C0C0', 'Arial', panelWidth - (this.marginX * 2), 30)
            this.__RefreshWindowList()
            this.__ApplySearchFilter()
            this.__RedrawWindowList()
            return
        }

        Panel := UI._sections['Panel'].graphics
        margin := this.marginX
        x := panelX + margin
        y := startY + margin

        lineHeight := 20
        fontSize := 16
        maxWidth := panelWidth - (margin * 2)

        headerOptions := Format('x{} s{} Bold c{}', x, fontSize, this.textColors.panelHeader)
        descriptionOptions := Format('x{} s{} c{}', (x + 10), fontSize, this.textColors.panelBody)

        hFont    := Gdip_FontFamilyCreate('Arial')
        headFont := Gdip_FontCreate(hFont, fontSize + 2, 1)
        bodyFont := Gdip_FontCreate(hFont, fontSize)
        windowName := this.__TruncateTextToWidth(window.name, fontSize, maxWidth)

        ; window information
        options := 'x' x ' y' y ' s' (fontSize + 4) ' Bold cFFFFFFFF'
        Gdip_TextToGraphics(Panel, windowName ' Information:', options, 'Arial', maxWidth, 30)
        y += lineHeight * 2

        ; process name
        CreateHeader('Process:')
        CreateDescription(window.process)

        ; hwnd
        CreateHeader('HWND:')
        CreateDescription(String(window.hwnd))

        ; PID
        CreateHeader('PID:')
        CreateDescription(String(WinGetPID(window.hwnd)))

        ; window title
        CreateHeader('Title:')
        CreateDescription(window.title)

        ; window dimensions
        WinGetPos(&winX, &winY, &winW, &winH, 'ahk_id ' window.hwnd)

        ; window size
        CreateHeader('Size:')
        CreateDescription(winW 'x' winH)

        ; window position
        CreateHeader('Position:')
        CreateDescription(winX ', ' winY)

        ; AlwaysOnTop
        CreateHeader('AlwaysOnTop:')
        alwaysOnTop := WinGetAlwaysOnTop(window.hwnd) = 1 ? 'True' : 'False'
        CreateDescription(alwaysOnTop)

        ; MinMax state
        CreateHeader('MinMax State:')
        switch WinGetMinMax(window.hwnd) {
        case -1: minMaxState := 'Minimized'
        case 0:  minMaxState := 'Unmaximized'
        case 1:  minMaxState := 'Maximized'
        }
        CreateDescription(minMaxState)

        ; Transparency
        CreateHeader('Transparency:')
        alpha := WinGetTransparent(window.hwnd)
        if alpha = '' {
            message := 'Could not retrieve transparency level.'
            CreateDescription(message)
        } else {
            percent := (alpha // 255) * 100 . '%'
            alpha := alpha . ' (0-255)'
            CreateDescription(alpha, lineHeight)
            CreateDescription(percent)
        }

        ; cleanup
        Gdip_DeleteFont(headFont)
        Gdip_DeleteFont(bodyFont)
        Gdip_DeleteFontFamily(hFont)

        ; auxiliary
        CreateHeader(title) {
            truncatedTitle := this.__TruncateTextToWidth(title, fontSize, maxWidth)
            options := headerOptions . ' y' y
            Gdip_TextToGraphics(Panel, truncatedTitle, options, 'Arial', 5000, 40)
            y += lineHeight
        }

        CreateDescription(text, yOffset := lineHeight * 2) {
            truncatedText := this.__TruncateTextToWidth(text, fontSize, maxWidth)
            options := descriptionOptions . ' y' y
            Gdip_TextToGraphics(Panel, truncatedText, options, 'Arial', 5000, 40)
            y += yOffset
        }
    }

    static __InitTopBar() {
        width := this.menuWidth
        height := this._topBarHeight
        UI.__CreateGDIPSection('TopBar', width, height)
        UI.DrawTopBar()
    }

    static __InitSearchBar() {
        height := this._searchBarRect.h
        width := this._searchBarRect.x2
        UI.__CreateGDIPSection('SearchBar', width, height)
    }

    static __InitPanelIcon() {
        size := this._searchBarRect.h
        UI.__CreateGDIPSection('PanelIcon', size, size)
    }

    static __InitWindowList() {
        width  := this._showPanel ? this._partitionPos : this.menuWidth
        height := this.__CalculateTotalHeight()
        UI.__CreateGDIPSection('WindowList', width, height)
    }

    static __InitPanel() {
        UI.__CreateGDIPSection('Panel', this._partitionPos, this._menuHeight - this._topBarHeight)
    }

    static __InitWindow() {
        UI.__CreateGDIPSection('Window', this.menuWidth, this._menuHeight)
    }

    ; parameter only exists for the reason of closing a window, so the nᵗʰ highlighted window is still highlighted
    static __RedrawWindowList(overrideHighlightedRow := false) {
        totalRows := this._windowList.Length

        ; reset scroll if list was empty and now has results
        if this._lastWindowCount = 0 && totalRows > 0 {
            this._scrollOffset := 0
            this._targetScrollOffset := 0
        }

        this._lastWindowCount := totalRows

        ; validate the highlighted row
        if this.alwaysHighlightFirstRow && !overrideHighlightedRow {
            this._highlightedRow := 1
        } else {
            totalRows := this._windowList.Length
            if this._highlightedRow > totalRows {
                this._highlightedRow := Max(1, totalRows)  ; ensure highlighted row is never 0 or scrollOffset will offset itself when list becomes empty during filtering
            }
        }

        ; update window list UI height if applicable
        if this.allowResize {
            height := this._menuHeight
            if height != this._lastWindowListUIHeight {
                this._lastWindowListUIHeight := height
            }
        }

        UI.DrawMenu(() {
            UI.UpdateSearchBar()
            UI.UpdateWindowList()
            this.__KeepHighlightedRowVisible()
            UI.UpdatePanel()
        })
    }

    static __ApplySearchFilter() {
        if this._searchText = this._placeholderSearchText || StrLen(this._searchText) = 0 {
            this._windowList := this._allWindows.Clone()
            return
        }

        this._windowList := this.__GetSearchResults()
    }

    static __GetSearchResults() {
        matches := []
        for win in this._allWindows {
            if InStr(win.name, this._searchText) || InStr(win.title, this._searchText) {
                matches.Push(win)
            }
        }
        return matches
    }

    static __RefreshWindowList(options := {}) {
        list := this.__GetAltTabWindowList(options)
        windows := []

        for id in list {
            title   := WinGetTitle(id)
            process := WinGetProcessPath(id)
            exe     := StrSplit(WinGetProcessName(id), '.exe')[1]

            name := this.nameOverrides.Get(exe, 0)
                || this.__GetWindowName(process)
                || exe

            windows.Push({
                hwnd:    id,
                title:   title,
                name:    name,
                process: process,
                exe:     exe
            })
        }

        if this._sortedWindows {
            SortWindows()
        }

        this._allWindows  := windows.Clone()  ; store complete list
        this._windowList := windows

        SortWindows() {
            i := 2
            while i <= windows.Length {
                temp := windows[i]
                j := i - 1
                while j >= 1 && StrCompare(windows[j].name, temp.name) > 0 {
                    windows[j + 1] := windows[j]
                    j--
                }
                windows[j + 1] := temp
                i++
            }
        }
    }

    static __GetWindowName(path) {
        size := DllCall('version\GetFileVersionInfoSizeW', 'Str', path, 'UInt*', 0, 'UInt')
        if !size {
            return
        }

        buf := Buffer(size)
        if !DllCall('version\GetFileVersionInfoW', 'Str', path, 'UInt', 0, 'UInt', size, 'Ptr', buf) {
            return
        }

        return Query('ProductName')

        Query(val) {
            ptr := 0, len := 0
            if DllCall('version\VerQueryValueW',
                'Ptr',      buf,
                'Str',      '\StringFileInfo\040904b0\' val,
                'Ptr*',     &ptr,
                'UInt*',    &len)
            {
                return StrGet(ptr, len, 'UTF-16')
            }
        }
    }

    static __DrawIcon(window, x, y) {
        try path := window.process
        catch {
            this.__RefreshWindowList()
            this.__RedrawWindowList()
            return
        }

        iconData := GetIconData(window.hwnd)
        pBitmap := iconData.bitmap

        if pBitmap {
            WindowList := UI._sections['WindowList'].graphics

            ; draw UWP icons slightly larger to compensate for smaller source images
            if iconData.isUWP {
                drawSize := this.iconSize * 1.25            ; 25% larger
                offset := (this.iconSize - drawSize) / 2    ; center it
                Gdip_DrawImage(WindowList, pBitmap, x + offset, y + offset, drawSize, drawSize)
            } else {
                Gdip_DrawImage(WindowList, pBitmap, x, y, this.iconSize, this.iconSize)
            }

            Gdip_DisposeImage(pBitmap)
        }

        GetIconData(hwnd) {
            pBitmap := 0
            isUWP := false

            uwpPath := ''
            if InStr(path, 'WindowsApps') || InStr(path, 'ApplicationFrameHost.exe') {
                try {
                    uwpPath := this.__GetLargestUWPLogoPath(hwnd)
                }
            }

            try {
                if uwpPath && FileExist(uwpPath) {
                    pBitmap := Gdip_CreateBitmapFromFile(uwpPath)
                    if pBitmap {
                        isUWP := true
                    }
                }

                if !pBitmap {
                    for size in [256, 128, 48] {
                        hIcon := 0
                        DllCall('PrivateExtractIcons', 'Str', path, 'Int', 0, 'Int', size, 'Int', size, 'Ptr*', &hIcon, 'Ptr*', 0, 'UInt', 1, 'UInt', 0)

                        if hIcon {
                            pBitmap := Gdip_CreateBitmapFromHICON(hIcon)
                            DllCall('DestroyIcon', 'Ptr', hIcon)
                            break
                        }
                    }
                }
            }

            if !pBitmap {
                try {
                    hIcon := 0
                    DllCall('PrivateExtractIcons', 'Str', 'shell32.dll', 'Int', 2, 'Int', 48, 'Int', 48, 'Ptr*', &hIcon, 'Ptr*', 0, 'UInt', 1, 'UInt', 0)

                    if hIcon {
                        pBitmap := Gdip_CreateBitmapFromHICON(hIcon)
                        DllCall('DestroyIcon', 'Ptr', hIcon)
                    }
                }
            }

            return {bitmap: pBitmap, isUWP: isUWP}
        }
    }

    static __GetLargestUWPLogoPath(hwnd) {
        Address := CallbackCreate(EnumChildProc.Bind(WinGetPID(hwnd)), 'Fast', 2)
        DllCall('User32.dll\EnumChildWindows', 'Ptr', hwnd, 'Ptr', Address, 'UInt*', &ChildPID := 0, 'Int')
        CallbackFree(Address)

        ; if no child PID, use the main window's PID
        if !ChildPID {
            ChildPID := WinGetPID(hwnd)
        }

        if !AppHasPackage(ChildPID) {
            return
        }

        try {
            processPath := ProcessGetPath(ChildPID)
            defaultLogoPath := GetDefaultLogoPath(processPath)
            largestPath := GetLargestLogoPath(defaultLogoPath)
            return largestPath
        } catch as e {
            return
        }

        EnumChildProc(PID, hwnd, lParam) {
            ChildPID := WinGetPID(hwnd)
            if ChildPID != PID {
                NumPut('UInt', ChildPID, lParam)
                return false
            }
            return true
        }

        AppHasPackage(ChildPID) {
            static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000, APPMODEL_ERROR_NO_PACKAGE := 15700
            ProcessHandle := DllCall('Kernel32.dll\OpenProcess', 'UInt', PROCESS_QUERY_LIMITED_INFORMATION, 'Int', false, 'UInt', ChildPID, 'Ptr')
            IsUWP := DllCall('Kernel32.dll\GetPackageId', 'Ptr', ProcessHandle, 'UInt*', &BufferLength := 0, 'Ptr', 0, 'Int') != APPMODEL_ERROR_NO_PACKAGE
            DllCall('Kernel32.dll\CloseHandle', 'Ptr', ProcessHandle, 'Int')
            return IsUWP
        }

        GetDefaultLogoPath(Path) {
            SplitPath Path, , &Dir
            if !RegExMatch(FileRead(Dir '\AppxManifest.xml', 'UTF-8'), '<Logo>(.*)</Logo>', &Match) {
                throw Error('Unable to read logo information from file.', -1, Dir '\AppxManifest.xml')
            }
            return Dir '\' Match[1]
        }

        GetLargestLogoPath(Path) {
            LoopFileSize := 0
            SplitPath Path, , &Dir, &Extension, &NameNoExt
            Loop Files Dir '\' NameNoExt '.scale-*.' Extension {
                if A_LoopFileSize > LoopFileSize && RegExMatch(A_LoopFileName, '\d+\.' Extension '$') {
                    LoopFilePath := A_LoopFilePath, LoopFileSize := A_LoopFileSize
                }
            }
            return LoopFilePath ?? ''
        }
    }

    static __OnMouseWheel(wParam, lParam, msg, hwnd) {
        if !this._canScroll || this._clicked.item {
            return
        }

        ; get scroll direction
        wheelDelta := (wParam >> 16) & 0xFFFF
        if wheelDelta > 0x7FFF {
            wheelDelta := wheelDelta - 0x10000
        }

        if wheelDelta > 0 {
            this._targetScrollOffset -= this.scrollPixelOffset
        } else {
            this._targetScrollOffset += this.scrollPixelOffset
        }

        ; clamp target
        maxScrollPixels := this.__GetMaxScrollPixels(
            this._windowList.Length * this._rowWithDivider - this.rowDividerHeight,
            this._menuHeight - this._topBarHeight)
        this._targetScrollOffset := Max(0, Min(this._targetScrollOffset, maxScrollPixels))

        ; start animation if not already running
        if !this._scrollTimerActive {
            this._scrollTimerActive := true
            SetTimer(this._scrollTimer, 3)
        }
    }

    static __OnLeftClick(wParam, lParam, msg, hwnd) {
        DllCall('SetCapture', 'Ptr', this.Menu.Hwnd)
        this.__GetMouseCoordsFromStruct(lParam, &x, &y)

        switch this._searchText {
        case '':
            ; this._searchText := this.placeholderSearchText
            ; UI.__DrawMenu(() {
            ;     this.__UpdateSearchBar()
            ; })

        case this._placeholderSearchText:
            rect := this._searchBarRect
            if rect.ContainsPoint(x, y) {
                this._searchText := ''
                UI.DrawMenu(() {
                    UI.UpdateSearchBar()
                })
                return
            }
        }

        if this.__PointIsOnPartition(x, y) {
            this._clicked.item := 'partition'
            return
        }

        if this._hoveredPanelTab {
            this._clicked.item := this._hoveredPanelTab
            UI.DrawMenu(() => UI.DrawPanelTabs())
            return
        }

        if this._hoveredCloseButton {
            this._clicked.item := 'close'
            this._clicked.index := this._hoveredCloseButton
            return
        }

        if this._hoveredOver {
            this._clicked.item := 'row'
            this._clicked.index := this._hoveredOver
            UI.DrawMenu(() {
                UI.UpdateWindowList()
            })
            return
        }

        rect := this._panelIcon.bg
        if rect.ContainsPoint(x, y) {
            this._clicked.item := 'panelIcon'
            UI.DrawMenu(() {
                UI.UpdatePanelIcon()
            })
            return
        }
    }

    static __OnLeftClickRelease(wParam, lParam, msg, hwnd) {
        LeftClickRelease()
        DllCall('ReleaseCapture')

        LeftClickRelease() {
            item := this._clicked.item

            if !item {
                return
            }

            this._clicked.item := ''
            this.__GetMouseCoordsFromStruct(lParam, &x, &y)

            index := this._clicked.index

            switch item, 'Off' {
            case 'partition':
                return

            case 'panelIcon':
                rect := this._panelIcon.bg
                if rect.ContainsPoint(x, y) {
                    this.TogglePanelVisibility()
                }

                UI.DrawMenu(() {
                    UI.UpdatePanelIcon()
                })
                return

            case 'close':
                for rect in this._closeButtonRects {
                    if rect.actualIndex = index {
                        if rect.ContainsPoint(x, y) {
                            this.__CloseWindow(index)
                            return
                        }
                        break
                    }
                }

            case 'row':
                for rect in this._windowRects {
                    if rect.actualIndex = index {
                        if rect.ContainsPoint(x, y) {
                            this.CloseMenu()
                            this.__ActivateWindow(rect.window)
                            return
                        }
                        break
                    }
                }

            case 'preview', 'info':
                if this._showPanel && x >= this._partitionPos {
                    panelRelativeX := x - this._partitionPos
                    panelRelativeY := y - this._topBarHeight

                    for rect in this._panelTabRects {
                        if rect.ContainsPoint(panelRelativeX, panelRelativeY) {
                            this._panelTab := rect.tab
                            if item != 'preview' {
                                this.__CleanupThumbnail()
                            }
                            UI.DrawMenu(() {
                                UI.UpdatePanel()
                            })
                            return
                        }
                    }

                    if this._hoveredPanelTab {
                        this._hoveredPanelTab := ''
                        UI.DrawMenu(() {
                            UI.DrawPanelTabs()
                        })
                    }
                    return
                }

            default:
                return
            }

            if this.__UpdateMouseHoverState(x, y) {
                UI.DrawMenu(() {
                    UI.UpdateWindowList()
                })
            }
        }
    }

    static __OnMiddleClick(wParam, lParam, msg, hwnd) {
        if this._hoveredOver {
           this._clicked.item := 'row'
           this._clicked.index := this._hoveredOver
            UI.DrawMenu(() {
                UI.UpdateWindowList()
            })
        }
    }

    static __OnMiddleClickRelease(wParam, lParam, msg, hwnd) {
        if this._clicked.item != 'row' {
            return
        }

        index := this._clicked.index
        this._clicked.item := ''

        this.__GetMouseCoordsFromStruct(lParam, &x, &y)

        if this.__PointIsOnWindowList(x, y) {
            for rect in this._windowRects {
                if rect.actualIndex = index {
                    if y >= rect.y1 && y <= rect.y2 {
                        this.__CloseWindow(index)
                    }
                    break
                }
            }
        }

        if this.__UpdateMouseHoverState(x, y) {
            UI.DrawMenu(() {
                UI.UpdateWindowList()
            })
        }
    }

    static __OnMouseLeave(*) {
        this.__ResetClickedAndHoveredItems()
    }

    static __ResetClickedAndHoveredItems(*) {
        this._mouseLeft := true

        hovered := this._hoveredOver || this._hoveredCloseButton
        if hovered {
            this._hoveredOver := 0
            this._hoveredCloseButton := 0

            UI.DrawMenu(() {
                UI.UpdateWindowList()
            })
        }
    }

    ; returns true if successful
    static __UpdateMouseHoverState(x, y) {
        if !this.__PointIsOnWindowList(x, y) {
            this._hoveredOver := 0
            this._hoveredCloseButton := 0
            return true
        }

        newHover := 0
        newHoveredCloseButton := 0

        ; check if hovering over a close button
        for rect in this._closeButtonRects {
            if rect.ContainsPoint(x, y) {
                newHoveredCloseButton := rect.actualIndex
                ; if the mouse is over any close button, ensure the corresponding
                ; row is marked as hovered (useful when not drawing every close button)
                newHover := newHoveredCloseButton
                break
            }
        }

        ; check if hovering over a row
        if !newHoveredCloseButton {
            for rect in this._windowRects {
                if y >= rect.y1 && y <= rect.y2 {
                    newHover := rect.actualIndex
                    break
                }
            }
        }

        ; if hovered row or close button is different
        if newHover != this._hoveredOver || newHoveredCloseButton != this._hoveredCloseButton {
            this._hoveredOver := newHover
            this._hoveredCloseButton := newHoveredCloseButton
            return true
        }
    }

    static __PointIsOnPartition(x, y) {
        if !this._showPanel || y < this._topBarHeight {
            return
        }

        partitionGrabWidth := this.partitionWidth + 6    ; adds 3 pixels on each side to make it easier to grab
        partitionLeft := this._partitionPos - partitionGrabWidth / 2
        partitionRight := partitionLeft + partitionGrabWidth

        if x >= partitionLeft && x <= partitionRight {
            return true
        }
    }

    static __OnPartitionMove(newSplitX) {
        DllCall('SetCursor', 'Ptr', DllCall('LoadCursor', 'Ptr', 0, 'Ptr', 32646))

        if newSplitX < this._minResizableWidth {
            newSplitX := this._minResizableWidth
        }

        if this.menuWidth - newSplitX < this._minResizableWidth {
            newSplitX := this.menuWidth - this._minResizableWidth
        }

        if newSplitX != this._partitionPos {
            this._partitionPos := newSplitX
            UI.DrawMenu(() {
                UI.UpdateWindowList()
                UI.UpdatePanel()
            })
        }
    }

    static __OnKeyPress(ih, vk, sc) {
        static NonRepeatableKeys := Map(
            'Escape',   true,
            'Enter',    true,
            'Home',     true,
            'End',      true,
            'Left',     true,
            'Right',    true,
            'Delete',   true,
            'Tab',      true,
        )

        key := GetKeyName(Format('vk{:x}sc{:x}', vk, sc))

        if key = this._lastPressedKey && NonRepeatableKeys.Has(this._lastPressedKey) {
            return
        }

        this._lastPressedKey := key

        switch key {
        case 'Escape':
            if this._clicked.item {
                this.__ResetClickedAndHoveredItems()
                if this.escapePriority {
                    this.CloseMenu()
                }
                return
            }

            if this.escapePriority || this._searchText = this._placeholderSearchText {
                this.CloseMenu()
                return
            }

            this._searchText := this._placeholderSearchText

        case 'Enter':
            this.ActivateWindowAndCloseMenu()
            return

        case 'Backspace':
            defaultText := this._searchText = this._placeholderSearchText
            if defaultText {
                return
            }

            inputLength := StrLen(this._searchText)

            if inputLength {
                if GetKeyState('Control') {
                    this._searchText := this._placeholderSearchText
                } else {
                    switch inputLength {
                    case 1:  this._searchText := this._placeholderSearchText
                    default: this._searchText := SubStr(this._searchText, 1, -1)
                    }
                }

                this.__ApplySearchFilter()
                this.__RedrawWindowList()
            }

            return

        case 'Home':
            this._lastUsedDevice := 'keyboard'
            this.HighlightFirstRow()
            return

        case 'End':
            this._lastUsedDevice := 'keyboard'
            this.HighlightLastRow()
            return

        case 'Up':
            this._lastUsedDevice := 'keyboard'
            this.HighlightPreviousRow()
            return

        case 'Down':
            this._lastUsedDevice := 'keyboard'
            this.HighlightNextRow()
            return

        case 'Left', 'Right':
            previewTabActive := this._panelTab = 'Preview'
            this._panelTab := previewTabActive ? 'Info' : 'Preview'
            this.__CleanupThumbnail()
            UI.DrawMenu(() => UI.UpdatePanel())
            return

        case 'Space':
            this.__AddInputCharacter(' ')

        case 'Delete':
            this.__CloseWindow()
            return

        case 'Tab':
            if !this._userIsTyping {
                temp := this._clicked.item
                this._clicked.item := 'PanelIcon'
                UI.DrawMenu(() => UI.UpdatePanelIcon())
                this.TogglePanelVisibility()
                Sleep(100)
                this._clicked.item := temp
                UI.DrawMenu(() => UI.UpdatePanelIcon())
            }
            return

        default:
            ; get the actual character including shift state
            char := __GetCharFromVK(vk, sc)

            if StrLen(char) = 1 && char != '' {
                this.__AddInputCharacter(char)
            } else {
                ; ignore special keys
                return
            }
        }

        this.__ApplySearchFilter()
        this.__RedrawWindowList()

        __GetCharFromVK(vk, sc) {
            ; get keyboard state
            static keyState := Buffer(256, 0)
            DllCall('GetKeyboardState', 'Ptr', keyState)

            ; clear the control key state (VK_CONTROL = 0x11)
            NumPut('UChar', 0, keyState, 0x11)

            ; convert VK to character
            charBuf := Buffer(2, 0)
            result := DllCall('ToUnicode', 'UInt', vk, 'UInt', sc, 'Ptr', keyState, 'Ptr', charBuf, 'Int', 2, 'UInt', 0)

            if result > 0 {
                return StrGet(charBuf, result, 'UTF-16')
            }
            return ''
        }
    }

    static __AddInputCharacter(input) {
        if this._searchText = this._placeholderSearchText {
            this._searchText := StrUpper(input)
        } else {
            this._searchText .= StrUpper(input)
        }
    }

    static __AnimateScroll() {
        diff := this._targetScrollOffset - this._scrollOffset

        ; if close enough, snap to target and stop
        if Abs(diff) < 0.5 {
            this._scrollOffset := this._targetScrollOffset
            SetTimer(this._scrollTimer, 0)
            this._scrollTimerActive := false
        } else {
            this._scrollOffset += diff * this.scrollSmoothingValue
        }


        UI.DrawMenu(() {
            this.__GetMouseClientCoords(&x, &y)
            hoverChanged := this.__UpdateMouseHoverState(x, y)
            UI.UpdateWindowList()
            if hoverChanged {
                UI.UpdatePanel()
            }
        })
    }

    static __GetMouseClientCoords(&x, &y) {
        MouseGetPos(&mouseX, &mouseY)

        ; convert screen to client coordinates
        pt := Buffer(8)
        NumPut('Int', mouseX, 'Int', mouseY, pt, 0)
        DllCall('ScreenToClient', 'Ptr', this.Menu.Hwnd, 'Ptr', pt)

        x := NumGet(pt, 0, 'Int')
        y := NumGet(pt, 4, 'Int')
    }

    static __Scroll(amount) {
        totalContentHeight := this._windowList.Length * this._rowWithDivider
        visibleHeight := this._menuHeight - this._topBarHeight
        maxScrollPixels := Max(0, totalContentHeight - visibleHeight)

        this._scrollOffset := Max(0, Min(this._scrollOffset + amount, maxScrollPixels))
        UI.DrawMenu(() {
            UI.UpdateWindowList()
        })
    }

    static __ActivateWindow(window) {
        try {
            WinActivate(window.hwnd)
            return true
        } catch {
            this.__RefreshWindowList()
            this.__ApplySearchFilter()
            this.__RedrawWindowList()
            return false
        }
    }

    static __KeepHighlightedRowVisible() {
        visibleHeight := this._menuHeight - this._topBarHeight

        ; scroll if highlighted row is above visible area
        highlightedRowTop := (this._highlightedRow - 1) * this._rowWithDivider
        if highlightedRowTop < this._scrollOffset {
            this._scrollOffset := ClampOffset(highlightedRowTop)
            return
        }

        ; scroll if highlighted row is below visible area
        highlightedRowBottom := highlightedRowTop + this.rowHeight
        if highlightedRowBottom > this._scrollOffset + visibleHeight {
            this._scrollOffset := ClampOffset(highlightedRowBottom - visibleHeight)
        }

        ClampOffset(offset) {
            maxScrollPixels := this.__GetMaxScrollPixels(
                this._windowList.Length * this._rowWithDivider,
                visibleHeight)
            return Min(offset, maxScrollPixels)
        }
    }

    static __GetMaxScrollPixels(totalContentHeight, visibleHeight) {
        return Max(0, totalContentHeight - visibleHeight)
    }

    ; returns a brighter or darker version of the color passed
    static __ColorBrightnessAutoAdjust(color, offset := 60) {
        r := (color >> 16) & 0xFF
        g := (color >> 8) & 0xFF
        b := color & 0xFF

        brightness := this.__GetColorLuminance(color)

        if (brightness > 150) {     ; if color is already bright, use a dark highlight
            r := Max(0, r - offset)
            g := Max(0, g - offset)
            b := Max(0, b - offset)
        } else {                    ; if color is dark, brighten it
            r := Min(255, r + offset)
            g := Min(255, g + offset)
            b := Min(255, b + offset)
        }

        return (0xFF << 24) | (r << 16) | (g << 8) | b  ; keep full opacity
    }

    ; returns black or white depending on color passed; useful for text that need to be contrasted better on their background
    static __GetContrastingColor(color) {
        r := (color >> 16) & 0xFF
        g := (color >> 8) & 0xFF
        b := color & 0xFF

        brightness := this.__GetColorLuminance(color)
        return brightness < 128 ? 0xFFFFFFFF : 0xFF000000  ; white text for dark backgrounds, black for light
    }

    static __GetColorLuminance(color) {
        r := (color >> 16) & 0xFF
        g := (color >> 8) & 0xFF
        b := color & 0xFF

        ; standard luminance formula
        return  (r * 0.299 + g * 0.587 + b * 0.114)
    }

    static __GetUserThemeColor() {
        return RegRead('HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'AppsUseLightTheme', 0)
    }

    static __FrameShadow(hwnd) {
        DllCall('dwmapi.dll\DwmIsCompositionEnabled', 'Int*', &dwmEnabled:=0)

        if !dwmEnabled {
            DllCall('user32.dll\SetClassLongPtr', 'Ptr', hwnd, 'Int', -26, 'Ptr', DllCall('user32.dll\GetClassLongPtr', 'Ptr', hwnd, 'Int', -26) | 0x20000)
            return
        }

        NumPut('Int', 1, 'Int', 1, 'Int', 1, 'Int', 1, margins := Buffer(16, 0))
        DllCall('dwmapi.dll\DwmSetWindowAttribute', 'Ptr', hwnd, 'Int', 33, 'Int*', 2, 'Int', 4)
        DllCall('dwmapi.dll\DwmExtendFrameIntoClientArea', 'Ptr', hwnd, 'Ptr', margins)
    }

    static __TruncateTextToWidth(text, fontSize, maxPixelWidth, fontName := 'Arial') {
        if maxPixelWidth <= 0 {
            return ''
        }

        if StrLen(text) = 0 {
            return text
        }

        ; create temporary bitmap/graphics for measuring
        tempBitmap := Gdip_CreateBitmap(maxPixelWidth + 100, fontSize + 20)
        tempGraphics := Gdip_GraphicsFromImage(tempBitmap)

        hFont := Gdip_FontFamilyCreate(fontName)
        pFont := Gdip_FontCreate(hFont, fontSize, 1)
        hFormat := Gdip_StringFormatCreate()

        RectF := Buffer(16)
        NumPut('Float', 0, 'Float', 0,
               'Float', maxPixelWidth + 100,
               'Float', fontSize + 20,
                RectF, 0)

        ; measure full text and extract width
        result := Gdip_MeasureString(tempGraphics, text, pFont, hFormat, &RectF)
        width := StrSplit(result, '|')[3]

        if width <= maxPixelWidth {
            Cleanup()
            return text
        }

        ; binary search for longest string that fits
        low := 1
        high := StrLen(text) - 1
        best := 1

        while low <= high {
            mid := (low + high) // 2
            testText := SubStr(text, 1, mid) . '…'
            result := Gdip_MeasureString(tempGraphics, testText, pFont, hFormat, &RectF)
            testWidth := StrSplit(result, '|')[3]

            if testWidth <= maxPixelWidth {
                best := mid
                low := mid + 1
            } else {
                high := mid - 1
            }
        }

        Cleanup()
        return SubStr(text, 1, best) . '…'

        Cleanup() {
            Gdip_DeleteStringFormat(hFormat)
            Gdip_DeleteFont(pFont)
            Gdip_DeleteFontFamily(hFont)
            Gdip_DeleteGraphics(tempGraphics)
            Gdip_DisposeImage(tempBitmap)
        }
    }

    /**
     * @author iseahound
     * @source - https://www.autohotkey.com/boards/viewtopic.php?f=83&p=566016#p566016
     * Modified
     * @returns {Array}
     */
    static __GetAltTabWindowList(options) {
        static  WS_EX_TOOLWINDOW := 0x80,
                GA_ROOTOWNER     := 3,
                ImmersiveShell,
                IApplicationViewCollection

        OSbuildNumber := StrSplit(A_OSVersion, '.')[3]
        if OSbuildNumber <= 17134 {   ; Windows 10 1607 to 1803 and Windows Server 2016
            IID_IApplicationViewCollection := '{2C08ADF0-A386-4B35-9250-0FE183476FCC}'
        } else {
            IID_IApplicationViewCollection := '{1841C6D7-4F9D-42C0-AF41-8747538F10E5}'
        }

        CLSID_ImmersiveShell := '{C2F03A33-21F5-47FA-B4BB-156362A2F239}'
        IID_IUnknown := '{00000000-0000-0000-C000-000000000046}'
        ImmersiveShell := ComObject(CLSID_ImmersiveShell, IID_IUnknown)
        IApplicationViewCollection := ComObjQuery(ImmersiveShell, IID_IApplicationViewCollection, IID_IApplicationViewCollection)

        AltTabList := []
        DetectHiddenWindows(false)

        winTitle        := options.winTitle ?? unset
        winText         := options.winText ?? unset
        excludeTitle    := options.excludeTitle ?? unset
        excludeText     := options.excludeText ?? unset
        WindowFilter    := options.WindowFilter ?? (*) => 0
        newMatchMode    := options.setTitleMatchMode ?? unset

        if IsSet(newMatchMode) {
            oldMatchMode := SetTitleMatchMode(newMatchMode)
            windows := WinGetList(winTitle?, winText?, excludeTitle?, excludeText?)
            SetTitleMatchMode(oldMatchMode)
        } else {
            windows := WinGetList(winTitle?, winText?, excludeTitle?, excludeText?)
        }

        for hwnd in windows {
            owner := DllCall('GetAncestor', 'Ptr', hwnd, 'UInt', GA_ROOTOWNER, 'Ptr')
            owner := owner || hwnd

            if DllCall('GetLastActivePopup', 'Ptr', owner) = hwnd {
                ex := WinGetExStyle(hwnd)

                ; don't add window to list if any of these conditions are true
                if !DllCall('IsWindowVisible', 'Ptr', hwnd)
                || (ex & WS_EX_TOOLWINDOW)
                || !IsWindowOnCurrentVirtualDesktop(hwnd)
                || !ShouldShowWindowInAltTab(hwnd)
                || WindowFilter(hwnd) {
                    continue
                }

                AltTabList.Push(hwnd)
            }
        }

        return AltTabList

        IsWindowOnCurrentVirtualDesktop(hwnd) {
            static IVirtualDesktopManager := ''
            if !IVirtualDesktopManager {
                IVirtualDesktopManager := ComObject(CLSID_VirtualDesktopManager := '{AA509086-5CA9-4C25-8F95-589D3C07B48A}', IID_IVirtualDesktopManager := '{A5CD92FF-29BE-454C-8D04-D82879FB3F1B}')
            }

            ComCall(3, IVirtualDesktopManager, 'UPtr', hwnd, 'Int*', &onCurrentDesktop := 0)   ;
            return onCurrentDesktop
        }

        ShouldShowWindowInAltTab(hwnd) {
            try ComCall(GetViewForHwnd := 6, IApplicationViewCollection, 'UPtr', hwnd, 'Ptr*', &pView := 0)
            pView ??= 0

            if pView {
                ComCall(GetShowInSwitchers := 27, pView, 'Int*', &ShowInSwitchers := 0)
                ObjRelease(pView)
            }
            return ShowInSwitchers ?? 0
        }
    }

    static __GetMouseCoordsFromStruct(lParam, &x, &y) {
        x := lParam & 0xFFFF
        y := lParam >> 16
    }

    static __PointIsOnPanel(x, y) {
        return x > this._partitionPos && y > this._topBarHeight
    }

    static __PointIsOnWindowList(x, y) {
        windowListWidth := this._showPanel ? this._partitionPos : this.menuWidth
        return x < windowListWidth && y > this._topBarHeight
    }

    static __CleanupThumbnail() {
        if this._thumbnail {
            DllCall('dwmapi\DwmUnregisterThumbnail', 'Ptr', this._thumbnail)
            this._thumbnail := 0
        }
        this._lastPreviewHwnd := 0
    }

    static __Cleanup() {
        this.__CleanupThumbnail()
        UI.__Cleanup()
    }

    static __New() {
        this.Menu := Gui('+AlwaysOnTop +ToolWindow -SysMenu -Caption +E0x80000')
        this.__FrameShadow(this.Menu.hwnd)

        this._OnMouseMove           := ObjBindMethod(this, '__OnMouseMove')
        this._OnMouseWheel          := ObjBindMethod(this, '__OnMouseWheel')
        this._OnMouseLeave          := ObjBindMethod(this, '__OnMouseLeave')
        this._OnLeftClick           := ObjBindMethod(this, '__OnLeftClick')
        this._OnLeftClickRelease    := ObjBindMethod(this, '__OnLeftClickRelease')
        this._OnMiddleClick         := ObjBindMethod(this, '__OnMiddleClick')
        this._OnMiddleClickRelease  := ObjBindMethod(this, '__OnMiddleClickRelease')
        this._scrollTimer           := ObjBindMethod(this, '__AnimateScroll')

        SetupInputHook()

        this._sortedWindows := false
        this._allWindows := []

        ; dimensions
        this._x := 0
        this._y := 0
        this._menuHeight := 0
        this._lastWindowListUIWidth := 0
        this._searchBarHeight := 34
        this._tabBarHeight := 40

        this._scrollOffset := 0
        this._targetScrollOffset := 0
        this._hoveredCloseButton := 0
        this._hoveredOver := 0
        this._lastPreviewHwnd := 0
        this._lastWindowCount := 0
        this._thumbnail := 0
        this._mouseLeft := true
        this._canScroll := false
        this._scrollTimerActive := false
        this._lastPressedKey := ''
        this._showPanel := false
        this._windowRects := []
        this._closeButtonRects := []
        this._panelTabRects := []
        this._clicked := {item: '', index: 0}
        this._onWindowActivate := (*) => 0
        this._onMenuOpen := (*) => 0
        this._hoveredPanelTab := ''
        this._panelTab := 'preview'
        this._lastUsedDevice := 'keyboard'
        this._placeholderSearchText := 'Search…'

        this._userIsTyping := false
        this._tempDisablePanel := false
        this._private_searchText := ''

        this.DefineProp('_searchText', {
            Get: (self) => this._private_searchText,
            Set: (self, value) {
                this._private_searchText := value

                emptySearchField := this._private_searchText = this._placeholderSearchText || this._private_searchText = ''

                if !emptySearchField {
                    this._userIsTyping := true

                    if this._showPanel {
                        this._tempDisablePanel := true
                        this._showPanel := false
                    }
                } else if this._userIsTyping {
                    this._userIsTyping := false

                    if this._tempDisablePanel {
                        this._showPanel := true
                        this._tempDisablePanel := false
                    }
                }
            }
        })

        ; see OverrideWindowNames() method for more information
        this.nameOverrides := Map()
        this.nameOverrides.CaseSense := 'Off'

        SetupInputHook() {
            this._ih := InputHook('L0 V')
            this._ih.KeyOpt('{All}', 'N')
            this._ih.OnKeyDown := ObjBindMethod(this, '__OnKeyPress')

            this._ih.OnKeyUp := (ih, vk, sc) {
                key := GetKeyName(Format('vk{:x}sc{:x}', vk, sc))
                if key = this._lastPressedKey {
                    this._lastPressedKey := ''
                }
            }
        }
    }
}


class UI extends Gui {
    static _sections := Map()
    static _isDrawing := false

    static __New() {
        this.Menu := this()
    }

    /**
     * @param {Func} Updates A function that calls the appropriate update methods
     * @example
     * UI.DrawMenu(() {
            UI.UpdatePanelIconUI()
            UI.UpdateWindowListUI()
            UI.UpdatePanelUI()
        })
     */
    static DrawMenu(UpdateUI) {
        if this._isDrawing {
            return
        }

        this._isDrawing := true
        UpdateUI()
        this.UpdateWindow()
        this._isDrawing := false
    }

    static DrawTopBar() {
        TopBar := this._sections['TopBar'].graphics
        Gdip_GraphicsClear(TopBar, TaskSwitcher.colors.topBar | 0x01000000)
    }

    static UpdatePanelIcon() {
        PanelIcon := this._sections['PanelIcon'].graphics
        Gdip_GraphicsClear(PanelIcon, TaskSwitcher.colors.topBar)

        ; draw panelIcon background
        if TaskSwitcher._clicked.item = 'panelIcon' {    ; highlight panel icon
            highlightColor := TaskSwitcher.__ColorBrightnessAutoAdjust(TaskSwitcher.colors.panelIcon)
            pBrush := Gdip_BrushCreateSolid(highlightColor)
        } else {    ; normal draw
            pBrush := Gdip_BrushCreateSolid(TaskSwitcher.colors.panelIcon)
        }

        previousSmoothingMode := Gdip_SetSmoothingMode(PanelIcon, 4)

        panelIconR := 6     ; radius
        background := TaskSwitcher._panelIcon.bg
        Gdip_FillRoundedRectangle(PanelIcon, pBrush, 0, 0, background.size, background.size, panelIconR)
        Gdip_DeleteBrush(pBrush)

        line := TaskSwitcher._panelIcon.line
        panelIconY := line.y

        ; draw panelIcon lines
        pBrush := Gdip_BrushCreateSolid(TaskSwitcher.colors.panelIconLines)
        loop 3 {
            Gdip_FillRoundedRectangle(PanelIcon, pBrush, line.x, panelIconY, line.w, line.h, 2)
            panelIconY += line.spacing * 2 ; this correctly advances Y by (line height + space height)
        }
        Gdip_DeleteBrush(pBrush)
        Gdip_SetSmoothingMode(PanelIcon, previousSmoothingMode)
    }

    static UpdateSearchBar() {
        SearchBar := this._sections['SearchBar'].graphics
        Gdip_GraphicsClear(SearchBar, TaskSwitcher.colors.topBar)
        previousSmoothingMode := Gdip_SetSmoothingMode(SearchBar, 4)

        searchBarRect := TaskSwitcher._searchBarRect

        ; search bar background
        if TaskSwitcher.colors.topBar != TaskSwitcher.colors.searchBar {
            pBrush := Gdip_BrushCreateSolid(TaskSwitcher.colors.searchBar)
            Gdip_FillRoundedRectangle(SearchBar, pBrush, 0, 0, searchBarRect.x2, searchBarRect.h, searchBarRect.r)
            Gdip_DeleteBrush(pBrush)
        }

        ; search bar text
        displayText := SubStr(TaskSwitcher._searchText . Chr(0x200B), 1, 60)

        searchBarOptions := 'x10 y10 s16 '
        searchBarOptions .= (TaskSwitcher._searchText = TaskSwitcher._placeholderSearchText)
            ? 'Italic c' TaskSwitcher.textColors.placeholder
            : 'Bold c' TaskSwitcher.textColors.searchBar

        Gdip_TextToGraphics(searchBar, displayText, searchBarOptions, 'Arial', TaskSwitcher._searchBarRect.x2 - (TaskSwitcher.marginX * 2) - 55, searchBarRect.h)
        Gdip_SetSmoothingMode(SearchBar, previousSmoothingMode)
    }

    static UpdateWindowList() {
        width := TaskSwitcher._showPanel ? TaskSwitcher._partitionPos : TaskSwitcher.menuWidth
        height := TaskSwitcher.__CalculateTotalHeight()

        if width != TaskSwitcher._lastWindowListUIWidth || height != TaskSwitcher._lastWindowListUIHeight {
            TaskSwitcher._lastWindowListUIWidth := width
            TaskSwitcher._lastWindowListUIHeight := height
            this.__DestroyGDIPSection('WindowList')
            this.__CreateGDIPSection('WindowList', width, height)
        }

        WindowList := this._sections['WindowList'].graphics
        Gdip_GraphicsClear(WindowList)
        Gdip_SetInterpolationMode(WindowList, 7)

        ; background
        pBrush := Gdip_BrushCreateSolid(TaskSwitcher.colors.row)
        Gdip_FillRectangle(WindowList, pBrush, 0, 0, width, height)
        Gdip_DeleteBrush(pBrush)

        ; pre-loop variable initalizations
        maxTextWidth := width - TaskSwitcher.iconSize - 15 - 40

        closeButtonSize := TaskSwitcher.closeButtonSize
        closeButtonX := width - TaskSwitcher.marginX - closeButtonSize - 10
        closeButtonY := (TaskSwitcher.rowHeight - closeButtonSize) / 2
        closeButtonOffset := closeButtonSize / 4

        closeButton := {
            line1: {
                x: closeButtonX + closeButtonOffset,
                start: closeButtonX + closeButtonSize - closeButtonOffset,
            },

            line2: {
                x: closeButtonX + closeButtonSize - closeButtonOffset,
                start: closeButtonX + closeButtonOffset
            },
        }

        if TaskSwitcher.fullLengthDividers {
            dividerX := 0
            dividerWidth := width
        } else {
            dividerX := TaskSwitcher.marginX
            dividerWidth := width - (TaskSwitcher.marginX * 2)
        }

        sameRow := TaskSwitcher._hoveredOver = TaskSwitcher._highlightedRow
        useMouse := TaskSwitcher._lastUsedDevice = 'mouse'
        isClicked := TaskSwitcher._clicked.item = 'row'

        TaskSwitcher._windowRects := []
        TaskSwitcher._closeButtonRects := []

        for index, window in TaskSwitcher._windowList {
            rowY := TaskSwitcher._topBarHeight + ((index - 1) * TaskSwitcher._rowWithDivider) - TaskSwitcher._scrollOffset

            if rowY + TaskSwitcher.rowHeight < TaskSwitcher._topBarHeight || rowY > height {
                continue
            }

            y1 := Max(rowY, TaskSwitcher._topBarHeight)

            TaskSwitcher._windowRects.Push({
                x1: 0,
                y1: Max(rowY, TaskSwitcher._topBarHeight),
                x2: width,
                y2: y1 + TaskSwitcher.rowHeight + TaskSwitcher.rowDividerHeight,
                window: window,
                actualIndex: index,
                ContainsPoint: (self, x, y) {
                    return x >= self.x1 && x <= self.x2 && y >= self.y1 && y <= self.y2
                }
            })

            DrawHighlightedRow(index)
            DrawIcon(window)
            DrawWindowText(index, window)
            DrawCloseButton(index)
            DrawDivider(index)
        }

        Gdip_SetInterpolationMode(WindowList, 2)
        return

        /**
         * supporting functions
         */

        DrawIcon(window) {
            iconX := TaskSwitcher.marginX + TaskSwitcher._rowNumberWidth
            iconY := rowY + (TaskSwitcher.rowHeight - TaskSwitcher.iconSize) / 2
            TaskSwitcher.__DrawIcon(window, iconX, iconY)
        }

        DrawWindowText(index, window) {
            isHovered := TaskSwitcher._hoveredOver = index

            if isHovered && (!sameRow || useMouse) {
                textColor := isClicked ? TaskSwitcher.textColors.rowClickHighlight : TaskSwitcher.textColors.rowHoverHighlight
            } else if TaskSwitcher._highlightedRow = index {
                textColor := TaskSwitcher.textColors.rowHighlight
            } else {
                textColor := TaskSwitcher.textColors.row
            }

            if TaskSwitcher.showRowNumbers && index <= 10 {
                x := 'x' TaskSwitcher.marginX
                y := 'y' rowY + (TaskSwitcher.rowHeight - 24) / 2

                Gdip_TextToGraphics(WindowList, SubStr(index, -1), x . ' ' y . ' Bold s24 c' textColor, 'Arial', 20, 20)
            }

            ; truncate text before rendering instead of letting Gdip scale it
            truncatedName := TaskSwitcher.__TruncateTextToWidth(window.name, 18, maxTextWidth)
            truncatedTitle := TaskSwitcher.__TruncateTextToWidth(window.title, 16, maxTextWidth)

            windowOptions := 'x' TaskSwitcher._titleX ' y' (rowY +  8) ' s18 Bold c' textColor
            titleOptions  := 'x' TaskSwitcher._titleX ' y' (rowY + 28) ' s16 c' textColor

            ; pass a very large width to prevent scaling, since we've already truncated
            Gdip_TextToGraphics(WindowList, truncatedName, windowOptions, 'Arial', 5000, 20)
            Gdip_TextToGraphics(WindowList, truncatedTitle, titleOptions, 'Arial', 5000, 20)
        }

        DrawHighlightedRow(index) {
            clicked := TaskSwitcher._clicked
            if clicked.item ~= 'row|close' && index = clicked.index {
                HighlightRow(TaskSwitcher.colors.rowClickHighlight)
                return
            }

            if TaskSwitcher._hoveredOver = index {                              ; mouse is hovered over row being checked
                if !(TaskSwitcher._hoveredOver = TaskSwitcher._highlightedRow)  ; mouse is not hovered over keyboard-highlighted row
                || TaskSwitcher._lastUsedDevice = 'mouse' {                     ; last used device is the mouse
                    HighlightRow(TaskSwitcher.colors.rowHoverHighlight)                  ; highlight row as mouse hover color
                    return
                }
            }

            ; triggers if:
            ; mouse is not hovered over row being checked
            ; mouse is hovered over keyboard-highlighted row
            ; last used device is the keyboard
            if TaskSwitcher._highlightedRow = index {                          ; if keyboard-highlighted row is row being checked
                HighlightRow(TaskSwitcher.colors.rowHighlight)              ; highlight row as row highlight
            }

            HighlightRow(color) {
                if !(color is Array) {
                    pBrushHover := Gdip_BrushCreateSolid(color)
                    Gdip_FillRectangle(WindowList, pBrushHover, 0, rowY, width, TaskSwitcher.rowHeight)
                    Gdip_DeleteBrush(pBrushHover)
                    return
                }

                ; create a gradient.
                previousSmoothingMode := Gdip_SetSmoothingMode(WindowList, 0)
                colors := color
                colorCount := colors.Length
                colorHeight := (TaskSwitcher.rowHeight / colorCount)

                if colorCount = 2 {
                    color1 := colors[1]
                    color2 := colors[2]

                    pBrushHover := Gdip_BrushCreateSolid(color1)
                    Gdip_FillRectangle(WindowList, pBrushHover, 0, rowY, width, colorHeight)
                    Gdip_DeleteBrush(pBrushHover)

                    pBrushHover := Gdip_CreateLineBrushFromRect(0, rowY + colorHeight, width, colorHeight, color1, color2, 1)
                    Gdip_FillRectangle(WindowList, pBrushHover, 0, rowY + colorHeight, width, colorHeight)
                    Gdip_DeleteBrush(pBrushHover)

                } else {
                    gradientSize := TaskSwitcher.rowHeight / (colorCount - 1)

                    loop colorCount - 1 {
                        color1 := colors[A_Index]
                        color2 := colors[A_Index+1]

                        offset := gradientSize * (A_Index - 1)
                        pBrushHover := Gdip_CreateLineBrushFromRect(0, rowY + offset, width, gradientSize, color1, color2, 1)
                        Gdip_FillRectangle(WindowList, pBrushHover, 0, rowY + offset, width, gradientSize)
                        Gdip_DeleteBrush(pBrushHover)
                    }
                }

                Gdip_SetSmoothingMode(WindowList, previousSmoothingMode)
            }
        }

        DrawCloseButton(index) {
            ; draw close button (X)
            if TaskSwitcher._hoveredOver = index || TaskSwitcher.showCloseButtonsOnAllRows {
                closeButtonY += rowY

                TaskSwitcher._closeButtonRects.Push({
                    x1: closeButtonX,
                    y1: closeButtonY,
                    x2: closeButtonX + closeButtonSize,
                    y2: closeButtonY + closeButtonSize,
                    actualIndex: index,
                    ContainsPoint: (self, x, y) {
                        return x >= self.x1 && x <= self.x2 && y >= self.y1 && y <= self.y2
                    }
                })

                ; close background color - highlighted or not
                isHoveringCloseButton := (TaskSwitcher._hoveredCloseButton = index)
                if isHoveringCloseButton {
                    pBrushClose := Gdip_BrushCreateSolid(TaskSwitcher.colors.closeButtonHoverHighlight)
                    pPen := Gdip_CreatePen(TaskSwitcher.colors.closeButtonXHoverHighlight, 2)
                } else {
                    pBrushClose := Gdip_BrushCreateSolid(TaskSwitcher.colors.closeButton)
                    pPen := Gdip_CreatePen(TaskSwitcher.colors.closeButtonX, 2)
                }

                previousSmoothingMode := Gdip_SetSmoothingMode(WindowList, 4)
                Gdip_FillEllipse(WindowList, pBrushClose, closeButtonX, closeButtonY, closeButtonSize, closeButtonSize)
                Gdip_SetSmoothingMode(WindowList, previousSmoothingMode)
                Gdip_DeleteBrush(pBrushClose)

                lineEndPoint := closeButtonY + closeButtonSize - closeButtonOffset

                ; line 1
                Gdip_DrawLine(WindowList, pPen, closeButton.line1.x, closeButtonY + closeButtonOffset, closeButton.line1.start, lineEndPoint)

                ; line 2
                Gdip_DrawLine(WindowList, pPen, closeButton.line2.x, closeButtonY + closeButtonOffset, closeButton.line2.start, lineEndPoint)
                Gdip_DeletePen(pPen)
            }
        }

        DrawDivider(index) {
            if index < TaskSwitcher._windowList.Length {
                dividerY := rowY + TaskSwitcher.rowHeight
                if dividerY > TaskSwitcher._topBarHeight && dividerY < height {
                    pBrushDiv := Gdip_BrushCreateSolid(TaskSwitcher.colors.rowDivider)
                    Gdip_FillRectangle(WindowList, pBrushDiv, dividerX, dividerY, dividerWidth, TaskSwitcher.rowDividerHeight)
                    Gdip_DeleteBrush(pBrushDiv)
                }
            }
        }
    }

    static UpdatePanel() {
        if !TaskSwitcher._showPanel {
            TaskSwitcher.__CleanupThumbnail()
            return
        }

        width := TaskSwitcher.menuWidth - TaskSwitcher._partitionPos
        height := TaskSwitcher._menuHeight - TaskSwitcher._topBarHeight

        if TaskSwitcher._lastWindowListUIWidth != TaskSwitcher._partitionPos || height != TaskSwitcher._lastWindowListUIHeight {
            this.__DestroyGDIPSection('Panel')
            this.__CreateGDIPSection('Panel', width, height)
        }

        Panel := this._sections['Panel'].graphics
        Gdip_GraphicsClear(Panel, 0x01000000)

        ; draw panel background
        pBrushPanel := Gdip_BrushCreateSolid(TaskSwitcher.colors.panel)
        Gdip_FillRectangle(Panel, pBrushPanel, 0, 0, width, height)
        Gdip_DeleteBrush(pBrushPanel)

        ; partition
        partitionWidth := TaskSwitcher.partitionWidth
        if TaskSwitcher.fullLengthPartition {
            partitionY := 0
            partitionHeight := height
        } else {
            partitionY := TaskSwitcher.marginY
            partitionHeight := height - (TaskSwitcher.marginY * 2)
        }

        pBrushPartition := Gdip_BrushCreateSolid(TaskSwitcher.colors.partition)
        Gdip_FillRectangle(Panel, pBrushPartition, 0, partitionY, partitionWidth, partitionHeight)  ; draw partition
        if TaskSwitcher.fullLengthPartition {
            Gdip_FillRectangle(Panel, pBrushPartition, 0, 0, width, partitionWidth) ; draw top partition
        }
        Gdip_DeleteBrush(pBrushPartition)

        this.DrawPanelTabs(Panel)

        ; draw tab content
        tabHeight := TaskSwitcher._tabBarHeight
        useMousedRow := TaskSwitcher.allowMouseToUpdatePanel && TaskSwitcher._lastUsedDevice = 'mouse' && TaskSwitcher._hoveredOver
        row := useMousedRow ? TaskSwitcher._hoveredOver : TaskSwitcher._highlightedRow

        if TaskSwitcher._windowList.Length = 0 {
            Panel := this._sections['Panel'].graphics
            if TaskSwitcher._panelTab = 'preview'  {
                availableWidth := width - (TaskSwitcher.marginX * 2)
                availableHeight := height - (TaskSwitcher.marginY * 2)

                x := TaskSwitcher.marginX
                y := tabHeight + TaskSwitcher.marginY + (availableHeight / 2) - 8

                options := 'x' x ' y' y ' s24 cFFC0C0C0 Center Bold'
                Gdip_TextToGraphics(Panel, 'No matches', options, 'Arial', availableWidth, availableHeight)
                TaskSwitcher.__CleanupThumbnail()
            } else {
                x := TaskSwitcher.marginX
                y := tabHeight + TaskSwitcher.marginY
                Gdip_TextToGraphics(Panel, "No information available", 'x' x ' y' y ' s16 cFFC0C0C0', 'Arial', width - (TaskSwitcher.marginX * 2), 30)
            }
            return
        }

        if row > 0 && row <= TaskSwitcher._windowList.Length {
            window := TaskSwitcher._windowList[row]

            if TaskSwitcher._panelTab = 'preview' {
                TaskSwitcher.__UpdatePanelPreview(window, 0, tabHeight, width, height - tabHeight)
            } else {
                TaskSwitcher.__UpdatePanelInfo(window, 0, tabHeight, width, height - tabHeight)
            }
        }
    }

    static UpdateWindow() {
        width := TaskSwitcher.menuWidth
        height := TaskSwitcher._menuHeight

        if height != TaskSwitcher._lastWindowUIHeight {
            UI.__DestroyGDIPSection('Window')
            UI.__CreateGDIPSection('Window', width, height)
            TaskSwitcher._lastWindowUIHeight := height
        }

        Window := UI._sections['Window']
        Gdip_GraphicsClear(Window.graphics, 0x01000000)

        listWidth := TaskSwitcher._showPanel ? TaskSwitcher._partitionPos : width
        panelIcon := TaskSwitcher._panelIcon.bg
        searchBar := TaskSwitcher._searchBarRect
        sections  := UI._sections

        BitBlt(Window.hdc, 0, 0, listWidth, height, sections['WindowList'].hdc, 0, 0)
        BitBlt(Window.hdc, 0, 0, width, TaskSwitcher._topBarHeight, sections['TopBar'].hdc, 0, 0)
        BitBlt(Window.hdc, panelIcon.x1, panelIcon.y1, panelIcon.size, panelIcon.size, sections['PanelIcon'].hdc, 0, 0)
        BitBlt(Window.hdc, searchBar.x1, searchBar.y1, searchBar.x2, searchBar.h, sections['SearchBar'].hdc, 0, 0)

        if TaskSwitcher._showPanel {
            panelWidth := width - TaskSwitcher._partitionPos
            panelHeight := height - TaskSwitcher._topBarHeight
            BitBlt(Window.hdc, TaskSwitcher._partitionPos, TaskSwitcher._topBarHeight, panelWidth, panelHeight, sections['Panel'].hdc, 0, 0)
        }

        if TaskSwitcher.coordinates = 'Recenter' {
            MonitorGetWorkArea(TaskSwitcher.monitorToDisplayOn, &left, &top, &right, &bottom)
            TaskSwitcher._y := top + (bottom - top - height) / 2
        }

        UpdateLayeredWindow(TaskSwitcher.Menu.Hwnd, Window.hdc, TaskSwitcher._x, TaskSwitcher._y, width, height)
    }

    static DrawPanelTabs(Panel := UI._sections['Panel'].graphics) {
        static tabs := ['Preview', 'Info']
        TaskSwitcher._panelTabRects := []

        width := TaskSwitcher.menuWidth - TaskSwitcher._partitionPos
        tabHeight := TaskSwitcher._tabBarHeight

        spacing := TaskSwitcher.marginX
        partitionSize := TaskSwitcher.partitionWidth * TaskSwitcher.fullLengthPartition
        halfPartitionSize := TaskSwitcher.partitionWidth / 2
        y := partitionSize + (TaskSwitcher.marginY * TaskSwitcher.fullLengthPartition)

        ; available space for tabs (minus partition and margins)
        availableWidth := width - halfPartitionSize - (spacing * 3)     ; left margin, between, right margin
        tabWidth := availableWidth / tabs.Length

        oldMode := Gdip_SetSmoothingMode(Panel, 4)

        for index, tabName in tabs {
            offset := index = 1 ? halfPartitionSize : 0
            x := offset + spacing + ((index - 1) * (tabWidth + spacing))

            bgColor := GetColorAdjustmentValue(index, tabName)
            pBrush := Gdip_BrushCreateSolid(bgColor)

            Gdip_FillRoundedRectangle(Panel, pBrush, x, y, tabWidth, tabHeight - TaskSwitcher.marginY, 6)
            Gdip_DeleteBrush(pBrush)

            textColor := TaskSwitcher.textColors.panelTab
            options := 'x' x ' y' (y + 6) ' s14 Bold c' textColor ' Center'
            Gdip_TextToGraphics(Panel, tabName, options, 'Arial', tabWidth, tabHeight - (y * 2))

            TaskSwitcher._panelTabRects.Push({
                x1:  x,
                y1:  y,
                x2:  x + tabWidth,
                y2:  y + (tabHeight - TaskSwitcher.marginY),
                tab: tabName,
                ContainsPoint: (self, x, y) {
                    return x >= self.x1 && x <= self.x2 && y >= self.y1 && y <= self.y2
                }
            })
        }

        Gdip_SetSmoothingMode(Panel, oldMode)

        GetColorAdjustmentValue(index, tabName) {
            colors := TaskSwitcher.colors

            if TaskSwitcher._clicked.item = tabName {                                       ; tab is clicked
                return colors.panelTabClickHighlight
            } else if TaskSwitcher._hoveredPanelTab = (index = 1 ? 'preview' : 'info') {    ; tab is hovered
                return colors.panelTabHoverHighlight
            } else if TaskSwitcher._panelTab = (index = 1 ? 'preview' : 'info') {           ; tab is active
                return colors.panelTabActive
            } else {
                return colors.panelTabInactive
            }
        }
    }

    static __CreateGDIPSection(sectionKey, w, h) {
        section := this._sections.Get(sectionKey, 0)
        if section {
            return
        }

        section := this._sections[sectionKey] := {}
        section.bitmap   := CreateDIBSection(w, h)
        section.hdc      := CreateCompatibleDC()
        section.obm      := SelectObject(section.hdc, section.bitmap)
        section.graphics := Gdip_GraphicsFromHDC(section.hdc)
    }

    static __DestroyGDIPSection(sectionKey) {
        section := this._sections.Get(sectionKey, 0)
        if !section {
            return
        }

        section := this._sections[sectionKey]
        Gdip_DeleteGraphics(section.graphics)
        SelectObject(section.hdc, section.obm)
        DeleteDC(section.hdc)
        DeleteObject(section.bitmap)
        this._sections.Delete(sectionKey)
    }

    static __Cleanup() {
        for section in this._sections {
            this.__DestroyGDIPSection(section)
        }
    }
}

/**
 * @plankoe @swagfag
 * @source https://old.reddit.com/r/AutoHotkey/comments/11dnz2l/enumerating_via_for_key_value_in_var_out_of/jaaknw6/
 */
class OrderedMap extends Map {
    __New(KVPairs*) {
        super.__New(KVPairs*)
        KeyArray := []
        keyCount := KVPairs.Length // 2
        KeyArray.Length := keyCount
        Loop keyCount
            KeyArray[A_Index] := KVPairs[(A_Index << 1) - 1]
        this.KeyArray := KeyArray
    }

    __Enum(*) {
        keyEnum := this.KeyArray.__Enum(1)
        return (&key?, &val?) => (
            keyEnum(&key) ? (val := this[key], true) : false
        )
    }
}