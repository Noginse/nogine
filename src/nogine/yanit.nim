# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## HTTP yanıt oluşturma ve gönderme modülü.
## Akıcı (fluent) API ile zincirlenebilir yanıt oluşturma.

import std/[asyncnet, asyncdispatch, tables, json, strutils, os]
import ./tipler
import ./yardimcilar

## Yeni boş yanıt oluştur
proc yeniYanit*(soket: AsyncSocket): Yanit =
  result = Yanit(
    durumKodu: 200,
    basliklar: initTable[string, string](),
    govde: "",
    gonderildi: false,
    soket: soket
  )
  result.basliklar["server"] = "Nogine/0.1.0"
  result.basliklar["date"] = httpZamani()

## Durum kodu ayarla (zincirlenebilir)
proc durum*(yanit: Yanit, kod: int): Yanit =
  yanit.durumKodu = kod
  result = yanit

## Başlık ayarla (zincirlenebilir)
proc baslikAyarla*(yanit: Yanit, isim: string, deger: string): Yanit =
  yanit.basliklar[isim.toLowerAscii()] = deger
  result = yanit

## Çerez ayarla (zincirlenebilir)
proc cerezAyarla*(yanit: Yanit, isim: string, deger: string,
                  saniye: int = -1, yol: string = "/",
                  guvenli: bool = false, httpSadece: bool = true): Yanit =
  var cerezDeger = isim & "=" & deger & "; Path=" & yol
  if saniye >= 0:
    cerezDeger &= "; Max-Age=" & $saniye
  if guvenli:
    cerezDeger &= "; Secure"
  if httpSadece:
    cerezDeger &= "; HttpOnly"
  yanit.basliklar["set-cookie"] = cerezDeger
  result = yanit

## Çerez sil
proc cerezSil*(yanit: Yanit, isim: string, yol: string = "/"): Yanit =
  result = yanit.cerezAyarla(isim, "", saniye = 0, yol = yol)

## HTTP yanıtını soket'e yaz
proc gonder*(yanit: Yanit): Future[void] {.async.} =
  if yanit.gonderildi:
    return
  yanit.gonderildi = true
  
  # Durum satırı
  var yanıtMetni = "HTTP/1.1 " & $yanit.durumKodu & " " & 
                   durumAciklamasi(yanit.durumKodu) & "\r\n"
  
  # Content-Length ekle
  if "content-length" notin yanit.basliklar:
    yanit.basliklar["content-length"] = $yanit.govde.len
  
  # Başlıkları yaz
  for isim, deger in yanit.basliklar:
    yanıtMetni &= isim & ": " & deger & "\r\n"
  
  yanıtMetni &= "\r\n"
  yanıtMetni &= yanit.govde
  
  try:
    await yanit.soket.send(yanıtMetni)
  except:
    discard

## JSON yanıt gönder
proc json*(yanit: Yanit, veri: JsonNode): Future[void] {.async.} =
  yanit.basliklar["content-type"] = "application/json; charset=utf-8"
  yanit.govde = $veri
  await yanit.gonder()

## HTML yanıt gönder
proc html*(yanit: Yanit, icerik: string): Future[void] {.async.} =
  yanit.basliklar["content-type"] = "text/html; charset=utf-8"
  yanit.govde = icerik
  await yanit.gonder()

## Düz metin yanıt gönder
proc metin*(yanit: Yanit, icerik: string): Future[void] {.async.} =
  yanit.basliklar["content-type"] = "text/plain; charset=utf-8"
  yanit.govde = icerik
  await yanit.gonder()

## Dosya indirme yanıtı
proc dosya*(yanit: Yanit, dosyaYolu: string, 
            indirmeAdi: string = ""): Future[void] {.async.} =
  if not fileExists(dosyaYolu):
    yanit.durumKodu = 404
    yanit.basliklar["content-type"] = "application/json; charset=utf-8"
    yanit.govde = """{"hata": "Dosya bulunamadı"}"""
    await yanit.gonder()
    return
  
  let uzanti = splitFile(dosyaYolu).ext
  let mimetipi = mimeHesapla(uzanti)
  let adi = if indirmeAdi.len > 0: indirmeAdi else: splitFile(dosyaYolu).name & uzanti
  
  yanit.basliklar["content-type"] = mimetipi
  yanit.basliklar["content-disposition"] = "attachment; filename=\"" & adi & "\""
  yanit.govde = readFile(dosyaYolu)
  await yanit.gonder()

## Yönlendirme yanıtı
proc yonlendir*(yanit: Yanit, url: string, 
                kalici: bool = false): Future[void] {.async.} =
  yanit.durumKodu = if kalici: 301 else: 302
  yanit.basliklar["location"] = url
  yanit.govde = ""
  await yanit.gonder()

## Ham HTML sayfası gönder (basit)
proc sayfa*(yanit: Yanit, baslik: string, icerik: string): Future[void] {.async.} =
  let html = """<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>""" & baslik & """</title>
</head>
<body>
""" & icerik & """
</body>
</html>"""
  await yanit.html(html)

## SSE (Server-Sent Events) başlat
proc sseBaslat*(yanit: Yanit): Future[void] {.async.} =
  yanit.basliklar["content-type"] = "text/event-stream"
  yanit.basliklar["cache-control"] = "no-cache"
  yanit.basliklar["connection"] = "keep-alive"
  yanit.basliklar["transfer-encoding"] = "chunked"
  
  # Başlıkları hemen gönder
  var baslikMetni = "HTTP/1.1 200 Tamam\r\n"
  for isim, deger in yanit.basliklar:
    baslikMetni &= isim & ": " & deger & "\r\n"
  baslikMetni &= "\r\n"
  
  try:
    await yanit.soket.send(baslikMetni)
    yanit.gonderildi = true
  except:
    discard

## SSE event gönder
proc sseGonder*(yanit: Yanit, veri: string, etkinlik: string = ""): Future[void] {.async.} =
  var mesaj = ""
  if etkinlik.len > 0:
    mesaj &= "event: " & etkinlik & "\n"
  mesaj &= "data: " & veri & "\n\n"
  try:
    await yanit.soket.send(mesaj)
  except:
    discard

## JSONP yanıt gönder
proc jsonp*(yanit: Yanit, veri: JsonNode, geriCagri: string): Future[void] {.async.} =
  yanit.basliklar["content-type"] = "application/javascript; charset=utf-8"
  yanit.govde = geriCagri & "(" & $veri & ");"
  await yanit.gonder()

## Boş yanıt (204 No Content)
proc bos*(yanit: Yanit): Future[void] {.async.} =
  yanit.durumKodu = 204
  yanit.govde = ""
  await yanit.gonder()