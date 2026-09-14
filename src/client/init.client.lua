--!strict
-- Kompaktowy HUD: male czcionki, mocniejsze kolory, sprint na Shift.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Loot = require(Shared:WaitForChild("Loot"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(19, 17, 28)
local CREAM = Color3.fromRGB(247, 243, 252)
local AMBER = Color3.fromRGB(255, 184, 72)
local TEAL = Color3.fromRGB(86, 226, 214)
local PINK = Color3.fromRGB(255, 118, 168)
local LILAC = Color3.fromRGB(178, 142, 255)
local MUTED = Color3.fromRGB(150, 144, 170)

local screen = Instance.new("ScreenGui")
screen.Name = "CursedStorageHUD"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

local TOP_PAD = 10 + GuiService:GetGuiInset().Y * 0.2

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 1.5
	s.Transparency = 0.35
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function card(name: string, size: UDim2, accent: Color3, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 10)
	stroke(frame, accent)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(44, 38, 62), INK)
	gradient.Rotation = 90
	gradient.Parent = frame
	return frame
end

local function text(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	textSize: number,
	color: Color3,
	bold: boolean?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

-- Lewy dolny rog: kasa, statystyki, faza, sterowanie -----------------------

local column = Instance.new("Frame")
column.Name = "LeftColumn"
column.AnchorPoint = Vector2.new(0, 1)
column.Position = UDim2.new(0, 14, 1, -14)
column.Size = UDim2.fromOffset(196, 240)
column.BackgroundTransparency = 1
column.Parent = screen

local layout = Instance.new("UIListLayout")
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = column

local cashCard = card("Cash", UDim2.fromOffset(196, 48), AMBER, column)
cashCard.LayoutOrder = 1
local cashCaption = text(cashCard, "Caption", UDim2.fromOffset(120, 12), UDim2.fromOffset(12, 8), 10, MUTED)
cashCaption.Text = "GOTOWKA"
local cashValue = text(cashCard, "Value", UDim2.fromOffset(170, 22), UDim2.fromOffset(12, 20), 18, AMBER, true)
cashValue.Text = "$0"

local statsCard = card("Stats", UDim2.fromOffset(196, 34), TEAL, column)
statsCard.LayoutOrder = 2
local statsLabel = text(statsCard, "Label", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), 11, TEAL)
statsLabel.Text = "Plecak 0 | Brudne 0 | Polki 0/6"

local phaseCard = card("Phase", UDim2.fromOffset(196, 32), AMBER, column)
phaseCard.LayoutOrder = 3
local phaseDot = Instance.new("Frame")
phaseDot.Size = UDim2.fromOffset(8, 8)
phaseDot.Position = UDim2.fromOffset(12, 12)
phaseDot.BackgroundColor3 = AMBER
phaseDot.BorderSizePixel = 0
phaseDot.Parent = phaseCard
corner(phaseDot, 4)
local phaseLabel = text(phaseCard, "Label", UDim2.fromOffset(160, 32), UDim2.fromOffset(26, 0), 11, AMBER)
phaseLabel.Text = "DZIEN - aukcje i handel"

local controls = card("Controls", UDim2.fromOffset(196, 86), LILAC, column)
controls.LayoutOrder = 4
controls.BackgroundTransparency = 0.3
local controlsTitle = text(controls, "Title", UDim2.fromOffset(170, 12), UDim2.fromOffset(12, 7), 10, LILAC)
controlsTitle.Text = "STEROWANIE"
local controlsBody = text(controls, "Body", UDim2.fromOffset(176, 62), UDim2.fromOffset(12, 22), 10, Color3.fromRGB(198, 192, 216))
controlsBody.Text = "E  licytuj / czysc / sprzedaj / lap zlodzieja\nF  wystaw na polke\nR  zajmij lombard\nShift  sprint"
controlsBody.TextYAlignment = Enum.TextYAlignment.Top

-- Cel gry (prawy dol, nad toastami) ---------------------------------------

local questCard = card("Quest", UDim2.fromOffset(230, 54), PINK, screen)
questCard.AnchorPoint = Vector2.new(1, 1)
questCard.Position = UDim2.new(1, -14, 1, -14)
local questTitle = text(questCard, "Title", UDim2.fromOffset(200, 12), UDim2.fromOffset(12, 7), 10, PINK)
questTitle.Text = "CEL"
local questBody = text(questCard, "Body", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(12, 20), 11, CREAM)
questBody.Text = "Wygraj locker na aukcji"
questBody.TextWrapped = true

-- Panel aukcji (gora, srodek) ---------------------------------------------

local auctionCard = card("Auction", UDim2.fromOffset(330, 88), AMBER, screen)
auctionCard.AnchorPoint = Vector2.new(0.5, 0)
auctionCard.Position = UDim2.new(0.5, 0, 0, TOP_PAD)

local auctionTier = text(auctionCard, "Tier", UDim2.fromOffset(200, 16), UDim2.fromOffset(12, 9), 13, AMBER, true)
auctionTier.Text = "BRAK AUKCJI"
local auctionMeta = text(auctionCard, "Meta", UDim2.fromOffset(210, 14), UDim2.fromOffset(12, 28), 10, MUTED)
auctionMeta.Text = "Nastepny locker startuje automatycznie"
local auctionBid = text(auctionCard, "Bid", UDim2.fromOffset(110, 20), UDim2.new(1, -122, 0, 8), 16, CREAM, true)
auctionBid.TextXAlignment = Enum.TextXAlignment.Right
auctionBid.Text = "-"
local auctionLeader = text(auctionCard, "Leader", UDim2.fromOffset(110, 12), UDim2.new(1, -122, 0, 30), 10, TEAL)
auctionLeader.TextXAlignment = Enum.TextXAlignment.Right

local barBack = Instance.new("Frame")
barBack.Name = "TimerBack"
barBack.Size = UDim2.new(1, -24, 0, 5)
barBack.Position = UDim2.fromOffset(12, 52)
barBack.BackgroundColor3 = Color3.fromRGB(52, 46, 68)
barBack.BorderSizePixel = 0
barBack.Parent = auctionCard
corner(barBack, 3)

local barFill = Instance.new("Frame")
barFill.Name = "TimerFill"
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = AMBER
barFill.BorderSizePixel = 0
barFill.Parent = barBack
corner(barFill, 3)

local hint = text(auctionCard, "Hint", UDim2.new(1, -24, 0, 14), UDim2.fromOffset(12, 64), 10, MUTED)
hint.Text = string.format("E przy lockerze podbija o $%d", Config.Auction.MinBidStep)

-- Toasty (prawy dol, nad kartami) -----------------------------------------

local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.Size = UDim2.fromOffset(246, 260)
toastHolder.AnchorPoint = Vector2.new(1, 1)
toastHolder.Position = UDim2.new(1, -14, 1, -76)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = screen

local toastLayout = Instance.new("UIListLayout")
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.Padding = UDim.new(0, 5)
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastHolder

local toastOrder = 0

local function toast(message: string, accent: Color3)
	toastOrder += 1

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.Size = UDim2.fromOffset(240, 32)
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.LayoutOrder = toastOrder
	frame.Parent = toastHolder
	corner(frame, 8)
	stroke(frame, accent)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(3, 20)
	bar.Position = UDim2.fromOffset(8, 6)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = frame
	corner(bar, 2)

	local label = text(frame, "Label", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(18, 0), 10, CREAM)
	label.Text = message
	label.TextWrapped = true

	task.delay(4, function()
		if not frame.Parent then
			return
		end
		TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		local fade = TweenService:Create(frame, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		frame:Destroy()
	end)
end

-- Sprint ------------------------------------------------------------------

local BASE_SPEED = 16
local SPRINT_SPEED = 26

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setSpeed(speed: number)
	local h = humanoid()
	if h then
		h.WalkSpeed = speed
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSpeed(SPRINT_SPEED)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSpeed(BASE_SPEED)
	end
end)

-- Stan --------------------------------------------------------------------

local currentLotId: string? = nil
local endsAt = 0
local duration = 0

local function setPanelIdle()
	currentLotId = nil
	duration = 0
	auctionTier.Text = "BRAK AUKCJI"
	auctionTier.TextColor3 = MUTED
	auctionMeta.Text = "Nastepny locker startuje automatycznie"
	auctionBid.Text = "-"
	auctionLeader.Text = ""
	barFill.Size = UDim2.fromScale(0, 1)
end

setPanelIdle()

local function setBalance(amount: number)
	cashValue.Text = string.format("$%d", amount)
end

local function refreshStats()
	local ok, profile = pcall(function()
		return Remotes.func("GetProfile"):InvokeServer()
	end)
	if not ok or type(profile) ~= "table" then
		return
	end

	local dirty = 0
	for _, item in profile.Inventory do
		if item.Dirty then
			dirty += 1
		end
	end

	setBalance(profile.Balance)
	statsLabel.Text = string.format(
		"Plecak %d | Brudne %d | Polki %d/6",
		#profile.Inventory,
		dirty,
		#profile.Displayed
	)

	-- Prosty samouczek: podpowiada nastepny krok.
	if #profile.Inventory == 0 and #profile.Displayed == 0 then
		questBody.Text = "Wygraj locker na aukcji (E przy lockerze)"
	elseif dirty > 0 then
		questBody.Text = string.format("Wyczysc %d brudnych rzeczy w warsztacie", dirty)
	elseif #profile.Displayed == 0 then
		questBody.Text = "Wystaw towar na polke (F przy swojej ladzie)"
	else
		questBody.Text = "Pilnuj polki - NPC kupuja, zlodzieje kradna"
	end
end

Remotes.event("BalanceChanged").OnClientEvent:Connect(setBalance)

Remotes.event("PhaseChanged").OnClientEvent:Connect(function(phase: string)
	if phase == "Night" then
		phaseLabel.Text = "NOC - zlodzieje na placu"
		phaseLabel.TextColor3 = PINK
		phaseDot.BackgroundColor3 = PINK
	else
		phaseLabel.Text = "DZIEN - aukcje i handel"
		phaseLabel.TextColor3 = AMBER
		phaseDot.BackgroundColor3 = AMBER
	end
end)

Remotes.event("AuctionStarted").OnClientEvent:Connect(function(data)
	currentLotId = data.LotId
	duration = math.max(1, data.Duration or Config.Auction.BiddingSeconds)
	endsAt = os.clock() + duration

	auctionTier.Text = string.upper(tostring(data.TierId)) .. " LOCKER"
	auctionTier.TextColor3 = AMBER
	auctionBid.Text = string.format("$%d", data.StartingBid or 0)
	auctionLeader.Text = if data.Leader then "prowadzi " .. data.Leader else "brak ofert"
	auctionLeader.TextColor3 = if data.Leader then TEAL else MUTED
	toast(string.format("Nowy locker: %s (%d szt.)", tostring(data.TierId), data.ItemCount or 0), AMBER)
end)

Remotes.event("AuctionEnded").OnClientEvent:Connect(function(data)
	if data.Winner then
		toast(string.format("%s wygral locker za $%d", data.Winner, data.Price), AMBER)
	else
		toast("Locker niesprzedany", MUTED)
	end
	setPanelIdle()
	refreshStats()
end)

Remotes.event("ItemRevealed").OnClientEvent:Connect(function(item)
	local rarity = Loot.rarityById(item.Rarity)
	toast(string.format("%s [%s] ~ $%d", item.Name, item.Rarity, item.Value), rarity.Color)
	refreshStats()
end)

Remotes.event("ItemCleaned").OnClientEvent:Connect(function(item)
	toast(string.format("Wyczyszczone: %s -> $%d", item.Name, item.Value), TEAL)
	refreshStats()
end)

Remotes.event("Notify").OnClientEvent:Connect(function(message: string)
	local accent = LILAC
	if string.find(message, "kupil") or string.find(message, "Nagroda") then
		accent = TEAL
	elseif string.find(message, "zlodziej") or string.find(message, "Ukradli") then
		accent = PINK
	end
	toast(message, accent)
	refreshStats()
end)

RunService.RenderStepped:Connect(function()
	if not currentLotId or duration <= 0 then
		return
	end
	local left = math.max(0, endsAt - os.clock())
	local ratio = math.clamp(left / duration, 0, 1)
	barFill.Size = UDim2.fromScale(ratio, 1)
	barFill.BackgroundColor3 = if ratio < 0.25 then PINK else AMBER
	auctionMeta.Text = string.format("%.0f s do konca licytacji", left)
end)

function _G.CursedStorageBid(amount: number)
	if currentLotId then
		Remotes.event("PlaceBid"):FireServer(currentLotId, amount)
	end
end

setBalance(Config.Currency.StartingBalance)
refreshStats()

task.spawn(function()
	while true do
		task.wait(5)
		pcall(refreshStats)
	end
end)

print("[CursedStorage] HUD gotowy.")
