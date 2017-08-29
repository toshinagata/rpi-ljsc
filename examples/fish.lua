package.path = "../ljsc/?.lua;" .. package.path

local sc = require "screen"
local png = require "png"
local util = require "util"
local vg = require "vg"
local term = require "termios"
local js = require "js"
local sdl = require "sdl"
local mix = require "mix"

local devno = nil

function init()
  --  Init screen
  if not sc.init(1, 320, 240) then sc.init(0, 320, 240) end
  bcol = sc.rgb(0.5, 0.5, 1)
  sc.cls(bcol)
  tcolor = sc.rgb(0, 0.4, 0)
  
  --  Init joystick (if not present then use keyboard)
  if js.init() > 0 then
    local j = 0
    while true do
      local dev = js.devinfo(j)
      if dev == nil then break end
      if dev.num_buttons >= 2 and dev.num_axes >= 2 then
        devno = j
        if dev.num_buttons >= 8 then
          break
        end
      end
      j = j + 1
    end
  else
    js = nil
    term.setRawMode()
  end

  dir_x = {1, 0.707, 0, -0.707, -1, -0.707, 0, 0.707 }
  dir_y = {0, 0.707, 1, 0.707, 0, -0.707, -1, -0.707 }
  ofs_x = 48
  ofs_y = 48
  range_x = sc.width + ofs_x * 2
  range_y = sc.height + ofs_y * 2
  
  --  Read character images
  --  0: right, 1: up-right, 2: up, 3: up-left,
  --  4: left, 5: down-left, 6: down, 7: down-right
  for i = 0, 2 do   -- 0: fish, 1: man1, 2: man2
    sc.patpng(i * 8 + 4, string.format("fish/fish%d0.png", i))
    sc.patpng(i * 8 + 3, string.format("fish/fish%d1.png", i))
    w, h, t4 = sc.patget(i * 8 + 4)
    w, h, t3 = sc.patget(i * 8 + 3)
    t0 = flip_horizontal(t4, w, h)
    t1 = flip_horizontal(t3, w, h)
    t2 = rotate_left(t0, w, h)
    t5 = rotate_left(t3, w, h)
    t6 = rotate_left(t4, w, h)
    t7 = flip_horizontal(t5, w, h)
    sc.patdef(i * 8, w, h, t0)
    sc.patdef(i * 8 + 1, w, h, t1)
    sc.patdef(i * 8 + 2, w, h, t2)
    sc.patdef(i * 8 + 5, w, h, t5)
    sc.patdef(i * 8 + 6, w, h, t6)
    sc.patdef(i * 8 + 7, w, h, t7)
  end
  
  sc.patpng(40, "fish/fish40.png")
  sc.patpng(41, "fish/fish41.png")
  sc.patpng(42, "fish/fish42.png")

  NORMAL = 40
  LAUGH = 41
  STONE = 42
  
  sc.patpng(51, "fish/title1.png")
  sc.patpng(52, "fish/title2.png")
  sc.patpng(53, "fish/title3.png")
  sc.patpng(54, "fish/title4.png")
  
  sc.patpng(60, "fish/clear1.png")
  
  --  Initialize audio system and read sounds
  sdl.init(sdl.INIT_AUDIO)
  mix.openAudio(22050, mix.AUDIO_S16, 2, 1024)
  mix.allocateChannels(16)
  chunks = {}
  local t = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 20, 30, 31, 32, 33, 40, 50, 60, 70, 80}
  for i, v in ipairs(t) do
    local fname = string.format("fish/bgm%02d.ogg", v)
    chunks[v] = mix.loadWAV(fname)
    if chunks[v] == nil then
      error("Cannot read " .. fname)
    end
  end

  maxghosts = 1
  
  TYPE_FISH = 1
  TYPE_MAN = 2
  TYPE_GHOST = 3

  chars = {}
  
  running = false
  
end

function rotate_left(t, w, h)
  local t2 = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      t2[x + y * h + 1] = t[(h - 1 - y) + x * h + 1]
    end
  end
  return t2
