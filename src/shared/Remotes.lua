--!strict
-- Tworzy i udostepnia RemoteEvent/RemoteFunction po obu stronach.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "CursedStorageRemotes"

local EVENTS = {
	"AuctionStarted",
	"AuctionEnded",
	"PlaceBid",
	"PhaseChanged",
	"ItemRevealed",
	"ScrubItem",
	"ItemCleaned",
	"StealAttempt",
	"StealResult",
	"BalanceChanged",
	"Notify",
}

local FUNCTIONS = {
	"GetProfile",
	"SellItem",
	"DisplayItem",
}

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Folder
end

local function ensure(folder: Folder, name: string, className: string): Instance
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name, 30)
end

function Remotes.init()
	local folder = getFolder()
	for _, name in EVENTS do
		ensure(folder, name, "RemoteEvent")
	end
	for _, name in FUNCTIONS do
		ensure(folder, name, "RemoteFunction")
	end
end

function Remotes.event(name: string): RemoteEvent
	return ensure(getFolder(), name, "RemoteEvent") :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return ensure(getFolder(), name, "RemoteFunction") :: RemoteFunction
end

return Remotes
