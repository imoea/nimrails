import sdl2
import std/[tables]

type
  SDLException = object of Defect

  SpritesRef* = ref object
    texture*: TexturePtr
    clip*: Rect

  Position* = tuple
    x, y: int

  TileKind* = enum
    empty, rail1, rail2, rail3, rail4, rail5, rail6, mountain, mine,
    number1, number2, number3, number4, number5, number6, override

  Tile* = object
    idx*, offset*: int
    kind*: TileKind = empty
    angle*, edges*: uint16
    flip*: bool

  UIRef* = ref object
    layout*: array[64, Tile]

  GameRef* = ref object
    bmpFont*: array[4096, byte]
    quit*: bool
    mousePos*: Position
    renderer*: RendererPtr
    sprites*: SpritesRef
    ui*: UIRef

    currRound*: int = 0
    nConnectedMines*, score*: int
    map*: array[64, Tile]
    bonusIdx*, currDstIdx*, currSrcIdx*, mineIdx*: int
    stationIdx*: Table[int, int]

    allowBlackOverride*, allowWhiteOverride*: bool = true
    currTile*: Tile
    validPlacement*: seq[int]
    text*: cstring

template sdlFailIf*(cond: typed, reason: string) =
  if cond:
    raise SDLException.newException(reason & ", SDL error: " & $getError())
