# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine yanıt sıkıştırma arackatmanı.
## zippy paketi kuruluysa gerçek gzip/deflate sıkıştırması yapar.
## Kurulum: nimble install zippy
## zippy yoksa Vary başlığını ayarlar, sıkıştırma yapmaz (graceful degradation).

import std/[asyncdispatch, strutils, tables]
import ../tipler

# zippy paketini koşullu olarak import et
when defined(zippyAvailable):
  import zippy

type
  SikistirmaAyarlari* = object
    minBoyut*: int                    ## Sıkıştırma için minimum boyut (byte)
    seviye*: int                      ## Sıkıştırma seviyesi (1=hızlı, 9=en iyi)
    sikistirilanTipler*: seq[string]  ## Sıkıştırılacak MIME tipleri

proc varsayilanSikistirmaAyarlari*(): SikistirmaAyarlari =
  SikistirmaAyarlari(
    minBoyut: 860,  ## 860B altı sıkıştırılmaz (HTTP overhead'den küçük getiri)
    seviye: 6,
    sikistirilanTipler: @[
      "text/html",
      "text/css",
      "text/plain",
      "text/javascript",
      "application/javascript",
      "application/json",
      "application/xml",
      "image/svg+xml"
    ]
  )

proc sikistirabilirMi(icerikTipi: string, tipler: seq[string]): bool =
  for tip in tipler:
    if icerikTipi.startsWith(tip):
      return true

proc gzipDestekliMi(istek: Istek): bool =
  let accept = istek.basliklar.getOrDefault("accept-encoding", "")
  result = "gzip" in accept

proc deflateDestekliMi(istek: Istek): bool =
  let accept = istek.basliklar.getOrDefault("accept-encoding", "")
  result = "deflate" in accept

## Sıkıştırma arackatmanı (zippy ile gerçek gzip/deflate)
proc nogineSikistirma*(ayarlar: SikistirmaAyarlari = varsayilanSikistirmaAyarlari()): ArackatmanProc =
  result = proc(istek: Istek, yanit: Yanit, sonraki: SonrakiProc): Future[void] {.async, gcsafe.} =
    await sonraki()

    # Zaten sıkıştırılmış veya küçük
    if yanit.basliklar.hasKey("content-encoding"):
      return
    if yanit.govde.len < ayarlar.minBoyut:
      return

    # Sıkıştırılabilir içerik tipi mi?
    let icerikTipi = yanit.basliklar.getOrDefault("content-type", "")
    if not sikistirabilirMi(icerikTipi, ayarlar.sikistirilanTipler):
      return

    # Vary başlığını her zaman ekle
    yanit.basliklar["vary"] = "Accept-Encoding"

    when defined(zippyAvailable):
      # Gerçek sıkıştırma (zippy mevcut)
      if gzipDestekliMi(istek):
        try:
          let sikistirilmis = compress(yanit.govde, BestSpeed, dfGzip)
          # Sıkıştırma gerçekten küçülttü mü?
          if sikistirilmis.len < yanit.govde.len:
            yanit.govde = sikistirilmis
            yanit.basliklar["content-encoding"] = "gzip"
            yanit.basliklar["content-length"] = $yanit.govde.len
        except:
          discard  # Sıkıştırma başarısız, orijinali gönder
      elif deflateDestekliMi(istek):
        try:
          let sikistirilmis = compress(yanit.govde, BestSpeed, dfDeflate)
          if sikistirilmis.len < yanit.govde.len:
            yanit.govde = sikistirilmis
            yanit.basliklar["content-encoding"] = "deflate"
            yanit.basliklar["content-length"] = $yanit.govde.len
        except:
          discard
    else:
      # zippy kurulu değil - sadece Vary başlığı eklendi, içerik ham gönderilir
      # `nimble install zippy` ile gerçek sıkıştırma aktif edilebilir
      discard

## Kısa syntax (varsayılan ayarlarla)
proc nogineSikistirma*(): ArackatmanProc =
  result = nogineSikistirma(varsayilanSikistirmaAyarlari())