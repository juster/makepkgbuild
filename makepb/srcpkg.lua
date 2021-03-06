--[[

srcpkg.lua

An abstract representation of a source package. Includes other classes
for representing PKGBUILDs and other lesser source package files.

--]]

local bash      = require "makepb.bash"
local tobashval = bash.tobashval

Pkgbuild = {}
Pkgbuild.__index = Pkgbuild

Pkgbuild.field_names = { "pkgname", "pkgver", "pkgrel", "epoch",
                         "pkgdesc", "arch", "url", "license", "install",
                         "options",
                         "changelog", "noextract", "groups",
                         "backup", "depends", "makedepends",
                         "checkdepends", "optdepends", "conflicts",
                         "provides", "replaces", "source" }

local OPTION_DEFAULTS = { strip = true; docs = true; libtool = true;
                          emptydirs = true; zipman = true; ccache = true;
                          distcc = true; buildflags = true; makeflags = true }

local PB_STRFIELDS = { pkgver = true, pkgrel = true,
                       pkgdesc = true, epoch = true, url = true,
                       install = true, changelog = true }

local PB_ARRFIELDS = {}
for i, name in ipairs({ "pkgname", "license", "source", "arch", "backup",
                        "depends", "makedepends", "checkdepends", "optdepends",
                        "groups", "conflicts", "provides", "replaces" }) do
    PB_ARRFIELDS[ name ] = true
end

function Pkgbuild:new ()
    local opts = {}
    for k, v in pairs( OPTION_DEFAULTS ) do opts[k] = v end
    return setmetatable( { fields  = {};
                           destdir = {};
                           funcs   = { build   = {};
                                       check   = {};
                                       package = {} };
                           options = opts }, self )
end

function Pkgbuild:set_field ( name, val )
    if PB_STRFIELDS[ name ] then
        if type( val ) ~= "string" and type( val ) ~= "number" then
            error( name .. " must be set with a string or number" )
        end
    elseif PB_ARRFIELDS[ name ] then
        if type( val ) == "string" or type( val ) == "number" then
            val = { val }
        elseif type( val ) ~= "table" then
            error( name .. " is an array field and must be set with an array" )
        end
    else
        error( name .. " is not a known PKGBULD field name" )
    end

    self.fields[ name ] = val
end

function Pkgbuild:get_field ( name )
    return self.fields[ name ]
end

function Pkgbuild:get_fields ( )
    local fieldscopy = {}
    for k, v in pairs( self.fields ) do fieldscopy[ k ] = v end
    return fieldscopy
end

function Pkgbuild:set_option ( name, enabled )
    if self.options[name] == nil then
        error( name .. " is not a valid PKGBUILD option name" )
    end

    if type( enabled ) ~= "boolean" then
        error( "You can only set an option to a boolean value" )
    end
    self.options[name] = enabled
    return enabled
end

function Pkgbuild:get_option ( name )
    if self.options[name] == nil then
        error( name .. " is not a valid PKGBUILD option name" )
    end

    return self.options[name]
end

function Pkgbuild:set_options ( listtbl )
    for i, opt in ipairs( listtbl ) do
        local enabled = true
        if opt:find( "^!" ) then
            opt = opt:sub( 2 )
            enabled = false
        end
        self:set_option( opt, enabled )
    end
end

function Pkgbuild:get_options_string ()
    local opts = {}
    for name, enabled in pairs( self.options ) do
        if not enabled then table.insert( opts, "!" .. name ) end
    end
    return "(" .. table.concat( opts, " " ) .. ")"
end

-- The "distribution directory" is what I call the directory contained in
-- the retrieved tarball.
function Pkgbuild:get_distdir ()
    if self.distdir then return self.distdir end
    return "${pkgname}-${pkgver}"
end

function Pkgbuild:get_preface ()
    local pbtext = ""

    local function gettext ( name )
        local val = self:get_field( name )
        if not val then return end

        local text
        if name == "pkgname" then
            -- pkgname is funky, its usually only explicitly typed as
            -- an array when used in a multipkg
            if type( val ) == "table" and #val == 1 then
                val = val[1]
            end
            text = tobashval( val )
        elseif name == "optdepends" or name == "source" then
            -- Certain arrays are better suited to multiple lines.
            local spaces  = string.rep( " ", #name+2 )

            -- Indent the array elements to lineup properly.
            text = tobashval( val, { arraynl = true } )
            text = text:gsub( "\n", "\n" .. spaces )
        else
            text = tobashval( val )
        end

        return text
    end

    for i, fname in ipairs( Pkgbuild.field_names ) do
        local txt
        if fname == "options" then txt = self:get_options_string()
        else txt = gettext( fname ) end

        if txt then pbtext = pbtext .. fname .. "=" .. txt .. "\n" end
    end

    return pbtext
end

function Pkgbuild:get_func ( funcname )
    local lines = self.funcs[ funcname ]
    if not ( lines and next( self.funcs[ funcname ] )) then return nil end
    local linescopy = { 'cd "${srcdir}/' .. self:get_distdir() .. '"' }
    for i, line in pairs( self.funcs[ funcname ] ) do
        linescopy[ i+1 ] = line
    end
    return linescopy
end

function Pkgbuild:prepend_func ( funcname, ... )
    for i, cmd in ipairs( arg ) do
        table.insert( self.funcs[ funcname ], i, cmd )
    end
end

function Pkgbuild:append_func ( funcname, ... )
    for i, cmd in ipairs( arg ) do
        table.insert( self.funcs[ funcname ], cmd )
    end
end

function Pkgbuild:create_func ( funcname )
    if self.funcs[ funcname ] then
        error( "Function named " .. funcname .. " already exists in PKGBUILD" )
    end

    self.funcs[ funcname ] = {}
end

function Pkgbuild:write_to ( handle )
    handle:write( self:get_preface())
    for i, fname in ipairs( { "build", "check", "package" } ) do
        local cmds = self:get_func( fname )
        if cmds then
            handle:write( "\n" .. fname .. "()\n{\n" )
            for i, cmd in ipairs( cmds ) do
                handle:write( "    " .. tostring(cmd) .. "\n" )
            end
            handle:write( "}\n" )
        end
    end
end

------------------------------------------------------------------------------

SrcPkgDir = {}
SrcPkgDir.__index = SrcPkgDir

function SrcPkgDir:new ()
    return setmetatable( { pkgbuild = Pkgbuild:new() }, self )
end

function SrcPkgDir:build ( parentdir )
    
end
