--URL SUPPORT :PRAY:
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local function readAutoSearchFlag()
    if type(getgenv) ~= "function" then
        return false
    end

    local success, environment = pcall(getgenv)
    return success
        and type(environment) == "table"
        and environment.SpookyTreeAutoSearch == true
end

local function writeAutoSearchFlag(enabled)
    if type(getgenv) ~= "function" then
        return false
    end

    local success, environment = pcall(getgenv)
    if not success or type(environment) ~= "table" then
        return false
    end

    environment.SpookyTreeAutoSearch = enabled
    return true
end

local searchingForTree = readAutoSearchFlag()

local HIGHLIGHT_NAME = "SpookyTreeHighlight"
local SCRIPT_URL = "https://raw.githubusercontent.com/vlexlyss/spookytool/refs/heads/main/tool.lua"

local VALID_SCRIPT_KEYS = {
    ["SPOOKY-7K4M-9Q2X-1R8P"] = true, -- vlex key
    ["SPOOKY-3V6N-8B5L-0C2D"] = true,
    ["SPOOKY-9F1H-4W7J-6T3A"] = true,
    ["SPOOKY-2P8R-5Y0K-3M7N"] = true,
    ["SPOOKY-6D4C-1X9V-8L2H"] = true,
    ["SPOOKY-0J3Q-7A5F-2N9W"] = true,
    ["SPOOKY-8L2T-6M1P-4C7Y"] = true,
    ["SPOOKY-5N9B-3R0D-7H1X"] = true,
    ["SPOOKY-1W6K-8Q4A-9V2J"] = true,
    ["SPOOKY-4C7P-2Y5M-0D8L"] = true,
    ["SPOOKY-7H1X-9N3B-5R0D"] = true,
    ["SPOOKY-3M8V-6J2Q-1A4F"] = true,
    ["SPOOKY-9T5L-0C7Y-4P2N"] = true,
    ["SPOOKY-2A6D-8X1W-3K9H"] = true,
    ["SPOOKY-6Q4J-1B7M-9F2C"] = true
}

local loadMenu
local KEY_FILE_PATH = "SpookyTreeTools.key"

local function normalizeScriptKey(value)
    if type(value) ~= "string" then
        return nil
    end

    return string.upper(string.match(value, "^%s*(.-)%s*$") or "")
end

local function readSavedScriptKey()
    if type(readfile) == "function" then
        local success, key = pcall(readfile, KEY_FILE_PATH)
        if success then
            key = normalizeScriptKey(key)
            if VALID_SCRIPT_KEYS[key] then
                return key
            end
        end
    end

    if type(getgenv) == "function" then
        local success, environment = pcall(getgenv)
        if success and type(environment) == "table" then
            local key = normalizeScriptKey(environment.SpookyTreeSavedKey)
            if VALID_SCRIPT_KEYS[key] then
                return key
            end
        end
    end

    return nil
end

local function hasSavedAuthorization()
    if readSavedScriptKey() then
        return true
    end

    if type(getgenv) ~= "function" then
        return false
    end

    local success, environment = pcall(getgenv)
    return success
        and type(environment) == "table"
        and environment.SpookyTreeAuthorized == true
end

local function saveAuthorization(key)
    local savedToFile = false
    if type(writefile) == "function" then
        local success, err = pcall(writefile, KEY_FILE_PATH, key)
        if success then
            savedToFile = true
        else
            warn("Spooky Tree Tools: Could not save key file: " .. tostring(err))
        end
    end

    if type(getgenv) == "function" then
        local success, environment = pcall(getgenv)
        if success and type(environment) == "table" then
            environment.SpookyTreeSavedKey = key
            environment.SpookyTreeAuthorized = true
        end
    end

    if not savedToFile then
        warn("Spooky Tree Tools: Key is saved for this executor session only; "
            .. "persistent saving requires writefile support.")
    end
end

