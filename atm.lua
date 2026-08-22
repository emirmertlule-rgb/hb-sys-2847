local PROTOCOL = "j7yq39j4gwpoku9h38w409geoTYUHIJ9u0UR-troglfd-2847"
local MODEM_SIDE = "back"
local BANK_ID = 0
local KASA_SIDE = "bottom"
local REDSTONE_SIDE = "right"
local COUNT_DURATION = 6
local DRAIN_DURATION = 10

rednet.open(MODEM_SIDE)

local ITEM_VALUES = {
  ["minecraft:copper_ingot"] = 0.2,
  ["minecraft:iron_ingot"] = 0.5,
  ["create:zinc_ingot"] = 1.5,
  ["minecraft:gold_ingot"] = 2,
  ["create:brass_ingot"] = 4,
  ["minecraft:emerald"] = 10,
  ["minecraft:diamond"] = 25,
  ["minecraft:netherite_ingot"] = 150,
}

-- varsayilan: acik (redstone sinyali YOK)
redstone.setOutput(REDSTONE_SIDE, false)

local function countKasa()
  local kasa = peripheral.wrap(KASA_SIDE)
  if not kasa then return 0, {} end
  local items = kasa.list()
  local totalValue = 0
  local itemsFound = {}
  for slot, item in pairs(items) do
    local value = ITEM_VALUES[item.name]
    if value then
      totalValue = totalValue + (value * item.count)
      table.insert(itemsFound, {name = item.name, count = item.count})
    end
  end
  return totalValue, itemsFound
end

local function sendToBank(msg)
  rednet.send(BANK_ID, msg, PROTOCOL)
  local id, response = rednet.receive(PROTOCOL, 5)
  return response
end

local function clearScreen()
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1,1)
end

local function depositScreen()
  clearScreen()
  print("PARA YATIRMA")
  print("")
  write("Kullanici adi: ")
  local username = read()
  write("Sifre: ")
  local password = read("*")

  local loginResp = sendToBank({action = "login", username = username, password = password})
  if not loginResp or loginResp.status ~= "ok" then
    print("Giris basarisiz.")
    sleep(2)
    return
  end

  print("")
  print("Chute ACIK, itemleri sandiga at.")
  print("")

  -- 6 saniye boyunca: chute ACIK kalir, her saniye kumulatif sayilir
  local maxSeen = 0
  local finalItems = {}
  for i = COUNT_DURATION, 1, -1 do
    local currentValue, currentItems = countKasa()
    if currentValue > maxSeen then
      maxSeen = currentValue
      finalItems = currentItems
    end
    term.setCursorPos(1, select(2, term.getCursorPos()))
    write("Sure: " .. i .. "s | Toplam: " .. maxSeen .. " birim   ")
    sleep(1)
  end

  print("")
  print("TOPLAM: " .. maxSeen .. " birim")

  if maxSeen > 0 then
    local newBalance = loginResp.balance + maxSeen
    sendToBank({action = "admin_setbalance", username = username, amount = newBalance})
    print("Yeni bakiye: " .. newBalance)
  end

  -- 10 saniye boyunca: chute KAPALI, itemler belt'e akar
  print("")
  print("Kasa Hazineye akiyor...")
  redstone.setOutput(REDSTONE_SIDE, true) -- kapali

  for i = DRAIN_DURATION, 1, -1 do
    term.setCursorPos(1, select(2, term.getCursorPos()))
    write("Akitma: " .. i .. "s...   ")
    sleep(1)
  end

  redstone.setOutput(REDSTONE_SIDE, false) -- tekrar acik (varsayilan)

  print("")
  print("Tamamlandi.")
  sleep(2)
end

local function mainMenu()
  while true do
    clearScreen()
    print("HANEDANOGULLARI ATM")
    print("")
    print("1) Para Yatir")
    print("2) Kapat")
    write("Secim: ")
    local choice = read()
    if choice == "1" then
      depositScreen()
    elseif choice == "2" then
      redstone.setOutput(REDSTONE_SIDE, false)
      break
    end
  end
end

mainMenu()
