

module( "makepb.bash", function ( mod )
                           mod.type     = type
                           mod.tostring = tostring
                           mod.ipairs   = ipairs
                           mod.table    = table
                           mod.string   = stirng
                       end )

function tobashval ( val, opts )
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
    elseif valt == "number" then
        return tostring( val )
    else
        error( "Cannot convert a " .. valt .. " into a bash expression" )
    end
end

