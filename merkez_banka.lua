-- ==========================================
-- HANEDANOGULLARI MERKEZ BANKASI
-- Merkez Banka Sunucu Kodu
-- ==========================================

local PROTOCOL = "j7yq39j4gwpoku9h38w409geoTYUHIJ9u0UR-troglfd-2847"
local MODEM_SIDE = "right" -- modeminin bagli oldugu yon, kendi kurulumuna gore degistir
local ADMIN_ID = nil -- ilk calistirmada senin bilgisayar ID'ni buraya yazacaksin

rednet.open(MODEM_SIDE)

-- ==========================================
-- VERI YONETIMI
-- ==========================================

local function loadAccounts()
  if fs.exists("accounts.txt") then
    local f = fs.open("accounts.txt", "r")
    local data = textutils.unserialize(f.readAll())
    f.close()
    return data or {}
  end
  return {}
end

local function saveAccounts(accounts)
  local f = fs.open("accounts.txt", "w")
  f.write(textutils.serialize(accounts))
  f.close()
end

local function logEvent(eventType, details)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local line = "[" .. timestamp .. "] " .. eventType .. ": " .. details
  local f = fs.open("bank_log.txt", "a")
  f.writeLine(line)
  f.close()
  print(line)
end

local function logSuspicious(reason, id, details)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local entry = timestamp .. " | " .. reason .. " | Terminal ID: " .. tostring(id) .. " | " .. details
  local f = fs.open("suspicious_log.txt", "a")
  f.writeLine(entry)
  f.close()
  print("[GUVENLIK UYARISI] " .. reason .. " - ID: " .. tostring(id))
end

-- ==========================================
-- ACIL DURUM SISTEMI
-- ==========================================

local BACKUP_ID = nil -- yedek bilgisayarin ID'si, ikinci bir bilgisayar kurup buraya ID'sini yazacaksin

local function emergencyWipe(reason)
  logEvent("ACIL_DURUM", "Tetiklenme sebebi: " .. reason)
  print("!!! GUVENLIK IHLALI ALGILANDI !!!")
  print("Sebep: " .. reason)

  if BACKUP_ID then
    print("Veriler yedege aktariliyor...")
    local f = fs.open("accounts.txt", "r")
    if f then
      local data = f.readAll()
      f.close()
      rednet.send(BACKUP_ID, {action = "restore_backup", data = data}, PROTOCOL)
      sleep(2) -- gonderimin ulasmasi icin bekleme
      print("Yedekleme mesaji gonderildi.")
    end
  else
    print("UYARI: Yedek bilgisayar ID'si ayarlanmamis, yedekleme atlaniyor!")
  end

  print("Orijinal veriler siliniyor...")
  if fs.exists("accounts.txt") then fs.delete("accounts.txt") end
  if fs.exists("bank_log.txt") then fs.delete("bank_log.txt") end
  print("Islem tamamlandi. Sistem durduruluyor.")
  error("Acil durum protokolu calistirildi - sistem durduruldu")
end

-- ==========================================
-- GUVENLIK - BASARISIZ GIRIS TAKIBI
-- ==========================================

local failedAttempts = {}
local MAX_FAILED_ATTEMPTS = 5

local function recordFailedAttempt(username, terminalID)
  failedAttempts[username] = (failedAttempts[username] or 0) + 1
  logSuspicious("BASARISIZ_GIRIS", terminalID, "Kullanici: " .. username .. " Deneme: " .. failedAttempts[username])

  if failedAttempts[username] >= MAX_FAILED_ATTEMPTS then
    emergencyWipe("Brute force tespit edildi - " .. username .. " icin " .. MAX_FAILED_ATTEMPTS .. " basarisiz deneme")
  end
end

local function clearFailedAttempts(username)
  failedAttempts[username] = 0
end

-- ==========================================
-- ANA PROGRAM
-- ==========================================

local accounts = loadAccounts()

print("==========================================")
print("  HANEDANOGULLARI MERKEZ BANKASI")
print("==========================================")
print("Bilgisayar ID: " .. os.getComputerID())
print("Kayitli hesap sayisi: " .. (function() local c=0 for _ in pairs(accounts) do c=c+1 end return c end)())
print("Banka aktif, mesajlar bekleniyor...")
print("==========================================")

