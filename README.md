# Cursed Storage

Roblox experience: kupuj porzucone lockery na aukcji, czysc i wyceniaj znaleziska,
wystawiaj je w swoim lombardzie dla pasywnego dochodu i okradaj innych graczy
w nocnym okienku napadow.

## Uruchomienie

1. Zainstaluj plugin Rojo w Roblox Studio (Creator Store).
2. W folderze projektu uruchom serwer:

```bash
rojo.exe serve
```

3. W Studio otworz panel Rojo i kliknij **Connect** (w trybie edycji, nie w czasie testu).
4. Wcisnij Play. W konsoli powinno pojawic sie `[CursedStorage] Serwer uruchomiony.`

## Wymagania w Studio

- Home > Game Settings > Security > **Enable Studio Access to API Services** (DataStore).
- Testowanie napadow wymaga dwoch graczy: Test > Clients and Servers > 2 players.

## Struktura

```text
src/shared   -> Config, ItemDefs, Loot, Remotes (ReplicatedStorage.Shared)
src/server   -> serwisy gry (ServerScriptService.Server)
src/client   -> HUD gracza (StarterPlayerScripts.Client)
```

## Petla rozgrywki

1. **Aukcja** – `AuctionService` co jakis czas wystawia lockery czterech tierow.
   Klient widzi tylko tier i cene, nie zawartosc.
2. **Odkrywanie** – zwyciezca dostaje przedmioty jako brudne.
3. **Czyszczenie** – `CleaningService` wymaga kilku interakcji; brudny przedmiot
   sprzedasz tylko za 35% wartosci.
4. **Lombard** – `ShopService` wyplaca pasywny dochod z wystawionych przedmiotow.
5. **Napad** – `HeistService` przelacza dzien/noc. Noca mozna kradnac wystawione
   przedmioty innych graczy, z kara predkosci przy noszeniu lupu.

## Balans

Cala ekonomia siedzi w `src/shared/Config.lua`:

- `Config.Rarities` – wagi losowania i mnozniki wartosci (Common ... Cursed).
- `Config.LockerTiers` – ceny startowe, liczba przedmiotow, `RarityBoost`.
- `Config.Heist` – dlugosc cyklu, dlugosc nocy, cooldown kradziezy.
- `Config.Shop` – slots ekspozycji i stawka pasywnego dochodu.

## Nastepne kroki

- Modele lockerow, wnetrze lombardu i strefy ekspozycji w Workspace.
- ProximityPrompt do licytacji, czyszczenia i kradziezy.
- Systemy obrony: alarmy, kamery, pulapki.
- Monetyzacja: dodatkowe sloty ekspozycji, szybsze czyszczenie, skiny lombardu.
- Zamiana ProfileService na ProfileStore przed publikacja (ochrona przed utrata danych).
