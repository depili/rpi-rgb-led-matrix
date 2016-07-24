require 'socket'
require 'zmq'
require 'color'

class	ZmqMatrix
	attr_accessor :matrix
	
	# Initialize the zmq context, create a socket and connect to the matrix
	# host is 'tcp://example.com:port'
	def initialize(host, rows, cols)
		@context = ZMQ::Context.new
		@socket = @context.socket(:PUSH)
		@socket.connect(host)
		@rows = rows
		@columns = cols
		@matrix = Array.new
		@matrix.fill(0, nil, @rows * @columns)
		@current_color = 0
	end
	
	# Send the updated matrix state
	def send
		@socket.send(@matrix.pack('C*'))
	end
	
	# Set one pixel to given color
	def setPixel(r,c,color)
		a = (r*@columns + c)*3
		@matrix[a] = color[0]
		@matrix[a+1] = color[1]
		@matrix[a+2] = color[2]
	end
	
	# Fill the entire matrix with given color
	def fill(color)
		@matrix.fill(nil, @rows * @columns * 3) {|i| color[i%3]}
	end
	
	# Scroll a bitmap that is 2d array of boolean variables
	# Color is the color to draw the 'true' values in
	# i is the number of pixels to scroll
	# x and y are the coordinates of the top left corner
	# l is the length of the scroll "window"
	def scroll(bitmap, color, i, x, y, l)
		s = bitmap[0].size
		if s < l
			# Bitmap is smaller than requested scroll area, just print the text
			draw_bitmap(bitmap, color, 0, x, y, l)
			return
		end
	
		i = i%s
		size = s - i
		if size >= l
			draw_bitmap(bitmap, color, i, x, y, l)
		else
			draw_bitmap(bitmap, color, i, x, y, l)
			draw_bitmap(bitmap, color, 0, x, y + size, l - size)
		end
	end
	
	def scroll_plasma(bitmap, i, x, y, l)
		@current_color += 1
		
		s = bitmap[0].size
		if s < l
			# Bitmap is smaller than requested scroll area, just print the text
			draw_plasma_bitmap(bitmap, 0, x, y, l)
			return
		end
	
		i = i%s
		size = s - i
		if size >= l
			draw_plasma_bitmap(bitmap, i, x, y, l)
		else
			draw_plasma_bitmap(bitmap, i, x, y, l)
			draw_plasma_bitmap(bitmap, 0, x, y + size, l - size)
		end
	end
	
	
	# Clear the matrix
	def clear
		fill [0,0,0]
		send
	end
	
	# Shutdown, clear the matrix and then close the zmq socket and context
	def shutdown
		clear
		@socket.close
		@context.destroy
	end
	
	def flame_fill
		if @fire_buffer.nil?
			@fire_buffer = Array.new.fill(0,nil, @rows*@columns)
		end
		
		# Randomize bottom row
		(0..@columns).each do |i|
			@fire_buffer[-i] = Random.rand(255)
		end
				
		(0...@rows-1).each do |r|
			(0...@columns-1).each do |c|
				value =  flame((r+1) % @rows, (c -1 + @columns) % @columns)
				value += flame((r+1) % @rows, (c % @columns))
				value += flame((r+1) % @rows, (c +1) % @columns)
				value += flame((r+2) % @rows, c % @columns)
				value *= 30
				value /= 129
				@fire_buffer[(r*@columns)+c] = value
			end
		end
		@matrix = @fire_buffer.map {|c| flame_palette[c]}.flatten
	end
	
	private
	
	def flame(y,x)
		@fire_buffer[(y*@columns)+x]
	end
	
	def flame_palette
		return @_flame_palette unless @_flame_palette.nil?
		
		@_flame_palette = Array.new
		(0..255).each do |i|
			c = Color::HSL.new(i / 4, 100, [50,i/256.0*100].min).to_rgb
			@_flame_palette << [(c.r*255).to_i, (c.g*255).to_i, (c.b*255).to_i]
		end
		return @_flame_palette
	end
	
	def flame_color(r,c)
		color = flame_palette[@fire_buffer[(r*@columns)+c]]
	end
	
	def plasma_palette
		return @_plasma_palette unless @_plasma_palette.nil?
		
		@_plasma_palette = Array.new
		(0..360).each do |i|
			c = Color::HSL.new(i,50,50).to_rgb
			@_plasma_palette << [(c.r*255).to_i, (c.g*255).to_i, (c.b*255).to_i]
		end
		return @_plasma_palette
	end
	
	def plasma_color(r,c)
		color = plasma_palette[(plasma_bitmap[(r*@columns)+c] + @current_color) % 360]
	end
	
	# Draw a given bitmap with the given color
	def draw_bitmap(bitmap, color, i, x, y, l)
		bitmap.each_with_index do |row, r|
			row[i,l].each_with_index do |b, c|
				setPixel(r+x,c+y,color) if b
			end
		end
	end
	
	def draw_plasma_bitmap(bitmap, i, x, y, l)
		bitmap.each_with_index do |row, r|
			row[i,l].each_with_index do |b, c|
				setPixel(r+x,c+y,plasma_color(r,c)) if b
			end
		end
	end
	
	def plasma_bitmap
		return @_plasma_bitmap unless @_plasma_bitmap.nil?
		
		@_plasma_bitmap = Array.new.fill(0, nil, @rows * @columns)
		(0..@rows).each do |r|
			(0..@columns).each do |c|
				color = 128.0 + (128.0 * Math.sin(c / 16.0))
				color += 128.0 + (128.0 * Math.sin(r / 8.0))
				color += 128.0 + (128.0 * Math.sin((c + r) / 16.0))
				color += 128.0 + (128.0 * Math.sin(Math.sqrt(c * c + r * r)) / 8.0)
				@_plasma_bitmap[(r*@columns)+c] = color.to_i % 360
			end
		end
		return @_plasma_bitmap
	end
	
end