# Nim Rails

Last updated: 2025-04-12

An experimental implementation of the game [30 Rails](https://boardgamegeek.com/boardgame/200551/30-rails) with [SDL2 for Nim](https://github.com/nim-lang/sdl2).

## To-do

Features:

- [x] Tile placement
- [x] Game rounds
- [ ] Overrides
- [ ] Scoring
- [ ] Advanced game

## Dependencies

### Assets

- [IBM VGA 8x16](https://int10h.org/oldschool-pc-fonts/fontlist/font?ibm_vga_8x16) font (included)

### Libraries

Install SDL2 development libraries on Ubuntu.

```sh
sudo apt update
sudo apt install libsdl2-dev libsdl2-gfx-dev libsdl2-image-dev
```

Add the following dependencies to the `.nimble` file, or install them manually with `nimble install`.

```nimble
requires "sdl2"  # nimble install sdl2
```
