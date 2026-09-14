--!strict
-- Buduje cala scene w runtime: magazyn, trzy stanowiska, swiatlo i dekoracje.
-- Wszystko jest ustawione tak, zeby zadne dwie sciany nie lezaly w tej samej
-- plaszczyznie - to wlasnie powodowalo migotanie obrazu przy ruchu kamera.

local Lighting = game:GetService("Lighting")
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

-- Paleta -------------------------------------------------------------------

local PALETTE = {
	Floor = Color3.fromRGB(58, 56, 64),
	FloorTrim = Color3.fromRGB(38, 36, 44),
	Wall = Color3.fromRGB(74, 70, 82),
	WallTrim = Color3.fromRGB(46, 44, 54),
	Auction = Color3.fromRGB(255, 150, 60),
	Cleaning = Color3.fromRGB(70, 190, 210),
	Shop = Color3.fromRGB(180, 110, 255),
	Metal = Color3.fromRGB(120, 116, 126),
	Wood = Color3.fromRGB(126, 88, 60),
	Crate = Color3.fromRGB(150, 108, 66),
}

local function notify(player: Player, message: string)
	Remotes.event("Notify"):FireClient(player, message)
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- Tabliczka nad stanowiskiem. Ramka + tlo, zeby tekst byl czytelny.
local function sign(parent: BasePart, text: string, offsetY: number, accent: Color3, name: string?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = (name or "Caption") .. "Gui"
	gui.Size = UDim2.new(0, 320, 0, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 16, 24)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2.5
	stroke.Transparency = 0.1
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = name or "Caption"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 248, 238)
	label.Text = text
	label.Parent = frame

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 28
	constraint.Parent = label

	return label
end

-- Kazdy prompt siedzi na wlasnym Attachment, zeby przyciski nie nakladaly sie
-- na siebie w jednym punkcie.
local function makePrompt(
	parent: BasePart,
	name: string,
	action: string,
	object: string,
	key: Enum.KeyCode,
	offset: Vector3?
): ProximityPrompt
	local anchor = Instance.new("Attachment")
	anchor.Name = name .. "Anchor"
	anchor.Position = offset or Vector3.new(0, 0, 0)
	anchor.Parent = parent

	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	p.KeyboardKeyCode = key
	p.Parent = anchor
	return p
end