local function showKeyScreen()
    local keyGui = Instance.new("ScreenGui")
    keyGui.Name = "SpookyTreeKeyPrompt"
    keyGui.ResetOnSpawn = false
    keyGui.Parent = playerGui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(340, 175)
    panel.Position = UDim2.new(0.5, -170, 0.5, -87)
    panel.BackgroundColor3 = Color3.fromRGB(15, 17, 19)
    panel.BorderSizePixel = 1
    panel.BorderColor3 = Color3.fromRGB(65, 100, 145)
    panel.Parent = keyGui

    local heading = Instance.new("TextLabel")
    heading.Size = UDim2.new(1, -20, 0, 35)
    heading.Position = UDim2.fromOffset(10, 8)
    heading.BackgroundTransparency = 1
    heading.Text = "Spooky Tools - Enter Key"
    heading.TextColor3 = Color3.fromRGB(225, 235, 245)
    heading.TextSize = 18
    heading.Font = Enum.Font.Arial
    heading.Parent = panel

    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(1, -30, 0, 38)
    keyInput.Position = UDim2.fromOffset(15, 52)
    keyInput.BackgroundColor3 = Color3.fromRGB(25, 34, 45)
    keyInput.BorderSizePixel = 1
    keyInput.BorderColor3 = Color3.fromRGB(67, 104, 150)
    keyInput.PlaceholderText = "Enter script key"
    keyInput.Text = ""
    keyInput.ClearTextOnFocus = false
    keyInput.TextColor3 = Color3.fromRGB(225, 235, 245)
    keyInput.PlaceholderColor3 = Color3.fromRGB(150, 165, 180)
    keyInput.TextSize = 15
    keyInput.Font = Enum.Font.Arial
    keyInput.Parent = panel

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -30, 0, 20)
    status.Position = UDim2.fromOffset(15, 93)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Color3.fromRGB(255, 125, 125)
    status.TextSize = 13
    status.Font = Enum.Font.Arial
    status.Parent = panel

    local submit = Instance.new("TextButton")
    submit.Size = UDim2.new(1, -30, 0, 38)
    submit.Position = UDim2.fromOffset(15, 122)
    submit.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
    submit.BorderSizePixel = 1
    submit.BorderColor3 = Color3.fromRGB(67, 104, 150)
    submit.Text = "Unlock"
    submit.TextColor3 = Color3.fromRGB(225, 235, 245)
    submit.TextSize = 16
    submit.Font = Enum.Font.Arial
    submit.AutoButtonColor = true
    submit.Parent = panel

    local submitting = false
    local function validateKey()
        if submitting then
            return
        end
        submitting = true

        local key = normalizeScriptKey(keyInput.Text)
        if not VALID_SCRIPT_KEYS[key] then
            status.Text = "Invalid key. Please try again."
            submitting = false
            return
        end

        saveAuthorization(key)
        keyGui:Destroy()
        loadMenu()
    end

    submit.MouseButton1Click:Connect(validateKey)
    keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            validateKey()
        end
    end)
end

loadMenu = function()
local gui = Instance.new("ScreenGui")
gui.Name = "SpookyTreeTools"
gui.ResetOnSpawn = false
gui.Parent = playerGui


local main = Instance.new("Frame")
main.Name = "Window"
main.Size = UDim2.fromOffset(390, 382)
main.Position = UDim2.new(0, 30, 0, 120)
main.BackgroundColor3 = Color3.fromRGB(15, 17, 19)
main.BorderSizePixel = 1
main.BorderColor3 = Color3.fromRGB(65, 100, 145)
main.ClipsDescendants = true
main.Parent = gui

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(43, 79, 125)
titleBar.BorderSizePixel = 0
titleBar.Parent = main

local arrow = Instance.new("TextLabel")
arrow.Size = UDim2.fromOffset(32, 34)
arrow.Position = UDim2.fromOffset(4, 0)
arrow.BackgroundTransparency = 1
arrow.Text = "▼"
arrow.TextColor3 = Color3.fromRGB(225, 235, 245)
arrow.TextSize = 17
arrow.Font = Enum.Font.Arial
arrow.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -75, 1, 0)
title.Position = UDim2.fromOffset(38, 0)
title.BackgroundTransparency = 1
title.Text = "Spooky Tools"
title.TextColor3 = Color3.fromRGB(225, 235, 245)
title.TextSize = 17
title.Font = Enum.Font.Arial
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -38, 0, 0)
close.BackgroundTransparency = 1
close.Text = "×"
close.TextColor3 = Color3.fromRGB(225, 235, 245)
close.TextSize = 30
close.Font = Enum.Font.Arial
close.AutoButtonColor = false
close.Parent = titleBar

local flyEnabled = false
local flyButton = nil
local flyVelocity = nil
local flyGyro = nil
local flyConnection = nil
local requestedWalkSpeed = nil
local originalWalkSpeeds = {}
local originalAutoRotate = {}
local characterAddedConnection = nil

local function stopFlying()
    flyEnabled = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    if flyVelocity then
        flyVelocity:Destroy()
        flyVelocity = nil
    end

    if flyGyro then
        flyGyro:Destroy()
        flyGyro = nil
    end

    for humanoid, wasAutoRotateEnabled in pairs(originalAutoRotate) do
        if humanoid.Parent then
            humanoid.AutoRotate = wasAutoRotateEnabled
        end
        originalAutoRotate[humanoid] = nil
    end

    if flyButton then
        flyButton.Text = "Fly: OFF"
    end
end

