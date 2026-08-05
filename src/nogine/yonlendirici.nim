# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine yönlendirici (router) modülü.
## Route eşleştirme, dinamik parametreler ve wildcard desteği.

import std/[tables, strutils, sequtils]
import ./tipler

## Route desenini bölümlere ayır
proc deseniBol*(desen: string): seq[string] =
  result = desen.split("/").filterIt(it.len > 0)

## Route deseninde wildcard var mı?
proc wildcardMi*(desen: string): bool =
  result = "*" in desen

## Bir route deseninin parametrik olup olmadığını kontrol et
proc parametrikMi*(bolum: string): bool =
  result = bolum.startsWith(":")

## Wildcard route segment mi?
proc wildcardSegmentMi*(bolum: string): bool =
  result = bolum.startsWith("*")

## Route desenini ve URL'yi eşleştir, parametreleri döndür
proc rotaEslestir*(desen: string, yol: string, params: var Table[string, string]): bool =
  params.clear()
  let desenBolumleri = deseniBol(desen)
  let yolBolumleri = deseniBol(yol)
  
  # Wildcard kontrolü
  if wildcardMi(desen):
    # /dosyalar/* şeklinde wildcard
    var wildcardKonum = -1
    for i, bolum in desenBolumleri:
      if wildcardSegmentMi(bolum):
        wildcardKonum = i
        break
    
    if wildcardKonum >= 0:
      # Wildcard öncesi bölümleri eşleştir
      for i in 0..<wildcardKonum:
        if i >= yolBolumleri.len:
          return false
        if parametrikMi(desenBolumleri[i]):
          params[desenBolumleri[i][1..^1]] = yolBolumleri[i]
        elif desenBolumleri[i] != yolBolumleri[i]:
          return false
      
      # Wildcard parametre adı varsa, geri kalan yolu kaydet
      let wildcardAd = desenBolumleri[wildcardKonum][1..^1]
      if wildcardAd.len > 0 and wildcardKonum < yolBolumleri.len:
        params[wildcardAd] = yolBolumleri[wildcardKonum..^1].join("/")
      
      return wildcardKonum <= yolBolumleri.len
  
  # Uzunluk kontrolü (wildcard yoksa kesin eşleşme)
  if desenBolumleri.len != yolBolumleri.len:
    return false
  
  # Her bölümü kontrol et
  for i in 0..<desenBolumleri.len:
    let desenBolum = desenBolumleri[i]
    let yolBolum = yolBolumleri[i]
    
    if parametrikMi(desenBolum):
      # :parametre - dinamik parametre
      params[desenBolum[1..^1]] = yolBolum
    elif desenBolum != yolBolum:
      # Statik bölüm eşleşmedi
      return false
  
  result = true

## Yeni route oluştur
proc yeniRota*(metod: HttpMetod, desen: string,
               isleyici: IsleyiciProc,
               arackatmanlar: seq[ArackatmanProc] = @[]): RotaTanimi =
  result = RotaTanimi(
    metod: metod,
    desen: desen,
    isleyici: isleyici,
    arackatmanlar: arackatmanlar,
    wildcard: wildcardMi(desen),
    bolumler: deseniBol(desen)
  )

## Route listesinde eşleşen route'u bul
proc rotaBul*(rotalar: seq[RotaTanimi], metod: HttpMetod,
              yol: string, params: var Table[string, string]): int =
  ## Döndürdüğü değer rotalar dizisindeki indeks, -1 ise bulunamadı
  result = -1
  var geciciParams = initTable[string, string]()
  
  for i, rota in rotalar:
    if rota.metod != metod:
      continue
    if rotaEslestir(rota.desen, yol, geciciParams):
      params = geciciParams
      result = i
      return

## Route'un tam string gösterimi
proc rotaGoster*(rota: RotaTanimi): string =
  result = $rota.metod & " " & rota.desen
  if rota.wildcard:
    result &= " [wildcard]"
  if rota.arackatmanlar.len > 0:
    result &= " [" & $rota.arackatmanlar.len & " arackatman]"