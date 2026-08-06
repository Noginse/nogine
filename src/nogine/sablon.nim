# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine sablon (template) motoru.
## Desteklenen: degisken, if/elif/else, for, extends, block, include, macro, filtre, yorum

import std/[tables, strutils, os, sequtils, algorithm]
import ./tipler

type
  SablonYukleyici* = ref object
    dizin*: string
    onbellek*: Table[string, string]
    onbellekAktif*: bool

  BlokIcerigi = Table[string, string]
  MakroTanimi = object
    parametreler: seq[string]
    govde: string

proc yeniSablonYukleyici*(dizin: string = "templates",
                           onbellek: bool = true): SablonYukleyici =
  result = SablonYukleyici(
    dizin: dizin,
    onbellek: initTable[string, string](),
    onbellekAktif: onbellek
  )

proc dosyaOku(yukleyici: SablonYukleyici, isim: string): string =
  if yukleyici.onbellekAktif and isim in yukleyici.onbellek:
    return yukleyici.onbellek[isim]
  let yol = yukleyici.dizin / isim
  if not fileExists(yol):
    return "<!-- sablon bulunamadi: " & yol & " -->"
  result = readFile(yol)
  if yukleyici.onbellekAktif:
    yukleyici.onbellek[isim] = result

proc filtreUygula(deger: string, filtreler: seq[string]): string =
  result = deger
  for filtre in filtreler:
    case filtre.strip()
    of "buyuk", "upper":    result = result.toUpperAscii()
    of "kucuk", "lower":    result = result.toLowerAscii()
    of "trim":              result = result.strip()
    of "uzunluk", "length": result = $result.len
    of "html":
      result = result.replace("&", "&amp;").replace("<", "&lt;")
                     .replace(">", "&gt;").replace("\"", "&quot;")
    of "url":
      result = result.replace(" ", "%20").replace("&", "%26")
    of "ters", "reverse":
      var chars = toSeq(result.items)
      reverse(chars)
      result = chars.join("")
    else: discard

proc degiskenAl(baglam: SablonBaglami, anahtar: string): string =
  if anahtar in baglam:
    return baglam[anahtar]
  let parcalar = anahtar.split(".")
  if parcalar.len > 0 and parcalar[0] in baglam:
    return baglam[parcalar[0]]
  result = ""

proc ifadeDegerlendir(baglam: SablonBaglami, ifade: string): bool =
  let s = ifade.strip()
  if s.startsWith("not "):
    return not ifadeDegerlendir(baglam, s[4..^1])
  if " and " in s:
    let p = s.split(" and ", 1)
    return ifadeDegerlendir(baglam, p[0]) and ifadeDegerlendir(baglam, p[1])
  if " or " in s:
    let p = s.split(" or ", 1)
    return ifadeDegerlendir(baglam, p[0]) or ifadeDegerlendir(baglam, p[1])
  # Karsilastirma: a == b, a != b, a > b, a < b
  for op in ["==", "!=", ">=", "<=", ">", "<"]:
    if op in s:
      let p = s.split(op, 1)
      let sol = degiskenAl(baglam, p[0].strip())
      let sag = p[1].strip().strip(chars={'"', '\''})
      case op
      of "==": return sol == sag
      of "!=": return sol != sag
      of ">":  return (try: parseInt(sol) > parseInt(sag) except: false)
      of "<":  return (try: parseInt(sol) < parseInt(sag) except: false)
      of ">=": return (try: parseInt(sol) >= parseInt(sag) except: false)
      of "<=": return (try: parseInt(sol) <= parseInt(sag) except: false)
      else: discard
  let deger = degiskenAl(baglam, s)
  result = deger.len > 0 and deger != "false" and deger != "0"

proc isleParcali(sablon: string, baglam: var SablonBaglami,
                 bloklar: var BlokIcerigi,
                 makrolar: var Table[string, MakroTanimi],
                 derinlik: int = 0): string

