--!strict
-- Swiat: otwarty plac skladowy pod gola przestrzenia.
-- Zero pudelka ze scian, zero widocznego Baseplate - teren jest ogromny,
-- a horyzont zamyka panorama miasta i wzgorza.
-- Mapa jest wspolna, ale kazdy gracz dostaje wlasne stanowisko lombardu.

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
local lockerInfo: TextLabel?
local benchInfo: TextLabel?

-- Stanowiska graczy --------------------------------------------------------

type Stall = {
	Index: number,
	Owner: Player?,
	Origin: Vector3,
	Rotation: number,
	Model: Model,
	NameLabel: TextLabel,
	InfoLabel: TextLabel,
	Pedestals: { BasePart },
}

local stalls: { Stall } = {}
local stallByUserId: { [number]: Stall } = {}

local STALL_COUNT = 6
local SLOTS_PER_STALL = 6
local GROUND_HALF = 1024
local YARD_HALF = 190

local PALETTE = {
	Ground = Color3.fromRGB(96, 112, 78),
	Yard = Color3.fromRGB(72, 70, 76),
	YardTrim = Color3.fromRGB(52, 50, 56),
	Road = Color3.fromRGB(58, 56, 60),
	Auction = Color3.fromRGB(255, 150, 60),
	Cleaning = Color3.fromRGB(70, 190, 210),
	Shop = Color3.fromRGB(180, 110, 255),
	Metal = Color3.fromRGB(116, 112, 122),
	Crate = Color3.fromRGB(150, 108, 66),
	ContainerA = Color3.fromRGB(186, 84, 64),
	ContainerB = Color3.fromRGB(64, 112, 150),
	ContainerC = Color3.fromRGB(196, 156, 62),
	City = Color3.fromRGB(62, 66, 82),
	Hill = Color3.fromRGB(78, 96, 70),
}

local function notify(player: Player, message: string)
	Remotes.event("Notify"):FireClient(player, message)
end

local function part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	if parent then
		p.Parent = parent
	else
		p.Parent = root
	end
	return p
end

