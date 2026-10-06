--URL SUPPORT :PRAY:
if game.PlaceId ~= 13822889 then
    return
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")

local DISCORD_INVITE_URL = "https://discord.gg/65VCr7eCVk"
local showWebhookMenu
local resendWebhookForFoundTree
local webhookAlertSent = false
local webhookAlertInFlight = false
local WEBHOOK_FILE_PATH = "SpookyTreeTools.webhook"

local function createDiscordButton(parent, position, width)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(width or 310, 38)
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
    button.BorderSizePixel = 1
    button.BorderColor3 = Color3.fromRGB(67, 104, 150)
    button.Text = "Join Discord"
    button.TextColor3 = Color3.fromRGB(225, 235, 245)
    button.TextSize = 16
    button.Font = Enum.Font.Arial
    button.AutoButtonColor = false
    button.Parent = parent

    button.MouseButton1Click:Connect(function()
        local success, err = pcall(function()
            GuiService:OpenBrowserWindow(DISCORD_INVITE_URL)
        end)

        if not success then
            warn("Spooky Tree Tools: Could not open Discord invite "
                .. DISCORD_INVITE_URL
                .. ": "
                .. tostring(err))
        end
    end)

    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(51, 87, 130)
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
    end)

    return button
end

local function createWebhookButton(parent, position, width)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(width, 38)
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
    button.BorderSizePixel = 1
    button.BorderColor3 = Color3.fromRGB(67, 104, 150)
    button.Text = "Webhook"
    button.TextColor3 = Color3.fromRGB(225, 235, 245)
    button.TextSize = 16
    button.Font = Enum.Font.Arial
    button.AutoButtonColor = false
    button.Parent = parent

    button.MouseButton1Click:Connect(function()
        if showWebhookMenu then
            showWebhookMenu()
        end
    end)

    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(51, 87, 130)
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
    end)

    return button
end

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local function getExecutorEnvironment()
    if type(getgenv) ~= "function" then
        return nil
    end

    local success, environment = pcall(getgenv)
    if success and type(environment) == "table" then
        return environment
    end

    return nil
