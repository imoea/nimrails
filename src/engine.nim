import sdl2, sdl2/[gfx, image]
import std/[algorithm, bitops, math, random, sequtils, tables]
import renderer, types

## Edge connectivity is denoted by a sequence of rotating bits, so a tile can be
## flipped or rotated with bit manipulations.
## - 4 edges of a tile are denoted by 4 bits each, totalling 16 bits.
## - 4 bits denote which other edges each edge is connected to.
##
##  rail1   rail2   rail3   rail4   rail5   rail6
##  .....   ..U..   ..U..   ..U..   .....   ..U..
##  .....   ..*..   .*...   ..*..   .....   ..*..
##  ....R   ..*..   L...R   L***R   L...R   ..*.R
##  ...*.   ..*..   ...*.   ..*..   .*.*.   ..**.
##  ..D..   ..D..   ..D..   ..D..   ..D..   ..D..
##
## RDLU = Right Down Left Up; e.g., DU, DR = Down->Up, Down->Right
let railEdges: Table[int, uint16] = {
  1: 0b1100_1100_0000_0000'u16, # RD; DR    ;   ;
  2: 0b0000_0101_0000_0101'u16, #   ; DU    ;   ; UD
  3: 0b1100_1100_0011_0011'u16, # RD; DR    ; LU; UL
  4: 0b1010_0101_1010_0101'u16, # RL; DU    ; LR; UD
  5: 0b1100_1110_0110_0000'u16, # RD; DL, DR; LD;
  6: 0b1100_1101_0000_0101'u16  # RD; DU, DR;   ; UD
}.toTable

proc newSpritesRef*(texture: TexturePtr; w, h: cint): SpritesRef =
  ## Create a new spritesheet reference.

  new result
  result.texture = texture
  result.clip = rect(0, 0, w, h)

proc newUIRef(): UIRef =
  ## Create a new UI reference.

  new result

  result.layout[0] = Tile(kind: override)
  result.layout[1] = Tile(kind: override)

  # Index the layout and offset it to the right.
  for i in 0..63:
    result.layout[i].idx = i
    result.layout[i].offset = 256

proc newGameRef*(renderer: RendererPtr; w: int = 6): GameRef =
  ## Create a new game reference.

  new result
  result.renderer = renderer

  # Load the font.
  discard readBytes(open("assets/IBM_VGA_8x16.bin"), result.bmpFont, 0, 4096)
  gfxPrimitivesSetFont(addr result.bmpFont, 8, 16)

  # Load the tile sprites.
  result.sprites = newSpritesRef(
    renderer.loadTexture("assets/spritesheet.png"), 16, 16)
  sdlFailIf(result.sprites.texture.isNil, "Sprites could not be created")

  # Load the UI.
  result.ui = newUIRef()

  # Index the map.
  for i in 0..63:
    result.map[i].idx = i

############
# GAMEPLAY #
############

proc flip(t: var Tile) =
  ## Flip a tile and update its edge connectivity.

  t.edges = ((t.edges and 0b0101_0101_0101_0101) or
             (t.edges and 0b0010_0010_0010_0010) shl 2 or
             (t.edges and 0b1000_1000_1000_1000) shr 2)
  t.flip = not t.flip

proc rotCCW(t: var Tile) =
  ## Rotate a tile counter-clockwise and update its edge connectivity.

  let b = t.edges.rotateLeftBits(4)
  t.edges = 0
  for i in countup(0, 15, 4):
    let s = b.bitsliced(i .. i + 3)
    t.edges.setMask(rotateLeftBits(s or s shl 12, 1).bitsliced(0 .. 3) shl i)
  t.angle = if t.angle == 0: 270 else: t.angle - 90

proc rotCW(t: var Tile) =
  ## Rotate a tile clockwise and update its edge connectivity.

  let b = t.edges.rotateRightBits(4)
  t.edges = 0
  for i in countup(0, 15, 4):
    let s = b.bitsliced(i .. i + 3)
    t.edges.setMask(rotateRightBits(s or s shl 12, 1).bitsliced(12 .. 15) shl i)
  t.angle = if t.angle == 270: 0 else: t.angle + 90

proc isOnMap(idx: int): bool =
  ## Determine if a map index is on the map. Stations placed along the edges are
  ## not considered to be on the map.

  result = idx mod 8 in 1 .. 6 and idx div 8 in 1 .. 6

