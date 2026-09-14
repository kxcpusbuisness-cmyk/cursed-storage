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

print("[CursedStorage] Serwer uruchomiony.")
