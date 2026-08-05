# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Middleware (arackatman) sistemi testleri.
## Zincir çalışma sırası, sonraki çağrısı, erken durdurma.

import std/[unittest, asyncdispatch, tables]
import ../src/nogine/tipler
import ../src/nogine/yanit
import ../src/nogine/arackatman

## Test için minimal Istek ve Yanit oluştur
proc testIstek(): Istek =
  result = Istek(
    metod: hmGET,
    yol: "/test",
    sorguSatiri: "",
    basliklar: initTable[string, string](),
    govde: "",
    params: initTable[string, string](),
    sorguParams: initTable[string, string](),
    cerezler: initTable[string, string](),
    dosyalar: initTable[string, YuklenenDosya](),
    formVerisi: initTable[string, string](),
    istemciIp: "127.0.0.1",
    protokol: "HTTP/1.1",
    soket: nil
  )

proc testYanit(): Yanit =
  result = Yanit(
    durumKodu: 200,
    basliklar: initTable[string, string](),
    govde: "",
    gonderildi: false,
    soket: nil
  )

suite "Middleware Zincir Testleri":

  test "Tek middleware + handler çalışır":
    var sira: seq[string] = @[]

    let m1: ArackatmanProc =
      proc(i: Istek, y: Yanit, s: SonrakiProc): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("m1_once")
        await s()
        {.gcsafe.}: sira.add("m1_sonra")

    let h: IsleyiciProc =
      proc(i: Istek, y: Yanit): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("handler")

    waitFor zincirleCalistir(@[m1], h, testIstek(), testYanit())
    check sira == @["m1_once", "handler", "m1_sonra"]

  test "Çoklu middleware sıralı çalışır":
    var sira: seq[string] = @[]

    let m1: ArackatmanProc =
      proc(i: Istek, y: Yanit, s: SonrakiProc): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("A")
        await s()

    let m2: ArackatmanProc =
      proc(i: Istek, y: Yanit, s: SonrakiProc): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("B")
        await s()

    let m3: ArackatmanProc =
      proc(i: Istek, y: Yanit, s: SonrakiProc): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("C")
        await s()

    let h: IsleyiciProc =
      proc(i: Istek, y: Yanit): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("H")

    waitFor zincirleCalistir(@[m1, m2, m3], h, testIstek(), testYanit())
    check sira == @["A", "B", "C", "H"]

  test "Erken durdurma - sonraki çağrılmazsa handler çalışmaz":
    var sira: seq[string] = @[]

    let bekci: ArackatmanProc =
      proc(i: Istek, y: Yanit, s: SonrakiProc): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("bekci")
        # sonraki() çağrılmıyor - zincir durur
        y.durumKodu = 401

    let h: IsleyiciProc =
      proc(i: Istek, y: Yanit): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("handler")

    let y = testYanit()
    waitFor zincirleCalistir(@[bekci], h, testIstek(), y)
    check sira == @["bekci"]
    check y.durumKodu == 401

  test "Middleware istek verisine erişebilir":
    var okunanYol = ""

    let m: ArackatmanProc =
      proc(i: Istek, y: Yanit, s: SonrakiProc): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: okunanYol = i.yol
        await s()

    let h: IsleyiciProc =
      proc(i: Istek, y: Yanit): Future[void] {.async, gcsafe.} = discard

    let istek = testIstek()
    istek.yol = "/api/kullanicilar"
    waitFor zincirleCalistir(@[m], h, istek, testYanit())
    check okunanYol == "/api/kullanicilar"

  test "Middleware yanıt başlığı ekleyebilir":
    let m: ArackatmanProc =
      proc(i: Istek, y: Yanit, s: SonrakiProc): Future[void] {.async, gcsafe.} =
        y.basliklar["x-test-id"] = "middleware-ekledi"
        await s()

    let h: IsleyiciProc =
      proc(i: Istek, y: Yanit): Future[void] {.async, gcsafe.} = discard

    let y = testYanit()
    waitFor zincirleCalistir(@[m], h, testIstek(), y)
    check y.basliklar["x-test-id"] == "middleware-ekledi"

  test "Boş middleware listesi - handler direkt çalışır":
    var calisti = false
    let h: IsleyiciProc =
      proc(i: Istek, y: Yanit): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: calisti = true

    waitFor zincirleCalistir(@[], h, testIstek(), testYanit())
    check calisti == true

  test "Yanıt gönderildiyse zincir devam etmez":
    var sira: seq[string] = @[]

    let m1: ArackatmanProc =
      proc(i: Istek, y: Yanit, s: SonrakiProc): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("m1")
        y.gonderildi = true  ## Yanıt gönderildi işaretle
        await s()

    let m2: ArackatmanProc =
      proc(i: Istek, y: Yanit, s: SonrakiProc): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("m2")
        await s()

    let h: IsleyiciProc =
      proc(i: Istek, y: Yanit): Future[void] {.async, gcsafe.} =
        {.gcsafe.}: sira.add("handler")

    waitFor zincirleCalistir(@[m1, m2], h, testIstek(), testYanit())
    check "m1" in sira
    check "m2" notin sira
    check "handler" notin sira

when isMainModule:
  echo ""
  echo "Middleware testleri tamamlandı."