# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine - A Nim Web Framework
## Ana modül. Tüm bileşenleri bir araya getirir.
##
## Kullanım:
## ```nim
## import nogine
##
## let uygulama = yeniNogine()
##
## uygulama.al("/") proc(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
##   await yanit.json(%*{"mesaj": "Merhaba Dünya"})
##
## uygulama.dinle(port = 8080)
## ```

import std/[asyncnet, asyncdispatch, tables, strutils]
import nogine/tipler
import nogine/hatalar
import nogine/istek
import nogine/yanit
import nogine/yonlendirici
import nogine/arackatman
import nogine/websocket
import nogine/dogrulama
import nogine/sablon

export tipler
export hatalar
export istek
export yanit
export yonlendirici
export arackatman
export websocket
export dogrulama
export sablon

## Yeni Nogine uygulaması oluştur
proc yeniNogine*(): Nogine =
  result = Nogine(
    rotalar: @[],
    wsRotalar: @[],
    globalArackatmanlar: @[],
    hataIsleyicileri: initTable[int, IsleyiciProc](),
    varsayilanBasliklar: initTable[string, string](),
    wsbaglantilari: initTable[string, WsBaglanti](),
    aktifMi: false,
    prefix: ""
  )
  result.varsayilanBasliklar["x-powered-by"] = "Nogine"

## Route ekle (iç fonksiyon)
proc rotaEkle(uygulama: Nogine, metod: HttpMetod, yol: string,
              arackatmanlar: seq[ArackatmanProc], isleyici: IsleyiciProc) =
  let tamYol = uygulama.prefix & yol
  uygulama.rotalar.add(yeniRota(metod, tamYol, isleyici, arackatmanlar))

## GET route ekle
proc al*(uygulama: Nogine, yol: string, isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmGET, yol, @[], isleyici)

proc al*(uygulama: Nogine, yol: string, arackatman: ArackatmanProc,
         isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmGET, yol, @[arackatman], isleyici)

proc al*(uygulama: Nogine, yol: string, arackatmanlar: seq[ArackatmanProc],
         isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmGET, yol, arackatmanlar, isleyici)

## POST route ekle
proc ekle*(uygulama: Nogine, yol: string, isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmPOST, yol, @[], isleyici)

proc ekle*(uygulama: Nogine, yol: string, arackatman: ArackatmanProc,
           isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmPOST, yol, @[arackatman], isleyici)

proc ekle*(uygulama: Nogine, yol: string, arackatmanlar: seq[ArackatmanProc],
           isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmPOST, yol, arackatmanlar, isleyici)

## PUT route ekle
proc guncelle*(uygulama: Nogine, yol: string, isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmPUT, yol, @[], isleyici)

proc guncelle*(uygulama: Nogine, yol: string, arackatman: ArackatmanProc,
               isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmPUT, yol, @[arackatman], isleyici)

## DELETE route ekle
proc sil*(uygulama: Nogine, yol: string, isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmDELETE, yol, @[], isleyici)

proc sil*(uygulama: Nogine, yol: string, arackatman: ArackatmanProc,
          isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmDELETE, yol, @[arackatman], isleyici)

## PATCH route ekle
proc yama*(uygulama: Nogine, yol: string, isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmPATCH, yol, @[], isleyici)

## OPTIONS route ekle
proc secenekler*(uygulama: Nogine, yol: string, isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmOPTIONS, yol, @[], isleyici)

## HEAD route ekle
proc bas*(uygulama: Nogine, yol: string, isleyici: IsleyiciProc) =
  uygulama.rotaEkle(hmHEAD, yol, @[], isleyici)

## Global middleware ekle
proc kullan*(uygulama: Nogine, arackatman: ArackatmanProc) =
  uygulama.globalArackatmanlar.add(arackatman)

## Hata handler'ı kaydet
proc hata*(uygulama: Nogine, kod: int, isleyici: IsleyiciProc) =
  uygulama.hataIsleyicileri[kod] = isleyici

## WebSocket route ekle
proc websocket*(uygulama: Nogine, yol: string,
                isleyici: proc(baglanti: WsBaglanti): Future[void] {.closure, gcsafe.}) =
  uygulama.wsRotalar.add(WsRotaTanimi(yol: yol, isleyici: isleyici))

## Grup prefix desteği
proc grup*(uygulama: Nogine, prefix: string, islemler: proc()) =
  let eskiPrefix = uygulama.prefix
  uygulama.prefix = eskiPrefix & prefix
  islemler()
  uygulama.prefix = eskiPrefix

## Kolaylık: gruptaAl ile route gruplama
template gruptaAl*(uygulama: Nogine, onekStr: string, islemler: untyped) =
  let eskiOnekKorunan = uygulama.prefix
  uygulama.prefix = eskiOnekKorunan & onekStr
  islemler
  uygulama.prefix = eskiOnekKorunan

