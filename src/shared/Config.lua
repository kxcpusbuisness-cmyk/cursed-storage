--!strict
-- Centralna konfiguracja gry Cursed Storage.
-- Zmieniaj wartosci tutaj, zeby balansowac ekonomie bez ruszania logiki.

local Config = {}

Config.Currency = {
	Name = "Cash",
	StartingBalance = 500,
}

-- Aukcje lockerow
Config.Auction = {
	IntervalSeconds = 90, -- jak czesto startuje nowa aukcja
	BiddingSeconds = 20, -- ile trwa licytacja
	MinBidStep = 25,
	LockersPerRound = 3,
}

-- Okno napadow (heist)
Config.Heist = {
	CycleSeconds = 300, -- pelny cykl dzien + noc
	NightSeconds = 90, -- ile trwa okno kradziezy
	CarrySpeedPenalty = 0.55, -- mnoznik predkosci podczas noszenia lupu
	StealCooldownSeconds = 45, -- cooldown na okradanie tego samego gracza
}

-- Pasywny dochod z lombardu
Config.Shop = {
	PayoutIntervalSeconds = 15,
	DisplaySlots = 12,
	PassiveRatePerValue = 0.01, -- 1% wartosci wystawionych przedmiotow na wyplate
}

-- Czyszczenie przedmiotow
Config.Cleaning = {
	DirtyValueMultiplier = 0.35, -- brudny przedmiot sprzedasz znacznie taniej
	ScrubsRequired = 5,
	SecondsPerScrub = 0.35,
}

-- Rzadkosci: waga losowania, mnoznik wartosci, kolor UI
Config.Rarities = {
	{ Id = "Common", Weight = 1000, ValueMultiplier = 1.0, Color = Color3.fromRGB(170, 170, 170) },
	{ Id = "Uncommon", Weight = 450, ValueMultiplier = 1.8, Color = Color3.fromRGB(90, 200, 120) },
	{ Id = "Rare", Weight = 180, ValueMultiplier = 3.5, Color = Color3.fromRGB(70, 150, 255) },
	{ Id = "Epic", Weight = 60, ValueMultiplier = 7.5, Color = Color3.fromRGB(170, 100, 255) },
	{ Id = "Legendary", Weight = 14, ValueMultiplier = 18.0, Color = Color3.fromRGB(255, 180, 40) },
	{ Id = "Cursed", Weight = 4, ValueMultiplier = 45.0, Color = Color3.fromRGB(255, 60, 60) },
}

-- Typy lockerow na aukcji
Config.LockerTiers = {
	{ Id = "Dusty", BasePrice = 150, ItemCount = 3, RarityBoost = 0.0 },
	{ Id = "Sealed", BasePrice = 600, ItemCount = 5, RarityBoost = 0.35 },
	{ Id = "Evidence", BasePrice = 2200, ItemCount = 6, RarityBoost = 0.9 },
	{ Id = "Condemned", BasePrice = 9000, ItemCount = 8, RarityBoost = 1.8 },
}

Config.Datastore = {
	Name = "CursedStorage_Player_v1",
	AutosaveSeconds = 60,
}

return Config
