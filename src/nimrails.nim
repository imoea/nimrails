import sdl2
import engine, types

proc main() =
  sdlFailIf(not sdl2.init(INIT_EVERYTHING), "SDL2 initialisation failed")
  defer: sdl2.quit()

  let window = createWindow(
    title = "30 Rails",
    x = SDL_WINDOWPOS_CENTERED,
    y = SDL_WINDOWPOS_CENTERED,
    w = 512, # window width
    h = 256, # window height
    flags = SDL_WINDOW_SHOWN
  )
  sdlFailIf(window.isNil, "Window could not be created")
  defer: window.destroy()

  let renderer = window.createRenderer(
    index = -1,
    flags = Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture
  )
  sdlFailIf(renderer.isNil, "Renderer could not be created")
  defer: renderer.destroy()

  var game = newGameRef(renderer)
  game.run()

main()
