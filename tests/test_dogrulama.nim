# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Doğrulama modülü testleri

import std/[unittest, json, strutils]
import ../src/nogine/dogrulama

suite "Doğrulama - Zorunlu Alan":

  test "Zorunlu alanlar mevcut - geçerli":
    let veri = %*{"isim": "Ali", "email": "ali@ornek.com"}
    var d = yeniDogrulama()
    d.zorunlu(veri, "isim", "email")
    check d.gecerliMi == true
    check d.hatalar.len == 0

  test "Zorunlu alan eksik - hata":
    let veri = %*{"isim": "Ali"}
    var d = yeniDogrulama()
    d.zorunlu(veri, "isim", "email")
    check d.gecerliMi == false
    check d.hatalar.len == 1

  test "Zorunlu alan boş string - hata":
    let veri = %*{"isim": ""}
    var d = yeniDogrulama()
    d.zorunlu(veri, "isim")
    check d.gecerliMi == false

suite "Doğrulama - E-posta":

  test "Geçerli e-posta":
    let veri = %*{"email": "test@ornek.com"}
    var d = yeniDogrulama()
    d.emailKontrol(veri, "email")
    check d.gecerliMi == true

  test "Geçersiz e-posta - @ yok":
    let veri = %*{"email": "gecersizemail"}
    var d = yeniDogrulama()
    d.emailKontrol(veri, "email")
    check d.gecerliMi == false

  test "Geçersiz e-posta - domain yok":
    let veri = %*{"email": "test@"}
    var d = yeniDogrulama()
    d.emailKontrol(veri, "email")
    check d.gecerliMi == false

suite "Doğrulama - Uzunluk":

  test "Minimum uzunluk - geçerli":
    let veri = %*{"sifre": "gizli123"}
    var d = yeniDogrulama()
    d.minUzunluk(veri, "sifre", 8)
    check d.gecerliMi == true

  test "Minimum uzunluk - çok kısa":
    let veri = %*{"sifre": "kisa"}
    var d = yeniDogrulama()
    d.minUzunluk(veri, "sifre", 8)
    check d.gecerliMi == false

  test "Maksimum uzunluk - geçerli":
    let veri = %*{"aciklama": "Kısa"}
    var d = yeniDogrulama()
    d.maxUzunluk(veri, "aciklama", 100)
    check d.gecerliMi == true