end

function flip_horizontal(t, w, h)
  local t2 = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      t2[x + y * h + 1] = t[w - 1 - x + y * h + 1]
    end
  end
  return t2
end

function collide(x1, y1, x2, y2, r)
  local x = x2 - x1
  local y = y2 - y1
  if x * x + y * y < r * r then
    local rad = math.floor((math.atan2(y, x) + 3.1416 * (0.75 + (math.random() * 0.5))) * 4 / 3.1416)
    return (rad + 8) % 8
  else
    return -1
  end
end

function initchars()
  local x, y, i, j, x1, y1, limit, tbl
  chars = {}
  tbl = {
    x = sc.width / 2, y = sc.height / 2, direction = 0, pat = 8, speed = 8,
    type = TYPE_MAN
  }
  chars[1] = tbl
  for i = 1, nfish do
    tbl = { type = TYPE_FISH }
    flag = true
    repeat
      x = math.floor(math.random() * (sc.width - 32))
      y = math.floor(math.random() * (sc.height - 48))
      flag = true
      for j = 1, i do
        x1 = chars[j].x
        y1 = chars[j].y
        if j == 1 then limit = 72 else limit = 32 end
        if collide(x, y, x1, y1, limit) >= 0 then
          flag = false
          break
        end
      end
    until flag
    tbl.x = x
    tbl.y = y
    tbl.speed = 3 + i * 2 / nfish
    tbl.direction = math.floor(math.random() * 8)
    tbl.dead = false
    tbl.pat = 0
    tbl.type = TYPE_FISH
    chars[i + 1] = tbl
  end
  for i = 1, maxghosts do
    chars[i + 1 + nfish] = { hidden = true, type = TYPE_GHOST }
  end
end

function eraseone(tbl)
  if not tbl.hidden then
    sc.clearbox(tbl.x, tbl.y, 32, 32, bcol)
  end
end

function erase()
  for i = 1, #chars do
    eraseone(chars[i])
  end
end

function drawone(tbl)
  local pat = tbl.pat
  if tbl.type == TYPE_MAN then
    pat = pat + tbl.direction
    if tbl.dead then
      sc.patdraw(pat, tbl.x, tbl.y, sc.rgba(1, 0, 0, 0.5))
    else
      sc.patdraw(pat, tbl.x, tbl.y)
    end
  elseif tbl.type == TYPE_FISH then
    if tbl.dead then
      pat = STONE
    else
      pat = pat + tbl.direction
    end
    sc.patdraw(pat, tbl.x, tbl.y)
  else
    if not tbl.hidden then
      sc.patdraw(pat, tbl.x, tbl.y)
    end
  end
end

function draw(rem)
  sc.clearbox(0, sc.height - 16, sc.width, 16, sc.rgba(0.5, 0.5, 1, 0.5))
  if rem < 10 then
    sc.tcolor(sc.rgb(1, 1, 1), sc.rgb(1, 0, 0))
  elseif rem < 30 then
    sc.tcolor(tcolor, sc.rgba(1, 1, 0, 0.7))
  end
  sc.gputs(76, sc.height - 16, string.format("Time %3d", rem))
  sc.tcolor(tcolor, 0)
  sc.gputs(4, sc.height - 16, string.format("Scene %2d", scene))
  sc.gputs(148, sc.height - 16, string.format("Score %06d Life %d", score, nlives))
  for i = 1, #chars do
    drawone(chars[i])
  end
end

