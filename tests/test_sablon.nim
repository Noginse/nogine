# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

import unittest
import std/tables
import ../src/nogine/sablon

suite "Sablon - Değişken Yerleştirme":
  test "Basit değişken":
    var baglam = yeniBaglam()
    baglamEkle(baglam, "isim", "Dünya")
    let sonuc = isle("Merhaba {{ isim }}!", baglam)
    check sonuc == "Merhaba Dünya!"

  test "Sayı değişkeni":
    var baglam = yeniBaglam()
    baglamEkle(baglam, "deger", 42)
    let sonuc = isle("Sayı: {{ deger }}", baglam)
    check sonuc == "Sayı: 42"

  test "Bool değişkeni":
    var baglam = yeniBaglam()
    baglamEkle(baglam, "aktif", true)
    let sonuc = isle("Durum: {{ aktif }}", baglam)
    check sonuc == "Durum: true"

  test "Yorum bloğu":
    var baglam = yeniBaglam()
    let sonuc = isle("Merhaba {# Bu bir yorum #}Dünya", baglam)
    check sonuc == "Merhaba Dünya"

suite "Sablon - Koşul Blokları":
  test "if - doğru koşul":
    var baglam = yeniBaglam()
    baglamEkle(baglam, "admin", "true")
    let sonuc = isle("{% if admin %}Yönetici{% endif %}", baglam)
    check sonuc == "Yönetici"

  test "if - yanlış koşul":
    var baglam = yeniBaglam()
    baglamEkle(baglam, "admin", "false")
    let sonuc = isle("{% if admin %}Yönetici{% endif %}", baglam)
    check sonuc == ""

  test "if/else":
    var baglam = yeniBaglam()
    baglamEkle(baglam, "girisYapti", "false")
    let sonuc = isle("{% if girisYapti %}Hoş geldin{% else %}Giriş yap{% endif %}", baglam)
    check sonuc == "Giriş yap"

suite "Sablon - For Döngüsü":
  test "Basit for döngüsü":
    var baglam = yeniBaglam()
    baglamEkle(baglam, "renkler", "kırmızı,mavi,yeşil")
    let sonuc = isle("{% for renk in renkler %}{{ renk }} {% endfor %}", baglam)
    check "kırmızı" in sonuc
    check "mavi" in sonuc
    check "yeşil" in sonuc

  test "Döngü sayacı":
    var baglam = yeniBaglam()
    baglamEkle(baglam, "ogeler", "a,b")
    let sonuc = isle("{% for oge in ogeler %}{{ loop_count }}.{{ oge }} {% endfor %}", baglam)
    check "1.a" in sonuc
    check "2.b" in sonuc

suite "Sablon - Filtreler":
  test "Büyük harf filtresi":
    var baglam = yeniBaglam()
    baglamEkle(baglam, "isim", "merhaba")
    let sonuc = isle("{{ isim | buyuk }}", baglam)
    check sonuc == "MERHABA"

  test "Küçük harf filtresi":
    var baglam = yeniBaglam()
    baglamEkle(baglam, "isim", "MERHABA")
    let sonuc = isle("{{ isim | kucuk }}", baglam)
    check sonuc == "merhaba"

  test "Eksik değişken boş döner":
    var baglam = yeniBaglam()
    let sonuc = isle("{{eksikDegisken}}", baglam)
    check sonuc == ""

echo "\nSablon testleri tamamlandı."
