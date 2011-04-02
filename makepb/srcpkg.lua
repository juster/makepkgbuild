--[[

srcpkg.lua

An abstract representation of a source package. Includes other classes
for representing PKGBUILDs and other lesser source package files.

--]]

local function tobashval ( val, opts )
    opts = opts or {}

    local valt = type( val )
    if valt == "table" then
        local array = {}
        for i, elem in ipairs( val ) do
            if type( elem ) == "table" then
                error( "Cannot convert nested tables into a bash expression" )
            end
            array[ i ] = tobashval( elem )
        end

        local sep = opts.arraynl and "\n" or " "
        return "(" .. table.concat( array, sep ) .. ")"
    elseif valt == "string" then
        if val:match( "%s" ) then
            -- If a space is in the string, then we need to quote the string.
            if val:find( "['$]" ) then
                -- We use double-quotes if a value contains single-quotes.
                val = val:gsub( "\\", "\\\\" )
                val = val:gsub( '(["$`])', '\\%1' ) -- escape stuff
                return '"' .. val .. '"'
            else
                -- We use single quotes for everything else, it's easier.
                return "'" .. val .. "'"
            end
        else
            return val
        end
    elseif valt == "integer" then
        tostring( val )
    else
        error( "Cannot convert a " .. valt .. " into a bash expression" )
    end
end

Pkgbuild = {}
Pkgbuild.__index = Pkgbuild

Pkgbuild.field_names = { "pkgname", "pkgver", "pkgrel", "epoch",
                         "pkgdesc", "arch", "url", "license", "install",
                         "changelog", "noextract", "groups",
                         "backup", "depends", "makedepends",
                         "checkdepends", "optdepends", "conflicts",
                         "provides", "replaces", "source" }

function Pkgbuild:new ()
    return setmetatable( { fields  = {};
                           destdir = {};
                           funcs   = { build   = {};
                                       check   = {};
                                       package = {} }}, self )
end

local PB_STRFIELDS = { pkgver = true, pkgrel = true,
                       pkgdesc = true, epoch = true, url = true,
                       install = true, changelog = true }

local PB_ARRFIELDS = {}
for i, name in ipairs({ "pkgname", "license", "source", "arch", "backup",
                        "depends", "makedepends", "checkdepends", "optdepends",
                        "groups", "conflicts", "provides", "replaces" }) do
    PB_ARRFIELDS[ name ] = true
end

function Pkgbuild:set_field ( name, val )
    if PB_STRFIELDS[ name ] then
        if type( val ) ~= "string" then
            error( name .. " is a string field and must be set with a string" )
        end
    elseif PB_ARRFIELDS[ name ] then
        if type( val ) == "string" then
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
        local txt = gettext( fname )
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