function proceedone(tbl)
  local x, y, r, x1, y1, limit, dir, tbl1, xmin, xmax, ymin, ymax
  local speed, dx, dy, pat
  x = tbl.x
  y = tbl.y
  dir = tbl.direction
  speed = tbl.speed
  if tbl.dead or tbl.hidden then return end
  xmin = 0
  xmax = sc.width - 32
  ymin = 0
  ymax = sc.height - 48
  x = tbl.x + dir_x[dir + 1] * speed
  y = tbl.y + dir_y[dir + 1] * speed
  if x < xmin or x >= xmax then
    dir = (12 - dir) % 8 -- {0,1,2,3,4,5,6,7}->{4,3,2,1,0,7,6,5}
  end
  if y < ymin or y >= ymax then
    dir = (8 - dir) % 8 -- {0,1,2,3,4,5,6,7}->{0,7,6,5,4,3,2,1}
  end
  for n = 1, #chars do
    tbl1 = chars[n]
    if tbl1 ~= tbl and not tbl1.hidden then
      limit = 32
      if tbl.type == TYPE_FISH and tbl1.type == TYPE_MAN then
        limit = 40
      elseif tbl.type == TYPE_GHOST and tbl1.type == TYPE_MAN then
        limit = 70
      elseif tbl.type ~= TYPE_GHOST and tbl1.type == TYPE_FISH and tbl1.dead then
        limit = 26
      end
      r = collide(x, y, tbl1.x, tbl1.y, limit)
      if r >= 0 then
        if tbl.type == TYPE_MAN then
          if tbl1.type == TYPE_FISH and not tbl1.dead then
            tbl1.dead = true
            tbl1.pat = STONE
            nalive = nalive - 1
            score = score + 10
            mix.playChannel(8, chunks[80], 0)
          elseif tbl1.type == TYPE_GHOST then
            tbl.dead = true
            tbl1.pat = LAUGH
          end
        elseif tbl.type == TYPE_GHOST and tbl1.type == TYPE_MAN then
          tbl.pat = LAUGH
          tbl.speed = 2
          r = (r + 4) % 8 --  Move toward the man
          if collide(x, y, tbl1.x, tbl1.y, 32) >= 0 then
            tbl1.dead = true
          end
        end
        dir = r
        break
      else
        if tbl.type == TYPE_GHOST and tbl1.type == TYPE_MAN then
          tbl.speed = 0.5
          tbl.pat = NORMAL
        end
      end
    end
  end
  if tbl.type == TYPE_GHOST then
    tbl.life = tbl.life - 1
    if tbl.life <= 0 then
      tbl.hidden = true
      local gidx = tbl.index
      local gattr = game_loops[gidx + 2]
      gattr.dead = true
      gattr.finalize(gattr)
    end
  end
  if dir ~= tbl.direction then
    if tbl.type == TYPE_MAN then
      --  Don't change direction unless user explicitly wants
      dir = tbl.direction
      x = tbl.x
      y = tbl.y
    else
      x = tbl.x + dir_x[dir + 1] * speed
      y = tbl.y + dir_y[dir + 1] * speed
    end
  end
  tbl.direction = dir
  ::skip_move::
  tbl.x = x
  tbl.y = y
  if tbl.type == TYPE_MAN then
    tbl.pat = 24 - tbl.pat
  end
end

function proceed()
  for n = 1, #chars do
    proceedone(chars[n])
  end
end

function scankey()
  local start = false
  local d = nil
  if js then
    local dev = js.read_event(devno)
    if dev then
      local val1 = dev.axes[1].value
      local val2 = dev.axes[2].value
      if val1 > 0 then
        if val2 > 0 then
          d = 7
        elseif val2 < 0 then
          d = 1
        else
          d = 0
        end
      elseif val1 < 0 then
        if val2 > 0 then
          d = 5
        elseif val2 < 0 then
          d = 3
        else
          d = 4
        end
      else
        if val2 > 0 then
          d = 6
        elseif val2 < 0 then
          d = 2
        end
      end
      if d then
        chars[1].direction = d
      end
      if dev.buttons[1].value > 0 and dev.buttons[2].value > 0 then
        os.exit()
      elseif (dev.num_buttons >= 8 and dev.buttons[8].value > 0) or dev.buttons[1].value > 0 then
        start = true
      end
    end
  else
    local c = term.realtimeKey()
    c = string.byte(c, 1)
    if c == 100 then -- 'd'
      d = 0
    elseif c == 101 then -- 'e'
      d = 1
    elseif c == 119 then -- 'w'
      d = 2
    elseif c == 113 then -- 'q'
      d = 3
    elseif c == 97 then  -- 'a'
      d = 4
    elseif c == 122 then -- 'z'
      d = 5
    elseif c == 120 then -- 'x'
      d = 6
    elseif c == 99 then  -- 'c'
      d = 7
    elseif c == 32 and not running then  -- ' '
      start = true
    elseif c == 8 or c == 127 and running then -- delete or backspace
      start = true
    end
    if d then
      chars[1].direction = d
    end
  end
  return start
