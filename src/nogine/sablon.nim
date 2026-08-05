# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine şablon (template) motoru.
## Değişken yerleştirme, koşullar, döngüler ve kalıtım desteği.

import std/[tables, strutils, os, json]
import ./hatalar

type
  SablonMotoru* = ref object
    dizin*: string                    ## Şablon dizini
    uzanti*: string                   ## Dosya uzantısı (.html varsayılan)
    onbellek*: Table[string, string]  ## Şablon önbelleği
    onbellekAcik*: bool               ## Önbellek açık mı?

## Yeni şablon motoru oluştur
proc yeniSablonMotoru*(dizin: string = "views", uzanti: string = ".html"): SablonMotoru =
  result = SablonMotoru(
    dizin: dizin,
    uzanti: uzanti,
    onbellek: initTable[string, string](),
    onbellekAcik: true
  )

## Şablon dosyasını yükle
proc yukle*(motor: SablonMotoru, isim: string): string =
  let dosyaYolu = motor.dizin / isim & motor.uzanti
  
  if motor.onbellekAcik and isim in motor.onbellek:
    return motor.onbellek[isim]
  
  if not fileExists(dosyaYolu):
    raise yeniSablonHatasi("Şablon bulunamadı: '" & isim & "' (" & dosyaYolu & ")")
  
  result = readFile(dosyaYolu)
  if motor.onbellekAcik:
    motor.onbellek[isim] = result

## {{ degisken }} yerleştirmesi
proc degiskenleriIsle(sablon: string, baglamm: Table[string, JsonNode]): string =
  result = sablon
  for isim, deger in baglamm:
    let yer = "{{" & isim & "}}"
    let yerBosluklu = "{{ " & isim & " }}"
    var degerStr: string
    case deger.kind
    of JString: degerStr = deger.getStr()
    of JInt:    degerStr = $deger.getInt()
    of JFloat:  degerStr = $deger.getFloat()
    of JBool:   degerStr = if deger.getBool(): "doğru" else: "yanlış"
    of JNull:   degerStr = ""
    else:       degerStr = $deger
    result = result.replace(yer, degerStr).replace(yerBosluklu, degerStr)

## {# yorum #} bloklarını kaldır
proc yorumlariKaldir(sablon: string): string =
  result = sablon
  var konum = 0
  while true:
    let bas = result.find("{#", konum)
    if bas < 0: break
    let son = result.find("#}", bas)
    if son < 0: break
    result = result[0..<bas] & result[son+2..^1]
    konum = bas

## {% if kosul %} ... {% endif %} işle
proc kosullariIsle(sablon: string, baglamm: Table[string, JsonNode]): string =
  result = sablon
  var konum = 0
  
  while true:
    let ifBas = result.find("{% if ", konum)
    if ifBas < 0: break
    
    let ifSon = result.find("%}", ifBas)
    if ifSon < 0: break
    
    let kosulAdi = result[ifBas + 6 ..< ifSon].strip()
    let endifBas = result.find("{% endif %}", ifSon)
    if endifBas < 0: break
    
    # else bloğu var mı?
    let elseBas = result.find("{% else %}", ifSon, endifBas)
    
    # Koşulu değerlendir
    var kosulDogruMu = false
    if kosulAdi in baglamm:
      let deger = baglamm[kosulAdi]
      kosulDogruMu = case deger.kind
        of JBool:   deger.getBool()
        of JString: deger.getStr().len > 0
        of JInt:    deger.getInt() != 0
        of JNull:   false
        else:       true
    elif kosulAdi.startsWith("not "):
      let gercekAd = kosulAdi[4..^1].strip()
      if gercekAd in baglamm:
        let deger = baglamm[gercekAd]
        kosulDogruMu = not (case deger.kind
          of JBool:   deger.getBool()
          of JString: deger.getStr().len > 0
          of JNull:   false
          else:       true)
      else:
        kosulDogruMu = true
    
    let dogru_icerik = if elseBas > 0:
                         result[ifSon+2 ..< elseBas]
                       else:
                         result[ifSon+2 ..< endifBas]
    let yanlis_icerik = if elseBas > 0:
                           result[elseBas+10 ..< endifBas]
                         else: ""
    
    let secilen = if kosulDogruMu: dogru_icerik else: yanlis_icerik
    result = result[0..<ifBas] & secilen & result[endifBas+11..^1]
    konum = ifBas