proc isleParcali(sablon: string, baglam: var SablonBaglami,
                 bloklar: var BlokIcerigi,
                 makrolar: var Table[string, MakroTanimi],
                 derinlik: int = 0): string =
  if derinlik > 50:
    return sablon
  result = ""
  var i = 0
  while i < sablon.len:
    # {{ degisken }} - degisken degistirme
    if i + 1 < sablon.len and sablon[i] == '{' and sablon[i+1] == '{':
      let bitis = sablon.find("}}", i + 2)
      if bitis < 0:
        result.add(sablon[i])
        inc i
        continue
      let icerik = sablon[i+2 ..< bitis].strip()
      # Filtre kontrolu: degisken | filtre1 | filtre2
      let parcalar = icerik.split("|")
      let degiskenAdi = parcalar[0].strip()
      let deger = degiskenAl(baglam, degiskenAdi)
      if parcalar.len > 1:
        result.add(filtreUygula(deger, parcalar[1..^1]))
      else:
        result.add(deger)
      i = bitis + 2
    # {# yorum #}
    elif i + 1 < sablon.len and sablon[i] == '{' and sablon[i+1] == '#':
      let bitis = sablon.find("#}", i + 2)
      i = if bitis >= 0: bitis + 2 else: sablon.len
    # {% tag %}
    elif i + 1 < sablon.len and sablon[i] == '{' and sablon[i+1] == '%':
      let bitis = sablon.find("%}", i + 2)
      if bitis < 0:
        result.add(sablon[i])
        inc i
        continue
      let etiket = sablon[i+2 ..< bitis].strip()
      i = bitis + 2
      # {% if ifade %}
      if etiket.startsWith("if "):
        let ifade = etiket[3..^1].strip()
        # if/elif/else/endif bloklarini bul
        var derinlikSayac = 1
        var j = i
        var ifBitisKonum = -1
        while j < sablon.len:
          if j + 1 < sablon.len and sablon[j] == '{' and sablon[j+1] == '%':
            let eb = sablon.find("%}", j + 2)
            if eb >= 0:
              let ic = sablon[j+2 ..< eb].strip()
              if ic.startsWith("if "): inc derinlikSayac
              elif ic == "endif":
                dec derinlikSayac
                if derinlikSayac == 0:
                  ifBitisKonum = j
                  break
            j = if eb >= 0: eb + 2 else: sablon.len
          else: inc j
        if ifBitisKonum < 0:
          continue
        let ifBlok = sablon[i ..< ifBitisKonum]
        i = ifBitisKonum + "{% endif %}".len + 2
        # if/elif/else ayir
        var secilenBlok = ""
        if ifadeDegerlendir(baglam, ifade):
          # else veya elif'ten once olan kisim
          let elseIdx = ifBlok.find("{% else %}")
          let elifIdx = ifBlok.find("{% elif ")
          if elifIdx >= 0 and (elseIdx < 0 or elifIdx < elseIdx):
            secilenBlok = ifBlok[0 ..< elifIdx]
          elif elseIdx >= 0:
            secilenBlok = ifBlok[0 ..< elseIdx]
          else:
            secilenBlok = ifBlok
        else:
          let elseIdx = ifBlok.find("{% else %}")
          if elseIdx >= 0:
            secilenBlok = ifBlok[elseIdx + "{% else %}".len ..< ifBlok.len]
        if secilenBlok.len > 0:
          var altBaglam = baglam
          result.add(isleParcali(secilenBlok, altBaglam, bloklar, makrolar, derinlik+1))
      # {% for eleman in liste %}
      elif etiket.startsWith("for ") and " in " in etiket:
        let forIcerik = etiket[4..^1]
        let inIdx = forIcerik.find(" in ")
        let degiskenAdi = forIcerik[0 ..< inIdx].strip()
        let listeAdi = forIcerik[inIdx+4 ..< forIcerik.len].strip()
        # endfor bul
        var derinlikSayac = 1
        var j = i
        var forBitisKonum = -1
        while j < sablon.len:
          if j + 1 < sablon.len and sablon[j] == '{' and sablon[j+1] == '%':
            let eb = sablon.find("%}", j + 2)
            if eb >= 0:
              let ic = sablon[j+2 ..< eb].strip()
              if ic.startsWith("for "): inc derinlikSayac
              elif ic == "endfor":
                dec derinlikSayac
                if derinlikSayac == 0:
                  forBitisKonum = j
                  break
            j = if eb >= 0: eb + 2 else: sablon.len
          else: inc j
        if forBitisKonum < 0: continue
        let forGovde = sablon[i ..< forBitisKonum]
        i = forBitisKonum + "{% endfor %}".len + 2
        let listeStr = degiskenAl(baglam, listeAdi)
        let elemanlar = if listeStr.len > 0: listeStr.split(",") else: newSeq[string]()
        for idx, eleman in elemanlar:
          var altBaglam = baglam
          altBaglam[degiskenAdi] = eleman.strip()
          altBaglam["loop_index"] = $idx
          altBaglam["loop_count"] = $(idx + 1)
          altBaglam["loop_first"] = if idx == 0: "true" else: "false"
          altBaglam["loop_last"] = if idx == elemanlar.len-1: "true" else: "false"
          result.add(isleParcali(forGovde, altBaglam, bloklar, makrolar, derinlik+1))
      # {% include "dosya.html" %}
      elif etiket.startsWith("include "):
        let dosyaAdi = etiket[8..^1].strip().strip(chars={'"', '\''})
        discard dosyaAdi  # yukleyici olmadan atlat
      # {% block isim %}
      elif etiket.startsWith("block "):
        let blokAdi = etiket[6..^1].strip()
        let endBlok = "{% endblock %}"
        let blokBitis = sablon.find(endBlok, i)
        if blokBitis >= 0:
          let blokIcerik = sablon[i ..< blokBitis]
          i = blokBitis + endBlok.len
          if blokAdi in bloklar:
            var altBaglam = baglam
            result.add(isleParcali(bloklar[blokAdi], altBaglam, bloklar, makrolar, derinlik+1))
          else:
            var altBaglam = baglam
            result.add(isleParcali(blokIcerik, altBaglam, bloklar, makrolar, derinlik+1))
      # {% raw %} ... {% endraw %}
      elif etiket == "raw":
        let rawBitis = sablon.find("{% endraw %}", i)
        if rawBitis >= 0:
          result.add(sablon[i ..< rawBitis])
          i = rawBitis + "{% endraw %}".len
      # {% set anahtar = deger %}
      elif etiket.startsWith("set ") and "=" in etiket:
        let setIcerik = etiket[4..^1]
        let eqIdx = setIcerik.find("=")
        let anahtar = setIcerik[0 ..< eqIdx].strip()
        let deger = setIcerik[eqIdx+1 ..< setIcerik.len].strip().strip(chars={'"', '\''})
        baglam[anahtar] = deger
      # bilinmeyen etiket - atla
    else:
      result.add(sablon[i])
      inc i

