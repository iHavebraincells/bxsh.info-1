--// Aztup UI Library (Rewritten & Fixed)
--// Full rewrite: fixed dragging, sliders, notifications, added new elements

local Players         = game:GetService("Players")
local UIS             = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------------
-- Library table
----------------------------------------------------------------------
local library = {
    windows       = {},
    gui           = nil,
    _notifQueue   = {},   -- for stacking notifications
    _notifPad     = 10,
    _notifHeight  = 65,
}

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------

-- Creates an Instance and sets all properties; Parent is set last.
local function create(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            obj[k] = v
        end
    end
    if props.Parent then
        obj.Parent = props.Parent
    end
    return obj
end

-- Rounded corner helper
local function addCorner(parent, radius)
    return create("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius or 6) })
end

-- Padding helper
local function addPadding(parent, h, v)
    return create("UIPadding", {
        Parent = parent,
        PaddingLeft   = UDim.new(0, h or 6),
        PaddingRight  = UDim.new(0, h or 6),
        PaddingTop    = UDim.new(0, v or 4),
        PaddingBottom = UDim.new(0, v or 4),
    })
end

local function tween(obj, t, props, style, dir)
    TweenService:Create(obj,
        TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    ):Play()
end

-- Ensure the root ScreenGui exists once
local function ensureGui(lib)
    if not lib.gui or not lib.gui.Parent then
        lib.gui = create("ScreenGui", {
            Parent           = LocalPlayer:WaitForChild("PlayerGui"),
            Name             = "AztupUI",
            ResetOnSpawn     = false,
            ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
            IgnoreGuiInset   = true,
        })
    end
    return lib.gui
end

----------------------------------------------------------------------
-- NOTIFICATIONS  (stacking, no overlap)
----------------------------------------------------------------------

local NOTIF_W = 260
local NOTIF_H = 65
local NOTIF_PAD = 8
local NOTIF_MARGIN_X = 16
local NOTIF_MARGIN_Y = 16

function library:Notify(data)
    data = data or {}
    local title    = data.title    or "Notification"
    local text     = data.text     or ""
    local duration = data.duration or 3

    ensureGui(self)

    -- Hidden off-screen start position (slide in from right)
    local slot = #self._notifQueue + 1
    local yPos = -(NOTIF_MARGIN_Y + (NOTIF_H + NOTIF_PAD) * slot)

    local frame = create("Frame", {
        Parent           = self.gui,
        Size             = UDim2.new(0, NOTIF_W, 0, NOTIF_H),
        Position         = UDim2.new(1, NOTIF_W + NOTIF_MARGIN_X, 1, yPos),
        BackgroundColor3 = Color3.fromRGB(22, 22, 28),
        BorderSizePixel  = 0,
        ZIndex           = 50,
    })
    addCorner(frame, 8)

    -- Accent bar on the left
    local accent = create("Frame", {
        Parent           = frame,
        Size             = UDim2.new(0, 3, 1, -12),
        Position         = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = data.accentColor or Color3.fromRGB(100, 160, 255),
        BorderSizePixel  = 0,
        ZIndex           = 51,
    })
    addCorner(accent, 3)

    create("TextLabel", {
        Parent            = frame,
        Size              = UDim2.new(1, -24, 0, 22),
        Position          = UDim2.new(0, 18, 0, 8),
        Text              = title,
        TextColor3        = Color3.fromRGB(240, 240, 240),
        BackgroundTransparency = 1,
        TextXAlignment    = Enum.TextXAlignment.Left,
        Font              = Enum.Font.GothamBold,
        TextSize          = 13,
        ZIndex            = 51,
    })

    create("TextLabel", {
        Parent            = frame,
        Size              = UDim2.new(1, -24, 0, 28),
        Position          = UDim2.new(0, 18, 0, 30),
        Text              = text,
        TextColor3        = Color3.fromRGB(180, 180, 190),
        BackgroundTransparency = 1,
        TextXAlignment    = Enum.TextXAlignment.Left,
        TextWrapped       = true,
        Font              = Enum.Font.Gotham,
        TextSize          = 11,
        ZIndex            = 51,
    })

    table.insert(self._notifQueue, frame)

    -- Slide in
    tween(frame, 0.35, { Position = UDim2.new(1, -(NOTIF_W + NOTIF_MARGIN_X), 1, yPos) })

    task.delay(duration, function()
        -- Slide out
        tween(frame, 0.3, { Position = UDim2.new(1, NOTIF_W + NOTIF_MARGIN_X, 1, yPos) })
        task.wait(0.35)
        frame:Destroy()

        -- Remove from queue and re-stack remaining
        for i, f in ipairs(self._notifQueue) do
            if f == frame then
                table.remove(self._notifQueue, i)
                break
            end
        end
        for i, f in ipairs(self._notifQueue) do
            local newY = -(NOTIF_MARGIN_Y + (NOTIF_H + NOTIF_PAD) * i)
            tween(f, 0.25, { Position = UDim2.new(1, -(NOTIF_W + NOTIF_MARGIN_X), 1, newY) })
        end
    end)
end

----------------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------------

function library:CreateWindow(config)
    config = config or {}

    local ACCENT     = config.accent     or Color3.fromRGB(100, 160, 255)
    local BAR_COLOR  = config.barColor   or Color3.fromRGB(18, 18, 24)
    local BG_COLOR   = config.bgColor    or Color3.fromRGB(28, 28, 36)
    local TEXT_COLOR = config.textColor  or Color3.fromRGB(240, 240, 240)
    local title      = config.title      or config.text or "Window"
    local keybind    = config.keybind    or nil  -- e.g. Enum.KeyCode.RightShift

    ensureGui(self)

    --------------------------------------------------------------------
    -- Root frame (title bar)
    --------------------------------------------------------------------
    local main = create("Frame", {
        Parent           = self.gui,
        Size             = UDim2.new(0, 230, 0, 32),
        Position         = config.position or UDim2.new(0, 40, 0, 40),
        BackgroundColor3 = BAR_COLOR,
        BorderSizePixel  = 0,
        Active           = true,
        ClipsDescendants = false,
    })
    addCorner(main, 8)
    create("UIStroke", { Parent = main, Color = Color3.fromRGB(50, 50, 65), Thickness = 1 })

    -- Accent top strip
    local strip = create("Frame", {
        Parent           = main,
        Size             = UDim2.new(1, 0, 0, 2),
        Position         = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = ACCENT,
        BorderSizePixel  = 0,
        ZIndex           = 2,
    })
    addCorner(strip, 2)

    -- Title label
    create("TextLabel", {
        Parent            = main,
        Size              = UDim2.new(1, -48, 1, 0),
        Position          = UDim2.new(0, 12, 0, 0),
        Text              = title,
        TextColor3        = TEXT_COLOR,
        BackgroundTransparency = 1,
        TextXAlignment    = Enum.TextXAlignment.Left,
        Font              = Enum.Font.GothamBold,
        TextSize          = 13,
        ZIndex            = 2,
    })

    -- Collapse button
    local collapseBtn = create("TextButton", {
        Parent            = main,
        Size              = UDim2.new(0, 22, 0, 22),
        Position          = UDim2.new(1, -26, 0.5, -11),
        Text              = "−",
        TextColor3        = Color3.fromRGB(180, 180, 195),
        BackgroundColor3  = Color3.fromRGB(40, 40, 52),
        BorderSizePixel   = 0,
        Font              = Enum.Font.GothamBold,
        TextSize          = 14,
        ZIndex            = 3,
    })
    addCorner(collapseBtn, 5)

    --------------------------------------------------------------------
    -- Container (scrollable content area)
    --------------------------------------------------------------------
    local container = create("ScrollingFrame", {
        Parent                   = main,
        Size                     = UDim2.new(1, 0, 0, 0),
        Position                 = UDim2.new(0, 0, 1, 4),
        BackgroundColor3         = BG_COLOR,
        BorderSizePixel          = 0,
        ClipsDescendants         = true,
        ScrollBarThickness       = 3,
        ScrollBarImageColor3     = ACCENT,
        CanvasSize               = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize      = Enum.AutomaticSize.Y,
        ZIndex                   = 2,
    })
    addCorner(container, 8)
    create("UIStroke", { Parent = container, Color = Color3.fromRGB(50, 50, 65), Thickness = 1 })

    local layout = create("UIListLayout", {
        Parent          = container,
        SortOrder       = Enum.SortOrder.LayoutOrder,
        Padding         = UDim.new(0, 2),
    })
    addPadding(container, 6, 6)

    -- Keep container height synced with content (max 340)
    local MAX_H = config.maxHeight or 340
    local function updateContainerSize()
        local h = math.min(layout.AbsoluteContentSize.Y + 14, MAX_H)
        container.Size = UDim2.new(1, 0, 0, h)
        main.Size = UDim2.new(0, 230, 0, 32)  -- bar stays fixed; container is sibling
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateContainerSize)
    task.defer(updateContainerSize)

    --------------------------------------------------------------------
    -- Dragging (no global mouse-move bleed between windows)
    --------------------------------------------------------------------
    local dragging, dragStart, startPos = false, nil, nil

    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos  = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale,  startPos.X.Offset + delta.X,
                startPos.Y.Scale,  startPos.Y.Offset + delta.Y
            )
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    --------------------------------------------------------------------
    -- Collapse / expand
    --------------------------------------------------------------------
    local collapsed = false

    collapseBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        if collapsed then
            tween(container, 0.25, { Size = UDim2.new(1, 0, 0, 0) })
            collapseBtn.Text = "+"
        else
            updateContainerSize()
            local target = math.min(layout.AbsoluteContentSize.Y + 14, MAX_H)
            tween(container, 0.25, { Size = UDim2.new(1, 0, 0, target) })
            collapseBtn.Text = "−"
        end
    end)

    -- Optional keybind to show/hide the whole window
    if keybind then
        UIS.InputBegan:Connect(function(input, gpe)
            if not gpe and input.KeyCode == keybind then
                main.Visible = not main.Visible
            end
        end)
    end

    --------------------------------------------------------------------
    -- Shared element styles
    --------------------------------------------------------------------
    local ELEM_BG      = Color3.fromRGB(36, 36, 46)
    local ELEM_BG_HOV  = Color3.fromRGB(44, 44, 58)
    local ELEM_H       = 28

    local function applyHover(btn, normal, hover)
        btn.MouseEnter:Connect(function() tween(btn, 0.12, { BackgroundColor3 = hover }) end)
        btn.MouseLeave:Connect(function() tween(btn, 0.12, { BackgroundColor3 = normal }) end)
    end

    local function baseElem(h)
        local f = create("Frame", {
            Parent           = container,
            Size             = UDim2.new(1, 0, 0, h or ELEM_H),
            BackgroundColor3 = ELEM_BG,
            BorderSizePixel  = 0,
        })
        addCorner(f, 5)
        return f
    end

    --------------------------------------------------------------------
    -- Window object returned to the caller
    --------------------------------------------------------------------
    local window = { _collapsed = false, _main = main, _container = container }

    ------------------------------------------------------------------
    -- SEPARATOR / LABEL
    ------------------------------------------------------------------
    function window:Label(text)
        local f = baseElem(22)
        create("TextLabel", {
            Parent            = f,
            Size              = UDim2.new(1, -10, 1, 0),
            Position          = UDim2.new(0, 8, 0, 0),
            Text              = text,
            TextColor3        = Color3.fromRGB(160, 160, 180),
            BackgroundTransparency = 1,
            TextXAlignment    = Enum.TextXAlignment.Left,
            Font              = Enum.Font.Gotham,
            TextSize          = 11,
        })
    end

    function window:Separator(text)
        local f = create("Frame", {
            Parent           = container,
            Size             = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
        })
        local line = create("Frame", {
            Parent           = f,
            Size             = UDim2.new(1, -10, 0, 1),
            Position         = UDim2.new(0, 5, 0.5, 0),
            BackgroundColor3 = Color3.fromRGB(55, 55, 70),
            BorderSizePixel  = 0,
        })
        if text and text ~= "" then
            local lbl = create("TextLabel", {
                Parent            = f,
                AutomaticSize     = Enum.AutomaticSize.X,
                Size              = UDim2.new(0, 0, 1, 0),
                Position          = UDim2.new(0.5, 0, 0, 0),
                AnchorPoint       = Vector2.new(0.5, 0),
                Text              = "  " .. text .. "  ",
                TextColor3        = Color3.fromRGB(130, 130, 155),
                BackgroundColor3  = BG_COLOR,
                BorderSizePixel   = 0,
                Font              = Enum.Font.GothamBold,
                TextSize          = 10,
            })
        end
    end

    ------------------------------------------------------------------
    -- BUTTON
    ------------------------------------------------------------------
    function window:Button(text, callback)
        local f = baseElem(ELEM_H)
        local btn = create("TextButton", {
            Parent            = f,
            Size              = UDim2.new(1, 0, 1, 0),
            Text              = text,
            TextColor3        = Color3.fromRGB(220, 220, 235),
            BackgroundTransparency = 1,
            Font              = Enum.Font.Gotham,
            TextSize          = 12,
        })
        applyHover(f, ELEM_BG, ELEM_BG_HOV)

        btn.MouseButton1Click:Connect(function()
            tween(f, 0.08, { BackgroundColor3 = ACCENT })
            tween(f, 0.2,  { BackgroundColor3 = ELEM_BG_HOV })
            pcall(callback)
        end)
    end

    ------------------------------------------------------------------
    -- TOGGLE
    ------------------------------------------------------------------
    function window:Toggle(text, default, callback)
        -- Normalise old-style call: Toggle(text, callback)
        if type(default) == "function" then
            callback = default
            default  = false
        end
        local state = default == true

        local f = baseElem(ELEM_H)

        local label = create("TextLabel", {
            Parent            = f,
            Size              = UDim2.new(1, -50, 1, 0),
            Position          = UDim2.new(0, 8, 0, 0),
            Text              = text,
            TextColor3        = Color3.fromRGB(220, 220, 235),
            BackgroundTransparency = 1,
            TextXAlignment    = Enum.TextXAlignment.Left,
            Font              = Enum.Font.Gotham,
            TextSize          = 12,
        })

        -- Pill track
        local track = create("Frame", {
            Parent           = f,
            Size             = UDim2.new(0, 34, 0, 18),
            Position         = UDim2.new(1, -42, 0.5, -9),
            BackgroundColor3 = state and ACCENT or Color3.fromRGB(55, 55, 70),
            BorderSizePixel  = 0,
        })
        addCorner(track, 9)

        -- Thumb
        local thumb = create("Frame", {
            Parent           = track,
            Size             = UDim2.new(0, 12, 0, 12),
            Position         = state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel  = 0,
        })
        addCorner(thumb, 6)

        local btn = create("TextButton", {
            Parent            = f,
            Size              = UDim2.new(1, 0, 1, 0),
            Text              = "",
            BackgroundTransparency = 1,
        })
        applyHover(f, ELEM_BG, ELEM_BG_HOV)

        local function refresh()
            tween(track, 0.18, { BackgroundColor3 = state and ACCENT or Color3.fromRGB(55, 55, 70) })
            tween(thumb, 0.18, { Position = state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6) })
        end
        refresh()

        btn.MouseButton1Click:Connect(function()
            state = not state
            refresh()
            pcall(callback, state)
        end)

        -- Return an object so the caller can programmatically set state
        return {
            SetState = function(_, s)
                state = s
                refresh()
            end,
            GetState = function() return state end,
        }
    end

    ------------------------------------------------------------------
    -- SLIDER
    ------------------------------------------------------------------
    function window:Slider(text, min, max, default, callback)
        -- Normalise old-style call: Slider(text, min, max, callback)
        if type(default) == "function" then
            callback = default
            default  = min
        end
        default = math.clamp(default or min, min, max)

        local value = default

        local f = baseElem(42)

        create("TextLabel", {
            Parent            = f,
            Size              = UDim2.new(1, -50, 0, 18),
            Position          = UDim2.new(0, 8, 0, 4),
            Text              = text,
            TextColor3        = Color3.fromRGB(220, 220, 235),
            BackgroundTransparency = 1,
            TextXAlignment    = Enum.TextXAlignment.Left,
            Font              = Enum.Font.Gotham,
            TextSize          = 12,
        })

        local valLabel = create("TextLabel", {
            Parent            = f,
            Size              = UDim2.new(0, 40, 0, 18),
            Position          = UDim2.new(1, -48, 0, 4),
            Text              = tostring(value),
            TextColor3        = ACCENT,
            BackgroundTransparency = 1,
            TextXAlignment    = Enum.TextXAlignment.Right,
            Font              = Enum.Font.GothamBold,
            TextSize          = 12,
        })

        -- Track background
        local track = create("Frame", {
            Parent           = f,
            Size             = UDim2.new(1, -16, 0, 5),
            Position         = UDim2.new(0, 8, 1, -12),
            BackgroundColor3 = Color3.fromRGB(50, 50, 65),
            BorderSizePixel  = 0,
        })
        addCorner(track, 3)

        -- Fill
        local fill = create("Frame", {
            Parent           = track,
            Size             = UDim2.new((value - min) / (max - min), 0, 1, 0),
            BackgroundColor3 = ACCENT,
            BorderSizePixel  = 0,
        })
        addCorner(fill, 3)

        -- Invisible drag button over track
        local dragBtn = create("TextButton", {
            Parent            = track,
            Size              = UDim2.new(1, 0, 0, 20),
            Position          = UDim2.new(0, 0, 0.5, -10),
            Text              = "",
            BackgroundTransparency = 1,
        })

        local sliding = false

        local function applyDrag(inputPos)
            local relX = math.clamp(inputPos.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
            local pct  = relX / track.AbsoluteSize.X
            value = math.floor(min + (max - min) * pct + 0.5)
            fill.Size  = UDim2.new(pct, 0, 1, 0)
            valLabel.Text = tostring(value)
            pcall(callback, value)
        end

        dragBtn.MouseButton1Down:Connect(function()
            sliding = true
        end)

        UIS.InputChanged:Connect(function(input)
            if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
                applyDrag(input.Position)
            end
        end)

        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                sliding = false
            end
        end)

        return {
            SetValue = function(_, v)
                value = math.clamp(v, min, max)
                local pct = (value - min) / (max - min)
                fill.Size     = UDim2.new(pct, 0, 1, 0)
                valLabel.Text = tostring(value)
            end,
            GetValue = function() return value end,
        }
    end

    ------------------------------------------------------------------
    -- DROPDOWN
    ------------------------------------------------------------------
    function window:Dropdown(text, options, callback)
        options = options or {}
        local selected = nil

        local f = baseElem(ELEM_H)

        create("TextLabel", {
            Parent            = f,
            Size              = UDim2.new(0.6, 0, 1, 0),
            Position          = UDim2.new(0, 8, 0, 0),
            Text              = text,
            TextColor3        = Color3.fromRGB(220, 220, 235),
            BackgroundTransparency = 1,
            TextXAlignment    = Enum.TextXAlignment.Left,
            Font              = Enum.Font.Gotham,
            TextSize          = 12,
        })

        local selLabel = create("TextLabel", {
            Parent            = f,
            Size              = UDim2.new(0.35, 0, 1, 0),
            Position          = UDim2.new(0.62, 0, 0, 0),
            Text              = "Select...",
            TextColor3        = Color3.fromRGB(140, 140, 165),
            BackgroundTransparency = 1,
            TextXAlignment    = Enum.TextXAlignment.Right,
            Font              = Enum.Font.Gotham,
            TextSize          = 11,
        })

        local arrow = create("TextLabel", {
            Parent            = f,
            Size              = UDim2.new(0, 16, 1, 0),
            Position          = UDim2.new(1, -20, 0, 0),
            Text              = "▾",
            TextColor3        = Color3.fromRGB(140, 140, 165),
            BackgroundTransparency = 1,
            Font              = Enum.Font.Gotham,
            TextSize          = 12,
        })

        -- Dropdown panel (rendered inside main, above container clip)
        local panel = create("Frame", {
            Parent           = main,
            Size             = UDim2.new(0, 218, 0, 0),
            Position         = UDim2.new(0, 6, 0, 32),   -- will be repositioned
            BackgroundColor3 = Color3.fromRGB(28, 28, 38),
            BorderSizePixel  = 0,
            Visible          = false,
            ZIndex           = 10,
        })
        addCorner(panel, 6)
        create("UIStroke", { Parent = panel, Color = Color3.fromRGB(55, 55, 70), Thickness = 1 })

        local panelLayout = create("UIListLayout", {
            Parent    = panel,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding   = UDim.new(0, 1),
        })
        addPadding(panel, 4, 4)

        local function closePanel()
            tween(panel, 0.15, { Size = UDim2.new(0, 218, 0, 0) })
            task.delay(0.15, function() panel.Visible = false end)
            tween(arrow, 0.15, { Rotation = 0 })
        end

        local open = false

        -- Build option rows
        for _, opt in ipairs(options) do
            local row = create("TextButton", {
                Parent            = panel,
                Size              = UDim2.new(1, 0, 0, 24),
                Text              = opt,
                TextColor3        = Color3.fromRGB(210, 210, 230),
                BackgroundColor3  = Color3.fromRGB(36, 36, 48),
                BorderSizePixel   = 0,
                Font              = Enum.Font.Gotham,
                TextSize          = 11,
                ZIndex            = 11,
            })
            addCorner(row, 4)

            row.MouseEnter:Connect(function() tween(row, 0.1, { BackgroundColor3 = Color3.fromRGB(48, 48, 64) }) end)
            row.MouseLeave:Connect(function() tween(row, 0.1, { BackgroundColor3 = Color3.fromRGB(36, 36, 48) }) end)

            row.MouseButton1Click:Connect(function()
                selected = opt
                selLabel.Text  = opt
                selLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
                closePanel()
                open = false
                pcall(callback, opt)
            end)
        end

        -- Toggle button
        local toggleBtn = create("TextButton", {
            Parent            = f,
            Size              = UDim2.new(1, 0, 1, 0),
            Text              = "",
            BackgroundTransparency = 1,
        })
        applyHover(f, ELEM_BG, ELEM_BG_HOV)

        toggleBtn.MouseButton1Click:Connect(function()
            open = not open
            if open then
                -- Position panel just below this element
                local relY = f.AbsolutePosition.Y - container.AbsolutePosition.Y + container.CanvasPosition.Y
                panel.Position = UDim2.new(0, 6, 0, 32 + relY + ELEM_H + 2)
                panel.Visible  = true
                local targetH  = math.min(panelLayout.AbsoluteContentSize.Y + 10, 160)
                tween(panel, 0.18, { Size = UDim2.new(0, 218, 0, targetH) })
                tween(arrow, 0.15, { Rotation = 180 })
            else
                closePanel()
            end
        end)

        return {
            SetSelected = function(_, opt)
                selected = opt
                selLabel.Text = opt
            end,
            GetSelected = function() return selected end,
        }
    end

    ------------------------------------------------------------------
    -- TEXTBOX  (text input field)
    ------------------------------------------------------------------
    function window:TextBox(placeholder, callback)
        local f = baseElem(ELEM_H)

        local box = create("TextBox", {
            Parent            = f,
            Size              = UDim2.new(1, -10, 1, -6),
            Position          = UDim2.new(0, 5, 0, 3),
            PlaceholderText   = placeholder or "Type here...",
            Text              = "",
            TextColor3        = Color3.fromRGB(220, 220, 235),
            PlaceholderColor3 = Color3.fromRGB(110, 110, 130),
            BackgroundTransparency = 1,
            Font              = Enum.Font.Gotham,
            TextSize          = 12,
            TextXAlignment    = Enum.TextXAlignment.Left,
            ClearTextOnFocus  = false,
        })

        box.FocusLost:Connect(function(enter)
            if enter then
                pcall(callback, box.Text)
            end
        end)

        f.MouseEnter:Connect(function() tween(f, 0.12, { BackgroundColor3 = ELEM_BG_HOV }) end)
        f.MouseLeave:Connect(function() tween(f, 0.12, { BackgroundColor3 = ELEM_BG }) end)

        return {
            GetText  = function() return box.Text end,
            SetText  = function(_, t) box.Text = t end,
            Clear    = function() box.Text = "" end,
        }
    end

    ------------------------------------------------------------------
    -- COLORPICKER  (hue strip + quick presets)
    ------------------------------------------------------------------
    function window:ColorPicker(text, default, callback)
        default = default or Color3.fromRGB(255, 100, 100)
        local currentColor = default

        local f = baseElem(ELEM_H)

        create("TextLabel", {
            Parent            = f,
            Size              = UDim2.new(1, -50, 1, 0),
            Position          = UDim2.new(0, 8, 0, 0),
            Text              = text,
            TextColor3        = Color3.fromRGB(220, 220, 235),
            BackgroundTransparency = 1,
            TextXAlignment    = Enum.TextXAlignment.Left,
            Font              = Enum.Font.Gotham,
            TextSize          = 12,
        })

        local swatch = create("Frame", {
            Parent           = f,
            Size             = UDim2.new(0, 20, 0, 16),
            Position         = UDim2.new(1, -28, 0.5, -8),
            BackgroundColor3 = default,
            BorderSizePixel  = 0,
        })
        addCorner(swatch, 4)

        -- Expanded panel
        local panel = create("Frame", {
            Parent           = container,
            Size             = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(32, 32, 42),
            BorderSizePixel  = 0,
            ClipsDescendants = true,
            Visible          = false,
        })
        addCorner(panel, 5)

        local presets = {
            Color3.fromRGB(255,80,80),   Color3.fromRGB(255,160,50),
            Color3.fromRGB(255,220,50),  Color3.fromRGB(80,220,120),
            Color3.fromRGB(80,180,255),  Color3.fromRGB(160,100,255),
            Color3.fromRGB(255,100,180), Color3.fromRGB(255,255,255),
        }

        local presetRow = create("Frame", {
            Parent           = panel,
            Size             = UDim2.new(1, -12, 0, 24),
            Position         = UDim2.new(0, 6, 0, 6),
            BackgroundTransparency = 1,
        })
        create("UIListLayout", { Parent = presetRow, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) })

        for _, c in ipairs(presets) do
            local dot = create("TextButton", {
                Parent           = presetRow,
                Size             = UDim2.new(0, 20, 0, 20),
                Text             = "",
                BackgroundColor3 = c,
                BorderSizePixel  = 0,
            })
            addCorner(dot, 4)
            dot.MouseButton1Click:Connect(function()
                currentColor = c
                swatch.BackgroundColor3 = c
                pcall(callback, c)
            end)
        end

        local open = false
        local openBtn = create("TextButton", {
            Parent            = f,
            Size              = UDim2.new(1, 0, 1, 0),
            Text              = "",
            BackgroundTransparency = 1,
        })
        applyHover(f, ELEM_BG, ELEM_BG_HOV)

        openBtn.MouseButton1Click:Connect(function()
            open = not open
            if open then
                panel.Visible = true
                tween(panel, 0.18, { Size = UDim2.new(1, 0, 0, 38) })
            else
                tween(panel, 0.15, { Size = UDim2.new(1, 0, 0, 0) })
                task.delay(0.15, function() panel.Visible = false end)
            end
        end)

        return {
            SetColor = function(_, c)
                currentColor = c
                swatch.BackgroundColor3 = c
            end,
            GetColor = function() return currentColor end,
        }
    end

    ------------------------------------------------------------------
    -- Visibility helpers
    ------------------------------------------------------------------
    function window:Show()   main.Visible = true  end
    function window:Hide()   main.Visible = false end
    function window:Toggle() main.Visible = not main.Visible end

    function window:Destroy()
        main:Destroy()
    end

    table.insert(library.windows, window)
    return window
end

----------------------------------------------------------------------
-- Destroy everything
----------------------------------------------------------------------
function library:Destroy()
    if self.gui then
        self.gui:Destroy()
        self.gui = nil
    end
    self.windows = {}
    self._notifQueue = {}
end

return library
