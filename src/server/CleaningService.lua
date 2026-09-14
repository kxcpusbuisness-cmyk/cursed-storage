--!strict
-- Czyszczenie przedmiotow: brudny przedmiot ma mala wartosc, czysty pelna.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CleaningService = {}
local ProfileService

local progress: { [number]: { [string]: number } } = {}
local lastScrub: { [number]: number } = {}

local function findItem(profile, uid: string)
	for _, item in profile.Inventory do
		if item.Uid == uid then
			return item
		end
	end
	return nil
end

local function onScrub(player: Player, uid: unknown)
	if type(uid) ~= "string" then
		return
	end

	-- Anty-spam: klient nie moze przyspieszyc czyszczenia.
	local now = os.clock()
	if now - (lastScrub[player.UserId] or 0) < Config.Cleaning.SecondsPerScrub then
		return
	end
	lastScrub[player.UserId] = now

	local profile = ProfileService.get(player)
	if not profile then
		return
	end

	local item = findItem(profile, uid)
	if not item or not item.Dirty then
		return
	end

	progress[player.UserId] = progress[player.UserId] or {}
	local playerProgress = progress[player.UserId]
	playerProgress[uid] = (playerProgress[uid] or 0) + 1

	if playerProgress[uid] >= Config.Cleaning.ScrubsRequired then
		playerProgress[uid] = nil
		item.Dirty = false
		profile.Stats.ItemsCleaned += 1
		Remotes.event("ItemCleaned"):FireClient(player, item)
	else
		Remotes.event("Notify"):FireClient(
			player,
			string.format("Czyszczenie: %d/%d", playerProgress[uid], Config.Cleaning.ScrubsRequired)
		)
	end
end

function CleaningService.start(profileService)
	ProfileService = profileService
	Remotes.event("ScrubItem").OnServerEvent:Connect(onScrub)
end

return CleaningService
