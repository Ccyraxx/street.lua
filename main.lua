-- STREET DUEL para o console Lupi: luta 2D, 4 lutadores, melhor de 3.
-- 1 jogador contra o computador (fg_bot) ou 2 jogadores no mesmo console.
-- Os modulos fg_core, fg_app, fg_bot e fg_view sao Lua puro, iguais aos da versao do PC.
-- Este arquivo e so o "adaptador" da SDK: desenho (ui.*), botoes (ui.btn) e paleta DB32.
-- Se algo falhar, o erro aparece na TELA (em vez de tela preta).
require "palette"
require "sprites"

local W, H = 480, 270
local floor = math.floor
local App, View, Bot, app, bot          -- carregados no primeiro quadro, dentro de pcall
local crashed, ready = nil, false
local safe = pcall or function(f, ...) return true, f(...) end

-- ================================================================ BOTOES (EDITE AQUI)
-- Cada botao tem uma lista de candidatos (funcoes que devolvem a constante da SDK): vale o
-- primeiro que existir. Assim, se uma constante nao existir, so aquele botao fica indisponivel.
local NAMES = { "left", "right", "up", "block", "punch", "kick", "special" }
local P1 = {   -- jogador 1 (usa so o que o Tetris ja usa; CIMA cai para G se nao existir)
  left  = { function() return LEFT end },
  right = { function() return RIGHT end },
  up    = { function() return UP end, function() return BTN_G end },
  block = { function() return DOWN end },
  punch = { function() return BTN_Z end },
  kick  = { function() return BTN_X end },
  special = { function() return BTN_F end },
}
local P2 = {   -- jogador 2 (SUPOSICAO: botoes de letra BTN_<LETRA>): A D andar, W pula, S defende
  left  = { function() return BTN_A end }, right = { function() return BTN_D end },
  up    = { function() return BTN_W end }, block = { function() return BTN_S end },
  punch = { function() return BTN_Q end }, kick  = { function() return BTN_E end },
  special = { function() return BTN_R end },
}
local P2_LABEL = { left = "A", right = "D", up = "W", block = "S", punch = "Q", kick = "E", special = "R" }

local map1, map2, p2ok, missing2 = {}, {}, true, ""

local function resolve(cands)
  for i = 1, #cands do
    local ok, v = safe(cands[i])
    if ok and type(v) == "number" then return v end
  end
  return nil
end

local function resolve_buttons()
  for i = 1, #NAMES do
    local n = NAMES[i]
    map1[n] = resolve(P1[n])
    map2[n] = resolve(P2[n])
    if map2[n] == nil then
      p2ok = false
      if #missing2 < 30 then missing2 = missing2 .. " " .. P2_LABEL[n] end
    end
  end
end

local function read_buttons(map, h)
  for i = 1, #NAMES do
    local n = NAMES[i]
    local b, on = map[n], false
    if b ~= nil then
      local r = ui.btn(b)
      on = (r ~= nil and r ~= false and r ~= 0)
    end
    h[n] = on
  end
end

-- ================================================================ CORES (paleta DB32)
local DB32 = {
  0x000000, 0x222034, 0x45283c, 0x663931, 0x8f563b, 0xdf7126, 0xd9a066, 0xeec39a,
  0xfbf236, 0x99e550, 0x6abe30, 0x37946e, 0x4b692f, 0x524b24, 0x323c39, 0x3f3f74,
  0x306082, 0x5b6ee1, 0x639bff, 0x5fcde4, 0xcbdbfc, 0xffffff, 0x9badb7, 0x847e87,
  0x696a6a, 0x595652, 0x76428a, 0xac3232, 0xd95763, 0xd77bba, 0x8f974a, 0x8a6f30,
}
local DR, DG, DB = {}, {}, {}
for i = 1, #DB32 do
  local c = DB32[i]
  DR[i], DG[i], DB[i] = floor(c / 65536), floor(c / 256) % 256, c % 256
end

local cache, ncache = {}, 0
local function color(rgb)
  local idx = cache[rgb]
  if idx then return idx end
  local r, g, b = floor(rgb / 65536), floor(rgb / 256) % 256, rgb % 256
  local best, bestd = 1, 1e9
  for i = 1, #DB32 do
    local dr, dg, db = r - DR[i], g - DG[i], b - DB[i]
    local d = dr * dr + dg * dg + db * db
    if d < bestd then best, bestd = i, d end
  end
  idx = Palette.hex(DB32[best])
  if ncache >= 1500 then cache, ncache = {}, 0 end
  cache[rgb] = idx
  ncache = ncache + 1
  return idx
end

-- ================================================================ DESENHO
-- ui.rect/rectfill recebem os dois cantos (inclusivos). Retangulos que saem da tela sao cortados aqui.
local gfx = {
  clear = function(rgb) ui.cls(color(rgb)) end,
  fill = function(x, y, w, h, rgb)
    local x1, y1 = x + w - 1, y + h - 1
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if x1 > W - 1 then x1 = W - 1 end
    if y1 > H - 1 then y1 = H - 1 end
    if x1 >= x and y1 >= y then ui.rectfill(x, y, x1, y1, color(rgb)) end
  end,
  box = function(x, y, w, h, rgb)
    if w > 0 and h > 0 then ui.rect(x, y, x + w - 1, y + h - 1, color(rgb)) end
  end,
  text = function(s, x, y, rgb) ui.print(s, x, y, color(rgb)) end,
}

