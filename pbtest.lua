
require "makepb.srcpkg"

local pb = Pkgbuild:new()

pb:set_field( "pkgname", "makepkgbuild-test" )
pb:set_field( "pkgver",  "1.0" )
pb:set_field( "pkgdesc", "Let's test out makepkgbuild's \"Pkgbuild\" class!" )
pb:set_field( "arch",    "any" )
pb:set_field( "url",     "https://github.com/juster/makepkgbuild" )

pb:append_func( "build", "make" )
pb:append_func( "package", 'make DESTDIR="$pkgdir" install' )

pb:write_to( io.stdout )
