package main

import "core:fmt"
import rl "vendor:raylib"

// load assets as bytes
image_background_bytes := #load("../assets/frogger_background_modified.png")
image_sprite_sheet_bytes := #load("../assets/frogger_sprite_sheet_modified.png")
font_data_bytes := #load("../assets/joystix monospace.otf")

Game :: struct {
	// Window and grid settings
	initial_window_width:             int,
	initial_window_height:            int,
	cell_size:                        i32,
	number_of_grid_cells_on_axis_x:   i32,
	number_of_grid_cells_on_axis_y:   i32,
	game_screen_width:                i32,
	game_screen_height:               i32,

	// Game state
	score:                            int,
	max_frogger_y:                    f32,
	debug_show_grid:                  bool,

	// Frogger position and movement
	frogger_start_pos:                [2]f32,
	frogger_pos:                      [2]f32,
	frogger_lerp_hop_duration:        f32,
	frogger_lerp_hop_timer:           f32,
	frogger_lerp_hop_start_pos:       [2]f32,
	frogger_lerp_hop_end_pos:         [2]f32,

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

	// Sprite sheet
	sprite_sheet_cell_size:           f32,

	// Frog sprites
	frog_sprite_1:                    rl.Rectangle,
	frog_sprite_2:                    rl.Rectangle,
	frog_sprite_3:                    rl.Rectangle,
	frogger_death_sprite_clip:        rl.Rectangle,

	// Log sprites
	log_sprite_row3:                  rl.Rectangle,
	log_sprite_row2:                  rl.Rectangle,
	log_sprite_row9:                  rl.Rectangle,

	// Turtle sprites
	turtle_sprite_1:                  rl.Rectangle,
	turtle_sprite_2:                  rl.Rectangle,
	turtle_sprite_3:                  rl.Rectangle,

	// Placeholder sprite
	placeholder_sprite:               rl.Rectangle,

	// Game entities
	floating_logs:                    [10]Entity,
	vehicles:                         [8]Entity,
	turtles:                          [7]Entity,

	// Game areas
	river_rectangle:                  rl.Rectangle,
	lillypad_areas:                   [5]rl.Rectangle,
	bog_rectangle:                    rl.Rectangle,
	frogger_reached_lillypads:        [5]bool,

	// Textures
	texture_background:               rl.Texture2D,
	texture_sprite_sheet:             rl.Texture2D,
	game_render_target:               rl.RenderTexture2D,

	// Font
	font:                             rl.Font,
}

game: Game

