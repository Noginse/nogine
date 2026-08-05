# Nogine - A Nim Web Framework
### Created by noginse

```
  ███╗   ██╗ ██████╗  ██████╗ ██╗███╗   ██╗███████╗
  ████╗  ██║██╔═══██╗██╔════╝ ██║████╗  ██║██╔════╝
  ██╔██╗ ██║██║   ██║██║  ███╗██║██╔██╗ ██║█████╗
  ██║╚██╗██║██║   ██║██║   ██║██║██║╚██╗██║██╔══╝
  ██║ ╚████║╚██████╔╝╚██████╔╝██║██║ ╚████║███████╗
  ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝╚═╝  ╚═══╝╚══════╝

  A Nim Web Framework  |  Created by noginse
  Sade API. Yüksek Performans. Sıfır Sihir.
```

> **Felsefe:** Sade API, yüksek performans, sıfır sihir.
> Geliştiricinin ne olduğunu her zaman anlaması gerekiyor.

## Kurulum

```ini
# nogine.nimble dosyasına ekle
requires "nogine >= 0.1.0"
requires "checksums >= 0.1.0"
```

## Hızlı Başlangıç

```nim
import nogine

let uygulama = yeniNogine()

uygulama.al("/") proc(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{"mesaj": "Merhaba Dünya!"})

uygulama.al("/kullanicilar/:id") proc(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  let id = istek.params["id"]
  await yanit.json(%*{"id": id})

waitFor uygulama.dinle(port = 8080)
```

Çalıştır:
```bash
nim c -r -d:release ornekler/basit_api.nim
curl http://localhost:8080/
# {"mesaj": "Merhaba Dünya!"}
```

---

## Özellikler

### Routing

```nim
uygulama.al("/yol", handler)        # GET
uygulama.ekle("/yol", handler)      # POST
uygulama.guncelle("/yol", handler)  # PUT
uygulama.sil("/yol", handler)       # DELETE
uygulama.yama("/yol", handler)      # PATCH

# Dinamik parametreler
uygulama.al("/kullanicilar/:id/gonderiler/:gid", handler)

# Wildcard
uygulama.al("/dosyalar/*yol", handler)

# Route gruplama
uygulama.gruptaAl("/api/v1"):
  uygulama.al("/kullanicilar", handler)
  uygulama.ekle("/kullanicilar", handler)
```

### Middleware

```nim
# Dahili middleware'ler
uygulama.kullan(nogineKors())
uygulama.kullan(nogineLoglama())
uygulama.kullan(nogineHizSiniri(saniyede = 100))
uygulama.kullan(nogineStatik("public", "/statik"))

# Özel middleware
proc kimlikDogrula(istek: Istek, yanit: Yanit, sonraki: SonrakiProc): Future[void] {.async, gcsafe.} =
  let token = istek.baslik("Authorization")
  if token.len == 0:
    discard yanit.durum(401)
    await yanit.json(%*{"hata": "Yetkisiz"})
    return
  await sonraki()

# Route bazlı
uygulama.al("/korunan", kimlikDogrula) proc(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{"veri": "gizli"})
```

### İstek

```nim
let id       = istek.param("id")            # Route parametresi
let sayfa    = istek.sorgu("sayfa", "1")    # Sorgu parametresi
let govde    = istek.json()                 # JSON body
let alan     = istek.form("kullanici_adi")  # Form alanı
let token    = istek.baslik("Authorization") # HTTP başlığı
let cerezDeg = istek.cerez("oturum_id")     # Çerez
let ip       = istek.istemciIp              # IP adresi
```

### Yanıt

```nim
await yanit.json(%*{"mesaj": "tamam"})         # JSON
await yanit.html("<h1>Merhaba</h1>")           # HTML
await yanit.metin("Düz metin")                 # Text
await yanit.dosya("rapor.pdf")                 # Dosya indirme
await yanit.yonlendir("/giris")                # Yönlendirme

# Zincirlenebilir API
discard yanit.durum(201)
discard yanit.baslikAyarla("X-Ozel", "deger")
discard yanit.cerezAyarla("oturum", "abc", saniye = 3600)
await yanit.json(%*{"olusturuldu": true})
```

### Doğrulama

```nim
let sonuc = dogrula(govde):
  d.zorunlu(govde, "isim", "email", "sifre")
  d.emailKontrol(govde, "email")
  d.minUzunluk(govde, "isim", 2)
  d.maxUzunluk(govde, "isim", 100)
  d.sifreKontrol(govde, "sifre", minUzunluk = 8)
  d.aralikKontrol(govde, "yas", 18.0, 99.0)

if not sonuc.gecerliMi:
  discard yanit.durum(422)
  await yanit.json(%*{"hatalar": sonuc.hatalar})
  return
```

