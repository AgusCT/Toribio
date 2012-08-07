--- Library for accesing a mouse.
-- This library allows to read data from a mouse,
-- such as it's coordinates and button presses.
-- The device will be named "mice", module "mice". 
-- @module mice
-- @alias device

local M = {}

M.start = function(conf)
	local toribio = require 'toribio'
	local nixiorator = require 'tasks/nixiorator'
	local nixio = nixiorator.nixio
	local sched = require 'sched'
	local catalog = require 'catalog'
	local floor = math.floor

	local filename = conf.filename or '/dev/input/mice'
	local devicename='mice:'..filename
	local fd = assert(nixio.open(filename, nixio.open_flags('rdonly', 'sync')))
	nixiorator.register_client(fd, 3)
	local x, y = 0, 0
	local bl, bm, br = 0, 0, 0

	local device={}
	
	local devtask = sched.run(function() 
		local nxtask = catalog.waitfor('nixiorator')
		catalog.register(devicename)
		local waitd ={emitter=nxtask,events={fd}, buff_len=0}
		while true do
			local _, _, data = sched.wait(waitd)
			
			local s1,dx,dy = string.byte(data,1,3)
			if floor(s1/16)%2 == 1 then 
				dx = dx - 0x100
			end
			if floor(s1/32)%2==1 then 
				dy = dy - 0x100
			end
			local left = s1%2
			if bl ~= left then 
				bl=left
				sched.signal(device.signals.leftbutton, left==1)
			end
			local right = floor(s1/2)%2
			if br ~= right then 
				br=right
				sched.signal(device.signals.rightbutton, right==1)
			end
			local middle = floor(s1/4)%2
			if bm ~= middle then 
				bm=middle
				sched.signal(device.signals.middlebutton, middle==1)
			end
			
			--print('DATA!!!', s1, '', dx,dy, left, middle, right)
			x, y = x+dx, y+dy
			
			if dx~=0 or dy~=0 then
				sched.signal(device.signals.move, x, y, dx, dy)

			end
		end 
	end)
	
	--- Name of the device (in this case, 'mice').
	device.name=devicename

	--- Module name (in this case, 'mice').
	device.module='mice'

	--- Task that will emit signals associated to this device.
	device.task=devtask

	--- Device file of the mouse.
	-- For example, '/dev/input/mice'
	device.filename=filename

	--- Signals emitted by this device.
	-- Button presses have single parameter: true on press,
	-- false on release.
	-- @field leftbutton Left button click.
	-- @field rightbutton Right button click.
	-- @field middlebutton Middle button click.
	-- @field move Mouse moved, first parameter x, second parameter y coordinates.
	-- @table signals
	device.signals={
		leftbutton={},
		rightbutton={},
		middlebutton={},
		move={},
	}

	--- Get mouse position.
	-- @return a pair of x, y coordinates.
	device.get_pos=function()
		return x, y
	end

	--- Reset position.
	-- Fixes the coordinates associated to the current
	-- position.
	-- @param newx number to set as x coordinate of
	-- the cursos (defaults to 0)
	-- @param newy number to set as y coordinate of
	-- the cursos (defaults to 0)
	device.reset_pos=function(newx, newy)
		newx, newy = newx or 0, newy or 0
		x, y = newx, newy
	end

	
	toribio.add_device(device)
end

return M
