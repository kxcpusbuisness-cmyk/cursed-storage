--!strict
-- Punkt wejscia serwera. Uruchamia wszystkie serwisy w poprawnej kolejnosci.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function onPlayerAdded(player: Player)
	local profile = ProfileService.load(player)
	Remotes.event("BalanceChanged"):FireClient(player, profile.Balance)
	Remotes.event("PhaseChanged"):FireClient(player, HeistService.getPhase())
end

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

ProfileService.start()
AuctionService.start(ProfileService)
CleaningService.start(ProfileService)
ShopService.start(ProfileService)
HeistService.start(ProfileService)
WorldService.start(ProfileService, AuctionService, CleaningService)

-- Komendy testowe na czacie. Dzialaja tylko w Studio, zeby nie wyciekly do gry.
local function handleCommand(player: Player, message: string)
	local parts = string.split(string.lower(message), " ")
	local command = parts[1]

	if command == "/aukcja" then
		local tier = AuctionService.forceLot(parts[2])
		if tier then
			Remotes.event("Notify"):FireClient(player, "Aukcja odpalona: " .. tier)
		else
			Remotes.event("Notify"):FireClient(player, "Nie znam takiego lockera. Uzyj: dusty, sealed, evidence, condemned")
		end
	elseif command == "/kasa" then
		local profile = ProfileService.get(player)
		local amount = tonumber(parts[2]) or 10000
		if profile then
			profile.Balance += math.floor(amount)
			Remotes.event("BalanceChanged"):FireClient(player, profile.Balance)
			Remotes.event("Notify"):FireClient(player, string.format("Dodane $%d", math.floor(amount)))
		end
	elseif command == "/pomoc" then
		Remotes.event("Notify"):FireClient(player, "/aukcja [tier] | /kasa [kwota] | /pomoc")
	end
end

local function hookCommands(player: Player)
	if not game:GetService("RunService"):IsStudio() then
		return
	end
	player.Chatted:Connect(function(message)
		local ok, err = pcall(handleCommand, player, message)
		if not ok then
			warn("[CursedStorage] Blad komendy: " .. tostring(err))
		end
	end)
end

Players.PlayerAdded:Connect(hookCommands)
for _, player in Players:GetPlayers() do
	hookCommands(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
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

print("[CursedStorage] Serwer uruchomiony. Komendy: /aukcja, /kasa, /pomoc")