end

    local function isDiscordWebhookUrl(url)
        if type(url) ~= "string" then
            return false
        end

        url = string.match(url, "^%s*(.-)%s*$") or ""
        return string.match(
                url,
                "^https://discord%.com/api/webhooks/%d+/[%w_%-%.]+$"
            ) ~= nil
            or string.match(
                url,
                "^https://discordapp%.com/api/webhooks/%d+/[%w_%-%.]+$"
            ) ~= nil
    end

    local function findRequestFunction()
        local environment = getExecutorEnvironment()
        if environment then
            if type(environment.request) == "function" then
                return environment.request
            end
            if type(environment.http_request) == "function" then
                return environment.http_request
            end
            if type(environment.syn) == "table"
                and type(environment.syn.request) == "function" then
                return environment.syn.request
            end
        end

        if type(request) == "function" then
            return request
        end
        if type(http_request) == "function" then
            return http_request
        end
        if type(syn) == "table" and type(syn.request) == "function" then
            return syn.request
        end
        if type(http) == "table" and type(http.request) == "function" then
            return http.request
        end

        return nil
    end

    local webhookUrl
    local function readSavedWebhook()
        local environment = getExecutorEnvironment()
        if environment and isDiscordWebhookUrl(environment.SpookyTreeWebhookUrl) then
            return environment.SpookyTreeWebhookUrl
        end

        if type(readfile) == "function" then
            local success, savedUrl = pcall(readfile, WEBHOOK_FILE_PATH)
            if success and savedUrl ~= "" then
                if isDiscordWebhookUrl(savedUrl) then
                    return string.match(savedUrl, "^%s*(.-)%s*$")
                end
                warn("Spooky Tree Tools: Saved webhook URL is invalid; "
                    .. "re-enter it from the webhook menu.")
            end
        end

        return nil
    end

    webhookUrl = readSavedWebhook()

    local function saveWebhookUrl(url)
        url = string.match(url, "^%s*(.-)%s*$") or ""
        if not isDiscordWebhookUrl(url) then
            return false, "Enter a valid Discord webhook URL."
        end

        webhookUrl = url
        local environment = getExecutorEnvironment()
        if environment then
            environment.SpookyTreeWebhookUrl = url
        end

        if resendWebhookForFoundTree then
            resendWebhookForFoundTree()
        end

        if type(writefile) == "function" then
            local success, err = pcall(writefile, WEBHOOK_FILE_PATH, url)
            if success then
                return true, "Webhook saved on this executor."
            end
            warn("Spooky Tree Tools: Could not save webhook URL: " .. tostring(err))
            return true, "Webhook set for this session only; persistent save failed."
        end

        return true, "Webhook set for this session only; file saving is unavailable."
    end

    local function sendWebhookAlert(treeType, target)
        if not webhookUrl then
            return
        end
        if webhookAlertSent or webhookAlertInFlight then
            return
        end

        local requestFunction = findRequestFunction()
        if not requestFunction then
            warn("Spooky Tree Tools: Webhook is configured, but this executor "
                .. "does not expose a supported HTTP request function.")
            return
        end
        webhookAlertInFlight = true

        local position
        if target and target:IsA("Model") then
            local success, pivot = pcall(function()
                return target:GetPivot()
            end)
            if success then
                position = pivot.Position
            end
        elseif target and target:IsA("BasePart") then
            position = target.Position
        end
        if not position and target then
            local part = target:FindFirstChildWhichIsA("BasePart", true)
            if part then
                position = part.Position
            end
        end

        local x = position and string.format("%.2f", position.X) or "Unavailable"
        local y = position and string.format("%.2f", position.Y) or "Unavailable"
        local z = position and string.format("%.2f", position.Z) or "Unavailable"
        local isNeon = treeType == "Spooky Neon"
        local joinUrl = "https://www.roblox.com/games/start?placeId="
            .. tostring(game.PlaceId)
            .. "&gameInstanceId="
            .. HttpService:UrlEncode(game.JobId)
        local body = HttpService:JSONEncode({
            content = string.format(
                "@everyone **%s found!** Coordinates: X %s, Y %s, Z %s. "
                    .. "Join this server: %s",
                treeType,
                x,
                y,
                z,
                joinUrl
            ),
            allowed_mentions = { parse = { "everyone" } },
            username = "Spooky Tree Finder",
            embeds = {
                {
                    title = isNeon and "Spooky Neon Found!" or "Spooky Tree Found!",
                    description = "A **" .. treeType .. "** tree was found.",
                    color = isNeon and 65535 or 16742440,
                    url = joinUrl,
                    fields = {
                        {
                            name = "X",
                            value = x,
                            inline = true
                        },
                        {
                            name = "Y",
                            value = y,
                            inline = true
                        },
                        {
                            name = "Z",
                            value = z,
                            inline = true
                        },
                        {
                            name = "Join Server",
                            value = "[Click here to join](" .. joinUrl .. ")",
                            inline = false
                        }
                    },
                    footer = { text = "Spooky Tree Tools" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
            }
        })

        task.spawn(function()
            for attempt = 1, 3 do
                local options = {
                    Url = webhookUrl,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = body,
                    Timeout = 10
                }
                local success, response = pcall(requestFunction, options)
                if not success then
                    success, response = pcall(requestFunction, {
                        url = options.Url,
                        method = options.Method,
                        headers = options.Headers,
                        body = options.Body,
                        timeout = options.Timeout
                    })
                end
                if success then
                    local statusCode = type(response) == "table"
                        and (response.StatusCode or response.Status)
                    statusCode = tonumber(statusCode)
                        or tonumber(type(statusCode) == "string"
                            and string.match(statusCode, "^%s*(%d+)")
                            or nil)
                    if statusCode == 200 or statusCode == 204
                        or (statusCode == nil and type(response) == "table"
                            and response.Success == true) then
                        webhookAlertSent = true
                        webhookAlertInFlight = false
                        return
                    end
                    if attempt == 3 then
                        warn("Spooky Tree Tools: Webhook request returned HTTP "
                            .. tostring(statusCode or "an unknown status")
                            .. (type(response) == "table"
                                and response.StatusMessage
                                and (": " .. tostring(response.StatusMessage))
                                or "")
                            .. (type(response) == "table"
                                and type(response.Body) == "string"
                                and response.Body ~= ""
                                and (": " .. string.sub(response.Body, 1, 300))
                                or "")
                            .. ".")
                    end
                elseif attempt == 3 then
                    warn("Spooky Tree Tools: Webhook request failed: "
                        .. tostring(response))
                end

                if attempt < 3 then
                    task.wait(attempt * 2)
                end
            end
            webhookAlertInFlight = false
        end)
    end

    showWebhookMenu = function()
        local existing = playerGui:FindFirstChild("SpookyTreeWebhookConfig")
        if existing then
            existing:Destroy()
        end

        local menuGui = Instance.new("ScreenGui")
        menuGui.Name = "SpookyTreeWebhookConfig"
        menuGui.ResetOnSpawn = false
        menuGui.DisplayOrder = 20
        menuGui.Parent = playerGui

        local panel = Instance.new("Frame")
        panel.Size = UDim2.fromOffset(400, 292)
        panel.Position = UDim2.new(0.5, -200, 0.5, -146)
        panel.BackgroundColor3 = Color3.fromRGB(15, 17, 19)
        panel.BorderSizePixel = 1
        panel.BorderColor3 = Color3.fromRGB(65, 100, 145)
        panel.ClipsDescendants = true
        panel.Parent = menuGui

        local titleBar = Instance.new("Frame")
        titleBar.Size = UDim2.new(1, 0, 0, 34)
        titleBar.BackgroundColor3 = Color3.fromRGB(43, 79, 125)
        titleBar.BorderSizePixel = 0
        titleBar.Parent = panel

        local heading = Instance.new("TextLabel")
        heading.Size = UDim2.new(1, -56, 1, 0)
        heading.Position = UDim2.fromOffset(14, 0)
        heading.BackgroundTransparency = 1
        heading.Text = "Webhook Alerts"
        heading.TextColor3 = Color3.fromRGB(225, 235, 245)
        heading.TextSize = 17
        heading.Font = Enum.Font.Arial
        heading.TextXAlignment = Enum.TextXAlignment.Left
        heading.Parent = titleBar

        local closeButton = Instance.new("TextButton")
        closeButton.Size = UDim2.fromOffset(34, 34)
        closeButton.Position = UDim2.new(1, -38, 0, 0)
        closeButton.BackgroundTransparency = 1
        closeButton.Text = "×"
        closeButton.TextColor3 = Color3.fromRGB(225, 235, 245)
        closeButton.TextSize = 30
        closeButton.Font = Enum.Font.Arial
        closeButton.AutoButtonColor = false
        closeButton.Parent = titleBar
        closeButton.MouseButton1Click:Connect(function()
            menuGui:Destroy()
        end)

        local dragging = false
        local dragStart
        local startPosition
        titleBar.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = inputObject.Position
                startPosition = panel.Position
            end
        end)
        titleBar.InputEnded:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        local dragConnection = UserInputService.InputChanged:Connect(
            function(inputObject)
                if dragging
                    and inputObject.UserInputType == Enum.UserInputType.MouseMovement then
                    local delta = inputObject.Position - dragStart
                    panel.Position = UDim2.new(
                        startPosition.X.Scale,
                        startPosition.X.Offset + delta.X,
                        startPosition.Y.Scale,
                        startPosition.Y.Offset + delta.Y
                    )
                end
            end
        )
        menuGui.Destroying:Connect(function()
            dragConnection:Disconnect()
        end)

        local hint = Instance.new("TextLabel")
        hint.Size = UDim2.new(1, -28, 0, 48)
        hint.Position = UDim2.fromOffset(14, 46)
        hint.BackgroundTransparency = 1
        hint.Text = "Paste your Discord webhook URL. Alerts ping @everyone once per server and include tree coordinates plus a join link."
        hint.TextColor3 = Color3.fromRGB(175, 190, 205)
        hint.TextSize = 14
        hint.TextWrapped = true
        hint.Font = Enum.Font.Arial
        hint.TextXAlignment = Enum.TextXAlignment.Left
        hint.TextYAlignment = Enum.TextYAlignment.Top
        hint.Parent = panel

        local input = Instance.new("TextBox")
        input.Size = UDim2.new(1, -28, 0, 40)
        input.Position = UDim2.fromOffset(14, 102)
        input.BackgroundColor3 = Color3.fromRGB(25, 34, 45)
        input.BorderSizePixel = 1
        input.BorderColor3 = Color3.fromRGB(67, 104, 150)
        input.PlaceholderText = "https://discord.com/api/webhooks/..."
        input.Text = webhookUrl or ""
        input.ClearTextOnFocus = false
        input.TextXAlignment = Enum.TextXAlignment.Left
        input.TextColor3 = Color3.fromRGB(225, 235, 245)
        input.PlaceholderColor3 = Color3.fromRGB(150, 165, 180)
        input.TextSize = 12
        input.Font = Enum.Font.Arial
        input.Parent = panel

        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, -28, 0, 42)
        status.Position = UDim2.fromOffset(14, 150)
        status.BackgroundTransparency = 1
        status.Text = "Keep your webhook URL private; anyone who has it can post to your channel."
        status.TextColor3 = Color3.fromRGB(220, 190, 120)
        status.TextSize = 13
        status.TextWrapped = true
        status.Font = Enum.Font.Arial
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.TextYAlignment = Enum.TextYAlignment.Center
        status.Parent = panel

        local saveButton = Instance.new("TextButton")
        saveButton.Size = UDim2.fromOffset(180, 38)
        saveButton.Position = UDim2.fromOffset(14, 238)
        saveButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
        saveButton.BorderSizePixel = 1
        saveButton.BorderColor3 = Color3.fromRGB(67, 104, 150)
        saveButton.Text = "Confirm"
        saveButton.TextColor3 = Color3.fromRGB(225, 235, 245)
        saveButton.TextSize = 15
        saveButton.Font = Enum.Font.Arial
        saveButton.Parent = panel

        local cancelButton = Instance.new("TextButton")
        cancelButton.Size = UDim2.fromOffset(180, 38)
        cancelButton.Position = UDim2.fromOffset(206, 238)
        cancelButton.BackgroundColor3 = Color3.fromRGB(54, 59, 66)
        cancelButton.BorderSizePixel = 1
        cancelButton.BorderColor3 = Color3.fromRGB(85, 95, 105)
        cancelButton.Text = "Cancel"
        cancelButton.TextColor3 = Color3.fromRGB(225, 235, 245)
        cancelButton.TextSize = 15
        cancelButton.Font = Enum.Font.Arial
        cancelButton.Parent = panel

        saveButton.MouseButton1Click:Connect(function()
            local saved, message = saveWebhookUrl(input.Text)
            status.Text = message
            if not saved then
                status.TextColor3 = Color3.fromRGB(255, 125, 125)
                return
            end
            menuGui:Destroy()
        end)

        cancelButton.MouseButton1Click:Connect(function()
            menuGui:Destroy()
        end)
    end

