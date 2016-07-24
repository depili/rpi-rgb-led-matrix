def time_diff(time)
	diff = Time.now - time
	str = Time.at(diff.to_i.abs).utc.strftime "%H:%M:%S"
	if diff <= 0
		return "T -#{str}", diff
	else
		return "T +#{str}", diff
	end
end

def print_time_diff(font, time, color1 = [0,255,0], color2 = [255,64,64], x=0, y=0)
	text, diff = time_diff time
	bitmap = font.text_to_bitmap text
	if diff <= 0
		color = color1
	else
		color = color2
	end
	@matrix.scroll_plasma(bitmap, 0, x, y, bitmap[0].size)
end