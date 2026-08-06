# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine dosya yükleme modülü.
## Multipart form verisi işleme, disk kayıt, tip ve boyut kontrolü.

import std/[os, strutils, tables, times, random]
import ./tipler
import ./hatalar
import ./yardimcilar

type
  YuklemeAyarlari* = object
    maxBoyut*: int             ## Maksimum dosya boyutu (byte, varsayılan: 10MB)
    izinliTipler*: seq[string] ## İzin verilen MIME tipleri (boş = hepsi)
    hedefDizin*: string        ## Yükleme dizini
    benzersizAd*: bool         ## Dosya adını benzersiz yap
    adKoruma*: bool            ## Tehlikeli dosya adlarını temizle

  DosyaYuklemeHatasi* = object of NogineHatasi

proc varsayilanYuklemeAyarlari*(): YuklemeAyarlari =
  YuklemeAyarlari(
    maxBoyut: 10 * 1024 * 1024,  ## 10MB
    izinliTipler: @[],
    hedefDizin: "uploads",
    benzersizAd: true,
    adKoruma: true
  )

## Güvenli dosya adı oluştur
proc guvenliDosyaAdi*(ad: string): string =
  result = ""
  for c in ad:
    if c in {'a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.'}:
      result.add(c)
    else:
      result.add('_')
  if result.len == 0: result = "dosya"

## Benzersiz dosya adı üret
proc benzersizDosyaAdi*(uzanti: string): string =
  randomize()
  let zaman = $toUnix(getTime())
  let rastgele = $rand(99999)
  result = zaman & "_" & rastgele & uzanti

## MIME tipini doğrula
proc tipDogrula*(icerikTipi: string, izinliTipler: seq[string]): bool =
  if izinliTipler.len == 0: return true
  for tip in izinliTipler:
    if icerikTipi.startsWith(tip): return true
  result = false

## Multipart boundary'yi başlıktan çıkar
proc boundaryAl*(icerikTipi: string): string =
  result = ""
  for parca in icerikTipi.split(";"):
    let temiz = parca.strip()
    if temiz.toLowerAscii().startsWith("boundary="):
      result = temiz[9..^1].strip(chars={'"', '\''})
      return

## Multipart verisini ayrıştır - gelişmiş versiyon
proc multipartAyristir*(govde: string, boundary: string): seq[YuklenenDosya] =
  result = @[]
  if boundary.len == 0 or govde.len == 0: return
  
  let sinir = "--" & boundary
  let sonSinir = "--" & boundary & "--"
  var konum = 0
  
  while konum < govde.len:
    # Sınır çizgisini bul
    let sinirKonum = govde.find(sinir, konum)
    if sinirKonum < 0: break
    
    # Son sınır mı?
    let sinirSonu = sinirKonum + sinir.len
    if sinirSonu + 2 <= govde.len and govde[sinirSonu..sinirSonu+1] == "--":
      break
    
    # \r\n'yi atla
    var parcaBas = sinirSonu
    if parcaBas + 1 < govde.len and govde[parcaBas] == '\r':
      parcaBas += 2
    elif parcaBas < govde.len and govde[parcaBas] == '\n':
      parcaBas += 1
    
    # Başlık sonu bul (\r\n\r\n)
    let baslikSonu = govde.find("\r\n\r\n", parcaBas)
    if baslikSonu < 0:
      konum = sinirKonum + sinir.len
      continue
    
    let baslikMetni = govde[parcaBas..<baslikSonu]
    var icerikBas = baslikSonu + 4
    
    # Sonraki sınırı bul
    let sonrakiSinir = govde.find("\r\n" & sinir, icerikBas)
    let icerikSon = if sonrakiSinir >= 0: sonrakiSinir else: govde.len
    let icerik = govde[icerikBas..<icerikSon]
    
    # Başlıkları ayrıştır
    var dosyaIsim = ""
    var alanAdi = ""
    var icerikTipi = "application/octet-stream"
    
    for satir in baslikMetni.split("\r\n"):
      let satirKucuk = satir.toLowerAscii()
      if satirKucuk.startsWith("content-disposition:"):
        for parca in satir.split(";"):
          let p = parca.strip()
          if p.toLowerAscii().startsWith("name="):
            alanAdi = p[5..^1].strip(chars={'"', '\''})
          elif p.toLowerAscii().startsWith("filename="):
            dosyaIsim = p[9..^1].strip(chars={'"', '\''})
      elif satirKucuk.startsWith("content-type:"):
        icerikTipi = satir.split(":")[1].strip()
    
    if dosyaIsim.len > 0 or alanAdi.len > 0:
      result.add(YuklenenDosya(
        isim: dosyaIsim,
        icerikTipi: icerikTipi,
        boyut: icerik.len,
        veri: icerik
      ))
    
    konum = if sonrakiSinir >= 0: sonrakiSinir + 2 else: govde.len

