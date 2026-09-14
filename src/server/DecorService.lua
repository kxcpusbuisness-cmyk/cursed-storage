--!strict
-- Warstwa wygladu: nowa paleta, mniejsze napisy na tabliczkach
-- i duzo dodatkow na placu (food truck, targ, arkady, fontanna, zielen).

local Workspace = game:GetService("Workspace")

local DecorService = {}

local root: Instance

-- Nowa paleta: cieplejszy plac, mocniejsze akcenty.
local RECOLOR: { [string]: { Color3 } } = {
	Ground = { Color3.fromRGB(108, 146, 92), Color3.fromRGB(0, 0, 0) },
	Yard = { Color3.fromRGB(74, 72, 88), Color3.fromRGB(0, 0, 0) },
	Curb = { Color3.fromRGB(226, 196, 132), Color3.fromRGB(0, 0, 0) },
	Lane = { Color3.fromRGB(250, 224, 150), Color3.fromRGB(0, 0, 0) },
	Roof = { Color3.fromRGB(198, 86, 96), Color3.fromRGB(0, 0, 0) },
	BackWall = { Color3.fromRGB(112, 104, 132), Color3.fromRGB(0, 0, 0) },
	Counter = { Color3.fromRGB(176, 106, 232), Color3.fromRGB(0, 0, 0) },
	Deck = { Color3.fromRGB(86, 80, 100), Color3.fromRGB(0, 0, 0) },
	Stage = { Color3.fromRGB(78, 68, 92), Color3.fromRGB(0, 0, 0) },
	Bleacher = { Color3.fromRGB(104, 92, 124), Color3.fromRGB(0, 0, 0) },
	Pillar = { Color3.fromRGB(70, 64, 82), Color3.fromRGB(0, 0, 0) },
	Canopy = { Color3.fromRGB(72, 62, 92), Color3.fromRGB(0, 0, 0) },
}

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or root
	return p
end

local function glow(host: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Parent = host
end

-- Tabliczki w swiecie byly ogromne. Tu je zmniejszamy i to samo
-- robimy cyklicznie, bo czesc podpisow tworzy sie na nowo.
local function shrinkSigns()
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BillboardGui") and descendant.Name ~= "Tag" then
			local isTitle = descendant.Name == "CaptionGui" or descendant.Name == "OwnerGui"
			descendant.Size = UDim2.fromOffset(if isTitle then 190 else 210, if isTitle then 34 else 30)
			descendant.MaxDistance = 120
		elseif descendant:IsA("UITextSizeConstraint") then
			descendant.MaxTextSize = 14
		elseif descendant:IsA("TextLabel") and descendant.Parent and descendant.Parent:FindFirstAncestorOfClass("BillboardGui") then
			descendant.Font = Enum.Font.GothamMedium
		end
	end
end

local function recolor()
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			local entry = RECOLOR[descendant.Name]
			if entry then
				descendant.Color = entry[1]
			end
		end
	end
end

-- Zielen: drzewa i krzaki dookola placu.
local function buildGreenery(parent: Instance)
	local random = Random.new(4242)
	for index = 1, 46 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(205, 420)
		local base = Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance)
		local height = random:NextNumber(14, 26)

		part(
			"Trunk",
			Vector3.new(2.4, height, 2.4),
			CFrame.new(base + Vector3.new(0, height / 2, 0)),
			Color3.fromRGB(104, 74, 52),
			Enum.Material.Wood,
			parent
		)

		for leaf = 1, 3 do
			local size = random:NextNumber(12, 20) - leaf * 2
			local crown = Instance.new("Part")
			crown.Name = "Leaves"
			crown.Shape = Enum.PartType.Ball
			crown.Anchored = true
			crown.CanCollide = false
			crown.Size = Vector3.new(size, size * 0.8, size)
			crown.Position = base + Vector3.new(random:NextNumber(-2, 2), height + leaf * 3, random:NextNumber(-2, 2))
			crown.Color = Color3.fromRGB(72, 142, 88):Lerp(Color3.fromRGB(132, 186, 96), random:NextNumber())
			crown.Material = Enum.Material.Grass
			crown.Parent = parent
		end
	end

	for index = 1, 40 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(195, 260)
		local size = random:NextNumber(4, 8)
		local bush = Instance.new("Part")
		bush.Name = "Bush"
		bush.Shape = Enum.PartType.Ball
		bush.Anchored = true
		bush.CanCollide = false
		bush.Size = Vector3.new(size, size * 0.7, size)
		bush.Position = Vector3.new(math.sin(angle) * distance, size * 0.25, math.cos(angle) * distance)
		bush.Color = Color3.fromRGB(84, 148, 92)
		bush.Material = Enum.Material.Grass
		bush.Parent = parent
	end
