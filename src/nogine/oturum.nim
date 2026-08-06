# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine oturum (session) yönetim modülü.
## Bellek tabanlı oturum deposu, cookie entegrasyonu.

import std/[tables, times, random]
import ./tipler
import ./yardimcilar

type
  ## Tek bir oturum kaydı
  Oturum* = ref object
    id*: string
    veri*: Table[string, string]
    olusturma*: Time
    sonDegisiklik*: Time
    suresi*: int           ## Saniye (0 = oturum sona erince)
    aktif*: bool

  ## Oturum deposu (bellek tabanlı)
  OturumDepo* = ref object
    oturumlar*: Table[string, Oturum]
    cerezAdi*: string

  ## Oturum ayarları
  OturumAyarlari* = object
    cerezAdi*: string
    suresi*: int
    guvenli*: bool
    httpSadece*: bool
    yol*: string

proc varsayilanOturumAyarlari*(): OturumAyarlari =
  OturumAyarlari(
    cerezAdi: "nogine_oturum",
    suresi: 3600,
    guvenli: false,
    httpSadece: true,
    yol: "/"
  )

proc yeniOturumDepo*(): OturumDepo =
  result = OturumDepo(
    oturumlar: initTable[string, Oturum](),
    cerezAdi: "nogine_oturum"
  )

proc yeniOturum*(id: string = ""): Oturum =
  let oturumId = if id.len > 0: id else: uuidUret()
  result = Oturum(
    id: oturumId,
    veri: initTable[string, string](),
    olusturma: getTime(),
    sonDegisiklik: getTime(),
    suresi: 3600,
    aktif: true
  )

## Oturum ID'sini isteğin çerezinden al, yoksa yeni oluştur
proc oturumAl*(depo: OturumDepo, istek: Istek): Oturum =
  let cerezDegeri = istek.cerezler.getOrDefault(depo.cerezAdi, "")
  if cerezDegeri.len > 0 and cerezDegeri in depo.oturumlar:
    result = depo.oturumlar[cerezDegeri]
    result.sonDegisiklik = getTime()
  else:
    result = yeniOturum()
    depo.oturumlar[result.id] = result

## Oturumu yanıta kaydet (çerez ayarla)
proc oturumKaydet*(depo: OturumDepo, oturum: Oturum, yanit: Yanit,
                   ayarlar: OturumAyarlari = varsayilanOturumAyarlari()) =
  depo.oturumlar[oturum.id] = oturum
  var cerezDeger = ayarlar.cerezAdi & "=" & oturum.id & "; Path=" & ayarlar.yol
  if ayarlar.suresi > 0:
    cerezDeger &= "; Max-Age=" & $ayarlar.suresi
  if ayarlar.guvenli:
    cerezDeger &= "; Secure"
  if ayarlar.httpSadece:
    cerezDeger &= "; HttpOnly"
  yanit.basliklar["set-cookie"] = cerezDeger

## Oturumda değer al
proc `[]`*(oturum: Oturum, anahtar: string): string =
  result = oturum.veri.getOrDefault(anahtar, "")

## Oturumda değer ata
proc `[]=`*(oturum: Oturum, anahtar: string, deger: string) =
  oturum.veri[anahtar] = deger
  oturum.sonDegisiklik = getTime()

## Oturumda değer var mı?
proc varMi*(oturum: Oturum, anahtar: string): bool =
  result = anahtar in oturum.veri

## Oturumdan değer sil
proc sil*(oturum: Oturum, anahtar: string) =
  oturum.veri.del(anahtar)

## Giriş yapıldı mı?
proc girisYapmisMi*(oturum: Oturum): bool =
  result = oturum.aktif and oturum.veri.getOrDefault("_giris", "") == "1"

## Giriş yap
proc girisYap*(oturum: Oturum, kullanici: string) =
  oturum.veri["_giris"] = "1"
  oturum.veri["_kullanici"] = kullanici
  oturum.sonDegisiklik = getTime()

## Çıkış yap
proc cikisYap*(oturum: Oturum) =
  oturum.veri.del("_giris")
  oturum.veri.del("_kullanici")
  oturum.aktif = false

## Oturum kullanıcı adı
proc kullanici*(oturum: Oturum): string =
  result = oturum.veri.getOrDefault("_kullanici", "")

## Oturumu tamamen temizle
proc temizle*(oturum: Oturum) =
  oturum.veri.clear()
  oturum.aktif = false

## Flash mesaj ekle (bir sonraki istekte okunur ve silinir)
proc flash*(oturum: Oturum, mesaj: string, tur: string = "bilgi") =
  oturum.veri["_flash_" & tur] = mesaj

## Flash mesaj oku ve sil
proc flashAl*(oturum: Oturum, tur: string = "bilgi"): string =
  let anahtar = "_flash_" & tur
  result = oturum.veri.getOrDefault(anahtar, "")
  if result.len > 0:
    oturum.veri.del(anahtar)

## Süresi geçmiş oturumları temizle
proc eskiOturumlariSil*(depo: OturumDepo) =
  let simdi = getTime()
  var silinecekler: seq[string] = @[]
  for id, oturum in depo.oturumlar:
    let gecen = (simdi - oturum.sonDegisiklik).inSeconds
    if gecen > oturum.suresi and oturum.suresi > 0:
      silinecekler.add(id)
  for id in silinecekler:
    depo.oturumlar.del(id)