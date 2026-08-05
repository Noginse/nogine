# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Tam uygulama örneği: Auth, CRUD, Middleware, Doğrulama.

import std/[asyncdispatch, json, strutils]
import ../src/nogine
import ../src/nogine/arackatmanlar/kors as korsmod
import ../src/nogine/arackatmanlar/loglama as logmod
import ../src/nogine/arackatmanlar/hiz_siniri as hizmod

let uygulama = yeniNogine()

uygulama.kullan(korsmod.nogineKors())
uygulama.kullan(logmod.nogineLoglama())
uygulama.kullan(hizmod.nogineHizSiniriDakika(dakikada = 200))

# ---- Kimlik doğrulama ----
proc kimlikDogrula(istek: Istek, yanit: Yanit, sonraki: SonrakiProc): Future[void] {.async, gcsafe.} =
  let token = istek.baslik("Authorization")
  if not strutils.startsWith(token, "Bearer "):
    discard yanit.durum(401)
    await yanit.json(%*{"hata": "Yetkisiz: Bearer token gerekli"})
    return
  if token[7..^1] != "gizli-token-123":
    discard yanit.durum(403)
    await yanit.json(%*{"hata": "Geçersiz token"})
    return
  await sonraki()

# ---- Route handler'ları ----
proc anaH(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{"uygulama": "Nogine Örnek API", "versiyon": "0.1.0", "yazar": "noginse"})

proc girisH(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  let govde = istek.json()
  var kullaniciAdi = ""
  if govde.hasKey("kullanici_adi"):
    kullaniciAdi = govde["kullanici_adi"].getStr()
  if kullaniciAdi == "admin":
    await yanit.json(%*{"token": "gizli-token-123", "basari": true})
  else:
    discard yanit.durum(401)
    await yanit.json(%*{"hata": "Gecersiz kimlik"})

proc profilH(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{"kullanici": "admin", "email": "admin@nogine.dev"})

proc kullanicilerH(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{
    "kullanicilar": [%*{"id": "1", "isim": "Ali Veli"}, %*{"id": "2", "isim": "Ayşe Fatma"}],
    "toplam": 2
  })

proc kullaniciDetayH(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  let id = istek.param("id")
  if id == "0":
    discard yanit.durum(404)
    await yanit.json(%*{"hata": "Kullanıcı bulunamadı"})
    return
  await yanit.json(%*{"id": id, "isim": "Kullanıcı " & id})

proc kullaniciEkleH(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  let govde = istek.json()
  var dogrHatalar: seq[string] = @[]
  if not govde.hasKey("isim") or govde["isim"].getStr().len == 0:
    dogrHatalar.add("'isim' alani zorunludur")
  if not govde.hasKey("email") or govde["email"].getStr().len == 0:
    dogrHatalar.add("'email' alani zorunludur")
  elif "@" notin govde["email"].getStr():
    dogrHatalar.add("'email' gecerli bir e-posta olmalidir")
  if govde.hasKey("isim") and govde["isim"].getStr().len < 2:
    dogrHatalar.add("'isim' en az 2 karakter olmalidir")
  if dogrHatalar.len > 0:
    discard yanit.durum(422)
    await yanit.json(%*{"hatalar": dogrHatalar})
    return
  discard yanit.durum(201)
  await yanit.json(%*{"olusturuldu": true, "isim": govde["isim"].getStr()})

proc hata404H(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{"hata": "Sayfa bulunamadı", "yol": istek.yol})

# ---- Rota kaydı ----
uygulama.al("/", anaH)
uygulama.ekle("/giris", girisH)

uygulama.gruptaAl("/api/v1"):
  uygulama.al("/profil", kimlikDogrula, profilH)
  uygulama.al("/kullanicilar", kimlikDogrula, kullanicilerH)
  uygulama.al("/kullanicilar/:id", kimlikDogrula, kullaniciDetayH)
  uygulama.ekle("/kullanicilar", kimlikDogrula, kullaniciEkleH)

uygulama.hata(404, hata404H)

echo "Tam uygulama: http://localhost:8080"
echo "Örnek: curl -X POST http://localhost:8080/giris -d '{\"kullanici_adi\":\"admin\"}' -H 'Content-Type: application/json'"
waitFor uygulama.dinle(port = 8080)