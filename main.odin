package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/linalg"

import "vendor:sdl2"
import "vendor:sdl2/ttf"

Object :: struct {
    x: f64,
    y: f64,
    velocity: [2]f64,
    mass: f64,
}

SPEED :: 5

radius_from_mass :: proc(mass: f64) -> f64 {
    return math.sqrt(mass) / 2
}

update_objects :: proc(objects: ^[dynamic]Object) {
    for _ in 0..<SPEED {
        i := 0
        for i < len(objects) {
            skip_add := false
            object := &objects[i]
            object.x += object.velocity.x
            object.y += object.velocity.y
            j := 0
            for j < len(objects) {
                skip_add = false
                object_inside := &objects[j]
                other_x, other_y: f64
                other_mass: f64

                other_x = object_inside.x
                other_y = object_inside.y
                other_mass = object_inside.mass

                if object != object_inside {
                    other_distance: [2]f64
                    other_distance.x = other_x - object.x
                    other_distance.y = (other_y - object.y)

                    other_normalized := linalg.vector_normalize(other_distance)

                    distance := linalg.distance(other_distance, [?]f64{0, 0})
                    if distance < radius_from_mass(object.mass) || distance < radius_from_mass(other_mass) {
                        if object.mass > object_inside.mass {
                            object_inside.x = object.x
                            object_inside.y = object.y
                        }

                        object_inside.mass += object.mass
                        object_inside.velocity /= 4

                        unordered_remove(objects, i)

                        skip_add = true
                        break
                    }

                    effect := 0.01 * (1 / math.max(distance, 1)) * other_mass * (1 / object.mass)

                    new_velocity: [2]f64
                    new_velocity.x = object.velocity.x * (1 - effect) + other_normalized.x * effect
                    new_velocity.y = object.velocity.y * (1 - effect) + other_normalized.y * effect
                    object.velocity = new_velocity
                }

                j += 1
            }
            if !skip_add {
                i += 1
            }
        }
    }
}

render_object :: proc(renderer: ^sdl2.Renderer, object: Object) {
    x, y, w, h: uint
    radius := radius_from_mass(object.mass)
    x = cast(uint) (object.x - radius)
    y = cast(uint) (object.y - radius)
    w = cast(uint) radius * 2
    h = cast(uint) radius * 2

    box: sdl2.Rect
    box.x = cast(i32) x
    box.y = cast(i32) y
    box.w = cast(i32) w
    box.h = cast(i32) h
    sdl2.RenderFillRect(renderer, &box)
}

SCREEN_WIDTH :: 1920
SCREEN_HEIGHT :: 1080

render_filled_rect :: proc(renderer: ^sdl2.Renderer, x: i32, y: i32, w: i32, h: i32, color: u32) {
    box: sdl2.Rect
    box.x = x
    box.y = y
    box.w = w
    box.h = h
    sdl2.SetRenderDrawColor(renderer, cast(u8) (color >> 24) & 0xFF, cast(u8) (color >> 16) & 0xFF, cast(u8) (color >> 8) & 0xFF, cast(u8) (color >> 0) & 0xFF)
    sdl2.RenderFillRect(renderer, &box)
}

MIN_MASS :: 128
MAX_MASS :: 16384

config_dimensions :: proc() -> (x: i32, y: i32, w: i32, h: i32) {
    x = (SCREEN_WIDTH - 20) - (SCREEN_WIDTH / 3)
    y = 20
    w = SCREEN_WIDTH / 3
    h = SCREEN_HEIGHT - 40
    return
}

config_mass_slider_dimensions :: proc() -> (x: i32, y: i32, by: i32, w: i32, h: i32, bh: i32) {
    gui_x, gui_y, gui_w, gui_h := config_dimensions()
    w = gui_w - 80
    h = 25
    bh = 5
    x = gui_x + 40
    y = gui_y + 80
    by = y + (h / 2) - bh / 2
    return
}

config_delete_button_dimensions :: proc() -> (x: i32, y: i32, w: i32, h: i32) {
    gui_x, gui_y, gui_w, gui_h := config_dimensions()
    x = gui_x + 40
    y = gui_y + 120
    w = 25
    h = 25
    return
}

handle_click_config :: proc(x: i32, y: i32, state: ^State) {
    gui_x, gui_y, gui_w, gui_h := config_dimensions()

    sx, sy, sby, sw, sh, sbh := config_mass_slider_dimensions()
    if x > sx && x < sx + sw && y > sy && y < sy + sh {
        mass_percentage := cast(f64) (x - sx) / cast(f64) sw
        state.current_object_config.mass = mass_percentage * (MAX_MASS - MIN_MASS) + MIN_MASS
        state.dragging_slider = true
    }

    bx, by, bw, bh := config_delete_button_dimensions()
    if x > bx && x < bx + bw && y > by && y < by + bh {
        index := -1
        for &object, i in state.objects {
            if &object == state.current_object_config {
                index = i
            }
        }
        assert(index >= 0)
        unordered_remove(&state.objects, index)
        state.current_object_config = nil
    }
}

