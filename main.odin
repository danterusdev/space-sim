package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/linalg"

import "vendor:sdl2"

Object :: union {
    StaticObject,
    DynamicObject,
}

StaticObject :: struct {
    x: f64,
    y: f64,
    mass: uint,
}

DynamicObject :: struct {
    x: f64,
    y: f64,
    velocity: [2]f64,
    mass: uint,
}

SPEED :: 5

size_from_mass :: proc(mass: f64) -> f64 {
    return math.sqrt(mass)
}

update_objects :: proc(objects: ^[dynamic]Object) {
    for _ in 0..<SPEED {
        i := 0
        for i < len(objects) {
            skip_add := false
            object := &objects[i]
            switch &o in object {
                case DynamicObject:
                    o.x += o.velocity.x
                    o.y += o.velocity.y
                    j := 0
                    for j < len(objects) {
                        skip_add = false
                        object_inside := &objects[j]
                        other_x, other_y: f64
                        other_mass: uint

                        switch &ob in object_inside {
                            case StaticObject:
                                other_x = ob.x
                                other_y = ob.y
                                other_mass = ob.mass
                            case DynamicObject:
                                other_x = ob.x
                                other_y = ob.y
                                other_mass = ob.mass
                        }

                        if object != object_inside {
                            other_distance: [2]f64
                            other_distance.x = cast(f64) other_x - o.x
                            other_distance.y = (cast(f64) other_y - o.y)

                            other_normalized := linalg.vector_normalize(other_distance)

                            distance := linalg.distance(other_distance, [?]f64{0, 0})
                            if distance < size_from_mass(cast(f64) o.mass) / 2 || distance < size_from_mass(cast(f64) other_mass) / 2 {
                                switch &ob in object_inside {
                                    case StaticObject:
                                        ob.mass += o.mass
                                    case DynamicObject:
                                        if o.mass > ob.mass {
                                            ob.x = o.x
                                            ob.y = o.y
                                        }

                                        ob.mass += o.mass
                                        ob.velocity /= 4
                                }

                                unordered_remove(objects, i)

                                skip_add = true
                                break
                            }

                            effect := 0.01 * (cast(f64) 1 / math.max(distance, 1)) * cast(f64) other_mass * (1 / cast(f64) o.mass)

                            new_velocity: [2]f64
                            new_velocity.x = o.velocity.x * (1 - effect) + other_normalized.x * effect
                            new_velocity.y = o.velocity.y * (1 - effect) + other_normalized.y * effect
                            o.velocity = new_velocity
                        }

                        j += 1
                    }
                case StaticObject:
            }
            if !skip_add {
                i += 1
            }
        }
    }
}

render_object :: proc(renderer: ^sdl2.Renderer, object: Object) {
    x, y, w, h: uint
    switch o in object {
        case StaticObject:
            size := size_from_mass(cast(f64) o.mass)
            x = cast(uint) (o.x - size / 2)
            y = cast(uint) (o.y - size / 2)
            w = cast(uint) size
            h = cast(uint) size
        case DynamicObject:
            size := size_from_mass(cast(f64) o.mass)
            x = cast(uint) (o.x - size / 2)
            y = cast(uint) (o.y - size / 2)
            w = cast(uint) size
            h = cast(uint) size
    }
    box: sdl2.Rect
    box.x = cast(i32) x
    box.y = cast(i32) y
    box.w = cast(i32) w
    box.h = cast(i32) h
    sdl2.RenderFillRect(renderer, &box)
}

SCREEN_WIDTH :: 1920
SCREEN_HEIGHT :: 1080

//reset_single_dynamic :: proc(objects: ^[dynamic]Object) {
//    clear(objects)
//    for _ in 0..<10 {
//        x := cast(f64) rand.int_max(SCREEN_WIDTH)
//        y := cast(f64) rand.int_max(SCREEN_HEIGHT)
//        mass := cast(uint) rand.int_max(240) + 120
//        append(objects, StaticObject { x, y, mass })
//    }
//
//    append(objects, DynamicObject { 0, 0, {2, 0}, 25 })
//}
//
//reset_multi_dynamic :: proc(objects: ^[dynamic]Object, count: u64) {
//    clear(objects)
//    for _ in 0..<count {
//        x := cast(f64) rand.int_max(SCREEN_WIDTH)
//        y := cast(f64) rand.int_max(SCREEN_HEIGHT)
//        x_velocity := rand.float64_range(0, 0.25)
//        y_velocity := rand.float64_range(0, 0.25)
//        mass := cast(uint) rand.int_max(1024) + 120
//        append(objects, DynamicObject { x, y, {x_velocity, y_velocity}, mass })
//    }
//}

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

handle_click_config :: proc(x: i32, y: i32, state: ^State) {
    gui_x: i32 = (SCREEN_WIDTH - 5) - (SCREEN_WIDTH / 3)
    gui_y: i32 = 5
    gui_w: i32 = SCREEN_WIDTH / 3
    gui_h: i32 = SCREEN_HEIGHT - 10

    if x > gui_x + 10 && x < gui_x + gui_w - 10 && y > gui_y + 30 && y < gui_y + 55 {
        mass_percentage := cast(f64) (x - (gui_x + 10)) / cast(f64) (gui_x + gui_w - 10 - (gui_x + 10))
        state.current_object_config.mass = cast(uint) (mass_percentage * cast(f64) (MAX_MASS - MIN_MASS) + cast(f64) MIN_MASS)
        state.dragging_slider = true
    }
}

