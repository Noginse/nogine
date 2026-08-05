# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## İstek (request) modülü testleri.
## Not: Gerçek soket gerektiren testler entegrasyon testlerine ayrılmıştır.
## Bu suite parse fonksiyonlarını doğrudan test eder.

import std/[unittest, tables, strutils, json]
import ../src/nogine/yardimcilar

suite "Sorgu Parametresi Parse Testleri":

  test "Basit anahtar=deger":
    let p = sorguyuCozumle("isim=Ali&sehir=Ankara")
    check p["isim"] == "Ali"
    check p["sehir"] == "Ankara"

  test "Soru işareti ile":
    let p = sorguyuCozumle("?sayfa=3&boyut=20")
    check p["sayfa"] == "3"
    check p["boyut"] == "20"

  test "URL kodlu değer":
    let p = sorguyuCozumle("mesaj=Merhaba%20Dunya")
    check p["mesaj"] == "Merhaba Dunya"

  test "Boş sorgu":
    let p = sorguyuCozumle("")
    check p.len == 0

  test "Değersiz anahtar":
    let p = sorguyuCozumle("bayrak&diger=var")
    check "bayrak" in p
    check p["diger"] == "var"

suite "Çerez Parse Testleri":

  test "Tek çerez":
    let c = cerezleriCozumle("oturum=abc123")
    check c["oturum"] == "abc123"

  test "Çoklu çerez":
    let c = cerezleriCozumle("oturum=abc; dil=tr; tema=karanlik")
    check c["oturum"] == "abc"
    check c["dil"] == "tr"
    check c["tema"] == "karanlik"

  test "Boş çerez başlığı":
    let c = cerezleriCozumle("")
    check c.len == 0

suite "Multipart Form Parse Testleri":

  test "Basit multipart alanı":
    let sinir = "----boundary123"
    let govde = "------boundary123\r\n" &
                "Content-Disposition: form-data; name=\"kullanici\"\r\n\r\n" &
                "Ali\r\n" &
                "------boundary123--"
    let form = multipartFormCozumle(govde, "----boundary123")
    check "kullanici" in form

  test "URL encode/decode döngüsü":
    let orijinal = "Merhaba Dünya & test=1"
    let kodlanmis = urlKodla(orijinal)
    let cozulmus = urlCoz(kodlanmis)
    check cozulmus == orijinal

suite "HTTP Yardımcı Testleri":

  test "MIME: HTML":
    check mimeHesapla(".html") == "text/html; charset=utf-8"

  test "MIME: JS":
    check mimeHesapla(".js") == "application/javascript; charset=utf-8"

  test "MIME: PNG":
    check mimeHesapla(".png") == "image/png"

  test "MIME: bilinmeyen":
    check mimeHesapla(".xyz") == "application/octet-stream"

  test "Base64 kodla/çöz":
    let metin = "Nogine - A Nim Web Framework"
    let kodlu = base64Kodla(metin)
    check base64Coz(kodlu) == metin

  test "Güvenli int dönüşüm - geçerli":
    check guvenliInt("42") == 42

  test "Güvenli int dönüşüm - geçersiz":
    check guvenliInt("abc", -1) == -1

  test "Boyut biçimlendirme - byte":
    check boyutBicimlendir(512) == "512 B"

  test "Boyut biçimlendirme - KB":
    check boyutBicimlendir(2048) == "2 KB"

  test "Boyut biçimlendirme - MB":
    check boyutBicimlendir(2097152) == "2 MB"

  test "HTTP zamanı RFC formatı":
    let t = httpZamani()
    check t.endsWith(" GMT")
    check t.len > 20

when isMainModule:
  echo ""
  echo "İstek yardımcı testleri tamamlandı."