-- draw.lua
--
-- PacPac functions to wrap low-level love.graphics functions.
--

local M = {}

-- Maps nonnegative reals to [0, 1].
local function lightning_taper(x)
  return math.exp(-5 * x)
end

function M.setColor(r, g, b, a, opts)
  if level_num == 3 then
    local m = 1.0
    if last_lightning ~= nil then
      m = 1.0 - lightning_taper(clock - last_lightning)
    end
    if opts and opts.is_wall then m = 1.0 - m end
    if opts and opts.is_live then m = 1.0 end
    r = math.floor(r * m)
    g = math.floor(g * m)
    b = math.floor(b * m)
  end
  love.graphics.setColor(r, g, b, a)
end

return M
