class "DisplayComponentsRenderer" {
	new = function (self)
		self.components = {}
	
		self.font = love.graphics.newFont("Assets/NotoSansCJKtc-Medium_1.otf", 48)
	
		self.isRenderingVideo = false
		self.isEncodingVideo = false
		self.canvas = nil
		self.pipe = nil
		
		self.exportingTransparency = false
		
		self.exportingWidth = self:getWidth()
		self.exportingHeight = self:getHeight()
		self.exportingFramerate = 60
		self.exportingCRF = 18
		self.exportingPresets = {"ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"}
		self.exportingPresetID = 6
		self.exportingThread = love.thread.newThread([[
			require "love.image"
			require "love.event"
			
			local pipe
			
			if select("#", ...) >= 8 then
				-- If it is using H.264 encoding, it sends more parameters
				
				pipe = io.popen(
					string.format("\"\"%s\" -f image2pipe -r %d -s %dx%d -c:v rawvideo -pix_fmt rgba -frame_size %d -i - -vf colormatrix=bt601:bt709 -pix_fmt yuv420p -c:v libx264 -crf %d -preset:v %s -y \"%s\"\"", ...), "wb"
				)
			else
				pipe = io.popen(
					string.format("\"\"%s\" -f image2pipe -r %d -s %dx%d -c:v rawvideo -pix_fmt rgba -frame_size %d -i - -c:v png -y \"%s\"\"", ...), "wb"
				)
			end
			
			while not love.thread.getChannel("renderingStopped"):peek() or love.thread.getChannel("imageData"):getCount() > 0 do
				
				local imageData = love.thread.getChannel("imageData"):pop()
				
				if imageData then
					pipe:write(imageData:getString())
					
					imageData:release()
				end
			end
			
			love.thread.getChannel("renderingStopped"):pop()
			
			pipe:read('*a')	-- wait for the pipe
			pipe:close()
		]])
	end,
	
	update = function (self, dt, ...)
		
		if self.isRenderingVideo then
			dt = 1 / self.exportingFramerate
		end
		
		for i = 1, select("#", ...) do
			select(i, ...):update(dt)
		end
		
		if self.isRenderingVideo and player:getTimeManager():getTime() >= player:getEndTime() then
			self:finishRendering()
		end
		
		if self.isEncodingVideo and not self.exportingThread:isRunning() then
			love.window.showMessageBox("Video Export", "The video has been exported.", "info")
			self:finishEncoding()
		end
	end,
	
	draw = function (self)
		if self.isRenderingVideo then
			love.graphics.setCanvas(self.canvas)
			love.graphics.clear()
		end
		
		for i = 1, #self.components do
			self.components[i]:draw(self:getWidth(), self:getHeight())
		end
		
		love.graphics.setFont(self.font)
		
		if self.isRenderingVideo then
			love.graphics.setCanvas()
			
			local imageData = self.canvas:newImageData(0,1, 0,0, self.exportingWidth,self.exportingHeight)
			
			while love.thread.getChannel("imageData"):getCount() > 3 do end
			love.thread.getChannel("imageData"):push(imageData)
			imageData:release()
			
			local percentage = string.format("%3.2f", math.min(100*(player:getTimeManager():getTime()-player:getInitialTime())/(player:getEndTime()-player:getInitialTime()), 100))
			local renderingProgressMessage = "Rendering: " .. percentage .. "%"
			
			love.graphics.print(
				renderingProgressMessage,
				(love.graphics.getWidth()  - love.graphics.getFont():getWidth(renderingProgressMessage)) / 2,
				(love.graphics.getHeight() - love.graphics.getFont():getHeight()) / 2
			)
			
		elseif self.isEncodingVideo then
			local encodingProgressMessage = "Waiting for encoding..."
			
			love.graphics.print(
				encodingProgressMessage,
				(love.graphics.getWidth()  - love.graphics.getFont():getWidth(encodingProgressMessage)) / 2,
				(love.graphics.getHeight() - love.graphics.getFont():getHeight()) / 2
			)
		end
	end,
	
	setExportingPresetID = function (self, id)
		self.exportingPresetID = id
	end,
	
	getEncoderDirectory = function (self)
		return getDirectory() .. "/ffmpeg.exe"
	end,
	
	checkIfEncoderExist = function (self)
		local ffmpeg = io.open(self:getEncoderDirectory(), "r")
		local exist
		
		if ffmpeg then
			exist = true
			ffmpeg:close()
		else
			exist = false
		end
		
		return exist
	end,
	
	startToRender = function (self)
		local folderName = "Videos"
		if not love.filesystem.getInfo(folderName) then
			os.execute(string.format("cd %s && mkdir %s", getDirectory() ,folderName))
		end
		
		if not self:checkIfEncoderExist() then
			love.window.showMessageBox("Error", "FFmpeg not found. Please download FFmpeg binary and place \"ffmpeg.exe\" under the MIDIFall folder.", "info")
			return
		end
		
		local ffmpegPath = self:getEncoderDirectory()
		local width = self.exportingWidth
		local height = self.exportingHeight
		local framerate = self.exportingFramerate
		local crf = self.exportingCRF
		local preset = self.exportingPresets[self.exportingPresetID]
		
		player:pause()
		
		self.isRenderingVideo = true
		self.isEncodingVideo = true
		self.canvas = love.graphics.newCanvas(width, height)
		
		if not self.exportingTransparency then
			self.exportingThread:start(
				ffmpegPath,
				framerate,
				width, height,
				4*width*height,
				crf, preset,
				string.format("%s/%s/%s.mp4", getDirectory(), folderName, os.date("%Y%m%d-%H%M%S"))
			)
		else
			self.exportingThread:start(
				ffmpegPath,
				framerate,
				width, height,
				4*width*height,
				string.format("%s/%s/%s.mov", getDirectory(), folderName, os.date("%Y%m%d-%H%M%S"))
			)
		end
		
		player:moveToBeginning()
		player:resume()
	end,
	
	finishRendering = function (self)
		player:pause()
		player:moveToBeginning()
		self.isRenderingVideo = false
		love.thread.getChannel("renderingStopped"):push(true)
	end,
	
	finishEncoding = function (self)
		self.isEncodingVideo = false
	end,
	
	setExportingResolution = function (self, width, height)
		self.exportingWidth = width
		self.exportingHeight = height
	end,
	
	getWidth = function (self)
		if self.isRenderingVideo then
			return self.exportingWidth
		else
			return love.graphics.getWidth()
		end
	end,
	
	getHeight = function (self)
		if self.isRenderingVideo then
			return self.exportingHeight
		else
			return love.graphics.getHeight()
		end
	end,
	
	getIsExportingVideo = function (self)
		return self.isRenderingVideo or self.isEncodingVideo
	end,
	
	terminateVideoExport = function (self)
		self:finishRendering()
		self:finishEncoding()
		
		love.window.showMessageBox("Video Export", "The video export process has been terminated.", "info")
	end,
	
	addComponent = function (self, component)
		self.components[#self.components + 1] = component
	end,
}