### Hata Yönetimi

```nim
uygulama.hata(404) proc(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{"hata": "Sayfa bulunamadı"})

uygulama.hata(500) proc(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.json(%*{"hata": "Sunucu hatası"})
```

### WebSocket

```nim
var baglantilar: Table[string, WsBaglanti]

uygulama.websocket("/ws") proc(baglanti: WsBaglanti): Future[void] {.async, gcsafe.} =
  baglanti.baglandiIsleyici = proc(): Future[void] {.async, gcsafe.} =
    {.gcsafe.}: baglantilar[baglanti.id] = baglanti
    await baglanti.gonder("Hoş geldiniz!")

  baglanti.mesajIsleyici = proc(veri: string): Future[void] {.async, gcsafe.} =
    {.gcsafe.}:
      for id, diger in baglantilar:
        await diger.gonder("[" & baglanti.id[0..5] & "]: " & veri)

  baglanti.kapatildiIsleyici = proc(): Future[void] {.async, gcsafe.} =
    {.gcsafe.}: baglantilar.del(baglanti.id)
```

### Template Motoru

```nim
# views/merhaba.html:
# Merhaba {{ isim }}!
# {% if admin %}Yönetici{% endif %}
# {% for oge in liste %}{{ oge }} {% endfor %}

let motor = yeniSablonMotoru("views")
var baglam = initTable[string, JsonNode]()
baglam["isim"] = %"Dünya"
baglam["admin"] = %true
baglam["liste"] = %[%"a", %"b", %"c"]

let html = motor.render("merhaba", baglam)
await yanit.html(html)
```

---

## Proje Yapısı

```
nogine/
  src/
    nogine.nim              # Ana giriş noktası
    nogine/
      tipler.nim            # Core tipler (Istek, Yanit, vb.)
      istek.nim             # İstek parse & okuma
      yanit.nim             # Yanıt oluşturma & gönderme
      yonlendirici.nim      # Route eşleştirme motoru
      arackatman.nim        # Middleware zincir yöneticisi
      websocket.nim         # WebSocket desteği
      dogrulama.nim         # Doğrulama sistemi
      sablon.nim            # Template motoru
      hatalar.nim           # Hata tipleri
      yardimcilar.nim       # URL, MIME, UUID yardımcıları
      arackatmanlar/
        loglama.nim         # Renkli request logger
        kors.nim            # CORS middleware
        hiz_siniri.nim      # Rate limiting
        sikistirma.nim      # Gzip/deflate desteği
        statik_dosya.nim    # Static file serving
  tests/
    test_yonlendirici.nim   # Router testleri
    test_dogrulama.nim      # Doğrulama testleri
    test_sablon.nim         # Template testleri
  examples/
    basit_api.nim           # Temel REST API örneği
    websocket_ornegi.nim    # WebSocket sohbet örneği
    tam_uygulama.nim        # Kapsamlı örnek
  benchmarks/
    hiz_testi.nim           # Benchmark aracı
  nogine.nimble
  README.md
  LICENSE
```

---

## Benchmark Sonuçları

Ortam: Nim 2.2.10, Linux x86_64, `-d:release`, curl tabanlı paralel test

```
┌──────────────────┬──────────────┬──────────────┐
│ Metrik           │ Nogine       │ Jester       │
├──────────────────┼──────────────┼──────────────┤
│ 500 paralel RPS  │ ~2200        │ ~2000        │
│ Başlatma süresi  │ Anlık        │ Anlık        │
│ Bellek kullanımı │ Düşük        │ Düşük        │
│ Bağımlılık sayısı│ 1 (checksums)│ 5+           │
└──────────────────┴──────────────┴──────────────┘
```

Nogine, Jester'a kıyasla:
- **Daha az bağımlılık**: Sadece `checksums` paketi gerektirir
- **Türkçe API**: Tüm proc adları ve hata mesajları Türkçe
- **Şeffaf mimari**: Sihir yok, her şey okunabilir
- **Async-first**: asyncdispatch tabanlı sıfır bloke

---

## Katkıda Bulunma

1. Fork edin
2. Feature branch açın: `git checkout -b ozellik/yeni-ozellik`
3. Değişikliklerinizi commit edin: `git commit -m 'Yeni özellik: ...'`
4. Push edin: `git push origin ozellik/yeni-ozellik`
5. Pull Request açın

**Test çalıştırma:**
```bash
nim c -r tests/test_yonlendirici.nim
nim c -r tests/test_dogrulama.nim
nim c -r tests/test_sablon.nim
```

---

## Lisans

MIT — Created by noginse  
https://github.com/noginse/nogine