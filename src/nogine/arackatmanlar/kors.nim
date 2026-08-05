# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine CORS (Cross-Origin Resource Sharing) arackatmanı.

import std/[asyncdispatch, strutils, tables]
import ../tipler
import ../yanit as yanit_mod

type
  KorsAyarlari* = object
    izinVerilenKaynaklar*: seq[string]
    izinVerilenMetodlar*: seq[string]
    izinVerilenBasliklar*: seq[string]
    acigaCikarilanBasliklar*: seq[string]
    kimlikBilgisiIzin*: bool
    onYuklemeSuresi*: int

proc varsayilanKorsAyarlari*(): KorsAyarlari =
  KorsAyarlari(
    izinVerilenKaynaklar: @["*"],
    izinVerilenMetodlar: @["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"],
    izinVerilenBasliklar: @["Content-Type", "Authorization", "X-Requested-With",
                            "Accept", "Origin", "Access-Control-Request-Method",
                            "Access-Control-Request-Headers"],
    acigaCikarilanBasliklar: @["Content-Length", "Content-Range"],
    kimlikBilgisiIzin: true,
    onYuklemeSuresi: 86400
  )

proc kaynakIzinli(kaynak: string, izinVerilenler: seq[string]): bool =
  if "*" in izinVerilenler: return true
  for izinli in izinVerilenler:
    if izinli == kaynak: return true
    if izinli.startsWith("*."):
      let domain = izinli[2..^1]
      if kaynak.endsWith("." & domain) or kaynak == domain: return true
  result = false

proc nogineKors*(ayarlar: KorsAyarlari): ArackatmanProc =
  result = proc(istek: Istek, yanit: Yanit, sonraki: SonrakiProc): Future[void] {.async, gcsafe.} =
    let kaynak = istek.basliklar.getOrDefault("origin", "")
    if kaynak.len > 0:
      if kaynakIzinli(kaynak, ayarlar.izinVerilenKaynaklar):
        if "*" in ayarlar.izinVerilenKaynaklar and not ayarlar.kimlikBilgisiIzin:
          yanit.basliklar["access-control-allow-origin"] = "*"
        else:
          yanit.basliklar["access-control-allow-origin"] = kaynak
          yanit.basliklar["vary"] = "Origin"
        if ayarlar.kimlikBilgisiIzin:
          yanit.basliklar["access-control-allow-credentials"] = "true"
        if ayarlar.acigaCikarilanBasliklar.len > 0:
          yanit.basliklar["access-control-expose-headers"] =
            ayarlar.acigaCikarilanBasliklar.join(", ")

    if istek.metod == hmOPTIONS:
      yanit.basliklar["access-control-allow-methods"] = ayarlar.izinVerilenMetodlar.join(", ")
      yanit.basliklar["access-control-allow-headers"] = ayarlar.izinVerilenBasliklar.join(", ")
      yanit.basliklar["access-control-max-age"] = $ayarlar.onYuklemeSuresi
      yanit.durumKodu = 204
      yanit.govde = ""
      await yanit.gonder()
      return

    await sonraki()

proc nogineKors*(): ArackatmanProc =
  result = nogineKors(varsayilanKorsAyarlari())

proc nogineKors*(izinVerilenKaynaklar: seq[string]): ArackatmanProc =
  var ayarlar = varsayilanKorsAyarlari()
  ayarlar.izinVerilenKaynaklar = izinVerilenKaynaklar
  result = nogineKors(ayarlar)