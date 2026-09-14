--!strict
-- HUD. Nic nie siedzi w gornym lewym/prawym rogu, bo tam Roblox trzyma
-- swoj pasek i liste graczy. Kasa i faza sa w lewym dolnym rogu.

local GuiService = game:GetService("GuiService")
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
local MUTED = Color3.fromRGB(168, 162, 184)

local screen = Instance.new("ScreenGui")
screen.Name = "CursedStorageHUD"
screen.ResetOnSpawn = false
-- false = Roblox sam odsuwa nasze GUI od swojego paska u gory.
screen.IgnoreGuiInset = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- Dodatkowy zapas pod pasek Robloxa (unibar jest wyzszy niz sam inset).
local TOP_PAD = 12 + GuiService:GetGuiInset().Y * 0.25

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
	s.Transparency = 0.3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function gradient(parent: Instance)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(40, 36, 54), INK)
	g.Rotation = 90
	g.Parent = parent
	return g
end

local function card(name: string, size: UDim2, position: UDim2, anchor: Vector2, accent: Color3, parent: Instance?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = parent or screen
	corner(frame, 14)
	stroke(frame, accent, 2)
	gradient(frame)
	return frame
end

local function text(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	textSize: number,
	color: Color3
): TextLabel
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

-- Lewa dolna kolumna: kasa, statystyki, faza, sterowanie -------------------

local leftColumn = Instance.new("Frame")
leftColumn.Name = "LeftColumn"
leftColumn.AnchorPoint = Vector2.new(0, 1)
leftColumn.Position = UDim2.new(0, 18, 1, -18)
leftColumn.Size = UDim2.fromOffset(250, 280)
leftColumn.BackgroundTransparency = 1
leftColumn.Parent = screen

local leftLayout = Instance.new("UIListLayout")
leftLayout.FillDirection = Enum.FillDirection.Vertical
leftLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
leftLayout.Padding = UDim.new(0, 8)
leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
leftLayout.Parent = leftColumn

local cashCard = card("Cash", UDim2.fromOffset(250, 74), UDim2.new(), Vector2.new(), GOLD, leftColumn)
cashCard.LayoutOrder = 1

local cashIcon = text(cashCard, "Icon", UDim2.fromOffset(46, 46), UDim2.fromOffset(12, 14), 28, GOLD)
cashIcon.Text = "$"
cashIcon.TextXAlignment = Enum.TextXAlignment.Center

local cashCaption = text(cashCard, "Caption", UDim2.fromOffset(170, 16), UDim2.fromOffset(62, 14), 12, MUTED)
cashCaption.Text = "GOTOWKA"

local cashValue = text(cashCard, "Value", UDim2.fromOffset(170, 34), UDim2.fromOffset(62, 30), 26, CREAM)
cashValue.Text = "0"

local statsCard = card("Stats", UDim2.fromOffset(250, 44), UDim2.new(), Vector2.new(), MINT, leftColumn)
statsCard.LayoutOrder = 2
local statsLabel = text(statsCard, "Label", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(14, 0), 13, MINT)
statsLabel.Text = "Ekwipunek 0  |  Brudne 0  |  Polki 0/6"

local phaseCard = card("Phase", UDim2.fromOffset(250, 44), UDim2.new(), Vector2.new(), GOLD, leftColumn)
phaseCard.LayoutOrder = 3

local phaseDot = Instance.new("Frame")
phaseDot.Name = "Dot"
phaseDot.Size = UDim2.fromOffset(12, 12)
phaseDot.Position = UDim2.fromOffset(14, 16)
phaseDot.BackgroundColor3 = GOLD
phaseDot.BorderSizePixel = 0
phaseDot.Parent = phaseCard
corner(phaseDot, 6)

local phaseLabel = text(phaseCard, "Label", UDim2.fromOffset(200, 44), UDim2.fromOffset(36, 0), 15, GOLD)
phaseLabel.Text = "DZIEN - aukcje i handel"

local controls = card("Controls", UDim2.fromOffset(250, 92), UDim2.new(), Vector2.new(), VIOLET, leftColumn)
controls.LayoutOrder = 4
controls.BackgroundTransparency = 0.25

local controlsTitle = text(controls, "Title", UDim2.fromOffset(220, 18), UDim2.fromOffset(14, 8), 12, VIOLET)
controlsTitle.Text = "STEROWANIE"

local controlsBody = text(controls, "Body", UDim2.fromOffset(224, 58), UDim2.fromOffset(14, 28), 13, Color3.fromRGB(198, 192, 212))
controlsBody.Text = "E  licytuj / czysc / sprzedaj\nF  wystaw na polke\nR  zajmij wlasny lombard"
controlsBody.TextYAlignment = Enum.TextYAlignment.Top

-- Panel aukcji (gora, na srodku) -------------------------------------------

local auctionCard = card(
	"Auction",
	UDim2.fromOffset(440, 128),
	UDim2.new(0.5, 0, 0, TOP_PAD),
	Vector2.new(0.5, 0),
	GOLD
)

local auctionTier = text(auctionCard, "Tier", UDim2.fromOffset(270, 26), UDim2.fromOffset(18, 14), 20, GOLD)
auctionTier.Text = "BRAK AUKCJI"

local auctionMeta = text(auctionCard, "Meta", UDim2.fromOffset(270, 20), UDim2.fromOffset(18, 42), 14, MUTED)
auctionMeta.Text = "Nastepny locker startuje automatycznie"

local auctionBid = text(auctionCard, "Bid", UDim2.fromOffset(160, 34), UDim2.new(1, -178, 0, 12), 26, CREAM)
auctionBid.TextXAlignment = Enum.TextXAlignment.Right
auctionBid.Text = "-"

local auctionLeader = text(auctionCard, "Leader", UDim2.fromOffset(160, 18), UDim2.new(1, -178, 0, 46), 13, MINT)
auctionLeader.TextXAlignment = Enum.TextXAlignment.Right
auctionLeader.Text = ""

local barBack = Instance.new("Frame")
barBack.Name = "TimerBack"
barBack.Size = UDim2.new(1, -36, 0, 8)
barBack.Position = UDim2.fromOffset(18, 76)
barBack.BackgroundColor3 = Color3.fromRGB(48, 44, 60)
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

local hint = text(auctionCard, "Hint", UDim2.new(1, -36, 0, 20), UDim2.fromOffset(18, 94), 13, MUTED)
hint.Text = string.format("E przy lockerze podbija o $%d", Config.Auction.MinBidStep)

-- Toasty (prawy dol, zeby nie zaslanialy listy graczy) ---------------------

local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.Size = UDim2.fromOffset(340, 320)
toastHolder.Position = UDim2.new(1, -18, 1, -18)
toastHolder.AnchorPoint = Vector2.new(1, 1)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = screen

local toastLayout = Instance.new("UIListLayout")
toastLayout.FillDirection = Enum.FillDirection.Vertical
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.Padding = UDim.new(0, 8)
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastHolder

local toastOrder = 0

local function toast(message: string, accent: Color3)
	toastOrder += 1

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.Size = UDim2.fromOffset(330, 46)
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.LayoutOrder = toastOrder
	frame.Parent = toastHolder
	corner(frame, 12)
	stroke(frame, accent, 2)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(4, 30)
	bar.Position = UDim2.fromOffset(10, 8)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = frame
	corner(bar, 2)

	local label = text(frame, "Label", UDim2.new(1, -32, 1, 0), UDim2.fromOffset(24, 0), 14, CREAM)
	label.Text = message
	label.TextWrapped = true

	frame.Position = UDim2.fromOffset(40, 0)
	TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
		Position = UDim2.fromOffset(0, 0),
	}):Play()

	task.delay(4.5, function()
		if not frame.Parent then
			return
		end
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		local fade = TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		frame:Destroy()
	end)
end

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
	cashValue.Text = string.format("%d", amount)
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
		"Ekwipunek %d  |  Brudne %d  |  Polki %d/6",
		#profile.Inventory,
		dirty,
		#profile.Displayed
	)
end

Remotes.event("BalanceChanged").OnClientEvent:Connect(function(amount: number)
	setBalance(amount)
end)

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
	auctionBid.Text = string.format("$%d", data.StartingBid or 0)
	auctionLeader.Text = if data.Leader then "prowadzi " .. data.Leader else "brak ofert"
	auctionLeader.TextColor3 = if data.Leader then MINT else MUTED
	toast(string.format("Nowy locker: %s (%d przedmiotow)", tostring(data.TierId), data.ItemCount or 0), GOLD)
end)

Remotes.event("AuctionEnded").OnClientEvent:Connect(function(data)
	if data.Winner then
		toast(string.format("%s wygral locker za $%d", data.Winner, data.Price), GOLD)
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
	toast(string.format("Wyczyszczone: %s -> $%d", item.Name, item.Value), MINT)
	refreshStats()
end)

Remotes.event("Notify").OnClientEvent:Connect(function(message: string)
	toast(message, VIOLET)
	refreshStats()
end)

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
