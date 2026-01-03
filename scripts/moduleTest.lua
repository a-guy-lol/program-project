
local MathModule = {}

function MathModule.Add(a, b)
	return a + b
end

function MathModule.Multiply(a, b)
	return a * b
end

function MathModule.Power(base, exponent)
	-- simple integer exponent example
	local result = 1
	for _ = 1, exponent do
		result *= base
	end
	return result
end

function MathModule.Stats(numbers)
	-- returns sum and average
	local sum = 0
	for _, n in ipairs(numbers) do
		sum += n
	end
	local avg = (#numbers > 0) and (sum / #numbers) or 0
	return sum, avg
end

return MathModule
