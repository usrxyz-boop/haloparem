local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local VIM = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
while not LP do task.wait() LP = Players.LocalPlayer end

-- SETTINGS (shared by GUI + farm loop)
local SPEED, TIMEOUT, SKIP = 20, 3, 1
local MIN_DIST = 6          -- farm ignores coins closer than this (Coin Aura grabs them). Set 0 to disable.
local AURA_RADIUS = 8
local EMOTE_ID, EMOTE_POS = 87058607990254, 0.84
local joinRejoinEnabled = true

local env = (getgenv and getgenv()) or _G
env.__CoinFarmRun = (env.__CoinFarmRun or 0) + 1
local runId = env.__CoinFarmRun

local function active()
    return env.__CoinFarmRun == runId
end

-- Remove GUI left over from an older run
pcall(function()
    local old = LP:WaitForChild("PlayerGui"):FindFirstChild("CoinFarmGUI")
    if old then old:Destroy() end
end)

--------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CoinFarmGUI"
gui.ResetOnSpawn = false
gui.Parent = LP:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(270, 240)
frame.Position = UDim2.new(0.5, -135, 0.5, -120)
frame.BackgroundColor3 = Color3.fromRGB(25, 27, 35)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -52, 0, 38)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = "Coin Farm | Tablet"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

-- Drag (touch + mouse)
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement
    ) then
        local d = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local function button(text, y, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 34)
    b.Position = UDim2.fromOffset(10, y)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    b.Text = text
    b.BorderSizePixel = 0
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local toggle = button("Auto Join + Rejoin: ON", 42, Color3.fromRGB(38, 135, 95))
toggle.Activated:Connect(function()
    joinRejoinEnabled = not joinRejoinEnabled
    toggle.Text = "Auto Join + Rejoin: " .. (joinRejoinEnabled and "ON" or "OFF")
    toggle.BackgroundColor3 = joinRejoinEnabled
        and Color3.fromRGB(38, 135, 95)
        or Color3.fromRGB(65, 67, 78)
end)

local function makeBox(label, value, y)
    local name = Instance.new("TextLabel")
    name.Size = UDim2.fromOffset(100, 30)
    name.Position = UDim2.fromOffset(14, y)
    name.BackgroundTransparency = 1
    name.Text = label
    name.TextColor3 = Color3.new(1, 1, 1)
    name.TextSize = 13
    name.Font = Enum.Font.Gotham
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.fromOffset(125, 28)
    box.Position = UDim2.new(1, -139, 0, y + 1)
    box.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.PlaceholderText = label
    box.Text = tostring(value)
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.BorderSizePixel = 0
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)
    return box
end

local speedBox = makeBox("SPEED", SPEED, 85)
local timeoutBox = makeBox("TIMEOUT", TIMEOUT, 123)
local skipBox = makeBox("SKIP", SKIP, 161)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 25)
status.Position = UDim2.fromOffset(10, 204)
status.BackgroundTransparency = 1
status.Text = "Settings ready"
status.TextColor3 = Color3.fromRGB(180, 190, 205)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.Parent = frame

local function setStatus(text)
    if status and status.Parent then status.Text = text end
end

local function updateSettings()
    local s = tonumber(speedBox.Text)
    local t = tonumber(timeoutBox.Text)
    local k = tonumber(skipBox.Text)
    if s and s > 0 then SPEED = math.clamp(s, 1, 100) end
    if t and t > 0 then TIMEOUT = math.clamp(t, 0.1, 30) end
    if k and k >= 0 then SKIP = math.clamp(k, 0, 10) end
    setStatus(string.format("Saved: speed %s | timeout %s | skip %s", SPEED, TIMEOUT, SKIP))
end

for _, box in ipairs({speedBox, timeoutBox, skipBox}) do
    box.FocusLost:Connect(updateSettings)
end

-- Minimize button + reopen icon
local ICON_URL = "https://raw.githubusercontent.com/usrxyz-boop/haloparem/main/MM2CoinIcon.png"

local minimize = Instance.new("TextButton")
minimize.Name = "Minimize"
minimize.Size = UDim2.fromOffset(30, 30)
minimize.Position = UDim2.new(1, -36, 0, 4)
minimize.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
minimize.Text = "—"
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.TextSize = 20
minimize.BorderSizePixel = 0
minimize.Parent = frame
Instance.new("UICorner", minimize).CornerRadius = UDim.new(0, 6)

local iconButton = Instance.new("ImageButton")
iconButton.Name = "CoinFarmIcon"
iconButton.Size = UDim2.fromOffset(52, 52)
iconButton.Position = UDim2.new(0, 15, 0.5, -26)
iconButton.BackgroundColor3 = Color3.fromRGB(25, 27, 35)
iconButton.Image = ICON_URL
iconButton.ScaleType = Enum.ScaleType.Fit
iconButton.Visible = false
iconButton.Parent = gui
Instance.new("UICorner", iconButton).CornerRadius = UDim.new(1, 0)

local iconBorder = Instance.new("UIStroke")
iconBorder.Color = Color3.fromRGB(90, 170, 255)
iconBorder.Thickness = 2
iconBorder.Parent = iconButton

minimize.Activated:Connect(function()
    frame.Visible = false
    iconButton.Visible = true
end)

iconButton.Activated:Connect(function()
    frame.Visible = true
    iconButton.Visible = false
end)

--------------------------------------------------------------------
-- AUTO JOIN (Tablet) + AUTO REJOIN
--------------------------------------------------------------------
local rejoining = false

local function tap(btn)
    if not btn then return end
    local p = btn.AbsolutePosition + btn.AbsoluteSize / 2
    VIM:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0)
end