local function readAutoSearchMode()
    local environment = getExecutorEnvironment()
    if not environment then
        return nil
    end

    if environment.SpookyTreeAutoSearchMode == "spooky"
        or environment.SpookyTreeAutoSearchMode == "spookyneon" then
        return environment.SpookyTreeAutoSearchMode
    end

    if environment.SpookyTreeAutoSearch == true then
        return "spooky"
    end

    return nil
end

local function writeAutoSearchMode(mode)
    local environment = getExecutorEnvironment()
    if not environment then
        return false
    end

    environment.SpookyTreeAutoSearchMode = mode
    environment.SpookyTreeAutoSearch = mode ~= nil
    return true
end

local treeSearchMode = readAutoSearchMode()
local executorEnvironment = getExecutorEnvironment()
local skipFoundTrees = executorEnvironment ~= nil
    and executorEnvironment.SpookyTreeSkipFoundTrees == true

local function writeSkipFoundTrees(enabled)
    local environment = getExecutorEnvironment()
    if not environment then
        return false
    end

    environment.SpookyTreeSkipFoundTrees = enabled
    skipFoundTrees = enabled
    return true
end

local HIGHLIGHT_NAME = "SpookyTreeHighlight"
local TREE_MARKER_NAME = "SpookyTreeMarker"
local SCRIPT_URL = "https://raw.githubusercontent.com/vlexlyss/spookytool/refs/heads/main/tool.lua"
local EXCLUSIVE_AUDIO_KEY = "SPOOKY-7K4M-9Q2X-1R8P"
local TREE_FOUND_SOUND_ID = "rbxassetid://116841974988859"

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
local authorizedScriptKey
local lastAuthorizationError

local function normalizeScriptKey(value)
    if type(value) ~= "string" then
        return nil
    end

    return string.upper(string.match(value, "^%s*(.-)%s*$") or "")
end

local function getCurrentHardwareId()
    local environment = getExecutorEnvironment()
    local locator = environment
        and (environment.gethwid or environment.get_hwid)
        or gethwid
    if type(locator) ~= "function" then
        return nil, "This executor does not provide an HWID API."
    end

    local success, value = pcall(locator)
    if not success then
        return nil, "Could not read this executor's hardware ID: "
            .. tostring(value)
    end

    if type(value) ~= "string" or value == "" then
        return nil, "The executor returned an empty or invalid hardware ID."
    end

    return value
end

local function encodeAuthorizationRecord(key, hardwareId)
    return HttpService:JSONEncode({
        key = key,
        hardwareId = hardwareId
    })
end

local function parseAuthorizationRecord(data)
    local success, record = pcall(function()
        return HttpService:JSONDecode(data)
    end)
    if success and type(record) == "table" then
        local key = normalizeScriptKey(record.key)
        if VALID_SCRIPT_KEYS[key] and type(record.hardwareId) == "string"
            and record.hardwareId ~= "" then
            return key, record.hardwareId, false
        end
    end

    local legacyKey = normalizeScriptKey(data)
    if VALID_SCRIPT_KEYS[legacyKey] then
        return legacyKey, nil, true
    end

    return nil
