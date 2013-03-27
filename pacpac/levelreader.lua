-- levelreader.lua
--
-- Interface for loading level data (aka maps) from files.
-- This doesn't really have to be a separate module, but I felt like pulling
-- out this functionality.
--
-- Meant to be used as:
--   local levelreader = require('levelreader')
--   local level = levelreader.read('level1.txt')
--
-- The output has the following form:
--   level = { m = << 2d array of sprite layout by (x,y) coords >>,
--             start_pos = << start positions of characters >>,
--             superdots = << positions of superdots >>,
--             ghost_hotel = << hotel position info >>,
--             wall_color = {r = red, g = green, b = blue}
--           }
--


local M = {}


-------------------------------------------------------------------------------
-- Public interface.
-------------------------------------------------------------------------------

-- Read level info from a file.
function M.read(filename)
  local section = nil
  local level = { map = {}, superdots = {}, start_pos = {}, ghost_hotel = {} }
  for line in love.filesystem.lines(filename) do
    -- Skip over lines starting with #, which has ascii code 35.
    if line:byte() ~= 35 then
      if #line == 0 then
        section = nil
      elseif section == 'map' then
        for i = 1, #line do
          if level.map[i] == nil then level.map[i] = {} end
          table.insert(level.map[i], tonumber(line:sub(i, i)))
        end
      elseif section == 'superdots' then
        for x, y in string.gmatch(line, '([%d%.]+),%s*([%d%.]+)') do
          table.insert(level.superdots, {x, y})
        end
      elseif section == 'start_pos' then
        for color, x, y in string.gmatch(line, '(%w+).-(%d+).-(%d+)') do
          level.start_pos[color] = {x + 0.5, y + 0.5}
        end
      elseif section == 'ghost_hotel' then
        for pos, x, y in string.gmatch(line, '(%w+).-(%d+).-(%d+)') do
          level.ghost_hotel[pos] = {x + 0.5, y + 0.5}
        end
      elseif section == 'wall_color' then
        local r, g, b = string.match(line, '(%d+)%s+(%d+)%s+(%d+)')
        level.wall_color = {r = r, g = g, b = b}
      elseif section == nil then
        section = line:sub(1, #line - 1)
      end
    end
  end
  return level
end


return M