end

function title_loop(attr)
  sc.cls(bcol)
  for n = 1, nfish do
    proceedone(chars[n + 1])
    drawone(chars[n + 1])
  end
  sc.patdraw(51, 0, 130)
  sc.patdraw(52, 75, 100)
  if js then
    sc.patdraw(53, 66, 32)
  else
    sc.patdraw(54, 66, 32)
  end
  sc.flush()
  if scankey() then
    return true
  else
    return false
  end
end

function title_music_loop(attr)
  if mix.playChannel(0, chunks[60], 0) ~= 0 then
    print("Error in Mix_PLayChannel()")
  end
  return false
end


function handle_loops(loops)
  local tstart = util.now()
  while true do
    local attr = nil
    for n = 1, #loops do
      --  Look for the earliest event
      local nattr = loops[n]
      if not nattr.dead then
        if nattr.tnext == nil then
          nattr.tnext = 0
        end
        if attr == nil or attr.tnext > nattr.tnext then
          attr = nattr
        end
      end
    end
    if attr == nil then
      --  All events are dead
      return
    end
    --  Wait if it is too early
    local tnow = util.now() - tstart
    if tnow < attr.tnext then
      util.sleep(attr.tnext - tnow)
    end
    if attr.func(attr, tnow) then
      attr.dead = true
      if attr.finalize then
        attr.finalize(attr, tnow)
      end
    end
    attr.tnext = attr.tnext + attr.interval
  end
end

function title()
  nfish = 6
  initchars()
  title_loops = {
    { interval = 0.05, func = title_loop,
      finalize = function(attr)
        title_loops[2].dead = true
        mix.haltChannel(0)
      end
    },
    { interval = 44, func = title_music_loop }
  }
  handle_loops(title_loops)
end

function ghost_music_loop(attr)
  mix.playChannel(attr.channel, chunks[attr.chidx], 0)
  if chars[attr.idx + 1 + nfish].pat == LAUGH then
    attr.interval = 0.15
  else
    attr.interval = 0.3
  end
  return false
end

function gen_ghost()
  local gtbl, gidx
  for n = 1, maxghosts do
    if chars[n + 1 + nfish].hidden then
      gidx = n
      gtbl = chars[gidx + 1 + nfish]
      gtbl.index = gidx
      break
    end
  end
  if gtbl == nil then return end
  local manx = chars[1].x
  local many = chars[1].y
  while true do
    local x = math.random() * (sc.width - 32)
    local y = math.random() * (sc.height - 48)
    if collide(x, y, manx, many, 80) < 0 then
      gtbl.x = math.floor(x)
      gtbl.y = math.floor(y)
      gtbl.direction = math.floor(math.random() * 8)
      gtbl.speed = 1
      gtbl.life = math.floor(math.random() * 150) + 200
      gtbl.hidden = false
      gtbl.type = TYPE_GHOST
      gtbl.pat = 40
      break
    end
  end
  game_loops[gidx + 2] = {
    interval = 0.3, idx = gidx, channel = gidx + 3, chidx = gidx + 29,
    func = ghost_music_loop,
    finalize = function(attr)
      mix.haltChannel(attr.channel)
    end
  }
end

