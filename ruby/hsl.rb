class	HSL
	attr_accessor :h, :s, :l
	
	def self.to_rgb(h,s,l)
		c = (1-(2*l-1).abs)*s
		h1 = h / 60
		x = c*(1-(h1%2-1).abs)
		if h1 < 1
			r = c
			g = x
			b = 0
		elsif h1 < 2
			r = x
			g = c
			b = 0
		elsif h1 < 3
			r = 0
			g = c
			b = x
		elsif h1 < 4 
			r = 0
			g = x
			b = c
		elsif h1 < 5
			r = x
			g = 0
			b = c
		elsif h1 < 6
			r = c
			g = 0
			b = x
		else
			r = g = b = 0
		end
		m = l - (0.5 * c)
		return [((r + m )*255).to_i, ((g + m )*255).to_i, ((b + m )*255).to_i]
	end
	
	def to_rgb
		HSL.to_rgb(@h,@s,@l)
	end
	
	def initialize(hue,saturation,lightness)
		@h = hue
		@s = saturation
		@l = lightness
	end
end