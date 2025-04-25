import sdl2, sdl2/[gfx]
import types

proc toRect(idx: int; dx: int = 0): Rect =
  ## Convert a map index into a rect for drawing tiles.

  result = rect(((idx mod 8) * 32 + dx).cint, ((idx div 8) * 32).cint, 32, 32)

proc drawTile*(g: GameRef, t: Tile) =
  ## Draw a tile to the game map, accounting for its orientation.

  g.sprites.clip.x = t.kind.ord.cint * g.sprites.clip.w
  g.sprites.clip.y = 0
  var
    dest = t.idx.toRect(t.offset)
    center = point(16, 16)
    flip = if t.flip: SDL_FLIP_HORIZONTAL else: SDL_FLIP_NONE
  g.renderer.copyEx(g.sprites.texture, addr g.sprites.clip, addr dest,
                    t.angle.cdouble, addr center, flip)

proc drawMap*(g: GameRef) =
  ## Draw the game map.

  # Highlight valid placements in gray.
  g.renderer.setDrawColor(211, 211, 211, 255)
  for idx in g.validPlacement:
    var dest = idx.toRect()
    g.renderer.fillRect(addr dest)

  # Draw non-empty tiles.
  for tile in g.map:
    if tile.kind != empty:
      g.drawTile(tile)

  # Highlight the bonus tile with a red border.
  g.renderer.setDrawColor(255, 0, 0, 255)
  if g.bonusIdx != 0:
    var dest = g.bonusIdx.toRect()
    g.renderer.drawRect(addr dest)

proc drawUI*(g: GameRef) =
  ## Draw the UI.

  # Draw UI elements.
  g.renderer.setDrawColor(211, 211, 211, 255)
  var dest = g.ui.layout[1].idx.toRect(g.ui.layout[1].offset)
  g.renderer.fillRect(addr dest)

  for tile in g.ui.layout:
    if tile.kind != empty:
      g.drawTile(tile)

  discard g.renderer.stringColor(272, 224, g.text, 0xFF000000.uint32)
