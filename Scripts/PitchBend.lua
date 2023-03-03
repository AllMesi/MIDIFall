class "PitchBend" {
	new = function (self, time, signedValue, channel)
		self.time = time
		self.signedValue = signedValue
		self.channel = channel
	end,
	
	getTime = function (self)
		return self.time
	end,
	
	getSignedValue = function (self)
		return self.signedValue
	end,

	getChannel = function(self)
		return self.channel
	end
}