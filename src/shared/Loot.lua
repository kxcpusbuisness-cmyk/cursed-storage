--!strict
-- Losowanie rzadkosci i generowanie zawartosci lockera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Config = require(Shared:WaitForChild("Config"))
local ItemDefs = require(Shared:WaitForChild("ItemDefs"))

local Loot = {}

export type LootItem = {
	Uid: string,
	DefId: string,
	Name: string,
	Rarity: string,
	Value: number,
	Dirty: boolean,
}

local uidCounter = 0
local function nextUid(): string
	uidCounter += 1
	return string.format("it_%d_%d", os.time(), uidCounter)
end

function Loot.rarityById(id: string)
	for _, rarity in Config.Rarities do
		if rarity.Id == id then
			return rarity
		end
	end
	return Config.Rarities[1]
end

-- rarityBoost > 0 zwieksza szanse na wysokie rzadkosci
function Loot.rollRarity(rarityBoost: number, rng: Random)
	local weights = {}
	local total = 0
	for index, rarity in Config.Rarities do
		local boost = 1 + rarityBoost * ((index - 1) / #Config.Rarities) * 4
		local weight = rarity.Weight * boost
		weights[index] = weight
		total += weight
	end

	local roll = rng:NextNumber() * total
	for index, weight in weights do
		roll -= weight
		if roll <= 0 then
			return Config.Rarities[index]
		end
	end
	return Config.Rarities[1]
end

function Loot.rollItem(rarityBoost: number, rng: Random): LootItem
	local def = ItemDefs[rng:NextInteger(1, #ItemDefs)]
	local rarity = Loot.rollRarity(rarityBoost, rng)
	local variance = rng:NextNumber(0.85, 1.2)
	local value = math.floor(def.BaseValue * rarity.ValueMultiplier * variance)

	return {
		Uid = nextUid(),
		DefId = def.Id,
		Name = def.Name,
		Rarity = rarity.Id,
		Value = math.max(1, value),
		Dirty = true,
	}
end

function Loot.rollLocker(tierId: string, seed: number?)
	local tier = Config.LockerTiers[1]
	for _, candidate in Config.LockerTiers do
		if candidate.Id == tierId then
			tier = candidate
		end
	end

	local rng = Random.new(seed or os.clock() * 1e6)
	local items: { LootItem } = {}
	for _ = 1, tier.ItemCount do
		table.insert(items, Loot.rollItem(tier.RarityBoost, rng))
	end

	local totalValue = 0
	for _, item in items do
		totalValue += item.Value
	end

	return {
		TierId = tier.Id,
		BasePrice = tier.BasePrice,
		Items = items,
		TotalValue = totalValue,
	}
end

-- Wartosc sprzedazy zalezy od tego, czy przedmiot jest wyczyszczony.
function Loot.sellValue(item: LootItem): number
	if item.Dirty then
		return math.floor(item.Value * Config.Cleaning.DirtyValueMultiplier)
	end
	return item.Value
end

return Loot
