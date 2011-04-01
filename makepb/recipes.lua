--[[

recipes.lua

Recipe base classes and recipes for making source packages.

--]]

require "makepb.srcpkg"
require "makepb.cmd"

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
    dsl.append = function ( func, ... )
                     pb:append_func( func, ... )
                 end
    dsl.prepend = function ( func, ... )
                      pb:prepend_func( func, ... )
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
    local parentdsl = RecipeClass.get_dsl( self )
    local dsl = { configure = function ( args )
                                  self.configcmd:push_args( args )
                              end;
                  make = function ( args )
                             self.makecmd:push_args( args )
                         end;
                  make_install = function ( args )
                                     self.makeinstallcmd:push_args( args )
                                 end }
    for k, v in pairs( dsl ) do parentdsl[ k ] = v end
    return parentdsl
end
