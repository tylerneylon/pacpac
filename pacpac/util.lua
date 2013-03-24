-- util.lua
--
-- A collection of generally useful functions.
--


local M = {}

local function is_pos_int(n)
  return type(n) == "number" and n > 0 and math.floor(n) == n
end

local function is_array(array)
  local max, n = 0, 0
  for k, _ in pairs(array) do
    if not is_pos_int(k) then return false end
    max = math.max(max, k)
    n = n + 1
  end
  return n == max
end

function M.str(t)
  if type(t) == 'table' then
    local s = '{'
    if is_array(t) then
      for i, v in ipairs(t) do
        if #s > 1 then s = s .. ', ' end
        s = s .. M.str(v)
      end
    else
      -- It's a non-array table.
      for k, v in pairs(t) do
        if #s > 1 then s = s .. ', ' end
        s = s .. M.str(k)
        s = s .. ' = '
        s = s .. M.str(v)
      end
    end
    s = s .. '}'
    return s
  elseif type(t) == 'number' then
    return tostring(t)
  elseif type(t) == 'boolean' then
    return tostring(t)
  elseif type(t) == 'string' then
    return t
  end
  return 'unknown type'
end

-- Turns {a, b} into {[str(a)] = a, [str(b)] = b}.
-- This is useful for testing if hash[key] for inclusion.
function M.hash_from_list(list)
  local hash = {}
  for k, v in pairs(list) do hash[M.str(v)] = v end
  return hash
end



return M
