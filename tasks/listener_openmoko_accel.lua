local M = {}

local toribio = require 'toribio'

M.init = function(conf)
	local sched = require 'lumen.sched'
	
	--[[
	return sched.run(function()
		local accel = toribio.wait_for_device('openmoko_accel')
		print('listener started', accel.name)
		while true do
			print ('ACC',accel.get_accel2())
			sched.sleep(conf.interval or 1)
		end
	end)
	--]]

	local accel1 = toribio.wait_for_device('accelerometer.1')
	local accel2 = toribio.wait_for_device('accelerometer.2')

	print('listener starting', accel1.name,accel2.name)
	sched.sigrun(
		{accel1.events.data},
		function(_,x,y,z)
			print (x,y,z)
		end
	)
	sched.sigrun(
		{accel2.events.data},
		function(_,x,y,z)
			print ('','','','',"",x,y,z)
		end
	)

	accel1.run(true,conf.accelerometer1.step or 0.1)
	accel2.run(true,conf.accelerometer2.step or 0.5)


end

return M
