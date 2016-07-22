#!/usr/bin/env ruby

require 'socket'
require 'benchmark'
require_relative 'zmq_matrix'
require_relative 'bdf_font'
require_relative 'utils'

unless ARGV.size == 3
	abort "Usage: matrix-test.rb host rows cols\nexample: matrix-test.rb tcp://localhost:5555 32 128"
end
host = ARGV[0]
rows = ARGV[1].to_i
cols = ARGV[2].to_i

font = BdfFont.new('../fonts/7x13B.bdf')

@matrix = ZmqMatrix.new(host, rows, cols)

Signal.trap("INT") {
	puts "SIGINT received, shutting down!"
  @matrix.shutdown
  exit
}

@matrix.fill([0,128,0])
@matrix.send

sleep 1

@matrix.fill([0,128,255])
@matrix.send

sleep 1

text = "Jotain hassua tekstiä tässä nyt skrollaillaan vähäsen ees taas ja silleen   "

l = font.text_length(text)
@matrix.fill([64,0,64])
background = @matrix.matrix
bitmap = font.text_to_bitmap("Foo")

200.times do
	@matrix.matrix = background.dup
	@matrix.scroll(bitmap, [0,255,0], 23, 0, 0, 128)
	@matrix.send
	sleep 1 / 200.0	
end

bitmap = font.text_to_bitmap(text)

puts "Testing speed with scrolling text"
time = Benchmark.realtime do
	(0..l*5).each do |i|
		@matrix.matrix = background.dup
		@matrix.scroll(bitmap, [0,255,0], i, 16, 32, 64)
		@matrix.send
		sleep 1 / 150.0
	end
end
puts "Total time:     #{time.round 2} seconds"
puts "Time per frame: #{(time / l).round(3)}"
puts "FPS:            #{(1 / (time / (l*5))).to_i}"

@matrix.shutdown