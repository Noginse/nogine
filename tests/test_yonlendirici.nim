# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Yönlendirici ve yardımcı modül testleri

import std/[unittest, tables, asyncdispatch, strutils]
import ../src/nogine/tipler
import ../src/nogine/yonlendirici
import ../src/nogine/yardimcilar

suite "Yönlendirici Testleri":

  test "Statik rota eşleşmesi - başarılı":
    var params = initTable[string, string]()
    check rotaEslestir("/kullanicilar", "/kullanicilar", params) == true

  test "Statik rota eşleşmesi - başarısız":
    var params = initTable[string, string]()
    check rotaEslestir("/kullanicilar", "/profil", params) == false

  test "Dinamik parametre eşleşmesi":
    var params = initTable[string, string]()
    check rotaEslestir("/kullanicilar/:id", "/kullanicilar/42", params) == true
    check params["id"] == "42"

  test "Çoklu dinamik parametre":
    var params = initTable[string, string]()
    check rotaEslestir("/kullanicilar/:id/gonderiler/:gid",
                       "/kullanicilar/5/gonderiler/99", params) == true
    check params["id"] == "5"
    check params["gid"] == "99"

  test "Wildcard rota":
    var params = initTable[string, string]()
    check rotaEslestir("/dosyalar/*yol", "/dosyalar/resimler/foto.jpg", params) == true
    check params["yol"] == "resimler/foto.jpg"

  test "Kök rota eşleşmesi":
    var params = initTable[string, string]()
    check rotaEslestir("/", "/", params) == true

  test "Eksik parametre eşleşmemeli":
    var params = initTable[string, string]()
    check rotaEslestir("/kullanicilar/:id", "/kullanicilar", params) == false

  test "Route listesinde doğru arama":
    var bosHandler: IsleyiciProc
    bosHandler = proc(i: Istek, y: Yanit): Future[void] {.async, gcsafe.} = discard
    var rotalar: seq[RotaTanimi]
    rotalar = @[
      yeniRota(hmGET, "/", bosHandler),
      yeniRota(hmGET, "/kullanicilar/:id", bosHandler),
      yeniRota(hmPOST, "/kullanicilar", bosHandler),
    ]
    var params = initTable[string, string]()

    check rotaBul(rotalar, hmGET, "/", params) == 0
    check rotaBul(rotalar, hmGET, "/kullanicilar/5", params) == 1
    check params["id"] == "5"
    check rotaBul(rotalar, hmPOST, "/kullanicilar", params) == 2
    check rotaBul(rotalar, hmDELETE, "/kullanicilar", params) == -1

  test "Desen bölümleme":
    let b1: seq[string] = @["kullanicilar", "gonderiler"]
    let b2: seq[string] = @[]
    let b3: seq[string] = @["tek"]
    check deseniBol("/kullanicilar/gonderiler") == b1
    check deseniBol("/") == b2
    check deseniBol("/tek") == b3

  test "Wildcard tespiti":
    check wildcardMi("/dosyalar/*yol") == true
    check wildcardMi("/kullanicilar/:id") == false

  test "Parametrik segment tespiti":
    check parametrikMi(":id") == true
    check parametrikMi("kullanicilar") == false

suite "Yardımcı Fonksiyon Testleri":

  test "Sorgu string parse - basit":
    let sonuc = sorguyuCozumle("sayfa=1&boyut=10")
    check sonuc["sayfa"] == "1"
    check sonuc["boyut"] == "10"

  test "Sorgu string parse - soru işaretli":
    let sonuc = sorguyuCozumle("?sayfa=2&boyut=5")
    check sonuc["sayfa"] == "2"

  test "URL kodlama/çözme":
    let orijinal = "Merhaba+Dunya"
    let kodlanmis = urlKodla(orijinal)
    let cozulmus = urlCoz(kodlanmis)
    check cozulmus == orijinal

  test "MIME tipi - HTML":
    check mimeHesapla(".html") == "text/html; charset=utf-8"

  test "MIME tipi - JSON":
    check mimeHesapla(".json") == "application/json; charset=utf-8"

  test "MIME tipi - PNG":
    check mimeHesapla(".png") == "image/png"

  test "MIME tipi - bilinmeyen":
    check mimeHesapla(".xyz") == "application/octet-stream"

  test "Çerez parse":
    let cerezler = cerezleriCozumle("oturum=abc123; dil=tr; tema=karanlik")
    check cerezler["oturum"] == "abc123"
    check cerezler["dil"] == "tr"
    check cerezler["tema"] == "karanlik"

  test "UUID üretme - format kontrolü":
    let uuid1 = uuidUret()
    let uuid2 = uuidUret()
    check uuid1.len == 36
    check uuid1[8] == '-'
    check uuid1[13] == '-'
    check uuid1[18] == '-'
    check uuid1[23] == '-'
    check uuid1 != uuid2

  test "Boyut biçimlendirme":
    check boyutBicimlendir(500) == "500 B"
    check boyutBicimlendir(1536) == "1 KB"
    check boyutBicimlendir(1048576) == "1 MB"

  test "Sabit karşılaştırma":
    check sabitKarsilastir("abc", "abc") == true
    check sabitKarsilastir("abc", "xyz") == false
    check sabitKarsilastir("abc", "abcd") == false

suite "HTTP Durum Kodları Testleri":

  test "200 açıklaması":
    check durumAciklamasi(200) == "Tamam"

  test "404 açıklaması":
    check durumAciklamasi(404) == "Bulunamadı"

  test "500 açıklaması":
    check durumAciklamasi(500) == "Sunucu Hatası"

  test "Metod dönüşümü":
    check metodDonustur("GET") == hmGET
    check metodDonustur("POST") == hmPOST
    check metodDonustur("DELETE") == hmDELETE
    check metodDonustur("get") == hmGET

when isMainModule:
  echo ""
  echo "Yönlendirici ve yardımcı testleri tamamlandı."