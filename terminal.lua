-- ==========================================
-- HANEDANOGULLARI BANKA TERMINALI
-- Pocket Computer / Esnaf Terminali Istemci Kodu
-- ==========================================

local PROTOCOL = "j7yq39j4gwpoku9h38w409geoTYUHIJ9u0UR-troglfd-2847"
local BANK_ID = nil -- Merkez Banka'nin bilgisayar ID'sini buraya yaz (kurulunca ogrenilir)
local MODEM_SIDE = "back" -- pocket computer'da modem genelde "back" tarafinda olur

rednet.open(MODEM_SIDE)

local currentUser = nil
local currentPass = nil

-- ==========================================
-- SES EFEKTLERI (Speaker varsa)
-- ==========================================

local function playSuccess()
  local speaker = peripheral.find("speaker")
  if speaker then
    speaker.playSound("minecraft:entity.experience_orb.pickup", 1, 1)
  end
end

local function playError()
  local speaker = peripheral.find("speaker")
  if speaker then
    speaker.playSound("minecraft:block.note_block.bass", 1, 0.5)
  end
end

-- ==========================================
-- BANKA ILE ILETISIM
-- ==========================================

local function sendAndWait(msg, timeout)
  rednet.send(BANK_ID, msg, PROTOCOL)
  local id, response = rednet.receive(PROTOCOL, timeout or 5)
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

local function printHeader(title)
  term.setTextColor(colors.yellow)
  print("==========================================")
  print("  " .. title)
  print("==========================================")
  term.setTextColor(colors.white)
end

local function waitKey()
  print("")
  print("(devam etmek icin bir tusa bas)")
  os.pullEvent("key")
end

-- ==========================================
-- MENU FONKSIYONLARI
-- ==========================================

local function registerScreen()
  clearScreen()
  printHeader("YENI HESAP AC")

  write("Kullanici adi: ")
  local user = read()
  write("Sifre: ")
  local pass = read("*")

  local response = sendAndWait({action="register", username=user, password=pass})

  if response then
    if response.status == "ok" then
      playSuccess()
      print("")
      print("Hesap olusturuldu! Simdi giris yapabilirsin.")
    else
      playError()
      print("")
      print("Hata: " .. response.msg)
    end
  else
    playError()
    print("")
    print("Banka yanit vermedi. Baglanti sorunu olabilir.")
  end
  waitKey()
end

local function loginScreen()
  clearScreen()
  printHeader("GIRIS YAP")

  write("Kullanici adi: ")
  local user = read()
  write("Sifre: ")
  local pass = read("*")

  local response = sendAndWait({action="login", username=user, password=pass})

  if response then
    if response.status == "ok" then
      playSuccess()
      currentUser = user
      currentPass = pass
      return true
    else
      playError()
      print("")
      print("Hata: " .. response.msg)
      waitKey()
      return false
    end
  else
    playError()
    print("")
    print("Banka yanit vermedi. Baglanti sorunu olabilir.")
    waitKey()
    return false
  end
end

local function showBalance()
  local response = sendAndWait({action="balance", username=currentUser, password=currentPass})
  clearScreen()
  printHeader("BAKIYE")
  if response and response.status == "ok" then
    print("")
    print("Kullanici: " .. currentUser)
    print("Bakiye: " .. response.balance .. " birim")
  else
    playError()
    print("Bakiye sorgulanamadi.")
  end
  waitKey()
end

local function transferScreen()
  clearScreen()
  printHeader("TRANSFER YAP")

  write("Alici kullanici adi: ")
  local to = read()
  write("Miktar: ")
  local amount = tonumber(read())

  if not amount then
    print("Gecersiz miktar!")
    waitKey()
    return
  end

  local response = sendAndWait({action="transfer", username=currentUser, password=currentPass, to=to, amount=amount})

  clearScreen()
  printHeader("TRANSFER SONUCU")
  if response and response.status == "ok" then
    playSuccess()
    print("")
    print("Transfer basarili!")
    print("Yeni bakiyen: " .. response.newBalance .. " birim")
  else
    playError()
    print("")
    print("Hata: " .. (response and response.msg or "Baglanti sorunu"))
  end
  waitKey()
end

-- ==========================================
-- ANA MENU (giris yaptiktan sonra)
-- ==========================================

local function mainMenu()
  while true do
    clearScreen()
    printHeader("HANEDANOGULLARI BANKASI")
    print("")
    print("Hosgeldin, " .. currentUser)
    print("")
    print("1) Bakiye Goruntule")
    print("2) Transfer Yap")
    print("3) Cikis Yap")
    print("")
    write("Secim: ")
    local choice = read()

    if choice == "1" then
      showBalance()
    elseif choice == "2" then
      transferScreen()
    elseif choice == "3" then
      currentUser = nil
      currentPass = nil
      return
    end
  end
end

-- ==========================================
-- BASLANGIC MENUSU
-- ==========================================

local function startScreen()
  clearScreen()
  printHeader("HANEDANOGULLARI BANKASI")
  print("")
  print("1) Giris Yap")
  print("2) Yeni Hesap Ac")
  print("3) Kapat")
  print("")
  write("Secim: ")
  return read()
end

-- ==========================================
-- ANA DONGU
-- ==========================================

if not BANK_ID then
  print("HATA: BANK_ID ayarlanmamis!")
  print("Bu dosyanin basindaki BANK_ID degiskenine")
  print("Merkez Banka bilgisayarinin ID'sini yaz.")
else
  while true do
    local choice = startScreen()

    if choice == "1" then
      if loginScreen() then
        mainMenu()
      end
    elseif choice == "2" then
      registerScreen()
    elseif choice == "3" then
      clearScreen()
      print("Hoscakal!")
      break
    end
  end
end
