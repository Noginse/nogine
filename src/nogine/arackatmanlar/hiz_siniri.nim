# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine hız sınırlama arackatmanı.
## IP tabanlı istek sayısı sınırlaması.

import std/[asyncdispatch, tables, times, json]
import ../tipler
import ../yanit

type
  HizSiniriAyarlari* = object
    pencere*: int
    maksimum*: int
    mesaj*: string

  IstemciDurumu = object
    istek: int
    sifirlanmaZamani: Time

var istemciTablosu {.global.} = initTable[string, IstemciDurumu]()

proc varsayilanHizAyarlari*(): HizSiniriAyarlari =
  HizSiniriAyarlari(
    pencere: 60,
    maksimum: 100,
    mesaj: "Çok fazla istek gönderdiniz. Lütfen bir süre bekleyin."
  )

proc nogineHizSiniri*(ayarlar: HizSiniriAyarlari): ArackatmanProc =
  result = proc(istek: Istek, yanit: Yanit, sonraki: SonrakiProc): Future[void] {.async, gcsafe.} =
    let ip = istek.istemciIp
    let simdi = getTime()

    {.gcsafe.}:
      if ip notin istemciTablosu:
        istemciTablosu[ip] = IstemciDurumu(
          istek: 0,
          sifirlanmaZamani: simdi + initDuration(seconds = ayarlar.pencere)
        )

      var durum = istemciTablosu[ip]
      if simdi >= durum.sifirlanmaZamani:
        durum.istek = 0
        durum.sifirlanmaZamani = simdi + initDuration(seconds = ayarlar.pencere)

      inc durum.istek
      istemciTablosu[ip] = durum

      let kalan = max(0, ayarlar.maksimum - durum.istek)
      yanit.basliklar["x-ratelimit-limit"] = $ayarlar.maksimum
      yanit.basliklar["x-ratelimit-remaining"] = $kalan
      yanit.basliklar["x-ratelimit-reset"] = $durum.sifirlanmaZamani.toUnix()

      if durum.istek > ayarlar.maksimum:
        yanit.durumKodu = 429
        yanit.basliklar["retry-after"] = $ayarlar.pencere
        yanit.basliklar["content-type"] = "application/json; charset=utf-8"
        yanit.govde = $(%*{"hata": ayarlar.mesaj, "bekleme": ayarlar.pencere})
        await yanit.gonder()
        return

    await sonraki()

proc nogineHizSiniri*(saniyede: int): ArackatmanProc =
  var ayarlar = varsayilanHizAyarlari()
  ayarlar.pencere = 1
  ayarlar.maksimum = saniyede
  result = nogineHizSiniri(ayarlar)

proc nogineHizSiniriDakika*(dakikada: int): ArackatmanProc =
  var ayarlar = varsayilanHizAyarlari()
  ayarlar.pencere = 60
  ayarlar.maksimum = dakikada
  result = nogineHizSiniri(ayarlar)

proc nogineHizSiniriSaat*(saatte: int): ArackatmanProc =
  var ayarlar = varsayilanHizAyarlari()
  ayarlar.pencere = 3600
  ayarlar.maksimum = saatte
  result = nogineHizSiniri(ayarlar)