end

local function clearSavedAuthorization()
    authorizedScriptKey = nil
    lastAuthorizationError = nil

    local environment = getExecutorEnvironment()
    if environment then
        environment.SpookyTreeSavedKey = nil
        environment.SpookyTreeHardwareId = nil
        environment.SpookyTreeAuthorized = nil
    end

    if type(isfile) == "function" then
        local success, exists = pcall(isfile, KEY_FILE_PATH)
        if success and not exists then
            return true
        end
    elseif type(readfile) == "function" then
        local success, data = pcall(readfile, KEY_FILE_PATH)
        if success and data == "" then
            return true
        end
    end

    if type(writefile) == "function" then
        local success, err = pcall(writefile, KEY_FILE_PATH, "")
        if success then
            return true
        end
        if type(delfile) ~= "function" then
            lastAuthorizationError = "Could not clear the saved key file: "
                .. tostring(err)
            return false, lastAuthorizationError
        end
    end

    if type(delfile) == "function" then
        local success, err = pcall(delfile, KEY_FILE_PATH)
        if success then
            return true
        end
        lastAuthorizationError = "Could not delete the saved key file: "
            .. tostring(err)
        return false, lastAuthorizationError
    end

    if type(readfile) == "function" then
        local success, data = pcall(readfile, KEY_FILE_PATH)
        if success and data ~= "" then
            lastAuthorizationError =
                "This executor cannot clear the persistent key file."
            return false, lastAuthorizationError
        end
    end

    return true
end

local function saveAuthorization(key, hardwareId)
    if not hardwareId then
        local hardwareIdError
        hardwareId, hardwareIdError = getCurrentHardwareId()
        if not hardwareId then
            lastAuthorizationError = "Cannot lock this key: "
                .. tostring(hardwareIdError)
            return false, lastAuthorizationError
        end
    end

    authorizedScriptKey = key
    lastAuthorizationError = nil

    local savedToFile = false
    if type(writefile) == "function" then
        local success, err = pcall(
            writefile,
            KEY_FILE_PATH,
            encodeAuthorizationRecord(key, hardwareId)
        )
        if success then
            savedToFile = true
        else
            warn("Spooky Tree Tools: Could not save key file: " .. tostring(err))
        end
    end

    local environment = getExecutorEnvironment()
    if environment then
        environment.SpookyTreeSavedKey = key
        environment.SpookyTreeHardwareId = hardwareId
        environment.SpookyTreeAuthorized = true
    end

    if not savedToFile then
        warn("Spooky Tree Tools: Key and HWID are saved for this executor "
            .. "session only; persistent saving requires writefile support.")
    end

    return true
end

local function readSavedScriptKey()
    local hardwareId, hardwareIdError = getCurrentHardwareId()
    if not hardwareId then
        lastAuthorizationError = hardwareIdError
        return nil
    end

    if type(readfile) == "function" then
        local success, data = pcall(readfile, KEY_FILE_PATH)
        if success then
            local key, savedHardwareId, isLegacy =
                parseAuthorizationRecord(data)
            if key then
                if isLegacy then
                    saveAuthorization(key, hardwareId)
                    return key
                end
                if savedHardwareId == hardwareId then
                    authorizedScriptKey = key
                    return key
                end
                lastAuthorizationError =
                    "This saved key is locked to a different hardware ID."
                return nil
            end
        end
    end

    local environment = getExecutorEnvironment()
    if environment then
        local key = normalizeScriptKey(environment.SpookyTreeSavedKey)
        local savedHardwareId = environment.SpookyTreeHardwareId
        if VALID_SCRIPT_KEYS[key] and type(savedHardwareId) == "string" then
            if savedHardwareId == hardwareId then
                authorizedScriptKey = key
                return key
            end
            lastAuthorizationError =
                "This saved key is locked to a different hardware ID."
        elseif VALID_SCRIPT_KEYS[key] then
            return saveAuthorization(key, hardwareId) and key or nil
        end
    end

    return nil
end

local function hasSavedAuthorization()
    return readSavedScriptKey() ~= nil
end

local function showKeyScreen()
    local keyGui = Instance.new("ScreenGui")
    keyGui.Name = "SpookyTreeKeyPrompt"
    keyGui.ResetOnSpawn = false
    keyGui.Parent = playerGui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(340, 270)
    panel.Position = UDim2.new(0.5, -170, 0.5, -135)
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
    status.Size = UDim2.new(1, -30, 0, 24)
    status.Position = UDim2.fromOffset(15, 93)
    status.BackgroundTransparency = 1
    status.Text = lastAuthorizationError or ""
    status.TextColor3 = Color3.fromRGB(255, 125, 125)
    status.TextWrapped = true
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

    local resetButton = Instance.new("TextButton")
    resetButton.Size = UDim2.new(1, -30, 0, 34)
    resetButton.Position = UDim2.fromOffset(15, 170)
    resetButton.BackgroundColor3 = Color3.fromRGB(82, 54, 54)
    resetButton.BorderSizePixel = 1
    resetButton.BorderColor3 = Color3.fromRGB(130, 78, 78)
    resetButton.Text = "Reset Local Key + HWID"
    resetButton.TextColor3 = Color3.fromRGB(245, 225, 225)
    resetButton.TextSize = 14
    resetButton.Font = Enum.Font.Arial
    resetButton.AutoButtonColor = true
    resetButton.Parent = panel

    createDiscordButton(panel, UDim2.fromOffset(15, 215), 145)
    createWebhookButton(panel, UDim2.fromOffset(170, 215), 155)

    resetButton.MouseButton1Click:Connect(function()
        local cleared, err = clearSavedAuthorization()
        if not cleared then
            status.Text = err
            warn("Spooky Tree Tools: Could not reset local authorization: "
                .. tostring(err))
            return
        end

        keyInput.Text = ""
        status.Text = "Local key and HWID binding cleared."
        status.TextColor3 = Color3.fromRGB(135, 225, 155)
    end)

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

        local saved, saveError = saveAuthorization(key)
        if not saved then
            status.Text = saveError
            submitting = false
            return
        end
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
main.Size = UDim2.fromOffset(390, 570)
main.Position = UDim2.new(0, 30, 0, 120)
main.BackgroundColor3 = Color3.fromRGB(15, 17, 19)
main.BorderSizePixel = 1
main.BorderColor3 = Color3.fromRGB(65, 100, 145)
main.ClipsDescendants = true
main.Parent = gui

