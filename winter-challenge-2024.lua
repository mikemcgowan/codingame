local next_token = string.gmatch(io.read(), "%S+")
local W = tonumber(next_token())
local H = tonumber(next_token())

local OWNER_ME = 1
local OWNER_ENEMY = 0
local OWNER_NA = -1
local DIRS = { "N", "E", "S", "W" }

local WALL = "WALL"
local ROOT = "ROOT"
local BASIC = "BASIC"
local TENTACLE = "TENTACLE"
local HARVESTER = "HARVESTER"
local SPORER = "SPORER"

local function debug(s)
  s = s and s or ""
  io.stderr:write(s .. "\n")
end

local grid = {
  deltas = function(self, a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx, dy
  end,

  adjacent = function(self, dx, dy)
    return math.abs(dx) == 1 and math.abs(dy) == 0 or math.abs(dx) == 0 and math.abs(dy) == 1
  end,

  distance_between = function(self, a, b)
    local dx, dy = self:deltas(a, b)
    return math.sqrt(dx * dx + dy * dy)
  end,

  dir_from_deltas = function(self, dx, dy)
    local dir
    if dx > 0 then
      dir = "E"
    elseif dx < 0 then
      dir = "W"
    elseif dy > 0 then
      dir = "S"
    elseif dy < 0 then
      dir = "N"
    end
    return dir
  end,

  move_point_in_dir = function(self, p, dir)
    local x, y = p.x, p.y
    if dir == "N" then
      y = y - 1
    elseif dir == "E" then
      x = x + 1
    elseif dir == "S" then
      y = y + 1
    elseif dir == "W" then
      x = x - 1
    end
    return x, y
  end,
}

local function is_protein(typ)
  return #typ == 1 -- A, B, C, D
end

local function is_organ(typ)
  return typ == ROOT or typ == BASIC or typ == TENTACLE or typ == HARVESTER or typ == SPORER
end

local function organs(all_things, owner)
  owner = owner and owner or OWNER_ME
  local ts = {}
  for _, v in ipairs(all_things) do
    if v.owner == owner and is_organ(v.typ) then
      table.insert(ts, v)
    end
  end
  return ts
end

local function proteins(all_things)
  local ts = {}
  for _, v in ipairs(all_things) do
    if is_protein(v.typ) then
      table.insert(ts, v)
    end
  end
  return ts
end

local function enemies(all_things)
  local ts = {}
  for _, v in ipairs(all_things) do
    if v.owner == OWNER_ENEMY then
      table.insert(ts, v)
    end
  end
  return ts
end

local function can_grow_basic(my_protein_stack)
  return my_protein_stack.A > 0
end

local function can_grow_harvester(my_protein_stack)
  return my_protein_stack.C > 0 and my_protein_stack.D > 0
end

local function can_grow_tentacle(my_protein_stack)
  return my_protein_stack.B > 0 and my_protein_stack.C > 0
end

local function closest_thing(thing, things)
  local distance
  local closest
  for _, t in ipairs(things) do
    local d = grid:distance_between(t, thing)
    if not distance or d < distance then
      distance = d
      closest = t
    end
  end
  return distance, closest
end

local function closest_pair(xs, ys)
  local distance
  local closest
  for _, x in ipairs(xs) do
    for _, y in ipairs(ys) do
      local d = grid:distance_between(x, y)
      if not distance or d < distance then
        distance = d
        closest = { from = x, to = y }
      end
    end
  end
  return distance, closest
end

local function closest_protein(cells, all_things)
  return closest_pair(cells, proteins(all_things))
end

local function closest_enemy(cells, all_things)
  return closest_pair(cells, enemies(all_things))
end

local function get_harvester_direction(all_things, next_x, next_y)
  for _, v in ipairs(all_things) do
    if is_protein(v.typ) then
      local dx, dy = grid:deltas(v, { x = next_x, y = next_y })
      if grid:adjacent(dx, dy) then
        local dir = grid:dir_from_deltas(dx, dy)
        if dir then
          return dir
        end
      end
    end
  end
end

local function parse()
  local entityCount = tonumber(io.read())
  local all_things = {}
  for _ = 1, entityCount do
    next_token = string.gmatch(io.read(), "%S+")
    local x = tonumber(next_token())
    local y = tonumber(next_token())
    local typ = next_token() -- WALL, ROOT, BASIC, TENTACLE, HARVESTER, SPORER, A, B, C, D
    local owner = tonumber(next_token()) -- 1 if your organ, 0 if enemy organ, -1 if neither
    local organ_id = tonumber(next_token()) -- id of this entity if it's an organ, 0 otherwise
    local organ_dir = next_token() -- N, E, S, W or X if not an organ
    local organ_parent_id = tonumber(next_token())
    local organ_root_id = tonumber(next_token())
    table.insert(all_things, {
      id = organ_id,
      x = x,
      y = y,
      typ = typ,
      owner = owner,
      organ_dir = organ_dir,
      organ_parent_id = organ_parent_id,
      organ_root_id = organ_root_id,
    })
  end
  return all_things
end

local function protein_stacks()
  next_token = string.gmatch(io.read(), "%S+")
  local myA = tonumber(next_token())
  local myB = tonumber(next_token())
  local myC = tonumber(next_token())
  local myD = tonumber(next_token())
  next_token = string.gmatch(io.read(), "%S+")
  local enA = tonumber(next_token())
  local enB = tonumber(next_token())
  local enC = tonumber(next_token())
  local enD = tonumber(next_token())
  return { A = myA, B = myB, C = myC, D = myD }, { A = enA, B = enB, C = enC, D = enD }
end

local function is_being_harvested(all_things, protein)
  for _, t in ipairs(all_things) do
    if t.typ == HARVESTER and t.owner == OWNER_ME then
      local x, y = grid:move_point_in_dir(t, t.organ_dir)
      if protein.x == x and protein.y == y then
        return true
      end
    end
  end
  return false
end

local function get_thing_at(all_things, x, y)
  for _, t in ipairs(all_things) do
    if t.x == x and t.y == y then
      return t
    end
  end
end

local function empty_cells_adjacent_to(all_things, thing)
  local cells = {}
  for _, dir in ipairs(DIRS) do
    local x2, y2 = grid:move_point_in_dir({ x = thing.x, y = thing.y }, dir)
    local t = get_thing_at(all_things, x2, y2)
    if not t then
      table.insert(cells, { thing = thing, x = x2, y = y2 })
    end
  end
  return cells
end

local function grow_from(id, x, y, typ, extra)
  local t = {
    "GROW",
    id,
    x,
    y,
    typ,
  }
  if extra then
    t[#t + 1] = extra
  end
  print(table.concat(t, " "))
end

local function spread_adjacent(thing, all_things)
  for _, dir in ipairs(DIRS) do
    local x, y = grid:move_point_in_dir(thing, dir)
    if not get_thing_at(all_things, x, y) then
      debug("spread_adjacent(): there's nothing at " .. x .. "," .. y .. " so growing from there")
      grow_from(thing.id, x, y, BASIC)
      return true
    end
  end
  return false
end

local function spread_anywhere(all_things)
  for _, t in ipairs(all_things) do
    if t.owner == OWNER_ME then
      if spread_adjacent(t, all_things) then
        return true
      end
    end
  end
  return false
end

local function empty_growable_cells(all_things)
  local empty_cells = {}
  for _, t in ipairs(all_things) do
    if t.owner == OWNER_ME then
      for _, v in ipairs(empty_cells_adjacent_to(all_things, t)) do
        table.insert(empty_cells, v)
      end
    end
  end
  return empty_cells
end

local function grow_towards_closest_protein(my_protein_stack, all_things)
  local distance, pair = closest_protein(empty_growable_cells(all_things), all_things)
  if distance and pair and not is_being_harvested(all_things, pair.to) then
    debug("closest protein is at " .. pair.to.x .. "," .. pair.to.y)
    local dir = get_harvester_direction(all_things, pair.to.x, pair.to.y)
    if dir and can_grow_harvester(my_protein_stack) then
      grow_from(pair.from.thing.id, pair.to.x, pair.to.y, HARVESTER, dir)
      return true
    elseif can_grow_basic(my_protein_stack) then
      grow_from(pair.from.thing.id, pair.to.x, pair.to.y, BASIC)
      return true
    end
  end
  return false
end

local function grow_towards_closest_enemy(my_protein_stack, all_things)
  local distance, pair = closest_enemy(empty_growable_cells(all_things), all_things)
  if distance and pair then
    debug("closest enemy is at " .. pair.to.x .. "," .. pair.to.y)
    if can_grow_basic(my_protein_stack) then
      grow_from(pair.from.thing.id, pair.to.x, pair.to.y, BASIC)
      return true
    end
  end
  return false
end

while true do
  local instr_sent = false
  local all_things = parse()
  local my_protein_stack, enemy_protein_stack = protein_stacks()
  local requiredActionsCount = tonumber(io.read())

  -- grow towards closest protein, maybe planting a harvester
  if not instr_sent and (can_grow_basic(my_protein_stack) or can_grow_harvester(my_protein_stack)) then
    debug("calling grow_towards_closest_protein")
    instr_sent = grow_towards_closest_protein(my_protein_stack, all_things)
  end

  -- grow towards closest enemy, maybe planting a tentacle
  if not instr_sent and (can_grow_basic(my_protein_stack) or can_grow_tentacle(my_protein_stack)) then
    debug("calling grow_towards_closest_enemy")
    instr_sent = grow_towards_closest_enemy(my_protein_stack, all_things)
  end

  -- spread anywhere
  if not instr_sent and can_grow_basic(my_protein_stack) then
    debug("calling spread_anywhere")
    instr_sent = spread_anywhere(all_things)
  end

  if not instr_sent then
    print("WAIT")
  end
end