handle_move_config :: proc(x: i32, y: i32, state: ^State) {
    gui_x: i32 = (SCREEN_WIDTH - 5) - (SCREEN_WIDTH / 3)
    gui_y: i32 = 5
    gui_w: i32 = SCREEN_WIDTH / 3
    gui_h: i32 = SCREEN_HEIGHT - 10

    if state.dragging_slider {
        mass_percentage := cast(f64) (x - (gui_x + 10)) / cast(f64) (gui_x + gui_w - 10 - (gui_x + 10))
        mass_percentage = max(min(mass_percentage, 1), 0)
        state.current_object_config.mass = cast(uint) (mass_percentage * cast(f64) (MAX_MASS - MIN_MASS) + cast(f64) MIN_MASS)
    }
}

handle_unclick_config :: proc(x: i32, y: i32, state: ^State) {
    if state.dragging_slider {
        state.dragging_slider = false
    }
}

render_config :: proc(renderer: ^sdl2.Renderer, state: ^State) {
    x: i32 = (SCREEN_WIDTH - 5) - (SCREEN_WIDTH / 3)
    y: i32 = 5
    w: i32 = SCREEN_WIDTH / 3
    h: i32 = SCREEN_HEIGHT - 10
    render_filled_rect(renderer, x, y, w, h, 0x50505050)

    // Mass Slider
    {
        render_filled_rect(renderer, x + 10, y + 40, w - 20, 5, 0x303030FF)
        mass_percentage := cast(f64) (state.current_object_config.mass - MIN_MASS) / cast(f64) (MAX_MASS - MIN_MASS)
        render_filled_rect(renderer, x + 10 - 12 + cast(i32) (cast(f64) (w - 20) * mass_percentage), y + 30, 25, 25, 0xAAAAAAFF)
    }
}

State :: struct {
    running: bool,
    current_object_config: ^DynamicObject,
    dragging_slider: bool,
}

main :: proc() {
    sdl2.Init(sdl2.INIT_EVERYTHING)
    window := sdl2.CreateWindow("Window", sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED, SCREEN_WIDTH, SCREEN_HEIGHT, sdl2.WINDOW_SHOWN)
    renderer := sdl2.CreateRenderer(window, -1, sdl2.RENDERER_ACCELERATED | sdl2.RENDERER_PRESENTVSYNC)

    objects: [dynamic]Object
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
                        clear(&objects)
                        state = State {}
                    case .S:
                        state.running = !state.running
                }
            } else if event.type == .MOUSEBUTTONDOWN {
                event_handle: {
                    button_event := event.button
                    event_x := cast(f64) button_event.x
                    event_y := cast(f64) button_event.y

                    if state.current_object_config != nil && event_x > (SCREEN_WIDTH - 5) - (SCREEN_WIDTH / 3) {
                        handle_click_config(button_event.x, button_event.y, &state)
                        break event_handle
                    } else if state.current_object_config != nil {
                        state.current_object_config = nil
                        break event_handle
                    }


                    for &object in objects {
                        o := &object.(DynamicObject)
                        object_left := o.x - size_from_mass(cast(f64) o.mass) / 2
                        object_right := o.x + size_from_mass(cast(f64) o.mass) / 2
                        object_top := o.y - size_from_mass(cast(f64) o.mass) / 2
                        object_bottom := o.y + size_from_mass(cast(f64) o.mass) / 2

                        if event_x > object_left && event_x < object_right && event_y > object_top && event_y < object_bottom {
                            state.current_object_config = o
                            break event_handle
                        }
                    }

                    append(&objects, DynamicObject { cast(f64) button_event.x, cast(f64) button_event.y, {0, 0}, 240 })
                }
            } else if event.type == .MOUSEBUTTONUP {
                event_handle_up: {
                    button_event := event.button
                    event_x := cast(f64) button_event.x
                    event_y := cast(f64) button_event.y

                    if state.current_object_config != nil {
                        handle_unclick_config(button_event.x, button_event.y, &state)
                        break event_handle_up
                    }
                }
            } else if event.type == .MOUSEMOTION {
                motion_event := event.button
                event_x := cast(f64) motion_event.x
                event_y := cast(f64) motion_event.y

                if state.current_object_config != nil && event_x > (SCREEN_WIDTH - 5) - (SCREEN_WIDTH / 3) {
                    handle_move_config(motion_event.x, motion_event.y, &state)
                }
            }
        }

        if state.running {
            update_objects(&objects)
        }

        sdl2.SetRenderDrawColor(renderer, 0x10, 0x10, 0x10, 0x00)
        sdl2.RenderClear(renderer)

        sdl2.SetRenderDrawColor(renderer, 0xEE, 0xEE, 0xEE, 0xFF)
        for object in objects {
            render_object(renderer, object)
        }

        if state.current_object_config != nil {
            render_config(renderer, &state)
        }

        sdl2.RenderPresent(renderer)
    }
}
