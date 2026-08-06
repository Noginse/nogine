# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Şablon motoru testleri

import std/[unittest, json, tables, strutils]
import ../src/nogine/sablon

suite "Şablon Motoru Testleri":

  test "Değişken yerleştirme":
    var baglam = initTable[string, string]()
    baglam["isim"] = "Dünya"
    let sonuc = renderMetin("Merhaba {{isim}}!", baglam)
    check sonuc == "Merhaba Dünya!"

  test "Boşluklu değişken":
    var baglam = initTable[string, string]()
    baglam["deger"] = "42"
    let sonuc = renderMetin("Sayı: {{ deger }}", baglam)
    check sonuc == "Sayı: 42"

  test "Boolean değişken":
    var baglam = initTable[string, string]()
    baglam["aktif"] = %true
    let sonuc = renderMetin("Durum: {{aktif}}", baglam)
    check sonuc == "Durum: doğru"

  test "Yorum bloğu kaldırma":
    var baglam = initTable[string, string]()
    let sonuc = renderMetin("Merhaba {# Bu bir yorum #}Dünya", baglam)
    check sonuc == "Merhaba Dünya"

  test "If koşulu - doğru":
    var baglam = initTable[string, string]()
    baglam["admin"] = %true
    let sablon = "{% if admin %}Yönetici{% endif %}"
    let sonuc = renderMetin(sablon, baglam)
    check sonuc == "Yönetici"

  test "If koşulu - yanlış":
    var baglam = initTable[string, string]()
    baglam["admin"] = %false
    let sablon = "{% if admin %}Yönetici{% endif %}"
    let sonuc = renderMetin(sablon, baglam)
    check sonuc == ""

  test "If/else koşulu":
    var baglam = initTable[string, string]()
    baglam["girisYapti"] = %false
    let sablon = "{% if girisYapti %}Hoş geldin{% else %}Giriş yap{% endif %}"
    let sonuc = renderMetin(sablon, baglam)
    check sonuc == "Giriş yap"

  test "For döngüsü":
    var baglam = initTable[string, string]()
    baglam["renkler"] = %[%"kırmızı", %"mavi", %"yeşil"]
    let sablon = "{% for renk in renkler %}{{renk}} {% endfor %}"
    let sonuc = renderMetin(sablon, baglam)
    check sonuc.contains("kırmızı")
    check sonuc.contains("mavi")
    check sonuc.contains("yeşil")

  test "Döngü indeksi":
    var baglam = initTable[string, string]()
    baglam["ogeler"] = %[%"a", %"b"]
    let sablon = "{% for oge in ogeler %}{{dongu_sayac}}.{{oge}} {% endfor %}"
    let sonuc = renderMetin(sablon, baglam)
    check sonuc.contains("1.a")
    check sonuc.contains("2.b")

  test "Boş değişken değiştirilmez":
    var baglam = initTable[string, string]()
    let sonuc = renderMetin("{{eksikDegisken}}", baglam)
    check sonuc == "{{eksikDegisken}}"

when isMainModule:
  echo ""
  echo "Şablon testleri tamamlandı."