# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Basit REST API örneği.
## Çalıştırmak için: nim c -r examples/basit_api.nim

import std/[asyncdispatch, json]
import ../src/nogine
import ../src/nogine/arackatmanlar/kors as korsmod
import ../src/nogine/arackatmanlar/loglama as logmod

let uygulama = yeniNogine()

uygulama.kullan(korsmod.nogineKors())
uygulama.kullan(logmod.nogineLoglama())

proc anaSayfa(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{
    "mesaj": "Nogine - A Nim Web Framework",
    "yazar": "noginse",
    "versiyon": "0.1.0"
  })

proc saglikKontrol(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{"durum": "tamam"})

proc kullaniciBul(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  let id = istek.param("id")
  await yanit.json(%*{"id": id, "isim": "Örnek Kullanıcı"})

proc kullaniciOlustur(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  let govde = istek.json()
  discard yanit.durum(201)
  await yanit.json(%*{"olusturuldu": true, "isim": govde["isim"].getStr()})

proc sorguIsle(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{
    "sayfa": istek.sorgu("sayfa", "1"),
    "boyut": istek.sorgu("boyut", "10")
  })

proc hata404(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{"hata": "Sayfa bulunamadı", "yol": istek.yol})

uygulama.al("/", anaSayfa)
uygulama.al("/saglik", saglikKontrol)
uygulama.al("/kullanicilar/:id", kullaniciBul)
uygulama.ekle("/kullanicilar", kullaniciOlustur)
uygulama.al("/sorgu", sorguIsle)
uygulama.hata(404, hata404)

echo "Basit API: http://localhost:8080"
echo "Test: curl http://localhost:8080/"
echo "Test: curl http://localhost:8080/kullanicilar/42"
waitFor uygulama.dinle(port = 8080)