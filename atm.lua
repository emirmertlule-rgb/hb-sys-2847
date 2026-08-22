-- ==========================================
-- HANEDANOGULLARI ATM SISTEMI (v3)
-- Fiziksel item <-> Dijital bakiye koprusu
--
-- FIZIKSEL KURULUM:
-- [Bilgisayar] -> [Sandik] -> Smart Chute 1 (redstone) -> [Kasa] -> Smart Chute 2 (redstone) -> [Hazine]
--
-- AKIS:
-- 1) Kullanici giris yapar
-- 2) "Para Yatir" secer
-- 3) Ekranda "itemleri sandiga at" yazar, Chute 1 ACILIR
-- 4) 6 saniye boyunca acik kalir (itemler Sandik -> Kasa akar)
-- 5) Chute 1 KAPANIR, Kasa'daki miktar SAYILIR, bakiyeye eklenir
-- 6) Chute 2 ACILIR, 10 saniye boyunca Kasa'daki itemler Hazine'ye akar
-- 7) Chute 2 KAPANIR, Kasa artik BOS, bir sonraki islem icin hazir
-- ==========================================

local PROTOCOL = "j7yq39j4gwpoku9h38w409geoTYUHIJ9u0UR-troglfd-2847"
local MODEM_SIDE = "back" -- ATM'nin modemi arkada
local BANK_ID = 0 -- Merkez Banka ID'si, kendi kurulumuna gore ayarla
local KASA_SIDE = "bottom" -- Kasa'nin (ilk Smart Chute'un altindaki gecici depo) bilgisayara gore yonu

-- REDSTONE CIKISLARI
-- Eger her iki Smart Chute da AYNI yonden (sagdan) kontrol ediliyorsa,
-- bu iki chute'u AYRI redstone hatlariyla kontrol etmen gerekiyor.
-- Ornegin: Chute 1 icin "right", Chute 2 icin "left" gibi FARKLI yonler kullan.
local CHUTE1_REDSTONE_SIDE = "right" -- Sandik -> Kasa arasindaki chute
local CHUTE2_REDSTONE_SIDE = "left"  -- Kasa -> Hazine arasindaki chute, FARKLI bir yon olmali

local DEPOSIT_DURATION = 6  -- para koyma suresi (saniye)
local WITHDRAW_DURATION = 10 -- Kasa'yi Hazine'ye bosaltma suresi (saniye)

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

local function closeChute1() redstone.setOutput(CHUTE1_REDSTONE_SIDE, true) end
local function openChute1()  redstone.setOutput(CHUTE1_REDSTONE_SIDE, false) end
local function closeChute2() redstone.setOutput(CHUTE2_REDSTONE_SIDE, true) end
local function openChute2()  redstone.setOutput(CHUTE2_REDSTONE_SIDE, false) end

-- baslangicta ikisi de kapali olsun
closeChute1()
closeChute2()

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

local function countdown(seconds, label)
  for i = seconds, 1, -1 do
    term.setCursorPos(1, select(2, term.getCursorPos()))
    write(label .. ": " .. i .. " saniye...   ")
    sleep(1)
  end
  print("")
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

  print("")
  print("Giris basarili, hosgeldin " .. username .. "!")
  print("")
  print(">>> ITEMLERI SIMDI SANDIGA AT <<<")
  print("")

  -- ADIM 1: Chute 1 ac, itemler Sandik'tan Kasa'ya aksin
  openChute1()
  countdown(DEPOSIT_DURATION, "Koyma suresi")
  closeChute1()
  sleep(0.5) -- son itemlerin de dusmesi icin kisa bekleme

  print("")
  print("Sayiliyor...")
  local totalValue, itemsFound = countKasa()

  if totalValue <= 0 then
    print("")
    print("Kasa'da gecerli item bulunamadi, islem iptal edildi.")
    print("Kabul edilen itemler:")
    for name, value in pairs(ITEM_VALUES) do
      print("  " .. name .. " = " .. value .. " birim")
    end
    -- yine de Kasa'yi bosalt, icinde gecersiz item kalmasin
    print("")
    print("Kasa temizleniyor...")
    openChute2()
    countdown(WITHDRAW_DURATION, "Temizleme suresi")
    closeChute2()
    print("")
    print("(devam etmek icin tusa bas)")
    os.pullEvent("key")
    return
  end

  print("")
  print("Kasa'da bulunan degerli itemler:")
  for _, item in ipairs(itemsFound) do
    print("  " .. item.name .. " x" .. item.count .. " = " .. item.value .. " birim")
  end
  print("")
  print("YATIRILAN DEGER: " .. totalValue .. " birim")

  -- ADIM 2: bakiyeyi guncelle
  local newBalance = loginResp.balance + totalValue
  local setResp = sendToBank({action = "admin_setbalance", username = username, amount = newBalance})

  if setResp and setResp.status == "ok" then
    print("")
    print("Yatirma basarili!")
    print("Yeni bakiye: " .. newBalance .. " birim")
  else
    print("")
    print("!!! KRITIK HATA: Itemler sayildi ama bakiye guncellenemedi !!!")
    print("Bu durumu hemen admin'e bildir, manuel duzeltme gerekebilir.")
  end

  -- ADIM 3: Kasa'yi Hazine'ye bosalt (Chute 2)
  print("")
  print(">>> KASA HAZINEYE BOSALTILIYOR <<<")
  openChute2()
  countdown(WITHDRAW_DURATION, "Bosaltma suresi")
  closeChute2()

  print("")
  print("Islem tamamlandi, Kasa bosaltildi.")
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
      closeChute1()
      closeChute2()
      break
    end
  end
end

mainMenu()
