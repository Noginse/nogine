# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine yardımcı fonksiyonları.
## URL kodlama/çözme, MIME tipi tespiti, UUID üretme ve diğer araçlar.

import std/[strutils, tables, times, random, base64, uri]

## URL decode
proc urlCoz*(s: string): string =
  result = decodeUrl(s)

## URL encode
proc urlKodla*(s: string): string =
  result = encodeUrl(s)

## Sorgu dizesini parse et
proc sorguyuCozumle*(sorgu: string): Table[string, string] =
  result = initTable[string, string]()
  if sorgu.len == 0:
    return
  let temiz = if sorgu.startsWith("?"): sorgu[1..^1] else: sorgu
  for cift in temiz.split("&"):
    let bolumler = cift.split("=", 1)
    if bolumler.len == 2:
      result[urlCoz(bolumler[0])] = urlCoz(bolumler[1])
    elif bolumler.len == 1 and bolumler[0].len > 0:
      result[urlCoz(bolumler[0])] = ""

## Çerez başlığını parse et
proc cerezleriCozumle*(cerezBasligi: string): Table[string, string] =
  result = initTable[string, string]()
  for cift in cerezBasligi.split(";"):
    let temiz = cift.strip()
    let bolumler = temiz.split("=", 1)
    if bolumler.len == 2:
      result[bolumler[0].strip()] = bolumler[1].strip()

## Rastgele UUID üret (v4)
proc uuidUret*(): string =
  randomize()
  const hex = "0123456789abcdef"
  var d: array[32, char]
  for i in 0..<32:
    d[i] = hex[rand(15)]
  result = newString(36)
  var pos = 0
  for i in 0..7:   result[pos] = d[i]; inc pos
  result[pos] = '-'; inc pos
  for i in 8..11:  result[pos] = d[i]; inc pos
  result[pos] = '-'; inc pos
  result[pos] = '4'; inc pos
  for i in 12..14: result[pos] = d[i]; inc pos
  result[pos] = '-'; inc pos
  for i in 15..18: result[pos] = d[i]; inc pos
  result[pos] = '-'; inc pos
  for i in 19..30: result[pos] = d[i]; inc pos

## MIME tipini dosya uzantısından belirle
proc mimeHesapla*(uzanti: string): string =
  case uzanti.toLowerAscii()
  of ".html", ".htm": "text/html; charset=utf-8"
  of ".css":          "text/css; charset=utf-8"
  of ".js":           "application/javascript; charset=utf-8"
  of ".json":         "application/json; charset=utf-8"
  of ".xml":          "application/xml; charset=utf-8"
  of ".txt":          "text/plain; charset=utf-8"
  of ".png":          "image/png"
  of ".jpg", ".jpeg": "image/jpeg"
  of ".gif":          "image/gif"
  of ".svg":          "image/svg+xml"
  of ".ico":          "image/x-icon"
  of ".webp":         "image/webp"
  of ".pdf":          "application/pdf"
  of ".zip":          "application/zip"
  of ".tar":          "application/x-tar"
  of ".gz":           "application/gzip"
  of ".mp3":          "audio/mpeg"
  of ".mp4":          "video/mp4"
  of ".webm":         "video/webm"
  of ".woff":         "font/woff"
  of ".woff2":        "font/woff2"
  of ".ttf":          "font/ttf"
  of ".otf":          "font/otf"
  of ".wasm":         "application/wasm"
  else:               "application/octet-stream"

## HTTP zaman formatı (RFC 7231)
proc httpZamani*(): string =
  let n = now().utc
  result = format(n, "ddd, dd MMM yyyy HH:mm:ss") & " GMT"

## Base64 kodla
proc base64Kodla*(s: string): string =
  result = encode(s)

## Base64 çöz
proc base64Coz*(s: string): string =
  result = decode(s)

## String'i güvenli integer'a dönüştür
proc guvenliInt*(s: string, varsayilan: int = 0): int =
  try:
    result = parseInt(s)
  except ValueError:
    result = varsayilan

## İki string'i sabit sürede karşılaştır (timing attack önlemi)
proc sabitKarsilastir*(a, b: string): bool =
  if a.len != b.len:
    return false
  var fark = 0
  for i in 0..<a.len:
    fark = fark or (ord(a[i]) xor ord(b[i]))
  result = fark == 0

## Boyutu insan dostu formata çevir
proc boyutBicimlendir*(boyut: int): string =
  if boyut < 1024:
    result = $boyut & " B"
  elif boyut < 1024 * 1024:
    result = $(boyut div 1024) & " KB"
  elif boyut < 1024 * 1024 * 1024:
    result = $(boyut div (1024 * 1024)) & " MB"
  else:
    result = $(boyut div (1024 * 1024 * 1024)) & " GB"

## Şu anki Unix timestamp
proc simdikiZaman*(): int64 =
  result = getTime().toUnix()

## Multipart form body'yi parse et
proc multipartFormCozumle*(govde: string, sinir: string): Table[string, string] =
  result = initTable[string, string]()
  let sinirCizgisi = "--" & sinir
  var konum = 0

  while konum < govde.len:
    let sinirBas = govde.find(sinirCizgisi, konum)
    if sinirBas < 0: break

    let icerikBas = govde.find("\r\n\r\n", sinirBas + sinirCizgisi.len)
    if icerikBas < 0: break

    let baslikMetni = govde[sinirBas + sinirCizgisi.len + 2 ..< icerikBas]
    let sonrakiSinir = govde.find(sinirCizgisi, icerikBas + 4)
    let icerik = if sonrakiSinir > 0:
                   govde[icerikBas + 4 ..< sonrakiSinir - 2]
                 else:
                   govde[icerikBas + 4 ..< govde.len]

    var isim = ""
    for satir in baslikMetni.split("\r\n"):
      if satir.toLowerAscii().startsWith("content-disposition:"):
        for kisim in satir.split(";"):
          let temiz = kisim.strip()
          if temiz.toLowerAscii().startsWith("name="):
            isim = temiz[5..^1].strip(chars={'"', '\''})

    if isim.len > 0:
      result[isim] = icerik

    if sonrakiSinir < 0: break
    konum = sonrakiSinir