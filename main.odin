package main

import rl "vendor:raylib"

// https://forum.sublimetext.com/t/my-sublime-text-windows-cheat-sheet/8411

sfx_squish_bytes := #load("squish.wav")
image_background_bytes := #load("frogger_background_modified.png")
image_sprite_sheet_bytes := #load("frogger_sprite_sheet_modified.png")


draw_rectangle_on_grid :: proc(grid_rectangle: rl.Rectangle, color: rl.Color, cell_size: f32) {
	render_rectangle := rl.Rectangle {
		grid_rectangle.x * cell_size,
		grid_rectangle.y * cell_size,
		grid_rectangle.width * cell_size,
		grid_rectangle.height * cell_size,
	}

	rl.DrawRectangleRec(render_rectangle, color)
}

draw_rectangle_lines_on_grid :: proc(
	grid_rectangle: rl.Rectangle,
	line_thick: f32,
	color: rl.Color,
	cell_size: f32,
) {
	render_rectangle := rl.Rectangle {
		grid_rectangle.x * cell_size,
		grid_rectangle.y * cell_size,
		grid_rectangle.width * cell_size,
		grid_rectangle.height * cell_size,
	}

	rl.DrawRectangleLinesEx(render_rectangle, line_thick, color)
}

// NOTE: come up with examples of passing lists of things to functions

