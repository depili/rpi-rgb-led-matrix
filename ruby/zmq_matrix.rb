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
end