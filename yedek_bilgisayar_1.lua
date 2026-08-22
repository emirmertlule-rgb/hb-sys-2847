-- ==========================================
-- HANEDANOGULLARI YEDEK BILGISAYAR
-- Acil durumda banka verilerini alip saklar
-- Bu bilgisayari MERKEZ BANKA'dan FARKLI ve
-- GIZLI bir yerde tut!
-- ==========================================

local PROTOCOL = "j7yq39j4gwpoku9h38w409geoTYUHIJ9u0UR-troglfd-2847"
local MODEM_SIDE = "right"

rednet.open(MODEM_SIDE)

print("==========================================")
print("  HANEDANOGULLARI YEDEK SISTEMI")
print("==========================================")
print("Bilgisayar ID: " .. os.getComputerID())
print("Bu ID'yi merkez_banka.lua icindeki")
print("BACKUP_ID degiskenine yaz!")
print("")
print("Yedek bekleniyor...")
print("==========================================")

while true do
  local id, message = rednet.receive(PROTOCOL)

  if type(message) == "table" and message.action == "restore_backup" then
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local filename = "yedek_" .. timestamp .. ".txt"

    local f = fs.open(filename, "w")
    f.write(message.data)
    f.close()

    print("[" .. os.date("%H:%M:%S") .. "] Yedek alindi ve kaydedildi: " .. filename)
  end
end
