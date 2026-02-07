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
class TaskSwitcher {
    ; @OPTIONS that can be changed here or used as a property name when passing options to TaskSwitcher({option: value})
    ; Note - Options that go through Gdip_TextToGraphics require ARGB format as a string (e.g. 'FF00FF00' is an opaque green)
    ;        while other color options use a 0xARGB (hex) number (e.g. 0xFF00FF00 is opaque green).
    ;        I have made it so all explicit colors passed use 0xARGB. The appropriate options are converted to their naturally-accepted format.

    /**
     * Most colors can be set to 'Auto' except rowBackgroundColor and bannerColor
     *
     * When set to auto, all colors use the background they're on to determine their color.
     * However, some colors like texts and the panel icon lines will be set to black or white to ensure high constrast.
     * The other colors will be set to a brighter/darker version of the color they're on to be thematic while offering some contrast.
     *
     * Some color options support an array of colors that will dictate a gradient.
     * If only two colors are supplied, the gradient is not a 50%-50% split. This is because if the second color starts blending too soon, it can affect visibility of the text.
     * No considerations are done if more than two colors are supplied, you must use your own judgement if the text visibility is good enough for you.
     * Those options that support gradients are: rowSelectedColor, mouseRowSelectedBackgroundColor, and mouseRowHoverBackgroundColor
     */
    ; static rowBackgroundColor               := 0xFF333333,
    ;        rowTextColor                     := 0xFFFFFFFF,
    ;        rowSelectedColor                 := 0x30FFFFFF,
    ;        rowSelectedTextColor             := 0xFF6995DB,
    ;        mouseRowHoverTextColor           := 0xFF6995DB,
    ;        mouseRowHoverBackgroundColor     := 0x30FFFFFF,
    ;        mouseRowSelectedBackgroundColor  := 'Auto',

    ;        bannerColor                      := 0xFF1B56B5,
    ;        bannerTitleColor                 := 0xFFFFFFFF,
    ;        placeholderTextColor             := 0xFFC8C8C8,
    ;        searchTextColor                  := 0xFFFFFFFF,
    ;        searchBackgroundColor            := 0xFF333333,
    ;        closeBackgroundColor             := 0x40FFFFFF,
    ;        closeHoverBackgroundColor        := 0x80FF0000,
    ;        closeXColor                      := 0xFFAAAAAA,
    ;        closeXHoverColor                 := 0xFFFFFFFF,
    ;        panelBackgroundColor             := 0xFF333333,
    ;        panelIconBackgroundColor         := 0xFF333333,
    ;        panelIconLinesColor              := 0xFFFFFFFF,
    ;        rowDividerColor                  := 0xFFFFFFFF,
    ;        partitionColor                   := 0xFFFFFFFF,

    static rowBackgroundColor               := 0xFF333333,
           rowTextColor                     := 'Auto',
           rowSelectedColor                 := 'Auto',
           rowSelectedTextColor             := 'Auto',
           rowDividerColor                  := 'Auto',
           mouseRowHoverTextColor           := 'Auto',
           mouseRowHoverBackgroundColor     := 'Auto',
           mouseRowSelectedBackgroundColor  := 'Auto',
           mouseRowSelectedTextColor        := 'Auto',

           bannerColor                      := 0xFF1B56B5,
           bannerTitleColor                 := 'Auto',
           placeholderTextColor             := 'Auto',
           searchTextColor                  := 'Auto',
           searchBackgroundColor            := 'Auto',
           closeBackgroundColor             := 'Auto',
           closeHoverBackgroundColor        := 'Auto',
           closeXColor                      := 'Auto',
           closeXHoverColor                 := 'Auto',
           panelBackgroundColor             := 'Auto',
           panelHeaderTextColor             := 'Auto',
           panelBodyTextColor               := 'Auto',
           panelIconBackgroundColor         := 'Auto',
           panelIconLinesColor              := 'Auto',
           partitionColor                   := 'Auto',

           bannerTitle                      := 'Task Switcher',
           placeholderSearchText            := '',
           monitor                          := MonitorGetPrimary(),     ; any valid number that represents a monitor you have (can use MonitorGetCount() to find out the the max)
           marginX                          := 12,
           marginY                          := 12,
           menuWidth                        := 700,
           bannerHeight                     := 90,
           rowHeight                        := 75,
           iconSize                         := 32,
           rowDividerHeight                 := 1,
           closeButtonSize                  := 24,
           partitionWidth                   := 2,
           maxVisibleRows                   := 8,
           scrollSmoothness                 := 0.35,    ; higher values make it feel snappier and less smooth
           scrollPixelOffset                := 40,
           defaultPanelSizePercent          := 0.5,     ; 0.0-1.0 float

           wrapRowSelection                 := true,
           alwaysHighlightFirst             := true,    ; applies to filtering windows when typing
           showAllCloseButtons              := false,
           escapeAlwaysClose                := false,   ; alternatively, you could also just use a hotkey to do the same thing
           showPanelOnOpen                  := true,
           fullLengthDividers               := false,
           fullLengthPartition              := true,
           preventResize                    := false,
           closeOnOutsideClick              := true,    ; closes the menu if you click with any mouse button outside the menu
           clickPassthrough                 := false,
           rowNumbers                       := true,
           mouseRowHoverUpdatesPanel        := true,


        /**
         * @coordinates option
          * 4 valid values: 'Center', 'Recenter', 'Mouse', {x: xPos, y: yPos}
          * Center - Centers the UI in the middle of your primary monitor.
          * Recenter - Same as center except when you type to filter windows, the smaller list will continue to keep the UI centered.
          * Mouse - UI spawns wherever the mouse is.
          * {x: xPos, y: yPos} - Custom coordinates object.
         */
           coordinates := 'Center'


    ; @END_OF_OPTIONS --------------------------------


    static isOpen => WinExist('ahk_id' this.Menu.Hwnd)
    static isActive => WinActive('ahk_id' this.Menu.Hwnd)
    static hasMouseOver => (MouseGetPos(,, &win), win = TaskSwitcher.Menu.Hwnd)

    static ToggleMenuSorted(options := {}) {
        if this.open {
            this.CloseMenu()
            return
        }

        this.__OpenMenu(options, true)
    }

    static ToggleMenu(options := {}) {
        if this.open {
            this.CloseMenu()
            return
        }

        this.__OpenMenu(options, false)
    }

    static OpenMenuSorted(options := {}) {
        if this.open {
            return
        }

        this.__OpenMenu(options, true)
    }

    static OpenMenu(options := {}) {
        if this.open {
            return
        }

        this.__OpenMenu(options, false)
    }

    static CloseMenu() {
        if !this.open {
            return
        }

        Critical(10)    ; attempt to prevent scenarios where computer is under heavy load (like a game running) and inputhook isn't stopped for some reason

        DllCall('ReleaseCapture')
        this._ih.Stop()
        this.Menu.Hide()
        OnMessage(0x200, this._OnMouseMove, 0)
        OnMessage(0x20A, this._OnMouseWheel, 0)
        OnMessage(0x2A3, this._OnMouseLeave, 0)
        OnMessage(0x201, this._OnLeftClick, 0)
        OnMessage(0x202, this._OnLeftClickRelease, 0)
        OnMessage(0x203, this._OnRightClick, 0)
        OnMessage(0x204, this._OnRightClickRelease, 0)
        OnMessage(0x207, this._OnMiddleClick, 0)
        OnMessage(0x208, this._OnMiddleClickRelease, 0)

        this._lastUsedDevice := 'keyboard'
        this._lastPreviewHwnd := 0
        this._windowRects := []
        this._hoveredOver := 0
        this._hoveredCloseButton := 0
        this._clicked := {item: '', index: 0}
        this._mouseLeft := true
        this._tempDisablePanel := false                 ; needs to come before this._searchText
        this._userIsTyping := false
        this._showInfoPanel := this.showPanelOnOpen
        this._searchText := this.placeholderSearchText

        this._scrollOffset := 0
        this._targetScrollOffset := 0
        this.open := false
        Critical('Off')
    }

    static ActivateWindowAndCloseMenu(selectedRow := this._selectedRow) {
        this.CloseMenu()
        this.ActivateWindow(selectedRow)
    }

    static ActivateWindow(selectedRow := this._selectedRow) {
        if this.Menu.windows.Has(selectedRow) {
            window := this.Menu.windows[selectedRow]
            if this.__ActivateWindow(window) {
                this._onWindowActivate(window)
            }
        }
    }

    static SelectPreviousWindow() {
        if this._selectedRow > 1 {
            this._selectedRow -= 1
        } else if this.wrapRowSelection {
            this._selectedRow := this.Menu.windows.Length
        } else {
            return  ; returns if no changes were made
        }

        this.__KeepSelectedRowVisible()
        this.__DrawMenu(() {
            this.__UpdateWindowList()
            this.__UpdatePanel()
        })
    }