end

-- Food truck: bo plac musi czyms pachniec.
local function buildFoodTruck(parent: Instance)
	local center = Vector3.new(86, 0, 58)

	part("TruckBody", Vector3.new(26, 11, 12), CFrame.new(center + Vector3.new(0, 6.5, 0)), Color3.fromRGB(248, 140, 108), Enum.Material.Metal, parent)
	part("TruckCab", Vector3.new(9, 8, 11.4), CFrame.new(center + Vector3.new(17, 5, 0)), Color3.fromRGB(236, 96, 88), Enum.Material.Metal, parent)
	part("TruckWindow", Vector3.new(14, 5, 0.6), CFrame.new(center + Vector3.new(-2, 8, 6.2)), Color3.fromRGB(180, 232, 240), Enum.Material.Glass, parent)
	local awning = part("Awning", Vector3.new(16, 0.5, 7), CFrame.new(center + Vector3.new(-2, 11.4, 9.5)) * CFrame.fromOrientation(math.rad(-12), 0, 0), Color3.fromRGB(255, 220, 130), Enum.Material.Fabric, parent)
	glow(awning, Color3.fromRGB(255, 220, 150), 1.6, 26)

	for _, x in { -9, 9 } do
		for _, z in { -6, 6 } do
			local wheel = Instance.new("Part")
			wheel.Name = "Wheel"
			wheel.Shape = Enum.PartType.Cylinder
			wheel.Anchored = true
			wheel.Size = Vector3.new(1.8, 4.4, 4.4)
			wheel.CFrame = CFrame.new(center + Vector3.new(x, 2.2, z)) * CFrame.fromOrientation(0, 0, math.rad(90))
			wheel.Color = Color3.fromRGB(32, 32, 38)
			wheel.Material = Enum.Material.Rubber
			wheel.Parent = parent
		end
	end

	for index = 1, 3 do
		part("PicnicTable", Vector3.new(8, 0.6, 5), CFrame.new(center + Vector3.new(-24 - index * 10, 4, 4)), Color3.fromRGB(206, 154, 96), Enum.Material.WoodPlanks, parent)
		part("TableLeg", Vector3.new(1, 4, 1), CFrame.new(center + Vector3.new(-24 - index * 10, 2, 4)), Color3.fromRGB(120, 116, 128), Enum.Material.Metal, parent)
		local umbrella = part("Umbrella", Vector3.new(10, 0.5, 10), CFrame.new(center + Vector3.new(-24 - index * 10, 10, 4)), Color3.fromRGB(120, 208, 224), Enum.Material.Fabric, parent)
		glow(umbrella, Color3.fromRGB(140, 220, 235), 0.8, 16)
		part("UmbrellaPole", Vector3.new(0.6, 6, 0.6), CFrame.new(center + Vector3.new(-24 - index * 10, 7, 4)), Color3.fromRGB(150, 146, 158), Enum.Material.Metal, parent)
	end
end

-- Mini targ z namiotami - tlo dla NPC.
local function buildMarket(parent: Instance)
	local colors = {
		Color3.fromRGB(255, 138, 92),
		Color3.fromRGB(120, 208, 224),
		Color3.fromRGB(190, 140, 255),
		Color3.fromRGB(255, 206, 110),
	}

	for index = 1, 4 do
		local base = Vector3.new(-150 + index * 16, 0, 92)
		part("TentTable", Vector3.new(13, 4, 8), CFrame.new(base + Vector3.new(0, 2.4, 0)), Color3.fromRGB(168, 128, 88), Enum.Material.WoodPlanks, parent)
		local canvas = part(
			"TentTop",
			Vector3.new(15, 0.6, 11),
			CFrame.new(base + Vector3.new(0, 12, 0)),
			colors[index],
			Enum.Material.Fabric,
			parent
		)
		glow(canvas, colors[index], 1.2, 22)
		for _, offset in { Vector3.new(-6.5, 0, -4.5), Vector3.new(6.5, 0, -4.5), Vector3.new(-6.5, 0, 4.5), Vector3.new(6.5, 0, 4.5) } do
			part("TentPole", Vector3.new(0.7, 12, 0.7), CFrame.new(base + offset + Vector3.new(0, 6, 0)), Color3.fromRGB(146, 142, 156), Enum.Material.Metal, parent)
		end
		for crate = 1, 3 do
			part("MarketBox", Vector3.new(3, 3, 3), CFrame.new(base + Vector3.new(-4 + crate * 3.4, 5.9, 0)), colors[index]:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.WoodPlanks, parent)
		end
	end
