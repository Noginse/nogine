# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## HTTP istek işleme modülü.
## Ham HTTP isteğini parse ederek Istek nesnesine dönüştürür.

import std/[asyncnet, asyncdispatch, tables, strutils, json]
import ./tipler
import ./hatalar
import ./yardimcilar

## Yeni boş istek oluştur
proc yeniIstek*(soket: AsyncSocket): Istek =
  result = Istek(
    metod: hmGET,
    yol: "/",
    sorguSatiri: "",
    basliklar: initTable[string, string](),
    govde: "",
    params: initTable[string, string](),
    sorguParams: initTable[string, string](),
    cerezler: initTable[string, string](),
    dosyalar: initTable[string, YuklenenDosya](),
    formVerisi: initTable[string, string](),
    istemciIp: "",
    protokol: "HTTP/1.1",
    soket: soket
  )

## HTTP isteğini soket'ten oku ve parse et
proc istekOku*(soket: AsyncSocket): Future[Istek] {.async.} =
  result = yeniIstek(soket)
  
  # İlk satırı oku (GET /yol HTTP/1.1)
  let ilkSatir = await soket.recvLine()
  if ilkSatir.len == 0:
    raise yeniIstekHatasi("Boş istek alındı")
  
  let parcalar = ilkSatir.split(" ")
  if parcalar.len < 3:
    raise yeniIstekHatasi("Geçersiz HTTP istek satırı: " & ilkSatir)
  
  result.metod = metodDonustur(parcalar[0])
  result.protokol = parcalar[2].strip()
  
  # URL ve sorgu dizesini ayır
  let urlParcalar = parcalar[1].split("?", 1)
  result.yol = urlCoz(urlParcalar[0])
  if urlParcalar.len > 1:
    result.sorguSatiri = urlParcalar[1]
    result.sorguParams = sorguyuCozumle(urlParcalar[1])
  
  # Başlıkları oku
  var icerikUzunlugu = 0
  while true:
    let satir = await soket.recvLine()
    if satir == "" or satir == "\r\n" or satir == "\n":
      break
    let kolonKonum = satir.find(":")
    if kolonKonum > 0:
      let anahtar = satir[0..<kolonKonum].strip().toLowerAscii()
      let deger = satir[kolonKonum+1..^1].strip()
      result.basliklar[anahtar] = deger
      
      if anahtar == "content-length":
        try:
          icerikUzunlugu = parseInt(deger)
        except:
          icerikUzunlugu = 0
      elif anahtar == "cookie":
        result.cerezler = cerezleriCozumle(deger)
  
  # IP adresini al
  if "x-forwarded-for" in result.basliklar:
    result.istemciIp = result.basliklar["x-forwarded-for"].split(",")[0].strip()
  elif "x-real-ip" in result.basliklar:
    result.istemciIp = result.basliklar["x-real-ip"]
  else:
    try:
      result.istemciIp = soket.getPeerAddr()[0]
    except:
      result.istemciIp = "bilinmiyor"
  
  # Gövdeyi oku
  if icerikUzunlugu > 0:
    result.govde = await soket.recv(icerikUzunlugu)
    
    # İçerik tipine göre parse et
    let icerikTipi = result.basliklar.getOrDefault("content-type", "")
    
    if "application/json" in icerikTipi:
      # JSON otomatik parse edilmez, istek.json() ile yapılır
      discard
    elif "application/x-www-form-urlencoded" in icerikTipi:
      result.formVerisi = sorguyuCozumle(result.govde)
    elif "multipart/form-data" in icerikTipi:
      # Boundary'yi çıkar
      let sinirParcalari = icerikTipi.split("boundary=")
      if sinirParcalari.len > 1:
        let sinir = sinirParcalari[1].strip()
        result.formVerisi = multipartFormCozumle(result.govde, sinir)

## Gövdeyi JSON olarak parse et
proc json*(istek: Istek): JsonNode =
  if istek.govde.len == 0:
    raise yeniJsonHatasi("İstek gövdesi boş")
  try:
    result = parseJson(istek.govde)
  except JsonParsingError as e:
    raise yeniJsonHatasi(e.msg)

## Sorgu parametresi al
proc sorgu*(istek: Istek, isim: string, varsayilan: string = ""): string =
  result = istek.sorguParams.getOrDefault(isim, varsayilan)

## Başlık değeri al
proc baslik*(istek: Istek, isim: string, varsayilan: string = ""): string =
  result = istek.basliklar.getOrDefault(isim.toLowerAscii(), varsayilan)

## Çerez değeri al
proc cerez*(istek: Istek, isim: string, varsayilan: string = ""): string =
  result = istek.cerezler.getOrDefault(isim, varsayilan)

## Form alanı al
proc form*(istek: Istek, isim: string, varsayilan: string = ""): string =
  result = istek.formVerisi.getOrDefault(isim, varsayilan)

## Route parametresi al
proc param*(istek: Istek, isim: string, varsayilan: string = ""): string =
  result = istek.params.getOrDefault(isim, varsayilan)

## İstek JSON mu?
proc jsonMu*(istek: Istek): bool =
  let ct = istek.basliklar.getOrDefault("content-type", "")
  result = "application/json" in ct

## İstek form mu?
proc formMu*(istek: Istek): bool =
  let ct = istek.basliklar.getOrDefault("content-type", "")
  result = "application/x-www-form-urlencoded" in ct or "multipart/form-data" in ct

## Accept başlığında belirli bir içerik tipi var mı?
proc kabul*(istek: Istek, icerikTipi: string): bool =
  let accept = istek.basliklar.getOrDefault("accept", "*/*")
  result = "*/*" in accept or icerikTipi in accept

## İstek bilgilerini özet string olarak döndür
proc ozet*(istek: Istek): string =
  result = $istek.metod & " " & istek.yol
  if istek.sorguSatiri.len > 0:
    result &= "?" & istek.sorguSatiri