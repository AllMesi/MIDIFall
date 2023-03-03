class "NotesComponent" {
	extends "DisplayComponent",
	
	-- Override
	new = function (self, x,y, width,height)
		self:super(x,y, width,height)
		
		self.noteScale = 10.0
		self.noteLengthOffset = 0		-- TODO: offset not yet done!
		-- self.noteLengthFlooring = true
		
		self.colorAlpha = 0.8
		
		self.useRainbowColor = false
		self.rainbowColorHueShift = 0.45
		self.rainbowColorSaturation = 0.8
		self.rainbowColorValue = 0.8
		
		self.brightNote = true
		self.brightNoteSaturation = 0.6
		self.brightNodeValue = 0.9
		
		self.pitchBendSemitone = 24

		self.noteOutlines = true
		
		self.useDefaultTheme = true
		self.regularNoteSprite = Sprite()
		self.diamondNoteSprite = Sprite(
			love.graphics.newImage("Assets/Arrow left icon 4.png")
		)
	end,

	-- Implement
	update = function (self, dt)
		
	end,
	
	-- Implement
	draw = function (self, screenWidth,screenHeight, lowestKey, highestKey, keyGap)
		if not self.enabled then
			return
		end
		
		love.graphics.push()
		
		--//////// Common Infomation ////////
		local song = player:getSong()
		
		local sortedTracks = song:getSortedTracks()
		local time = player:getTimeManager():getTime()
		
		if self.orientation == 1 or self.orientation == 3 then
			if self.orientation == 1 then
				love.graphics.translate(0,screenHeight)
				love.graphics.scale(1,-1)
			end
			love.graphics.translate(screenWidth, 0)
			love.graphics.rotate(math.pi/2)
			
			screenWidth, screenHeight = screenHeight, screenWidth
			
		elseif self.orientation == 2 then
			love.graphics.translate(screenWidth, 0)
			love.graphics.scale(-1,1)
		end
		
		local resolutionRatio = screenWidth / (self.height*screenHeight)
		
		local spaceForEachKey = (self.height*screenHeight) / (highestKey-lowestKey+1)
		local keyHeightRatio = 1 - keyGap
			-- 1.0 = a crotchet
		local absoluteKeyGap = keyGap*spaceForEachKey
		
		local noteScale = ( screenWidth / 1920 ) * ( self.noteScale*128/song:getTimeDivision() )
		local pixelMoved = math.floor(noteScale*(time-player:getInitialTime()))
		
		local noteLengthOffset = self.noteLengthOffset * song:getTimeDivision()
		
		local leftBoundary = math.max( math.floor(self.x * screenWidth), 0 )
		
		local firstNonFinishedNoteIDInTracks = player:getFirstNonFinishedNoteIDInTracks()
		local currentPitchBendValueInTracks = player:getCurrentPitchBendValueInTracks()
		
		--//////// Main Section ////////
		love.graphics.translate(0, screenHeight*self.y)
		
		love.graphics.translate(0, absoluteKeyGap/2)
		
		local scissorWidth = math.clamp(screenWidth-leftBoundary, 0,screenWidth)
		if self.orientation == 0 then
			love.graphics.setScissor(leftBoundary, 0, scissorWidth, screenHeight)
		elseif self.orientation == 1 then
			love.graphics.setScissor(0, 0, screenHeight, scissorWidth)
		elseif self.orientation == 2 then
			love.graphics.setScissor(0, 0, scissorWidth, screenHeight)
		elseif self.orientation == 3 then
			love.graphics.setScissor(0, leftBoundary, screenHeight, scissorWidth)
		end
		
		for i, track in ipairs(sortedTracks) do
			local trackID = track:getID()
			
			if track:getEnabled() then
				local notes = track:getNotes()
				local pitchBends = track:getPitchBends()
				local isPitchBendValueInTracksIncreasing = player:getIsPitchBendValueInTracksIncreasing()
				
				for noteID = firstNonFinishedNoteIDInTracks[trackID], #notes do
					local note = notes[noteID]
					local noteTime = note:getTime()
					local noteLength = note:getLength() or 0
					local notePitch = note:getPitch()
					
					if notePitch >= lowestKey and notePitch <= highestKey then
						local noteX = math.floor(screenWidth*self.x + noteScale * (noteTime-player:getInitialTime()) - pixelMoved)
						local noteY = (highestKey-notePitch) * spaceForEachKey
						local noteCulledWidth = math.max(leftBoundary - noteX, 0)
						
						-- If the current note is outside the right boundary, then so to the later notes
						if noteX >= screenWidth then
							break
						end
						
						--//////// coloring ////////
						local h,s,v
						local h2,s2,v2
						if self.useRainbowColor then
							h,s,v = ((notePitch-lowestKey) / highestKey + self.rainbowColorHueShift) % 1, self.rainbowColorSaturation, self.rainbowColorValue
						else
							h,s,v = unpack(track:getCustomColorHSV())
						end
						
						-- Brighten up the key while playing
						if self.brightNote and noteTime <= time then
							s = self.brightNoteSaturation
							v = self.brightNodeValue
						end
						
						love.graphics.setColor(vivid.HSVtoRGB(h,s,v,self.colorAlpha))
						
						
						--//////// Drawing ////////
						-- Here math.max seems to be unnecessary since it would be culled out before.
						-- However, the precision problem may cause a very small negative number.
						-- Hence, to prevent a note being shown outside the boundary, using a math.max is better.
						local noteWidth = math.ceil(math.max(noteScale * (noteLength - noteLengthOffset), 0))
						local noteHeight = math.max(((self.height*screenHeight) / (highestKey-lowestKey+1))*keyHeightRatio, 0)
							
						if track:getIsDiamond() then
							local size = (12/7) * noteHeight
							local halfSize = size / 2
							
							if self.useDefaultTheme then
								love.graphics.push()
								love.graphics.translate(0, -(size-noteHeight)/2)
								
								love.graphics.polygon("fill",
									noteX+noteCulledWidth, noteY,
									noteX+noteCulledWidth-halfSize, noteY+halfSize,
									noteX+noteCulledWidth, noteY+size,
									noteX+noteCulledWidth+halfSize, noteY+halfSize
								)
								
								love.graphics.pop()
							else
								self.diamondNoteSprite:draw(noteX-halfSize,noteY, size,size, screenWidth,screenHeight)
							end
							
						else
							-- idk if this works correctly
							local pbV = currentPitchBendValueInTracks[trackID]
							local pbShift = -self.pitchBendSemitone*spaceForEachKey * pbV/8192
							if noteTime <= time then
							-- if true then
							-- if false then
								
								if self.useDefaultTheme then
									love.graphics.rectangle("fill", noteX+noteCulledWidth,noteY+(note:getChannel() == pbC and pbShift or 0), math.max(noteWidth-noteCulledWidth, 0),noteHeight)
									if self.noteOutlines then
										local r, g, b, a = love.graphics.getColor()
										love.graphics.setColor(r/2,g/2,b/2,a)
										love.graphics.rectangle("line", noteX+noteCulledWidth,noteY+pbShift, math.max(noteWidth-noteCulledWidth, 0),noteHeight)
									end
								else
									self.regularNoteSprite:draw(noteX,noteY, noteWidth,noteHeight, screenWidth,screenHeight)
								end
							else
								-- love.graphics.rectangle("fill", noteX+noteCulledWidth,noteY, noteWidth-noteCulledWidth,noteHeight, noteHeight/2,noteHeight/2)
								
								if self.useDefaultTheme then
									love.graphics.rectangle("fill", noteX+noteCulledWidth,noteY+pbShift, math.max(noteWidth-noteCulledWidth, 0),noteHeight)
									if self.noteOutlines then
										local r, g, b, a = love.graphics.getColor()
										love.graphics.setColor(r/2,g/2,b/2,a)
										love.graphics.rectangle("line", noteX+noteCulledWidth,noteY+(note:getChannel() == pbC and pbShift or 0), math.max(noteWidth-noteCulledWidth, 0),noteHeight)
									end
									
									-- love.graphics.setColor(1,1,1)
									-- love.graphics.print(noteID, noteX+noteCulledWidth,noteY,0,0.5)
								else
									self.regularNoteSprite:draw(noteX,noteY, noteWidth,noteHeight, screenWidth,screenHeight)
								end
								
								-- love.graphics.setColor(0,0,0)
								-- love.graphics.setLineWidth(4)
								-- love.graphics.rectangle("line", noteX+noteCulledWidth,noteY, noteWidth-noteCulledWidth,noteHeight)
							end
							-- love.graphics.setColor(1,1,1)
							-- love.graphics.print(noteID, noteX+noteCulledWidth,noteY)
							-- love.graphics.print(noteTime, 0,50,0,2)
							-- love.graphics.print(currentPitchBendValueInTracks[trackID], 0,70,0,2)
						end
					end
				end
			end
		end
		
		love.graphics.setScissor()
		
		love.graphics.pop()
	end,
	
	getNotesScale = function (self)
		return self.noteScale
	end,
}