end

-- Kacik arcade + automaty, zeby bylo gdzie sie kreacic.
local function buildArcade(parent: Instance)
	local center = Vector3.new(-70, 0, -112)
	part("ArcadeFloor", Vector3.new(34, 1, 24), CFrame.new(center + Vector3.new(0, 0.6, 0)), Color3.fromRGB(56, 48, 76), Enum.Material.Concrete, parent)

	for index = 1, 5 do
		local cabinet = part(
			"ArcadeCab",
			Vector3.new(5, 10, 4),
			CFrame.new(center + Vector3.new(-14 + index * 5.6, 6, -8)),
			Color3.fromRGB(58, 52, 84),
			Enum.Material.SmoothPlastic,
			parent
		)
		local screen = part(
			"ArcadeScreen",
			Vector3.new(3.6, 3, 0.4),
			cabinet.CFrame * CFrame.new(0, 2.2, 2.1),
			Color3.fromRGB(140, 230, 255):Lerp(Color3.fromRGB(255, 140, 220), index / 5),
			Enum.Material.Neon,
			parent
		)
		glow(screen, screen.Color, 1.8, 18)
	end

	for index = 1, 3 do
		local machine = part("Vending", Vector3.new(4.5, 9, 3), CFrame.new(center + Vector3.new(-10 + index * 9, 5.4, 9)), Color3.fromRGB(226, 82, 96), Enum.Material.Metal, parent)
		local glass = part("VendingGlass", Vector3.new(3.4, 6, 0.4), machine.CFrame * CFrame.new(0, 0.8, 1.6), Color3.fromRGB(180, 255, 220), Enum.Material.Neon, parent)
		glow(glass, Color3.fromRGB(180, 255, 220), 1.4, 16)
	end
end

-- Fontanna na srodku placu jako punkt orientacyjny.
local function buildFountain(parent: Instance)
	local center = Vector3.new(0, 0, 8)
	local basin = Instance.new("Part")
	basin.Name = "FountainBasin"
	basin.Shape = Enum.PartType.Cylinder
	basin.Anchored = true
	basin.Size = Vector3.new(3, 26, 26)
	basin.CFrame = CFrame.new(center + Vector3.new(0, 1.6, 0)) * CFrame.fromOrientation(0, 0, math.rad(90))
	basin.Color = Color3.fromRGB(196, 188, 176)
	basin.Material = Enum.Material.Marble
	basin.Parent = parent

	local water = Instance.new("Part")
	water.Name = "FountainWater"
	water.Shape = Enum.PartType.Cylinder
	water.Anchored = true
	water.CanCollide = false
	water.Size = Vector3.new(0.8, 22, 22)
	water.CFrame = CFrame.new(center + Vector3.new(0, 3.2, 0)) * CFrame.fromOrientation(0, 0, math.rad(90))
	water.Color = Color3.fromRGB(126, 208, 236)
	water.Material = Enum.Material.Neon
	water.Transparency = 0.35
	water.Parent = parent
	glow(water, Color3.fromRGB(140, 214, 245), 2, 30)

	part("FountainCore", Vector3.new(3, 9, 3), CFrame.new(center + Vector3.new(0, 6, 0)), Color3.fromRGB(206, 198, 186), Enum.Material.Marble, parent)
	local top = part("FountainTop", Vector3.new(6, 1, 6), CFrame.new(center + Vector3.new(0, 10.6, 0)), Color3.fromRGB(126, 208, 236), Enum.Material.Neon, parent)
	glow(top, Color3.fromRGB(126, 208, 236), 1.6, 24)

	for index = 0, 5 do
		local angle = math.rad(index * 60)
		part("Bench", Vector3.new(9, 0.7, 3), CFrame.new(center + Vector3.new(math.sin(angle) * 22, 3, math.cos(angle) * 22)) * CFrame.fromOrientation(0, angle, 0), Color3.fromRGB(190, 132, 86), Enum.Material.WoodPlanks, parent)
		part("BenchLeg", Vector3.new(8, 2.6, 0.8), CFrame.new(center + Vector3.new(math.sin(angle) * 22, 1.4, math.cos(angle) * 22)) * CFrame.fromOrientation(0, angle, 0), Color3.fromRGB(112, 108, 122), Enum.Material.Metal, parent)
	end