handle_move_config :: proc(x: i32, y: i32, state: ^State) {
    gui_x, gui_y, gui_w, gui_h := config_dimensions()

    if state.dragging_slider {
        sx, sy, sby, sw, sh, sbh := config_mass_slider_dimensions()
        mass_percentage := cast(f64) (x - sx) / cast(f64) sw
        mass_percentage = max(min(mass_percentage, 1), 0)
        state.current_object_config.mass = mass_percentage * (MAX_MASS - MIN_MASS) + MIN_MASS
    }
}

handle_unclick_config :: proc(x: i32, y: i32, state: ^State) {
    if state.dragging_slider {
        state.dragging_slider = false
    }
}

render_config :: proc(renderer: ^sdl2.Renderer, state: ^State) {
    x, y, w, h := config_dimensions()
    render_filled_rect(renderer, x, y, w, h, 0x50505050)

    // Mass Slider
    {
        sx, sy, sby, sw, sh, sbh := config_mass_slider_dimensions()
        render_filled_rect(renderer, sx, sby, sw, sbh, 0x303030FF)
        mass_percentage := cast(f64) (state.current_object_config.mass - MIN_MASS) / cast(f64) (MAX_MASS - MIN_MASS)
        render_filled_rect(renderer, sx - (sh / 2) + cast(i32) (cast(f64) sw * mass_percentage), sy, sh, sh, 0xAAAAAAFF)
    }

    // Delete button
    {
        bx, by, bw, bh := config_delete_button_dimensions()
        render_filled_rect(renderer, bx, by, bw, bh, 0xAAAAAAFF)
    }
}

State :: struct {
    running: bool,
    current_object_config: ^Object,
    dragging_slider: bool,
    objects: [dynamic]Object
}

main :: proc() {
    sdl2.Init(sdl2.INIT_EVERYTHING)
    window := sdl2.CreateWindow("Window", sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED, SCREEN_WIDTH, SCREEN_HEIGHT, sdl2.WINDOW_SHOWN)
    renderer := sdl2.CreateRenderer(window, -1, sdl2.RENDERER_ACCELERATED | sdl2.RENDERER_PRESENTVSYNC)

    ttf.Init()
    font := ttf.OpenFont("OpenSans-Regular.ttf", 24)

    paused_surface := ttf.RenderText_Solid(font, "(paused)", {255, 0, 0, 255})
    paused_text := sdl2.CreateTextureFromSurface(renderer, paused_surface)
    paused_w, paused_h: c.int
    ttf.SizeText(font, "(paused)", &paused_w, &paused_h)

    state: State

    loop: for {
        event: sdl2.Event
        for sdl2.PollEvent(&event) {
            if event.type == .QUIT {
                break loop
            } else if event.type == .KEYDOWN {
                key := event.key
                #partial switch key.keysym.scancode {
                    case .R:
                        clear(&state.objects)
                        state = State {}
                    case .S:
                        state.running = !state.running
                }
            } else if event.type == .MOUSEBUTTONDOWN {
                event_handle: {
                    button_event := event.button
                    event_x := button_event.x
                    event_y := button_event.y

                    if state.current_object_config != nil && event_x > (SCREEN_WIDTH - 5) - (SCREEN_WIDTH / 3) {
                        handle_click_config(button_event.x, button_event.y, &state)
                        break event_handle
                    } else if state.current_object_config != nil {
                        state.current_object_config = nil
                        break event_handle
                    }


                    for &object in state.objects {
                        object_left := cast(i32) (object.x - radius_from_mass(object.mass))
                        object_right := cast(i32) (object.x + radius_from_mass(object.mass))
                        object_top := cast(i32) (object.y - radius_from_mass(object.mass))
                        object_bottom := cast(i32) (object.y + radius_from_mass(object.mass))

                        if event_x > object_left && event_x < object_right && event_y > object_top && event_y < object_bottom {
                            state.current_object_config = &object
                            break event_handle
                        }
                    }

                    append(&state.objects, Object { cast(f64) event_x, cast(f64) event_y, {0, 0}, 240 })
                }
            } else if event.type == .MOUSEBUTTONUP {
                event_handle_up: {
                    button_event := event.button
                    event_x := button_event.x
                    event_y := button_event.y

                    if state.current_object_config != nil {
                        handle_unclick_config(event_x, event_y, &state)
                        break event_handle_up
                    }
                }
            } else if event.type == .MOUSEMOTION {
                motion_event := event.button
                event_x := motion_event.x
                event_y := motion_event.y

                if state.current_object_config != nil {
                    handle_move_config(event_x, event_y, &state)
                }
            }
        }

        if state.running {
            update_objects(&state.objects)
        }

        sdl2.SetRenderDrawColor(renderer, 0x10, 0x10, 0x10, 0x00)
        sdl2.RenderClear(renderer)

        if !state.running {
            paused_rect := sdl2.Rect { 0, 0, paused_w, paused_h }
            sdl2.RenderCopy(renderer, paused_text, nil, &paused_rect)
        }

        sdl2.SetRenderDrawColor(renderer, 0xEE, 0xEE, 0xEE, 0xFF)
        for object in state.objects {
            render_object(renderer, object)
        }

        if state.current_object_config != nil {
            render_config(renderer, &state)
        }

        sdl2.RenderPresent(renderer)
    }
}
