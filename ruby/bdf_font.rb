#  bdf_font.rb
#
# Parse Glyph bitmap distribution format font files
# See https://en.wikipedia.org/wiki/Glyph_Bitmap_Distribution_Format
#
# Created by Vesa-Pekka Palmu on 2016-07-16.
# Copyright 2016 Vesa-Pekka Palmu.
# Licensed under the MIT license.
#

class BdfFont

	attr_reader :chars, :height, :baseline, :width

	# Parse one bdf format font file as a new font
	def initialize(font_file)
		@glyphs = {}
		@chars = -1
		
		file = File.open(font_file)
		loop do
			l = file.readline
			if l.start_with? 'FONTBOUNDINGBOX'
				_, width, height, x_offset, baseline = *l.split
				@width = width.to_i
				@height = height.to_i
				@x_offset = x_offset.to_i
				@baseline = baseline.to_i
			elsif l.start_with? 'CHARS '
				# Number of defined characters in this font
				@chars = l.split.last.to_i
			elsif l.start_with? 'STARTCHAR'
				# Start of a glyph definition
				parse_glyph(file)
			end
			
			if @glyphs.size == @chars
				break
			end
		end
		# Successfully parsed the font file and there was at least @chars unique glyphs.
		# We don't actually check for excess glyphs...
	rescue EOFError
		# File ended before correct number of glyphs were parsed.
		raise IOError, "EOF before all glyphs were read. Expected #{@chars} got #{@glyphs.size}"
	ensure
		file.close
	end
	
	# Print one character out
	def to_s(codepoint)
		glyph = @glyphs[codepoint]
		return nil if glyph.nil?		
		print_bitmap glyph[:bitmap]
		return nil
	end
	
	def get_glyph(codepoint)
		return @glyphs[codepoint]
	end
	
	def get_bitmap(codepoint)
		get_glyph(codepoint)[:bitmap]
	end
	
	# Generate a bitmap for a string
	def text_to_bitmap(str, start = nil, length = nil)
		bitmap = Array.new
		@height.times do
			bitmap << Array.new
		end
		str.each_codepoint do |c|
			get_bitmap(c).each_with_index do |r, i|
				bitmap[i] += r
			end
		end
		unless start.nil?
			bitmap.each_with_index {|r, i| bitmap[i] = r[start, length]}
		end
		return bitmap
	end
	
	def text_to_s(str, start = nil, length = nil)
		print_bitmap text_to_bitmap(str, start, length)
		return nil
	end
	
	def text_length(str)
		l = 0
		str.each_codepoint do |c|
			l += get_glyph(c)[:width]
		end
		return l
	end
		
	private
	
	def print_bitmap(bitmap)
		bitmap.each do |r|
			r.each do |b|
				print b ? 'X' : ' '
			end
			print "\n"
		end
	end
	
	# Parse one glyph from the file
	def parse_glyph(file)
		current_glyph = nil
		current_codepoint = nil
		loop do
			l = file.readline
			if l.start_with? 'ENCODING'
				_, current_codepoint = *l.split
			elsif l.start_with? 'BBX'
				_, width, height, x_offset, y_offset = *l.split
				current_glyph = {
					width: width.to_i,
					height: height.to_i,
					y_offset: y_offset.to_i,
					bitmap: []
				}
			elsif l.start_with? 'BITMAP'
				# Start of the glyph bitmap
				row = 0
				
				loop do
					l = file.readline
					if row < current_glyph[:height]
						current_glyph[:bitmap][row] = shift_row_bitmap(l, x_offset.to_i, current_glyph[:width])
						row += 1
					elsif l.start_with?('ENDCHAR') && row == current_glyph[:height]
						@glyphs[current_codepoint.to_i] = current_glyph
						return
					elsif
						raise IOError, "Error parsing glyph with codepoint #{current_codepoint}"
					end
				end
			end
		end
	end
	
	# The bitmap is stored as a hex encoded lines
	# Each bit represents one bit on bitmap row
	# The data is stored in 8bit chunks and padded as needed
	# MSB is the first pixel on the given row
	def shift_row_bitmap(data, x_offset, width)
		parsed = data.to_i(16)
		first_bit = 8 * ((width + 7) / 8) + x_offset
		ret = Array.new
		(0..(width-1)).each do |i|
			ret[i] = parsed[first_bit - i] == 1
		end
		return ret
	end
end