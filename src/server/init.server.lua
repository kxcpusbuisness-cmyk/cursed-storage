--!strict
-- Punkt wejscia serwera. Uruchamia wszystkie serwisy w poprawnej kolejnosci.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
Remotes.init()

local Server = ServerScriptService:WaitForChild("Server")
local ProfileService = require(Server:WaitForChild("ProfileService"))
local AuctionService = require(Server:WaitForChild("AuctionService"))
local CleaningService = require(Server:WaitForChild("CleaningService"))
local ShopService = require(Server:WaitForChild("ShopService"))
local HeistService = require(Server:WaitForChild("HeistService"))
local WorldService = require(Server:WaitForChild("WorldService"))

ProfileService.start()
AuctionService.start(ProfileService)
CleaningService.start(ProfileService)
ShopService.start(ProfileService)
HeistService.start(ProfileService)
WorldService.start(ProfileService, AuctionService, CleaningService)

Remotes.func("GetProfile").OnServerInvoke = function(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return nil
	end
	return {
		Balance = profile.Balance,
		Inventory = profile.Inventory,
		Displayed = profile.Displayed,
		Stats = profile.Stats,
	}
end

-- Komendy sa tylko dla wlasciciela gry (i w Studio), nie dla graczy.
local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	return false
end

local function handleCommand(player: Player, message: string)
	if not isAdmin(player) then
		return
	end

	local parts = string.split(string.lower(message), " ")
	local command = parts[1]

	if command == "/aukcja" then
		local tier = AuctionService.forceLot(parts[2])
		if tier then
			Remotes.event("Notify"):FireClient(player, "Aukcja odpalona: " .. tier)
		else
			Remotes.event("Notify"):FireClient(player, "Tiery: dusty, sealed, evidence, condemned")
		end
	elseif command == "/kasa" then
		local profile = ProfileService.get(player)
		local amount = math.floor(tonumber(parts[2]) or 10000)
		if profile then
			profile.Balance += amount
			Remotes.event("BalanceChanged"):FireClient(player, profile.Balance)
			Remotes.event("Notify"):FireClient(player, string.format("Dodane $%d", amount))
		end
	elseif command == "/noc" then
		if HeistService.forcePhase then
			HeistService.forcePhase("Night")
		end
	elseif command == "/dzien" then
		if HeistService.forcePhase then
			HeistService.forcePhase("Day")
		end
	elseif command == "/pomoc" then
		Remotes.event("Notify"):FireClient(player, "/aukcja [tier] | /kasa [kwota] | /noc | /dzien")
	end
end

local function onPlayerAdded(player: Player)
	local profile = ProfileService.load(player)
	Remotes.event("BalanceChanged"):FireClient(player, profile.Balance)
	Remotes.event("PhaseChanged"):FireClient(player, HeistService.getPhase())

	-- Kazdy gracz dostaje wlasne stanowisko na wspolnej mapie.
	WorldService.assignStall(player)

	if isAdmin(player) then
		player.Chatted:Connect(function(message)
			local ok, err = pcall(handleCommand, player, message)
			if not ok then
				warn("[CursedStorage] Blad komendy: " .. tostring(err))
			end
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	local ok, err = pcall(onPlayerAdded, player)
	if not ok then
		warn("[CursedStorage] Blad dolaczania gracza: " .. tostring(err))
	end
end)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	ProfileService.release(player)
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		ProfileService.save(player)
	end
end)

print("[CursedStorage] Serwer uruchomiony.")