    static SelectNextWindow() {
        if this._selectedRow < this.Menu.windows.Length {
            this._selectedRow += 1
        } else if this.wrapRowSelection {
            this._selectedRow := 1
        } else {
            return  ; returns if no changes were made
        }

        this.__KeepSelectedRowVisible()
        this.__DrawMenu(() {
            this.__UpdateWindowList()
            this.__UpdatePanel()
        })
    }

    static SelectFirstRow() {
        if this._selectedRow != 1 {
            this._selectedRow := 1
            this.__KeepSelectedRowVisible()
            this.__DrawMenu(() {
                this.__UpdateWindowList()
            })
        }
    }

    static SelectLastRow() {
        last := this.Menu.windows.Length
        if this._selectedRow != last {
            this._selectedRow := last
            this.__KeepSelectedRowVisible()
            this.__DrawMenu(() {
                this.__UpdateWindowList()
            })
        }
    }

    static TogglePanel() {
        if this._userIsTyping {
            return false
        }

        this._showInfoPanel ^= 1
        this.__DrawMenu(() {
            this.__UpdateWindowList()
            this.__UpdatePanel()
        })
        return true
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
            Critical(10)
            altTabHotkeysEnabled := true
            TaskSwitcher.OpenMenu({index: 2})
            Critical('Off')
        }, state)

        HotIf((*) => altTabHotkeysEnabled && TaskSwitcher.isActive)
        Hotkey('!Tab', (*) => TaskSwitcher.SelectNextWindow(), state)
        Hotkey('+!Tab', (*) => TaskSwitcher.SelectPreviousWindow(), state)
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
            } else if this.open && WinWaitActive(this.Menu.Hwnd,, 2) {   ; in the process of opening
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
        Hotkey('!Escape', (*) => 0)
    }

    static CtrlAltTab() {
        Hotkey('!^Tab', (*) => 0)
    }

    /**
     * Allows custom name overrides. This exists because I couldn't find Steam's actual DisplayName/ProductName.
     * Expects an even-amount of parameters as if you were passing them to a Map.
     * @example
     * position 1: steamhelper
     * position 2: Steam
     * repeat for every window name change
     * @end
     */
    static OverrideWindowNames(exe_name_pairs*) {
        this.nameOverrides.Set(exe_name_pairs*)
    }

    static Call(options := {}) {
        for option, value in options.OwnProps() {
            if !this.HasOwnProp(option) {
                throw Error(option ' option doesn`'t exist. Make sure you spelled it correctly.')
            }
            this.%option% := value
        }

        if this.closeOnOutsideClick {
            passthrough := this.clickPassthrough ? '~' : ''
            ; closes task switcher if click happens outside the menu
            HotIf((*) => TaskSwitcher.isOpen && !TaskSwitcher.hasMouseOver)
            for button in ['LButton', 'RButton', 'MButton', 'XButton1', 'XButton2'] {
                key := Format('{}*{}', passthrough, button)
                Hotkey(key, (*) => this.CloseMenu())
            }
            HotIf()
        }

        if this.rowNumbers {
            HotIf((key) => TaskSwitcher.isOpen && this.Menu.windows.Has(key))
            loop 9 {
                Hotkey(A_Index, (key) => this.ActivateWindowAndCloseMenu(key))
            }
            HotIf((key) => TaskSwitcher.isOpen && this.Menu.windows.Has(10))
            Hotkey('0', (key) => this.ActivateWindowAndCloseMenu(10))
            HotIf()
        }

        VariousPropertiesSetup()
        ColorSetup()
        TextOptionsSetup()
        SearchBarDimensions()
        PanelIconDimensions()

        this.__InitBanner()
        this.__InitSearchBar()
        this.__InitPanelIcon()
        this.__InitWindowList()
        this.__InitPanel()
        this.__InitWindow()


        ; auxiliary setup initialization -----------------------------
        ColorSetup() {
            textColors := ['bannerTitleColor', 'searchTextColor', 'placeholderTextColor',
                        'rowSelectedTextColor', 'mouseRowHoverTextColor', 'rowTextColor',
                        'panelHeaderTextColor', 'panelBodyTextColor', 'mouseRowSelectedTextColor']

            colors := ['rowBackgroundColor', 'bannerColor', 'rowTextColor', 'rowSelectedColor', 'mouseRowHoverBackgroundColor',
                       'mouseRowHoverTextColor', 'mouseRowSelectedBackgroundColor', 'mouseRowSelectedTextColor', 'partitionColor', 'rowDividerColor',
                       'rowSelectedTextColor', 'searchBackgroundColor', 'closeBackgroundColor', 'closeHoverBackgroundColor',
                       'closeXColor', 'closeXHoverColor', 'panelBackgroundColor', 'panelIconBackgroundColor',
                       'panelIconLinesColor', 'placeholderTextColor', 'searchTextColor', 'bannerTitleColor',
                       'panelHeaderTextColor', 'panelBodyTextColor']

            EnsureColorHasAlpha()
            EnsureTextColorsAreFormatted()

            /**
             * Color Functions
             */
            EnsureTextColorsAreFormatted() {
                for textColor in textColors {
                    color := this.%textColor%
                    try this.%textColor% := Format('{:08X}', color) ; 0xARGB to string
                    catch {
                        throw Error('The color: ' color '`nis incorrect for option: ' textColor)
                    }
                }
            }

            EnsureColorHasAlpha() {
                for property in colors {
                    color := this.%property%

                    if color = 'Auto' {
                        switch property {
                        case 'closeBackgroundColor', 'panelBackgroundColor', 'rowDividerColor':
                            ColorBrightnessAutoAdjust(property, this.rowBackgroundColor)
                        case 'searchBackgroundColor', 'panelIconBackgroundColor':
                            ColorBrightnessAutoAdjust(property, this.bannerColor)
                        case 'placeholderTextColor':
                            ColorBrightnessAutoAdjust(property, this.searchBackgroundColor)
                        case 'closeXHoverColor':
                            ColorBrightnessAutoAdjust(property, this.closeHoverBackgroundColor)
                        case 'partitionColor':
                            ColorBrightnessAutoAdjust(property, this.panelBackgroundColor)

                        case 'rowSelectedColor':
                            ColorBrightnessAutoAdjustPossibleArray(property, this.rowBackgroundColor)
                        case 'mouseRowHoverBackgroundColor':
                            ColorBrightnessAutoAdjustPossibleArray(property, this.rowBackgroundColor)
                        case 'mouseRowSelectedBackgroundColor':
                            ColorBrightnessAutoAdjustPossibleArray(property, this.mouseRowHoverBackgroundColor)

                        case 'mouseRowHoverTextColor':
                            GetContrastingColorPossibleArray(property, this.mouseRowHoverBackgroundColor)
                        case 'rowSelectedTextColor':
                            GetContrastingColorPossibleArray(property, this.rowSelectedColor)

                        case 'closeXColor':
                            GetContrastingColor(property, this.closeBackgroundColor)
                        case 'panelIconLinesColor':
                            GetContrastingColor(property, this.panelIconBackgroundColor)
                        case 'bannerTitleColor':
                            GetContrastingColor(property, this.bannerColor)
                        case 'placeholderTextColor', 'searchTextColor':
                            GetContrastingColor(property, this.searchBackgroundColor)
                        case 'rowTextColor':
                            GetContrastingColor(property, this.rowBackgroundColor)
                        case 'panelHeaderTextColor', 'panelBodyTextColor':
                            GetContrastingColor(property, this.panelBackgroundColor)
                        case 'mouseRowSelectedTextColor':
                            GetContrastingColor(property, this.mouseRowSelectedBackgroundColor)
                        default:
                            throw Error('Auto option is not supported for this property: ' property)
                        }

                    } else if color is Array {
                        for index, color in color {
                            this.%property%[index] := color | 0x01000000
                        }
                    } else {
                        this.%property% := color | 0x01000000
                    }
                }

                ; supporting color functions
                GetContrastingColorPossibleArray(property, color) {
                    if color is Array {
                        color := color[1]
                    }
                    GetContrastingColor(property, color)
                }

                ColorBrightnessAutoAdjustPossibleArray(property, color) {
                    if color is Array {
                        color := color[1]
                    }
                    ColorBrightnessAutoAdjust(property, color)
                }

                ColorBrightnessAutoAdjust(property, color) {
                    this.%property% := this.__ColorBrightnessAutoAdjust(color) | 0x01000000
                }

                GetContrastingColor(property, color) {
                    this.%property% := this.__GetContrastingColor(color)
                }
            }
        }

        TextOptionsSetup() {
            this._bannerTextOptions := 'x' this.marginX ' y5 s28 Bold c' this.bannerTitleColor
            ; this._windowOptions := 's18 Bold x' titleX
            ; this._titleOptions := 's16 x' titleX
        }

        VariousPropertiesSetup() {
            ; this._allWindows := this.__AltTabWindows()
            ; this.Menu.windows := this._allWindows.Clone()

            this._showInfoPanel := this.showPanelOnOpen
            this._searchText := this.placeholderSearchText
            ; this._partitionX := this.menuWidth * 0.8
            this._rowNumberWidth := this.rowNumbers ? 30 : 0
            this._titleX := (this.iconSize + (2 * this.marginX)) + (this._rowNumberWidth)
            this._rowWithDivider := this.rowHeight + this.rowDividerHeight
            this.__RefreshWindows()
            this.__UpdateTotalHeight()
            this._lastWindowListHeight := this._lastWindowHeight := this._lockedHeight := this._menuHeight

            minWidthMultiplier := 0.2   ; window list and panel can't be less than 20% of the menu width
            minWidthInPixels := this.menuWidth * minWidthMultiplier
            this._listMinWidth := minWidthInPixels
            this._infoPanelMinWidth := minWidthInPixels

            upperBounds := Max(this.menuWidth * (1 - this.defaultPanelSizePercent))
            this._partitionX := Min(upperBounds, this.menuWidth - minWidthInPixels)
        }

        SearchBarDimensions() {
            height := 34
            x1 := this.marginX
            y1 := this.bannerHeight - this.marginY - height

            this._searchBarRect := {
                x1: x1,
                y1: y1,
                x2: x1 + this.menuWidth - (2 * height + (this.marginX * 2)),
                y2: y1 + height,
                h: height,
                r: 8
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
                    size: panelIconBackgroundSize
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

        this.DeleteProp('Call')
    }


    /**
     * @Private_Methods
     */


    static __FirstDraw() {
        static _ := () {
            this.HasOwnProp('Call') && this()
            ; if this.preventResize {
            ;     this.__UpdateTotalHeight()
            ;     this._lockedHeight := this._menuHeight
            ; }
        }()

        ; this._lastBitmapHeight :=
        ; this._lockedHeight := this._menuHeight
        ; this.__UpdateTotalHeight()  ; Call this FIRST to get the correct height

        ; this._lastBitmapHeight := this._menuHeight
        ; this._lockedHeight := this._menuHeight

        ; this._lastWindowListWidth := this._partitionX

        this.__UpdateTotalHeight()      ; necessary for certain this._selectedRow starting values when this.__ScrollToSelectedRow() is called
        this.__KeepSelectedRowVisible()
        this.__DrawMenu()

        switch this.coordinates {
        case 'Center', 'Recenter':
            MonitorGetWorkArea(this.monitor, &left, &top, &right, &bottom)
            this._x := left + (right - left - this.menuWidth) / 2
            this._y := top + (bottom - top - this._menuHeight) / 2
        case 'Mouse':
            MouseGetPos(&this._x, &this._y)
        default:
            this._x := this.coordinates.x
            this._y := this.coordinates.y
        }
    }

    static __OpenMenu(options, sortedWindows := false) {
        ; start := GetSystemTime()
        this.open := true
        this._sortedWindows := sortedWindows
        OnMessage(0x200, this._OnMouseMove)
        OnMessage(0x20A, this._OnMouseWheel)
        OnMessage(0x2A3, this._OnMouseLeave)
        OnMessage(0x201, this._OnLeftClick)
        OnMessage(0x202, this._OnLeftClickRelease)
        OnMessage(0x203, this._OnRightClick)
        OnMessage(0x204, this._OnRightClickRelease)
        OnMessage(0x207, this._OnMiddleClick)
        OnMessage(0x208, this._OnMiddleClickRelease)

        startingIndex := options.index ?? 1

        this.__RefreshWindows(options)
        this._selectedRow := Min(Max(1, startingIndex), this.Menu.windows.Length)

        this.__FirstDraw()
        this.Menu.Show('w' this.menuWidth ' h' this._menuHeight)
        this._ih.Start()
        ; this._onMenuOpen(this.Menu)
        ; ToolTip(GetSystemTime() - start)
    }

    static __CloseWindow(selectedRow := this._selectedRow) {
        if !this.Menu.windows.Has(selectedRow) {
            this.__RefreshWindows()
            this.__ApplySearchFilter()
            this.__WindowListRefreshUI()
            return
        }

        window := this.Menu.windows[selectedRow]
        this._ih.Stop()

        WinClose(window.hwnd)
        if !WinWaitClose(window.hwnd,, 3) {
            return
        }

        this._ih.Start()

        ; helps when window list shifts when window is closed and the bottom of a scrollable list is visible
        switch this.Menu.windows.Length {
        case 1 + this.maxVisibleRows:
            this._scrollOffset := 0
            this._targetScrollOffset := 0
        case 1:
            this._searchText := this.placeholderSearchText
        default:
            rowHeight := this.rowHeight + this.rowDividerHeight
            this._scrollOffset := Max(0, this._scrollOffset - rowHeight)
        }

        this.__RefreshWindows()
        this.__ApplySearchFilter()
        this.__WindowListRefreshUI('override')
    }

    static __UpdateTotalHeight() {
        totalRows := this.Menu.windows.Length

        if totalRows > this.maxVisibleRows {
            ; show partial row to indicate scrollability
            visibleRows := this.maxVisibleRows - 0.5
            totalDividers := Floor(visibleRows)
            contentHeight := Round(visibleRows * this.rowHeight + (totalDividers * this.rowDividerHeight))
        } else {
            totalDividers := Max(0, totalRows - 1)
            contentHeight := (totalRows * this.rowHeight) + (totalDividers * this.rowDividerHeight)
        }

        totalHeight := this.bannerHeight + contentHeight
        return this._menuHeight := totalHeight
    }

    /**
     * @param {String/Func} Updates 'All' or a function that calls the appropriate update methods
     */
    static __DrawMenu(Updates := 'All') {
        if this._isDrawing {
            return
        }

        this._isDrawing := true
        this._ih.Stop()
        if Updates = 'All' {
            this.__UpdateSearchBar()
            this.__UpdatePanelIcon()
            this.__UpdateWindowList()
            this.__UpdatePanel()
        } else {
            Updates()
        }

        this.__UpdateWindow()
        this._isDrawing := false
        this._ih.Start()
    }

    static __DrawBanner(width, height) {
        Banner := this._sections['Banner'].graphics
        Gdip_GraphicsClear(Banner, this.bannerColor | 0x01000000)

        ; banner title centered at top
        Gdip_TextToGraphics(Banner, this.bannerTitle, this._bannerTextOptions, 'Arial', width, 35)
    }

    static __UpdatePanelIcon() {
        PanelIcon := this._sections['PanelIcon'].graphics
        Gdip_GraphicsClear(PanelIcon, this.bannerColor)

        ; draw panelIcon background
        if this._clicked.item = 'panelIcon' {    ; highlight panel icon
            pBrush := Gdip_BrushCreateSolid(this.__ColorBrightnessAutoAdjust(this.panelIconBackgroundColor))
        } else {    ; normal draw
            pBrush := Gdip_BrushCreateSolid(this.panelIconBackgroundColor)
        }

        previousSmoothingMode := Gdip_SetSmoothingMode(PanelIcon, 4)

        panelIconR := 6     ; radius
        background := this._panelIcon.bg
        Gdip_FillRoundedRectangle(PanelIcon, pBrush, 0, 0, background.size, background.size, panelIconR)
        Gdip_DeleteBrush(pBrush)

        line := this._panelIcon.line
        panelIconY := line.y

        ; draw panelIcon lines
        pBrush := Gdip_BrushCreateSolid(this.panelIconLinesColor)
        loop 3 {
            Gdip_FillRoundedRectangle(PanelIcon, pBrush, line.x, panelIconY, line.w, line.h, 2)
            panelIconY += line.spacing * 2 ; this correctly advances Y by (line height + space height)
        }
        Gdip_DeleteBrush(pBrush)
        Gdip_SetSmoothingMode(PanelIcon, previousSmoothingMode)
    }

    static __UpdateSearchBar() {
        SearchBar := this._sections['SearchBar'].graphics
        Gdip_GraphicsClear(SearchBar, this.bannerColor)
        previousSmoothingMode := Gdip_SetSmoothingMode(SearchBar, 4)

        searchBarRect := this._searchBarRect

        ; search bar background
        if this.searchBackgroundColor != this.searchTextColor {
            pBrush := Gdip_BrushCreateSolid(this.searchBackgroundColor)
            Gdip_FillRoundedRectangle(SearchBar, pBrush, 0, 0, searchBarRect.x2, searchBarRect.h, searchBarRect.r)
            Gdip_DeleteBrush(pBrush)
        }

        ; search bar text
        displayText := SubStr(this._searchText . Chr(0x200B), 1, 60)

        searchBarOptions := 'x10 y10 s16 '
        searchBarOptions .= (this._searchText = this.placeholderSearchText)
            ? 'Italic c' this.placeholderTextColor  ; placeholder text
            : 'Bold c' this.searchTextColor         ; user-input text

        Gdip_TextToGraphics(searchBar, displayText, searchBarOptions, 'Arial', this._searchBarRect.x2 - (this.marginX * 2) - 55, searchBarRect.h)
        Gdip_SetSmoothingMode(SearchBar, previousSmoothingMode)
    }

    static __UpdateWindowList() {
        width := this._showInfoPanel ? this._partitionX : this.menuWidth
        height := !this.preventResize ? this.__UpdateTotalHeight() : this._lockedHeight

        if width != this._lastWindowListWidth || height != this._lastWindowListHeight {
            this._lastWindowListWidth := width
            this._lastWindowListHeight := height
            this.__DestroyGDIPSection('WindowList')
            this.__CreateGDIPSection('WindowList', width, height)
        }

        WindowList := this._sections['WindowList'].graphics
        Gdip_GraphicsClear(WindowList)

        Gdip_SetInterpolationMode(WindowList, 7)

        ; background
        pBrush := Gdip_BrushCreateSolid(this.rowBackgroundColor)
        Gdip_FillRectangle(WindowList, pBrush, 0, 0, width, height)
        Gdip_DeleteBrush(pBrush)

        ; pre-loop variable initalization
        maxTextWidth := width - this.iconSize - 15 - 40

        closeButtonSize := this.closeButtonSize
        closeButtonX := width - this.marginX - closeButtonSize - 10
        closeButtonY := (this.rowHeight - closeButtonSize) / 2
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

        if this.fullLengthDividers {
            dividerX := 0
            dividerWidth := width
        } else {
            dividerX := this.marginX
            dividerWidth := width - (this.marginX * 2)
        }

        this._windowRects := []
        this._closeButtonRects := []

        rowX := this.rowNumbers ? 30 : 0

        for index, window in this.Menu.windows {
            rowY := this.bannerHeight + ((index - 1) * this._rowWithDivider) - this._scrollOffset

            if rowY + this.rowHeight < this.bannerHeight || rowY > height {
                continue
            }

            y1 := Max(rowY, this.bannerHeight)

            this._windowRects.Push({
                x1: 0,
                y1: Max(rowY, this.bannerHeight),
                x2: width,
                y2: y1 + this.rowHeight,
                window: window,
                actualIndex: index
            })

            DrawHighlightedRow(index)
            DrawIcon(window)
            DrawWindowText(index, window)
            DrawCloseButton(index)
            DrawDivider(index)
        }

        Gdip_SetInterpolationMode(WindowList, 2)

        /**
         * supporting functions
         */

        DrawIcon(window) {
            iconX := this.marginX + this._rowNumberWidth
            iconY := rowY + (this.rowHeight - this.iconSize) / 2
            this.__DrawIcon(window, iconX, iconY)
        }

        DrawWindowText(index, window) {
            sameRow := this._hoveredOver = this._selectedRow
            if sameRow {
                mouse := this._lastUsedDevice = 'mouse'
                if mouse && this._hoveredOver = index {
                    textColor := this._clicked.item = 'row'
                        ? this.mouseRowSelectedTextColor
                        : this.mouseRowHoverTextColor
                } else if this._selectedRow = index {
                    textColor := this.rowSelectedTextColor
                } else {
                    textColor := this.rowTextColor
                }
            } else if this._hoveredOver = index {
                textColor := this._clicked.item = 'row'
                    ? this.mouseRowSelectedTextColor
                    : this.mouseRowHoverTextColor
            } else if this._selectedRow = index {
                textColor := this.rowSelectedTextColor
            } else {
                textColor := this.rowTextColor
            }

            if this.rowNumbers && index <= 10 {
                x := 'x' this.marginX
                y := 'y' rowY + (this.rowHeight - 24) / 2

                Gdip_TextToGraphics(WindowList, SubStr(index, -1), x . ' ' y . ' Bold s24 c' textColor, 'Arial', 20, 20)
            }

            ; truncate text before rendering instead of letting Gdip scale it
            truncatedName := this.__TruncateTextToWidth(window.name, 18, maxTextWidth)
            truncatedTitle := this.__TruncateTextToWidth(window.title, 16, maxTextWidth)

            windowOptions := 'x' this._titleX ' y' (rowY +  8) ' s18 Bold c' textColor
            titleOptions  := 'x' this._titleX ' y' (rowY + 28) ' s16 c' textColor

            ; pass a very large width to prevent scaling, since we've already truncated
            Gdip_TextToGraphics(WindowList, truncatedName, windowOptions, 'Arial', 5000, 20)
            Gdip_TextToGraphics(WindowList, truncatedTitle, titleOptions, 'Arial', 5000, 20)
        }

        DrawHighlightedRow(index) {
            switch this._clicked.item {
            case 'row', 'close':
                clickedIndex := this._clicked.index
            default:
                clickedIndex := 0
            }

            if clickedIndex = index {
                HighlightRow(this.mouseRowSelectedBackgroundColor)
                return
            }

            sameRow := this._hoveredOver = this._selectedRow
            if sameRow {
                mouse := this._lastUsedDevice = 'mouse'
                if mouse && this._hoveredOver = index {
                    HighlightRow(this.mouseRowHoverBackgroundColor)
                } else if this._selectedRow = index {
                    HighlightRow(this.rowSelectedColor)
                }
                return
            }

            if this._hoveredOver = index {
                HighlightRow(this.mouseRowHoverBackgroundColor)
            } else if this._selectedRow = index {
                HighlightRow(this.rowSelectedColor)
            }

            HighlightRow(color) {
                ; create a gradient.
                if !(color is Array) {
                    pBrushHover := Gdip_BrushCreateSolid(color)
                    Gdip_FillRectangle(WindowList, pBrushHover, 0, rowY, width, this.rowHeight)
                    Gdip_DeleteBrush(pBrushHover)
                    return
                }

                previousSmoothingMode := Gdip_SetSmoothingMode(WindowList, 0)
                colors := color
                colorCount := colors.Length
                colorHeight := (this.rowHeight / colorCount)

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
                    gradientSize := this.rowHeight / (colorCount - 1)

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
            if this._hoveredOver = index || this.showAllCloseButtons {
                closeButtonY += rowY

                this._closeButtonRects.Push({
                    x1: closeButtonX,
                    y1: closeButtonY,
                    x2: closeButtonX + closeButtonSize,
                    y2: closeButtonY + closeButtonSize,
                    actualIndex: index,
                })

                ; close background color - highlighted or not
                isHoveringCloseButton := (this._hoveredCloseButton = index)
                if isHoveringCloseButton {
                    pBrushClose := Gdip_BrushCreateSolid(this.closeHoverBackgroundColor)
                    pPen := Gdip_CreatePen(this.closeXHoverColor, 2)
                } else {
                    pBrushClose := Gdip_BrushCreateSolid(this.closeBackgroundColor)
                    pPen := Gdip_CreatePen(this.closeXColor, 2)
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
            if index < this.Menu.windows.Length {
                dividerY := rowY + this.rowHeight
                if dividerY > this.bannerHeight && dividerY < height {
                    pBrushDiv := Gdip_BrushCreateSolid(this.rowDividerColor)
                    Gdip_FillRectangle(WindowList, pBrushDiv, dividerX, dividerY, dividerWidth, this.rowDividerHeight)
                    Gdip_DeleteBrush(pBrushDiv)
                }
            }
        }
    }

    static __UpdatePanel() {
        if !this._showInfoPanel {
            this.__CleanupThumbnail()
            return
        }

        width := this.menuWidth - this._partitionX
        height := this._menuHeight - this.bannerHeight

        if this._lastWindowListWidth != this._partitionX || height != this._lastWindowListHeight {
            this.__DestroyGDIPSection('Panel')
            this.__CreateGDIPSection('Panel', width, height)
        }

        Panel := this._sections['Panel'].graphics
        Gdip_GraphicsClear(Panel, 0x01000000)

        ; draw panel background
        pBrushPanel := Gdip_BrushCreateSolid(this.panelBackgroundColor)
        Gdip_FillRectangle(Panel, pBrushPanel, 0, 0, width, height)
        Gdip_DeleteBrush(pBrushPanel)

        ; partition
        partitionWidth := this.partitionWidth
        if this.fullLengthPartition {
            partitionY := 0
            partitionHeight := height
        } else {
            partitionY := this.marginY
            partitionHeight := height - (this.marginY * 2)
        }

        pBrushPartition := Gdip_BrushCreateSolid(this.partitionColor)
        Gdip_FillRectangle(Panel, pBrushPartition, 0, partitionY, partitionWidth, partitionHeight)
        Gdip_FillRectangle(Panel, pBrushPartition, 0, 0, width, partitionWidth)
        Gdip_DeleteBrush(pBrushPartition)

        this.__DrawPanelTabs(Panel)

        ; draw tab content
        tabHeight := 40
        useMousedRow := this.mouseRowHoverUpdatesPanel && this._lastUsedDevice = 'mouse' && this._hoveredOver
        row := useMousedRow ? this._hoveredOver : this._selectedRow

        if row > 0 && row <= this.Menu.windows.Length {
            window := this.Menu.windows[row]

            if this._panelTab = 'preview' {
                this.__UpdatePanelPreview(window, 0, tabHeight, width, height - tabHeight)
            } else {
                this.__UpdatePanelInfo(window, 0, tabHeight, width, height - tabHeight)
            }
        }
    }

    static __DrawPanelTabs(Panel := this._sections['Panel'].graphics) {
        static tabs := ['Preview', 'Info']
        this._panelTabRects := []

        width := this.menuWidth - this._partitionX
        tabHeight := 40

        spacing := this.marginX
        partitionSize := this.partitionWidth / 2
        y := this.marginY + (partitionSize * 2)

        ; available space for tabs (minus partition and margins)
        availableWidth := width - partitionSize - (spacing * 3)     ; left margin, between, right margin
        tabWidth := availableWidth / tabs.Length

        oldMode := Gdip_SetSmoothingMode(Panel, 4)
        for index, tabName in tabs {
            offset := index = 1 ? partitionSize : 0
            x := offset + spacing + ((index - 1) * (tabWidth + spacing))

            colorAdjustment := GetColorAdjustmentValue(index, tabName)
            bgColor := this.__ColorBrightnessAutoAdjust(this.panelBackgroundColor, colorAdjustment)
            pBrush := Gdip_BrushCreateSolid(bgColor)
            Gdip_FillRoundedRectangle(Panel, pBrush, x, y, tabWidth, tabHeight - this.marginY, 6)
            Gdip_DeleteBrush(pBrush)

            textColor := this.rowTextColor
            options := 'x' x ' y' (y + 6) ' s14 Bold c' textColor ' Center'
            Gdip_TextToGraphics(Panel, tabName, options, 'Arial', tabWidth, tabHeight - (y * 2))

            this._panelTabRects.Push({
                x1:  x,
                y1:  y,
                x2:  x + tabWidth,
                y2:  y + (tabHeight - this.marginY),
                tab: tabName
            })
        }

        Gdip_SetSmoothingMode(Panel, oldMode)

        GetColorAdjustmentValue(index, tabName) {
            if this._clicked.item = tabName {                                       ; tab is clicked
                return 120
            } else if this._hoveredPanelTab = (index = 1 ? 'preview' : 'info') {    ; tab is hovered
                return 100
            } else if this._panelTab = (index = 1 ? 'preview' : 'info') {           ; tab is active
                return 80
            } else {
                return 60
            }
        }
    }

    static __OnMouseMove(wParam, lParam, msg, hwnd) {
        static tme := TrackMouseLeave(hwnd)

        if this._mouseLeft {
            this._mouseLeft := false
            DllCall('user32.dll\TrackMouseEvent', 'Ptr', tme)
        }

        x := lParam & 0xFFFF
        y := lParam >> 16

        if this._clicked.item = 'partition' {
            this.__OnPartitionMove(x)
            DllCall('SetCursor', 'Ptr', DllCall('LoadCursor', 'Ptr', 0, 'Ptr', 32646))
            return
        } else if this.__IsOnPartition(x, y) {
            DllCall('SetCursor', 'Ptr', DllCall('LoadCursor', 'Ptr', 0, 'Ptr', 32646))
            return
        }

        if this._clicked.item {
            return
        }

        this._canScroll := (y > this.bannerHeight) && x < (this._showInfoPanel ? this._partitionX : this.menuWidth)
        if (y > this.bannerHeight) && x < (this._showInfoPanel ? this._partitionX : this.menuWidth) {
            this._hoveredPanelTab := ''
            this._canScroll := true

            if this.__MouseOverRowOrCloseButton(x, y) {
                this._lastUsedDevice := 'mouse'
                this.__DrawMenu(() {
                    this.__UpdateWindowList()
                    if this.mouseRowHoverUpdatesPanel {
                        this.__UpdatePanel
                    }
                })
            }
            return
        }

        this._canScroll := false
        this._hoveredCloseButton := 0
        if this._hoveredOver {
            this._hoveredOver := 0
            this.__DrawMenu(() {
                this.__UpdateWindowList()
            })
        }

        oldHoveredTab := this._hoveredPanelTab

        if this._showInfoPanel && x >= this._partitionX {
            panelRelativeX := x - this._partitionX
            panelRelativeY := y - this.bannerHeight

            for rect in this._panelTabRects {
                if panelRelativeX >= rect.x1 && panelRelativeX <= rect.x2
                    && panelRelativeY >= rect.y1 && panelRelativeY <= rect.y2 {
                    this._hoveredPanelTab := rect.tab
                    hoveredTab := true
                    break
                }
            }
        }

        if !IsSet(hoveredTab) {
            this._hoveredPanelTab := ''
            this.__DrawMenu(() => this.__DrawPanelTabs())
        } else if oldHoveredTab != this._hoveredPanelTab {
            this.__DrawMenu(() => this.__DrawPanelTabs())
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
        if !WinExist(window.hwnd) {
            Panel := this._sections['Panel'].graphics
            x := panelX + this.marginX
            y := startY + this.marginY
            Gdip_TextToGraphics(Panel, "Window closed", 'x' x ' y' y ' s16 cFFC0C0C0', 'Arial', panelWidth - (this.marginX * 2), 30)
            this.__RefreshWindows()
            this.__ApplySearchFilter()
            this.__WindowListRefreshUI()
            return
        }

        ; if window is minimized, the live preview is shortened but enlarged version of the toolbar which is not what we want
        if WinGetMinMax(window.hwnd) = -1 {
            Panel := this._sections['Panel'].graphics
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

        WinGetPos(,, &winW, &winH, 'ahk_id ' window.hwnd)   ; get window dimensions for preview

        margin := this.marginX
        maxWidth := panelWidth - (margin * 2)
        maxHeight := panelHeight - (margin * 2)

        sourceAspect := winW / winH

        destWidth := Min(maxWidth, Round(maxHeight * sourceAspect))
        destHeight := Min(maxHeight, Round(destWidth / sourceAspect))

        destX := this._partitionX + margin + (maxWidth - destWidth) / 2
        destY := this.bannerHeight + startY + margin + (maxHeight - destHeight) / 2

        props := Buffer(48, 0)
        NumPut('UInt', 0x1F, props, 0)
        NumPut('Int', destX, props, 4)
        NumPut('Int', destY, props, 8)
        NumPut('Int', destX + destWidth, props, 12)
        NumPut('Int', destY + destHeight, props, 16)
        NumPut('Int', 0, props, 20)
        NumPut('Int', 0, props, 24)
        NumPut('Int', winW, props, 28)
        NumPut('Int', winH, props, 32)
        NumPut('UChar', 255, props, 36)
        NumPut('Int', 1, props, 40)
        NumPut('Int', 1, props, 44)

        try {
            DllCall('dwmapi\DwmUpdateThumbnailProperties', 'Ptr', this._thumbnail, 'Ptr', props)
        } catch {
            MsgBox('DLL update thumbnail properties failed')
        }
    }


    static __UpdatePanelInfo(window, panelX, startY, panelWidth, panelHeight) {
        if !WinExist(window.hwnd) {
            Panel := this._sections['Panel'].graphics
            x := panelX + this.marginX
            y := startY + this.marginY
            Gdip_TextToGraphics(Panel, "Window closed", 'x' x ' y' y ' s16 cFFC0C0C0', 'Arial', panelWidth - (this.marginX * 2), 30)
            this.__RefreshWindows()
            this.__ApplySearchFilter()
            this.__WindowListRefreshUI()
            return
        }

        Panel := this._sections['Panel'].graphics
        margin := this.marginX
        x := panelX + margin
        y := startY + margin

        lineHeight := 20
        fontSize := 16
        maxWidth := panelWidth - (margin * 2)

        headerOptions := Format('x{} s{} Bold c{}', x, fontSize, this.panelHeaderTextColor)
        descriptionOptions := Format('x{} s{} c{}', (x + 10), fontSize, this.panelBodyTextColor)

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

    static __UpdateWindow() {
        width := this.menuWidth
        height := this._menuHeight

        if height != this._lastWindowHeight {
            this.__DestroyGDIPSection('Window')
            this.__CreateGDIPSection('Window', width, height)
            this._lastWindowHeight := height
        }

        Window := this._sections['Window']
        Gdip_GraphicsClear(Window.graphics, 0x01000000)

        listWidth := this._showInfoPanel ? this._partitionX : width
        panelIcon := this._panelIcon.bg
        searchBar := this._searchBarRect
        sections  := this._sections

        BitBlt(Window.hdc, 0, 0, listWidth, height, sections['WindowList'].hdc, 0, 0)
        BitBlt(Window.hdc, 0, 0, width, this.bannerHeight, sections['Banner'].hdc, 0, 0)
        BitBlt(Window.hdc, panelIcon.x1, panelIcon.y1, panelIcon.size, panelIcon.size, sections['PanelIcon'].hdc, 0, 0)
        BitBlt(Window.hdc, searchBar.x1, searchBar.y1, searchBar.x2, searchBar.h, sections['SearchBar'].hdc, 0, 0)

        if this._showInfoPanel {
            panelWidth := width - this._partitionX
            panelHeight := height - this.bannerHeight
            BitBlt(Window.hdc, this._partitionX, this.bannerHeight, panelWidth, panelHeight, sections['Panel'].hdc, 0, 0)
        }

        if this.coordinates = 'Recenter' {
            MonitorGetWorkArea(this.monitor, &left, &top, &right, &bottom)
            this._y := top + (bottom - top - height) / 2
        }

        UpdateLayeredWindow(this.Menu.Hwnd, Window.hdc, this._x, this._y, width, height)
    }

    static __InitBanner() {
        width := this.menuWidth
        height := this.bannerHeight
        this.__CreateGDIPSection('Banner', width, height)
        this.__DrawBanner(width, height)
    }

    static __InitSearchBar() {
        height := this._searchBarRect.h
        width := this._searchBarRect.x2
        this.__CreateGDIPSection('SearchBar', width, height)
    }

    static __InitPanelIcon() {
        size := this._searchBarRect.h
        this.__CreateGDIPSection('PanelIcon', size, size)
    }

    static __InitWindowList() {
        width  := this._showInfoPanel ? this._partitionX : this.menuWidth
        height := !this.preventResize ? this.__UpdateTotalHeight() : this._lockedHeight
        this.__CreateGDIPSection('WindowList', width, height)
    }

    static __InitPanel() {
        this.__CreateGDIPSection('Panel', this._partitionX, this._menuHeight - this.bannerHeight)
    }

    static __InitWindow() {
        this.__CreateGDIPSection('Window', this.menuWidth, this._menuHeight)
    }

    ; parameter only exists for the reason of closing a window, so the nᵗʰ selected window is still selected
    static __WindowListRefreshUI(overrideSelectedRow := false) {
        totalRows := this.Menu.windows.Length

        ; reset scroll if list was empty and now has results
        if this._lastWindowCount = 0 && totalRows > 0 {
            this._scrollOffset := 0
            this._targetScrollOffset := 0
        }

        this._lastWindowCount := totalRows

        if this.alwaysHighlightFirst && !overrideSelectedRow {
            this._selectedRow := 1
        } else {
            totalRows := this.Menu.windows.Length
            if this._selectedRow > totalRows {
                this._selectedRow := totalRows
            }
        }

        if this.preventResize {
            height := this._lockedHeight
        } else {
            height := this._menuHeight
            if height != this._lastWindowListHeight {
                this._lastWindowListHeight := height
            }
        }

        ; having this enabled hides the panel while typing. do I want this enabled?
        ; this._showInfoPanel := this._showInfoPanel && (this.preventResize || this._searchText = this.defaultSearchText)

        this.__DrawMenu(() {
            ; this.__UpdateTotalHeight()
            this.__UpdateSearchBar()
            this.__UpdateWindowList()
            this.__KeepSelectedRowVisible()
            this.__UpdatePanel()
        })
    }

    static __ApplySearchFilter() {
        if this._searchText = this.placeholderSearchText || StrLen(this._searchText) = 0 {
            this.Menu.windows := this._allWindows.Clone()
            return
        }

        this.Menu.windows := this.__PerformSearch()
    }

    static __PerformSearch() {
        matches := []
        for win in this._allWindows {
            if InStr(win.name, this._searchText) || InStr(win.title, this._searchText) {
                matches.Push(win)
            }
        }
        return matches
    }


    static __RefreshWindows(options := {}) {
        list := this.__AltTabWindows(options)
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
        this.Menu.windows := windows

        SortWindows() {
            i := 2
            while i <= windows.Length {
                temp := windows[i]
                j := i - 1
                while j >= 1 and StrCompare(windows[j].name, temp.name) > 0 {
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
            this.__RefreshWindows()
            this.__WindowListRefreshUI()
            return
        }

        cacheKey := path

        if !this._iconCache.Has(cacheKey) {
            GetIcon(window.hwnd)
        }

        iconData := this._iconCache[cacheKey]
        pBitmap := iconData.bitmap

        if pBitmap && Gdip_GetImageWidth(pBitmap) {
            WindowList := this._sections['WindowList'].graphics

            ; draw UWP icons slightly larger to compensate for smaller source images
            if iconData.isUWP {
                drawSize := this.iconSize * 1.25            ; 25% larger
                offset := (this.iconSize - drawSize) / 2    ; center it
                Gdip_DrawImage(WindowList, pBitmap, x + offset, y + offset, drawSize, drawSize)
            } else {
                Gdip_DrawImage(WindowList, pBitmap, x, y, this.iconSize, this.iconSize)
            }
        }

        ; get icon function
        GetIcon(hwnd) {
            uwpPath := ''
            if InStr(path, 'WindowsApps') || InStr(path, 'ApplicationFrameHost.exe') {
                try {
                    uwpPath := this.__GetLargestUWPLogoPath(hwnd)
                }
            }

            pBitmap := 0
            isUWP := false

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
                    DllCall('PrivateExtractIcons', 'Str', 'shell32.dll', 'Int', 0, 'Int', 48, 'Int', 48, 'Ptr*', &hIcon, 'Ptr*', 0, 'UInt', 1, 'UInt', 0)

                    if hIcon {
                        pBitmap := Gdip_CreateBitmapFromHICON(hIcon)
                        DllCall('DestroyIcon', 'Ptr', hIcon)
                    }
                }
            }

            this._iconCache[cacheKey] := {bitmap: pBitmap, isUWP: isUWP}
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
                NumPut 'UInt', ChildPID, lParam
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
            this.Menu.windows.Length * this._rowWithDivider - this.rowDividerHeight,
            this._menuHeight - this.bannerHeight)
        this._targetScrollOffset := Max(0, Min(this._targetScrollOffset, maxScrollPixels))

        ; start animation if not already running
        if !this._scrollTimerActive {
            this._scrollTimerActive := true
            SetTimer(this._scrollTimer, 3)
        }
    }

    static __OnLeftClick(wParam, lParam, msg, hwnd) {
        DllCall('SetCapture', 'Ptr', this.Menu.Hwnd)
        x := lParam & 0xFFFF
        y := lParam >> 16

        switch this._searchText {
        case '':
            ; this._searchText := this.placeholderSearchText
            ; this.__DrawMenu(() {
            ;     this.__UpdateSearchBar()
            ; })

        case this.placeholderSearchText:
            rect := this._searchBarRect
            if x >= rect.x1 && x <= rect.x2 && y >= rect.y1 && y <= rect.y2 {
                this._searchText := ''
                this.__DrawMenu(() {
                    this.__UpdateSearchBar()
                })
                return
            }
        }

        if this.__IsOnPartition(x, y) {
            this._clicked.item := 'partition'
            return
        }

        if this._hoveredPanelTab {
            this._clicked.item := this._hoveredPanelTab
            this.__DrawMenu(() => this.__DrawPanelTabs())
            ; this._clicked.index :=
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
            this.__DrawMenu(() {
                this.__UpdateWindowList()
            })
            return
        }

        rect := this._panelIcon.bg
        if x >= rect.x1 && x <= rect.x2 && y >= rect.y1 && y <= rect.y2 {
            this._clicked.item := 'panelIcon'
            this.__DrawMenu(() {
                this.__UpdatePanelIcon()
            })
            return
        }
    }

    static __OnLeftClickRelease(wParam, lParam, msg, hwnd) {
        LeftClickRelease()
        DllCall('ReleaseCapture')

        LeftClickRelease() {
            item := this._clicked.item
            ; this._panelTab := ''

            if !item {
                return
            }

            this._clicked.item := ''
            x := lParam & 0xFFFF
            y := lParam >> 16

            ; released outside the bounds
            ; if x < 0 || x > this.menuWidth || y < 0 || y > this._menuHeight {
            ;     return
            ; }

            index := this._clicked.index

            switch item, 'Off' {
            case 'partition':
                return

            case 'panelIcon':
                rect := this._panelIcon.bg
                if x >= rect.x1 && x <= rect.x2 && y >= rect.y1 && y <= rect.y2 {
                    this.TogglePanel()
                }

                this.__DrawMenu(() {
                    this.__UpdatePanelIcon()
                })
                return

            case 'close':
                for rect in this._closeButtonRects {
                    if rect.actualIndex = index {
                        if x >= rect.x1 && x <= rect.x2 && y >= rect.y1 && y <= rect.y2 {
                            this.__CloseWindow(index)
                            return
                        }
                        break
                    }
                }

            case 'row':
                for rect in this._windowRects {
                    if rect.actualIndex = index {
                        if x >= rect.x1 && x <= rect.x2 && y >= rect.y1 && y <= rect.y2 {
                            this.CloseMenu()
                            this.__ActivateWindow(rect.window)
                            return
                        }
                        break
                    }
                }

            case 'preview', 'info':
                if this._showInfoPanel && x >= this._partitionX {
                    panelRelativeX := x - this._partitionX
                    panelRelativeY := y - this.bannerHeight

                    for rect in this._panelTabRects {
                        if panelRelativeX >= rect.x1 && panelRelativeX <= rect.x2
                            && panelRelativeY >= rect.y1 && panelRelativeY <= rect.y2 {
                            this._panelTab := rect.tab
                            if item != 'preview' {
                                this.__CleanupThumbnail()
                            }
                            this.__DrawMenu(() {
                                this.__UpdatePanel()
                            })
                            return
                        }
                    }

                    if this._hoveredPanelTab {
                        this._hoveredPanelTab := ''
                        this.__DrawMenu(() {
                            this.__DrawPanelTabs()
                        })
                    }
                    return
                }

            default:
                return
            }

            if this.__MouseOverRowOrCloseButton(x, y) {
                this.__DrawMenu(() {
                    this.__UpdateWindowList()
                })
            }
        }
    }

    static __OnRightClick(wParam, lParam, msg, hwnd) {

    }

    static __OnRightClickRelease(wParam, lParam, msg, hwnd) {

    }

    static __OnMiddleClick(wParam, lParam, msg, hwnd) {
        if this._hoveredOver {
           this._clicked.item := 'row'
           this._clicked.index := this._hoveredOver
            this.__DrawMenu(() {
                this.__UpdateWindowList()
            })
        }
    }

    static __OnMiddleClickRelease(wParam, lParam, msg, hwnd) {
        if this._clicked.item = 'row' {
            x := lParam & 0xFFFF
            y := lParam >> 16
            index := this._clicked.index
            this._clicked.item := ''

            listWidth := this._showInfoPanel ? this._partitionX : this.menuWidth

            if x > listWidth || y < this.bannerHeight {
                return
            }

            for rect in this._windowRects {
                if rect.actualIndex = index {
                    if y >= rect.y1 && y <= rect.y2 {
                        this.__CloseWindow(index)
                        return
                    }
                    break
                }
            }

            if this.__MouseOverRowOrCloseButton(x, y) {
                this.__DrawMenu(() {
                    this.__UpdateWindowList()
                })
            }
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

            this.__DrawMenu(() {
                this.__UpdateWindowList()
            })
        }

        ; item := this._clicked.item
        ; if item {
        ;     ; this._clicked := {item: '', index: 0}

        ;     switch item {
        ;     case 'close', 'row':
        ;         CoordMode('Mouse', 'Window')
        ;         MouseGetPos(&x, &y)
        ;         if this.__MouseOverRowOrCloseButton(x, y) {
        ;             this.__DrawMenu(() {
        ;                 this.__UpdateWindowList()
        ;             })
        ;         }
        ;     case 'panelIcon':
        ;         this.__DrawMenu(() {
        ;             this.__UpdatePanelIcon()
        ;         })
        ;     }
        ; }
    }

    static __MouseOverRowOrCloseButton(x, y) {
        newHover := 0
        newHoveredCloseButton := 0

        listWidth := this._showInfoPanel ? this._partitionX : this.menuWidth

        if x > listWidth || y < this.bannerHeight {
            return
        }

        ; check if hovering over a close button
        for rect in this._closeButtonRects {
            if x >= rect.x1 && x <= rect.x2 && y >= rect.y1 && y <= rect.y2 {
                newHoveredCloseButton := rect.actualIndex
                ; if the mouse is over any close button, ensure the corresponding
                ; row is marked as hovered (used when not drawing every close button)
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

        if newHover != this._hoveredOver || newHoveredCloseButton != this._hoveredCloseButton {
            this._hoveredOver := newHover
            this._hoveredCloseButton := newHoveredCloseButton
            return true
        }
    }

    static __IsOnPartition(x, y) {
        if !this._showInfoPanel || y < this.bannerHeight {
            return
        }

        partitionGrabWidth := this.partitionWidth + 6    ; adds 3 pixels on each side to make it easier to grab
        partitionLeft := this._partitionX - partitionGrabWidth / 2
        partitionRight := partitionLeft + partitionGrabWidth

        if x >= partitionLeft && x <= partitionRight {
            return true
        }
    }

    static __OnPartitionMove(newSplitX) {
        if newSplitX < this._listMinWidth {
            newSplitX := this._listMinWidth
        }

        if this.menuWidth - newSplitX < this._infoPanelMinWidth {
            newSplitX := this.menuWidth - this._infoPanelMinWidth
        }

        if newSplitX != this._partitionX {
            this._partitionX := newSplitX
            this.__DrawMenu(() {
                this.__UpdateWindowList()
                this.__UpdatePanel()
            })
        }
    }

    static __OnKeyPress(ih, vk, sc) {
        key := GetKeyName(Format('vk{:x}sc{:x}', vk, sc))

        if !this.open {
            ToolTip('key: ' key)
            SetTimer(ToolTip, -1000)
            this._ih.Stop()
            return
        }

        switch key {
        case 'Escape':
            if this._clicked.item {
                this.__ResetClickedAndHoveredItems()
                if this.escapeAlwaysClose {
                    this.CloseMenu()
                }
                return
            }

            if this.escapeAlwaysClose || this._searchText = this.placeholderSearchText {
                this.CloseMenu()
                return
            }

            this._searchText := this.placeholderSearchText

        case 'Enter':
            this.ActivateWindowAndCloseMenu()
            return

        case 'Backspace':
            defaultText := this._searchText = this.placeholderSearchText
            if defaultText {
                return
            }

            inputLength := StrLen(this._searchText)

            if inputLength {
                if GetKeyState('Control') {
                    this._searchText := this.placeholderSearchText
                } else {
                    switch inputLength {
                    case 1:  this._searchText := this.placeholderSearchText
                    default: this._searchText := SubStr(this._searchText, 1, -1)
                    }
                }

                ; this.Menu.windows := this._allWindows.Clone()
                this.__ApplySearchFilter()
                this.__WindowListRefreshUI()
            }

            return

        case 'Home':
            this._lastUsedDevice := 'keyboard'
            this.SelectFirstRow()
            return

        case 'End':
            this._lastUsedDevice := 'keyboard'
            this.SelectLastRow()
            return

        case 'Up':
            this._lastUsedDevice := 'keyboard'
            this.SelectPreviousWindow()
            return

        case 'Down':
            this._lastUsedDevice := 'keyboard'
            this.SelectNextWindow()
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
                this.__DrawMenu(() => this.__UpdatePanelIcon())
                this.TogglePanel()
                Sleep(100)
                this._clicked.item := temp
                this.__DrawMenu(() => this.__UpdatePanelIcon())
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

        ; if this._searchText = this.placeholderSearchText {
        ;     ; do nothing
        ; } else if StrLen(this._searchText) = 0 {
        ;     this._searchText := this.placeholderSearchText
        ; } else {
        ;     matches := this.__PerformSearch()
        ; }

        ; this.Menu.windows := matches
        this.__ApplySearchFilter()
        this.__WindowListRefreshUI()

        __GetCharFromVK(vk, sc) {
            ; get keyboard state
            keyState := Buffer(256, 0)
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
        if this._searchText = this.placeholderSearchText {
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
            this._scrollOffset += diff * this.scrollSmoothness
        }

        ; visibleHeight := this._menuHeight - this.bannerHeight
        ; totalContentHeight := this.Menu.windows.Length * (this.rowHeight + this.rowDividerHeight)
        ; if totalContentHeight <= visibleHeight {
        ;     this._scrollOffset := 0
        ; }

        this.__DrawMenu(() {
            this.__UpdateHoverFromMouse()
            this.__UpdateWindowList()
        })
    }

    static __UpdateHoverFromMouse() {
        MouseGetPos(&mouseX, &mouseY)

        ; convert screen to client coordinates
        pt := Buffer(8)
        NumPut('Int', mouseX, pt, 0)
        NumPut('Int', mouseY, pt, 4)
        DllCall('ScreenToClient', 'Ptr', this.Menu.Hwnd, 'Ptr', pt)

        x := NumGet(pt, 0, 'Int')
        y := NumGet(pt, 4, 'Int')

        listWidth := this._showInfoPanel ? this._partitionX : this.menuWidth

        if x > listWidth || y < this.bannerHeight {
            return
        }

        ; check which row the mouse is over
        newHover := 0
        for rect in this._windowRects {
            if y >= rect.y1 && y <= rect.y2 {
                newHover := rect.actualIndex
                break
            }
        }

        if newHover != this._hoveredOver {
            this._hoveredOver := newHover
        }
    }

    static __Scroll(amount) {
        totalContentHeight := this.Menu.windows.Length * this._rowWithDivider
        visibleHeight := this._menuHeight - this.bannerHeight
        maxScrollPixels := Max(0, totalContentHeight - visibleHeight)

        this._scrollOffset := Max(0, Min(this._scrollOffset + amount, maxScrollPixels))
        this.__DrawMenu(() {
            this.__UpdateWindowList()
        })
    }

    static __ActivateWindow(window) {
        try {
            WinActivate(window.hwnd)
            return true
        } catch {
            this.__RefreshWindows()
            this.__ApplySearchFilter()
            this.__WindowListRefreshUI()
            return false
        }
    }

    static __KeepSelectedRowVisible() {
        visibleHeight := this._menuHeight - this.bannerHeight

        ; scroll if selected row is above visible area
        selectedRowTop := (this._selectedRow - 1) * this._rowWithDivider
        if selectedRowTop < this._scrollOffset {
            this._scrollOffset := ClampOffset(selectedRowTop)
            return
        }

        ; scroll if selected row is below visible area
        selectedRowBottom := selectedRowTop + this.rowHeight
        if selectedRowBottom > this._scrollOffset + visibleHeight {
            this._scrollOffset := ClampOffset(selectedRowBottom - visibleHeight)
        }

        ClampOffset(offset) {
            maxScrollPixels := this.__GetMaxScrollPixels(
                this.Menu.windows.Length * this._rowWithDivider,
                visibleHeight)
            return Min(offset, maxScrollPixels)
        }
    }

    static __GetMaxScrollPixels(totalContentHeight, visibleHeight) {
        return Max(0, totalContentHeight - visibleHeight)
    }

    static __ColorBrightnessAutoAdjust(color, offset := 60) {
        r := (color >> 16) & 0xFF
        g := (color >> 8) & 0xFF
        b := color & 0xFF

        brightness := this.__GetColorLuminance(color)

        if (brightness > 170) {     ; if color is already bright, use a dark highlight
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
        NumPut('Float', 0, RectF, 0)
        NumPut('Float', 0, RectF, 4)
        NumPut('Float', maxPixelWidth + 100, RectF, 8)
        NumPut('Float', fontSize + 20, RectF, 12)

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
    static __AltTabWindows(options) {
        static  WS_EX_TOOLWINDOW := 0x80,
                GW_OWNER         := 4,
                GA_ROOTOWNER     := 3,
                ImmersiveShell,
                IApplicationViewCollection

        OSbuildNumber := StrSplit(A_OSVersion, '.')[3]
        if OSbuildNumber <= 17134 {   ; Windows 10 1607 to 1803 and Windows Server 2016
            IID_IApplicationViewCollection := '{2C08ADF0-A386-4B35-9250-0FE183476FCC}'
        } else {
            IID_IApplicationViewCollection := '{1841C6D7-4F9D-42C0-AF41-8747538F10E5}'
        }

        ImmersiveShell := ComObject(CLSID_ImmersiveShell := '{C2F03A33-21F5-47FA-B4BB-156362A2F239}', IID_IUnknown := '{00000000-0000-0000-C000-000000000046}')
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

                if !DllCall('IsWindowVisible', 'Ptr', hwnd) {
                    continue
                }

                if (ex & WS_EX_TOOLWINDOW) {
                    continue
                }

                if !IsWindowOnCurrentVirtualDesktop(hwnd) {
                    continue
                }

                if !ShouldShowWindowInAltTab(hwnd) {
                    continue
                }

                if WindowFilter(hwnd) {
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

    static __CleanupThumbnail() {
        if this._thumbnail {
            DllCall('dwmapi\DwmUnregisterThumbnail', 'Ptr', this._thumbnail)
            this._thumbnail := 0
        }
        this._lastPreviewHwnd := 0
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

    static __GDIP_Cleanup() {
        for section in this._sections {
            this.__DestroyGDIPSection(section)
        }

        if this._iconCache.Count > 50 {
            this.__CleanupIcons()
        }
    }

    static __Cleanup() {
        this.__GDIP_Cleanup()
        this.__CleanupIcons()
    }

    static __CleanupIcons() {
        ; cleanup cached icons - extract bitmap from object
        for key, iconData in this._iconCache {
            if iconData && IsObject(iconData) && iconData.HasProp('bitmap') && iconData.bitmap {
                Gdip_DisposeImage(iconData.bitmap)
            } else if iconData && !IsObject(iconData) {
                ; handle old cached items that are just pointers
                Gdip_DisposeImage(iconData)
            }
        }
    }

    static __New() {
        this.Menu := Gui('+AlwaysOnTop +ToolWindow -SysMenu -Caption +E0x80000')
        this.__FrameShadow(this.Menu.hwnd)

        this._OnMouseMove           := ObjBindMethod(this, '__OnMouseMove')
        this._OnMouseWheel          := ObjBindMethod(this, '__OnMouseWheel')
        this._OnMouseLeave          := ObjBindMethod(this, '__OnMouseLeave')
        this._OnLeftClick           := ObjBindMethod(this, '__OnLeftClick')
        this._OnLeftClickRelease    := ObjBindMethod(this, '__OnLeftClickRelease')
        this._OnRightClick          := ObjBindMethod(this, '__OnRightClick')
        this._OnRightClickRelease   := ObjBindMethod(this, '__OnRightClickRelease')
        this._OnMiddleClick         := ObjBindMethod(this, '__OnMiddleClick')
        this._OnMiddleClickRelease  := ObjBindMethod(this, '__OnMiddleClickRelease')

        this._ih := InputHook('L0 V')
        this._ih.KeyOpt('{All}', 'N')
        this._ih.OnKeyDown := ObjBindMethod(this, '__OnKeyPress')

        this.open := false
        this._sections := Map()
        this._iconCache := Map()
        this._sortedWindows := false

        ; dimensions
        this._x := 0
        this._y := 0
        this._menuHeight := 0
        this._lastWindowListWidth := 0

        this._scrollOffset := 0
        this._targetScrollOffset := 0
        this._hoveredCloseButton := 0
        this._hoveredOver := 0
        this._clicked := {item: '', index: 0}
        this._mouseLeft := true
        this._closeButtonRects := []
        this._onWindowActivate := (*) => 0
        this._onMenuOpen := (*) => 0
        this._isDrawing := false
        this._scrollTimer := ObjBindMethod(this, '__AnimateScroll')
        this._scrollTimerActive := false
        this._canScroll := false
        this._showInfoPanel := false
        this._thumbnail := 0
        this._panelTab := 'preview'  ; default to preview tab
        this._panelTabRects := []
        this._hoveredPanelTab := ''  ; track which tab is being hovered
        this._lastPreviewHwnd := 0
        this._lastWindowCount := 0
        this._lastUsedDevice := 'keyboard'

        this._userIsTyping := false
        this._tempDisablePanel := false
        this._private_searchText := ''

        this.DefineProp('_searchText', {
            Get: (self) => this._private_searchText,
            Set: (self, value) {
                this._private_searchText := value

                emptySearchField := this._private_searchText = this.placeholderSearchText || this._private_searchText = ''

                if !emptySearchField {
                    this._userIsTyping := true

                    if this._showInfoPanel {
                        this._tempDisablePanel := true
                        this._showInfoPanel := false
                    }
                } else if this._userIsTyping {
                    this._userIsTyping := false

                    if this._tempDisablePanel {
                        this._showInfoPanel := true
                        this._tempDisablePanel := false
                    }
                }
            }
        })

        ; Allows custom name overrides. This exists because I couldn't find Steam's actual DisplayName/ProductName
        ; Key = exe name (excludes .exe) e.g. Steam's .exe name is steamwebhelper.exe so I've added steamwebhelper to the map.
        ; Value = the name you want the window to have
        this.nameOverrides := Map()
        this.nameOverrides.CaseSense := 'Off'
    }
}