## Varsayılan başlık ekle
proc baslikEkle*(uygulama: Nogine, isim: string, deger: string) =
  uygulama.varsayilanBasliklar[isim.toLowerAscii()] = deger

## WebSocket isteği mi?
proc wsIstekMi(istek: Istek): bool =
  let upgrade = istek.basliklar.getOrDefault("upgrade", "")
  result = upgrade.toLowerAscii() == "websocket"

## Bir WebSocket bağlantısını işle
proc wsBaglantiIsle(uygulama: Nogine, soket: AsyncSocket,
                    istek: Istek): Future[void] {.async.} =
  for wsRota in uygulama.wsRotalar:
    if wsRota.yol == istek.yol:
      let elSikismasi = await wsElSikismasi(soket, istek)
      if elSikismasi:
        let baglanti = yeniBaglanti(soket)
        uygulama.wsbaglantilari[baglanti.id] = baglanti
        await wsRota.isleyici(baglanti)
        await baglantiYonet(baglanti)
        uygulama.wsbaglantilari.del(baglanti.id)
      return

## Tek bir HTTP isteğini işle
proc istekIsle(uygulama: Nogine, soket: AsyncSocket): Future[void] {.async.} =
  var gelen: Istek = nil
  var cikis: Yanit = nil
  try:
    gelen = await istekOku(soket)
    cikis = yeniYanit(soket)

    # Varsayılan başlıkları ekle
    for isim, deger in uygulama.varsayilanBasliklar:
      cikis.basliklar[isim] = deger

    # WebSocket isteği mi?
    if wsIstekMi(gelen):
      await uygulama.wsBaglantiIsle(soket, gelen)
      return

    # Route'u bul
    var params = initTable[string, string]()
    let rotaIndeks = rotaBul(uygulama.rotalar, gelen.metod, gelen.yol, params)

    if rotaIndeks < 0:
      # 404
      if 404 in uygulama.hataIsleyicileri:
        gelen.params = params
        await zincirleCalistir(uygulama.globalArackatmanlar,
                               uygulama.hataIsleyicileri[404], gelen, cikis)
      else:
        cikis.durumKodu = 404
        cikis.basliklar["content-type"] = "application/json; charset=utf-8"
        cikis.govde = "{\"hata\": \"Rota bulunamadi: " & gelen.yol & "\"}"
        await cikis.gonder()
      return

    # Route bulundu
    gelen.params = params
    let rota = uygulama.rotalar[rotaIndeks]

    # Global + route arackatmanlarını birleştir
    var tumArackatmanlar = uygulama.globalArackatmanlar & rota.arackatmanlar
    await zincirleCalistir(tumArackatmanlar, rota.isleyici, gelen, cikis)

    # Yanıt gönderilmediyse 204 dön
    if not cikis.gonderildi:
      await cikis.bos()

  except GecersizIstekHatasi as e:
    if not isNil(cikis) and not cikis.gonderildi:
      cikis.durumKodu = 400
      cikis.basliklar["content-type"] = "application/json; charset=utf-8"
      cikis.govde = "{\"hata\": \"" & e.msg & "\"}"
      await cikis.gonder()
  except Exception as e:
    if not isNil(uygulama.genelHataIsleyici) and not isNil(gelen) and not isNil(cikis):
      await uygulama.genelHataIsleyici(gelen, cikis, e)
    elif not isNil(cikis) and 500 in uygulama.hataIsleyicileri:
      await uygulama.hataIsleyicileri[500](gelen, cikis)
    elif not isNil(cikis) and not cikis.gonderildi:
      cikis.durumKodu = 500
      cikis.basliklar["content-type"] = "application/json; charset=utf-8"
      cikis.govde = "{\"hata\": \"Sunucu hatasi\"}"
      await cikis.gonder()
  finally:
    try:
      soket.close()
    except:
      discard

## Sunucuyu başlat (async)
proc dinle*(uygulama: Nogine, port: int = 8080,
            host: string = "0.0.0.0"): Future[void] {.async.} =
  let sunucu = newAsyncSocket()
  sunucu.setSockOpt(OptReuseAddr, true)
  sunucu.bindAddr(Port(port), host)
  sunucu.listen()

  uygulama.aktifMi = true
  echo "╔══════════════════════════════════════╗"
  echo "║   Nogine - A Nim Web Framework       ║"
  echo "║   Created by noginse                 ║"
  echo "╚══════════════════════════════════════╝"
  echo "  Sunucu başlatıldı: http://" & host & ":" & $port
  echo "  Rotalar: " & $uygulama.rotalar.len
  echo ""

  while uygulama.aktifMi:
    let soket = await sunucu.accept()
    asyncCheck istekIsle(uygulama, soket)

## Sunucuyu bloklamalı başlat
proc dinleBlokla*(uygulama: Nogine, port: int = 8080, host: string = "0.0.0.0") =
  waitFor uygulama.dinle(port, host)