## {% for ogre in liste %} ... {% endfor %} işle
proc dongusuIsle(sablon: string, baglamm: Table[string, JsonNode]): string =
  result = sablon
  var konum = 0
  
  while true:
    let forBas = result.find("{% for ", konum)
    if forBas < 0: break
    
    let forSon = result.find("%}", forBas)
    if forSon < 0: break
    
    let forSatir = result[forBas + 7 ..< forSon].strip()
    let inKonum = forSatir.find(" in ")
    if inKonum < 0:
      konum = forBas + 1
      continue
    
    let ogeAdi = forSatir[0..<inKonum].strip()
    let listeAdi = forSatir[inKonum+4..^1].strip()
    
    let endforBas = result.find("{% endfor %}", forSon)
    if endforBas < 0: break
    
    let sablonIcerik = result[forSon+2 ..< endforBas]
    
    var dongIcerik = ""
    if listeAdi in baglamm and baglamm[listeAdi].kind == JArray:
      for i, oge in baglamm[listeAdi].elems:
        var ogeBaglam = baglamm
        ogeBaglam[ogeAdi] = oge
        ogeBaglam["dongu_indeks"] = %i
        ogeBaglam["dongu_sayac"] = %(i + 1)
        ogeBaglam["dongu_ilkMi"] = %(i == 0)
        ogeBaglam["dongu_sonMu"] = %(i == baglamm[listeAdi].elems.len - 1)
        dongIcerik &= degiskenleriIsle(sablonIcerik, ogeBaglam)
    
    result = result[0..<forBas] & dongIcerik & result[endforBas+12..^1]
    konum = forBas

## {% extends "ana_sablon" %} kalıtım desteği
proc kalitimIsle*(motor: SablonMotoru, sablon: string,
                  baglamm: Table[string, JsonNode]): string =
  # extends tag'i ara
  let extendsBas = sablon.find("{% extends \"")
  if extendsBas < 0:
    return sablon
  
  let extendsSon = sablon.find("\" %}", extendsBas)
  if extendsSon < 0:
    return sablon
  
  let anaSablonAdi = sablon[extendsBas + 12 ..< extendsSon]
  let anaSablon = motor.yukle(anaSablonAdi)
  
  # Blokları çıkar
  var cocukBloklar = initTable[string, string]()
  var s = 0
  while true:
    let blockBas = sablon.find("{% block ", s)
    if blockBas < 0: break
    let blockIsimSon = sablon.find(" %}", blockBas + 9)
    if blockIsimSon < 0: break
    let blockIsim = sablon[blockBas + 9 ..< blockIsimSon]
    let endblockBas = sablon.find("{% endblock %}", blockIsimSon + 3)
    if endblockBas < 0: break
    cocukBloklar[blockIsim] = sablon[blockIsimSon + 3 ..< endblockBas]
    s = endblockBas + 14
  
  # Ana şablondaki blokları çocuk bloklarıyla değiştir
  result = anaSablon
  for isim, icerik in cocukBloklar:
    let blokDeseni = "{% block " & isim & " %}"
    let blokSonDeseni = "{% endblock %}"
    let basBas = result.find(blokDeseni)
    if basBas >= 0:
        let sonBas = result.find(blokSonDeseni, basBas)
        if sonBas >= 0:
          result = result[0..<basBas] & icerik & result[sonBas + blokSonDeseni.len..^1]

## {% include "parca" %} partial desteği
proc parcalariIsle*(motor: SablonMotoru, sablon: string): string =
  result = sablon
  var konum = 0
  while true:
    let includeBas = result.find("{% include \"", konum)
    if includeBas < 0: break
    let includeSon = result.find("\" %}", includeBas)
    if includeSon < 0: break
    let parcaAdi = result[includeBas + 12 ..< includeSon]
    try:
      let parcaIcerik = motor.yukle(parcaAdi)
      result = result[0..<includeBas] & parcaIcerik & result[includeSon+4..^1]
    except:
      result = result[0..<includeBas] & result[includeSon+4..^1]
    konum = includeBas

## Şablonu render et
proc render*(motor: SablonMotoru, isim: string,
             baglamm: Table[string, JsonNode] = initTable[string, JsonNode]()): string =
  var sablon = motor.yukle(isim)
  
  # Kalıtımı işle
  sablon = motor.kalitimIsle(sablon, baglamm)
  
  # Partial'ları işle
  sablon = motor.parcalariIsle(sablon)
  
  # Yorumları kaldır
  sablon = yorumlariKaldir(sablon)
  
  # Koşulları işle
  sablon = kosullariIsle(sablon, baglamm)
  
  # Döngüleri işle
  sablon = dongusuIsle(sablon, baglamm)
  
  # Değişkenleri yerleştir
  sablon = degiskenleriIsle(sablon, baglamm)
  
  result = sablon

## Doğrudan string şablonu render et (dosyasız)
proc renderMetin*(sablon: string,
                  baglamm: Table[string, JsonNode] = initTable[string, JsonNode]()): string =
  var s = yorumlariKaldir(sablon)
  s = kosullariIsle(s, baglamm)
  s = dongusuIsle(s, baglamm)
  s = degiskenleriIsle(s, baglamm)
  result = s