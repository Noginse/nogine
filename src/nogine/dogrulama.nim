# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine veri doğrulama modülü.
## JSON verisi ve form alanları için doğrulama kuralları.
## Tüm hata mesajları Türkçe'dir.

import std/[json, strutils, re]

type
  DogrulamaHatasi* = object
    ## Doğrulama sonucu: hatalar ve geçerlilik durumu
    hatalar*: seq[string]
    gecerliMi*: bool

## Yeni boş doğrulama hatası oluştur
proc yeniDogrulama*(): DogrulamaHatasi =
  DogrulamaHatasi(hatalar: @[], gecerliMi: true)

## Hata ekle
proc hataEkle*(d: var DogrulamaHatasi, mesaj: string) =
  d.hatalar.add(mesaj)
  d.gecerliMi = false

## Zorunlu alan kontrolü
proc zorunlu*(d: var DogrulamaHatasi, veri: JsonNode, alanlar: varargs[string]) =
  for alan in alanlar:
    if alan notin veri or veri[alan].kind == JNull:
      d.hataEkle("'" & alan & "' alanı zorunludur")
    elif veri[alan].kind == JString and veri[alan].getStr().strip().len == 0:
      d.hataEkle("'" & alan & "' alanı boş olamaz")

## Tip kontrolü
proc tipKontrol*(d: var DogrulamaHatasi, veri: JsonNode, alan: string, tip: JsonNodeKind) =
  if alan notin veri:
    return
  if veri[alan].kind != tip:
    let tipAdi = case tip
      of JNull:    "null"
      of JBool:    "boolean"
      of JInt:     "tam sayı"
      of JFloat:   "ondalık sayı"
      of JString:  "metin"
      of JObject:  "nesne"
      of JArray:   "dizi"
    d.hataEkle("'" & alan & "' alanı " & tipAdi & " tipinde olmalıdır")

## Minimum uzunluk kontrolü
proc minUzunluk*(d: var DogrulamaHatasi, veri: JsonNode, alan: string, min: int) =
  if alan notin veri or veri[alan].kind != JString:
    return
  let deger = veri[alan].getStr()
  if deger.len < min:
    d.hataEkle("'" & alan & "' alanı en az " & $min & " karakter olmalıdır")

## Maksimum uzunluk kontrolü
proc maxUzunluk*(d: var DogrulamaHatasi, veri: JsonNode, alan: string, maks: int) =
  if alan notin veri or veri[alan].kind != JString:
    return
  let deger = veri[alan].getStr()
  if deger.len > maks:
    d.hataEkle("'" & alan & "' alanı en fazla " & $maks & " karakter olabilir")

## Uzunluk aralığı kontrolü
proc uzunlukKontrol*(d: var DogrulamaHatasi, veri: JsonNode, alan: string,
                     min: int = 0, maks: int = high(int)) =
  d.minUzunluk(veri, alan, min)
  if maks != high(int):
    d.maxUzunluk(veri, alan, maks)

## Minimum sayı değeri kontrolü
proc minDeger*(d: var DogrulamaHatasi, veri: JsonNode, alan: string, min: float) =
  if alan notin veri:
    return
  var deger: float
  case veri[alan].kind
  of JInt:   deger = veri[alan].getInt().float
  of JFloat: deger = veri[alan].getFloat()
  else: return
  if deger < min:
    d.hataEkle("'" & alan & "' alanı en az " & $min & " olmalıdır")

## Maksimum sayı değeri kontrolü
proc maxDeger*(d: var DogrulamaHatasi, veri: JsonNode, alan: string, maks: float) =
  if alan notin veri:
    return
  var deger: float
  case veri[alan].kind
  of JInt:   deger = veri[alan].getInt().float
  of JFloat: deger = veri[alan].getFloat()
  else: return
  if deger > maks:
    d.hataEkle("'" & alan & "' alanı en fazla " & $maks & " olabilir")

## Sayı aralığı kontrolü
proc aralikKontrol*(d: var DogrulamaHatasi, veri: JsonNode, alan: string,
                    min: float, maks: float) =
  d.minDeger(veri, alan, min)
  d.maxDeger(veri, alan, maks)

## E-posta format kontrolü
proc emailKontrol*(d: var DogrulamaHatasi, veri: JsonNode, alan: string) =
  if alan notin veri or veri[alan].kind != JString:
    return
  let deger = veri[alan].getStr()
  let emailDeseni = re"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"
  if not deger.match(emailDeseni):
    d.hataEkle("'" & alan & "' alanı geçerli bir e-posta adresi olmalıdır")