close.MouseButton1Click:Connect(function()
    stopFlying()
    if characterAddedConnection then
        characterAddedConnection:Disconnect()
        characterAddedConnection = nil
    end
    for humanoid, originalSpeed in pairs(originalWalkSpeeds) do
        if humanoid.Parent then
            humanoid.WalkSpeed = originalSpeed
        end
    end
    gui:Destroy()
end)

local dragging = false
local dragStart
local startPosition

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

local highlightedTrees = {}
local knownTreeClasses = {}
local selectedTree = nil
local treeFoundNotified = false

local function notifyTreeFound(treeType)
    if treeFoundNotified then
        return
    end

    treeFoundNotified = true

    task.spawn(function()
        for attempt = 1, 10 do
            local success, err = pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "Spooky Tree Found!",
                    Text = "A " .. treeType .. " tree is in this server.",
                    Duration = 5
                })
            end)

            if success then
                return
            end

            if attempt == 10 then
                warn("Spooky Tree Tools: Could not show tree notification: "
                    .. tostring(err))
                return
            end

            task.wait(0.5)
        end
    end)
end

local function isPlankTarget(target)

    local current = target

    while current and current ~= workspace do
        if string.find(string.lower(current.Name), "plank", 1, true) then
            return true
        end

        current = current.Parent
    end

    for _, descendant in ipairs(target:GetDescendants()) do
        if string.find(string.lower(descendant.Name), "plank", 1, true) then
            return true
        end
    end

    return false
end

local function isPlayerOwnerName(ownerName)
    local normalizedName = string.lower(string.match(ownerName, "^%s*(.-)%s*$") or "")
    if normalizedName == "" then
        return true
    end

    for _, candidate in ipairs(Players:GetPlayers()) do
        if string.lower(candidate.Name) == normalizedName
            or string.lower(candidate.DisplayName) == normalizedName then
            return true
        end
    end

    return false
end

local function ownerValueIsNonPlayer(owner)
    if not owner:IsA("ValueBase") then
        return false
    end

    local value = owner.Value
    if value == nil then
        return false
    end

    if typeof(value) == "Instance" then
        if value:IsA("Player") or Players:GetPlayerFromCharacter(value) then
            return false
        end

        return not isPlayerOwnerName(value.Name)
    end

    return not isPlayerOwnerName(tostring(value))
end

local function hasNonPlayerOwner(target)
    local current = target
    while current and current ~= workspace do
        local owner = current:FindFirstChild("Owner")
        if owner and ownerValueIsNonPlayer(owner) then
            return true
        end
        current = current.Parent
    end

    local workspaceOwner = workspace:FindFirstChild("Owner")
    if workspaceOwner and ownerValueIsNonPlayer(workspaceOwner) then
        return true
    end

    return false
end

local function isEligibleTreeTarget(target)
    return not isPlankTarget(target) and not hasNonPlayerOwner(target)
end

local function hasSpookyTree()
    for treeClass, target in pairs(highlightedTrees) do
        if treeClass.Parent and target and target.Parent then
            local value = string.lower(treeClass.Value)
            if (value == "spooky" or value == "spookyneon")
                and not hasNonPlayerOwner(target) then
                return true, value
            end
        end
    end

    return false
end

local function addHighlight(treeClass)

    if not treeClass:IsA("StringValue") then
        return
    end

    if treeClass.Name ~= "TreeClass" then
        return
    end

    knownTreeClasses[treeClass] = true

    local value = string.lower(treeClass.Value)

    if value ~= "spooky" and value ~= "spookyneon" then
        return
    end

    local target = treeClass:FindFirstAncestorOfClass("Model")
        or treeClass.Parent

    if not target then
        return
    end

    if not isEligibleTreeTarget(target) then
        local existingHighlight = target:FindFirstChild(HIGHLIGHT_NAME)
        if existingHighlight then
            existingHighlight:Destroy()
        end

        highlightedTrees[treeClass] = nil
        if selectedTree == target then
            selectedTree = nil
        end

        return
    end

    local highlight = target:FindFirstChild(HIGHLIGHT_NAME)

    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = HIGHLIGHT_NAME
        highlight.Parent = target
    end

    highlight.Adornee = target
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    if value == "spookyneon" then
        highlight.FillColor = Color3.fromRGB(0, 255, 255)
    else
        highlight.FillColor = Color3.fromRGB(255, 120, 40)
    end

    highlight.OutlineColor = Color3.new(1, 1, 1)

    highlightedTrees[treeClass] = target
    notifyTreeFound(value == "spookyneon" and "Spooky Neon" or "spooky")
end

local watchedOwners = {}
local refreshQueued = false

