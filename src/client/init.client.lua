--!strict
-- HUD: karta gotowki, faza dnia, panel aukcji z paskiem czasu, toasty i podpowiedzi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Loot = require(Shared:WaitForChild("Loot"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(16, 15, 22)
local CREAM = Color3.fromRGB(255, 248, 238)
local GOLD = Color3.fromRGB(255, 196, 84)
local MINT = Color3.fromRGB(120, 235, 170)
local VIOLET = Color3.fromRGB(190, 130, 255)

local screen = Instance.new("ScreenGui")
screen.Name = "CursedStorageHUD"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- Male helpery -------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = 0.35
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
	return g
end

local function card(name: string, size: UDim2, position: UDim2, anchor: Vector2, accent: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = screen

	corner(frame, 14)
	stroke(frame, accent, 2)
	gradient(frame, Color3.fromRGB(38, 34, 50), INK)

	return frame
end

local function text(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

-- Karta gotowki ------------------------------------------------------------

local cashCard = card("Cash", UDim2.fromOffset(226, 68), UDim2.fromOffset(18, 18), Vector2.new(0, 0), GOLD)

local cashIcon = text(cashCard, "Icon", UDim2.fromOffset(44, 44), UDim2.fromOffset(12, 12), 26, GOLD)
cashIcon.Text = "$"
cashIcon.TextXAlignment = Enum.TextXAlignment.Center

local cashCaption = text(cashCard, "Caption", UDim2.fromOffset(150, 16), UDim2.fromOffset(60, 12), 12, Color3.fromRGB(170, 162, 186))
cashCaption.Text = "GOTOWKA"

local cashValue = text(cashCard, "Value", UDim2.fromOffset(150, 30), UDim2.fromOffset(60, 28), 24, CREAM)
cashValue.Text = "0"

-- Karta fazy ---------------------------------------------------------------

local phaseCard = card("Phase", UDim2.fromOffset(226, 44), UDim2.fromOffset(18, 96), Vector2.new(0, 0), GOLD)

local phaseDot = Instance.new("Frame")
phaseDot.Name = "Dot"
phaseDot.Size = UDim2.fromOffset(12, 12)
phaseDot.Position = UDim2.fromOffset(14, 16)
phaseDot.BackgroundColor3 = GOLD
phaseDot.BorderSizePixel = 0
phaseDot.Parent = phaseCard
corner(phaseDot, 6)

local phaseLabel = text(phaseCard, "Label", UDim2.fromOffset(180, 44), UDim2.fromOffset(36, 0), 15, GOLD)
phaseLabel.Text = "DZIEN - aukcje i handel"

-- Panel aukcji -------------------------------------------------------------

local auctionCard = card("Auction", UDim2.fromOffset(420, 132), UDim2.new(0.5, 0, 0, 18), Vector2.new(0.5, 0), GOLD)
auctionCard.BackgroundTransparency = 0.08

local auctionTier = text(auctionCard, "Tier", UDim2.fromOffset(260, 26), UDim2.fromOffset(18, 14), 20, GOLD)
auctionTier.Text = "BRAK AUKCJI"

local auctionMeta = text(auctionCard, "Meta", UDim2.fromOffset(260, 20), UDim2.fromOffset(18, 42), 14, Color3.fromRGB(178, 170, 196))
auctionMeta.Text = "Napisz /aukcja albo poczekaj na kolejna runde"

local auctionBid = text(auctionCard, "Bid", UDim2.fromOffset(150, 34), UDim2.new(1, -168, 0, 12), 26, CREAM)
auctionBid.TextXAlignment = Enum.TextXAlignment.Right
auctionBid.Text = "-"

local auctionLeader = text(auctionCard, "Leader", UDim2.fromOffset(150, 18), UDim2.new(1, -168, 0, 46), 13, MINT)
auctionLeader.TextXAlignment = Enum.TextXAlignment.Right
auctionLeader.Text = ""

local barBack = Instance.new("Frame")
barBack.Name = "TimerBack"
barBack.Size = UDim2.new(1, -36, 0, 8)
barBack.Position = UDim2.fromOffset(18, 78)
barBack.BackgroundColor3 = Color3.fromRGB(46, 42, 58)
barBack.BorderSizePixel = 0
barBack.Parent = auctionCard
corner(barBack, 4)

local barFill = Instance.new("Frame")
barFill.Name = "TimerFill"
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = GOLD
barFill.BorderSizePixel = 0
barFill.Parent = barBack
corner(barFill, 4)

local hint = text(auctionCard, "Hint", UDim2.new(1, -36, 0, 20), UDim2.fromOffset(18, 96), 13, Color3.fromRGB(150, 144, 168))
hint.Text = string.format("E przy lockerze podbija o $%d", Config.Auction.MinBidStep)

-- Podpowiedzi sterowania ---------------------------------------------------

local controls = card("Controls", UDim2.fromOffset(268, 96), UDim2.new(0, 18, 1, -18), Vector2.new(0, 1), VIOLET)
controls.BackgroundTransparency = 0.25

local controlsTitle = text(controls, "Title", UDim2.fromOffset(240, 18), UDim2.fromOffset(14, 10), 13, VIOLET)
controlsTitle.Text = "STEROWANIE"

local controlsBody = text(controls, "Body", UDim2.fromOffset(240, 58), UDim2.fromOffset(14, 30), 13, Color3.fromRGB(196, 190, 210))
controlsBody.Text = "E  licytuj / czysc / sprzedaj\nF  wystaw na polke\n/aukcja  /kasa  /pomoc"
controlsBody.TextYAlignment = Enum.TextYAlignment.Top

-- Toasty -------------------------------------------------------------------

local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.Size = UDim2.fromOffset(340, 300)
toastHolder.Position = UDim2.new(1, -18, 0, 18)
toastHolder.AnchorPoint = Vector2.new(1, 0)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = screen

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = toastHolder

local toastOrder = 0

local function toast(message: string, accent: Color3)
	toastOrder += 1

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.Size = UDim2.fromOffset(330, 44)
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.LayoutOrder = toastOrder
	frame.Parent = toastHolder
	corner(frame, 12)
	stroke(frame, accent, 2)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(4, 28)
	bar.Position = UDim2.fromOffset(10, 8)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = frame
	corner(bar, 2)

	local label = text(frame, "Label", UDim2.new(1, -30, 1, 0), UDim2.fromOffset(22, 0), 14, CREAM)
	label.Text = message
	label.TextWrapped = true

	frame.Position = UDim2.fromOffset(40, 0)
	TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
		Position = UDim2.fromOffset(0, 0),
	}):Play()

	task.delay(4, function()
		if not frame.Parent then
			return
		end
		local fade = TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		fade:Play()
		fade.Completed:Wait()
		frame:Destroy()
	end)
end

-- Stan aukcji --------------------------------------------------------------

local currentLotId: string? = nil
local endsAt = 0
local duration = 0

local function setPanelIdle()
	currentLotId = nil
	duration = 0
	auctionTier.Text = "BRAK AUKCJI"
	auctionTier.TextColor3 = Color3.fromRGB(150, 144, 168)
	auctionMeta.Text = "Napisz /aukcja albo poczekaj na kolejna runde"
	auctionBid.Text = "-"
	auctionLeader.Text = ""
	barFill.Size = UDim2.fromScale(0, 1)
end

setPanelIdle()

local function setBalance(amount: number)
	cashValue.Text = string.format("%d", amount)
end

Remotes.event("BalanceChanged").OnClientEvent:Connect(setBalance)

Remotes.event("PhaseChanged").OnClientEvent:Connect(function(phase: string)
	if phase == "Night" then
		phaseLabel.Text = "NOC - napady otwarte"
		phaseLabel.TextColor3 = Color3.fromRGB(255, 110, 110)
		phaseDot.BackgroundColor3 = Color3.fromRGB(255, 110, 110)
	else
		phaseLabel.Text = "DZIEN - aukcje i handel"
		phaseLabel.TextColor3 = GOLD
		phaseDot.BackgroundColor3 = GOLD
	end
end)

Remotes.event("AuctionStarted").OnClientEvent:Connect(function(data)
	currentLotId = data.LotId
	duration = math.max(1, data.Duration or Config.Auction.BiddingSeconds)
	endsAt = os.clock() + duration

	auctionTier.Text = string.upper(tostring(data.TierId)) .. " LOCKER"
	auctionTier.TextColor3 = GOLD
	auctionMeta.Text = string.format("%d przedmiotow w srodku", data.ItemCount or 0)
	auctionBid.Text = string.format("$%d", data.StartingBid or 0)
	auctionLeader.Text = if data.Leader then "prowadzi " .. data.Leader else "brak ofert"
	auctionLeader.TextColor3 = if data.Leader then MINT else Color3.fromRGB(150, 144, 168)
end)

Remotes.event("AuctionEnded").OnClientEvent:Connect(function(data)
	if data.Winner then
		toast(string.format("%s wygral locker za $%d", data.Winner, data.Price), GOLD)
	else
		toast("Locker niesprzedany", Color3.fromRGB(150, 144, 168))
	end
	setPanelIdle()
end)

Remotes.event("ItemRevealed").OnClientEvent:Connect(function(item)
	local rarity = Loot.rarityById(item.Rarity)
	toast(string.format("%s [%s] ~ $%d", item.Name, item.Rarity, item.Value), rarity.Color)
end)

Remotes.event("ItemCleaned").OnClientEvent:Connect(function(item)
	toast(string.format("Wyczyszczone: %s -> $%d", item.Name, item.Value), MINT)
end)

Remotes.event("Notify").OnClientEvent:Connect(function(message: string)
	toast(message, VIOLET)
end)

-- Pasek czasu odswiezany co klatke.
RunService.RenderStepped:Connect(function()
	if not currentLotId or duration <= 0 then
		return
	end
	local left = math.max(0, endsAt - os.clock())
	local ratio = math.clamp(left / duration, 0, 1)
	barFill.Size = UDim2.fromScale(ratio, 1)
	barFill.BackgroundColor3 = if ratio < 0.25 then Color3.fromRGB(255, 110, 110) else GOLD
	auctionMeta.Text = string.format("%.0f s do konca licytacji", left)
end)

-- Licytowanie z konsoli klienta, gdyby bylo potrzebne.
function _G.CursedStorageBid(amount: number)
	if currentLotId then
		Remotes.event("PlaceBid"):FireServer(currentLotId, amount)
	end
end

local profile = Remotes.func("GetProfile"):InvokeServer()
if profile then
	setBalance(profile.Balance)
else
	setBalance(Config.Currency.StartingBalance)
end

print("[CursedStorage] HUD gotowy.")
