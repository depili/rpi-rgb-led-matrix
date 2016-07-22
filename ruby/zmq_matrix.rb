require 'socket'
require 'zmq'

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
	
	private
	
	# Draw a given bitmap with the given color
	def draw_bitmap(bitmap, color, i, x, y, l)
		bitmap.each_with_index do |row, r|
			row[i,l].each_with_index do |b, c|
				setPixel(r+x,c+y,color) if b
			end
		end
	end
	
end