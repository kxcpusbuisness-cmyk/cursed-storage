--!strict
-- Minimalny HUD: gotowka, faza dnia, licytacja, powiadomienia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Loot = require(Shared:WaitForChild("Loot"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "CursedStorageHUD"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = playerGui

local function makeLabel(name: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 245, 225)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = ""
	label.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label

	return label
end

local balanceLabel = makeLabel("Balance", UDim2.new(0, 16, 0, 16), UDim2.new(0, 200, 0, 48))
local phaseLabel = makeLabel("Phase", UDim2.new(0, 16, 0, 72), UDim2.new(0, 200, 0, 36))
local auctionLabel = makeLabel("Auction", UDim2.new(0.5, -180, 0, 16), UDim2.new(0, 360, 0, 56))
local notifyLabel = makeLabel("Notify", UDim2.new(0.5, -180, 0, 84), UDim2.new(0, 360, 0, 36))
notifyLabel.Visible = false

local function setBalance(amount: number)
	balanceLabel.Text = string.format("$ %d", amount)
end

Remotes.event("BalanceChanged").OnClientEvent:Connect(setBalance)

Remotes.event("PhaseChanged").OnClientEvent:Connect(function(phase: string)
	if phase == "Night" then
		phaseLabel.Text = "NOC - napady otwarte"
		phaseLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
	else
		phaseLabel.Text = "DZIEN - aukcje i handel"
		phaseLabel.TextColor3 = Color3.fromRGB(255, 210, 120)
	end
end)

local currentLotId: string? = nil

Remotes.event("AuctionStarted").OnClientEvent:Connect(function(data)
	currentLotId = data.LotId
	local leader = if data.Leader then " | " .. data.Leader else ""
	auctionLabel.Text = string.format(
		"Locker %s | %d przedmiotow | $%d%s",
		data.TierId,
		data.ItemCount,
		data.StartingBid,
		leader
	)
end)

Remotes.event("AuctionEnded").OnClientEvent:Connect(function(data)
	currentLotId = nil
	if data.Winner then
		auctionLabel.Text = string.format("Sprzedane: %s za $%d", data.Winner, data.Price)
	else
		auctionLabel.Text = "Locker niesprzedany"
	end
end)

Remotes.event("ItemRevealed").OnClientEvent:Connect(function(item)
	local rarity = Loot.rarityById(item.Rarity)
	notifyLabel.Text = string.format("%s [%s] ~ $%d", item.Name, item.Rarity, item.Value)
	notifyLabel.TextColor3 = rarity.Color
	notifyLabel.Visible = true
end)

Remotes.event("ItemCleaned").OnClientEvent:Connect(function(item)
	notifyLabel.Text = string.format("Wyczyszczone: %s -> $%d", item.Name, item.Value)
	notifyLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
	notifyLabel.Visible = true
end)

Remotes.event("Notify").OnClientEvent:Connect(function(message: string)
	notifyLabel.Text = message
	notifyLabel.TextColor3 = Color3.fromRGB(255, 245, 225)
	notifyLabel.Visible = true
end)

-- Przykladowy sposob licytowania z klienta.
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
