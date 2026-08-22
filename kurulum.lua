-- ==========================================
-- HANEDANOGULLARI KURULUM ARACI
-- Bu script, hangi bilgisayar tipini kurmak
-- istedigini sorar ve dogru dosyalari indirir.
-- Creative test icin hizli kurulum.
-- ==========================================

local BASE_URL = "https://raw.githubusercontent.com/emirmertlule-rgb/hb-sys-2847/refs/heads/main/"

local FILES = {
  ["merkez_banka.lua"] = "merkez_banka.lua",
  ["terminal.lua"] = "terminal.lua",
  ["admin_araci.lua"] = "admin_araci.lua",
  ["atm.lua"] = "atm.lua",
  ["yedek_bilgisayar.lua"] = "yedek_bilgisayar.lua",
}

print("==========================================")
print("  HANEDANOGULLARI KURULUM ARACI")
print("==========================================")
print("")
print("Hangi bilgisayari kurmak istiyorsun?")
print("1) Merkez Banka")
print("2) Terminal (kullanici / pocket computer)")
print("3) Admin Araci")
print("4) ATM")
print("5) Yedek Bilgisayar")
print("6) HEPSINI indir (test icin)")
print("")
write("Secim: ")
local choice = read()

local function download(filename)
  local url = BASE_URL .. filename
  print("Indiriliyor: " .. filename .. " ...")
  local h = http.get(url)
  if h then
    local content = h.readAll()
    h.close()
    local f = fs.open(filename, "w")
    f.write(content)
    f.close()
    print("  Tamam: " .. filename)
    return true
  else
    print("  HATA: " .. filename .. " indirilemedi")
    return false
  end
end

if choice == "1" then
  download("merkez_banka.lua")
elseif choice == "2" then
  download("terminal.lua")
elseif choice == "3" then
  download("admin_araci.lua")
elseif choice == "4" then
  download("atm.lua")
elseif choice == "5" then
  download("yedek_bilgisayar.lua")
elseif choice == "6" then
  for name, _ in pairs(FILES) do
    download(name)
  end
else
  print("Gecersiz secim.")
end

print("")
print("Kurulum tamamlandi.")
print("Dosyalari duzenlemek icin 'edit <dosyaadi>' kullan")
print("(MODEM_SIDE, BANK_ID gibi ayarlari kontrol etmeyi unutma)")
