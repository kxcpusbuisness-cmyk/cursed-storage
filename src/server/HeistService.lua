--!strict
-- Cykl dzien/noc oraz kradziez wystawionych przedmiotow w okienku nocnym.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local HeistService = {}
local ProfileService

local phase = "Day"
local cooldowns: { [string]: number } = {}

function HeistService.getPhase(): string
	return phase
end

local function setPhase(next: string)
	phase = next
	Lighting.ClockTime = if next == "Night" then 0 else 14
	Remotes.event("PhaseChanged"):FireAllClients(next)
end

local function onStealAttempt(player: Player, targetUserId: unknown, uid: unknown)
	local result = function(ok: boolean, reason: string, payload: any?)
		Remotes.event("StealResult"):FireClient(player, { ok = ok, reason = reason, item = payload })
	end

	if phase ~= "Night" then
		return result(false, "not_night")
	end
	if type(targetUserId) ~= "number" or type(uid) ~= "string" then
		return result(false, "bad_request")
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return result(false, "invalid_target")
	end

	local key = player.UserId .. "->" .. targetUserId
	if os.clock() < (cooldowns[key] or 0) then
		return result(false, "cooldown")
	end

	local thief = ProfileService.get(player)
	local victim = ProfileService.get(target)
	if not thief or not victim then
		return result(false, "no_profile")
	end

	for index, item in victim.Displayed do
		if item.Uid == uid then
			table.remove(victim.Displayed, index)
			table.insert(thief.Inventory, item)
			thief.Stats.ItemsStolen += 1
			victim.Stats.TimesRobbed += 1
			cooldowns[key] = os.clock() + Config.Heist.StealCooldownSeconds

			-- Kara predkosci: lup trzeba fizycznie doniesc do bazy.
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local base = humanoid.WalkSpeed
				humanoid.WalkSpeed = base * Config.Heist.CarrySpeedPenalty
				task.delay(8, function()
					if humanoid and humanoid.Parent then
						humanoid.WalkSpeed = base
					end
				end)
			end

			Remotes.event("Notify"):FireClient(target, player.Name .. " okradl twoj lombard!")
			return result(true, "stolen", item)
		end
	end

	return result(false, "item_missing")
end

function HeistService.start(profileService)
	ProfileService = profileService
	Remotes.event("StealAttempt").OnServerEvent:Connect(onStealAttempt)

	task.spawn(function()
		while true do
			setPhase("Day")
			task.wait(Config.Heist.CycleSeconds - Config.Heist.NightSeconds)
			setPhase("Night")
			task.wait(Config.Heist.NightSeconds)
		end
	end)
end

return HeistService