proc nextRound(g: GameRef) =
  ## Determine the new current tile and its valid placements on the map.

  inc g.currRound
  var
    nextTileKind = empty
    nextEdges: uint16

  case g.currRound

  of 1 .. 6:
    # Place a mountain randomly on each of the six rows.
    g.validPlacement = @[g.currRound * 8 + rand(1 .. 6)]
    nextTileKind = mountain
    g.text = "Click to place a mountain."

  of 7:
    # Select one mountain to be removed.
    g.validPlacement =
      g.map.filterIt(it.kind == mountain)
           .mapIt(it.idx)
           .sorted()
    g.text = "Choose a mountain to remove."

  of 8:
    # Place a mine beside one of the remaining five mountains.
    g.validPlacement =
      g.map.filterIt(it.kind == mountain)
           .mapIt(@[it.idx - 8, it.idx + 1, it.idx + 8, it.idx - 1])
           .concat()
           .filterIt(it.isOnMap() and g.map[it].kind == empty)
           .sorted()
    nextTileKind = mine
    g.text = "Place a mine."

  of 9 .. 12:
    # Place one station along each of the four map edges.
    g.validPlacement = @[]
    for idxRange in [
      [1, 2, 3, 4, 5, 6],       # Top edge
      [8, 16, 24, 32, 40, 48],  # Left edge
      [15, 23, 31, 39, 47, 55], # Right edge
      [57, 58, 59, 60, 61, 62]  # Bottom edge
    ]:
      block addRange:
        for idx in g.stationIdx.values():
          if idx in idxRange:
            break addRange
        g.validPlacement &= idxRange
    nextTileKind = TileKind(g.currRound)
    g.text = "Place a station."

  of 13:
    # Set any one of the remaining empty tiles as the bonus tile.
    g.validPlacement =
      g.map.filterIt(it.kind == empty and it.idx.isOnMap())
           .mapIt(it.idx)
           .sorted()
    g.text = "Select a bonus tile."

  of 14 .. 43:
    # Place the remaining rails on any empty tiles along a row or column as
    # determined by a die roll.
    let n = rand(1 .. 6)
    g.validPlacement = countup(n + 8, n + 48, 8).toSeq() # n-th column
    g.validPlacement &= (n * 8 + 1 .. n * 8 + 6).toSeq() # n-th row
    g.validPlacement.keepItIf(g.map[it].kind == empty)
    if g.validPlacement.len == 0:
      # If there are no more empty tiles along a given row or column, allow
      # placement on any empty tile on the map.
      g.validPlacement =
        g.map.filterIt(it.kind == empty and it.idx.isOnMap())
             .mapIt(it.idx)
             .sorted()
    nextTileKind = TileKind(rand(1 .. 6))
    # Get the edge connectivity of the rail tile.
    nextEdges = railEdges[nextTileKind.ord]
    g.text = "Place the next rail tile."

  else: discard

  # Create a new tile for the current round.
  g.currTile = Tile(idx: g.validPlacement[0], kind: nextTileKind,
                    edges: nextEdges)

proc moveCurrTile(g: GameRef) =
  ## Move the current tile to the mouse position.

  if g.mousePos.x < 256 and g.mousePos.y < 256:
    let idx = (g.mousePos.y div 32) * 8 + (g.mousePos.x div 32)
    if idx in g.validPlacement:
      g.currTile.idx = idx

proc placeCurrTile(g: GameRef) =
  ## Place the current tile on the game map.

  case g.currTile.kind

  of empty:
    if g.currRound == 13:
      # Set the bonus tile.
      g.bonusIdx = g.currTile.idx

  of mine:
    # Place the mine.
    g.mineIdx = g.currTile.idx

  of number1, number2, number3, number4:
    # Place a station and determine its connecting edge.
    g.stationIdx[g.currTile.kind.ord - 6] = g.currTile.idx
    g.currTile.edges = (
      case g.currTile.idx
      of 1, 2, 3, 4, 5, 6: 0b0000_0100_0000_0000 # D
      of 8, 16, 24, 32, 40, 48: 0b1000_0000_0000_0000 # R
      of 15, 23, 31, 39, 47, 55: 0b0000_0000_0010_0000 # L
      of 57, 58, 59, 60, 61, 62: 0b0000_0000_0000_0001 # U
      else: 0
    )

  else: discard

  g.map[g.currTile.idx] = g.currTile
  g.nextRound()

#############
# GAME LOOP #
#############

proc handleInput(g: GameRef) =
  ## Handle the player's keyboard and mouse input.

  var event = defaultEvent
  while pollEvent(event):
    case event.kind

    of QuitEvent:
      # Quit the game.
      g.quit = true

    of MouseButtonUp:
      case event.button.button:

      of BUTTON_LEFT:
        if g.mousePos.x < 256:
          # Place the current tile on the game map.
          g.placeCurrTile()

      of BUTTON_RIGHT:
        # Flip the orientation of the current tile.
        if g.currRound in 14 .. 43 and g.currTile.kind == rail6:
          g.currTile.flip()

      else: discard

    of MouseMotion:
      # Move the current tile to the mouse position.
      g.mousePos = (event.motion.x, event.motion.y)
      g.moveCurrTile()

    of MouseWheel:
      # Rotate the current tile.
      if g.currRound in 14 .. 43:
        if event.wheel.y > 0:
          g.currTile.rotCCW()
        elif event.wheel.y < 0:
          g.currTile.rotCW()

    else: discard

proc render(g: GameRef) =
  ## Render the game map and UI.

  g.renderer.setDrawColor(255, 255, 255, 255)
  g.renderer.clear()

  g.drawMap()
  g.drawTile(g.currTile)
  g.drawUI()

  g.renderer.present()

proc run*(g: GameRef) =
  ## Run the game

  g.nextRound()
  while not g.quit:
    let start = getPerformanceCounter()

    g.handleInput()
    g.render()

    let
      finish = getPerformanceCounter()
      elapsedMS = (finish - start).float / getPerformanceFrequency().float
    delay(floor(16.666 - elapsedMS).uint32)
