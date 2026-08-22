-- ==========================================
-- HANEDANOGULLARI ATM SISTEMI
-- Fiziksel item <-> Dijital bakiye koprusu
-- ==========================================

local PROTOCOL = "j7yq39j4gwpoku9h38w409geoTYUHIJ9u0UR-troglfd-2847"
local MODEM_SIDE = "back" -- ATM'nin modemi arkada
local BANK_ID = 0 -- Merkez Banka ID'si
local CHEST_SIDE = "top" -- yatirma/cekme sandiginin bagli oldugu yon, kendine gore ayarla

rednet.open(MODEM_SIDE)

-- ==========================================
-- DEGER TABLOSU
-- Buraya istedigin itemleri ve degerlerini ekleyebilirsin
-- ==========================================

local ITEM_VALUES = {
  ["minecraft:copper_ingot"] = 0.2,
  ["minecraft:iron_ingot"] = 0.5,
  ["create:zinc_ingot"] = 1.5, -- Create'in kendi zinc ingot'u (dogru modid'i JEI'den teyit et)
  ["minecraft:gold_ingot"] = 2,
  ["create:brass_ingot"] = 4,
  ["minecraft:emerald"] = 10,
  ["minecraft:diamond"] = 25,
  ["minecraft:netherite_ingot"] = 150,
}

-- ==========================================
-- YARDIMCI FONKSIYONLAR
-- ==========================================

local function getChest()
  return peripheral.wrap(CHEST_SIDE)
end

local function countDepositValue()
  local chest = getChest()
  if not chest then return 0, {} end

  local items = chest.list()
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

-- SENIN KURULUMUN: [Bilgisayar] -> [Sandik] -> Chute -> Belt -> [Kasa]
-- Chute ve Belt itemleri ZATEN OTOMATIK olarak Kasa'ya tasiyor.
-- Kod hicbir sey tasimiyor, SADECE KASA'YI OKUYUP SAYIYOR.
-- KASA_SIDE: bilgisayarin, Kasa'yi (son nokta) hangi yonden gordugu.
-- Eger Kasa bilgisayara dogrudan bagli degilse (araya Belt/baska blok giriyorsa),
-- bir Wired Modem ile Kasa'ya ayrica baglanman gerekebilir - bu durumda
-- KASA_SIDE yerine peripheral.getNames() ile bulunan ismi kullan.
local KASA_SIDE = "bottom" -- kendi kurulumuna gore ayarla

-- Onceki sayimda Kasa'da olanlari hatirlamak icin (kumulatif fark hesaplamak yerine,
-- her seferinde Kasa'yi TAMAMEN BOSALTARAK sayiyoruz - en guvenli yontem)
local function countAndClearKasa()
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
      -- NOT: Itemleri silmiyoruz, Kasa senin gercek hazinen olarak kalmali.
      -- Sadece SAYIYORUZ. Amaayni itemin tekrar sayilmamasi icin,
      -- bir "sayilan miktar" defteri tutmamiz gerekiyor (asagida).
    end
  end

  return totalValue, itemsFound
end

-- Daha once sayilan toplam miktarlari hatirlayan defter (kalici dosyada saklanir)
local function loadCountedLedger()
  if fs.exists("counted_ledger.txt") then
    local f = fs.open("counted_ledger.txt", "r")
    local data = textutils.unserialize(f.readAll())
    f.close()
    return data or {}
  end
  return {}
end

local function saveCountedLedger(ledger)
  local f = fs.open("counted_ledger.txt", "w")
  f.write(textutils.serialize(ledger))
  f.close()
end

-- Bu fonksiyon, Kasa'daki mevcut miktarlari, daha once sayilan miktarlarla
-- karsilastirip SADECE YENI EKLENEN kismi hesaplar. Boylece Kasa hic bosaltilmasa
-- (item'lar kalici olarak orada dursa) bile, ayni itemler tekrar tekrar sayilmaz.
local function depositAndMoveItems()
  local kasa = peripheral.wrap(KASA_SIDE)
  if not kasa then return 0, {} end

  local ledger = loadCountedLedger()
  local items = kasa.list()

  -- Kasa'daki her item turunden GERCEK toplam miktari hesapla
  local currentTotals = {}
  for slot, item in pairs(items) do
    currentTotals[item.name] = (currentTotals[item.name] or 0) + item.count
  end

  local totalValue = 0
  local itemsFound = {}

  for itemName, currentCount in pairs(currentTotals) do
    local value = ITEM_VALUES[itemName]
    if value then
      local previouslyCounted = ledger[itemName] or 0
      local newAmount = currentCount - previouslyCounted

      if newAmount > 0 then
        local itemTotal = value * newAmount
        totalValue = totalValue + itemTotal
        table.insert(itemsFound, {name = itemName, count = newAmount, value = itemTotal})
      end

      -- defteri guncelle: artik bu kadarini saydik
      ledger[itemName] = currentCount
    end
  end

  saveCountedLedger(ledger)
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
-- ANA MENU
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
  print("Once giris yap, sonra itemleri atmani")
  print("istiyecegiz.")
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

  -- giris basarili, once Vault'ta bekleyen eski itemler varsa
  -- (kimseye ait olmayan) onlari temizle, hesaba yanlis yazilmasin
  depositAndMoveItems() -- bu cagrinin sonucunu kullanmiyoruz, sadece Vault'u sifirliyoruz

  print("")
  print("Giris basarili, hosgeldin " .. username .. "!")
  print("")
  print("Simdi itemleri sandiga at, sistem 6 saniye")
  print("boyunca surekli sayacak.")
  print("")

  -- 6 saniye boyunca her saniye Vault'u kontrol et,
  -- akip giden itemleri kacirmamak icin kumulatif topla
  local cumulativeValue = 0
  local cumulativeItems = {}

  for i = 6, 1, -1 do
    term.setCursorPos(1, select(2, term.getCursorPos()))
    write("Kalan sure: " .. i .. " saniye... (su ana kadar: " .. cumulativeValue .. " birim)   ")

    local roundValue, roundItems = depositAndMoveItems()
    if roundValue > 0 then
      cumulativeValue = cumulativeValue + roundValue
      for _, item in ipairs(roundItems) do
        table.insert(cumulativeItems, item)
      end
    end

    sleep(1)
  end

  -- son bir kontrol daha (son saniyede gelenleri de yakalamak icin)
  local finalValue, finalItems = depositAndMoveItems()
  if finalValue > 0 then
    cumulativeValue = cumulativeValue + finalValue
    for _, item in ipairs(finalItems) do
      table.insert(cumulativeItems, item)
    end
  end

  print("")
  print("Sayim tamamlandi.")

  local totalValue = cumulativeValue
  local itemsFound = cumulativeItems

  if totalValue == 0 then
    print("")
    print("Vault'ta gecerli item bulunamadi, islem iptal edildi.")
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
  print("Vault'ta bulunan degerli itemler:")
  for _, item in ipairs(itemsFound) do
    print("  " .. item.name .. " x" .. item.count .. " = " .. item.value .. " birim")
  end
  print("")
  print("TOPLAM DEGER: " .. totalValue .. " birim")

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
  print("Fiziksel item vermek icin ek bir Item Vault")
  print("+ Deployer sistemi kurulmasi gerekiyor.")
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
    print("1) Para Yatir (Sandiktaki itemleri yatir)")
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
      break
    end
  end
end

mainMenu()
