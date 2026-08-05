# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine statik dosya sunumu arackatmanı.

import std/[asyncdispatch, os, strutils, times, tables]
import ../tipler
import ../yanit
import ../yardimcilar

type
  StatikAyarlari* = object
    kok*: string
    url_prefix*: string
    onbellek*: bool
    onbellekSuresi*: int
    dizinListesi*: bool
    varsayilanSayfa*: string

proc varsayilanStatikAyarlari*(kok: string = "public"): StatikAyarlari =
  StatikAyarlari(
    kok: kok,
    url_prefix: "/statik",
    onbellek: true,
    onbellekSuresi: 86400,
    dizinListesi: false,
    varsayilanSayfa: "index.html"
  )

proc guvenliYol(kok: string, istemciYol: string): string =
  let tam = normalizedPath(kok / istemciYol)
  if not tam.startsWith(kok): result = ""
  else: result = tam

proc dizinListesiHtml(yol: string, urlYol: string): string =
  result = "<!DOCTYPE html><html lang=\"tr\"><head><meta charset=\"UTF-8\">" &
           "<title>Dizin: " & urlYol & "</title></head><body>" &
           "<h1>Dizin: " & urlYol & "</h1><hr><ul>"
  if urlYol != "/":
    result &= "<li><a href=\"../\">../</a></li>"
  for girdi in walkDir(yol):
    let isim = extractFilename(girdi.path)
    let ek = if girdi.kind == pcDir: "/" else: ""
    result &= "<li><a href=\"" & isim & ek & "\">" & isim & ek & "</a></li>"
  result &= "</ul><hr><small>Nogine - Created by noginse</small></body></html>"

proc nogineStatik*(ayarlar: StatikAyarlari): ArackatmanProc =
  result = proc(istek: Istek, yanit: Yanit, sonraki: SonrakiProc): Future[void] {.async, gcsafe.} =
    if istek.metod != hmGET and istek.metod != hmHEAD:
      await sonraki()
      return

    if not istek.yol.startsWith(ayarlar.url_prefix):
      await sonraki()
      return

    let goreli = istek.yol[ayarlar.url_prefix.len..^1]
    let dosyaYolu = guvenliYol(absolutePath(ayarlar.kok), goreli)

    if dosyaYolu.len == 0:
      yanit.durumKodu = 403
      yanit.basliklar["content-type"] = "application/json; charset=utf-8"
      yanit.govde = "{\"hata\": \"Erişim reddedildi\"}"
      await yanit.gonder()
      return

    if dirExists(dosyaYolu):
      let varsayilan = dosyaYolu / ayarlar.varsayilanSayfa
      if fileExists(varsayilan):
        let uzanti = splitFile(varsayilan).ext
        yanit.basliklar["content-type"] = mimeHesapla(uzanti)
        yanit.govde = readFile(varsayilan)
        if ayarlar.onbellek:
          yanit.basliklar["cache-control"] = "public, max-age=" & $ayarlar.onbellekSuresi
        await yanit.gonder()
      elif ayarlar.dizinListesi:
        yanit.basliklar["content-type"] = "text/html; charset=utf-8"
        yanit.govde = dizinListesiHtml(dosyaYolu, istek.yol)
        await yanit.gonder()
      else:
        yanit.durumKodu = 403
        yanit.basliklar["content-type"] = "application/json; charset=utf-8"
        yanit.govde = "{\"hata\": \"Dizin listeleme kapalı\"}"
        await yanit.gonder()
      return

    if not fileExists(dosyaYolu):
      await sonraki()
      return

    let sonDegisiklik = getLastModificationTime(dosyaYolu)
    let etag = "\"" & $sonDegisiklik.toUnix() & "\""
    let istemciEtag = istek.basliklar.getOrDefault("if-none-match", "")
    if istemciEtag == etag:
      yanit.durumKodu = 304
      await yanit.gonder()
      return

    let uzanti = splitFile(dosyaYolu).ext
    yanit.basliklar["content-type"] = mimeHesapla(uzanti)
    yanit.basliklar["etag"] = etag
    yanit.basliklar["last-modified"] = httpZamani()

    if ayarlar.onbellek:
      yanit.basliklar["cache-control"] = "public, max-age=" & $ayarlar.onbellekSuresi
    else:
      yanit.basliklar["cache-control"] = "no-cache, no-store, must-revalidate"

    if istek.metod == hmHEAD:
      yanit.basliklar["content-length"] = $int(getFileSize(dosyaYolu))
      await yanit.gonder()
    else:
      yanit.govde = readFile(dosyaYolu)
      await yanit.gonder()

proc nogineStatik*(kok: string, prefix: string = "/statik"): ArackatmanProc =
  var ayarlar = varsayilanStatikAyarlari(kok)
  ayarlar.url_prefix = prefix
  result = nogineStatik(ayarlar)