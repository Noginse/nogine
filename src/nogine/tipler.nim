# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine'nin temel tip tanımları.
## Tüm framework bu modüldeki tipleri kullanır.

import std/[asyncnet, asyncdispatch, tables, json, times, strutils]

type
  ## HTTP metod sabitleri
  HttpMetod* = enum
    hmGET    = "GET"
    hmPOST   = "POST"
    hmPUT    = "PUT"
    hmDELETE = "DELETE"
    hmPATCH  = "PATCH"
    hmOPTIONS = "OPTIONS"
    hmHEAD   = "HEAD"

  ## Yüklenen dosya bilgisi
  YuklenenDosya* = object
    isim*: string          ## Orijinal dosya adı
    icerikTipi*: string    ## MIME tipi
    boyut*: int            ## Boyut (byte)
    veri*: string          ## Ham veri

  ## HTTP isteği
  Istek* = ref object
    metod*: HttpMetod          ## HTTP metodu
    yol*: string               ## İstek yolu (/kullanicilar/123)
    sorguSatiri*: string       ## Sorgu dizesi (?sayfa=1&boyut=10)
    basliklar*: Table[string, string]  ## HTTP başlıkları
    govde*: string             ## İstek gövdesi (ham)
    params*: Table[string, string]     ## Route parametreleri (:id gibi)
    sorguParams*: Table[string, string] ## Sorgu parametreleri
    cerezler*: Table[string, string]   ## Çerezler
    dosyalar*: Table[string, YuklenenDosya]  ## Yüklenen dosyalar
    formVerisi*: Table[string, string] ## Form verisi
    istemciIp*: string         ## İstemci IP adresi
    protokol*: string          ## HTTP/1.0 veya HTTP/1.1
    soket*: AsyncSocket        ## Ham soket

  ## HTTP yanıtı
  Yanit* = ref object
    durumKodu*: int            ## HTTP durum kodu (200, 404, vb.)
    basliklar*: Table[string, string]  ## Yanıt başlıkları
    govde*: string             ## Yanıt gövdesi
    gonderildi*: bool          ## Yanıt gönderildi mi?
    soket*: AsyncSocket        ## Ham soket

  ## Sonraki middleware'i çağıran proc
  SonrakiProc* = proc(): Future[void] {.closure, gcsafe.}

  ## Middleware handler tipi
  ArackatmanProc* = proc(istek: Istek, yanit: Yanit, sonraki: SonrakiProc): Future[void] {.closure, gcsafe.}

  ## Normal route handler
  IsleyiciProc* = proc(istek: Istek, yanit: Yanit): Future[void] {.closure, gcsafe.}

  ## WebSocket bağlantısı
  WsBaglanti* = ref object
    id*: string                ## Bağlantı kimliği
    soket*: AsyncSocket        ## WebSocket soketi
    odalar*: seq[string]       ## Katıldığı odalar
    bagliMi*: bool             ## Bağlantı aktif mi?
    baglandiIsleyici*: proc(): Future[void] {.closure, gcsafe.}
    mesajIsleyici*: proc(veri: string): Future[void] {.closure, gcsafe.}
    kapatildiIsleyici*: proc(): Future[void] {.closure, gcsafe.}

  ## Route tanımı
  RotaTanimi* = object
    metod*: HttpMetod
    desen*: string             ## /kullanicilar/:id gibi
    isleyici*: IsleyiciProc
    arackatmanlar*: seq[ArackatmanProc]
    wildcard*: bool            ## Wildcard rota mı?
    bolumler*: seq[string]     ## Desen bölümleri

  ## WebSocket rota tanımı
  WsRotaTanimi* = object
    yol*: string
    isleyici*: proc(baglanti: WsBaglanti): Future[void] {.closure, gcsafe.}

  ## Nogine uygulaması
  Nogine* = ref object
    rotalar*: seq[RotaTanimi]
    wsRotalar*: seq[WsRotaTanimi]
    globalArackatmanlar*: seq[ArackatmanProc]
    hataIsleyicileri*: Table[int, IsleyiciProc]
    genelHataIsleyici*: proc(istek: Istek, yanit: Yanit, hata: ref Exception): Future[void] {.closure, gcsafe.}
    varsayilanBasliklar*: Table[string, string]
    wsbaglantilari*: Table[string, WsBaglanti]
    aktifMi*: bool
    prefix*: string            ## Grup prefix'i

  ## Template bağlamı
  SablonBaglami* = Table[string, string]

  ## Sıkıştırma algoritması
  SikistirmaAlgoritma* = enum
    saGzip = "gzip"
    saDeflate = "deflate"
    saBrotli = "br"
    saYok = ""

  ## Rate limit durumu
  HizSiniriDurumu* = object
    istek*: int                ## İstek sayısı
    sifirlanmaZamani*: Time    ## Sayaç sıfırlanma zamanı

## HTTP durum kodları için Türkçe açıklamalar
proc durumAciklamasi*(kod: int): string =
  case kod
  of 100: "Devam Et"
  of 101: "Protokol Değiştiriliyor"
  of 200: "Tamam"
  of 201: "Oluşturuldu"
  of 202: "Kabul Edildi"
  of 204: "İçerik Yok"
  of 301: "Kalıcı Yönlendirme"
  of 302: "Geçici Yönlendirme"
  of 304: "Değiştirilmedi"
  of 400: "Hatalı İstek"
  of 401: "Yetkisiz"
  of 403: "Yasaklandı"
  of 404: "Bulunamadı"
  of 405: "Metod İzin Verilmiyor"
  of 409: "Çakışma"
  of 422: "İşlenemeyen Varlık"
  of 429: "Çok Fazla İstek"
  of 500: "Sunucu Hatası"
  of 502: "Hatalı Ağ Geçidi"
  of 503: "Hizmet Kullanılamıyor"
  else: "Bilinmeyen"

## Metod string'den HttpMetod'a dönüştür
proc metodDonustur*(s: string): HttpMetod =
  case s.toUpperAscii()
  of "GET":     hmGET
  of "POST":    hmPOST
  of "PUT":     hmPUT
  of "DELETE":  hmDELETE
  of "PATCH":   hmPATCH
  of "OPTIONS": hmOPTIONS
  of "HEAD":    hmHEAD
  else: raise newException(ValueError, "Geçersiz HTTP metodu: " & s)