local menuMinimized = false
local MENU_HEIGHT = 570
local treeList

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(43, 79, 125)
titleBar.BorderSizePixel = 0
titleBar.Parent = main

local arrow = Instance.new("TextButton")
arrow.Size = UDim2.fromOffset(32, 34)
arrow.Position = UDim2.fromOffset(4, 0)
arrow.BackgroundTransparency = 1
arrow.Text = "▼"
arrow.TextColor3 = Color3.fromRGB(225, 235, 245)
arrow.TextSize = 17
arrow.Font = Enum.Font.Arial
arrow.AutoButtonColor = false
arrow.Parent = titleBar

arrow.MouseButton1Click:Connect(function()
    menuMinimized = not menuMinimized
    main.Size = UDim2.fromOffset(390, menuMinimized and 34 or MENU_HEIGHT)
    arrow.Text = menuMinimized and "▲" or "▼"

    if menuMinimized then
        treeList.Visible = false
    end
end)

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

local closeCleanup
local closeMenu
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
        flyButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
    end
end

closeMenu = function()
    if closeCleanup then
        closeCleanup()
    end
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
end

close.MouseButton1Click:Connect(closeMenu)

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
local notificationState = getExecutorEnvironment()
local notifiedJobs = notificationState
    and notificationState.SpookyTreeNotifiedJobs
if type(notifiedJobs) ~= "table" then
    notifiedJobs = {}
    if notificationState then
        notificationState.SpookyTreeNotifiedJobs = notifiedJobs
    end
end
local currentJobId = game.JobId
local treeFoundNotified = currentJobId ~= ""
    and notifiedJobs[currentJobId] == true

local function playExclusiveTreeFoundSound()
    if authorizedScriptKey ~= EXCLUSIVE_AUDIO_KEY then
        return
    end

    local sound = Instance.new("Sound")
    sound.SoundId = TREE_FOUND_SOUND_ID
    sound.Volume = 1
    sound.Parent = SoundService
    Debris:AddItem(sound, 15)

    local success, err = pcall(function()
        SoundService:PlayLocalSound(sound)
    end)
    if not success then
        sound:Destroy()
        warn("Spooky Tree Tools: Could not play exclusive tree-found sound: "
            .. tostring(err))
    end
end

local function notifyTreeFound(treeType, target)
    sendWebhookAlert(treeType, target)

    if treeFoundNotified or (currentJobId ~= "" and notifiedJobs[currentJobId]) then
        return
    end

    treeFoundNotified = true
    if currentJobId ~= "" then
        notifiedJobs[currentJobId] = true
    end
    playExclusiveTreeFoundSound()
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

local function removeTreeVisuals(target)
    if not target then
        return
    end

    for _, name in ipairs({ HIGHLIGHT_NAME, TREE_MARKER_NAME }) do
        local visual = target:FindFirstChild(name, true)
        if visual then
            visual:Destroy()
        end
    end
end

local function removeTrackedTree(treeClass, target)
    highlightedTrees[treeClass] = nil
    if selectedTree == target then
        selectedTree = nil
    end

    for _, otherTarget in pairs(highlightedTrees) do
        if otherTarget == target then
            return
        end
    end

    removeTreeVisuals(target)
end

local function updateTreeMarker(target, treeType)
    local adornee
    if target:IsA("BasePart") then
        adornee = target
    elseif target:IsA("Model") then
        adornee = target.PrimaryPart
            or target:FindFirstChildWhichIsA("BasePart", true)
    end

    if not adornee then
        return
    end

    local marker = target:FindFirstChild(TREE_MARKER_NAME, true)
    if not marker then
        marker = Instance.new("BillboardGui")
        marker.Name = TREE_MARKER_NAME
        marker.Size = UDim2.fromOffset(170, 34)
        marker.StudsOffset = Vector3.new(0, 5, 0)
        marker.AlwaysOnTop = true
        marker.LightInfluence = 0
        marker.MaxDistance = 1000

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundColor3 = Color3.fromRGB(15, 17, 19)
        label.BackgroundTransparency = 0.2
        label.BorderSizePixel = 0
        label.Font = Enum.Font.GothamBold
        label.TextSize = 16
        label.TextStrokeTransparency = 0.35
        label.Parent = marker

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = label
    end

    marker.Adornee = adornee
    marker.Parent = adornee

    local label = marker:FindFirstChild("Label")
    if label then
        if treeType == "spookyneon" then
            label.Text = "SPOOKY NEON"
            label.TextColor3 = Color3.fromRGB(0, 255, 255)
        else
            label.Text = "SPOOKY"
            label.TextColor3 = Color3.fromRGB(255, 150, 65)
        end
    end
end

local function hasSpookyTree(searchMode)
    for treeClass, target in pairs(highlightedTrees) do
        if treeClass.Parent and target and target.Parent then
            local value = string.lower(treeClass.Value)
            if (searchMode == nil
                    and (value == "spooky" or value == "spookyneon")
                or searchMode == value)
                and not hasNonPlayerOwner(target) then
                return true, value, target
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
    local target = treeClass:FindFirstAncestorOfClass("Model")
        or treeClass.Parent

    if value ~= "spooky" and value ~= "spookyneon" then
        removeTrackedTree(treeClass, highlightedTrees[treeClass] or target)
        return
    end

    if not target then
        return
    end

    if not isEligibleTreeTarget(target) then
        removeTrackedTree(treeClass, target)
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
    updateTreeMarker(target, value)

    highlightedTrees[treeClass] = target
    notifyTreeFound(
        value == "spookyneon" and "Spooky Neon" or "spooky",
        target
    )
end

