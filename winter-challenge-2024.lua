local next_token = string.gmatch(io.read(), "%S+")
local W = tonumber(next_token())
local H = tonumber(next_token())

local OWNER_ME = 1
local OWNER_ENEMY = 0
local OWNER_NA = -1
local DIRS = { "N", "E", "S", "W" }
local MIN_SPORER_UNOBSTRUCTED = W > H and W // 2 or H // 2

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

  two_away = function(self, dx, dy)
    return math.abs(dx) + math.abs(dy) == 2
  end,

  distance_between = function(self, a, b)
    local dx, dy = self:deltas(a, b)
    return math.sqrt(dx * dx + dy * dy)
  end,

  point_to_str = function(self, p)
    return p.x .. "," .. p.y
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
    if x > 0 and y > 0 and x <= W and y <= H then
      return { x = x, y = y }
    end
  end,
}

local function copy_table_and_append(t, a)
  local u = {}
  for _, v in ipairs(t) do
    table.insert(u, v)
  end
  table.insert(u, a)
  return u
end

local function is_protein(typ)
  return #typ == 1 -- A, B, C, D
end

local function is_organ(typ)
  return typ == ROOT or typ == BASIC or typ == TENTACLE or typ == HARVESTER or typ == SPORER
end

local function organ_root_ids(all_things)
  local root_ids = {}
  for _, t in ipairs(all_things) do
    if t.owner == OWNER_ME and t.typ == ROOT then
      table.insert(root_ids, t.id)
    end
  end
  return root_ids
end

local function organs(all_things, root_id, owner)
  owner = owner and owner or OWNER_ME
  local ts = {}
  for _, v in ipairs(all_things) do
    if v.owner == owner and is_organ(v.typ) and v.organ_root_id == root_id then
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

local function can_grow_sporer(my_protein_stack)
  return my_protein_stack.B > 0 and my_protein_stack.D > 0
end

local function can_grow_root(my_protein_stack)
  return my_protein_stack.A > 0 and my_protein_stack.B > 0 and my_protein_stack.C > 0 and my_protein_stack.D > 0
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
      if grid:two_away(dx, dy) then
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
      local p = grid:move_point_in_dir(t, t.organ_dir)
      if p and protein.x == p.x and protein.y == p.y then
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
    local p = grid:move_point_in_dir({ x = thing.x, y = thing.y }, dir)
    if p then
      local t = get_thing_at(all_things, p.x, p.y)
      if not t then
        table.insert(cells, { thing = thing, x = p.x, y = p.y })
      end
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
    local p = grid:move_point_in_dir(thing, dir)
    if p then
      if not get_thing_at(all_things, p.x, p.y) then
        grow_from(thing.id, p.x, p.y, BASIC)
        return true
      end
    end
  end
  return false
end

local function count_unobstructed(all_things, cell, dir)
  local c = 0
  local p = { x = cell.x, y = cell.y }
  repeat
    local obstruction = true
    local p2 = grid:move_point_in_dir(p, dir)
    if p2 then
      obstruction = get_thing_at(all_things, p2.x, p2.y)
      if not obstruction then
        p = p2
        c = c + 1
      end
    end
  until obstruction
  return c
end

local function furthest_unobstructed(all_things, t)
  if t.organ_dir == "X" then
    return
  end
  local dir = t.organ_dir
  local p = { x = t.x, y = t.y }
  repeat
    local obstruction = true
    local p2 = grid:move_point_in_dir(p, dir)
    if p2 then
      obstruction = get_thing_at(all_things, p2.x, p2.y)
      if not obstruction then
        p = p2
      end
    end
  until obstruction
  if p.x ~= t.x or p.y ~= t.y then
    return p
  end
end

local function spread_anywhere(all_things, root_id)
  for _, t in ipairs(all_things) do
    if t.owner == OWNER_ME and t.organ_root_id == root_id then
      if spread_adjacent(t, all_things) then
        return true
      end
    end
  end
  return false
end

