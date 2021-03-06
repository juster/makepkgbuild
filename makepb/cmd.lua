--[[

cmd.lua

A simple command class. Allows other classes to override the default behavior.
The only purpose is to make modifying command arguments easier.

--]]

local bash      = require( "makepb.bash" )
local tobashval = bash.tobashval

Cmd = {}
Cmd.__index = Cmd

function Cmd:new ( name )
    return setmetatable( { cmdname = name;
                           args    = {};
                           cmdenv  = {}; }, self )
end

-- Convert a table of arguments into a proper array table...
local function convert_args ( args )
    if type( args ) ~= "table" then return { args } end

    -- #args only gives results when args is an array style table
    if #args > 0 then return args end

    -- The arguments are given as name/value pairs... (or empty)
    -- convert name/value pairs into GNU long arguments
    local results = {}
    for k, v in pairs( args ) do
        if type( v ) == "boolean" then
            if v then table.insert( results, "--" .. k ) end
        else
            if v:find( "%s" ) then v = "'" .. v .. "'" end
            table.insert( results, "--" .. k .. "=" .. v )
        end
    end
    return results
end

function Cmd:set ( args )
    self.args = convert_args( args )
end

function Cmd:add ( args )
    for i, arg in ipairs( convert_args( args )) do
        table.insert( self.args, arg )
    end
end

function Cmd:env ( newenv )
    if newenv == nil then return self.cmdenv end

    local envcopy = {}
    for k, v in pairs( newenv ) do envcopy[k] = v end
    self.cmdenv = envcopy
end

function Cmd:__tostring ( )
    local envsets = {}
    for k, v in pairs( self.cmdenv ) do
        table.insert( envsets, k .. "=" .. tobashval( v ))
    end

    local cmdtxt = ""
    if #envsets > 0 then
        cmdtxt = table.concat( envsets, " " ) .. " "
    end
    return cmdtxt .. self.cmdname .. " " .. table.concat( self.args, " " )
end
