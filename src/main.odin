package game

import rlgrid "./rl_grid"
import "core:fmt"
import "core:math"
import "core:mem"
import rl "vendor:raylib"

// load assets as bytes
image_background_bytes := #load("../assets/frogger_background_modified.png")
image_sprite_sheet_bytes := #load("../assets/frogger_sprite_sheet_modified.png")
font_data_bytes := #load("../assets/joystix monospace.otf")

sprite_sheet_cell_size: f32 = 16

global_cell_size: f32 = 64
global_number_grid_cells_axis_x: f32 = 14
global_number_grid_cells_axis_y: f32 = 16
global_game_view_pixels_width: f32 = global_cell_size * global_number_grid_cells_axis_x
global_game_view_pixels_height: f32 = global_cell_size * global_number_grid_cells_axis_y

Game_Memory :: struct {
	// View
	game_render_target:               rl.RenderTexture2D,

	// Textures
	texture_background:               rl.Texture2D,
	texture_sprite_sheet:             rl.Texture2D,

	// Font
	font:                             rl.Font,

	// Debugging tools
	debug_show_grid:                  bool,

	// Game state
	score:                            int,
	max_frogger_y:                    f32,

	// Frogger position and movement
	frogger_pos:                      [2]f32,
	frogger_lerp_hop_timer:           f32,
	frogger_lerp_hop_start_pos:       [2]f32,
	frogger_lerp_hop_end_pos:         [2]f32,
	frogger_lerp_hop_duration:        f32,


	// Frogger animation
	frogger_animation_timer:          f32,
	frogger_animation_frame_duration: f32,
	frogger_current_animation_frame:  i32,
	frogger_animation_playing:        bool,
	frog_animation_sequence:          [4]i32,
	frogger_facing_direction:         i32,

	// Frogger death
	frogger_death_timer_duration:     f32,
	frogger_death_timer:              f32,

	// Game entities
	floating_logs:                    []rlgrid.Entity,
	vehicles:                         []rlgrid.Entity,
	turtles:                          []rlgrid.Entity,
	pause:                            bool,
}

gmem: ^Game_Memory

// Lillypad areas - 5 spots at the top row between grid cells
lillypad_areas := [5]rl.Rectangle {
	{0.5, 2, 1, 1}, // between positions 1-2
	{3.5, 2, 1, 1}, // between positions 3-4
	{6.5, 2, 1, 1}, // between positions 5-6
	{9.5, 2, 1, 1}, // between positions 7-8
	{12.5, 2, 1, 1}, // between positions 9-10
}

// Animation timing - triggered on hop start
frogger_animation_timer := 0
frogger_animation_frame_duration := 0.1 // 10fps to see each frame clearly
frogger_current_animation_frame := 0
frogger_animation_playing := false

// Animation sequence: 3,2,1,2,3 (5 frames total)
frog_animation_sequence := [4]i32{3, 2, 1, 3}

// Frog facing direction (0=up, 1=right, 2=down, 3=left)
frogger_facing_direction := 0

frogger_death_timer_duration := 1
frogger_death_timer := frogger_death_timer_duration

frogger_death_sprite_clip := rl.Rectangle{0, 3, 1, 1}

// Frog sprite clips (first 3 sprites on top row)
frog_sprite_1 := rl.Rectangle{0, 0, 1, 1} // First sprite
frog_sprite_2 := rl.Rectangle{1, 0, 1, 1} // Second sprite  
frog_sprite_3 := rl.Rectangle{2, 0, 1, 1} // Third sprite - idle/default

// Log sprites (converting to 0-indexed)
log_sprite_row3 := rl.Rectangle{3, 2, 6, 1} // 6-wide log starting at cell 3, ending at cell 8, row 2 (0-indexed row 1)
log_sprite_row2 := rl.Rectangle{4, 3, 4, 1} // 4-wide log starting at cell 3, row 2 (was row 3, cell 4)
log_sprite_row9 := rl.Rectangle{6, 8, 3, 1} // 3-wide log starting at cell 6, row 8 (was row 9, cell 7)

// Turtle sprites (row 5, 0-indexed, first 3 cells)
turtle_sprite_1 := rl.Rectangle{0, 5, 1, 1} // First turtle sprite
turtle_sprite_2 := rl.Rectangle{1, 5, 1, 1} // Second turtle sprite
turtle_sprite_3 := rl.Rectangle{2, 5, 1, 1} // Third turtle sprite