task.spawn(function()
    while active() do
        local pg = LP:FindFirstChild("PlayerGui")
        if joinRejoinEnabled and pg and not pg:FindFirstChild("MainGUI") then
            pcall(function() tap(pg.DeviceSelect.Container.Tablet.Button) end)
            pcall(function() tap(pg.Join.Friends.Play) end)
        end
        task.wait(0.5)
    end
end)

GuiService.ErrorMessageChanged:Connect(function(msg)
    if not active() or not joinRejoinEnabled
        or not msg or msg == "" or rejoining then return end
    rejoining = true
    task.wait(1)
    if active() and joinRejoinEnabled then
        pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
    end
end)

-- Anti-AFK
LP.Idled:Connect(function()
    if not active() then return end
    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.1)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end)

--------------------------------------------------------------------
-- EMOTE FREEZE
--------------------------------------------------------------------
local track

local function emote(char)
    local hum = char:WaitForChild("Humanoid")
    local animator = hum:WaitForChild("Animator")
    if track then pcall(function() track:Stop(0) end) end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. EMOTE_ID
    local t = animator:LoadAnimation(anim)
    track = t
    t.Priority = Enum.AnimationPriority.Action4
    t:Play(0)

    task.spawn(function()
        local waited = os.clock()
        while active() and t == track and t.IsPlaying
            and t.Length == 0 and os.clock() - waited < 5 do
            task.wait()
        end
        if active() and t == track and t.IsPlaying then
            t.TimePosition = EMOTE_POS
            t:AdjustSpeed(0)
        end
    end)
end

LP.CharacterAdded:Connect(function(char)
    task.spawn(emote, char)
end)
if LP.Character then task.spawn(emote, LP.Character) end

--------------------------------------------------------------------
-- COIN HELPERS
--------------------------------------------------------------------
local function touch(a, b)
    pcall(function()
        firetouchinterest(a, b, 0)
        firetouchinterest(a, b, 1)
    end)
end

-- Works whether the coin is a Part or a Model
local function getCoinPart(coin)
    if coin:IsA("BasePart") then return coin end
    if coin:IsA("Model") and coin.PrimaryPart then return coin.PrimaryPart end
    return coin:FindFirstChildWhichIsA("BasePart", true)
end

local function getCoinVisual(coin)
    return coin:FindFirstChild("CoinVisual", true)
end

local function isCollected(coin)
    if not coin or not coin.Parent then return true end
    local v = getCoinVisual(coin)
    if not v then return true end
    if v:GetAttribute("Collected") then return true end
    if coin:GetAttribute("Collected") then return true end
    return false
end

--------------------------------------------------------------------
-- COIN AURA
--------------------------------------------------------------------
task.spawn(function()
    while active() do
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            for _, map in ipairs(Workspace:GetChildren()) do
                local c = map:FindFirstChild("CoinContainer")
                if c then
                    for _, part in ipairs(c:GetDescendants()) do
                        if part:IsA("BasePart")
                            and part:FindFirstChild("TouchInterest")
                            and (root.Position - part.Position).Magnitude <= AURA_RADIUS then
                            touch(root, part)
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

--------------------------------------------------------------------
-- AUTO FARM
--------------------------------------------------------------------
local skipped = {}

local function nearest(root)
    local best, bestPart, bestDist = nil, nil, math.huge
    for _, map in ipairs(Workspace:GetChildren()) do
        local c = map:FindFirstChild("CoinContainer")
        if c then
            for _, coin in ipairs(c:GetChildren()) do
                if not isCollected(coin)
                    and not (skipped[coin] and skipped[coin] > os.clock()) then
                    local part = getCoinPart(coin)
                    if part then
                        local d = (root.Position - part.Position).Magnitude
                        if d > MIN_DIST and d < bestDist then
                            best, bestPart, bestDist = coin, part, d
                        end
                    end
                end
            end
        end
    end
    return best, bestPart
end

task.spawn(function()
    while active() do
        local ok, err = pcall(function()
            local char = LP.Character or LP.CharacterAdded:Wait()
            local root = char:WaitForChild("HumanoidRootPart")
            local hum = char:WaitForChild("Humanoid")

            -- Only stop if the game explicitly says we're not alive
            if hum.Health <= 0 or LP:GetAttribute("Alive") == false then
                setStatus("Waiting to spawn...")
                task.wait(0.5)
                return
            end

            local coin, part = nearest(root)
            if not coin then
                setStatus("No coins found")
                task.wait(0.5)
                return
            end

            setStatus("Farming: " .. coin.Name)
            pcall(function() hum:ChangeState(11) end)

            local start, goal = root.Position, part.Position
            local dir = Vector3.new(goal.X - start.X, 0, goal.Z - start.Z)
            local cf = dir.Magnitude > 0.01
                and CFrame.lookAt(goal, goal + dir) or CFrame.new(goal)

            local tween = TweenService:Create(
                root,
                TweenInfo.new(math.max((start - goal).Magnitude / SPEED, 0.05),
                    Enum.EasingStyle.Linear),
                {CFrame = cf}
            )
            tween:Play()

            local began = os.clock()
            while active() and os.clock() - began < TIMEOUT do
                if isCollected(coin) then break end
                if hum.Health <= 0 then break end
                if (root.Position - part.Position).Magnitude <= AURA_RADIUS then break end
                task.wait(0.05)
            end

            if tween.PlaybackState == Enum.PlaybackState.Playing then
                tween:Cancel()
            end

            if not isCollected(coin) then
                skipped[coin] = os.clock() + SKIP
            end
        end)

        if not ok then warn("[Farm] " .. tostring(err)) end
        task.wait()
    end
end)

print("Coin Farm loaded")