main :: proc() {
	// Initialize game struct
	game.cell_size = 64
	game.number_of_grid_cells_on_axis_x = 14
	game.number_of_grid_cells_on_axis_y = 16
	game.initial_window_width = 640
	game.initial_window_height = 640
	game.score = 0
	game.max_frogger_y = f32(game.number_of_grid_cells_on_axis_y) - 2

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(
		i32(game.initial_window_width),
		i32(game.initial_window_height),
		"Frogger [For Educational Purposes Only]",
	)
	rl.InitAudioDevice()
	rl.SetTargetFPS(60)

	// Load font
	game.font = rl.LoadFontFromMemory(
		".otf",
		&font_data_bytes[0],
		i32(len(font_data_bytes)),
		256,
		nil,
		0,
	)

	// wave_squish := rl.LoadWaveFromMemory(".wav", &sfx_squish_bytes[0], i32(len(sfx_squish_bytes)))
	// sfx_squish := rl.LoadSoundFromWave(wave_squish)

	image_background := rl.LoadImageFromMemory(
		".png",
		&image_background_bytes[0],
		i32(len(image_background_bytes)),
	)
	game.texture_background = rl.LoadTextureFromImage(image_background)

	image_sprite_sheet := rl.LoadImageFromMemory(
		".png",
		&image_sprite_sheet_bytes[0],
		i32(len(image_sprite_sheet_bytes)),
	)
	game.texture_sprite_sheet = rl.LoadTextureFromImage(image_sprite_sheet)


	game.game_screen_width = game.cell_size * game.number_of_grid_cells_on_axis_x
	game.game_screen_height = game.cell_size * game.number_of_grid_cells_on_axis_y

	game.game_render_target = rl.LoadRenderTexture(game.game_screen_width, game.game_screen_height)
	rl.SetTextureFilter(game.game_render_target.texture, rl.TextureFilter.BILINEAR)


	game.debug_show_grid = false

	game.frogger_start_pos = [2]f32{6, 14}
	game.frogger_pos = game.frogger_start_pos

	game.frogger_lerp_hop_duration = 0.1
	game.frogger_lerp_hop_timer = 0
	game.frogger_lerp_hop_start_pos = {}
	game.frogger_lerp_hop_end_pos = {}

	// Animation timing - triggered on hop start
	game.frogger_animation_timer = 0
	game.frogger_animation_frame_duration = 0.1 // 10fps to see each frame clearly
	game.frogger_current_animation_frame = 0
	game.frogger_animation_playing = false

	// Animation sequence: 3,2,1,2,3 (5 frames total)
	game.frog_animation_sequence = [4]i32{3, 2, 1, 3}

	// Frog facing direction (0=up, 1=right, 2=down, 3=left)
	game.frogger_facing_direction = 0

	game.frogger_death_timer_duration = 1
	game.frogger_death_timer = game.frogger_death_timer_duration

	game.frogger_death_sprite_clip = rl.Rectangle{0, 3, 1, 1}

	game.sprite_sheet_cell_size = 16

	// Frog sprite clips (first 3 sprites on top row)
	game.frog_sprite_1 = rl.Rectangle{0, 0, 1, 1} // First sprite
	game.frog_sprite_2 = rl.Rectangle{1, 0, 1, 1} // Second sprite  
	game.frog_sprite_3 = rl.Rectangle{2, 0, 1, 1} // Third sprite - idle/default

	// Log sprites (converting to 0-indexed)
	game.log_sprite_row3 = rl.Rectangle{3, 2, 6, 1} // 6-wide log starting at cell 3, ending at cell 8, row 2 (0-indexed row 1)
	game.log_sprite_row2 = rl.Rectangle{4, 3, 4, 1} // 4-wide log starting at cell 3, row 2 (was row 3, cell 4)
	game.log_sprite_row9 = rl.Rectangle{6, 8, 3, 1} // 3-wide log starting at cell 6, row 8 (was row 9, cell 7)

	// Turtle sprites (row 5, 0-indexed, first 3 cells)
	game.turtle_sprite_1 = rl.Rectangle{0, 5, 1, 1} // First turtle sprite
	game.turtle_sprite_2 = rl.Rectangle{1, 5, 1, 1} // Second turtle sprite
	game.turtle_sprite_3 = rl.Rectangle{2, 5, 1, 1} // Third turtle sprite

	game.floating_logs = [10]Entity {
		{rectangle = {0, 3, 6, 1}, speed = 2, color = rl.BROWN, sprite = game.log_sprite_row3},
		{rectangle = {7, 3, 6, 1}, speed = 2, color = rl.BROWN, sprite = game.log_sprite_row3},
		{rectangle = {13, 3, 6, 1}, speed = 2, color = rl.BROWN, sprite = game.log_sprite_row3},
		{rectangle = {0, 5, 4, 1}, speed = 3, color = rl.BROWN, sprite = game.log_sprite_row2},
		{rectangle = {4, 5, 4, 1}, speed = 3, color = rl.BROWN, sprite = game.log_sprite_row2},
		{rectangle = {9, 5, 4, 1}, speed = 3, color = rl.BROWN, sprite = game.log_sprite_row2},
		{rectangle = {0, 6, 3, 1}, speed = 1, color = rl.BROWN, sprite = game.log_sprite_row9},
		{rectangle = {3, 6, 3, 1}, speed = 1, color = rl.BROWN, sprite = game.log_sprite_row9},
		{rectangle = {7, 6, 3, 1}, speed = 1, color = rl.BROWN, sprite = game.log_sprite_row9},
		{rectangle = {11, 6, 3, 1}, speed = 1, color = rl.BROWN, sprite = game.log_sprite_row9},
	}

	// Placeholder sprites for vehicles and turtles (will fix later)
	game.placeholder_sprite = rl.Rectangle{0, 0, 1, 1}

	game.vehicles = [8]Entity {
		{{0, 13, 1, 1}, -1.5, rl.YELLOW, game.placeholder_sprite},
		{{3, 13, 1, 1}, -1.5, rl.YELLOW, game.placeholder_sprite},
		{{6, 13, 1, 1}, -1.5, rl.YELLOW, game.placeholder_sprite},
		{{10, 13, 1, 1}, -1.5, rl.YELLOW, game.placeholder_sprite},
		{{0, 12, 1, 1}, 2.0, rl.WHITE, game.placeholder_sprite},
		{{3, 12, 1, 1}, 2.0, rl.WHITE, game.placeholder_sprite},
		{{6, 12, 1, 1}, 2.0, rl.WHITE, game.placeholder_sprite},
		{{10, 12, 1, 1}, 2.0, rl.WHITE, game.placeholder_sprite},
	}

	game.river_rectangle = rl.Rectangle{0, 0, 14, 8}

	// Lillypad areas - 5 spots at the top row between grid cells
	game.lillypad_areas = [5]rl.Rectangle {
		{0.5, 2, 1, 1}, // between positions 1-2
		{3.5, 2, 1, 1}, // between positions 3-4
		{6.5, 2, 1, 1}, // between positions 5-6
		{9.5, 2, 1, 1}, // between positions 7-8
		{12.5, 2, 1, 1}, // between positions 9-10
	}

	// Bog area - rows 1 and 2, excluding lillypad areas
	game.bog_rectangle = rl.Rectangle{0, 1, 14, 2}

	game.frogger_reached_lillypads = [5]bool{}

	game.turtles = [7]Entity {
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

	for !rl.WindowShouldClose() {
		// gameplay
		can_frogger_request_to_hop := game.frogger_lerp_hop_timer <= 0
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

				frogger_next_pos := game.frogger_pos + move_direction

				is_frogger_next_position_out_of_bounds :=
					frogger_next_pos.x < 0 ||
					frogger_next_pos.x > f32(game.number_of_grid_cells_on_axis_x) - 1 ||
					frogger_next_pos.y < number_of_tiles_for_score_data ||
					frogger_next_pos.y >
						f32(game.number_of_grid_cells_on_axis_y) -
							number_of_tiles_for_lives_and_time_data

				if !is_frogger_next_position_out_of_bounds {
					// Update facing direction based on movement
					if move_direction.y < 0 {
						game.frogger_facing_direction = 0 // Up
					} else if move_direction.x > 0 {
						game.frogger_facing_direction = 1 // Right
					} else if move_direction.y > 0 {
						game.frogger_facing_direction = 2 // Down
					} else if move_direction.x < 0 {
						game.frogger_facing_direction = 3 // Left
					}

					game.frogger_lerp_hop_timer = game.frogger_lerp_hop_duration
					game.frogger_lerp_hop_start_pos = game.frogger_pos
					game.frogger_lerp_hop_end_pos = frogger_next_pos

					// Start hop animation
					game.frogger_animation_playing = true
					game.frogger_animation_timer = 0
					game.frogger_current_animation_frame = 0
				}
			}
		} else {
			game.frogger_lerp_hop_timer -= rl.GetFrameTime()
			if game.frogger_lerp_hop_timer < 0 {
				game.frogger_lerp_hop_timer = 0
			}
			amount := (1.0) - game.frogger_lerp_hop_timer / game.frogger_lerp_hop_duration
			game.frogger_pos.y =
				(1.0 - amount) * game.frogger_lerp_hop_start_pos.y +
				(amount * game.frogger_lerp_hop_end_pos.y)
			game.frogger_pos.x =
				(1.0 - amount) * game.frogger_lerp_hop_start_pos.x +
				(amount * game.frogger_lerp_hop_end_pos.x)
		}

		if (game.max_frogger_y == game.frogger_pos.y + 1) {
			game.score += 10
			game.max_frogger_y = game.frogger_pos.y
		}

		move_entities(game.vehicles[:], f32(game.number_of_grid_cells_on_axis_x))
		move_entities(game.floating_logs[:], f32(game.number_of_grid_cells_on_axis_x))
		move_entities(game.turtles[:], f32(game.number_of_grid_cells_on_axis_x))

		// Update hop animation
		if game.frogger_animation_playing {
			game.frogger_animation_timer += rl.GetFrameTime()
			if game.frogger_animation_timer >= game.frogger_animation_frame_duration {
				game.frogger_animation_timer = 0
				game.frogger_current_animation_frame += 1

				// Animation complete after all 5 frames (3,2,1,2,3)
				if game.frogger_current_animation_frame >= 4 {
					game.frogger_animation_playing = false
					game.frogger_current_animation_frame = 0
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
		frogger_center_pos := game.frogger_pos + 0.5
		for log in game.floating_logs {
			log_rectangle := log.rectangle
			is_frog_on_log := rl.CheckCollisionPointRec(frogger_center_pos, log_rectangle)
			if is_frog_on_log {
				is_frogger_floating = true
				log_speed := log.speed
				move_amount := log_speed * rl.GetFrameTime()
				game.frogger_pos.x += move_amount
				game.frogger_lerp_hop_end_pos.x += move_amount
			}
		}

		for turtle in game.turtles {
			turtle_rectangle := turtle.rectangle
			is_frog_on_turtle := rl.CheckCollisionPointRec(frogger_center_pos, turtle_rectangle)
			if is_frog_on_turtle {
				is_frogger_floating = true
				turtle_speed := turtle.speed
				move_amount := turtle_speed * rl.GetFrameTime()
				game.frogger_pos.x += move_amount
				game.frogger_lerp_hop_end_pos.x += move_amount
			}
		}

		// Check if frog goes out of bounds while floating (riding logs/turtles)
		if is_frogger_floating {
			frogger_out_of_bounds_left := game.frogger_pos.x < -1
			frogger_out_of_bounds_right :=
				game.frogger_pos.x > f32(game.number_of_grid_cells_on_axis_x)

			if frogger_out_of_bounds_left || frogger_out_of_bounds_right {
				game.frogger_pos = game.frogger_start_pos
				game.frogger_lerp_hop_start_pos = game.frogger_start_pos
				game.frogger_lerp_hop_end_pos = game.frogger_start_pos
				game.frogger_lerp_hop_timer = 0
			}
		}

		should_check_if_frogger_drowns_in_river := !is_frogger_floating
		if should_check_if_frogger_drowns_in_river {
			frogger_center_pos := game.frogger_pos + 0.5
			is_fogger_in_river := rl.CheckCollisionPointRec(
				frogger_center_pos,
				game.river_rectangle,
			)

			// Don't drown if frogger is on a lillypad area
			is_on_lillypad := false
			for lillypad_area in game.lillypad_areas {
				if rl.CheckCollisionPointRec(frogger_center_pos, lillypad_area) {
					is_on_lillypad = true
					break
				}
			}

			if is_fogger_in_river && !is_on_lillypad {
				game.frogger_pos = game.frogger_start_pos
				game.max_frogger_y = f32(game.number_of_grid_cells_on_axis_y)
			}
		}

		reset_frogger :: proc() {
			game.frogger_pos = game.frogger_start_pos
			game.max_frogger_y = f32(game.number_of_grid_cells_on_axis_y)
		}

		for vehicle in game.vehicles {
			is_frogger_hit := rl.CheckCollisionPointRec(
				get_cell_center_pos(game.frogger_pos),
				vehicle.rectangle,
			)
			if is_frogger_hit {
				// rl.PlaySound(sfx_squish)
				game.frogger_pos = game.frogger_start_pos
				game.max_frogger_y = f32(game.number_of_grid_cells_on_axis_y)

			}
		}

		// Check if frogger reached any lillypad areas
		for lillypad_area, i in game.lillypad_areas {
			frogger_center := get_cell_center_pos(game.frogger_pos)
			is_frogger_on_lillypad := rl.CheckCollisionPointRec(frogger_center, lillypad_area)

			if is_frogger_on_lillypad {
				game.frogger_reached_lillypads[i] = true
				// Reset frogger position after reaching lillypad
				game.frogger_pos = game.frogger_start_pos
				game.max_frogger_y = f32(game.number_of_grid_cells_on_axis_y)

			}
		}

		// Check if frogger collided with bog areas (excluding lillypads)
		frogger_center := get_cell_center_pos(game.frogger_pos)
		is_frogger_in_bog := rl.CheckCollisionPointRec(frogger_center, game.bog_rectangle)

		if is_frogger_in_bog {
			// Check if frogger is NOT on a lillypad area
			is_on_lillypad := false
			for lillypad_area in game.lillypad_areas {
				if rl.CheckCollisionPointRec(frogger_center, lillypad_area) {
					is_on_lillypad = true
					break
				}
			}

			// If in bog but not on lillypad, frogger dies
			if !is_on_lillypad {
				game.frogger_pos = game.frogger_start_pos
				game.frogger_lerp_hop_start_pos = game.frogger_start_pos
				game.frogger_lerp_hop_end_pos = game.frogger_start_pos
				game.frogger_lerp_hop_timer = 0
				game.max_frogger_y = f32(game.number_of_grid_cells_on_axis_y)
			}
		}

		// debug options
		if rl.IsKeyPressed(.F1) {
			game.debug_show_grid = !game.debug_show_grid
		}


		// rendering

		screen_width := f32(rl.GetScreenWidth())
		screen_height := f32(rl.GetScreenHeight())

		scale := min(
			screen_width / f32(game.game_screen_width),
			screen_height / f32(game.game_screen_height),
		)

		// NOTE(jblat): For mouse, see: https://github.com/raysan5/raylib/blob/master/examples/core/core_window_letterbox.c

		{ 	// DRAW TO RENDER TEXTURE
			rl.BeginTextureMode(game.game_render_target)
			defer rl.EndTextureMode()

			rl.ClearBackground(rl.LIGHTGRAY)

			background_src_rectangle := rl.Rectangle {
				0,
				0,
				f32(game.texture_background.width),
				f32(game.texture_background.height),
			}
			background_texture_scale_x :=
				f32(game.game_screen_width) / f32(game.texture_background.width)
			background_texture_scale_y :=
				f32(game.game_screen_height) / f32(game.texture_background.height)

			background_render_rectangle := rl.Rectangle {
				0,
				0,
				f32(game.texture_background.width) * background_texture_scale_x,
				f32(game.texture_background.height) * background_texture_scale_y,
			}
			rl.DrawTexturePro(
				game.texture_background,
				background_src_rectangle,
				background_render_rectangle,
				[2]f32{},
				0,
				rl.WHITE,
			)

			draw_entities_with_sprites(
				game.floating_logs[:],
				game.texture_sprite_sheet,
				game.sprite_sheet_cell_size,
				f32(game.cell_size),
			)

			for log in game.floating_logs {
				draw_rectangle_on_grid(log.rectangle, rl.PURPLE, f32(game.cell_size))
			}

			draw_entities_with_sprites(
				game.turtles[:],
				game.texture_sprite_sheet,
				game.sprite_sheet_cell_size,
				f32(game.cell_size),
			)
			draw_entities_with_padding(game.vehicles[:], f32(game.cell_size), 0, 0.1)


			// Draw lillypad areas that have been reached as bright green rectangles
			for lillypad_area, i in game.lillypad_areas {
				if game.frogger_reached_lillypads[i] {
					draw_rectangle_on_grid(
						lillypad_area,
						rl.Color{50, 255, 50, 255},
						f32(game.cell_size),
					)
				}
			}

			// Determine which frog sprite to use based on animation frame
			current_frog_sprite := game.frog_sprite_3 // Default idle sprite
			if game.frogger_animation_playing {
				// During hop animation, use the sequence: 3,2,1,2,3
				sprite_number := game.frog_animation_sequence[game.frogger_current_animation_frame]
				switch sprite_number {
				case 1:
					current_frog_sprite = game.frog_sprite_1
				case 2:
					current_frog_sprite = game.frog_sprite_2
				case 3:
					current_frog_sprite = game.frog_sprite_3
				}
			}

			// Calculate rotation based on facing direction
			rotation_angle: f32 = 0
			switch game.frogger_facing_direction {
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
			draw_sprite_on_grid(
				game.frogger_pos,
				current_frog_sprite,
				game.texture_sprite_sheet,
				game.sprite_sheet_cell_size,
				f32(game.cell_size),
				rotation_angle,
			)

			if game.debug_show_grid {
				// draw grid

				for x: i32 = 0; x < game.number_of_grid_cells_on_axis_x; x += 1 {
					render_x := f32(x * game.cell_size)
					render_start_y: f32 = 0
					render_end_y := f32(game.game_screen_height)
					rl.DrawLineV(
						[2]f32{render_x, render_start_y},
						[2]f32{render_x, render_end_y},
						rl.WHITE,
					)
				}

				for y: i32 = 0; y < game.number_of_grid_cells_on_axis_y; y += 1 {
					render_y := f32(y * game.cell_size)
					render_start_x: f32 = 0
					render_end_x := f32(game.game_screen_width)
					rl.DrawLineV(
						[2]f32{render_start_x, render_y},
						[2]f32{render_end_x, render_y},
						rl.WHITE,
					)
				}

			}
			draw_text_on_grid_centered(
				fmt.ctprintf("Score: %d", game.score),
				[2]f32{7, 0},
				1,
				0,
				rl.WHITE,
				game.font,
				f32(game.cell_size),
			)
		}

		{ 	// DRAW TO WINDOW
			rl.BeginDrawing()
			defer rl.EndDrawing()

			rl.ClearBackground(rl.BLACK)

			src := rl.Rectangle {
				0,
				0,
				f32(game.game_render_target.texture.width),
				f32(-game.game_render_target.texture.height),
			}

			window_midpoint_x := screen_width - (f32(game.game_screen_width) * scale) / 2
			window_midpoint_y := screen_height - (f32(game.game_screen_height) * scale) / 2
			window_scaled_width := f32(game.game_screen_width) * scale
			window_scaled_height := f32(game.game_screen_height) * scale

			dst := rl.Rectangle {
				(screen_width - window_scaled_width) / 2,
				(screen_height - window_scaled_height) / 2,
				window_scaled_width,
				window_scaled_height,
			}

			rl.DrawTexturePro(game.game_render_target.texture, src, dst, [2]f32{0, 0}, 0, rl.WHITE)

		}

	}
	free_all(context.temp_allocator)
}
