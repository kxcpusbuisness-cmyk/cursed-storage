# Workflow: zmiany na biezaco

```text
AI commituje na GitHub  ->  GitHub Desktop: Pull  ->  Rojo serve  ->  Roblox Studio
```

## Jednorazowa konfiguracja

1. Zainstaluj GitHub Desktop: https://desktop.github.com
2. **File > Clone repository** > `kxcpusbuisness-cmyk/cursed-storage`
3. Jako lokalizacje wskaz `C:\Users\kacper\Documents` (powstanie folder `cursed-storage`).
4. Wrzuc `rojo.exe` do tego folderu.
5. W CMD:

```bat
cd /d "%USERPROFILE%\Documents\cursed-storage"
rojo.exe serve
```

6. W Studio: panel Rojo > **Connect** (w trybie edycji).

## Codzienna petla

1. Mowisz, co zmienic.
2. AI wypycha commit na `main`.
3. W GitHub Desktop klikasz **Fetch origin**, potem **Pull origin**.
4. Rojo natychmiast wysyla zmiany do Studio - nie trzeba restartowac serwera.

## Uwagi

- Synchronizacja jest jednokierunkowa: pliki na dysku nadpisuja skrypty w Studio.
  Kod edytuj wiec w plikach, a nie w Studio.
- Modele, mape i terrain buduj w Studio - Rojo ich nie rusza, bo nie sa w `src`.
- Plugin Rojo dziala tylko w trybie edycji. Rozlaczenie przy Play jest normalne.