floating_logs := [?]rlgrid.Entity {
	{rectangle = {0, 3, 6, 1}, speed = 2, color = rl.BROWN, sprite = log_sprite_row3},
	{rectangle = {7, 3, 6, 1}, speed = 2, color = rl.BROWN, sprite = log_sprite_row3},
	{rectangle = {13, 3, 6, 1}, speed = 2, color = rl.BROWN, sprite = log_sprite_row3},
	{rectangle = {0, 5, 4, 1}, speed = 3, color = rl.BROWN, sprite = log_sprite_row2},
	{rectangle = {4, 5, 4, 1}, speed = 3, color = rl.BROWN, sprite = log_sprite_row2},
	{rectangle = {9, 5, 4, 1}, speed = 3, color = rl.BROWN, sprite = log_sprite_row2},
	{rectangle = {0, 6, 3, 1}, speed = 1, color = rl.BROWN, sprite = log_sprite_row9},
	{rectangle = {3, 6, 3, 1}, speed = 1, color = rl.BROWN, sprite = log_sprite_row9},
	{rectangle = {7, 6, 3, 1}, speed = 1, color = rl.BROWN, sprite = log_sprite_row9},
	{rectangle = {11, 6, 3, 1}, speed = 1, color = rl.BROWN, sprite = log_sprite_row9},
}

// Placeholder sprites for vehicles and turtles (will fix later)
placeholder_sprite := rl.Rectangle{0, 0, 1, 1}

vehicles := [8]rlgrid.Entity {
	{{0, 13, 1, 1}, -1.5, rl.YELLOW, placeholder_sprite},
	{{3, 13, 1, 1}, -1.5, rl.YELLOW, placeholder_sprite},
	{{6, 13, 1, 1}, 2, rl.YELLOW, placeholder_sprite},
	{{10, 13, 1, 1}, 2, rl.YELLOW, placeholder_sprite},
	{{0, 12, 1, 1}, 2.0, rl.WHITE, placeholder_sprite},
	{{3, 12, 1, 1}, 2.0, rl.WHITE, placeholder_sprite},
	{{6, 12, 1, 1}, 2.0, rl.WHITE, placeholder_sprite},
	{{10, 12, 1, 1}, 2.0, rl.WHITE, placeholder_sprite},
}

river_rectangle := rl.Rectangle{0, 0, 14, 8}


// Bog area - rows 1 and 2, excluding lillypad areas
bog_rectangle := rl.Rectangle{0, 1, 14, 2}

frogger_reached_lillypads := [5]bool{}

turtles := [7]rlgrid.Entity {
	{
		rectangle = {2, 4, 2, 1},
		speed     = -1.5,
		color     = rl.DARKGREEN,
		sprite    = rl.Rectangle{0, 5, 2, 1}, // 2-wide turtle
	},
	{
		rectangle = {6, 4, 2, 1},
		speed     = -1.5,
		color     = rl.DARKGREEN,
		sprite    = rl.Rectangle{0, 5, 2, 1}, // 2-wide turtle
	},
	{
		rectangle = {10, 4, 2, 1},
		speed     = -1.5,
		color     = rl.DARKGREEN,
		sprite    = rl.Rectangle{0, 5, 2, 1}, // 2-wide turtle
	},
	{
		rectangle = {14, 4, 2, 1},
		speed     = -1.5,
		color     = rl.DARKGREEN,
		sprite    = rl.Rectangle{0, 5, 2, 1}, // 2-wide turtle
	},
	{
		rectangle = {1, 7, 3, 1},
		speed = 1.8,
		color = rl.DARKGREEN,
		sprite = rl.Rectangle{0, 5, 3, 1},
	}, // 3-wide turtle
	{
		rectangle = {6, 7, 3, 1},
		speed = 1.8,
		color = rl.DARKGREEN,
		sprite = rl.Rectangle{0, 5, 3, 1},
	}, // 3-wide turtle
	{
		rectangle = {11, 7, 3, 1},
		speed     = 1.8,
		color     = rl.DARKGREEN,
		sprite    = rl.Rectangle{0, 5, 3, 1}, // 3-wide turtle
	},
}

// NOTE: come up with examples of passing lists of things to functions