local function refreshTreeHighlights()
    refreshQueued = false
    for treeClass in pairs(knownTreeClasses) do
        if treeClass.Parent then
            addHighlight(treeClass)
        else
            knownTreeClasses[treeClass] = nil
            highlightedTrees[treeClass] = nil
        end
    end
end

local function scheduleTreeHighlightRefresh()
    if refreshQueued then
        return
    end

    refreshQueued = true
    task.delay(0.1, refreshTreeHighlights)
end

local function watchOwner(owner)
    if watchedOwners[owner] or not owner:IsA("ValueBase") then
        return
    end

    watchedOwners[owner] = owner:GetPropertyChangedSignal("Value"):Connect(
        scheduleTreeHighlightRefresh
    )
end

for _, instance in ipairs(workspace:GetDescendants()) do
    if instance.Name == "Owner" then
        watchOwner(instance)
    end
    if instance.Name == "TreeClass" then
        addHighlight(instance)
    end
end

workspace.DescendantAdded:Connect(function(instance)
    if instance.Name == "TreeClass" then
        task.wait()
        addHighlight(instance)
    elseif string.find(string.lower(instance.Name), "plank", 1, true) then
        for treeClass, target in pairs(highlightedTrees) do
            if target and target.Parent and not isEligibleTreeTarget(target) then
                local highlight = target:FindFirstChild(HIGHLIGHT_NAME)
                if highlight then
                    highlight:Destroy()
                end

                highlightedTrees[treeClass] = nil
                if selectedTree == target then
                    selectedTree = nil
                end
            end
        end
    elseif instance.Name == "Owner" then
        watchOwner(instance)
        scheduleTreeHighlightRefresh()
    end
end)

workspace.DescendantRemoving:Connect(function(instance)
    if instance.Name == "TreeClass" then
        knownTreeClasses[instance] = nil
        local target = highlightedTrees[instance]
        highlightedTrees[instance] = nil

        if target then
            local stillHasTrackedTreeClass = false
            for treeClass, otherTarget in pairs(highlightedTrees) do
                if treeClass.Parent and otherTarget == target then
                    stillHasTrackedTreeClass = true
                    break
                end
            end

            if not stillHasTrackedTreeClass then
                local highlight = target:FindFirstChild(HIGHLIGHT_NAME)
                if highlight then
                    highlight:Destroy()
                end
            end
        end
    elseif instance.Name == "Owner" then
        local connection = watchedOwners[instance]
        if connection then
            connection:Disconnect()
            watchedOwners[instance] = nil
        end
    end
end)

local selector = Instance.new("TextButton")
selector.Size = UDim2.fromOffset(300, 38)
selector.Position = UDim2.fromOffset(15, 50)
selector.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
selector.BorderSizePixel = 1
selector.BorderColor3 = Color3.fromRGB(67, 104, 150)
selector.Text = "Select highlighted tree..."
selector.TextColor3 = Color3.fromRGB(225, 235, 245)
selector.TextSize = 16
selector.Font = Enum.Font.Arial
selector.TextXAlignment = Enum.TextXAlignment.Left
selector.AutoButtonColor = false
selector.Parent = main

local selectorPadding = Instance.new("UIPadding")
selectorPadding.PaddingLeft = UDim.new(0, 10)
selectorPadding.Parent = selector

local selectorArrow = Instance.new("TextLabel")
selectorArrow.Size = UDim2.fromOffset(25, 38)
selectorArrow.Position = UDim2.new(1, -30, 0, 0)
selectorArrow.BackgroundTransparency = 1
selectorArrow.Text = "▼"
selectorArrow.TextColor3 = Color3.fromRGB(220, 230, 240)
selectorArrow.TextSize = 13
selectorArrow.Font = Enum.Font.Arial
selectorArrow.Parent = selector

local treeList = Instance.new("ScrollingFrame")
treeList.Size = UDim2.fromOffset(300, 100)
treeList.Position = UDim2.fromOffset(15, 91)
treeList.BackgroundColor3 = Color3.fromRGB(18, 20, 22)
treeList.BorderSizePixel = 1
treeList.BorderColor3 = Color3.fromRGB(60, 92, 130)
treeList.ScrollBarThickness = 5
treeList.ScrollBarImageColor3 = Color3.fromRGB(65, 105, 150)
treeList.CanvasSize = UDim2.new(0, 0, 0, 0)
treeList.Visible = false
treeList.ZIndex = 10
treeList.Parent = main

local treeLayout = Instance.new("UIListLayout")
treeLayout.Padding = UDim.new(0, 2)
treeLayout.Parent = treeList

local treePadding = Instance.new("UIPadding")
treePadding.PaddingTop = UDim.new(0, 3)
treePadding.PaddingLeft = UDim.new(0, 3)
treePadding.PaddingRight = UDim.new(0, 3)
treePadding.Parent = treeList

