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
                                        ob.mass += o.mass
                                        ob.velocity /= 4

                                        if o.mass > ob.mass {
                                            ob.x = o.x
                                            ob.y = o.y
                                        }
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

reset_single_dynamic :: proc(objects: ^[dynamic]Object) {
    clear(objects)
    for _ in 0..<10 {
        x := cast(f64) rand.int_max(SCREEN_WIDTH)
        y := cast(f64) rand.int_max(SCREEN_HEIGHT)
        mass := cast(uint) rand.int_max(240) + 120
        append(objects, StaticObject { x, y, mass })
    }

    append(objects, DynamicObject { 0, 0, {2, 0}, 25 })
}

reset_multi_dynamic :: proc(objects: ^[dynamic]Object, count: u64) {
    clear(objects)
    for _ in 0..<count {
        x := cast(f64) rand.int_max(SCREEN_WIDTH)
        y := cast(f64) rand.int_max(SCREEN_HEIGHT)
        x_velocity := rand.float64_range(0, 0.25)
        y_velocity := rand.float64_range(0, 0.25)
        mass := cast(uint) rand.int_max(1024) + 120
        append(objects, DynamicObject { x, y, {x_velocity, y_velocity}, mass })
    }
}

Mode :: enum {
    Standard,
    Place_Dynamic_Random_Mass,
}

main :: proc() {
    sdl2.Init(sdl2.INIT_EVERYTHING)
    window := sdl2.CreateWindow("Window", sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED, SCREEN_WIDTH, SCREEN_HEIGHT, sdl2.WINDOW_SHOWN)
    renderer := sdl2.CreateRenderer(window, -1, sdl2.RENDERER_ACCELERATED | sdl2.RENDERER_PRESENTVSYNC)

    objects: [dynamic]Object
    mode: Mode

    loop: for {
        event: sdl2.Event
        for sdl2.PollEvent(&event) {
            if event.type == .QUIT {
                break loop
            } else if event.type == .KEYDOWN {
                key := event.key
                #partial switch key.keysym.scancode {
                    case .A:
                        reset_single_dynamic(&objects)
                        mode = .Standard
                    case .B:
                        reset_multi_dynamic(&objects, 10)
                        mode = .Standard
                    case .C:
                        reset_multi_dynamic(&objects, 100)
                        mode = .Standard
                    case .D:
                        reset_multi_dynamic(&objects, 0)
                        mode = .Place_Dynamic_Random_Mass
                }
            } else if event.type == .MOUSEBUTTONDOWN {
                #partial switch mode {
                    case .Place_Dynamic_Random_Mass:
                        button_event := event.button
                        mass := cast(uint) rand.int_max(1024) + 120
                        append(&objects, DynamicObject { cast(f64) button_event.x, cast(f64) button_event.y, {0, 0}, mass })
                }
            }
        }

        update_objects(&objects)

        sdl2.SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0x00)
        sdl2.RenderClear(renderer)

        sdl2.SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF)
        for object in objects {
            render_object(renderer, object)
        }

        sdl2.RenderPresent(renderer)
    }
}
