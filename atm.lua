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

-- GUVENLIK KRITIK: Bu fonksiyon, itemleri SAYMADAN ONCE degil,
-- SAYARKEN AYNI ANDA banka deposuna tasir. Boylece oyuncunun
-- "bakiye eklendi, simdi itemi geri alayim" yapmasi imkansiz olur.
-- VAULT_SIDE: itemlerin tasinacagi guvenli banka deposunun yonu
local VAULT_SIDE = "bottom" -- kendi kurulumuna gore ayarla, ATM sandiginin ALTINDA/yaninda guvenli bir depo olmali

local function depositAndMoveItems()
  local chest = getChest()
  if not chest then return 0, {} end

  local items = chest.list()
  local totalValue = 0
  local itemsFound = {}

  for slot, item in pairs(items) do
    local value = ITEM_VALUES[item.name]
    if value then
      -- pushItems tek seferde max 64 (bir stack) tasiyor,
      -- slot tamamen bosalana kadar dongu ile devam ediyoruz
      local totalMoved = 0
      while true do
        local moved = chest.pushItems(VAULT_SIDE, slot)
        if not moved or moved == 0 then break end
        totalMoved = totalMoved + moved
      end

      if totalMoved > 0 then
        local itemTotal = value * totalMoved
        totalValue = totalValue + itemTotal
        table.insert(itemsFound, {name = item.name, count = totalMoved, value = itemTotal})
      end
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
  print("Once hesap bilgilerini gir, SONRA itemler")
  print("sandiktan alinip banka bakiyene eklenecek.")
  print("")

  write("Kullanici adi: ")
  local username = read()
  write("Sifre: ")
  local password = read("*")

  -- once giris dogrula (item tasimadan once kimligi kontrol et)
  local loginResp = sendToBank({action = "login", username = username, password = password})

  if not loginResp or loginResp.status ~= "ok" then
    print("")
    print("Kimlik dogrulama basarisiz! Islem iptal edildi.")
    print("(devam etmek icin tusa bas)")
    os.pullEvent("key")
    return
  end

  -- KRITIK ADIM: itemleri SAYARKEN AYNI ANDA guvenli depoya tasi
  -- boylece oyuncunun "once say, sonra geri al" yapmasi imkansiz
  local totalValue, itemsFound = depositAndMoveItems()

  if totalValue == 0 then
    print("")
    print("Sandikta gecerli item bulunamadi, islem yapilmadi.")
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
  print("Sandiktan alinan ve guvenli depoya tasinan itemler:")
  for _, item in ipairs(itemsFound) do
    print("  " .. item.name .. " x" .. item.count .. " = " .. item.value .. " birim")
  end
  print("")
  print("TOPLAM DEGER: " .. totalValue .. " birim")

  -- itemler artik guvenli depoda, geri alinamaz. Simdi bakiyeyi guncelle
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
