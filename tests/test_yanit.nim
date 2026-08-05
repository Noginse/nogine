# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Yanıt (response) modülü testleri.
## Durum kodları, başlık yönetimi, çerez, zincirlenebilir API.

import std/[unittest, tables, asyncdispatch, strutils]
import ../src/nogine/tipler
import ../src/nogine/yanit
import ../src/nogine/yardimcilar

## soket gerektirmeyen minimal Yanit oluşturucu (test amacıyla)
proc testYanit(): Yanit =
  result = Yanit(
    durumKodu: 200,
    basliklar: initTable[string, string](),
    govde: "",
    gonderildi: false,
    soket: nil
  )

suite "Yanıt Durum Kodu Testleri":

  test "Varsayılan durum 200":
    let y = testYanit()
    check y.durumKodu == 200

  test "Durum kodu değiştirme":
    var y = testYanit()
    let d = y.durum(404)
    check y.durumKodu == 404
    check d.durumKodu == 404

  test "Durum kodu 201":
    var y = testYanit()
    discard y.durum(201)
    check y.durumKodu == 201

  test "Başlangıçta gönderilmedi":
    let y = testYanit()
    check y.gonderildi == false

suite "Yanıt Başlık Testleri":

  test "Başlık ekleme - küçük harfe normalize":
    var y = testYanit()
    discard y.baslikAyarla("Content-Type", "application/json")
    check "content-type" in y.basliklar
    check y.basliklar["content-type"] == "application/json"

  test "Çoklu başlık":
    var y = testYanit()
    discard y.baslikAyarla("X-A", "deger1")
    discard y.baslikAyarla("X-B", "deger2")
    check y.basliklar["x-a"] == "deger1"
    check y.basliklar["x-b"] == "deger2"

  test "Zincirlenebilir API - durum + başlık":
    var y = testYanit()
    discard y.durum(201).baslikAyarla("X-Olusturuldu", "evet")
    check y.durumKodu == 201
    check y.basliklar["x-olusturuldu"] == "evet"

suite "Yanıt Çerez Testleri":

  test "Çerez ayarlama - temel":
    var y = testYanit()
    discard y.cerezAyarla("oturum", "abc123")
    check "set-cookie" in y.basliklar
    let cv = y.basliklar["set-cookie"]
    check "oturum=abc123" in cv

  test "Çerez - Max-Age ayarı":
    var y = testYanit()
    discard y.cerezAyarla("token", "xyz", saniye = 3600)
    check "Max-Age=3600" in y.basliklar["set-cookie"]

  test "Çerez - yol":
    var y = testYanit()
    discard y.cerezAyarla("x", "1", yol = "/api")
    check "Path=/api" in y.basliklar["set-cookie"]

  test "Çerez silme - Max-Age=0":
    var y = testYanit()
    discard y.cerezSil("oturum")
    check "set-cookie" in y.basliklar
    check "Max-Age=0" in y.basliklar["set-cookie"]

suite "HTTP Durum Kodu Açıklamaları":

  test "1xx": check durumAciklamasi(100) == "Devam Et"
  test "200": check durumAciklamasi(200) == "Tamam"
  test "201": check durumAciklamasi(201) == "Oluşturuldu"
  test "204": check durumAciklamasi(204) == "İçerik Yok"
  test "301": check durumAciklamasi(301) == "Kalıcı Yönlendirme"
  test "302": check durumAciklamasi(302) == "Geçici Yönlendirme"
  test "304": check durumAciklamasi(304) == "Değiştirilmedi"
  test "400": check durumAciklamasi(400) == "Hatalı İstek"
  test "401": check durumAciklamasi(401) == "Yetkisiz"
  test "403": check durumAciklamasi(403) == "Yasaklandı"
  test "404": check durumAciklamasi(404) == "Bulunamadı"
  test "429": check durumAciklamasi(429) == "Çok Fazla İstek"
  test "500": check durumAciklamasi(500) == "Sunucu Hatası"
  test "503": check durumAciklamasi(503) == "Hizmet Kullanılamıyor"

when isMainModule:
  echo "Yanıt testleri tamamlandı."