resendWebhookForFoundTree = function()
    for treeClass, target in pairs(highlightedTrees) do
        if treeClass.Parent and target and target.Parent
            and isEligibleTreeTarget(target) then
            local value = string.lower(treeClass.Value)
            if value == "spooky" or value == "spookyneon" then
                sendWebhookAlert(
                    value == "spookyneon" and "Spooky Neon" or "spooky",
                    target
                )
                return
            end
        end
    end
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
                removeTrackedTree(treeClass, target)
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
                removeTreeVisuals(target)
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

treeList = Instance.new("ScrollingFrame")
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
                removeTrackedTree(treeClass, target)
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
        flyButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
        task.delay(2, function()
            if flyButton.Parent and flyButton.Text == "Character not ready" then
                flyButton.Text = "Fly: OFF"
            end
        end)
        return
    end

    flyEnabled = true
    flyButton.Text = "Fly: ON"
    flyButton.BackgroundColor3 = Color3.fromRGB(51, 87, 130)
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
local hopIsAutoSearch = false
local hopTaskRunning = false
local beginServerHop
local HOP_RETRY_DELAY = 5
local visitedServersFallback = {}
local treeSearchButton = Instance.new("TextButton")
treeSearchButton.Size = UDim2.fromOffset(300, 38)
treeSearchButton.Position = UDim2.fromOffset(15, 331)
treeSearchButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
treeSearchButton.BorderSizePixel = 1
treeSearchButton.BorderColor3 = Color3.fromRGB(67, 104, 150)
treeSearchButton.Text = treeSearchMode == "spooky" and "Find Spooky Tree: ON"
    or "Find Spooky Tree: OFF"
treeSearchButton.TextColor3 = Color3.fromRGB(225, 235, 245)
treeSearchButton.TextSize = 16
treeSearchButton.Font = Enum.Font.Arial
treeSearchButton.AutoButtonColor = false
treeSearchButton.Parent = main

local neonSearchButton = Instance.new("TextButton")
neonSearchButton.Size = UDim2.fromOffset(300, 38)
neonSearchButton.Position = UDim2.fromOffset(15, 378)
neonSearchButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
neonSearchButton.BorderSizePixel = 1
neonSearchButton.BorderColor3 = Color3.fromRGB(67, 104, 150)
neonSearchButton.Text = treeSearchMode == "spookyneon"
    and "Find Spooky Neon: ON"
    or "Find Spooky Neon: OFF"
neonSearchButton.TextColor3 = Color3.fromRGB(225, 235, 245)
neonSearchButton.TextSize = 16
neonSearchButton.Font = Enum.Font.Arial
neonSearchButton.AutoButtonColor = false
neonSearchButton.Parent = main

local skipTreesButton = Instance.new("TextButton")
skipTreesButton.Size = UDim2.fromOffset(300, 38)
skipTreesButton.Position = UDim2.fromOffset(15, 425)
skipTreesButton.BackgroundColor3 = skipFoundTrees
    and Color3.fromRGB(51, 87, 130)
    or Color3.fromRGB(39, 70, 108)
skipTreesButton.BorderSizePixel = 1
skipTreesButton.BorderColor3 = Color3.fromRGB(67, 104, 150)
skipTreesButton.Text = skipFoundTrees and "Skip Trees: ON" or "Skip Trees: OFF"
skipTreesButton.TextColor3 = Color3.fromRGB(225, 235, 245)
skipTreesButton.TextSize = 16
skipTreesButton.Font = Enum.Font.Arial
skipTreesButton.AutoButtonColor = false
skipTreesButton.Parent = main

skipTreesButton.MouseButton1Click:Connect(function()
    local nextState = not skipFoundTrees
    if not writeSkipFoundTrees(nextState) then
        warn("Spooky Tree Tools: Skip Trees toggle requires getgenv support.")
        return
    end

    skipTreesButton.Text = skipFoundTrees and "Skip Trees: ON"
        or "Skip Trees: OFF"
    skipTreesButton.BackgroundColor3 = skipFoundTrees
        and Color3.fromRGB(51, 87, 130)
        or Color3.fromRGB(39, 70, 108)
end)

createDiscordButton(main, UDim2.fromOffset(15, 472), 145)
createWebhookButton(main, UDim2.fromOffset(170, 472), 145)

local resetAuthorizationButton = Instance.new("TextButton")
resetAuthorizationButton.Size = UDim2.fromOffset(300, 34)
resetAuthorizationButton.Position = UDim2.fromOffset(15, 519)
resetAuthorizationButton.BackgroundColor3 = Color3.fromRGB(82, 54, 54)
resetAuthorizationButton.BorderSizePixel = 1
resetAuthorizationButton.BorderColor3 = Color3.fromRGB(130, 78, 78)
resetAuthorizationButton.Text = "Reset Local Key + HWID"
resetAuthorizationButton.TextColor3 = Color3.fromRGB(245, 225, 225)
resetAuthorizationButton.TextSize = 14
resetAuthorizationButton.Font = Enum.Font.Arial
resetAuthorizationButton.AutoButtonColor = true
resetAuthorizationButton.Parent = main
resetAuthorizationButton.MouseButton1Click:Connect(function()
    local cleared, err = clearSavedAuthorization()
    if not cleared then
        resetAuthorizationButton.Text = "Reset failed - see console"
        warn("Spooky Tree Tools: Could not reset local authorization: "
            .. tostring(err))
        return
    end

    closeMenu()
    showKeyScreen()
end)

local function getVisitedServerState(placeId)
    local placeKey = tostring(placeId)
    local environment = getExecutorEnvironment()
    local allVisited
    if environment then
        if type(environment.SpookyTreeVisitedServers) ~= "table" then
            environment.SpookyTreeVisitedServers = {}
        end
        allVisited = environment.SpookyTreeVisitedServers
    else
        allVisited = visitedServersFallback
    end

    if type(allVisited) ~= "table" then
        allVisited = {}
        visitedServersFallback = allVisited
    end

    local state = allVisited[placeKey]
    if type(state) ~= "table" then
        state = {}
        allVisited[placeKey] = state
    end

    return state
end

local function hasVisitedServer(placeId, serverId)
    return getVisitedServerState(placeId)[serverId] == true