end

-- Dzwig, opony i billboardy - klimat placu skladowego.
local function buildIndustrial(parent: Instance)
	local base = Vector3.new(-176, 0, -176)
	part("CranePad", Vector3.new(20, 2, 20), CFrame.new(base + Vector3.new(0, 1, 0)), Color3.fromRGB(92, 88, 104), Enum.Material.Concrete, parent)
	part("CraneMast", Vector3.new(5, 96, 5), CFrame.new(base + Vector3.new(0, 48, 0)), Color3.fromRGB(248, 186, 72), Enum.Material.Metal, parent)
	part("CraneArm", Vector3.new(96, 3.5, 4), CFrame.new(base + Vector3.new(34, 92, 0)), Color3.fromRGB(248, 186, 72), Enum.Material.Metal, parent)
	part("CraneCounter", Vector3.new(14, 6, 6), CFrame.new(base + Vector3.new(-14, 92, 0)), Color3.fromRGB(74, 70, 86), Enum.Material.Metal, parent)
	part("CraneCable", Vector3.new(0.5, 44, 0.5), CFrame.new(base + Vector3.new(70, 68, 0)), Color3.fromRGB(52, 50, 60), Enum.Material.Metal, parent)
	part("CraneHook", Vector3.new(7, 7, 7), CFrame.new(base + Vector3.new(70, 43, 0)), Color3.fromRGB(198, 82, 72), Enum.Material.CorrodedMetal, parent)

	local random = Random.new(909)
	for stack = 1, 8 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(150, 184)
		local spot = Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance)
		for tire = 1, random:NextInteger(3, 6) do
			local ring = Instance.new("Part")
			ring.Name = "Tire"
			ring.Shape = Enum.PartType.Cylinder
			ring.Anchored = true
			ring.CanCollide = false
			ring.Size = Vector3.new(1.6, 7, 7)
			ring.CFrame = CFrame.new(spot + Vector3.new(0, 1 + tire * 1.7, 0)) * CFrame.fromOrientation(0, 0, math.rad(90))
			ring.Color = Color3.fromRGB(38, 38, 44)
			ring.Material = Enum.Material.Rubber
			ring.Parent = parent
		end
	end

	local boards = {
		{ Vector3.new(0, 0, 196), 0, Color3.fromRGB(255, 150, 60) },
		{ Vector3.new(-196, 0, 0), 90, Color3.fromRGB(190, 130, 255) },
		{ Vector3.new(196, 0, 40), -90, Color3.fromRGB(120, 235, 190) },
	}
	for _, spec in boards do
		local position = spec[1] :: Vector3
		local rotation = math.rad(spec[2] :: number)
		local accent = spec[3] :: Color3
		part("BoardLeg", Vector3.new(2.5, 30, 2.5), CFrame.new(position + Vector3.new(0, 15, 0)) * CFrame.fromOrientation(0, rotation, 0), Color3.fromRGB(96, 92, 108), Enum.Material.Metal, parent)
		local face = part("Billboard", Vector3.new(46, 22, 1.4), CFrame.new(position + Vector3.new(0, 38, 0)) * CFrame.fromOrientation(0, rotation, 0), Color3.fromRGB(30, 28, 40), Enum.Material.SmoothPlastic, parent)
		local strip = part("BillboardGlow", Vector3.new(46, 1.6, 1.8), face.CFrame * CFrame.new(0, -11.5, 0), accent, Enum.Material.Neon, parent)
		glow(strip, accent, 2.4, 44)
	end
end

local function buildAll()
	local parent = Instance.new("Folder")
	parent.Name = "Decor"
	parent.Parent = root

	buildGreenery(parent)
	buildFoodTruck(parent)
	buildMarket(parent)
	buildArcade(parent)
	buildFountain(parent)
	buildIndustrial(parent)
end

function DecorService.start()
	root = Workspace:FindFirstChild("CursedStorageWorld") or Workspace

	local ok, err = pcall(function()
		recolor()
		buildAll()
		shrinkSigns()
	end)
	if not ok then
		warn("[CursedStorage] Blad dekoracji: " .. tostring(err))
	end

	-- WorldService odtwarza czesc tabliczek, wiec pilnujemy rozmiaru dalej.
	task.spawn(function()
		while true do
			task.wait(3)
			pcall(shrinkSigns)
		end
	end)

	print("[CursedStorage] Dekoracje gotowe.")
end

return DecorService