local function sign(parent: BasePart, text: string, offsetY: number, accent: Color3, name: string?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = (name or "Caption") .. "Gui"
	gui.Size = UDim2.new(0, 340, 0, 68)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 150
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
	constraint.MaxTextSize = 26
	constraint.Parent = label

	return label
end

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
	anchor.Position = offset or Vector3.zero
	anchor.Parent = parent

	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 11
	p.RequiresLineOfSight = false
	p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	p.KeyboardKeyCode = key
	p.Parent = anchor
	return p
end

local function neonLight(host: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Parent = host
end

-- Czyszczenie szablonu -----------------------------------------------------
-- Baseplate ze startowego projektu byl w tej samej plaszczyznie co nasza
-- podloga (migotanie) i konczyl sie na 512 studach (widoczna krawedz).

local function clearTemplate()
	for _, child in Workspace:GetChildren() do
		if
			child.Name == "Baseplate"
			or child.Name == "CursedStorageWorld"
			or child:IsA("SpawnLocation")
			or (child:IsA("BasePart") and child.Size.X >= 400 and child.Size.Y <= 40)
		then
			child:Destroy()
		end
	end
end

local function setupLighting()
	Lighting.ClockTime = 15.6
	Lighting.GeographicLatitude = 22
	Lighting.Brightness = 2.6
	Lighting.ExposureCompensation = 0.2
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.Ambient = Color3.fromRGB(84, 80, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 130, 148)
	Lighting.FogEnd = 1600
	Lighting.FogStart = 600
	Lighting.FogColor = Color3.fromRGB(178, 184, 196)

	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = Lighting
	end
	sky.StarCount = 3000
	sky.SunAngularSize = 12
	sky.MoonAngularSize = 9

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.35
	atmosphere.Offset = 0.2
	atmosphere.Haze = 1.8
	atmosphere.Glare = 0.25
	atmosphere.Color = Color3.fromRGB(210, 204, 194)
	atmosphere.Decay = Color3.fromRGB(104, 112, 128)

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.05

	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not grade then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Parent = Lighting
	end
	grade.Saturation = 0.12
	grade.Contrast = 0.08
	grade.TintColor = Color3.fromRGB(255, 249, 240)
end

-- Teren --------------------------------------------------------------------

local function buildGround()
	-- Ogromna plyta trawy. Dzieki 2048 studom krawedzi nie widac nawet
	-- przy maksymalnie odsunietej kamerze.
	part({
		Name = "Ground",
		Size = Vector3.new(GROUND_HALF * 2, 8, GROUND_HALF * 2),
		Position = Vector3.new(0, -4, 0),
		Color = PALETTE.Ground,
		Material = Enum.Material.Grass,
	})

	-- Plac skladowy: asfalt podniesiony o 0.1, wiec zadnego z-fightingu.
	part({
		Name = "Yard",
		Size = Vector3.new(YARD_HALF * 2, 1, YARD_HALF * 2),
		Position = Vector3.new(0, 0.1, 0),
		Color = PALETTE.Yard,
		Material = Enum.Material.Asphalt,
	})

	-- Krawezniki placu.
	for _, spec in
		{
			{ Vector3.new(0, 0.8, -YARD_HALF), Vector3.new(YARD_HALF * 2, 1.4, 3) },
			{ Vector3.new(0, 0.8, YARD_HALF), Vector3.new(YARD_HALF * 2, 1.4, 3) },
			{ Vector3.new(-YARD_HALF, 0.8, 0), Vector3.new(3, 1.4, YARD_HALF * 2) },
			{ Vector3.new(YARD_HALF, 0.8, 0), Vector3.new(3, 1.4, YARD_HALF * 2) },
		}
	do
		part({
			Name = "Curb",
			Size = spec[2] :: Vector3,
			Position = spec[1] :: Vector3,
			Color = PALETTE.YardTrim,
			Material = Enum.Material.Concrete,
		})
	end

	-- Malowane pasy prowadzace do stanowisk.
	for index = 0, 5 do
		local angle = math.rad(index * 60)
		part({
			Name = "Lane",
			Size = Vector3.new(8, 0.15, 150),
			CFrame = CFrame.new(Vector3.new(math.sin(angle) * 78, 0.68, math.cos(angle) * 78))
				* CFrame.fromOrientation(0, angle, 0),
			Color = Color3.fromRGB(150, 146, 120),
			Material = Enum.Material.Concrete,
			Transparency = 0.45,
			CastShadow = false,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(22, 0.6, 22)
	spawn.Position = Vector3.new(0, 0.9, 44)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(255, 196, 96)
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Parent = root
	neonLight(spawn, Color3.fromRGB(255, 200, 120), 2, 26)
end

-- Tlo: panorama i wzgorza. Bez scian, wiec plac nie jest pudelkiem.
local function buildSkyline()
	local backdrop = Instance.new("Folder")
	backdrop.Name = "Backdrop"
	backdrop.Parent = root

	local random = Random.new(1337)

	for index = 1, 54 do
		local angle = (index / 54) * math.pi * 2
		local distance = 520 + random:NextNumber(0, 160)
		local height = random:NextNumber(60, 260)
		local width = random:NextNumber(40, 90)

		local tower = part({
			Name = "Tower",
			Size = Vector3.new(width, height, width),
			CFrame = CFrame.new(Vector3.new(math.sin(angle) * distance, height / 2, math.cos(angle) * distance))
				* CFrame.fromOrientation(0, angle, 0),
			Color = PALETTE.City:Lerp(Color3.fromRGB(120, 126, 148), random:NextNumber()),
			Material = Enum.Material.Concrete,
			CastShadow = false,
		}, backdrop)

		if random:NextNumber() > 0.55 then
			local beacon = part({
				Name = "Beacon",
				Size = Vector3.new(4, 4, 4),
				Position = tower.Position + Vector3.new(0, height / 2 + 3, 0),
				Color = Color3.fromRGB(255, 120, 110),
				Material = Enum.Material.Neon,
				CastShadow = false,
			}, backdrop)
			neonLight(beacon, Color3.fromRGB(255, 120, 110), 1.4, 40)
		end
	end

	-- Wzgorza zasypuja horyzont miedzy wiezami.
	for index = 1, 24 do
		local angle = (index / 24) * math.pi * 2 + 0.12
		local distance = 760 + random:NextNumber(0, 120)
		local size = random:NextNumber(220, 380)
		local hill = Instance.new("Part")
		hill.Name = "Hill"
		hill.Shape = Enum.PartType.Ball
		hill.Anchored = true
		hill.CastShadow = false
		hill.Size = Vector3.new(size, size * 0.7, size)
		hill.Position = Vector3.new(math.sin(angle) * distance, -size * 0.22, math.cos(angle) * distance)
		hill.Color = PALETTE.Hill:Lerp(Color3.fromRGB(110, 132, 98), random:NextNumber())
		hill.Material = Enum.Material.Grass
		hill.Parent = backdrop
	end
end

-- Kontenery i dekoracje placu ---------------------------------------------

local function container(position: Vector3, rotation: number, color: Color3)
	local body = part({
		Name = "Container",
		Size = Vector3.new(34, 14, 12),
		CFrame = CFrame.new(position) * CFrame.fromOrientation(0, math.rad(rotation), 0),
		Color = color,
		Material = Enum.Material.CorrodedMetal,
	})

	for _, side in { -1, 1 } do
		part({
			Name = "ContainerRib",
			Size = Vector3.new(1.2, 14.4, 12.6),
			CFrame = body.CFrame * CFrame.new(side * 16, 0, 0),
			Color = color:Lerp(Color3.new(0, 0, 0), 0.25),
			Material = Enum.Material.DiamondPlate,
		})
	end

	return body
end

local function buildYardProps()
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = root

	local random = Random.new(77)

	local containers = {
		{ Vector3.new(-150, 7.6, -120), 12, PALETTE.ContainerA },
		{ Vector3.new(-146, 21.6, -120), 12, PALETTE.ContainerB },
		{ Vector3.new(-120, 7.6, -158), 74, PALETTE.ContainerC },
		{ Vector3.new(150, 7.6, -132), -18, PALETTE.ContainerB },
		{ Vector3.new(154, 21.6, -132), -18, PALETTE.ContainerA },
		{ Vector3.new(160, 7.6, 120), 96, PALETTE.ContainerC },
		{ Vector3.new(-160, 7.6, 130), 84, PALETTE.ContainerA },
		{ Vector3.new(-30, 7.6, 168), 4, PALETTE.ContainerB },
		{ Vector3.new(40, 7.6, 170), -6, PALETTE.ContainerC },
	}
	for _, spec in containers do
		container(spec[1] :: Vector3, spec[2] :: number, spec[3] :: Color3)
	end

	-- Skrzynie, palety, beczki.
	for index = 1, 34 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(95, 178)
		local position = Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance)
		local kind = random:NextInteger(1, 3)

		if kind == 1 then
			local size = random:NextNumber(5, 8)
			part({
				Name = "Crate",
				Size = Vector3.new(size, size, size),
				CFrame = CFrame.new(position + Vector3.new(0, size / 2 + 0.6, 0))
					* CFrame.fromOrientation(0, random:NextNumber(0, math.pi), 0),
				Color = PALETTE.Crate,
				Material = Enum.Material.WoodPlanks,
			}, props)
		elseif kind == 2 then
			local barrel = Instance.new("Part")
			barrel.Name = "Barrel"
			barrel.Shape = Enum.PartType.Cylinder
			barrel.Anchored = true
			barrel.Size = Vector3.new(6, 4, 4)
			barrel.CFrame = CFrame.new(position + Vector3.new(0, 3.6, 0)) * CFrame.fromOrientation(0, 0, math.rad(90))
			barrel.Color = Color3.fromRGB(96, 132, 96)
			barrel.Material = Enum.Material.Metal
			barrel.Parent = props
		else
			part({
				Name = "Pallet",
				Size = Vector3.new(9, 0.8, 7),
				CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
					* CFrame.fromOrientation(0, random:NextNumber(0, math.pi), 0),
				Color = Color3.fromRGB(158, 126, 84),
				Material = Enum.Material.WoodPlanks,
			}, props)
		end
	end

	-- Latarnie placu.
	for index = 0, 7 do
		local angle = math.rad(index * 45 + 22)
		local base = Vector3.new(math.sin(angle) * 150, 0, math.cos(angle) * 150)
		part({
			Name = "LampPost",
			Size = Vector3.new(1.6, 34, 1.6),
			Position = base + Vector3.new(0, 17, 0),
			Color = PALETTE.Metal,
			Material = Enum.Material.Metal,
		}, props)
		local head = part({
			Name = "LampHead",
			Size = Vector3.new(7, 1.2, 3.4),
			Position = base + Vector3.new(0, 34.4, 0),
			Color = Color3.fromRGB(255, 234, 190),
			Material = Enum.Material.Neon,
			CastShadow = false,
		}, props)
		neonLight(head, Color3.fromRGB(255, 226, 180), 2.4, 60)
	end
end

-- Hala aukcyjna: zadaszenie na filarach, otwarta z kazdej strony ----------

local function buildAuctionHall()
	local hall = Instance.new("Folder")
	hall.Name = "AuctionHall"
	hall.Parent = root

	local center = Vector3.new(0, 0, -96)

	part({
		Name = "Stage",
		Size = Vector3.new(76, 2.4, 48),
		Position = center + Vector3.new(0, 1.2, 0),
		Color = Color3.fromRGB(64, 60, 68),
		Material = Enum.Material.Concrete,
	}, hall)

	part({
		Name = "StageTrim",
		Size = Vector3.new(78, 0.6, 50),
		Position = center + Vector3.new(0, 2.6, 0),
		Color = PALETTE.Auction,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CastShadow = false,
	}, hall)

	-- Filary + dach tylko nad scena.
	for _, offset in
		{
			Vector3.new(-34, 0, -20),
			Vector3.new(34, 0, -20),
			Vector3.new(-34, 0, 20),
			Vector3.new(34, 0, 20),
		}
	do
		part({
			Name = "Pillar",
			Size = Vector3.new(4, 40, 4),
			Position = center + offset + Vector3.new(0, 20, 0),
			Color = PALETTE.YardTrim,
			Material = Enum.Material.Concrete,
		}, hall)
	end

	part({
		Name = "Canopy",
		Size = Vector3.new(80, 2, 52),
		Position = center + Vector3.new(0, 41, 0),
		Color = Color3.fromRGB(58, 56, 64),
		Material = Enum.Material.Metal,
	}, hall)

	for index = -2, 2 do
		part({
			Name = "CanopyBeam",
			Size = Vector3.new(82, 1.4, 2),
			Position = center + Vector3.new(0, 39.4, index * 11),
			Color = PALETTE.Metal,
			Material = Enum.Material.Metal,
			CastShadow = false,
		}, hall)
	end

	-- Locker na scenie.
	local body = part({
		Name = "LockerBody",
		Size = Vector3.new(18, 18, 14),
		Position = center + Vector3.new(0, 11.4, -8),
		Color = Color3.fromRGB(196, 120, 48),
		Material = Enum.Material.CorrodedMetal,
	}, hall)

	local door = part({
		Name = "LockerDoor",
		Size = Vector3.new(16.4, 15.6, 0.9),
		Position = center + Vector3.new(0, 10.4, -0.6),
		Color = Color3.fromRGB(232, 164, 78),
		Material = Enum.Material.DiamondPlate,
	}, hall)

	part({
		Name = "LockerHandle",
		Size = Vector3.new(1.2, 4, 0.8),
		Position = center + Vector3.new(6, 10.4, 0),
		Color = Color3.fromRGB(58, 54, 60),
		Material = Enum.Material.Metal,
	}, hall)

	-- Neonowy szyld i reflektory.
	local arch = part({
		Name = "Arch",
		Size = Vector3.new(48, 1.6, 1.6),
		Position = center + Vector3.new(0, 30, 4),
		Color = PALETTE.Auction,
		Material = Enum.Material.Neon,
		CastShadow = false,
	}, hall)
	neonLight(arch, PALETTE.Auction, 3, 80)

	for _, x in { -22, 22 } do
		local spotHousing = part({
			Name = "Spot",
			Size = Vector3.new(4, 3, 4),
			Position = center + Vector3.new(x, 36, 8),
			Color = Color3.fromRGB(36, 34, 40),
			Material = Enum.Material.Metal,
		}, hall)
		local spot = Instance.new("SpotLight")
		spot.Angle = 70
		spot.Brightness = 4
		spot.Range = 70
		spot.Face = Enum.NormalId.Bottom
		spot.Color = Color3.fromRGB(255, 226, 180)
		spot.Parent = spotHousing
	end

	-- Trybuny dla graczy.
	for row = 1, 3 do
		part({
			Name = "Bleacher",
			Size = Vector3.new(70, 3, 8),
			Position = center + Vector3.new(0, 1.5 + (row - 1) * 3, 30 + row * 8),
			Color = Color3.fromRGB(78, 74, 84),
			Material = Enum.Material.Concrete,
		}, hall)
	end

	sign(body, "AUKCJA LOCKEROW", 13, PALETTE.Auction)
	lockerInfo = sign(body, "Czekam na aukcje...", 10, PALETTE.Auction, "Info")
	if lockerInfo then
		lockerInfo.TextColor3 = Color3.fromRGB(255, 214, 150)
	end

	local bid = makePrompt(door, "BidPrompt", "Podbij oferte", "Locker", Enum.KeyCode.E, Vector3.new(0, -3, 2))
	bid.Triggered:Connect(function(player)
		WorldService.onBid(player)
	end)
end

-- Warsztat czyszczenia -----------------------------------------------------

local function buildCleaningShed()
	local shed = Instance.new("Folder")
	shed.Name = "CleaningShed"
	shed.Parent = root

	local center = Vector3.new(-104, 0, 6)

	part({
		Name = "Deck",
		Size = Vector3.new(42, 1.8, 34),
		Position = center + Vector3.new(0, 0.9, 0),
		Color = Color3.fromRGB(66, 70, 74),
		Material = Enum.Material.Concrete,
	}, shed)

	-- Tylna sciana + dach, front otwarty.
	part({
		Name = "BackWall",
		Size = Vector3.new(2, 22, 34),
		Position = center + Vector3.new(-21, 11, 0),
		Color = Color3.fromRGB(88, 92, 98),
		Material = Enum.Material.Metal,
	}, shed)

	part({
		Name = "Roof",
		Size = Vector3.new(44, 1.4, 36),
		Position = center + Vector3.new(0, 22.5, 0),
		Color = Color3.fromRGB(70, 118, 130),
		Material = Enum.Material.Metal,
	}, shed)

	for _, offset in { Vector3.new(20, 0, -16), Vector3.new(20, 0, 16) } do
		part({
			Name = "Post",
			Size = Vector3.new(2.4, 22, 2.4),
			Position = center + offset + Vector3.new(0, 11, 0),
			Color = PALETTE.Metal,
			Material = Enum.Material.Metal,
		}, shed)
	end

	local bench = part({
		Name = "CleaningBench",
		Size = Vector3.new(20, 3.6, 10),
		Position = center + Vector3.new(0, 3.6, 6),
		Color = Color3.fromRGB(96, 172, 184),
		Material = Enum.Material.Metal,
	}, shed)

	part({
		Name = "Basin",
		Size = Vector3.new(8, 1.4, 6),
		Position = center + Vector3.new(-5, 6.2, 6),
		Color = Color3.fromRGB(150, 225, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
	}, shed)

	for index = 1, 4 do
		local bottle = part({
			Name = "Bottle",
			Size = Vector3.new(1.5, 3.2, 1.5),
			Position = center + Vector3.new(2 + index * 2.2, 7, 4),
			Color = Color3.fromRGB(120, 235, 190),
			Material = Enum.Material.Neon,
			CastShadow = false,
		}, shed)
		neonLight(bottle, Color3.fromRGB(120, 235, 190), 1, 14)
	end

	local neon = part({
		Name = "Neon",
		Size = Vector3.new(26, 1.2, 1.2),
		Position = center + Vector3.new(0, 20, 17),
		Color = PALETTE.Cleaning,
		Material = Enum.Material.Neon,
		CastShadow = false,
	}, shed)
	neonLight(neon, PALETTE.Cleaning, 2.4, 60)

	sign(bench, "CZYSZCZENIE", 8, PALETTE.Cleaning)
	benchInfo = sign(bench, "Brak brudnych przedmiotow", 5.2, PALETTE.Cleaning, "Info")
	if benchInfo then
		benchInfo.TextColor3 = Color3.fromRGB(170, 235, 245)
	end

	local scrub = makePrompt(bench, "ScrubPrompt", "Czysc przedmiot", "Stol", Enum.KeyCode.E, Vector3.new(0, 0, 6))
	scrub.Triggered:Connect(function(player)
		WorldService.onScrub(player)
	end)
end

-- Stanowiska graczy --------------------------------------------------------

local function buildStall(index: number): Stall
	local angle = math.rad(-150 + (index - 1) * 60)
	local origin = Vector3.new(math.sin(angle) * 118, 0, math.cos(angle) * 118)
	local facing = CFrame.new(origin) * CFrame.fromOrientation(0, angle + math.pi, 0)

	local model = Instance.new("Model")
	model.Name = string.format("Stall%02d", index)
	model.Parent = root

	local deck = part({
		Name = "Deck",
		Size = Vector3.new(38, 1.6, 30),
		CFrame = facing * CFrame.new(0, 0.8, 0),
		Color = Color3.fromRGB(68, 64, 76),
		Material = Enum.Material.Concrete,
	}, model)
	model.PrimaryPart = deck

	part({
		Name = "DeckTrim",
		Size = Vector3.new(40, 0.5, 32),
		CFrame = facing * CFrame.new(0, 1.9, 0),
		Color = PALETTE.Shop,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CastShadow = false,
	}, model)

	-- Zadaszenie na dwoch slupach, front calkowicie otwarty.
	for _, x in { -17, 17 } do
		part({
			Name = "Post",
			Size = Vector3.new(2, 20, 2),
			CFrame = facing * CFrame.new(x, 10, -13),
			Color = PALETTE.Metal,
			Material = Enum.Material.Metal,
		}, model)
	end

	part({
		Name = "BackWall",
		Size = Vector3.new(38, 20, 1.6),
		CFrame = facing * CFrame.new(0, 10, -14.5),
		Color = Color3.fromRGB(84, 80, 94),
		Material = Enum.Material.Brick,
	}, model)

	part({
		Name = "Roof",
		Size = Vector3.new(40, 1.4, 32),
		CFrame = facing * CFrame.new(0, 20.6, 0),
		Color = Color3.fromRGB(72, 64, 92),
		Material = Enum.Material.Metal,
	}, model)

	local counter = part({
		Name = "Counter",
		Size = Vector3.new(22, 4.4, 8),
		CFrame = facing * CFrame.new(0, 3.8, 9),
		Color = Color3.fromRGB(150, 96, 200),
		Material = Enum.Material.Wood,
	}, model)

	part({
		Name = "CounterTop",
		Size = Vector3.new(23.5, 0.6, 9.6),
		CFrame = facing * CFrame.new(0, 6.3, 9),
		Color = Color3.fromRGB(54, 50, 66),
		Material = Enum.Material.Marble,
	}, model)

	part({
		Name = "Register",
		Size = Vector3.new(3.2, 2.2, 2.6),
		CFrame = facing * CFrame.new(-7, 7.6, 9),
		Color = Color3.fromRGB(238, 196, 96),
		Material = Enum.Material.Metal,
	}, model)

	local neon = part({
		Name = "Neon",
		Size = Vector3.new(30, 1.2, 1.2),
		CFrame = facing * CFrame.new(0, 18.4, 13),
		Color = PALETTE.Shop,
		Material = Enum.Material.Neon,
		CastShadow = false,
	}, model)
	neonLight(neon, PALETTE.Shop, 2.4, 55)

	local nameLabel = sign(counter, string.format("WOLNY LOMBARD #%d", index), 9.5, PALETTE.Shop, "Owner")
	local infoLabel = sign(counter, "Podejdz i zajmij stanowisko", 6.6, PALETTE.Shop, "Info")
	infoLabel.TextColor3 = Color3.fromRGB(226, 196, 255)

	-- Postumenty ekspozycji: dwa rzedy po trzy, za lada.
	local pedestals: { BasePart } = {}
	for slot = 1, SLOTS_PER_STALL do
		local column = (slot - 1) % 3
		local row = math.floor((slot - 1) / 3)
		local pedestal = part({
			Name = string.format("Slot%02d", slot),
			Size = Vector3.new(5, 4.2, 5),
			CFrame = facing * CFrame.new(-8 + column * 8, 3.7, -2 - row * 8),
			Color = Color3.fromRGB(62, 58, 78),
			Material = Enum.Material.Slate,
		}, model)

		part({
			Name = "Rim",
			Size = Vector3.new(5.8, 0.3, 5.8),
			CFrame = pedestal.CFrame * CFrame.new(0, 2.3, 0),
			Color = PALETTE.Shop,
			Material = Enum.Material.Neon,
			CastShadow = false,
		}, pedestal)

		table.insert(pedestals, pedestal)
	end

	local stall: Stall = {
		Index = index,
		Owner = nil,
		Origin = origin,
		Rotation = angle,
		Model = model,
		NameLabel = nameLabel,
		InfoLabel = infoLabel,
		Pedestals = pedestals,
	}

	local claim = makePrompt(counter, "ClaimPrompt", "Zajmij lombard", "Stanowisko", Enum.KeyCode.R, Vector3.new(0, 0, 5.5))
	claim.Triggered:Connect(function(player)
		WorldService.onClaim(player, stall)
	end)

	local sell = makePrompt(counter, "SellPrompt", "Sprzedaj wszystko", "Kasa", Enum.KeyCode.E, Vector3.new(-8, 0, 5.5))
	sell.Triggered:Connect(function(player)
		WorldService.onSellAll(player, stall)
	end)

	local display = makePrompt(counter, "DisplayPrompt", "Wystaw na polke", "Ekspozycja", Enum.KeyCode.F, Vector3.new(8, 0, 5.5))
	display.Triggered:Connect(function(player)
		WorldService.onDisplay(player, stall)
	end)

	return stall
end

local function buildStalls()
	for index = 1, STALL_COUNT do
		table.insert(stalls, buildStall(index))
	end
end

local function stallOf(player: Player): Stall?
	return stallByUserId[player.UserId]
end

local function clearPedestal(pedestal: BasePart)
	local trophy = pedestal:FindFirstChild("Trophy")
	if trophy then
		trophy:Destroy()
	end
end

local function refreshStall(stall: Stall)
	local owner = stall.Owner
	local profile = owner and ProfileService.get(owner)

	if owner and profile then
		stall.NameLabel.Text = string.upper(owner.DisplayName) .. " - LOMBARD"
		stall.InfoLabel.Text = string.format(
			"Wystawione: %d/%d | Gotowka: $%d",
			#profile.Displayed,
			SLOTS_PER_STALL,
			profile.Balance
		)
	else
		stall.NameLabel.Text = string.format("WOLNY LOMBARD #%d", stall.Index)
		stall.InfoLabel.Text = "Podejdz i wcisnij R, zeby zajac"
	end

	for slot, pedestal in stall.Pedestals do
		clearPedestal(pedestal)
		local item = profile and profile.Displayed[slot]
		if item then
			local rarity = Loot.rarityById(item.Rarity)
			local trophy = part({
				Name = "Trophy",
				Size = Vector3.new(2.8, 2.8, 2.8),
				CFrame = pedestal.CFrame * CFrame.new(0, 3.8, 0),
				Color = rarity.Color,
				Material = Enum.Material.Neon,
				CastShadow = false,
			}, pedestal)
			neonLight(trophy, rarity.Color, 1.8, 14)
			sign(trophy, string.format("%s  $%d", item.Name, item.Value), 2.8, rarity.Color)
		end
	end
end

function WorldService.assignStall(player: Player): Stall?
	local existing = stallOf(player)
	if existing then
		return existing
	end

	for _, stall in stalls do
		if not stall.Owner then
			stall.Owner = player
			stallByUserId[player.UserId] = stall
			refreshStall(stall)
			notify(player, string.format("Dostales lombard #%d. Szukaj swojego neonu.", stall.Index))
			return stall
		end
	end

	notify(player, "Wszystkie lombardy zajete - mozesz handlowac przy dowolnej ladzie.")
	return nil
end

function WorldService.releaseStall(player: Player)
	local stall = stallOf(player)
	if not stall then
		return
	end
	stall.Owner = nil
	stallByUserId[player.UserId] = nil
	refreshStall(stall)
end

function WorldService.onClaim(player: Player, stall: Stall)
	local current = stallOf(player)
	if current == stall then
		return notify(player, "To juz twoje stanowisko.")
	end
	if stall.Owner then
		return notify(player, string.format("Zajete przez %s.", stall.Owner.DisplayName))
	end

	if current then
		current.Owner = nil
		refreshStall(current)
	end

	stall.Owner = player
	stallByUserId[player.UserId] = stall
	refreshStall(stall)
	notify(player, string.format("Zajales lombard #%d.", stall.Index))
end

-- Interakcje ---------------------------------------------------------------

function WorldService.onBid(player: Player)
	local lot = AuctionService.getActiveLot()
	if not lot then
		return notify(player, "Teraz nie ma aukcji. Nastepna startuje automatycznie.")
	end
	AuctionService.bid(player, lot.LotId, (tonumber(lot.HighestBid) or 0) + Config.Auction.MinBidStep)
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

function WorldService.onSellAll(player: Player, stall: Stall?)
	if stall and stall.Owner and stall.Owner ~= player then
		return notify(player, "To nie twoja kasa.")
	end

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

function WorldService.onDisplay(player: Player, stall: Stall?)
	local own = stallOf(player)
	if stall and own and stall ~= own then
		return notify(player, "Wystawiac mozesz tylko we wlasnym lombardzie.")
	end
	if not own then
		own = WorldService.assignStall(player)
		if not own then
			return
		end
	end

	local profile = ProfileService.get(player)
	if not profile then
		return
	end
	if #profile.Displayed >= SLOTS_PER_STALL then
		return notify(player, "Wszystkie polki zajete. Sprzedaj cos, zeby zrobic miejsce.")
	end

	local bestIndex: number? = nil
	local bestValue = -1
	for index, item in profile.Inventory do
		if not item.Dirty and item.Value > bestValue then
			bestIndex = index
			bestValue = item.Value
		end
	end

	if not bestIndex then
		return notify(player, "Najpierw wyczysc przedmiot w warsztacie.")
	end

	local item = table.remove(profile.Inventory, bestIndex)
	table.insert(profile.Displayed, item)
	notify(player, string.format("Wystawione: %s ($%d)", item.Name, item.Value))
	refreshStall(own)
end

function WorldService.setAuctionText(text: string)
	if lockerInfo then
		lockerInfo.Text = text
	end
end

-- Petla odswiezania --------------------------------------------------------

local function refreshTick()
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

	-- Tabliczka warsztatu pokazuje dane najblizszego gracza.
	local shed = root:FindFirstChild("CleaningShed")
	local benchPart = shed and shed:FindFirstChild("CleaningBench") :: BasePart?
	if benchInfo and benchPart then
		local closest: Player? = nil
		local closestDistance = 60
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local rootPart = character and character.PrimaryPart
			if rootPart then
				local distance = (rootPart.Position - benchPart.Position).Magnitude
				if distance < closestDistance then
					closest = player
					closestDistance = distance
				end
			end
		end

		local profile = closest and ProfileService.get(closest)
		if profile then
			local dirty = 0
			for _, item in profile.Inventory do
				if item.Dirty then
					dirty += 1
				end
			end
			benchInfo.Text = string.format("Brudne: %d | Ekwipunek: %d", dirty, #profile.Inventory)
		else
			benchInfo.Text = "Przynies brudne lupy i wcisnij E"
		end
	end

	for _, stall in stalls do
		refreshStall(stall)
	end
end

local function refreshLoop()
	while true do
		task.wait(1.5)
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
	buildSkyline()
	buildYardProps()
	buildAuctionHall()
	buildCleaningShed()
	buildStalls()

	Players.PlayerRemoving:Connect(function(player)
		WorldService.releaseStall(player)
	end)

	task.spawn(refreshLoop)

	print("[CursedStorage] Swiat zbudowany.")
end

return WorldService