move_entities :: proc(entities: []rlgrid.Entity, max_x: f32) {
	for &entity in entities {
		entity.rectangle.x += entity.speed * rl.GetFrameTime()

		should_warp_to_left_side := entity.rectangle.x > max_x + 3 && entity.speed > 0
		if should_warp_to_left_side {
			entity.rectangle.x = -entity.rectangle.width
		}

		should_warp_to_right_side :=
			entity.rectangle.x < -entity.rectangle.width && entity.speed < 0
		if should_warp_to_right_side {
			entity.rectangle.x = max_x + entity.rectangle.width
		}
	}
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(gmem)
}

@(export)
game_memory_ptr :: proc() -> rawptr {
	return gmem
}

@(export)
game_hot_reload :: proc(mem: rawptr) {
	gmem = (^Game_Memory)(mem)
}

@(export)
game_is_build_requested :: proc() -> bool {
	return rl.IsKeyPressed(.F5)

}

@(export)
game_should_run :: proc() -> bool {
	shouldWindowClose := rl.WindowShouldClose()
	return shouldWindowClose ? false : true
}

@(export)
game_free_memory :: proc() {
	free(gmem)
	rl.UnloadRenderTexture(gmem.game_render_target)
}

@(export)
game_init_platform :: proc() {
	initial_window_width := 640
	initial_window_height := 640
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(
		i32(initial_window_width),
		i32(initial_window_height),
		"Frogger [For Educational Purposes Only]",
	)
	rl.InitAudioDevice()
	rl.SetTargetFPS(60)
}

@(export)
game_reset_entities :: proc() {
	gmem.floating_logs = floating_logs[:]

	gmem.turtles = turtles[:]
	// gmem.diving_turtles = diving_turtles[:]

	gmem.vehicles = vehicles[:]
}

frogger_lerp_hop_duration: f32 = 0.1

@(export)
game_init :: proc() {
	gmem = new(Game_Memory)
	gmem.game_render_target = rl.LoadRenderTexture(
		i32(global_game_view_pixels_width),
		i32(global_game_view_pixels_height),
	)
	rl.SetTextureFilter(gmem.game_render_target.texture, rl.TextureFilter.BILINEAR)
	// Load font
	gmem.font = rl.LoadFontFromMemory(
		".otf",
		&font_data_bytes[0],
		i32(len(font_data_bytes)),
		256,
		nil,
		0,
	)
	gmem.max_frogger_y = f32(global_number_grid_cells_axis_y) - 2
	gmem.debug_show_grid = false
	// Load sounds
	// wave_squish := rl.LoadWaveFromMemory(".wav", &sfx_squish_bytes[0], i32(len(sfx_squish_bytes)))
	// sfx_squish := rl.LoadSoundFromWave(wave_squish)
	image_background := rl.LoadImageFromMemory(
		".png",
		&image_background_bytes[0],
		i32(len(image_background_bytes)),
	)
	image_sprite_sheet := rl.LoadImageFromMemory(
		".png",
		&image_sprite_sheet_bytes[0],
		i32(len(image_sprite_sheet_bytes)),
	)
	gmem.texture_background = rl.LoadTextureFromImage(image_background)
	gmem.texture_sprite_sheet = rl.LoadTextureFromImage(image_sprite_sheet)
	gmem.frogger_pos = [2]f32{7, 14}
	frogger_lerp_hop_start_pos: [2]f32
	frogger_lerp_hop_end_pos: [2]f32
	gmem.frogger_lerp_hop_start_pos = frogger_lerp_hop_start_pos
	gmem.frogger_lerp_hop_end_pos = frogger_lerp_hop_end_pos
	gmem.frogger_lerp_hop_timer = 0
	game_reset_frogger()
	game_reset_entities()
}

game_reset_frogger :: proc() {
	gmem.frogger_pos = [2]f32{7, 14}
}

