# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine hata tipleri ve hata yönetim sistemi.
## Tüm hata mesajları Türkçe'dir.

import std/strutils

type
  ## Temel Nogine hatası
  NogineHatasi* = object of CatchableError

  ## Route bulunamadı hatası
  RotaBulunamadiHatasi* = object of NogineHatasi

  ## Geçersiz istek hatası
  GecersizIstekHatasi* = object of NogineHatasi

  ## JSON parse hatası
  JsonParseHatasi* = object of NogineHatasi

  ## Doğrulama hatası (exception olarak)
  DogrulamaHatasiEx* = object of NogineHatasi
    hatalar*: seq[string]

  ## WebSocket hatası
  WebSocketHatasi* = object of NogineHatasi

  ## Middleware hatası
  ArackatmanHatasi* = object of NogineHatasi

  ## Hız sınırı aşıldı hatası
  HizSiniriHatasi* = object of NogineHatasi

  ## Dosya bulunamadı hatası
  DosyaBulunamadiHatasi* = object of NogineHatasi

  ## Template hatası
  SablonHatasiEx* = object of NogineHatasi

  ## Konfigürasyon hatası
  KonfigurasyonHatasi* = object of NogineHatasi

## Yeni bir NogineHatasi oluştur
proc yeniNogineHatasi*(mesaj: string): ref NogineHatasi =
  result = newException(NogineHatasi, mesaj)

## Yeni bir RotaBulunamadiHatasi oluştur
proc yeniRotaHatasi*(yol: string): ref RotaBulunamadiHatasi =
  result = newException(RotaBulunamadiHatasi,
    "Rota bulunamadı: '" & yol & "'. Bu yol için tanımlı bir işleyici yok.")

## Yeni bir GecersizIstekHatasi oluştur
proc yeniIstekHatasi*(mesaj: string): ref GecersizIstekHatasi =
  result = newException(GecersizIstekHatasi, "Geçersiz istek: " & mesaj)

## Yeni bir JsonParseHatasi oluştur
proc yeniJsonHatasi*(mesaj: string): ref JsonParseHatasi =
  result = newException(JsonParseHatasi,
    "JSON parse hatası: " & mesaj & ". Geçerli bir JSON gönderdiğinizden emin olun.")

## Yeni bir DogrulamaHatasiEx oluştur
proc yeniDogrulamaHatasiEx*(hatalar: seq[string]): ref DogrulamaHatasiEx =
  var h = newException(DogrulamaHatasiEx, "Doğrulama başarısız: " & hatalar.join(", "))
  h.hatalar = hatalar
  result = h

## Yeni bir WebSocketHatasi oluştur
proc yeniWsHatasi*(mesaj: string): ref WebSocketHatasi =
  result = newException(WebSocketHatasi, "WebSocket hatası: " & mesaj)

## Yeni bir HizSiniriHatasi oluştur
proc yeniHizHatasi*(saniyede: int): ref HizSiniriHatasi =
  result = newException(HizSiniriHatasi,
    "Hız sınırı aşıldı. Saniyede en fazla " & $saniyede & " istek gönderilebilir.")

## Yeni bir DosyaBulunamadiHatasi oluştur
proc yeniDosyaHatasi*(yol: string): ref DosyaBulunamadiHatasi =
  result = newException(DosyaBulunamadiHatasi,
    "Dosya bulunamadı: '" & yol & "'. Dosya yolunu kontrol edin.")

## Yeni bir SablonHatasiEx oluştur
proc yeniSablonHatasi*(mesaj: string): ref SablonHatasiEx =
  result = newException(SablonHatasiEx, "Şablon hatası: " & mesaj)

## Yeni bir KonfigurasyonHatasi oluştur
proc yeniKonfigHatasi*(mesaj: string): ref KonfigurasyonHatasi =
  result = newException(KonfigurasyonHatasi, "Konfigürasyon hatası: " & mesaj)