--!strict
-- Definicje przedmiotow. BaseValue jest przed mnoznikiem rzadkosci.

export type ItemDef = {
	Id: string,
	Name: string,
	BaseValue: number,
	Category: string,
	CleanSeconds: number,
}

local ItemDefs: { ItemDef } = {
	{ Id = "old_tv", Name = "Stary telewizor", BaseValue = 60, Category = "Electronics", CleanSeconds = 2 },
	{ Id = "vinyl_box", Name = "Pudlo winyli", BaseValue = 90, Category = "Media", CleanSeconds = 2 },
	{ Id = "rusty_bike", Name = "Zardzewialy rower", BaseValue = 120, Category = "Sport", CleanSeconds = 3 },
	{ Id = "arcade_cab", Name = "Automat arcade", BaseValue = 350, Category = "Electronics", CleanSeconds = 4 },
	{ Id = "pocket_watch", Name = "Zegarek kieszonkowy", BaseValue = 400, Category = "Jewelry", CleanSeconds = 2 },
	{ Id = "taxidermy_owl", Name = "Wypchana sowa", BaseValue = 260, Category = "Oddity", CleanSeconds = 3 },
	{ Id = "gold_coin", Name = "Zlota moneta", BaseValue = 700, Category = "Jewelry", CleanSeconds = 1 },
	{ Id = "painting", Name = "Zakurzony obraz", BaseValue = 850, Category = "Art", CleanSeconds = 4 },
	{ Id = "doll", Name = "Porcelanowa lalka", BaseValue = 300, Category = "Oddity", CleanSeconds = 3 },
	{ Id = "ritual_mask", Name = "Maska rytualna", BaseValue = 1500, Category = "Cursed", CleanSeconds = 5 },
	{ Id = "music_box", Name = "Pozytywka", BaseValue = 1100, Category = "Cursed", CleanSeconds = 4 },
	{ Id = "sealed_urn", Name = "Zapieczetowana urna", BaseValue = 2600, Category = "Cursed", CleanSeconds = 6 },
}

return ItemDefs
