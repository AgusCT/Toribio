--- Toribio application.
-- This application starts the different tasks and device loaders.
-- It is controlled trough a configuration file (default toribio-go.conf).
-- @usage	lua toribio-go.lua [-h] [-d] [-c conffile|'none'] 
--		-h Print help
--		-c Use given configuration file (or none). 
--		   Defaults to 'toribio-go.conf'
--		-d NONE|ERROR|WARNING|INFO|DETAIL|DEBUG|ALL
-- @script toribio-go

package.path = package.path .. ";;;Lumen/?.lua"

require 'strict'

local sched = require 'sched'
local log = require 'log'
local selector = require "tasks/selector".init({service='nixio'})

local toribio = require 'toribio'

-- From http://lua-users.org/wiki/AlternativeGetOpt
-- getopt_alt.lua
-- getopt, POSIX style command line argument parser
-- param arg contains the command line arguments in a standard table.
-- param options is a string with the letters that expect string values.
-- returns a table where associated keys are true, nil, or a string value.
-- The following example styles are supported
--   -a one  ==> opts["a"]=="one"
--   -bone   ==> opts["b"]=="one"
--   -c      ==> opts["c"]==true
--   --c=one ==> opts["c"]=="one"
--   -cdaone ==> opts["c"]==true opts["d"]==true opts["a"]=="one"
-- note POSIX demands the parser ends at the first non option
--      this behavior isn't implemented.
local function getopt( arg, options )
  local tab = {}
  for k, v in ipairs(arg) do
    if string.sub( v, 1, 2) == "--" then
      local x = string.find( v, "=", 1, true )
      if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 )
      else      tab[ string.sub( v, 3 ) ] = true
      end
    elseif string.sub( v, 1, 1 ) == "-" then
      local y = 2
      local l = string.len(v)
      local jopt
      while ( y <= l ) do
        jopt = string.sub( v, y, y )
        if string.find( options, jopt, 1, true ) then
          if y < l then
            tab[ jopt ] = string.sub( v, y+1 )
            y = l
          else
            tab[ jopt ] = arg[ k + 1 ]
          end
        else
          tab[ jopt ] = true
        end
        y = y + 1
      end
    end
  end
  return tab
end
-- Test code
--opts = getopt( arg, "ab" )
--for k, v in pairs(opts) do
--  print( k, v )
--end
-- End of: From http://lua-users.org/wiki/AlternativeGetOpt

local opts = getopt( _G.arg, "cd" )

local param_log_level = opts["d"]
if param_log_level  == true then param_log_level ='DETAIL' end
if param_log_level then
	toribio.configuration.log = toribio.configuration.log or {}
	toribio.configuration.log.defaultlevel = param_log_level
end

--watches for task die events and prints out
sched.sigrun({emitter='*', events={sched.EVENT_DIE}}, print)

--loads from a configuration file
local function load_configuration(file)
	local func_conf, err = loadfile(file)
	assert(func_conf,err)
	local conf = toribio.configuration
	local meta_create_on_query 
	meta_create_on_query = {
		__index = function (table, key)
			table[key]=setmetatable({}, meta_create_on_query)
			return table[key]
		end,
	}
	setmetatable(conf, meta_create_on_query)
	setfenv(func_conf, conf)
	func_conf()
	meta_create_on_query['__index']=nil
end

if opts["h"] then
	print [[Usage:
	lua toribio-go.lua [-h] [-d] [-c conffile|'none'] 
		-d Debug mode
		-h This help
		-c Use given configuration file (or none). 
		   Defaults to 'toribio-go.conf'
	]]
	os.exit()
end
if not opts["c"] then
	load_configuration('toribio-go.conf')
elseif opts["c"] ~= "none" then
	load_configuration(opts["c"])
end

--set log level
if toribio.configuration and toribio.configuration.log 
and toribio.configuration.log and toribio.configuration.log.defaultlevel then
	print ('Setting log level', toribio.configuration.log.defaultlevel)
	log.setlevel(toribio.configuration.log.defaultlevel)
end

sched.run(function()
	for _, section in ipairs({'deviceloaders', 'tasks'}) do
		for task, conf in pairs(toribio.configuration[section] or {}) do
			log ('TORIBIOGO', 'DETAIL', 'Processing conf %s %s: %s', section, task, tostring((conf and conf.load) or false))

			if conf and conf.load==true then
				--[[
				local taskmodule = require (section..'/'..task)
				if taskmodule.start then
					local ok = pcall(taskmodule.start,conf)
				end
				--]]
				log ('TORIBIOGO', 'INFO', 'Starting %s %s', section, task)
				toribio.start(section, task)
			end
		end
	end
end)

print('Toribio go!')
log ('TORIBIOGO', 'INFO', 'Ready')
sched.go()


