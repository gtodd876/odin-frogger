package main
import rl "vendor:raylib"

Entity :: struct {
	rectangle: rl.Rectangle,
	speed:     f32,
	color:     rl.Color,
	sprite:    rl.Rectangle,
}

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

draw_sprite_on_grid :: proc(
	grid_pos: [2]f32,
	sprite_clip: rl.Rectangle,
	texture: rl.Texture2D,
	sprite_sheet_cell_size: f32,
	cell_size: f32,
	rotation: f32 = 0,
) {
	// Source rectangle from sprite sheet
	src_rect := rl.Rectangle {
		sprite_clip.x * sprite_sheet_cell_size,
		sprite_clip.y * sprite_sheet_cell_size,
		sprite_clip.width * sprite_sheet_cell_size,
		sprite_clip.height * sprite_sheet_cell_size,
	}

	// Destination rectangle on screen - center it on the grid position
	dst_rect := rl.Rectangle {
		(grid_pos.x * cell_size),
		(grid_pos.y * cell_size),
		sprite_clip.width * cell_size,
		sprite_clip.height * cell_size,
	}
	dst_midpoint := [2]f32{dst_rect.width / 2, dst_rect.height / 2}
	dst_rect.x += dst_midpoint.x
	dst_rect.y += dst_midpoint.y

	rl.DrawTexturePro(texture, src_rect, dst_rect, dst_midpoint, rotation, rl.WHITE)
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

draw_entities_with_sprites :: proc(
	entities: []Entity,
	texture: rl.Texture2D,
	sprite_sheet_cell_size: f32,
	cell_size: f32,
) {
	for entity in entities {
		draw_sprite_on_grid(
			{entity.rectangle.x, entity.rectangle.y},
			entity.sprite,
			texture,
			sprite_sheet_cell_size,
			cell_size,
		)
	}
}

get_cell_center_pos :: proc(pos: [2]f32) -> [2]f32 {
	ret := [2]f32{pos.x + 0.5, pos.y + 0.5}
	return ret
}

draw_text_on_grid :: proc(
	text: cstring,
	grid_pos: [2]f32,
	font_size: f32,
	spacing: f32,
	color: rl.Color,
	font: rl.Font,
	cell_size: f32,
) {
	rl.DrawTextEx(
		font,
		text,
		{grid_pos.x * f32(cell_size), grid_pos.y * f32(cell_size)},
		font_size * cell_size,
		spacing * cell_size,
		color,
	)
}

draw_text_on_grid_centered :: proc(
	text: cstring,
	grid_pos: [2]f32,
	size: f32,
	spacing: f32,
	color: rl.Color,
	font: rl.Font,
	cell_size: f32,
) {
	text_length := rl.MeasureTextEx(font, text, size, spacing)
	draw_text_on_grid(
		text,
		{grid_pos.x - (text_length.x / 2), grid_pos.y},
		size,
		spacing,
		color,
		font,
		cell_size,
	)
}

// draw_text_on_grid_right_justified :: proc(
// 	font: rl.Font,
// 	text: cstring,
// 	pos: [2]f32,
// 	size, spacing: f32,
// 	tint: rl.Color,
// 	grid_cell_size: f32,
// ) {
// 	text_dimensions := rl.MeasureTextEx(font, text, size, spacing)
// 	dst_pos := [2]f32{pos.x - f32(text_dimensions.x), pos.y}
// 	draw_text_on_grid(font, text, dst_pos, size, spacing, tint, grid_cell_size)
// }
