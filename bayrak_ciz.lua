-- ==========================================
-- HANEDANOGULLARI BAYRAGI CIZICI
-- Bu script, ekrana/monitore dogrudan bayragi cizer
-- .nfp dosyasi olusturmaya gerek kalmadan calisir
-- ==========================================

local mon = peripheral.find("monitor") or term
mon.setBackgroundColor(colors.brown) -- bordo yerine en yakin renk (Minecraft paletinde koyu kirmizi/kahverengi)

-- eger gercek monitor kullaniliyorsa, buyuk boyut icin olceklendir
if peripheral.find("monitor") then
  mon.setTextScale(0.5)
end

mon.clear()

local w, h = mon.getSize()

-- Zemin: bordo (en yakin Minecraft rengi: colors.brown veya colors.red -- brown daha koyu, bordoya yakin)
mon.setBackgroundColor(colors.brown)
for y = 1, h do
  mon.setCursorPos(1, y)
  mon.write(string.rep(" ", w))
end

-- Ust ve alt altin seritler
mon.setBackgroundColor(colors.yellow)
mon.setCursorPos(1, 1)
mon.write(string.rep(" ", w))
mon.setCursorPos(1, h)
mon.write(string.rep(" ", w))

-- Merkez daire ve pence izi (basitlestirilmis piksel temsili)
local centerX = math.floor(w / 2)
local centerY = math.floor(h / 2)

-- Pence izi: 3 diyagonal cizgi, altin renkte
mon.setBackgroundColor(colors.yellow)
local clawLines = {
  {dx = -3, dy = -3, len = 5},
  {dx = -1, dy = -3, len = 5},
  {dx = 1,  dy = -3, len = 5},
}

for _, line in ipairs(clawLines) do
  for i = 0, line.len - 1 do
    local px = centerX + line.dx + i
    local py = centerY + line.dy + i
    if px >= 1 and px <= w and py >= 1 and py <= h then
      mon.setCursorPos(px, py)
      mon.write(" ")
    end
  end
end

-- Merkez etrafinda basit bir cember (yildiz motifleri yerine basitlestirilmis noktalar)
mon.setBackgroundColor(colors.yellow)
local radius = math.min(centerX, centerY) - 2
for angle = 0, 360, 45 do
  local rad = math.rad(angle)
  local px = math.floor(centerX + radius * math.cos(rad))
  local py = math.floor(centerY + radius * math.sin(rad) / 2) -- terminal karakterleri dikdortgen oldugu icin y'yi kucult
  if px >= 1 and px <= w and py >= 1 and py <= h then
    mon.setCursorPos(px, py)
    mon.write("*")
  end
end

mon.setCursorPos(1, 1)
mon.setBackgroundColor(colors.black)