while true do
  local id, message = rednet.receive(PROTOCOL)

  if type(message) ~= "table" or not message.action then
    -- gecersiz mesaj formati, yoksay
    goto continue
  end

  -- ============ KAYIT (REGISTER) ============
  if message.action == "register" then
    local username = message.username
    local password = message.password

    if not username or not password or username == "" or password == "" then
      rednet.send(id, {status = "error", msg = "Kullanici adi veya sifre bos olamaz"}, PROTOCOL)
    elseif accounts[username] then
      rednet.send(id, {status = "error", msg = "Bu kullanici adi zaten alinmis"}, PROTOCOL)
    else
      accounts[username] = {password = password, balance = 0}
      saveAccounts(accounts)
      logEvent("YENI_HESAP", username .. " tarafindan hesap acildi (Terminal: " .. id .. ")")
      rednet.send(id, {status = "ok", msg = "Hesap basariyla olusturuldu"}, PROTOCOL)
    end

  -- ============ GIRIS (LOGIN) ============
  elseif message.action == "login" then
    local username = message.username
    local password = message.password
    local acc = accounts[username]

    if acc and acc.password == password then
      clearFailedAttempts(username)
      logEvent("GIRIS", username .. " giris yapti (Terminal: " .. id .. ")")
      rednet.send(id, {status = "ok", balance = acc.balance}, PROTOCOL)
    else
      recordFailedAttempt(username, id)
      rednet.send(id, {status = "error", msg = "Kullanici adi veya sifre hatali"}, PROTOCOL)
    end

  -- ============ BAKIYE SORGULAMA ============
  elseif message.action == "balance" then
    local username = message.username
    local password = message.password
    local acc = accounts[username]

    if acc and acc.password == password then
      rednet.send(id, {status = "ok", balance = acc.balance}, PROTOCOL)
    else
      recordFailedAttempt(username, id)
      rednet.send(id, {status = "error", msg = "Kimlik dogrulama basarisiz"}, PROTOCOL)
    end

  -- ============ TRANSFER ============
  elseif message.action == "transfer" then
    local fromUser = message.username
    local password = message.password
    local toUser = message.to
    local amount = tonumber(message.amount)

    local fromAcc = accounts[fromUser]

    if not fromAcc or fromAcc.password ~= password then
      recordFailedAttempt(fromUser, id)
      rednet.send(id, {status = "error", msg = "Kimlik dogrulama basarisiz"}, PROTOCOL)
    elseif not accounts[toUser] then
      rednet.send(id, {status = "error", msg = "Alici bulunamadi: " .. tostring(toUser)}, PROTOCOL)
    elseif not amount or amount <= 0 then
      rednet.send(id, {status = "error", msg = "Gecersiz miktar"}, PROTOCOL)
    elseif fromAcc.balance < amount then
      rednet.send(id, {status = "error", msg = "Yetersiz bakiye"}, PROTOCOL)
    else
      fromAcc.balance = fromAcc.balance - amount
      accounts[toUser].balance = accounts[toUser].balance + amount
      saveAccounts(accounts)
      logEvent("TRANSFER", fromUser .. " -> " .. toUser .. " : " .. amount .. " birim")
      rednet.send(id, {status = "ok", msg = "Transfer basarili", newBalance = fromAcc.balance}, PROTOCOL)
    end

  -- ============ ADMIN KOMUTLARI ============
  elseif message.action == "admin_emergency" and id == ADMIN_ID then
    emergencyWipe("Admin tarafindan manuel tetiklendi")

  elseif message.action == "admin_setbalance" and id == ADMIN_ID then
    local target = message.username
    local newBalance = tonumber(message.amount)
    if accounts[target] and newBalance then
      accounts[target].balance = newBalance
      saveAccounts(accounts)
      logEvent("ADMIN_DUZELTME", target .. " bakiyesi " .. newBalance .. " olarak ayarlandi")
      rednet.send(id, {status = "ok", msg = "Bakiye guncellendi"}, PROTOCOL)
    end
  end

  ::continue::
end