local function lamp(position: Vector3, color: Color3)
	local housing = part({
		Name = "Lamp",
		Size = Vector3.new(3, 0.6, 3),
		Position = position,
		Color = Color3.fromRGB(30, 28, 34),
		Material = Enum.Material.Metal,
	})
	housing.Parent = root

	local bulb = part({
		Name = "Bulb",
		Size = Vector3.new(2.2, 0.25, 2.2),
		Position = position - Vector3.new(0, 0.45, 0),
		Color = color,
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	bulb.Parent = root

	local light = Instance.new("PointLight")
	light.Brightness = 2.2
	light.Range = 34
	light.Color = color
	light.Parent = bulb
end

-- Sprzatanie po szablonie Baseplate ---------------------------------------
-- To jest lek na migotanie: domyslny Baseplate lezal dokladnie w jednej
-- plaszczyznie z nasza podloga, wiec silnik nie wiedzial, ktora narysowac.

local function clearTemplate()
	for _, child in Workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		elseif child.Name == "CursedStorageWorld" then
			child:Destroy()
		end
	end
end

local function setupLighting()
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0.15
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(78, 74, 92)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 116, 136)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.35

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Haze = 1.4
	atmosphere.Glare = 0.2
	atmosphere.Color = Color3.fromRGB(210, 200, 190)
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.55
	bloom.Size = 22
	bloom.Threshold = 1.1
end

-- Budowa sceny -------------------------------------------------------------

local FLOOR_HALF = 150

local function buildGround()
	-- Podloga: gorna sciana dokladnie na y = 0.
	local floor = part({
		Name = "Floor",
		Size = Vector3.new(FLOOR_HALF * 2, 4, FLOOR_HALF * 2),
		Position = Vector3.new(0, -2, 0),
		Color = PALETTE.Floor,
		Material = Enum.Material.Concrete,
	})
	floor.Parent = root

	-- Strefy: cienkie plyty 0.12 nad podloga, zeby nie bylo z-fightingu.
	local zones = {
		{ Name = "AuctionZone", Position = Vector3.new(0, 0.06, -62), Size = Vector3.new(70, 0.12, 54), Color = PALETTE.Auction },
		{ Name = "CleaningZone", Position = Vector3.new(-64, 0.06, 6), Size = Vector3.new(48, 0.12, 56), Color = PALETTE.Cleaning },
		{ Name = "ShopZone", Position = Vector3.new(62, 0.06, 12), Size = Vector3.new(56, 0.12, 72), Color = PALETTE.Shop },
	}

	for _, zone in zones do
		local pad = part({
			Name = zone.Name,
			Size = zone.Size,
			Position = zone.Position,
			Color = zone.Color,
			Material = Enum.Material.Pavement,
			Transparency = 0.35,
			CastShadow = false,
		})
		pad.Parent = root
	end

	-- Sciezki od spawnu do stanowisk.
	local paths = {
		{ Position = Vector3.new(0, 0.04, -30), Size = Vector3.new(10, 0.08, 44) },
		{ Position = Vector3.new(-30, 0.04, 0), Size = Vector3.new(50, 0.08, 10) },
		{ Position = Vector3.new(30, 0.04, 0), Size = Vector3.new(50, 0.08, 10) },
	}

	for index, path in paths do
		local strip = part({
			Name = string.format("Path%02d", index),
			Size = path.Size,
			Position = path.Position,
			Color = PALETTE.FloorTrim,
			Material = Enum.Material.Pavement,
			CastShadow = false,
		})
		strip.Parent = root
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(16, 0.4, 16)
	spawn.Position = Vector3.new(0, 0.2, 8)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(255, 190, 90)
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Parent = root
end

local function buildWalls()
	local specs = {
		{ Name = "WallNorth", Position = Vector3.new(0, 20, -FLOOR_HALF), Size = Vector3.new(FLOOR_HALF * 2, 40, 4) },
		{ Name = "WallSouth", Position = Vector3.new(0, 20, FLOOR_HALF), Size = Vector3.new(FLOOR_HALF * 2, 40, 4) },
		{ Name = "WallWest", Position = Vector3.new(-FLOOR_HALF, 20, 0), Size = Vector3.new(4, 40, FLOOR_HALF * 2) },
		{ Name = "WallEast", Position = Vector3.new(FLOOR_HALF, 20, 0), Size = Vector3.new(4, 40, FLOOR_HALF * 2) },
	}

	for _, spec in specs do
		local wall = part({
			Name = spec.Name,
			Size = spec.Size,
			Position = spec.Position,
			Color = PALETTE.Wall,
			Material = Enum.Material.Brick,
		})
		wall.Parent = root
	end

	-- Filary wzdluz scian. Odsuniete o 3 kratki od sciany, wiec sie nie tna.
	for index = -4, 4 do
		if index ~= 0 then
			local x = index * 32
			for _, z in { -FLOOR_HALF + 4, FLOOR_HALF - 4 } do
				local pillar = part({
					Name = "Pillar",
					Size = Vector3.new(5, 40, 5),
					Position = Vector3.new(x, 20, z),
					Color = PALETTE.WallTrim,
					Material = Enum.Material.Concrete,
				})
				pillar.Parent = root
			end
		end
	end

	-- Belki dachowe: tylko szkielet, dach zostaje otwarty na niebo.
	for index = -3, 3 do
		local beam = part({
			Name = "Beam",
			Size = Vector3.new(FLOOR_HALF * 2, 2.5, 4),
			Position = Vector3.new(0, 38, index * 40),
			Color = PALETTE.WallTrim,
			Material = Enum.Material.Metal,
			CastShadow = false,
		})
		beam.Parent = root
	end

	lamp(Vector3.new(0, 34, -62), Color3.fromRGB(255, 190, 120))
	lamp(Vector3.new(-64, 34, 6), Color3.fromRGB(150, 235, 255))
	lamp(Vector3.new(62, 34, 12), Color3.fromRGB(220, 160, 255))
	lamp(Vector3.new(0, 34, 40), Color3.fromRGB(255, 235, 210))
end

local function crate(position: Vector3, size: number, rotation: number)
	local box = part({
		Name = "Crate",
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(position) * CFrame.fromOrientation(0, math.rad(rotation), 0),
		Color = PALETTE.Crate,
		Material = Enum.Material.WoodPlanks,
	})
	box.Parent = root
end

local function buildDecor()
	local spots = {
		{ Vector3.new(-100, 3, -100), 6, 12 },
		{ Vector3.new(-92, 3, -84), 6, -25 },
		{ Vector3.new(-98, 9, -100), 5, 40 },
		{ Vector3.new(104, 3, -96), 6, -8 },
		{ Vector3.new(112, 3, -82), 6, 33 },
		{ Vector3.new(-108, 3, 110), 6, 18 },
		{ Vector3.new(-96, 3, 118), 6, -12 },
		{ Vector3.new(108, 3, 116), 6, 27 },
		{ Vector3.new(0, 3, 120), 6, 0 },
		{ Vector3.new(14, 3, 122), 5, 22 },
	}

	for _, spot in spots do
		crate(spot[1] :: Vector3, spot[2] :: number, spot[3] :: number)
	end
end

local function buildAuction()
	-- Podest pod locker, zeby stanowisko mialo glebokosc.
	local podium = part({
		Name = "AuctionPodium",
		Size = Vector3.new(34, 1.6, 22),
		Position = Vector3.new(0, 0.8, -70),
		Color = PALETTE.FloorTrim,
		Material = Enum.Material.Concrete,
	})
	podium.Parent = root

	local body = part({
		Name = "LockerBody",
		Size = Vector3.new(16, 16, 12),
		Position = Vector3.new(0, 9.6, -72),
		Color = Color3.fromRGB(196, 120, 48),
		Material = Enum.Material.CorrodedMetal,
	})
	body.Parent = root

	-- Drzwi lekko przed korpusem, bez wspolnej plaszczyzny.
	local door = part({
		Name = "LockerDoor",
		Size = Vector3.new(14.4, 13.6, 0.8),
		Position = Vector3.new(0, 8.8, -65.6),
		Color = Color3.fromRGB(232, 164, 78),
		Material = Enum.Material.DiamondPlate,
	})
	door.Parent = root

	local handle = part({
		Name = "LockerHandle",
		Size = Vector3.new(1, 3.4, 0.6),
		Position = Vector3.new(5.2, 8.8, -65),
		Color = Color3.fromRGB(60, 56, 62),
		Material = Enum.Material.Metal,
	})
	handle.Parent = root

	-- Neonowa rama nad lockerem.
	local arch = part({
		Name = "AuctionArch",
		Size = Vector3.new(20, 1.2, 1.2),
		Position = Vector3.new(0, 19.4, -66),
		Color = PALETTE.Auction,
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	arch.Parent = root

	sign(body, "AUKCJA LOCKEROW", 11.5, PALETTE.Auction)
	lockerInfo = sign(body, "Czekam na aukcje...", 8.4, PALETTE.Auction, "Info")
	if lockerInfo then
		lockerInfo.TextColor3 = Color3.fromRGB(255, 214, 150)
	end

	local bidPrompt = makePrompt(door, "BidPrompt", "Podbij oferte", "Locker", Enum.KeyCode.E, Vector3.new(0, -2, 2))
	bidPrompt.Triggered:Connect(function(player)
		WorldService.onBid(player)
	end)
end

local function buildCleaning()
	local platform = part({
		Name = "CleaningPlatform",
		Size = Vector3.new(26, 1.2, 20),
		Position = Vector3.new(-64, 0.6, 0),
		Color = PALETTE.FloorTrim,
		Material = Enum.Material.Concrete,
	})
	platform.Parent = root

	local bench = part({
		Name = "CleaningBench",
		Size = Vector3.new(18, 3.4, 9),
		Position = Vector3.new(-64, 3.9, 0),
		Color = Color3.fromRGB(96, 172, 184),
		Material = Enum.Material.Metal,
	})
	bench.Parent = root

	local basin = part({
		Name = "Basin",
		Size = Vector3.new(7, 1.2, 5),
		Position = Vector3.new(-67, 6, 0),
		Color = Color3.fromRGB(150, 225, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
	})
	basin.Parent = root

	for index = 1, 3 do
		local bottle = part({
			Name = "Bottle",
			Size = Vector3.new(1.4, 3, 1.4),
			Position = Vector3.new(-58 + index * 1.8, 7.1, -2.4),
			Color = Color3.fromRGB(120, 235, 190),
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		bottle.Parent = root
	end

	local backboard = part({
		Name = "CleaningBoard",
		Size = Vector3.new(20, 12, 1),
		Position = Vector3.new(-73, 8, 0),
		Color = PALETTE.WallTrim,
		Material = Enum.Material.Metal,
		Orientation = Vector3.new(0, 90, 0),
	})
	backboard.Parent = root

	sign(bench, "CZYSZCZENIE", 7.4, PALETTE.Cleaning)
	benchInfo = sign(bench, "Brak brudnych przedmiotow", 4.6, PALETTE.Cleaning, "Info")
	if benchInfo then
		benchInfo.TextColor3 = Color3.fromRGB(170, 235, 245)
	end

	local scrubPrompt = makePrompt(bench, "ScrubPrompt", "Czysc przedmiot", "Stol", Enum.KeyCode.E, Vector3.new(0, 0, 5.5))
	scrubPrompt.Triggered:Connect(function(player)
		WorldService.onScrub(player)
	end)
end

local function buildShop()
	local platform = part({
		Name = "ShopPlatform",
		Size = Vector3.new(30, 1.2, 22),
		Position = Vector3.new(62, 0.6, -6),
		Color = PALETTE.FloorTrim,
		Material = Enum.Material.Concrete,
	})
	platform.Parent = root

	local counter = part({
		Name = "ShopCounter",
		Size = Vector3.new(20, 4.2, 9),
		Position = Vector3.new(62, 4.3, -6),
		Color = Color3.fromRGB(150, 96, 200),
		Material = Enum.Material.Wood,
	})
	counter.Parent = root

	local top = part({
		Name = "CounterTop",
		Size = Vector3.new(21.5, 0.6, 10.5),
		Position = Vector3.new(62, 6.7, -6),
		Color = Color3.fromRGB(58, 52, 70),
		Material = Enum.Material.Marble,
	})
	top.Parent = root

	local register = part({
		Name = "Register",
		Size = Vector3.new(3, 2, 2.4),
		Position = Vector3.new(56, 8, -6),
		Color = Color3.fromRGB(238, 196, 96),
		Material = Enum.Material.Metal,
	})
	register.Parent = root

	local neonStrip = part({
		Name = "ShopNeon",
		Size = Vector3.new(20, 0.8, 0.8),
		Position = Vector3.new(62, 14.6, -10.5),
		Color = PALETTE.Shop,
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	neonStrip.Parent = root

	sign(counter, "LOMBARD", 8.4, PALETTE.Shop)
	shopInfo = sign(counter, "Pusto", 5.4, PALETTE.Shop, "Info")
	if shopInfo then
		shopInfo.TextColor3 = Color3.fromRGB(226, 196, 255)
	end

	local sellPrompt = makePrompt(counter, "SellPrompt", "Sprzedaj wszystko", "Kasa", Enum.KeyCode.E, Vector3.new(-6, 0, 5.5))
	sellPrompt.Triggered:Connect(function(player)
		WorldService.onSellAll(player)
	end)

	local displayPrompt = makePrompt(counter, "DisplayPrompt", "Wystaw na polke", "Ekspozycja", Enum.KeyCode.F, Vector3.new(6, 0, 5.5))
	displayPrompt.Triggered:Connect(function(player)
		WorldService.onDisplay(player)
	end)

	shelvesFolder = Instance.new("Folder")
	shelvesFolder.Name = "Shelves"
	shelvesFolder.Parent = root

	-- Postumenty w dwoch rzedach za kasa, kazdy z neonowa obrecza.
	for index = 1, Config.Shop.DisplaySlots do
		local column = (index - 1) % 6
		local row = math.floor((index - 1) / 6)
		local position = Vector3.new(44 + column * 7, 2, 16 + row * 12)

		local pedestal = part({
			Name = string.format("Slot%02d", index),
			Size = Vector3.new(4.5, 4, 4.5),
			Position = position,
			Color = Color3.fromRGB(64, 60, 80),
			Material = Enum.Material.Slate,
		})
		pedestal.Parent = shelvesFolder

		local rim = part({
			Name = "Rim",
			Size = Vector3.new(5.2, 0.3, 5.2),
			Position = position + Vector3.new(0, 2.2, 0),
			Color = PALETTE.Shop,
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		rim.Parent = pedestal
	end
end

-- Interakcje ---------------------------------------------------------------

function WorldService.onBid(player: Player)
	local lot = AuctionService.getActiveLot()
	if not lot then
		return notify(player, "Teraz nie ma aukcji. Napisz /aukcja albo poczekaj.")
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

	local pedestals = {}
	for _, child in shelvesFolder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(pedestals, child)
		end
	end
	table.sort(pedestals, function(a, b)
		return a.Name < b.Name
	end)

	for index, pedestal in pedestals do
		local existing = pedestal:FindFirstChild("Trophy")
		if existing then
			existing:Destroy()
		end

		local item = profile and profile.Displayed[index]
		if item then
			local rarity = Loot.rarityById(item.Rarity)
			local trophy = part({
				Name = "Trophy",
				Size = Vector3.new(2.6, 2.6, 2.6),
				Position = pedestal.Position + Vector3.new(0, 3.6, 0),
				Color = rarity.Color,
				Material = Enum.Material.Neon,
				CastShadow = false,
			})
			trophy.Parent = pedestal

			local glow = Instance.new("PointLight")
			glow.Color = rarity.Color
			glow.Brightness = 1.6
			glow.Range = 12
			glow.Parent = trophy

			sign(trophy, string.format("%s  $%d", item.Name, item.Value), 2.6, rarity.Color)
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

	clearTemplate()
	setupLighting()

	root = Instance.new("Folder")
	root.Name = "CursedStorageWorld"
	root.Parent = Workspace

	buildGround()
	buildWalls()
	buildDecor()
	buildAuction()
	buildCleaning()
	buildShop()

	task.spawn(refreshLoop)

	print("[CursedStorage] Swiat zbudowany.")
end

return WorldService