local function getTreePosition(target)

    if target:IsA("Model") then
        return target:GetPivot().Position
    end

    if target:IsA("BasePart") then
        return target.Position
    end

    return nil
end

local function refreshTreeList()

    for _, child in ipairs(treeList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local trees = {}

    for treeClass, target in pairs(highlightedTrees) do

        if treeClass.Parent and target and target.Parent then
            if not isEligibleTreeTarget(target) then
                local highlight = target:FindFirstChild(HIGHLIGHT_NAME)
                if highlight then
                    highlight:Destroy()
                end

                highlightedTrees[treeClass] = nil
                if selectedTree == target then
                    selectedTree = nil
                end
            else
                table.insert(trees, {
                    treeClass = treeClass,
                    target = target
                })
            end
        end
    end

    table.sort(trees, function(a, b)
        return a.treeClass:GetFullName() <
            b.treeClass:GetFullName()
    end)

    for index, data in ipairs(trees) do

        local position = getTreePosition(data.target)

        local value = string.lower(data.treeClass.Value)

        local text

        if position then
            text = string.format(
                "%d. %s  [%d, %d, %d]",
                index,
                value,
                math.floor(position.X),
                math.floor(position.Y),
                math.floor(position.Z)
            )
        else
            text = index .. ". " .. value
        end

        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -5, 0, 29)
        button.BackgroundColor3 = Color3.fromRGB(38, 66, 101)
        button.BorderSizePixel = 1
        button.BorderColor3 = Color3.fromRGB(55, 85, 120)
        button.Text = text
        button.TextColor3 = Color3.fromRGB(220, 230, 240)
        button.TextSize = 13
        button.Font = Enum.Font.Arial
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.AutoButtonColor = false
        button.ZIndex = 11
        button.Parent = treeList

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 7)
        padding.Parent = button

        button.MouseButton1Click:Connect(function()

            if not isEligibleTreeTarget(data.target) then
                selectedTree = nil
                selector.Text = "Select highlighted tree..."
                refreshTreeList()
                return
            end

            selectedTree = data.target

            selector.Text = text
            treeList.Visible = false

        end)
    end

    treeList.CanvasSize = UDim2.fromOffset(
        0,
        treeLayout.AbsoluteContentSize.Y + 8
    )
end

selector.MouseButton1Click:Connect(function()

    refreshTreeList()

    treeList.Visible = not treeList.Visible

end)

local teleportButton = Instance.new("TextButton")
teleportButton.Size = UDim2.fromOffset(300, 38)
teleportButton.Position = UDim2.fromOffset(15, 143)
teleportButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
teleportButton.BorderSizePixel = 1
teleportButton.BorderColor3 = Color3.fromRGB(67, 104, 150)
teleportButton.Text = "Teleport to selected tree"
teleportButton.TextColor3 = Color3.fromRGB(225, 235, 245)
teleportButton.TextSize = 16
teleportButton.Font = Enum.Font.Arial
teleportButton.AutoButtonColor = false
teleportButton.Parent = main

teleportButton.MouseButton1Click:Connect(function()

    if not selectedTree or not selectedTree.Parent
        or not isEligibleTreeTarget(selectedTree) then
        selectedTree = nil
        selector.Text = "Select a highlighted tree..."
        return
    end

    local character = player.Character

    if not character then
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")

    if not root then
        return
    end

    local position = getTreePosition(selectedTree)

    if position then
        root.CFrame = CFrame.new(
            position + Vector3.new(0, 5, 0)
        )
    end

end)

flyButton = Instance.new("TextButton")
flyButton.Size = UDim2.fromOffset(300, 38)
flyButton.Position = UDim2.fromOffset(15, 190)
flyButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
flyButton.BorderSizePixel = 1
flyButton.BorderColor3 = Color3.fromRGB(67, 104, 150)
flyButton.Text = "Fly: OFF"
flyButton.TextColor3 = Color3.fromRGB(225, 235, 245)
flyButton.TextSize = 16
flyButton.Font = Enum.Font.Arial
flyButton.AutoButtonColor = false
flyButton.Parent = main

local walkSpeedInput = Instance.new("TextBox")
walkSpeedInput.Size = UDim2.fromOffset(190, 38)
walkSpeedInput.Position = UDim2.fromOffset(15, 237)
walkSpeedInput.BackgroundColor3 = Color3.fromRGB(25, 34, 45)
walkSpeedInput.BorderSizePixel = 1
walkSpeedInput.BorderColor3 = Color3.fromRGB(67, 104, 150)
walkSpeedInput.Text = "16"
walkSpeedInput.PlaceholderText = "WalkSpeed (1-200)"
walkSpeedInput.TextColor3 = Color3.fromRGB(225, 235, 245)
walkSpeedInput.PlaceholderColor3 = Color3.fromRGB(150, 165, 180)
walkSpeedInput.TextSize = 15
walkSpeedInput.Font = Enum.Font.Arial
walkSpeedInput.ClearTextOnFocus = false
walkSpeedInput.Parent = main