local function find_path(all_things, p1, p2)
  local stack = { { p1 } }
  local visited = {}
  while #stack > 0 do
    local next = {}
    for _, path in ipairs(stack) do
      local p = path[#path]
      visited[grid:point_to_str(p)] = true
      for _, dir in ipairs(DIRS) do
        local moved_p = grid:move_point_in_dir(p, dir)
        if moved_p then
          local next_p = moved_p
          if next_p.x == p2.x and next_p.y == p2.y then
            debug("path from " .. p1.x .. "," .. p1.y .. " to " .. p2.x .. "," .. p2.y .. " found of length " .. #path)
            return copy_table_and_append(path, next_p)
          end
          if not get_thing_at(all_things, next_p.x, next_p.y) and not visited[grid:point_to_str(next_p)] then
            table.insert(next, copy_table_and_append(path, next_p))
          end
        end
      end
    end
    stack = next
  end
  debug("path from " .. p1.x .. "," .. p1.y .. " not found")
end

local function empty_growable_cells(all_things, root_id)
  local empty_cells = {}
  for _, t in ipairs(all_things) do
    if t.owner == OWNER_ME and t.organ_root_id == root_id then
      for _, v in ipairs(empty_cells_adjacent_to(all_things, t)) do
        table.insert(empty_cells, v)
      end
    end
  end
  return empty_cells
end

local function grow_towards_closest_protein(my_protein_stack, all_things, root_id)
  local distance, pair = closest_protein(empty_growable_cells(all_things, root_id), all_things)
  if distance and pair and not is_being_harvested(all_things, pair.to) then
    debug(
      "closest protein from id "
        .. pair.from.thing.id
        .. ", type "
        .. pair.from.thing.typ
        .. " is at "
        .. pair.to.x
        .. ","
        .. pair.to.y
    )
    local path = find_path(
      all_things,
      { x = pair.from.thing.x, y = pair.from.thing.y },
      { x = pair.to.x, y = pair.to.y }
    )
    if path then
      local dir = get_harvester_direction(all_things, pair.from.thing.x, pair.from.thing.y)
      if dir and can_grow_harvester(my_protein_stack) then
        --grow_from(pair.from.thing.id, pair.to.x, pair.to.y, HARVESTER, dir)
        grow_from(pair.from.thing.id, path[2].x, path[2].y, HARVESTER, dir)
        return true
      elseif can_grow_basic(my_protein_stack) then
        --grow_from(pair.from.thing.id, pair.to.x, pair.to.y, BASIC)
        grow_from(pair.from.thing.id, path[2].x, path[2].y, BASIC)
        return true
      end
    end
  end
  return false
end

local function grow_towards_closest_enemy(my_protein_stack, all_things, root_id)
  local distance, pair = closest_enemy(empty_growable_cells(all_things, root_id), all_things)
  if distance and pair then
    debug(
      "closest enemy from id "
        .. pair.from.thing.id
        .. ", type "
        .. pair.from.thing.typ
        .. " is at "
        .. pair.to.x
        .. ","
        .. pair.to.y
    )
    local path = find_path(
      all_things,
      { x = pair.from.thing.x, y = pair.from.thing.y },
      { x = pair.to.x, y = pair.to.y }
    )
    if path then
      if can_grow_basic(my_protein_stack) then
        --grow_from(pair.from.thing.id, pair.to.x, pair.to.y, BASIC)
        grow_from(pair.from.thing.id, path[2].x, path[2].y, BASIC)
        return true
      end
    end
  end
  return false
end

local function grow_sporer(all_things, root_id)
  local ts = organs(all_things, root_id)
  for _, t in ipairs(ts) do
    if t.owner == OWNER_ME and t.typ == SPORER then
      return false
    end
  end
  local id, p, dir
  local max = MIN_SPORER_UNOBSTRUCTED - 1
  for _, t in ipairs(ts) do
    -- from each of the (up to) 4 adjacent empty cells, where could a sporer fire in a minimally long line?
    for _, empty_cell in ipairs(empty_cells_adjacent_to(all_things, t)) do
      for _, direction in ipairs(DIRS) do
        local l = count_unobstructed(all_things, empty_cell, direction)
        if l > max then
          id = t.id
          p = empty_cell
          dir = direction
          max = l
        end
      end
    end
  end
  if id and p and dir then
    grow_from(id, p.x, p.y, SPORER, dir)
    return true
  end
  return false
end

local function fire_spore(all_things, root_id)
  local ts = organs(all_things, root_id)
  for _, t in ipairs(ts) do
    if t.owner == OWNER_ME and t.typ == SPORER then
      local p = furthest_unobstructed(all_things, t)
      if p then
        local u = {
          "SPORE",
          t.id,
          p.x,
          p.y,
        }
        print(table.concat(u, " "))
        return true
      end
    end
  end
  return false
end

while true do
  local all_things = parse()
  local my_protein_stack, enemy_protein_stack = protein_stacks()
  local required_instr_count = tonumber(io.read())
  local root_ids = organ_root_ids(all_things)
  assert(required_instr_count == #root_ids)

  for _, root_id in ipairs(root_ids) do
    local instr_sent = false

    -- create a sporer
    if not instr_sent and can_grow_sporer(my_protein_stack) then
      debug("calling grow_sporer")
      instr_sent = grow_sporer(all_things, root_id)
    end

    -- fire a spore
    if not instr_sent and can_grow_root(my_protein_stack) then
      debug("calling fire_spore")
      instr_sent = fire_spore(all_things, root_id)
    end

    -- grow towards closest protein, maybe planting a harvester
    if not instr_sent and (can_grow_basic(my_protein_stack) or can_grow_harvester(my_protein_stack)) then
      debug("calling grow_towards_closest_protein")
      instr_sent = grow_towards_closest_protein(my_protein_stack, all_things, root_id)
    end

    -- grow towards closest enemy, maybe planting a tentacle
    if not instr_sent and (can_grow_basic(my_protein_stack) or can_grow_tentacle(my_protein_stack)) then
      debug("calling grow_towards_closest_enemy")
      instr_sent = grow_towards_closest_enemy(my_protein_stack, all_things, root_id)
    end

    -- spread anywhere
    if not instr_sent and can_grow_basic(my_protein_stack) then
      debug("calling spread_anywhere")
      instr_sent = spread_anywhere(all_things, root_id)
    end

    if not instr_sent then
      print("WAIT")
    end
  end
end
