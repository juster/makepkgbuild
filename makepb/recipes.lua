--[[

recipes.lua

Recipe base classes and recipes for making source packages.

--]]

require "makepb.srcpkg"
require "makepb.cmd"

local function merge_left ( left, right )
    for k, v in pairs( right ) do left[k] = v end
    return left
end

RecipeClass = {}
RecipeClass.__index = RecipeClass

function RecipeClass:new ( srcpkg )
    return setmetatable( { src = srcpkg }, self )
end

function RecipeClass:init ()
    error( "You should override init in your recipe sub-class" )
end

function RecipeClass:get_dsl ()
    local dsl = {}
    local pb  = self.src.pkgbuild
    dsl.append = function ( tbl )
                     for funcname, cmd in pairs( tbl ) do
                         if type( cmd ) == "table" then
                             pb:append_func( funcname, unpack( cmd ))
                         else
                             pb:append_func( funcname, cmd )
                         end
                     end
                 end
    dsl.prepend = function ( tbl )
                     for funcname, cmd in pairs( tbl ) do
                         if type( cmd ) == "table" then
                             pb:prepend_func( funcname, unpack( cmd ))
                         else
                             pb:prepend_func( funcname, cmd )
                         end
                     end
                 end
    return dsl
end

------------------------------------------------------------------------------

AutotoolsClass = RecipeClass:new()
AutotoolsClass.__index = AutotoolsClass

function AutotoolsClass:init ()
    self.makecmd        = Cmd:new( "make" )
    self.makeinstallcmd = Cmd:new( "make" )
    self.makeinstallcmd:push_args { "install", 'DESTDIR="$pkgdir"' }

    self.configcmd = Cmd:new( "./configure" )
    self.configcmd:push_args { prefix = "/usr" }

    -- We keep a reference to commands in case we want to modify these
    -- later. Their position is reserved even if they are modified.
    self.src.pkgbuild:prepend_func( "build",   self.configcmd, self.makecmd )
    self.src.pkgbuild:prepend_func( "package", self.makeinstallcmd )
    
end

function AutotoolsClass:get_dsl ()
    local dsl = { configure = function ( args )
                                  self.configcmd:push_args( args )
                              end;
                  make = function ( args )
                             self.makecmd:push_args( args )
                         end;
                  make_install = function ( args )
                                     self.makeinstallcmd:push_args( args )
                                 end }

    return merge_left( RecipeClass.get_dsl( self ), dsl )
end

------------------------------------------------------------------------------

RecipeLoader = {}
RecipeLoader.__index = RecipeLoader

RecipeLoader.imports = { "assert", "error", "ipairs", "next", "pairs",
                         "pcall", "print", "select", "tonumber",
                         "tostring", "type", "unpack", "xpcall",
                         "string", "table", "math" }

function RecipeLoader:new ( recipe_path )
    return setmetatable( { path          = recipe_path;
                           env           = nil;
                           classes       = {};
                           active_class  = nil;
                           class_imports = {} }, self )
end

function RecipeLoader:allow_classes ( namemap )
    for name, tbl in pairs( namemap ) do
        self.classes[ name ] = tbl -- copies the table
    end
end

function RecipeLoader:prepare_env ( srcpkg )
    local env = {}
    for i, fname in ipairs( RecipeLoader.imports ) do
        env[ fname ] = _G[ fname ]
    end

    local function set_recipe_class ( name )
        local classtbl = self.classes[ name ]
        if not classtbl then
            error( name .. " is not a valid recipe class" )
        end
        self.active_class = classtbl:new( srcpkg )
        self.active_class:init()

        -- Load the recipe class's DSL for use in the recipe
        self.class_imports = self.active_class:get_dsl()
    end
    env.use = set_recipe_class

    -- Storing of values into PKGBUILD fields is always permitted.
    -- No recipe class is required.
    local field_accessors = { name = "pkgname"; version = "pkgver";
                              desc = "pkgdesc"; release = "pkgrel"; }
    for i, field in ipairs( srcpkg.pkgbuild.field_names ) do
        if not field:find( "^pkg" ) then
            field_accessors[ field ] = field
        end
    end

    -- Helper functions corresponding to the recipe DSL.
    local function get_pbfield ( name )
        local field_name = field_accessors[ name ]
        if field_name then
            return srcpkg.pkgbuild:get_field( field_name )
        end
        -- XXX: differentiate between unset and unknown fields?
    end

    local function expand_string ( str )
        local function expander ( block )
            local name = block:sub( 2, #block-1 )
            local val  = get_pbfield( name )
            if not val then
                error( "Unknown or unset variable '" .. name .. "'", 6 )
            end

            if type( val ) == "table" then val = val[1] end
            return val
        end
        str = string.gsub( str, "#(%b{})", expander )
        return str
    end

    local function set_pbfield ( name, val )
        local field_name = field_accessors[ name ]
        if not field_name then return false end

        if type( val ) == "string" then val = expand_string( val ) end
        srcpkg.pkgbuild:set_field( field_name, val )
        return true
    end

    -- We must use __index and __newindex in order to use class-exported
    -- DSL names. setmetatable() uses the value of env only at the time
    -- it is passed to setmetatable(). To change the behavior of imports
    -- after the fact, we must use these functions.

    -- Called when a function/variable was not found.
    env.__index
        = function ( tbl, name )
              local func = self.class_imports[ name ]
              if func then return func end

              local field = get_pbfield( name )
              if field then return field end

              error( name .. " is not defined.\n"
                     .. "Did you remember to specify a PKGBUILD class?" )
          end

    -- Called when trying to create a new global variable/function.
    env.__newindex
        = function ( tbl, name, arg )
              if set_pbfield( name, arg ) then return end
              error( "Unknown package variable '" .. name .. "'" )
          end

    setmetatable( env, env )

    self.env = env
    return env
end

function RecipeLoader:run_recipe ( srcpkg )
    local recipe_env  = self:prepare_env( srcpkg )
    local recipe, err = loadfile( self.path )
    if not recipe then error( err, 0 ) end

    setfenv( recipe, recipe_env )
    local success, err = pcall( recipe )
    if not success then error( err, 0 ) end
end
