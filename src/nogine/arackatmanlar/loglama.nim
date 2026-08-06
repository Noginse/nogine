# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine loglama arackatmanı.
## İstekleri renkli, yapılandırılmış format ile loglar.

import std/[asyncdispatch, times, strutils]
import ../tipler

type
  LogSeviyesi* = enum
    lsDebug = "DEBUG"
    lsBilgi  = "BİLGİ"
    lsUyari  = "UYARI"
    lsHata   = "HATA"

  LogAyarlari* = object
    seviye*: LogSeviyesi
    renkli*: bool
    zaman*: bool
    ip*: bool

proc varsayilanLogAyarlari*(): LogAyarlari =
  LogAyarlari(seviye: lsBilgi, renkli: true, zaman: true, ip: true)

## ANSI renk kodları
const
  ANSI_SIFIRLA  = "\x1b[0m"
  ANSI_YESIL    = "\x1b[32m"
  ANSI_MAVI     = "\x1b[34m"
  ANSI_SARI     = "\x1b[33m"
  ANSI_KIRMIZI  = "\x1b[31m"
  ANSI_CAMGOB   = "\x1b[36m"
  ANSI_BEYAZ    = "\x1b[37m"
  ANSI_EFLATUN  = "\x1b[35m"

proc durumRengi(kod: int): string =
  if kod < 300:    ANSI_YESIL
  elif kod < 400:  ANSI_CAMGOB
  elif kod < 500:  ANSI_SARI
  else:            ANSI_KIRMIZI

proc metodRengi(metod: HttpMetod): string =
  case metod
  of hmGET:     ANSI_YESIL
  of hmPOST:    ANSI_MAVI
  of hmPUT:     ANSI_SARI
  of hmDELETE:  ANSI_KIRMIZI
  of hmPATCH:   ANSI_EFLATUN
  of hmOPTIONS: ANSI_CAMGOB
  of hmHEAD:    ANSI_BEYAZ

proc zamanBicimlendir(ms: float): string =
  if ms < 1.0:      result = "<1ms"
  elif ms < 1000.0: result = ms.formatFloat(ffDecimal, 1) & "ms"
  else:             result = (ms / 1000.0).formatFloat(ffDecimal, 2) & "s"

## Loglama arackatmanı
proc nogineLoglama*(ayarlar: LogAyarlari): ArackatmanProc =
  result = proc(istek: Istek, yanit: Yanit, sonraki: SonrakiProc): Future[void] {.async.} =
    let baslangic = epochTime()
    {.gcsafe.}:
      await sonraki()
    let sure = (epochTime() - baslangic) * 1000.0
    let zamanStr = if ayarlar.zaman: "[" & format(now(), "HH:mm:ss") & "] " else: ""
    let metodStr = ($istek.metod).alignLeft(7)
    let surlStr  = zamanBicimlendir(sure)
    var yolStr   = istek.yol
    if istek.sorguSatiri.len > 0: yolStr &= "?" & istek.sorguSatiri

    if ayarlar.renkli:
      var satir = zamanStr
      satir &= metodRengi(istek.metod) & metodStr & ANSI_SIFIRLA & " "
      satir &= yolStr
      satir &= " → " & durumRengi(yanit.durumKodu) & $yanit.durumKodu & ANSI_SIFIRLA
      satir &= " (" & surlStr & ")"
      if ayarlar.ip and istek.istemciIp.len > 0:
        satir &= " [" & istek.istemciIp & "]"
      echo satir
    else:
      var satir = zamanStr & metodStr & " " & yolStr
      satir &= " → " & $yanit.durumKodu & " (" & surlStr & ")"
      if ayarlar.ip and istek.istemciIp.len > 0:
        satir &= " [" & istek.istemciIp & "]"
      echo satir

## Varsayılan ayarlarla loglama
proc nogineLoglama*(): ArackatmanProc =
  result = nogineLoglama(varsayilanLogAyarlari())