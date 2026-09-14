--!strict
-- Aukcje lockerow: cykliczne rundy, licytacja, przekazanie lupu zwyciezcy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Loot = require(Shared:WaitForChild("Loot"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AuctionService = {}
local ProfileService

local activeLots: { [string]: any } = {}
local lotCounter = 0

local function notify(player: Player, message: string)
	Remotes.event("Notify"):FireClient(player, message)
end

local function creditBalance(player: Player, delta: number)
	local profile = ProfileService.get(player)
	if not profile then
		return
	end
	profile.Balance += delta
	Remotes.event("BalanceChanged"):FireClient(player, profile.Balance)
end

local function startLot(tierId: string)
	lotCounter += 1
	local lotId = "lot_" .. lotCounter
	local locker = Loot.rollLocker(tierId)

	activeLots[lotId] = {
		LotId = lotId,
		TierId = locker.TierId,
		Items = locker.Items,
		HighestBid = locker.BasePrice,
		HighestBidder = nil :: Player?,
		EndsAt = os.clock() + Config.Auction.BiddingSeconds,
	}

	-- Klient nie dostaje zawartosci lockera, tylko tier i cene startowa.
	Remotes.event("AuctionStarted"):FireAllClients({
		LotId = lotId,
		TierId = locker.TierId,
		StartingBid = locker.BasePrice,
		ItemCount = #locker.Items,
		Duration = Config.Auction.BiddingSeconds,
	})

	task.delay(Config.Auction.BiddingSeconds, function()
		local lot = activeLots[lotId]
		activeLots[lotId] = nil
		if not lot then
			return
		end

		local winner = lot.HighestBidder
		if not winner or not winner.Parent then
			Remotes.event("AuctionEnded"):FireAllClients({ LotId = lotId, Winner = nil })
			return
		end

		local profile = ProfileService.get(winner)
		if not profile or profile.Balance < lot.HighestBid then
			Remotes.event("AuctionEnded"):FireAllClients({ LotId = lotId, Winner = nil })
			return
		end

		creditBalance(winner, -lot.HighestBid)
		profile.Stats.LockersWon += 1

		for _, item in lot.Items do
			table.insert(profile.Inventory, item)
			Remotes.event("ItemRevealed"):FireClient(winner, item)
		end

		Remotes.event("AuctionEnded"):FireAllClients({
			LotId = lotId,
			Winner = winner.Name,
			Price = lot.HighestBid,
		})
	end)
end

local function onPlaceBid(player: Player, lotId: unknown, amount: unknown)
	if type(lotId) ~= "string" or type(amount) ~= "number" then
		return
	end

	local lot = activeLots[lotId]
	if not lot then
		return notify(player, "Ta aukcja juz sie skonczyla.")
	end

	amount = math.floor(amount)
	if amount < lot.HighestBid + Config.Auction.MinBidStep then
		return notify(player, "Oferta za niska.")
	end

	local profile = ProfileService.get(player)
	if not profile or profile.Balance < amount then
		return notify(player, "Nie masz tyle gotowki.")
	end

	lot.HighestBid = amount
	lot.HighestBidder = player

	Remotes.event("AuctionStarted"):FireAllClients({
		LotId = lotId,
		TierId = lot.TierId,
		StartingBid = amount,
		ItemCount = #lot.Items,
		Duration = math.max(0, lot.EndsAt - os.clock()),
		Leader = player.Name,
	})
end

-- Pozwala innym serwisom (np. WorldService) licytowac bez remote'a.
function AuctionService.bid(player: Player, lotId: string, amount: number)
	onPlaceBid(player, lotId, amount)
end

-- Zwraca aktualnie trwajaca aukcje albo nil.
function AuctionService.getActiveLot()
	for _, lot in activeLots do
		return lot
	end
	return nil
end

function AuctionService.start(profileService)
	ProfileService = profileService
	Remotes.event("PlaceBid").OnServerEvent:Connect(onPlaceBid)

	task.spawn(function()
		while true do
			if #Players:GetPlayers() > 0 then
				for _ = 1, Config.Auction.LockersPerRound do
					local tier = Config.LockerTiers[math.random(1, #Config.LockerTiers)]
					startLot(tier.Id)
					task.wait(Config.Auction.BiddingSeconds + 3)
				end
			end
			task.wait(Config.Auction.IntervalSeconds)
		end
	end)
end

return AuctionService
