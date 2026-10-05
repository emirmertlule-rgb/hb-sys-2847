-- YILAN v1.0  |  CC:Tweaked icin renkli Snake
-- Kontroller: Ok tuslari / WASD = yon,  P = duraklat,  Q = cik
-- Altin elma (sari) = 3 puan + 3 boy. Her elmada hiz artar.
-- Rekor "yilan_rekor" dosyasina kaydedilir.

local w, h = term.getSize()
local renkli = term.isColour()
local function R(c, yedek) return renkli and c or (yedek or colors.white) end

local ZEMIN    = colors.black
local DUVAR    = R(colors.gray, colors.white)
local GOVDE    = R(colors.lime)
local KAFA     = R(colors.green)
local ELMA     = R(colors.red)
local ALTIN    = R(colors.yellow)
local HUD_BG   = R(colors.blue, colors.white)
local HUD_FG   = R(colors.white, colors.black)

-- Oyun alani: 1. satir skor tablosu, kalan alan cerceveli saha
local SX1, SY1 = 2, 3          -- sahanin sol ust ic hucresi
local SX2, SY2 = w - 1, h - 1  -- sahanin sag alt ic hucresi
local REKOR_DOSYA = "yilan_rekor"

local function rekorOku()
  if not fs.exists(REKOR_DOSYA) then return 0 end
  local f = fs.open(REKOR_DOSYA, "r")
  local n = tonumber(f.readAll()) or 0
  f.close()
  return n
end

local function rekorYaz(n)
  local f = fs.open(REKOR_DOSYA, "w")
  f.write(tostring(n))
  f.close()
end

local function hucre(x, y, renk, harf)
  term.setCursorPos(x, y)
  term.setBackgroundColor(renk)
  term.write(harf or " ")
end