local setWalkSpeedButton = Instance.new("TextButton")
setWalkSpeedButton.Size = UDim2.fromOffset(103, 38)
setWalkSpeedButton.Position = UDim2.fromOffset(212, 237)
setWalkSpeedButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
setWalkSpeedButton.BorderSizePixel = 1
setWalkSpeedButton.BorderColor3 = Color3.fromRGB(67, 104, 150)
setWalkSpeedButton.Text = "Set Speed"
setWalkSpeedButton.TextColor3 = Color3.fromRGB(225, 235, 245)
setWalkSpeedButton.TextSize = 15
setWalkSpeedButton.Font = Enum.Font.Arial
setWalkSpeedButton.AutoButtonColor = false
setWalkSpeedButton.Parent = main

local function applyWalkSpeed()
    local speed = tonumber(walkSpeedInput.Text)
    if not speed or speed < 1 or speed > 200 then
        walkSpeedInput.Text = ""
        walkSpeedInput.PlaceholderText = "Enter 1-200"
        return
    end

    requestedWalkSpeed = speed
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        if originalWalkSpeeds[humanoid] == nil then
            originalWalkSpeeds[humanoid] = humanoid.WalkSpeed
        end
        humanoid.WalkSpeed = speed
    end

    walkSpeedInput.Text = tostring(speed)
    walkSpeedInput.PlaceholderText = "WalkSpeed (1-200)"
end

local function attachFlyMovers(root)
    if flyVelocity then
        flyVelocity:Destroy()
    end
    if flyGyro then
        flyGyro:Destroy()
    end

    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.MaxForce = Vector3.new(1000000, 1000000, 1000000)
    flyVelocity.P = 10000
    flyVelocity.Velocity = Vector3.zero
    flyVelocity.Parent = root

    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(1000000, 1000000, 1000000)
    flyGyro.P = 9000
    flyGyro.D = 500
    flyGyro.Parent = root

    local character = root:FindFirstAncestorOfClass("Model")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and originalAutoRotate[humanoid] == nil then
        originalAutoRotate[humanoid] = humanoid.AutoRotate
        humanoid.AutoRotate = false
    end
end

local function startFlying()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        flyButton.Text = "Character not ready"
        task.delay(2, function()
            if flyButton.Parent and flyButton.Text == "Character not ready" then
                flyButton.Text = "Fly: OFF"
            end
        end)
        return
    end

    flyEnabled = true
    flyButton.Text = "Fly: ON"
    attachFlyMovers(root)

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flyEnabled or not flyButton.Parent then
            stopFlying()
            return
        end

        local currentCharacter = player.Character
        local currentRoot = currentCharacter
            and currentCharacter:FindFirstChild("HumanoidRootPart")
        if not currentRoot then
            return
        end

        if not flyVelocity or flyVelocity.Parent ~= currentRoot then
            attachFlyMovers(currentRoot)
        end

        local camera = workspace.CurrentCamera
        if not camera then
            flyVelocity.Velocity = Vector3.zero
            return
        end

        local direction = Vector3.zero
        if UserInputService:GetFocusedTextBox() == nil then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                direction += camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                direction -= camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                direction += camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                direction -= camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                direction += Vector3.yAxis
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                direction -= Vector3.yAxis
            end
        end

        if direction.Magnitude > 0 then
            direction = direction.Unit * 60
        end

        flyVelocity.Velocity = direction
        local look = camera.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        if flatLook.Magnitude > 0 then
            flyGyro.CFrame = CFrame.lookAt(
                currentRoot.Position,
                currentRoot.Position + flatLook
            )
        end
    end)
end

flyButton.MouseButton1Click:Connect(function()
    if flyEnabled then
        stopFlying()
    else
        startFlying()
    end
end)

setWalkSpeedButton.MouseButton1Click:Connect(applyWalkSpeed)
walkSpeedInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        applyWalkSpeed()
    end
end)

characterAddedConnection = player.CharacterAdded:Connect(function(character)
    if requestedWalkSpeed then
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid and gui.Parent then
            originalWalkSpeeds[humanoid] = humanoid.WalkSpeed
            humanoid.WalkSpeed = requestedWalkSpeed
        end
    end

    if flyEnabled then
        local root = character:WaitForChild("HumanoidRootPart", 5)
        if root and flyEnabled and gui.Parent then
            attachFlyMovers(root)
        end
    end
end)