local GOLD, DIM, WHITE, RED, BLUE, INK, LINE = 0xfbf236, 0x9badb7, 0xffffff, 0xd95763, 0x639bff, 0x222034, 0x595652
local function center(s, y, c) gfx.text(s, floor((W - #s * 8) / 2), y, c) end

local function draw_error(msg)
  gfx.clear(0x000000)
  gfx.text("STREET DUEL - ERRO", 12, 12, RED)
  gfx.text("COPIE ESTA MENSAGEM E MANDE PARA O ASSISTENTE:", 12, 26, DIM)
  local done = safe(function()
    local y, i, n = 44, 1, #msg
    while i <= n and y < 250 do
      local j = i + 55
      if j > n then j = n end
      gfx.text(msg:sub(i, j), 12, y, WHITE)
      y, i = y + 10, j + 1
    end
  end)
  if not done then ui.print(msg, 12, 44, color(WHITE)) end
end

-- ================================================================ MENU DO TITULO
local menu, diff, row = 1, 2, 1            -- 1 jogador (vs CPU) ou 2; dificuldade 1..3
local DIFF_NAMES = { "FACIL", "NORMAL", "DIFICIL" }

local function title_lines()
  local t = {
    { "J1: SETAS MOVER (CIMA PULA, BAIXO DEFENDE)", 96 },
    { "Z SOCO   X CHUTE   F PODER ESPECIAL", 108 },
  }
  if menu == 2 then
    t[3] = { "J2: A D MOVER  W PULA  S DEFENDE", 126, RED }
    t[4] = { "Q SOCO   E CHUTE   R PODER ESPECIAL", 138, RED }
    if not p2ok then t[5] = { "J2 INDISPONIVEL. FALTAM BOTOES:" .. missing2, 150, RED } end
  else
    t[3] = { "VOCE LUTA CONTRA O COMPUTADOR", 126, DIM }
  end
  return t
end

local function select_lines()
  if menu == 2 then
    return { "J1: ESQ/DIR ESCOLHE  Z CONFIRMA  X CANCELA", "J2: A D ESCOLHE  Q CONFIRMA  E CANCELA" }
  end
  return { "ESQUERDA/DIREITA ESCOLHE  Z CONFIRMA  X CANCELA" }
end

local NAMES1, NAMES2 = { "VOCE", "CPU" }, { "J1", "J2" }

local function draw_menu(frame)
  gfx.fill(60, 158, 360, 30, INK)
  gfx.box(60, 158, 360, 30, LINE)
  if row == 1 then gfx.text(">", 68, 164, GOLD) end
  gfx.text((menu == 1 and "* " or "  ") .. "1 JOGADOR", 90, 164, (menu == 1) and GOLD or DIM)
  gfx.text((menu == 2 and "* " or "  ") .. "2 JOGADORES", 250, 164, (menu == 2) and GOLD or DIM)
  if menu == 1 then
    if row == 2 then gfx.text(">", 68, 176, GOLD) end
    for i = 1, 3 do
      gfx.text((diff == i and "* " or "  ") .. DIFF_NAMES[i], 90 + (i - 1) * 110, 176, (diff == i) and GOLD or DIM)
    end
  else
    gfx.text("DOIS JOGADORES NO MESMO CONSOLE", 100, 176, DIM)
  end
  if floor(frame / 30) % 2 == 0 then center("ESQ/DIR: OPCAO   X: LINHA   Z: INICIAR", 248, GOLD) end
end

-- ================================================================ LOOP
local held1, held2, prev = {}, {}, {}
local NOH = {}
local function pressed(name)
  local now = held1[name]
  local p = now and not prev[name]
  prev[name] = now
  return p
end

local function boot()
  App, View, Bot = require("fg_app"), require("fg_view"), require("fg_bot")
  resolve_buttons()
  app = App.new(true)
  bot = Bot.new(2)
  ready = true
end

local function step(frame)
  read_buttons(map1, held1)
  read_buttons(map2, held2)
  local z, x = pressed("punch"), pressed("kick")
  local l, r, u, d = pressed("left"), pressed("right"), pressed("up"), pressed("block")
  pressed("special")

  if app.screen == "title" then
    if menu == 1 then
      if u then row = 1 end
      if d or x then row = (row == 1) and 2 or 1 end
      if row == 2 then
        if l and diff > 1 then diff = diff - 1 end
        if r and diff < 3 then diff = diff + 1 end
      else
        if l then menu = 1 end
        if r then menu = 2 end
      end
    else
      row = 1
      if l then menu = 1 end
      if r then menu = 2 end
    end
    if z and not (menu == 2 and not p2ok) then
      app.auto2 = (menu == 1)
      bot = Bot.new(diff)
      bot.seed = (frame * 7919 + 4242) % 2147483646 + 1
      app:ok()
    end
  elseif z then
    app:ok()                               -- fim da luta -> titulo
  end

  local h2 = held2
  if app.auto2 then
    local g = app.game
    if app.screen == "play" and g then h2 = bot:think(g, g.f[2], g.f[1]) else h2 = NOH end
  end
  app:update(held1, h2)

  View.draw(app, gfx, frame, {
    names = (app.auto2 and NAMES1 or NAMES2),
    title = title_lines(),
    select = select_lines(),
  })
  if app.screen == "title" then draw_menu(frame) end
end

function loop(frame)
  for i = 1, #Palette do ui.palset(i - 1, Palette[i]) end
  ui.clip(0, 0, W, H)
  ui.camera(0, 0)
  if crashed then draw_error(crashed); return end
  local ok, err
  if not ready then
    ok, err = safe(boot)
    if not ok then crashed = tostring(err); draw_error(crashed); return end
  end
  ok, err = safe(step, frame)
  if not ok then crashed = tostring(err); draw_error(crashed) end
end
