--!strict
-- NPC i akcja. Zycie na placu: klienci ktorzy realnie kupuja z polek,
-- licytator, ochrona na patrolu i nocni zlodzieje, ktorych mozna
-- powstrzymac za nagrode.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local NpcService = {}

local ProfileService
local HeistService

local folder: Folder
local thiefCount = 0

local SKINS = {
	Color3.fromRGB(255, 214, 168),
	Color3.fromRGB(226, 176, 128),
	Color3.fromRGB(176, 126, 92),
	Color3.fromRGB(122, 86, 62),
}

local SHIRTS = {
	Color3.fromRGB(255, 138, 92),
	Color3.fromRGB(96, 196, 180),
	Color3.fromRGB(146, 132, 246),
	Color3.fromRGB(248, 196, 92),
	Color3.fromRGB(236, 118, 158),
	Color3.fromRGB(120, 190, 120),
}

local NAMES = {
	"Zdzisiek",
	"Pani Bogusia",
	"Karolek",
	"Wiesiek",
	"Mirka",
	"Kolekcjoner Tadek",
	"Turysta Bob",
	"Ciotka Hela",
}

local function notifyAll(message: string)
	for _, player in Players:GetPlayers() do
		Remotes.event("Notify"):FireClient(player, message)
	end
end

local function notify(player: Player, message: string)
	Remotes.event("Notify"):FireClient(player, message)
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function tag(parent: BasePart, label: string, accent: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(150, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = frame

	local s = Instance.new("UIStroke")
	s.Color = accent
	s.Thickness = 1.5
	s.Transparency = 0.2
	s.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamMedium
	text.TextSize = 12
	text.TextColor3 = Color3.fromRGB(246, 242, 252)
	text.Text = label
	text.Parent = frame
end

-- Prosty, kanciasty NPC. Bez Humanoida, zeby nic sie nie wywracalo.
local function makeNpc(name: string, shirt: Color3, position: Vector3, accent: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folder

	local skin = SKINS[math.random(1, #SKINS)]
	local base = CFrame.new(position)

	local torso = block(model, "Torso", Vector3.new(2, 2.4, 1.1), base, shirt)
	model.PrimaryPart = torso

	block(model, "Head", Vector3.new(1.5, 1.5, 1.5), base * CFrame.new(0, 2, 0), skin)
	block(model, "ArmL", Vector3.new(0.6, 2.1, 0.7), base * CFrame.new(-1.3, -0.1, 0), skin)
	block(model, "ArmR", Vector3.new(0.6, 2.1, 0.7), base * CFrame.new(1.3, -0.1, 0), skin)
	block(model, "LegL", Vector3.new(0.8, 2.3, 0.9), base * CFrame.new(-0.5, -2.3, 0), Color3.fromRGB(52, 58, 82))
	block(model, "LegR", Vector3.new(0.8, 2.3, 0.9), base * CFrame.new(0.5, -2.3, 0), Color3.fromRGB(52, 58, 82))
	block(model, "Cap", Vector3.new(1.7, 0.4, 1.7), base * CFrame.new(0, 2.95, 0), accent, Enum.Material.Fabric)

	tag(torso, name, accent)
	return model
end

local function pivot(model: Model, cf: CFrame)
	local ok = pcall(function()
		model:PivotTo(cf)
	end)
	if not ok and model.PrimaryPart then
		model.PrimaryPart.CFrame = cf
	end
end

-- Spacer do celu z lekkim kolysaniem, zeby NPC nie byl slupem.
local function walkTo(model: Model, target: Vector3, speed: number): boolean
	local step = 0
	while model.Parent do
		local primary = model.PrimaryPart
		if not primary then
			return false
		end

		local here = primary.Position
		local flatTarget = Vector3.new(target.X, here.Y, target.Z)
		local delta = flatTarget - here
		if delta.Magnitude < 3 then
			return true
		end

		step += 1
		local direction = delta.Unit
		local bob = math.sin(step * 0.55) * 0.18
		local next = here + direction * math.min(speed * 0.1, delta.Magnitude) + Vector3.new(0, bob, 0)
		pivot(model, CFrame.lookAt(next, next + direction))
		task.wait(0.1)
	end
	return false
end

local function world(): Instance?
	return Workspace:FindFirstChild("CursedStorageWorld")
end

local function stallModels(): { Model }
	local result: { Model } = {}
	local root = world()
	if not root then
		return result
	end
	for _, child in root:GetChildren() do
		if child:IsA("Model") and string.match(child.Name, "^Stall%d+$") then
			table.insert(result, child)
		end
	end
	return result
end

local function ownerLabel(stall: Model): TextLabel?
	local counter = stall:FindFirstChild("Counter")
	local gui = counter and counter:FindFirstChild("OwnerGui")
	local frame = gui and gui:FindFirstChildOfClass("Frame")
	return frame and frame:FindFirstChild("Owner") :: TextLabel?
end

-- Szuka stanowiska nalezacego do gracza (po podpisie nad lada).
local function stallOfPlayer(player: Player): Model?
	local wanted = string.upper(player.DisplayName)
	for _, stall in stallModels() do
		local label = ownerLabel(stall)
		if label and string.find(label.Text, wanted, 1, true) then
			return stall
		end
	end
	return nil
end

local function stallFront(stall: Model): Vector3
	local counter = stall:FindFirstChild("Counter") :: BasePart?
	if counter then
		return (counter.CFrame * CFrame.new(0, 0, 12)).Position
	end
	local primary = stall.PrimaryPart
	return primary and primary.Position or Vector3.new(0, 4, 0)
end

local function shoppers(): { Player }
	local result: { Player } = {}
	for _, player in Players:GetPlayers() do
		local profile = ProfileService.get(player)
		if profile and #profile.Displayed > 0 then
			table.insert(result, player)
		end
	end
	return result
end

-- Klient: idzie do losowego lombardu i kupuje najdrozszy towar z polki.
local function customerLoop(model: Model, name: string)
	while model.Parent do
		task.wait(math.random(2, 6))

		local targets = shoppers()
		if #targets == 0 then
			-- Nikt nic nie wystawil, wiec NPC krazy po placu.
			local angle = math.random() * math.pi * 2
			local distance = math.random(60, 160)
			walkTo(model, Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance), 14)
			continue
		end

		local buyer = targets[math.random(1, #targets)]
		local stall = stallOfPlayer(buyer)
		if not stall then
			continue
		end

		if not walkTo(model, stallFront(stall), 15) then
			continue
		end

		task.wait(math.random(1, 3))

		local profile = ProfileService.get(buyer)
		if not profile or #profile.Displayed == 0 then
			continue
		end

		-- 70% szans na zakup, inaczej tylko oglada.
		if math.random() > 0.7 then
			notify(buyer, string.format("%s tylko oglada twoja polke...", name))
			continue
		end

		local bestIndex = 1
		for index, item in profile.Displayed do
			if item.Value > profile.Displayed[bestIndex].Value then
				bestIndex = index
			end
		end

		local item = table.remove(profile.Displayed, bestIndex)
		if not item then
			continue
		end

		-- NPC placi z premia, wiec wystawianie jest oplacalne.
		local bonus = 1 + math.random(10, 45) / 100
		local price = math.floor(item.Value * bonus)
		profile.Balance += price
		profile.Stats.ItemsSold += 1

		Remotes.event("BalanceChanged"):FireClient(buyer, profile.Balance)
		notify(buyer, string.format("%s kupil %s za $%d!", name, item.Name, price))
	end
end

-- Ochrona: chodzi w kolko po placu.
local function patrolLoop(model: Model)
	local index = 0
	while model.Parent do
		index += 1
		local angle = math.rad(index * 51)
		walkTo(model, Vector3.new(math.sin(angle) * 140, 0, math.cos(angle) * 140), 17)
		task.wait(1)
	end
end

-- Licytator: krazy po scenie i komentuje aukcje.
local function auctioneerLoop(model: Model)
	local center = Vector3.new(0, 0, -96)
	while model.Parent do
		walkTo(model, center + Vector3.new(math.random(-20, 20), 0, math.random(6, 20)), 12)
		task.wait(math.random(3, 7))
	end
end

-- Nocny zlodziej: idzie do lombardu gracza i probuje ukrasc towar.
-- Kazdy gracz moze go powstrzymac klawiszem E i dostaje nagrode.
local function spawnThief()
	local targets = shoppers()
	if #targets == 0 then
		return
	end

	local victim = targets[math.random(1, #targets)]
	local stall = stallOfPlayer(victim)
	if not stall then
		return
	end

	thiefCount += 1
	local spawnAngle = math.random() * math.pi * 2
	local start = Vector3.new(math.sin(spawnAngle) * 185, 4, math.cos(spawnAngle) * 185)
	local model = makeNpc(
		string.format("Zlodziej #%d", thiefCount),
		Color3.fromRGB(38, 40, 56),
		start,
		Color3.fromRGB(255, 96, 96)
	)

	local torso = model.PrimaryPart
	if not torso then
		model:Destroy()
		return
	end

	local caught = false

	local anchor = Instance.new("Attachment")
	anchor.Name = "StopAnchor"
	anchor.Parent = torso

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StopPrompt"
	prompt.ActionText = "Powstrzymaj"
	prompt.ObjectText = "Zlodziej"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(hero)
		if caught then
			return
		end
		caught = true

		local profile = ProfileService.get(hero)
		local bounty = math.random(180, 420)
		if profile then
			profile.Balance += bounty
			Remotes.event("BalanceChanged"):FireClient(hero, profile.Balance)
		end
		notifyAll(string.format("%s zlapal zlodzieja! Nagroda $%d", hero.DisplayName, bounty))
		model:Destroy()
	end)

	notify(victim, "Ktos krazy wokol twojego lombardu! Wcisnij E przy zlodzieju.")

	task.spawn(function()
		walkTo(model, stallFront(stall), 19)
		if caught or not model.Parent then
			return
		end

		-- Okno na reakcje gracza.
		for _ = 1, 10 do
			if caught or not model.Parent then
				return
			end
			task.wait(0.8)
		end

		if caught or not model.Parent then
			return
		end

		local profile = ProfileService.get(victim)
		if profile and #profile.Displayed > 0 then
			local item = table.remove(profile.Displayed, math.random(1, #profile.Displayed))
			profile.Stats.TimesRobbed += 1
			if item then
				notify(victim, string.format("Ukradli ci %s ($%d)!", item.Name, item.Value))
			end
		end

		-- Uciekaj z lupem.
		local away = Vector3.new(math.sin(spawnAngle) * 220, 4, math.cos(spawnAngle) * 220)
		walkTo(model, away, 26)
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function thiefLoop()
	while true do
		task.wait(25)
		local phase = "Day"
		if HeistService and HeistService.getPhase then
			local ok, value = pcall(HeistService.getPhase)
			if ok then
				phase = tostring(value)
			end
		end

		if phase == "Night" and #folder:GetChildren() < 16 then
			pcall(spawnThief)
		end
	end
end

function NpcService.start(profileService, heistService)
	ProfileService = profileService
	HeistService = heistService

	local root = world() or Workspace
	folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = root

	local auctioneer = makeNpc("Licytator Rysiek", Color3.fromRGB(255, 150, 60), Vector3.new(14, 7, -78), Color3.fromRGB(255, 196, 84))
	task.spawn(auctioneerLoop, auctioneer)

	local cleaner = makeNpc("Pani Mopik", Color3.fromRGB(96, 214, 214), Vector3.new(-96, 5, 16), Color3.fromRGB(120, 235, 190))
	task.spawn(function()
		while cleaner.Parent do
			walkTo(cleaner, Vector3.new(-104 + math.random(-10, 10), 0, 6 + math.random(-8, 12)), 10)
			task.wait(math.random(3, 6))
		end
	end)

	local guard = makeNpc("Ochrona Zbyszek", Color3.fromRGB(60, 90, 160), Vector3.new(0, 5, 120), Color3.fromRGB(120, 170, 255))
	task.spawn(patrolLoop, guard)

	for index = 1, 6 do
		local name = NAMES[((index - 1) % #NAMES) + 1]
		local shirt = SHIRTS[((index - 1) % #SHIRTS) + 1]
		local angle = math.rad(index * 60)
		local npc = makeNpc(name, shirt, Vector3.new(math.sin(angle) * 70, 5, math.cos(angle) * 70), shirt)
		task.spawn(customerLoop, npc, name)
	end

	task.spawn(thiefLoop)

	print("[CursedStorage] NPC na placu.")
end

return NpcService