## URL format kontrolü
proc urlKontrol*(d: var DogrulamaHatasi, veri: JsonNode, alan: string) =
  if alan notin veri or veri[alan].kind != JString:
    return
  let deger = veri[alan].getStr()
  if not (deger.startsWith("http://") or deger.startsWith("https://")):
    d.hataEkle("'" & alan & "' alanı geçerli bir URL olmalıdır (http:// veya https:// ile başlamalı)")

## Telefon format kontrolü (Türk formatı)
proc telefonKontrol*(d: var DogrulamaHatasi, veri: JsonNode, alan: string) =
  if alan notin veri or veri[alan].kind != JString:
    return
  let deger = veri[alan].getStr().multiReplace((" ", ""), ("-", ""), ("(", ""), (")", ""))
  let telDeseni = re"^(\+90|0)?5[0-9]{9}$"
  if not deger.match(telDeseni):
    d.hataEkle("'" & alan & "' alanı geçerli bir Türk telefon numarası olmalıdır")

## Regex format kontrolü
proc formatKontrol*(d: var DogrulamaHatasi, veri: JsonNode, alan: string,
                    desen: Regex, aciklama: string = "") =
  if alan notin veri or veri[alan].kind != JString:
    return
  let deger = veri[alan].getStr()
  if not deger.match(desen):
    let mesaj = if aciklama.len > 0: aciklama
                else: "'" & alan & "' alanı geçerli formatta değil"
    d.hataEkle(mesaj)

## İzin verilen değerler kontrolü (enum gibi)
proc izinliDegerler*(d: var DogrulamaHatasi, veri: JsonNode, alan: string,
                      degerler: seq[string]) =
  if alan notin veri or veri[alan].kind != JString:
    return
  let deger = veri[alan].getStr()
  if deger notin degerler:
    d.hataEkle("'" & alan & "' alanı şu değerlerden biri olmalıdır: " &
               degerler.join(", "))

## Eşleşme kontrolü (şifre onayı gibi)
proc eslesmeli*(d: var DogrulamaHatasi, veri: JsonNode,
                alan1: string, alan2: string) =
  if alan1 notin veri or alan2 notin veri:
    return
  if veri[alan1] != veri[alan2]:
    d.hataEkle("'" & alan1 & "' ve '" & alan2 & "' alanları eşleşmelidir")

## Özel doğrulama kuralı
proc ozelKontrol*(d: var DogrulamaHatasi, kosul: bool, mesaj: string) =
  if not kosul:
    d.hataEkle(mesaj)

## Şifre güvenlik kontrolü
proc sifreKontrol*(d: var DogrulamaHatasi, veri: JsonNode, alan: string,
                   minUzunluk: int = 8) =
  if alan notin veri or veri[alan].kind != JString:
    return
  let sifre = veri[alan].getStr()
  
  if sifre.len < minUzunluk:
    d.hataEkle("'" & alan & "' en az " & $minUzunluk & " karakter olmalıdır")
    return
  
  var buyukHarf = false
  var kucukHarf = false
  var rakam = false
  
  for karakter in sifre:
    if karakter in {'A'..'Z'}: buyukHarf = true
    elif karakter in {'a'..'z'}: kucukHarf = true
    elif karakter in {'0'..'9'}: rakam = true
  
  if not buyukHarf:
    d.hataEkle("'" & alan & "' en az bir büyük harf içermelidir")
  if not kucukHarf:
    d.hataEkle("'" & alan & "' en az bir küçük harf içermelidir")
  if not rakam:
    d.hataEkle("'" & alan & "' en az bir rakam içermelidir")

## Doğrulama hatalarını JSON olarak döndür
proc jsonHatalar*(d: DogrulamaHatasi): string =
  result = "{\"gecerli\":" & $d.gecerliMi & ",\"hatalar\":["
  for i, hata in d.hatalar:
    if i > 0: result &= ","
    result &= "\"" & hata.replace("\"", "\\\"") & "\""
  result &= "]}"

## Kolaylık: tek bir doğrulama fonksiyonu
template dogrula*(govdeParam: JsonNode, islemler: untyped): DogrulamaHatasi =
  var d {.inject.} = yeniDogrulama()
  islemler
  d