proc isle*(sablon: string, baglam: SablonBaglami = initTable[string, string]()): string =
  ## Sablonu isle ve sonucu dondur
  var degBaglam = baglam
  var bloklar = initTable[string, string]()
  var makrolar = initTable[string, MakroTanimi]()
  result = isleParcali(sablon, degBaglam, bloklar, makrolar)

proc isle*(yukleyici: SablonYukleyici, dosyaAdi: string,
           baglam: SablonBaglami = initTable[string, string]()): string =
  ## Sablon dosyasini yukle ve isle
  let sablon = yukleyici.dosyaOku(dosyaAdi)
  result = isle(sablon, baglam)

proc yeniBaglam*(): SablonBaglami =
  ## Bos sablon baglami olustur
  result = initTable[string, string]()

proc baglamEkle*(baglam: var SablonBaglami, anahtar: string, deger: string) =
  baglam[anahtar] = deger

proc baglamEkle*(baglam: var SablonBaglami, anahtar: string, deger: int) =
  baglam[anahtar] = $deger

proc baglamEkle*(baglam: var SablonBaglami, anahtar: string, deger: bool) =
  baglam[anahtar] = if deger: "true" else: "false"

proc baglamEkleSeq*(baglam: var SablonBaglami, anahtar: string, deger: seq[string]) =
  baglam[anahtar] = deger.join(",")

proc render*(yukleyici: SablonYukleyici, dosyaAdi: string,
             baglam: SablonBaglami = initTable[string, string]()): string =
  result = yukleyici.isle(dosyaAdi, baglam)

proc sablonIsle*(sablon: string, baglam: SablonBaglami): string =
  ## Uyumluluk: isle() ile ayni
  result = isle(sablon, baglam)