move_entities :: proc(entities: []Entity, max_x: f32) {
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


draw_entities_with_padding :: proc(
	entities: []Entity,
	cell_size: f32,
	padding_x: f32 = 0,
	padding_y: f32 = 0,
) {
	for entity in entities {
		entity_rectangle_padded := entity.rectangle
		entity_rectangle_padded.x += padding_x
		entity_rectangle_padded.y += padding_y
		entity_rectangle_padded.width -= padding_x * 2
		entity_rectangle_padded.height -= padding_y * 2

		draw_rectangle_on_grid(entity_rectangle_padded, entity.color, cell_size)
	}
}

Entity :: struct {
	rectangle: rl.Rectangle,
	speed:     f32,
	color:     rl.Color,
}


get_cell_center_pos :: proc(pos: [2]f32) -> [2]f32 {
	ret := [2]f32{pos.x + 0.5, pos.y + 0.5}
	return ret
}

main :: proc() {
	// All positions and dimensions will be driven by the grid and then scaled however much is needed
	cell_size: i32 = 64

	number_of_grid_cells_on_axis_x: i32 = 14
	number_of_grid_cells_on_axis_y: i32 = 16

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


	wave_squish := rl.LoadWaveFromMemory(".wav", &sfx_squish_bytes[0], i32(len(sfx_squish_bytes)))
	sfx_squish := rl.LoadSoundFromWave(wave_squish)

	image_background := rl.LoadImageFromMemory(
		".png",
		&image_background_bytes[0],
		i32(len(image_background_bytes)),
	)
	texture_background := rl.LoadTextureFromImage(image_background)

	image_sprite_sheet := rl.LoadImageFromMemory(
		".png",
		&image_sprite_sheet_bytes[0],
		i32(len(image_sprite_sheet_bytes)),
	)
	texture_sprite_sheet := rl.LoadTextureFromImage(image_sprite_sheet)


	game_screen_width: i32 = cell_size * number_of_grid_cells_on_axis_x
	game_screen_height: i32 = cell_size * number_of_grid_cells_on_axis_y

	game_render_target := rl.LoadRenderTexture(game_screen_width, game_screen_height)
	rl.SetTextureFilter(game_render_target.texture, rl.TextureFilter.BILINEAR)


	debug_show_grid := false

	frogger_start_pos := [2]f32{6, 14}
	frogger_pos := frogger_start_pos

	frogger_lerp_hop_duration: f32 = 0.1
	frogger_lerp_hop_timer: f32 = 0
	frogger_lerp_hop_start_pos: [2]f32
	frogger_lerp_hop_end_pos: [2]f32

	frogger_death_timer_duration: f32 = 1
	frogger_death_timer: f32 = frogger_death_timer_duration

	frogger_death_sprite_clip := rl.Rectangle{0, 3, 1, 1}

	sprite_sheet_cell_size: f32 = 16

	floating_logs := [?]Entity {
		{rectangle = {1, 3, 4, 1}, speed = 2, color = rl.BROWN},
		{rectangle = {7, 3, 4, 1}, speed = 2, color = rl.BROWN},
		{rectangle = {13, 3, 4, 1}, speed = 2, color = rl.BROWN},
		{rectangle = {0, 5, 6, 1}, speed = 3, color = rl.BROWN},
		{rectangle = {8, 5, 6, 1}, speed = 3, color = rl.BROWN},
		{rectangle = {15, 5, 6, 1}, speed = 3, color = rl.BROWN},
		{rectangle = {0, 6, 3, 1}, speed = 1, color = rl.BROWN},
		{rectangle = {5, 6, 3, 1}, speed = 1, color = rl.BROWN},
		{rectangle = {9, 6, 3, 1}, speed = 1, color = rl.BROWN},
		{rectangle = {15, 6, 3, 1}, speed = 1, color = rl.BROWN},
	}

	vehicles := [?]Entity {
		{{0, 13, 1, 1}, -1.5, rl.YELLOW},
		{{3, 13, 1, 1}, -1.5, rl.YELLOW},
		{{6, 13, 1, 1}, -1.5, rl.YELLOW},
		{{10, 13, 1, 1}, -1.5, rl.YELLOW},
		{{0, 12, 1, 1}, 2.0, rl.WHITE},
		{{3, 12, 1, 1}, 2.0, rl.WHITE},
		{{6, 12, 1, 1}, 2.0, rl.WHITE},
		{{10, 12, 1, 1}, 2.0, rl.WHITE},
	}

	river_rectangle := rl.Rectangle{0, 0, 14, 8}

	// Lillypad areas - 5 spots at the top row between grid cells
	lillypad_areas := [?]rl.Rectangle {
		{0.5, 2, 1, 1}, // between positions 1-2
		{3.5, 2, 1, 1}, // between positions 3-4
		{6.5, 2, 1, 1}, // between positions 5-6
		{9.5, 2, 1, 1}, // between positions 7-8
		{12.5, 2, 1, 1}, // between positions 9-10
	}

	frogger_reached_lillypads := [5]bool{}

	turtles := [?]Entity {
		{rectangle = {2, 4, 2, 1}, speed = -1.5, color = rl.DARKGREEN},
		{rectangle = {6, 4, 2, 1}, speed = -1.5, color = rl.DARKGREEN},
		{rectangle = {10, 4, 2, 1}, speed = -1.5, color = rl.DARKGREEN},
		{rectangle = {14, 4, 2, 1}, speed = -1.5, color = rl.DARKGREEN},
		{rectangle = {1, 7, 3, 1}, speed = 1.8, color = rl.DARKGREEN},
		{rectangle = {6, 7, 3, 1}, speed = 1.8, color = rl.DARKGREEN},
		{rectangle = {11, 7, 3, 1}, speed = 1.8, color = rl.DARKGREEN},
	}

	for !rl.WindowShouldClose() {
		// gameplay
		can_frogger_request_to_hop := frogger_lerp_hop_timer <= 0
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

				frogger_next_pos := frogger_pos + move_direction

				is_frogger_next_position_out_of_bounds :=
					frogger_next_pos.x < 0 ||
					frogger_next_pos.x > f32(number_of_grid_cells_on_axis_x) - 1 ||
					frogger_next_pos.y < number_of_tiles_for_score_data ||
					frogger_next_pos.y >
						f32(number_of_grid_cells_on_axis_y) -
							number_of_tiles_for_lives_and_time_data

				if !is_frogger_next_position_out_of_bounds {
					frogger_lerp_hop_timer = frogger_lerp_hop_duration
					frogger_lerp_hop_start_pos = frogger_pos
					frogger_lerp_hop_end_pos = frogger_next_pos
				}
			}
		} else {
			frogger_lerp_hop_timer -= rl.GetFrameTime()
			if frogger_lerp_hop_timer < 0 {
				frogger_lerp_hop_timer = 0
			}
			amount := (1.0) - frogger_lerp_hop_timer / frogger_lerp_hop_duration
			frogger_pos.y =
				(1.0 - amount) * frogger_lerp_hop_start_pos.y +
				(amount * frogger_lerp_hop_end_pos.y)
			frogger_pos.x =
				(1.0 - amount) * frogger_lerp_hop_start_pos.x +
				(amount * frogger_lerp_hop_end_pos.x)
		}


		move_entities(vehicles[:], f32(number_of_grid_cells_on_axis_x))
		move_entities(floating_logs[:], f32(number_of_grid_cells_on_axis_x))
		move_entities(turtles[:], f32(number_of_grid_cells_on_axis_x))

		// when the frog is on log, the frog moves with log

		// logs = rectangle
		// logs_speed
		// frogger = pos

		// if the left corner is same as left corner as log rectangle

		// move frogger
		is_frogger_floating := false
		frogger_center_pos := frogger_pos + 0.5
		for log in floating_logs {
			log_rectangle := log.rectangle
			is_frog_on_log := rl.CheckCollisionPointRec(frogger_center_pos, log_rectangle)
			if is_frog_on_log {
				is_frogger_floating = true
				log_speed := log.speed
				move_amount := log_speed * rl.GetFrameTime()
				frogger_pos.x += move_amount
				frogger_lerp_hop_end_pos.x += move_amount
			}
		}

		for turtle in turtles {
			turtle_rectangle := turtle.rectangle
			is_frog_on_turtle := rl.CheckCollisionPointRec(frogger_center_pos, turtle_rectangle)
			if is_frog_on_turtle {
				is_frogger_floating = true
				turtle_speed := turtle.speed
				move_amount := turtle_speed * rl.GetFrameTime()
				frogger_pos.x += move_amount
				frogger_lerp_hop_end_pos.x += move_amount
			}
		}


		should_check_if_frogger_drowns_in_river := !is_frogger_floating
		if should_check_if_frogger_drowns_in_river {
			frogger_center_pos := frogger_pos + 0.5
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
				frogger_pos = frogger_start_pos
			}
		}

		for vehicle in vehicles {
			is_frogger_hit := rl.CheckCollisionPointRec(
				get_cell_center_pos(frogger_pos),
				vehicle.rectangle,
			)
			if is_frogger_hit {
				rl.PlaySound(sfx_squish)
				frogger_pos = frogger_start_pos
			}
		}

		// Check if frogger reached any lillypad areas
		for lillypad_area, i in lillypad_areas {
			frogger_center := get_cell_center_pos(frogger_pos)
			is_frogger_on_lillypad := rl.CheckCollisionPointRec(frogger_center, lillypad_area)

			if is_frogger_on_lillypad {
				frogger_reached_lillypads[i] = true
				// Reset frogger position after reaching lillypad
				frogger_pos = frogger_start_pos
			}
		}

		// debug options
		if rl.IsKeyPressed(.F1) {
			debug_show_grid = !debug_show_grid
		}


		// rendering

		screen_width := f32(rl.GetScreenWidth())
		screen_height := f32(rl.GetScreenHeight())

		scale := min(
			screen_width / f32(game_screen_width),
			screen_height / f32(game_screen_height),
		)

		// NOTE(jblat): For mouse, see: https://github.com/raysan5/raylib/blob/master/examples/core/core_window_letterbox.c

		{ 	// DRAW TO RENDER TEXTURE
			rl.BeginTextureMode(game_render_target)
			defer rl.EndTextureMode()

			rl.ClearBackground(rl.LIGHTGRAY)

			background_src_rectangle := rl.Rectangle {
				0,
				0,
				f32(texture_background.width),
				f32(texture_background.height),
			}
			background_texture_scale_x := f32(game_screen_width) / f32(texture_background.width)
			background_texture_scale_y := f32(game_screen_height) / f32(texture_background.height)

			background_render_rectangle := rl.Rectangle {
				0,
				0,
				f32(texture_background.width) * background_texture_scale_x,
				f32(texture_background.height) * background_texture_scale_y,
			}
			rl.DrawTexturePro(
				texture_background,
				background_src_rectangle,
				background_render_rectangle,
				[2]f32{},
				0,
				rl.WHITE,
			)

			// frogger_death_render_rectangle := rl.Rectangle{0, 0, f32(cell_size), f32(cell_size)}
			// frogger_death_scaled_sprite_sheet_clip := rl.Rectangle {
			// 	frogger_death_sprite_clip.x * sprite_sheet_cell_size,
			// 	frogger_death_sprite_clip.y * sprite_sheet_cell_size,
			// 	frogger_death_sprite_clip.width * sprite_sheet_cell_size,
			// 	frogger_death_sprite_clip.height * sprite_sheet_cell_size,
			// }

			// rl.DrawTexturePro(
			// 	texture_sprite_sheet,
			// 	frogger_death_scaled_sprite_sheet_clip,
			// 	frogger_death_render_rectangle,
			// 	[2]f32{},
			// 	0,
			// 	rl.WHITE,
			// )

			// rl.DrawTexture(texture_sprite_sheet, 0, 0, rl.WHITE)
			// draw_rectangle_lines_on_grid(river_rectangle, 5, rl.DARKBLUE, f32(cell_size))

			// bog_rectangle := rl.Rectangle{0, 1, 14, 2}
			// draw_rectangle_lines_on_grid(bog_rectangle, 5, rl.DARKGREEN, f32(cell_size))

			// median_rectangle := rl.Rectangle{0, 8, 14, 1}
			// draw_rectangle_lines_on_grid(median_rectangle, 5, rl.PURPLE, f32(cell_size))

			// road_rectangle := rl.Rectangle{0, 9, 14, 8}
			// draw_rectangle_lines_on_grid(road_rectangle, 5, rl.BLACK, f32(cell_size))

			// sidewalk_rectangle := rl.Rectangle{0, 14, 14, 1}
			// draw_rectangle_lines_on_grid(sidewalk_rectangle, 5, rl.PURPLE, f32(cell_size))

			draw_entities_with_padding(floating_logs[:], f32(cell_size), 0, 0.1)
			draw_entities_with_padding(turtles[:], f32(cell_size), 0, 0.1)
			draw_entities_with_padding(vehicles[:], f32(cell_size), 0, 0.1)


			// Draw lillypad areas that have been reached as bright green rectangles
			for lillypad_area, i in lillypad_areas {
				if frogger_reached_lillypads[i] {
					draw_rectangle_on_grid(
						lillypad_area,
						rl.Color{50, 255, 50, 255},
						f32(cell_size),
					)
				}
			}

			frogger_rectangle := rl.Rectangle{frogger_pos.x, frogger_pos.y, 1, 1}
			draw_rectangle_on_grid(frogger_rectangle, rl.GREEN, f32(cell_size))

			if debug_show_grid {
				// draw grid

				for x: i32 = 0; x < number_of_grid_cells_on_axis_x; x += 1 {
					render_x := f32(x * cell_size)
					render_start_y: f32 = 0
					render_end_y := f32(game_screen_height)
					rl.DrawLineV(
						[2]f32{render_x, render_start_y},
						[2]f32{render_x, render_end_y},
						rl.WHITE,
					)
				}

				for y: i32 = 0; y < number_of_grid_cells_on_axis_y; y += 1 {
					render_y := f32(y * cell_size)
					render_start_x: f32 = 0
					render_end_x := f32(game_screen_width)
					rl.DrawLineV(
						[2]f32{render_start_x, render_y},
						[2]f32{render_end_x, render_y},
						rl.WHITE,
					)
				}

			}
		}

		{ 	// DRAW TO WINDOW
			rl.BeginDrawing()
			defer rl.EndDrawing()

			rl.ClearBackground(rl.BLACK)

			src := rl.Rectangle {
				0,
				0,
				f32(game_render_target.texture.width),
				f32(-game_render_target.texture.height),
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
			rl.DrawTexturePro(game_render_target.texture, src, dst, [2]f32{0, 0}, 0, rl.WHITE)
		}

	}

}
