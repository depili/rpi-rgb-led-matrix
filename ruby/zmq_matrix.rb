require 'socket'
require 'zmq'

class	ZmqMatrix
	attr_accessor :matrix
	
	def initialize(host, rows, cols)
		@ctx = ZMQ::Context.new
		@socket = @ctx.socket(:PUSH)
		@socket.connect(host)
		@rows = rows
		@columns = cols
		@matrix = Array.new
		@matrix.fill(0, nil, @rows * @columns)
	end
	
	def send
		@socket.send(@matrix.pack('C*'))
	end
	
	def setPixel(r,c,color)
		a = (r*@columns + c)*3
		@matrix[a] = color[0]
		@matrix[a+1] = color[1]
		@matrix[a+2] = color[2]
	end
	
	def fill(color)
		@matrix.fill(nil, @rows * @columns * 3) {|i| color[i%3]}
	end
	
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
	
	private
	
	def draw_bitmap(bitmap, color, i, x, y, l)
		bitmap.each_with_index do |row, r|
			row[i,l].each_with_index do |b, c|
				setPixel(r+x,c+y,color) if b
			end
		end
	end
	
end