end

local function markServerVisited(placeId, serverId)
    local state = getVisitedServerState(placeId)
    if state[serverId] then
        return
    end

    state[serverId] = true
end

local function queueScriptForTeleport(searchMode, expectedSearchMode)

    local queuedSource = "loadstring(game:HttpGet("
        .. HttpService:JSONEncode(SCRIPT_URL)
        .. "))()"

    local queuedSearchMode = searchMode and HttpService:JSONEncode(searchMode)
        or "nil"
    queuedSource = "if type(getgenv) == 'function' then "
        .. "local env = getgenv(); "
        .. "env.SpookyTreeAuthorized = true; "
        .. "env.SpookyTreeAutoSearchMode = " .. queuedSearchMode .. "; "
        .. "env.SpookyTreeAutoSearch = "
        .. (searchMode and "true" or "false")
        .. " end; "
        .. queuedSource

    local attempt = 0
    while serverHop.Parent do
        if expectedSearchMode ~= treeSearchMode then
            return false, "Search mode changed before queue setup completed."
        end

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

local function waitForPlayerReady(searchMode)
    while serverHop.Parent do
        if searchMode and treeSearchMode ~= searchMode then
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

local function stopTreeSearch(found, treeType, target)
    if found and skipFoundTrees then
        serverHop.Text = "Tree found; continuing to hop..."
        notifyTreeFound(
            treeType == "spookyneon" and "Spooky Neon" or "spooky",
            target
        )
        return false
    end

    treeSearchMode = nil
    writeAutoSearchMode(nil)
    treeSearchButton.Text = "Find Spooky Tree: OFF"
    treeSearchButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
    neonSearchButton.Text = "Find Spooky Neon: OFF"
    neonSearchButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
    if found then
        serverHop.Text = "Spooky tree found!"
        notifyTreeFound(
            treeType == "spookyneon" and "Spooky Neon" or "spooky",
            target
        )
    end
    return true
end

beginServerHop = function()

    if hopTaskRunning or queueing then
        return
    end

    hopTaskRunning = true
    queueing = true
    local queuedSearchMode = treeSearchMode
    if not waitForPlayerReady(queuedSearchMode) then
        queueing = false
        hopTaskRunning = false
        if treeSearchMode then
            task.defer(beginServerHop)
        end
        return
    end

    local queued, queueError = queueScriptForTeleport(
        queuedSearchMode,
        queuedSearchMode
    )
    queueing = false

    if not queued then
        hopTaskRunning = false
        if serverHop.Parent then
            if treeSearchMode then
                task.defer(beginServerHop)
            else
                serverHop.Text = "Server Hop"
            end
        end
        if treeSearchMode == queuedSearchMode then
            warn("Spooky Tree Tools: " .. queueError)
        end
        return
    end
    if queuedSearchMode ~= treeSearchMode then
        hopTaskRunning = false
        if treeSearchMode then
            task.defer(beginServerHop)
        else
            queueing = true
            queueScriptForTeleport(nil, nil)
            queueing = false
            if treeSearchMode then
                task.defer(beginServerHop)
            end
        end
        return
    end
    local queuedSearchModeApplied = queuedSearchMode

    hopping = true
    hopIsAutoSearch = queuedSearchMode ~= nil
    serverHop.Text = "Finding server..."

    local placeId = game.PlaceId
    local currentJobId = game.JobId
    markServerVisited(placeId, currentJobId)
    local cursor = nil
    local lastCursor = nil
    local apiFailures = 0

    while hopping and serverHop.Parent do
        if hopIsAutoSearch and not treeSearchMode then
            hopping = false
            break
        end

        if treeSearchMode then
            local found, treeType, target = hasSpookyTree(treeSearchMode)
            if found then
                if stopTreeSearch(true, treeType, target) then
                    hopping = false
                    break
                end
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
            apiFailures = apiFailures + 1
            serverHop.Text = "Search failed; retrying..."
            local retryDelay = math.min(2 ^ apiFailures, 30)
            warn("Spooky Tree Tools: Server list request failed: "
                .. tostring(result))
            task.wait(retryDelay)
        else
            local decodeSuccess, data = pcall(function()
                return HttpService:JSONDecode(result)
            end)

            if not decodeSuccess or type(data) ~= "table"
                or type(data.data) ~= "table" then
                apiFailures = apiFailures + 1
                serverHop.Text = "Invalid server list; retrying..."
                local responseSummary = tostring(result)
                warn(
                    "Spooky Tree Tools: Server API returned an invalid list: "
                    .. string.sub(responseSummary, 1, 300)
                )
                task.wait(math.min(2 ^ apiFailures, 30))
            else
                apiFailures = 0
                local nextCursor = data.nextPageCursor
                if nextCursor ~= nil and type(nextCursor) ~= "string" then
                    warn("Spooky Tree Tools: Server API returned an invalid page cursor.")
                    cursor = nil
                    lastCursor = nil
                    task.wait(HOP_RETRY_DELAY)
                elseif nextCursor and nextCursor == lastCursor then
                    warn("Spooky Tree Tools: Server API repeated a page cursor; restarting pagination.")
                    cursor = nil
                    lastCursor = nil
                    task.wait(HOP_RETRY_DELAY)
                else
                cursor = nextCursor
                lastCursor = nextCursor
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
                        and not hasVisitedServer(placeId, server.id) then
                        attemptedServer = true
                        markServerVisited(placeId, server.id)
                        serverHop.Text = "Trying another server..."

                        if treeSearchMode ~= queuedSearchModeApplied then
                            queueing = true
                            local modeQueued, modeQueueError =
                                queueScriptForTeleport(
                                    treeSearchMode,
                                    treeSearchMode
                                )
                            queueing = false
                            if not modeQueued then
                                warn("Spooky Tree Tools: Could not update queued search mode: "
                                    .. tostring(modeQueueError))
                                hopping = false
                                break
                            end
                            queuedSearchModeApplied = treeSearchMode
                        end

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

                        local foundTreeWhileWaiting = false
                        if teleportSuccess then
                            local startedAt = os.clock()
                            repeat
                                if treeSearchMode then
                                    local found, treeType, target =
                                        hasSpookyTree(treeSearchMode)
                                    if found then
                                        local searchStopped =
                                            stopTreeSearch(true, treeType, target)
                                        if searchStopped then
                                            hopping = false
                                            break
                                        end
                                        foundTreeWhileWaiting = true
                                        break
                                    end
                                end

                                task.wait(0.25)
                            until failureRaised or not hopping
                                or not serverHop.Parent
                                or os.clock() - startedAt >= 45
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
                        elseif foundTreeWhileWaiting and hopping
                            and serverHop.Parent then
                            serverHop.Text = "Tree found; trying next server..."
                            task.wait(1)
                        elseif hopping and serverHop.Parent then
                            serverHop.Text = "Teleport timed out; waiting before retry..."
                            task.wait(HOP_RETRY_DELAY)
                        end
                    end
                end

                if not attemptedServer then
                    if cursor then
                        serverHop.Text = "Checking more servers..."
                        task.wait(0.5)
                    else
                        serverHop.Text = "No new servers; retrying..."
                        task.wait(HOP_RETRY_DELAY)
                    end
                end
                end
            end
        end
    end

    hopping = false
    hopIsAutoSearch = false
    hopTaskRunning = false
    if treeSearchMode and serverHop.Parent then
        task.defer(beginServerHop)
    end