local serverHop = Instance.new("TextButton")
serverHop.Size = UDim2.fromOffset(300, 38)
serverHop.Position = UDim2.fromOffset(15, 284)
serverHop.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
serverHop.BorderSizePixel = 1
serverHop.BorderColor3 = Color3.fromRGB(67, 104, 150)
serverHop.Text = "Server Hop"
serverHop.TextColor3 = Color3.fromRGB(225, 235, 245)
serverHop.TextSize = 16
serverHop.Font = Enum.Font.Arial
serverHop.AutoButtonColor = false
serverHop.Parent = main

local hopping = false
local queueing = false
local HOP_RETRY_DELAY = 5
local treeSearchButton = Instance.new("TextButton")
treeSearchButton.Size = UDim2.fromOffset(300, 38)
treeSearchButton.Position = UDim2.fromOffset(15, 331)
treeSearchButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
treeSearchButton.BorderSizePixel = 1
treeSearchButton.BorderColor3 = Color3.fromRGB(67, 104, 150)
treeSearchButton.Text = searchingForTree and "Find Spooky Tree: ON"
    or "Find Spooky Tree: OFF"
treeSearchButton.TextColor3 = Color3.fromRGB(225, 235, 245)
treeSearchButton.TextSize = 16
treeSearchButton.Font = Enum.Font.Arial
treeSearchButton.AutoButtonColor = false
treeSearchButton.Parent = main

local function queueScriptForTeleport(continueTreeSearch)

    local queuedSource = "loadstring(game:HttpGet("
        .. HttpService:JSONEncode(SCRIPT_URL)
        .. "))()"

    queuedSource = "if type(getgenv) == 'function' then "
        .. "getgenv().SpookyTreeAuthorized = true end; "
        .. queuedSource

    if continueTreeSearch then
        queuedSource = "getgenv().SpookyTreeAutoSearch = true; "
            .. queuedSource
    end

    local attempt = 0
    while serverHop.Parent do
        attempt = attempt + 1

        local success, result = pcall(function()
            if SCRIPT_URL == "" or SCRIPT_URL == "PASTE_RAW_SCRIPT_URL_HERE" then
                error("Set SCRIPT_URL to the hosted raw script URL.")
            end

            if type(queue_on_teleport) ~= "function" then
                error("Potassium queue_on_teleport is unavailable.")
            end

            return queue_on_teleport(queuedSource)
        end)

        if success and result ~= false then
            return true
        end

        local err = success and "queue_on_teleport returned false"
            or tostring(result)
        serverHop.Text = "Queue retry " .. attempt .. "..."
        warn("Spooky Tree Tools: Queue attempt " .. attempt .. " failed: " .. err)
        task.wait(1)
    end

    return false, "Queue cancelled because the UI was closed."
end

local function waitForPlayerReady(continueTreeSearch)
    while serverHop.Parent do
        if continueTreeSearch and not searchingForTree then
            return false
        end

        local character = player.Character
        if not character then
            serverHop.Text = "Waiting for character..."
            task.wait(0.25)
        else
            serverHop.Text = "Waiting for character..."
            local humanoid = character:WaitForChild("Humanoid", 2)
            local root = character:WaitForChild("HumanoidRootPart", 2)
            if humanoid and root and character == player.Character
                and humanoid.Health > 0 then
                task.wait(2)
                return true
            end
            task.wait(0.5)
        end
    end

    return false
end

local function stopTreeSearch(found, treeType)
    searchingForTree = false
    writeAutoSearchFlag(false)
    treeSearchButton.Text = "Find Spooky Tree: OFF"
    if found then
        serverHop.Text = "Spooky tree found!"
        notifyTreeFound(treeType == "spookyneon" and "Spooky Neon" or "spooky")
    end
end