local function ortala(y, yazi, fg, bg)
  term.setCursorPos(math.max(1, math.floor((w - #yazi) / 2) + 1), y)
  term.setTextColor(fg or colors.white)
  term.setBackgroundColor(bg or ZEMIN)
  term.write(yazi)
end

local function cerceve()
  term.setBackgroundColor(ZEMIN)
  term.clear()
  for x = SX1 - 1, SX2 + 1 do
    hucre(x, SY1 - 1, DUVAR)
    hucre(x, SY2 + 1, DUVAR)
  end
  for y = SY1, SY2 do
    hucre(SX1 - 1, y, DUVAR)
    hucre(SX2 + 1, y, DUVAR)
  end
end

local function hud(skor, rekor, durdu)
  term.setCursorPos(1, 1)
  term.setBackgroundColor(HUD_BG)
  term.setTextColor(HUD_FG)
  term.clearLine()
  local sol = " YILAN  Skor: " .. skor
  local sag = (durdu and "DURDU " or "") .. "Rekor: " .. rekor .. " "
  term.write(sol)
  term.setCursorPos(math.max(#sol + 1, w - #sag + 1), 1)
  term.write(sag)
end

local function anahtar(x, y) return x * 1000 + y end

local YONLER = {
  [keys.up] = {0, -1}, [keys.w] = {0, -1},
  [keys.down] = {0, 1}, [keys.s] = {0, 1},
  [keys.left] = {-1, 0}, [keys.a] = {-1, 0},
  [keys.right] = {1, 0}, [keys.d] = {1, 0},
}

local function oyna(rekor)
  cerceve()
  local cx, cy = math.floor((SX1 + SX2) / 2), math.floor((SY1 + SY2) / 2)
  local yilan = {}            -- yilan[1] = kafa
  local dolu = {}
  for i = 0, 2 do
    local p = {x = cx - i, y = cy}
    yilan[#yilan + 1] = p
    dolu[anahtar(p.x, p.y)] = true
  end
  local yon = {1, 0}
  local kuyruk = {}           -- en fazla 2 bekleyen yon degisikligi
  local buyume = 0
  local skor = 0
  local yem = nil
  local durdu = false

  local function yemKoy()
    local bos = {}
    for x = SX1, SX2 do
      for y = SY1, SY2 do
        if not dolu[anahtar(x, y)] then bos[#bos + 1] = {x, y} end
      end
    end
    if #bos == 0 then yem = nil return end
    local s = bos[math.random(#bos)]
    yem = {x = s[1], y = s[2], altin = math.random() < 0.15}
    hucre(yem.x, yem.y, yem.altin and ALTIN or ELMA)
  end

  for i, p in ipairs(yilan) do hucre(p.x, p.y, i == 1 and KAFA or GOVDE) end
  yemKoy()
  hud(skor, rekor, false)

  local function gecikme() return math.max(0.05, 0.2 - skor * 0.004) end
  local zaman = os.startTimer(gecikme())

  while true do
    local olay, p1 = os.pullEvent()

    if olay == "key" then
      if p1 == keys.q then return skor, "cikis" end
      if p1 == keys.p then
        durdu = not durdu
        hud(skor, rekor, durdu)
        if not durdu then zaman = os.startTimer(gecikme()) end
      elseif YONLER[p1] and not durdu and #kuyruk < 2 then
        local son = kuyruk[#kuyruk] or yon
        local yeni = YONLER[p1]
        -- ters yone ve ayni yone donmeyi engelle
        if yeni[1] ~= -son[1] or yeni[2] ~= -son[2] then
          if yeni[1] ~= son[1] or yeni[2] ~= son[2] then
            kuyruk[#kuyruk + 1] = yeni
          end
        end
      end

    elseif olay == "timer" and p1 == zaman and not durdu then
      if #kuyruk > 0 then yon = table.remove(kuyruk, 1) end
      local kafa = yilan[1]
      local nx, ny = kafa.x + yon[1], kafa.y + yon[2]

      -- kuyruk bu adimda cekilecekse oraya girmek serbest
      local son = yilan[#yilan]
      local kuyrukGidiyor = buyume == 0
      local carpti = nx < SX1 or nx > SX2 or ny < SY1 or ny > SY2
      if not carpti and dolu[anahtar(nx, ny)] then
        carpti = not (kuyrukGidiyor and son.x == nx and son.y == ny)
      end
      if carpti then return skor, "carpti" end

      local yedi = yem and yem.x == nx and yem.y == ny
      if yedi then
        local puan = yem.altin and 3 or 1
        skor = skor + puan
        buyume = buyume + puan
      end

      if buyume > 0 then
        buyume = buyume - 1
      else
        table.remove(yilan)
        dolu[anahtar(son.x, son.y)] = nil
        hucre(son.x, son.y, ZEMIN)
      end

      hucre(kafa.x, kafa.y, GOVDE)
      table.insert(yilan, 1, {x = nx, y = ny})
      dolu[anahtar(nx, ny)] = true
      hucre(nx, ny, KAFA)

      if yedi then
        if skor > rekor then rekor = skor end
        hud(skor, rekor, false)
        yemKoy()
        if not yem then return skor, "kazandi" end
      end
      zaman = os.startTimer(gecikme())
    end
  end
end

local function sonEkran(skor, rekor, yeniRekor, sebep)
  term.setBackgroundColor(ZEMIN)
  term.clear()
  local my = math.floor(h / 2) - 2
  ortala(my, sebep == "kazandi" and "SAHA DOLDU, KAZANDIN!" or "OYUN BITTI",
    R(colors.red), ZEMIN)
  ortala(my + 2, "Skor: " .. skor, colors.white, ZEMIN)
  if yeniRekor then
    ortala(my + 3, "YENI REKOR!", R(colors.yellow), ZEMIN)
  else
    ortala(my + 3, "Rekor: " .. rekor, R(colors.lightGray), ZEMIN)
  end
  ortala(my + 5, "Enter: tekrar   Q: cik", R(colors.lightGray), ZEMIN)
  while true do
    local _, k = os.pullEvent("key")
    if k == keys.enter or k == keys.numPadEnter then return true end
    if k == keys.q then return false end
  end
end

local function baslik()
  term.setBackgroundColor(ZEMIN)
  term.clear()
  local my = math.floor(h / 2) - 3
  ortala(my, "Y I L A N", R(colors.lime), ZEMIN)
  ortala(my + 2, "Ok tuslari / WASD", colors.white, ZEMIN)
  ortala(my + 3, "P duraklat, Q cik", colors.white, ZEMIN)
  ortala(my + 4, "Sari elma = 3 puan", R(colors.yellow), ZEMIN)
  ortala(my + 6, "Baslamak icin bir tusa bas", R(colors.lightGray), ZEMIN)
  os.pullEvent("key")
  sleep(0.1) -- basilan tusun oyuna sizmasini onle
end

if w < 12 or h < 8 then
  print("Ekran cok kucuk.")
  return
end

math.randomseed(os.epoch("utc"))
baslik()
local rekor = rekorOku()
while true do
  local skor, sebep = oyna(rekor)
  if sebep == "cikis" then break end
  local yeniRekor = skor > rekor
  if yeniRekor then rekor = skor; rekorYaz(rekor) end
  if not sonEkran(skor, rekor, yeniRekor, sebep) then break end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Oynadigin icin sagol! Rekor: " .. rekor)
