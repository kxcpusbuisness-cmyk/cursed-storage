--!strict
-- Proste zapisywanie profilu gracza w DataStore.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

-- W Studio bez "Enable Studio Access to API Services" GetDataStore rzuca blad,
-- dlatego dzialamy dalej bez zapisu zamiast zabijac caly serwer.
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Datastore.Name)
	end)
	if ok then
		store = result
	else
		warn("[CursedStorage] DataStore niedostepny, gram bez zapisu: " .. tostring(result))
	end
end

local ProfileService = {}
local profiles: { [number]: any } = {}

local function defaultProfile()
	return {
		Balance = Config.Currency.StartingBalance,
		Inventory = {}, -- LootItem[]
		Displayed = {}, -- LootItem[] wystawione w lombardzie
		Stats = {
			LockersWon = 0,
			ItemsCleaned = 0,
			ItemsSold = 0,
			ItemsStolen = 0,
			TimesRobbed = 0,
		},
	}
end

function ProfileService.load(player: Player)
	if not store then
		profiles[player.UserId] = defaultProfile()
		return profiles[player.UserId]
	end

	local key = "u_" .. player.UserId
	local ok, data = pcall(function()
		return store:GetAsync(key)
	end)

	if ok and type(data) == "table" then
		local profile = defaultProfile()
		for field, value in data do
			profile[field] = value
		end
		profiles[player.UserId] = profile
	else
		profiles[player.UserId] = defaultProfile()
	end

	return profiles[player.UserId]
end

function ProfileService.get(player: Player)
	return profiles[player.UserId]
end

function ProfileService.save(player: Player)
	local profile = profiles[player.UserId]
	if not profile or not store then
		return
	end
	pcall(function()
		store:SetAsync("u_" .. player.UserId, profile)
	end)
end

function ProfileService.release(player: Player)
	ProfileService.save(player)
	profiles[player.UserId] = nil
end

function ProfileService.start()
	task.spawn(function()
		while true do
			task.wait(Config.Datastore.AutosaveSeconds)
			for _, player in Players:GetPlayers() do
				ProfileService.save(player)
			end
		end
	end)
end

return ProfileService