local function beginServerHop()

    if hopping or queueing then
        return
    end

    queueing = true
    if not waitForPlayerReady(searchingForTree) then
        queueing = false
        return
    end

    local queued, queueError = queueScriptForTeleport(searchingForTree)
    queueing = false

    if not queued then
        if serverHop.Parent then
            serverHop.Text = "Server Hop"
        end
        warn("Spooky Tree Tools: " .. queueError)
        return
    end

    hopping = true
    serverHop.Text = "Finding server..."

    local placeId = game.PlaceId
    local currentJobId = game.JobId
    local attemptedServers = {
        [currentJobId] = true
    }
    local cursor = nil

    while hopping and serverHop.Parent do
        if searchingForTree then
            local found, treeType = hasSpookyTree()
            if found then
                hopping = false
                stopTreeSearch(true, treeType)
                break
            end
        end

        local serversUrl =
            "https://games.roblox.com/v1/games/"
            .. placeId
            .. "/servers/Public?sortOrder=Asc&limit=100"

        if cursor then
            serversUrl = serversUrl
                .. "&cursor="
                .. HttpService:UrlEncode(cursor)
        end

        local success, result = pcall(function()
            return game:HttpGet(serversUrl)
        end)

        if not success then
            serverHop.Text = "Search failed; retrying..."
            task.wait(2)
        else
            local decodeSuccess, data = pcall(function()
                return HttpService:JSONDecode(result)
            end)

            if not decodeSuccess or type(data) ~= "table"
                or type(data.data) ~= "table" then
                serverHop.Text = "Invalid server list; retrying..."
                local responseSummary = tostring(result)
                warn(
                    "Spooky Tree Tools: Server API returned an invalid list: "
                    .. string.sub(responseSummary, 1, 300)
                )
                task.wait(2)
            else
                cursor = data.nextPageCursor
                local attemptedServer = false

                for _, server in ipairs(data.data) do
                    if not hopping then
                        break
                    end

                    if type(server) == "table"
                        and type(server.id) == "string"
                        and type(server.playing) == "number"
                        and type(server.maxPlayers) == "number"
                        and server.id ~= currentJobId
                        and server.playing < server.maxPlayers
                        and not attemptedServers[server.id] then
                        attemptedServer = true
                        attemptedServers[server.id] = true
                        serverHop.Text = "Trying another server..."

                        local failureRaised = false
                        local failureConnection =
                            TeleportService.TeleportInitFailed:Connect(
                                function(failedPlayer, _, _, failedPlaceId)
                                    if failedPlayer == player
                                        and failedPlaceId == placeId then
                                        failureRaised = true
                                    end
                                end
                            )

                        local teleportSuccess, teleportError = pcall(function()
                            TeleportService:TeleportToPlaceInstance(
                                placeId,
                                server.id,
                                player
                            )
                        end)

                        if teleportSuccess then
                            local startedAt = os.clock()
                            repeat
                                if searchingForTree then
                                    local found, treeType = hasSpookyTree()
                                    if found then
                                        hopping = false
                                        stopTreeSearch(true, treeType)
                                        break
                                    end
                                end

                                task.wait(0.25)
                            until failureRaised or not hopping
                                or not serverHop.Parent
                                or os.clock() - startedAt >= 15
                        end
                        failureConnection:Disconnect()

                        if failureRaised then
                            serverHop.Text = "Teleport failed; trying another..."
                            task.wait(HOP_RETRY_DELAY)
                        elseif not teleportSuccess then
                            serverHop.Text = "Teleport failed; waiting before retry..."
                            warn(
                                "Spooky Tree Tools: Teleport to server "
                                .. server.id
                                .. " failed: "
                                .. tostring(teleportError)
                            )
                            task.wait(HOP_RETRY_DELAY)
                        elseif hopping and serverHop.Parent then
                            serverHop.Text = "Teleport timed out; waiting before retry..."
                            task.wait(HOP_RETRY_DELAY)
                        end
                    end
                end

                if not attemptedServer then
                    if cursor then
                        serverHop.Text = "Checking more servers..."
                    else
                        serverHop.Text = "No working server; searching again..."
                        task.wait(3)
                    end
                end
            end
        end
    end

    hopping = false
end

serverHop.MouseButton1Click:Connect(beginServerHop)

treeSearchButton.MouseButton1Click:Connect(function()
    if searchingForTree then
        searchingForTree = false
        writeAutoSearchFlag(false)
        treeSearchButton.Text = "Find Spooky Tree: OFF"
        if hopping then
            hopping = false
        end
        serverHop.Text = "Server Hop"
        return
    end

    searchingForTree = true
    if not writeAutoSearchFlag(true) then
        searchingForTree = false
        treeSearchButton.Text = "Find Spooky Tree: OFF"
        warn("Spooky Tree Tools: Persistent search requires getgenv support.")
        return
    end

    treeSearchButton.Text = "Find Spooky Tree: ON"
    local found, treeType = hasSpookyTree()
    if found then
        stopTreeSearch(true, treeType)
    else
        task.spawn(beginServerHop)
    end
end)

if searchingForTree then
    local found, treeType = hasSpookyTree()
    if found then
        stopTreeSearch(true, treeType)
    else
        task.defer(beginServerHop)
    end
end


local function hover(button)

    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(51, 87, 130)
    end)

    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
    end)

end

hover(selector)
hover(teleportButton)
hover(flyButton)
hover(setWalkSpeedButton)
hover(serverHop)
hover(treeSearchButton)
end

if hasSavedAuthorization() then
    loadMenu()
else
    showKeyScreen()
end
