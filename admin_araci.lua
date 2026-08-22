-- ==========================================
-- HANEDANOGULLARI ADMIN ARACI
-- Bu scripti SADECE senin (admin) bilgisayarinda calistir
-- Merkez Banka ile ayni ag uzerinde olmali (modem bagli)
-- ==========================================

local PROTOCOL = "j7yq39j4gwpoku9h38w409geoTYUHIJ9u0UR-troglfd-2847"
local MODEM_SIDE = "back" -- kendi bilgisayarina gore ayarla (pocket ise "back", normal bilgisayarsa right/left/top vs.)
local BANK_ID = 0 -- Merkez Banka'nin ID'si

rednet.open(MODEM_SIDE)

print("==========================================")
print("  HANEDANOGULLARI ADMIN ARACI")
print("==========================================")
print("")
write("Bakiyesini degistirmek istedigin kullanici adi: ")
local username = read()
write("Yeni bakiye miktari: ")
local amount = tonumber(read())

if not amount then
  print("Gecersiz miktar!")
  return
end

rednet.send(BANK_ID, {action = "admin_setbalance", username = username, amount = amount}, PROTOCOL)

local id, response = rednet.receive(PROTOCOL, 5)

if response and response.status == "ok" then
  print("")
  print("Basarili: " .. username .. " bakiyesi " .. amount .. " olarak ayarlandi.")
else
  print("")
  print("Hata olustu ya da banka yanit vermedi.")
  print("Not: Merkez Banka kodundaki ADMIN_ID degiskeninin,")
  print("bu bilgisayarin ID'siyle (" .. os.getComputerID() .. ") ayni oldugundan emin ol.")
end
