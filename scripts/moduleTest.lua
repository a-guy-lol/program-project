-- This script lives on a web server (e.g., GitHub)
local MathLib = {}

-- A function within the library that takes parameters
function MathLib:AddNumbers(a, b)
    local result = a + b
    print("Module: Adding " .. a .. " + " .. b .. " = " .. result)
    return result
end

-- Another function to calculate area
function MathLib:CalculateArea(length, width)
    local area = length * width
    print("Module: Area is " .. area)
    return area
end

-- CRITICAL: The script must return the table so the loader can use it
return MathLib
