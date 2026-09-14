--!strict
-- Lombard: sprzedaz przedmiotow, wystawianie na ekspozycje, pasywny dochod.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Loot = require(Shared:WaitForChild("Loot"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ShopService = {}
local ProfileService

local function takeFromInventory(profile, uid: string)
	for index, item in profile.Inventory do
		if item.Uid == uid then
			return table.remove(profile.Inventory, index)
		end
	end
	return nil
end

local function onSellItem(player: Player, uid: unknown)
	if type(uid) ~= "string" then
		return { ok = false, reason = "bad_request" }
	end

	local profile = ProfileService.get(player)
	if not profile then
		return { ok = false, reason = "no_profile" }
	end

	local item = takeFromInventory(profile, uid)
	if not item then
		return { ok = false, reason = "not_found" }
	end

	local payout = Loot.sellValue(item)
	profile.Balance += payout
	profile.Stats.ItemsSold += 1
	Remotes.event("BalanceChanged"):FireClient(player, profile.Balance)

	return { ok = true, payout = payout, dirty = item.Dirty }
end

local function onDisplayItem(player: Player, uid: unknown)
	if type(uid) ~= "string" then
		return { ok = false, reason = "bad_request" }
	end

	local profile = ProfileService.get(player)
	if not profile then
		return { ok = false, reason = "no_profile" }
	end

	if #profile.Displayed >= Config.Shop.DisplaySlots then
		return { ok = false, reason = "no_slots" }
	end

	local item = takeFromInventory(profile, uid)
	if not item then
		return { ok = false, reason = "not_found" }
	end

	table.insert(profile.Displayed, item)
	return { ok = true, displayed = #profile.Displayed }
end

-- Wystawione przedmioty daja pasywny dochod, ale mozna je ukrasc.
local function payoutLoop()
	while true do
		task.wait(Config.Shop.PayoutIntervalSeconds)
		for _, player in Players:GetPlayers() do
			local profile = ProfileService.get(player)
			if profile then
				local total = 0
				for _, item in profile.Displayed do
					total += Loot.sellValue(item)
				end
				local payout = math.floor(total * Config.Shop.PassiveRatePerValue)
				if payout > 0 then
					profile.Balance += payout
					Remotes.event("BalanceChanged"):FireClient(player, profile.Balance)
				end
			end
		end
	end
end

function ShopService.start(profileService)
	ProfileService = profileService
	Remotes.func("SellItem").OnServerInvoke = onSellItem
	Remotes.func("DisplayItem").OnServerInvoke = onDisplayItem
	task.spawn(payoutLoop)
end

return ShopService