function game_loop(attr, tnow)
  local limit = 120
  remtime = limit - tnow
  if remtime <= 0 then
    chars[1].dead = true
  end
  if math.random() < 0.01 then
    gen_ghost()
  end
  erase()
  proceed()
  if scankey() then
    chars[1].dead = true
  end
  draw(remtime)
  sc.flush()
  if chars[1].dead then
    nlives = nlives - 1
    return true
  elseif nalive <= 0 then
    if remtime > 0 then
      score = score + math.floor(remtime) * 10
    end
    return true
  end
  return false
end

function game_music_loop(attr)
  local ch = attr.count % 4
  local n
  if attr.count < 42 then
    n = 1
  else
    n = math.floor((attr.count - 37) / 5)
  end
  attr.interval = 240.0/(180.0 + (n - 1) * 8)
  mix.playChannel(ch, chunks[n], 0)
  attr.count = attr.count + 1
  return false
end

function game()
  nfish = 8
  nalive = nfish
  sc.tcolor(tcolor, 0)
  initchars()
  sc.cls(bcol)
  draw(120)
  sc.flush()
  mix.playChannel(0, chunks[20], 0)
  mix.waitWhilePlaying(0)
  sc.cls(bcol)
  game_loops = {
    { interval = 0.05, func = game_loop,
      finalize = function(attr)
        for i = 2, #game_loops do
          local lattr = game_loops[i]
          if not lattr.dead then
            lattr.dead = true
            if lattr.finalize then
              lattr.finalize(lattr)
            end
          end
        end
        if chars[1].dead then
          mix.playChannel(0, chunks[70], 0)
        else
          mix.playChannel(0, chunks[40], 0)
        end
        mix.waitWhilePlaying(0)
      end
    },
    { interval = 1.333, func = game_music_loop, count = 0,
      finalize = function(attr)
        for i = 0, 3 do
          mix.haltChannel(i)
        end
      end
    }
  }
  handle_loops(game_loops)
end

function pomp_loop(attr)
  local dx = (sc.width - 64) / 2 / 18
  local count = attr.count
  local n, x, dir, dir2
  attr.count = count + 1
  if count < 20 then
    n = math.floor(count / 2)
    x = dx * n
    dir = 0
    if n == 3 or n == 7 then
      dir = 3
    end
  elseif count < 24 then
    x = dx * (10 + count - 20)
    if count == 20 or count == 22 then
      dir = 0
    elseif count == 21 then
      dir = 1
    else
      dir = 7
    end
  elseif count < 28 then
    x = dx * (14 + math.floor((count - 24) / 2))
    if count < 26 then
      dir = 0
    else
      dir = 3
    end
  elseif count < 36 then
    x = dx * (16 + math.floor((count - 28) / 4))
    if count < 32 then
      dir = 0
    else
      dir = 7
    end
  else
    return true
  end
  dir2 = (12 - dir) % 8
  chars[1].x = x
  chars[2].x = x
  chars[3].x = x - 48
  chars[4].x = x - 48
  chars[5].x = sc.width - 32 - x
  chars[6].x = chars[5].x
  chars[7].x = chars[5].x + 48
  chars[8].x = chars[7].x
  for i = 1, 4 do
    chars[i].direction = dir
    chars[i + 4].direction = dir2
  end
  sc.cls(bcol)
  sc.patdraw(60, 45, 140)
  draw(remtime)
  sc.flush()
  
  return false
end

function pomp()
  mix.playChannel(0, chunks[50], 0)
  chars = {}
  for i = 1, 8 do
    chars[i] = { pat = 0, type = TYPE_FISH, y = 30 + 80 * (i % 2) }
  end
  pomp_loops = {
    { interval = 0.25, func = pomp_loop, count = 0 }
  }
  handle_loops(pomp_loops)
  score = score + 1000
end

init()
while true do
  title()
  nlives = 3
  score = 0
  scene = 1
  while nlives > 0 do
    maxghosts = math.floor((scene - 1) / 5) + 1
    game()
    if nalive <= 0 then
      if scene % 5 == 0 then
        pomp()
      end
      scene = scene + 1
    end
  end
  util.sleep(1.0)
end