## Dosyayı diske kaydet
proc diskKaydet*(dosya: YuklenenDosya, ayarlar: YuklemeAyarlari): string =
  ## Döndürülen değer: kaydedilen dosyanın tam yolu
  
  if dosya.boyut > ayarlar.maxBoyut:
    raise newException(DosyaYuklemeHatasi,
      "Dosya boyutu aşıldı. Maksimum: " & 
      boyutBicimlendir(ayarlar.maxBoyut) &
      ", Gelen: " & boyutBicimlendir(dosya.boyut))
  
  if not tipDogrula(dosya.icerikTipi, ayarlar.izinliTipler):
    raise newException(DosyaYuklemeHatasi,
      "İzin verilmeyen dosya tipi: " & dosya.icerikTipi)
  
  # Dizini oluştur
  if not dirExists(ayarlar.hedefDizin):
    createDir(ayarlar.hedefDizin)
  
  # Dosya adını belirle
  let uzanti = if "." in dosya.isim:
                 "." & dosya.isim.split(".")[^1]
               else: ""
  
  let dosyaAdi = if ayarlar.benzersizAd:
                   benzersizDosyaAdi(uzanti)
                 elif ayarlar.adKoruma:
                   guvenliDosyaAdi(dosya.isim)
                 else:
                   dosya.isim
  
  let tamYol = ayarlar.hedefDizin / dosyaAdi
  writeFile(tamYol, dosya.veri)
  result = tamYol

## İstekten dosya yükle
proc dosyaYukle*(istek: Istek, alanAdi: string,
                 ayarlar: YuklemeAyarlari = varsayilanYuklemeAyarlari()): string =
  ## Döndürülen değer: kaydedilen dosya yolu
  let icerikTipi = istek.basliklar.getOrDefault("content-type", "")
  let boundary = boundaryAl(icerikTipi)
  
  if boundary.len == 0:
    raise newException(DosyaYuklemeHatasi, "Multipart boundary bulunamadı")
  
  let dosyalar = multipartAyristir(istek.govde, boundary)
  for dosya in dosyalar:
    if dosya.isim.len > 0:
      result = diskKaydet(dosya, ayarlar)
      return
  
  raise newException(DosyaYuklemeHatasi, "'" & alanAdi & "' alanında dosya bulunamadı")

## Çoklu dosya yükle
proc cokluDosyaYukle*(istek: Istek,
                       ayarlar: YuklemeAyarlari = varsayilanYuklemeAyarlari()): seq[string] =
  result = @[]
  let icerikTipi = istek.basliklar.getOrDefault("content-type", "")
  let boundary = boundaryAl(icerikTipi)
  if boundary.len == 0: return
  
  let dosyalar = multipartAyristir(istek.govde, boundary)
  for dosya in dosyalar:
    if dosya.isim.len > 0 and dosya.boyut > 0:
      result.add(diskKaydet(dosya, ayarlar))