end

serverHop.MouseButton1Click:Connect(beginServerHop)

local function setTreeSearchMode(mode)
    if treeSearchMode == mode then
        mode = nil
    end

    local wasAutoSearch = hopIsAutoSearch
    treeSearchMode = mode
    if not writeAutoSearchMode(mode) then
        treeSearchMode = nil
        hopping = false
        hopIsAutoSearch = false
        treeSearchButton.Text = "Find Spooky Tree: OFF"
        treeSearchButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
        neonSearchButton.Text = "Find Spooky Neon: OFF"
        neonSearchButton.BackgroundColor3 = Color3.fromRGB(39, 70, 108)
        warn("Spooky Tree Tools: Persistent search requires getgenv support.")
        return
    end

    treeSearchButton.Text = mode == "spooky"
        and "Find Spooky Tree: ON"
        or "Find Spooky Tree: OFF"
    treeSearchButton.BackgroundColor3 = mode == "spooky"
        and Color3.fromRGB(51, 87, 130)
        or Color3.fromRGB(39, 70, 108)
    neonSearchButton.Text = mode == "spookyneon"
        and "Find Spooky Neon: ON"
        or "Find Spooky Neon: OFF"
    neonSearchButton.BackgroundColor3 = mode == "spookyneon"
        and Color3.fromRGB(51, 87, 130)
        or Color3.fromRGB(39, 70, 108)

    if mode and hopping then
        hopIsAutoSearch = true
    end

    if not mode then
        if wasAutoSearch then
            hopping = false
            hopIsAutoSearch = false
            task.spawn(function()
                while queueing and serverHop.Parent do
                    task.wait(0.05)
                end
                if not serverHop.Parent then
                    return
                end

                queueing = true
                local queued, queueError = queueScriptForTeleport(nil)
                queueing = false
                if not queued then
                    warn("Spooky Tree Tools: Could not clear queued search mode: "
                        .. tostring(queueError))
                end
                if treeSearchMode then
                    task.defer(beginServerHop)
                end
            end)
        end
        serverHop.Text = "Server Hop"
        return
    end

    local found, treeType, target = hasSpookyTree(mode)
    if found then
        if not stopTreeSearch(true, treeType, target) then
            task.spawn(beginServerHop)
        end
    else
        task.spawn(beginServerHop)
    end
end

closeCleanup = function()
    if treeSearchMode then
        treeSearchMode = nil
        writeAutoSearchMode(nil)
        hopping = false
        hopIsAutoSearch = false
    end

    for _, target in pairs(highlightedTrees) do
        if target and target.Parent then
            local marker = target:FindFirstChild(TREE_MARKER_NAME, true)
            if marker then
                marker:Destroy()
            end
        end
    end
end

treeSearchButton.MouseButton1Click:Connect(function()
    setTreeSearchMode("spooky")
end)

neonSearchButton.MouseButton1Click:Connect(function()
    setTreeSearchMode("spookyneon")
end)

if treeSearchMode then
    treeSearchButton.Text = treeSearchMode == "spooky"
        and "Find Spooky Tree: ON"
        or "Find Spooky Tree: OFF"
    treeSearchButton.BackgroundColor3 = treeSearchMode == "spooky"
        and Color3.fromRGB(51, 87, 130)
        or Color3.fromRGB(39, 70, 108)
    neonSearchButton.Text = treeSearchMode == "spookyneon"
        and "Find Spooky Neon: ON"
        or "Find Spooky Neon: OFF"
    neonSearchButton.BackgroundColor3 = treeSearchMode == "spookyneon"
        and Color3.fromRGB(51, 87, 130)
        or Color3.fromRGB(39, 70, 108)

    local found, treeType, target = hasSpookyTree(treeSearchMode)
    if found then
        if not stopTreeSearch(true, treeType, target) then
            task.defer(beginServerHop)
        end
    else
        task.defer(beginServerHop)
    end
end


local function hover(button)

    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(51, 87, 130)
    end)

    button.MouseLeave:Connect(function()
        local isActive = (button == flyButton and flyEnabled)
            or (button == treeSearchButton and treeSearchMode == "spooky")
            or (button == neonSearchButton and treeSearchMode == "spookyneon")
            or (button == skipTreesButton and skipFoundTrees)
        button.BackgroundColor3 = isActive
            and Color3.fromRGB(51, 87, 130)
            or Color3.fromRGB(39, 70, 108)
    end)

end

hover(selector)
hover(teleportButton)
hover(flyButton)
hover(setWalkSpeedButton)
hover(serverHop)
hover(treeSearchButton)
hover(neonSearchButton)
hover(skipTreesButton)
end

if playerGui:FindFirstChild("SpookyTreeTools") then
    return
elseif hasSavedAuthorization() then
    loadMenu()
else
    showKeyScreen()
end
