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
    x: uint,
    y: uint,
    mass: uint,
}

DynamicObject :: struct {
    x: f64,
    y: f64,
    velocity: [2]f64,
}

SPEED :: 5

update_object :: proc(object: ^Object, objects: [dynamic]Object) {
    for _ in 0..<SPEED {
        switch &o in object {
            case DynamicObject:
                o.x += o.velocity.x
                o.y += o.velocity.y
                for object in objects {
                    #partial switch ob in object {
                        case StaticObject:
                            other_distance: [2]f64
                            other_distance.x = cast(f64) ob.x - o.x
                            other_distance.y = (cast(f64) ob.y - o.y)

                            other_normalized := linalg.vector_normalize(other_distance)

                            distance := linalg.distance(other_distance, [?]f64{0, 0})
                            effect := 0.01 * (cast(f64) 1 / math.max(distance, 1)) * cast(f64) ob.mass

                            new_velocity: [2]f64
                            new_velocity.x = o.velocity.x * (1 - effect) + other_normalized.x * effect
                            new_velocity.y = o.velocity.y * (1 - effect) + other_normalized.y * effect
                            o.velocity = new_velocity
                    }
                }
            case StaticObject:
        }
    }
}

render_object :: proc(renderer: ^sdl2.Renderer, object: Object) {
    x, y, w, h: uint
    switch o in object {
        case StaticObject:
            size := o.mass
            x = o.x - size / 2
            y = o.y - size / 2
            w = size
            h = size
        case DynamicObject:
            x = cast(uint) (o.x - 2)
            y = cast(uint) (o.y - 2)
            w = 4
            h = 4
    }
    box: sdl2.Rect
    box.x = cast(i32) x
    box.y = cast(i32) y
    box.w = cast(i32) w
    box.h = cast(i32) h
    sdl2.RenderFillRect(renderer, &box)
}

reset :: proc(objects: ^[dynamic]Object) {
    clear(objects)
    for _ in 0..<10 {
        x := cast(uint) rand.int_max(1920)
        y := cast(uint) rand.int_max(1080)
        mass := cast(uint) rand.int_max(20) + 10
        append(objects, StaticObject { x, y, mass })
    }

    append(objects, DynamicObject { 0, 0, {2, 0} })
}

main :: proc() {
    sdl2.Init(sdl2.INIT_EVERYTHING)
    window := sdl2.CreateWindow("Window", sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED, 1920, 1080, sdl2.WINDOW_SHOWN)
    renderer := sdl2.CreateRenderer(window, -1, sdl2.RENDERER_ACCELERATED | sdl2.RENDERER_PRESENTVSYNC)

    objects: [dynamic]Object
    reset(&objects)

    loop: for {
        event: sdl2.Event
        for sdl2.PollEvent(&event) {
            if event.type == .QUIT {
                break loop
            } else if event.type == .KEYDOWN {
                key := event.key
                if key.keysym.scancode == .R {
                    reset(&objects)
                }
            }
        }

        for &object in objects {
            update_object(&object, objects)
        }

        sdl2.SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0x00)
        sdl2.RenderClear(renderer)

        sdl2.SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF)
        for object in objects {
            render_object(renderer, object)
        }

        sdl2.RenderPresent(renderer)
    }
}
