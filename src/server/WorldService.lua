--!strict
-- Buduje cala scene w runtime i obsluguje interakcje ProximityPrompt.
-- Dzieki temu po wcisnieciu Play widac gotowy swiat, bez budowania w Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Loot = require(Shared:WaitForChild("Loot"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local WorldService = {}

local ProfileService
local AuctionService
local CleaningService

local root: Folder
local shelvesFolder: Folder
local lockerInfo: TextLabel?
local benchInfo: TextLabel?
local shopInfo: TextLabel?

local function notify(player: Player, message: string)
	Remotes.event("Notify"):FireClient(player, message)
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function billboard(parent: BasePart, text: string, offsetY: number, name: string?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 280, 0, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name or "Caption"
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.fromRGB(255, 245, 225)
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Text = text
	textLabel.Parent = gui

	return textLabel
end

local function makePrompt(parent: BasePart, name: string, action: string, object: string, key: Enum.KeyCode): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = key
	p.Parent = parent
	return p
end

-- Budowa sceny -------------------------------------------------------------

local function buildGround()
	local floor = part({
		Name = "Floor",
		Size = Vector3.new(400, 4, 400),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(92, 88, 82),
		Material = Enum.Material.Concrete,
	})
	floor.Parent = root

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(255, 176, 64)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = root
end

local function buildAuction()
	local body = part({
		Name = "LockerBody",
		Size = Vector3.new(12, 12, 10),
		Position = Vector3.new(0, 6, -40),
		Color = Color3.fromRGB(196, 120, 48),
		Material = Enum.Material.CorrodedMetal,
	})
	body.Parent = root

	local door = part({
		Name = "LockerDoor",
		Size = Vector3.new(11, 10, 0.6),
		Position = Vector3.new(0, 6, -34.8),
		Color = Color3.fromRGB(228, 156, 72),
		Material = Enum.Material.DiamondPlate,
	})
	door.Parent = root

	billboard(body, "AUKCJA LOCKEROW", 8.5)
	lockerInfo = billboard(body, "Czekam na aukcje...", 6.6, "Info")
	if lockerInfo then
		lockerInfo.TextColor3 = Color3.fromRGB(255, 210, 120)
	end

	local bidPrompt = makePrompt(door, "BidPrompt", "Podbij oferte", "Locker", Enum.KeyCode.E)
	bidPrompt.Triggered:Connect(function(player)
		WorldService.onBid(player)
	end)
end

local function buildCleaning()
	local bench = part({
		Name = "CleaningBench",
		Size = Vector3.new(14, 4, 8),
		Position = Vector3.new(-40, 2, 0),
		Color = Color3.fromRGB(88, 164, 176),
		Material = Enum.Material.Metal,
	})
	bench.Parent = root

	billboard(bench, "CZYSZCZENIE", 5.2)
	benchInfo = billboard(bench, "Brak brudnych przedmiotow", 3.6, "Info")
	if benchInfo then
		benchInfo.TextColor3 = Color3.fromRGB(150, 230, 240)
	end

	local scrubPrompt = makePrompt(bench, "ScrubPrompt", "Czysc przedmiot", "Stol", Enum.KeyCode.E)
	scrubPrompt.Triggered:Connect(function(player)
		WorldService.onScrub(player)
	end)
end

local function buildShop()
	local counter = part({
		Name = "ShopCounter",
		Size = Vector3.new(16, 5, 8),
		Position = Vector3.new(40, 2.5, 0),
		Color = Color3.fromRGB(150, 96, 200),
		Material = Enum.Material.Wood,
	})
	counter.Parent = root

	billboard(counter, "LOMBARD", 6.2)
	shopInfo = billboard(counter, "Pusto", 4.6, "Info")
	if shopInfo then
		shopInfo.TextColor3 = Color3.fromRGB(220, 180, 255)
	end

	local sellPrompt = makePrompt(counter, "SellPrompt", "Sprzedaj wszystko", "Kasa", Enum.KeyCode.E)
	sellPrompt.Triggered:Connect(function(player)
		WorldService.onSellAll(player)
	end)

	local displayPrompt = makePrompt(counter, "DisplayPrompt", "Wystaw na polke", "Ekspozycja", Enum.KeyCode.F)
	displayPrompt.Triggered:Connect(function(player)
		WorldService.onDisplay(player)
	end)

	shelvesFolder = Instance.new("Folder")
	shelvesFolder.Name = "Shelves"
	shelvesFolder.Parent = root

	for index = 1, Config.Shop.DisplaySlots do
		local column = (index - 1) % 6
		local row = math.floor((index - 1) / 6)
		local pedestal = part({
			Name = string.format("Slot%02d", index),
			Size = Vector3.new(4, 3, 4),
			Position = Vector3.new(24 + column * 6, 1.5, 18 + row * 8),
			Color = Color3.fromRGB(70, 66, 88),
		})
		pedestal.Parent = shelvesFolder
	end
end

-- Interakcje ---------------------------------------------------------------

function WorldService.onBid(player: Player)
	local lot = AuctionService.getActiveLot()
	if not lot then
		return notify(player, "Teraz nie ma aukcji. Poczekaj chwile.")
	end
	AuctionService.bid(player, lot.LotId, lot.HighestBid + Config.Auction.MinBidStep)
end

function WorldService.onScrub(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return
	end

	for _, item in profile.Inventory do
		if item.Dirty then
			CleaningService.scrub(player, item.Uid)
			return
		end
	end

	notify(player, "Nie masz brudnych przedmiotow. Wygraj najpierw locker.")
end

function WorldService.onSellAll(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return
	end
	if #profile.Inventory == 0 then
		return notify(player, "Ekwipunek jest pusty.")
	end

	local total = 0
	local count = #profile.Inventory
	for index = count, 1, -1 do
		local item = table.remove(profile.Inventory, index)
		total += Loot.sellValue(item)
		profile.Stats.ItemsSold += 1
	end

	profile.Balance += total
	Remotes.event("BalanceChanged"):FireClient(player, profile.Balance)
	notify(player, string.format("Sprzedane %d przedmiotow za $%d", count, total))
end

function WorldService.onDisplay(player: Player)
	local profile = ProfileService.get(player)
	if not profile then
		return
	end
	if #profile.Displayed >= Config.Shop.DisplaySlots then
		return notify(player, "Brak wolnych slotow ekspozycji.")
	end

	-- Najpierw wystawiamy najcenniejszy wyczyszczony przedmiot.
	local bestIndex: number? = nil
	local bestValue = -1
	for index, item in profile.Inventory do
		if not item.Dirty and item.Value > bestValue then
			bestIndex = index
			bestValue = item.Value
		end
	end

	if not bestIndex then
		return notify(player, "Najpierw wyczysc przedmiot przy stole.")
	end

	local item = table.remove(profile.Inventory, bestIndex)
	table.insert(profile.Displayed, item)
	notify(player, string.format("Wystawione: %s ($%d)", item.Name, item.Value))
	WorldService.refreshShelves()
end

function WorldService.refreshShelves()
	if not shelvesFolder then
		return
	end

	local owner = Players:GetPlayers()[1]
	local profile = owner and ProfileService.get(owner)

	local pedestals = shelvesFolder:GetChildren()
	table.sort(pedestals, function(a, b)
		return a.Name < b.Name
	end)

	for index, pedestal in pedestals do
		local existing = pedestal:FindFirstChild("Trophy")
		if existing then
			existing:Destroy()
		end

		local item = profile and profile.Displayed[index]
		if item and pedestal:IsA("BasePart") then
			local rarity = Loot.rarityById(item.Rarity)
			local trophy = part({
				Name = "Trophy",
				Size = Vector3.new(2.4, 2.4, 2.4),
				Position = pedestal.Position + Vector3.new(0, 2.8, 0),
				Color = rarity.Color,
				Material = Enum.Material.Neon,
			})
			trophy.Parent = pedestal
			billboard(trophy, string.format("%s $%d", item.Name, item.Value), 2.2)
		end
	end
end

function WorldService.setAuctionText(text: string)
	if lockerInfo then
		lockerInfo.Text = text
	end
end

-- Jedno przejscie petli. Wydzielone, zeby mozna je bylo objac pcall.
local function refreshTick()
	do

		local owner = Players:GetPlayers()[1]
		local profile = owner and ProfileService.get(owner)
		if profile then
			local dirty = 0
			for _, item in profile.Inventory do
				if item.Dirty then
					dirty += 1
				end
			end

			if benchInfo then
				benchInfo.Text = string.format("Brudne: %d | Ekwipunek: %d", dirty, #profile.Inventory)
			end
			if shopInfo then
				shopInfo.Text = string.format(
					"Wystawione: %d/%d | Gotowka: $%d",
					#profile.Displayed,
					Config.Shop.DisplaySlots,
					profile.Balance
				)
			end
		end

		local lot = AuctionService.getActiveLot()
		if lot then
			WorldService.setAuctionText(string.format(
				"%s | %d przedmiotow | oferta $%d%s",
				tostring(lot.TierId or "Locker"),
				#(lot.Items or {}),
				tonumber(lot.HighestBid) or 0,
				if lot.HighestBidder then " | " .. lot.HighestBidder.Name else ""
			))
		else
			WorldService.setAuctionText("Czekam na kolejna aukcje...")
		end

		WorldService.refreshShelves()
	end
end

local function refreshLoop()
	while true do
		task.wait(1)
		local ok, err = pcall(refreshTick)
		if not ok then
			warn("[CursedStorage] Blad odswiezania: " .. tostring(err))
			task.wait(4)
		end
	end
end

function WorldService.start(profileService, auctionService, cleaningService)
	ProfileService = profileService
	AuctionService = auctionService
	CleaningService = cleaningService

	root = Instance.new("Folder")
	root.Name = "CursedStorageWorld"
	root.Parent = Workspace

	buildGround()
	buildAuction()
	buildCleaning()
	buildShop()

	task.spawn(refreshLoop)

	print("[CursedStorage] Swiat zbudowany.")
end

return WorldService