@(export)
game_update :: proc() {
	if rl.IsKeyPressed(.ENTER) {
		gmem.pause = !gmem.pause
	}

	if rl.IsKeyPressed(.BACKSPACE) {
		gmem.pause = !gmem.pause

	}

	// gameplay
	can_frogger_request_to_hop := gmem.frogger_lerp_hop_timer <= 0
	if can_frogger_request_to_hop {
		move_direction := [2]f32{}

		if rl.IsKeyPressed(.UP) {
			move_direction.y = -1
		}
		if rl.IsKeyPressed(.DOWN) {
			move_direction.y = 1
		}
		if rl.IsKeyPressed(.LEFT) {
			move_direction.x = -1
		}
		if rl.IsKeyPressed(.RIGHT) {
			move_direction.x = 1
		}

		did_frogger_request_to_hop := move_direction != [2]f32{0, 0}

		if did_frogger_request_to_hop {
			number_of_tiles_for_score_data: f32 = 1
			number_of_tiles_for_lives_and_time_data: f32 = 2

			frogger_next_pos := gmem.frogger_pos + move_direction

			is_frogger_next_position_out_of_bounds :=
				frogger_next_pos.x < 0 ||
				frogger_next_pos.x > f32(global_number_grid_cells_axis_x) - 1 ||
				frogger_next_pos.y < number_of_tiles_for_score_data ||
				frogger_next_pos.y >
					f32(global_number_grid_cells_axis_y) - number_of_tiles_for_lives_and_time_data

			if !is_frogger_next_position_out_of_bounds {
				// Update facing direction based on movement
				if move_direction.y < 0 {
					frogger_facing_direction = 0 // Up
				} else if move_direction.x > 0 {
					frogger_facing_direction = 1 // Right
				} else if move_direction.y > 0 {
					frogger_facing_direction = 2 // Down
				} else if move_direction.x < 0 {
					frogger_facing_direction = 3 // Left
				}

				gmem.frogger_lerp_hop_timer = frogger_lerp_hop_duration
				gmem.frogger_lerp_hop_start_pos = gmem.frogger_pos
				gmem.frogger_lerp_hop_end_pos = frogger_next_pos

				// Start hop animation
				frogger_animation_playing = true
				frogger_animation_timer = 0
				frogger_current_animation_frame = 0
			}
		}
	} else {
		gmem.frogger_lerp_hop_timer -= rl.GetFrameTime()
		if gmem.frogger_lerp_hop_timer < 0 {
			gmem.frogger_lerp_hop_timer = 0
		}
		amount := (1.0) - gmem.frogger_lerp_hop_timer / frogger_lerp_hop_duration
		gmem.frogger_pos.y =
			(1.0 - amount) * gmem.frogger_lerp_hop_start_pos.y +
			(amount * gmem.frogger_lerp_hop_end_pos.y)
		gmem.frogger_pos.x =
			(1.0 - amount) * gmem.frogger_lerp_hop_start_pos.x +
			(amount * gmem.frogger_lerp_hop_end_pos.x)
	}

	if (gmem.max_frogger_y == gmem.frogger_pos.y + 1) {
		gmem.score += 10
		gmem.max_frogger_y = gmem.frogger_pos.y
	}

	move_entities(vehicles[:], f32(global_number_grid_cells_axis_x))
	move_entities(floating_logs[:], f32(global_number_grid_cells_axis_x))
	move_entities(turtles[:], f32(global_number_grid_cells_axis_x))

	// Update hop animation
	if frogger_animation_playing {
		gmem.frogger_animation_timer += rl.GetFrameTime()
		if gmem.frogger_animation_timer >= gmem.frogger_animation_frame_duration {
			frogger_animation_timer = 0
			frogger_current_animation_frame += 1

			// Animation complete after all 5 frames (3,2,1,2,3)
			if frogger_current_animation_frame >= 4 {
				frogger_animation_playing = false
				frogger_current_animation_frame = 0
			}
		}
	}

	// when the frog is on log, the frog moves with log

	// logs = rectangle
	// logs_speed
	// frogger = pos

	// if the left corner is same as left corner as log rectangle

	// move frogger
	is_frogger_floating := false
	frogger_center_pos := gmem.frogger_pos + 0.5
	for log in floating_logs {
		log_rectangle := log.rectangle
		is_frog_on_log := rl.CheckCollisionPointRec(frogger_center_pos, log_rectangle)
		if is_frog_on_log {
			is_frogger_floating = true
			log_speed := log.speed
			move_amount := log_speed * rl.GetFrameTime()
			gmem.frogger_pos.x += move_amount
			gmem.frogger_lerp_hop_end_pos.x += move_amount
		}
	}

	for turtle in turtles {
		turtle_rectangle := turtle.rectangle
		is_frog_on_turtle := rl.CheckCollisionPointRec(frogger_center_pos, turtle_rectangle)
		if is_frog_on_turtle {
			is_frogger_floating = true
			turtle_speed := turtle.speed
			move_amount := turtle_speed * rl.GetFrameTime()
			gmem.frogger_pos.x += move_amount
			gmem.frogger_lerp_hop_end_pos.x += move_amount
		}
	}

	// Check if frog goes out of bounds while floating (riding logs/turtles)
	if is_frogger_floating {
		frogger_out_of_bounds_left := gmem.frogger_pos.x < -1
		frogger_out_of_bounds_right := gmem.frogger_pos.x > f32(global_number_grid_cells_axis_x)

		if frogger_out_of_bounds_left || frogger_out_of_bounds_right {
			gmem.frogger_pos = [2]f32{7, 14}
			frogger_lerp_hop_start_pos: [2]f32
			frogger_lerp_hop_end_pos: [2]f32
			gmem.frogger_lerp_hop_start_pos = frogger_lerp_hop_start_pos
			gmem.frogger_lerp_hop_end_pos = frogger_lerp_hop_end_pos
			gmem.frogger_lerp_hop_timer = 0
		}
	}

	should_check_if_frogger_drowns_in_river := !is_frogger_floating
	if should_check_if_frogger_drowns_in_river {
		frogger_center_pos := gmem.frogger_pos + 0.5
		is_fogger_in_river := rl.CheckCollisionPointRec(frogger_center_pos, river_rectangle)

		// Don't drown if frogger is on a lillypad area
		is_on_lillypad := false
		for lillypad_area in lillypad_areas {
			if rl.CheckCollisionPointRec(frogger_center_pos, lillypad_area) {
				is_on_lillypad = true
				break
			}
		}

		if is_fogger_in_river && !is_on_lillypad {
			reset_frogger()
		}
	}

	reset_frogger :: proc() {
		gmem.frogger_pos = {7, 14}
		gmem.max_frogger_y = f32(global_number_grid_cells_axis_y)
	}

	for vehicle in vehicles {
		is_frogger_hit := rl.CheckCollisionPointRec(
			rlgrid.get_cell_center_pos(gmem.frogger_pos),
			vehicle.rectangle,
		)
		if is_frogger_hit {
			// rl.PlaySound(sfx_squish)
			reset_frogger()

		}
	}

	// Check if frogger reached any lillypad areas
	for lillypad_area, i in lillypad_areas {
		frogger_center := rlgrid.get_cell_center_pos(gmem.frogger_pos)
		is_frogger_on_lillypad := rl.CheckCollisionPointRec(frogger_center, lillypad_area)

		if is_frogger_on_lillypad {
			frogger_reached_lillypads[i] = true
			// Reset frogger position after reaching lillypad
			reset_frogger()

		}
	}

	// Check if frogger collided with bog areas (excluding lillypads)
	frogger_center := rlgrid.get_cell_center_pos(gmem.frogger_pos)
	is_frogger_in_bog := rl.CheckCollisionPointRec(frogger_center, bog_rectangle)

	if is_frogger_in_bog {
		// Check if frogger is NOT on a lillypad area
		is_on_lillypad := false
		for lillypad_area in lillypad_areas {
			if rl.CheckCollisionPointRec(frogger_center, lillypad_area) {
				is_on_lillypad = true
				break
			}
		}

		// If in bog but not on lillypad, frogger dies
		if !is_on_lillypad {
			reset_frogger()
		}
	}

	// debug options
	if rl.IsKeyPressed(.F1) {
		gmem.debug_show_grid = !gmem.debug_show_grid
	}


	// rendering

	game_screen_width := global_cell_size * global_number_grid_cells_axis_x
	game_screen_height := global_cell_size * global_number_grid_cells_axis_y
	screen_width := f32(rl.GetScreenWidth())
	screen_height := f32(rl.GetScreenHeight())

	scale := min(screen_width / f32(game_screen_width), screen_height / f32(game_screen_height))

	{ 	// DRAW TO RENDER TEXTURE
		rl.BeginTextureMode(gmem.game_render_target)
		defer rl.EndTextureMode()

		rl.ClearBackground(rl.LIGHTGRAY)

		background_src_rectangle := rl.Rectangle {
			0,
			0,
			f32(gmem.texture_background.width),
			f32(gmem.texture_background.height),
		}
		background_texture_scale_x := f32(game_screen_width) / f32(gmem.texture_background.width)
		background_texture_scale_y := f32(game_screen_height) / f32(gmem.texture_background.height)

		background_render_rectangle := rl.Rectangle {
			0,
			0,
			f32(gmem.texture_background.width) * background_texture_scale_x,
			f32(gmem.texture_background.height) * background_texture_scale_y,
		}
		rl.DrawTexturePro(
			gmem.texture_background,
			background_src_rectangle,
			background_render_rectangle,
			[2]f32{},
			0,
			rl.WHITE,
		)

		rlgrid.draw_entities_with_sprites(
			gmem.floating_logs[:],
			gmem.texture_sprite_sheet,
			sprite_sheet_cell_size,
			global_cell_size,
		)

		for log in floating_logs {
			rlgrid.draw_rectangle_on_grid(log.rectangle, rl.PURPLE, global_cell_size)
		}

		rlgrid.draw_entities_with_sprites(
			gmem.turtles[:],
			gmem.texture_sprite_sheet,
			sprite_sheet_cell_size,
			global_cell_size,
		)
		rlgrid.draw_entities_with_padding(gmem.vehicles[:], global_cell_size, 0, 0.1)


		// Draw lillypad areas that have been reached as bright green rectangles
		for lillypad_area, i in lillypad_areas {
			if frogger_reached_lillypads[i] {
				rlgrid.draw_rectangle_on_grid(
					lillypad_area,
					rl.Color{50, 255, 50, 255},
					global_cell_size,
				)
			}
		}

		// Determine which frog sprite to use based on animation frame
		current_frog_sprite := frog_sprite_3 // Default idle sprite
		if frogger_animation_playing {
			// During hop animation, use the sequence: 3,2,1,2,3
			sprite_number := frog_animation_sequence[frogger_current_animation_frame]
			switch sprite_number {
			case 1:
				current_frog_sprite = frog_sprite_1
			case 2:
				current_frog_sprite = frog_sprite_2
			case 3:
				current_frog_sprite = frog_sprite_3
			}
		}

		// Calculate rotation based on facing direction
		rotation_angle: f32 = 0
		switch frogger_facing_direction {
		case 0:
			// Up
			rotation_angle = 0
		case 1:
			// Right
			rotation_angle = 90
		case 2:
			// Down
			rotation_angle = 180
		case 3:
			// Left
			rotation_angle = 270
		}

		// Draw frog sprite with rotation
		rlgrid.draw_sprite_on_grid(
			gmem.frogger_pos,
			current_frog_sprite,
			gmem.texture_sprite_sheet,
			sprite_sheet_cell_size,
			global_cell_size,
			rotation_angle,
		)

		if gmem.debug_show_grid {
			// draw grid

			for x: i32 = 0; x < i32(global_number_grid_cells_axis_x); x += 1 {
				render_x := f32(x) * global_cell_size
				render_start_y: f32 = 0
				render_end_y := f32(game_screen_height)
				rl.DrawLineV(
					[2]f32{render_x, render_start_y},
					[2]f32{render_x, render_end_y},
					rl.WHITE,
				)
			}

			for y: i32 = 0; y < i32(global_number_grid_cells_axis_y); y += 1 {
				render_y := f32(y) * global_cell_size
				render_start_x: f32 = 0
				render_end_x := f32(game_screen_width)
				rl.DrawLineV(
					[2]f32{render_start_x, render_y},
					[2]f32{render_end_x, render_y},
					rl.WHITE,
				)
			}

		}
		rlgrid.draw_text_on_grid_centered(
			fmt.ctprintf("Score: %d", gmem.score),
			[2]f32{7, 0},
			1,
			0,
			rl.WHITE,
			gmem.font,
			global_cell_size,
		)
	}

	{ 	// DRAW TO WINDOW
		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.BLACK)

		src := rl.Rectangle {
			0,
			0,
			f32(gmem.game_render_target.texture.width),
			f32(-gmem.game_render_target.texture.height),
		}

		window_midpoint_x := screen_width - (f32(game_screen_width) * scale) / 2
		window_midpoint_y := screen_height - (f32(game_screen_height) * scale) / 2
		window_scaled_width := f32(game_screen_width) * scale
		window_scaled_height := f32(game_screen_height) * scale

		dst := rl.Rectangle {
			(screen_width - window_scaled_width) / 2,
			(screen_height - window_scaled_height) / 2,
			window_scaled_width,
			window_scaled_height,
		}

		rl.DrawTexturePro(gmem.game_render_target.texture, src, dst, [2]f32{0, 0}, 0, rl.WHITE)

	}
	free_all(context.temp_allocator)
}
