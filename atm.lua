-- ==========================================
-- HANEDANOGULLARI ATM SISTEMI (v2 - Smart Chute)
-- Fiziksel item <-> Dijital bakiye koprusu
--
-- KURULUM: [Bilgisayar] -> [Sandik] -> Smart Chute (redstone kontrollu) -> [Kasa]
-- Smart Chute normalde KAPALI (redstone sinyali VAR).
-- Para yatirma sirasinda kisa sureligine ACILIR (redstone sinyali YOK),
-- itemler Kasa'ya akar, sonra tekrar KAPANIR.
-- Boylece akis tamamen kontrollu, dupe riski yok.
-- ==========================================

local PROTOCOL = "j7yq39j4gwpoku9h38w409geoTYUHIJ9u0UR-troglfd-2847"
local MODEM_SIDE = "back" -- ATM'nin modemi arkada
local BANK_ID = 0 -- Merkez Banka ID'si, kendi kurulumuna gore ayarla
local KASA_SIDE = "bottom" -- Kasa'nin (Smart Chute'un ALTINDAKI depo) bilgisayara gore yonu
local REDSTONE_SIDE = "right" -- Smart Chute'a giden redstone sinyalinin cikis yonu
local DEPOSIT_DURATION = 6 -- kac saniye boyunca chute acik kalsin

rednet.open(MODEM_SIDE)

-- ==========================================
-- DEGER TABLOSU
-- ==========================================

local ITEM_VALUES = {
  ["minecraft:copper_ingot"] = 0.2,
  ["minecraft:iron_ingot"] = 0.5,
  ["create:zinc_ingot"] = 1.5, -- Create'in kendi zinc ingot'u, dogru modid'i JEI'den teyit et
  ["minecraft:gold_ingot"] = 2,
  ["create:brass_ingot"] = 4,
  ["minecraft:emerald"] = 10,
  ["minecraft:diamond"] = 25,
  ["minecraft:netherite_ingot"] = 150,
}

-- ==========================================
-- CHUTE KONTROLU
-- ==========================================

local function closeChute()
  redstone.setOutput(REDSTONE_SIDE, true) -- sinyal VAR = Smart Chute KAPALI
end

local function openChute()
  redstone.setOutput(REDSTONE_SIDE, false) -- sinyal YOK = Smart Chute ACIK
end

-- baslangicta chute'un kapali oldugundan emin ol
closeChute()

-- ==========================================
-- KASA SAYIMI
-- ==========================================

local function countKasa()
  local kasa = peripheral.wrap(KASA_SIDE)
  if not kasa then return 0, {} end

  local items = kasa.list()
  local totalValue = 0
  local itemsFound = {}

  for slot, item in pairs(items) do
    local value = ITEM_VALUES[item.name]
    if value then
      local itemTotal = value * item.count
      totalValue = totalValue + itemTotal
      table.insert(itemsFound, {name = item.name, count = item.count, value = itemTotal})
    end
  end

  return totalValue, itemsFound
end

-- ==========================================
-- BANKA ILETISIMI
-- ==========================================

local function sendToBank(msg)
  rednet.send(BANK_ID, msg, PROTOCOL)
  local id, response = rednet.receive(PROTOCOL, 5)
  return response
end

-- ==========================================
-- EKRAN FONKSIYONLARI
-- ==========================================

local function clearScreen()
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1,1)
end

local function depositScreen()
  clearScreen()
  print("==========================================")
  print("  ATM - PARA YATIRMA")
  print("==========================================")
  print("")

  write("Kullanici adi: ")
  local username = read()
  write("Sifre: ")
  local password = read("*")

  local loginResp = sendToBank({action = "login", username = username, password = password})

  if not loginResp or loginResp.status ~= "ok" then
    print("")
    print("Kimlik dogrulama basarisiz! Islem iptal edildi.")
    print("(devam etmek icin tusa bas)")
    os.pullEvent("key")
    return
  end

  -- yatirma oncesi Kasa'daki mevcut degeri kaydet (referans noktasi)
  local beforeValue, _ = countKasa()

  print("")
  print("Giris basarili, hosgeldin " .. username .. "!")
  print("")
  print("Simdi itemleri sandiga at! Chute " .. DEPOSIT_DURATION .. " saniye acik kalacak.")
  print("")

  openChute()

  for i = DEPOSIT_DURATION, 1, -1 do
    term.setCursorPos(1, select(2, term.getCursorPos()))
    write("Kalan sure: " .. i .. " saniye...   ")
    sleep(1)
  end

  closeChute()
  sleep(0.5) -- chute'un kapanip son itemlerin de dusmesi icin kisa bekleme

  print("")
  print("Chute kapatildi, sayiliyor...")

  local afterValue, afterItems = countKasa()
  local totalValue = afterValue - beforeValue

  if totalValue <= 0 then
    print("")
    print("Yeni item algilanmadi, islem iptal edildi.")
    print("Kabul edilen itemler:")
    for name, value in pairs(ITEM_VALUES) do
      print("  " .. name .. " = " .. value .. " birim")
    end
    print("")
    print("(devam etmek icin tusa bas)")
    os.pullEvent("key")
    return
  end

  print("")
  print("YATIRILAN DEGER: " .. totalValue .. " birim")

  local newBalance = loginResp.balance + totalValue
  local setResp = sendToBank({action = "admin_setbalance", username = username, amount = newBalance})

  if setResp and setResp.status == "ok" then
    print("")
    print("Yatirma basarili!")
    print("Yeni bakiye: " .. newBalance .. " birim")
  else
    print("")
    print("!!! KRITIK HATA: Itemler alindi ama bakiye guncellenemedi !!!")
    print("Bu durumu hemen admin'e bildir, manuel duzeltme gerekebilir.")
  end

  print("")
  print("(devam etmek icin tusa bas)")
  os.pullEvent("key")
end

local function withdrawScreen()
  clearScreen()
  print("==========================================")
  print("  ATM - PARA CEKME")
  print("==========================================")
  print("")
  print("NOT: Bu ozellik henuz otomatik item verme")
  print("yapmiyor, sadece bakiyeni dusurur.")
  print("Fiziksel item vermek icin ek bir Deployer")
  print("sistemi kurulmasi gerekiyor.")
  print("")
  print("(devam etmek icin tusa bas)")
  os.pullEvent("key")
end

local function mainMenu()
  while true do
    clearScreen()
    print("==========================================")
    print("  HANEDANOGULLARI ATM")
    print("==========================================")
    print("")
    print("1) Para Yatir")
    print("2) Para Cek")
    print("3) Kapat")
    print("")
    write("Secim: ")
    local choice = read()

    if choice == "1" then
      depositScreen()
    elseif choice == "2" then
      withdrawScreen()
    elseif choice == "3" then
      closeChute() -- guvenlik: cikista chute'un kapali oldugundan emin ol
      break
    end
  end
end

mainMenu()
