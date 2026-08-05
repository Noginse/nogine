# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## WebSocket modülü testleri.

import std/[unittest, asyncdispatch, asyncnet, tables, strutils]
import ../src/nogine/websocket
import ../src/nogine/tipler
import ../src/nogine/yardimcilar

# ─── Unit Testler ────────────────────────────────────────────────────────────

suite "WebSocket Opcode Testleri":

  test "Metin opcode 0x1":
    check wocMetin.int == 0x1

  test "İkili opcode 0x2":
    check wocIkili.int == 0x2

  test "Kapat opcode 0x8":
    check wocKapat.int == 0x8

  test "Ping opcode 0x9":
    check wocPing.int == 0x9

  test "Pong opcode 0xA":
    check wocPong.int == 0xA

  test "Devam opcode 0x0":
    check wocDevam.int == 0x0

  test "FIN+Metin byte = 0x81":
    check (0x80 or wocMetin.int) == 0x81

  test "FIN+Ping byte = 0x89":
    check (0x80 or wocPing.int) == 0x89

  test "FIN+Pong byte = 0x8A":
    check (0x80 or wocPong.int) == 0x8A

  test "FIN+Kapat byte = 0x88":
    check (0x80 or wocKapat.int) == 0x88

suite "WebSocket Frame Encode Testleri":

  test "Küçük metin frame ilk byte 0x81":
    let frame = wsFrameKodla("Merhaba", wocMetin)
    check frame.len > 0
    check frame[0].uint8 == 0x81

  test "Frame payload length doğru":
    let mesaj = "Merhaba"
    let frame = wsFrameKodla(mesaj, wocMetin)
    check (frame[1].uint8 and 0x7F) == mesaj.len.uint8

  test "Boş mesaj frame - en az 2 byte":
    let frame = wsFrameKodla("", wocMetin)
    check frame.len >= 2

  test "Ping frame ilk byte 0x89":
    let frame = wsFrameKodla("", wocPing)
    check frame[0].uint8 == 0x89

  test "Pong frame ilk byte 0x8A":
    let frame = wsFrameKodla("", wocPong)
    check frame[0].uint8 == 0x8A

  test "Kapat frame ilk byte 0x88":
    let frame = wsFrameKodla("", wocKapat)
    check frame[0].uint8 == 0x88

  test "Uzun mesaj (200 byte) 16-bit uzunluk başlığı":
    let uzunMesaj = repeat('A', 200)
    let frame = wsFrameKodla(uzunMesaj, wocMetin)
    check (frame[1].uint8 and 0x7F) == 126
    let uzunluk = (frame[2].uint8.int shl 8) or frame[3].uint8.int
    check uzunluk == 200

  test "Frame decode - encode/decode döngüsü":
    let mesaj = "Nogine WebSocket Test"
    let frame = wsFrameKodla(mesaj, wocMetin)
    let (opcode, payload, tamamMi) = wsFrameCoz(frame)
    check tamamMi == true
    check opcode == wocMetin
    check payload == mesaj

  test "Boş mesaj decode döngüsü":
    let frame = wsFrameKodla("", wocMetin)
    let (_, payload, tamamMi) = wsFrameCoz(frame)
    check tamamMi == true
    check payload == ""

suite "WebSocket RFC 6455 Testleri":

  test "RFC 6455 bölüm 1.3 referans örneği":
    let clientKey = "dGhlIHNhbXBsZSBub25jZQ=="
    let beklenen  = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
    check wsAcceptAnahtari(clientKey) == beklenen

  test "Magic key RFC 6455 bölüm 1.3":
    ## Sabit değer wsAcceptAnahtari içinde kullanılır, doğruluğunu round-trip ile kontrol et
    let key = "dGhlIHNhbXBsZSBub25jZQ=="
    check wsAcceptAnahtari(key) == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="

  test "Farklı key farklı accept üretir":
    let k1 = wsAcceptAnahtari("dGhlIHNhbXBsZSBub25jZQ==")
    let k2 = wsAcceptAnahtari("YWJjMTIz")
    check k1 != k2

suite "WebSocket Bağlantı Nesnesi Testleri":

  test "yeniBaglanti UUID üretir (36 karakter)":
    let b = yeniBaglanti(nil)
    check b.id.len == 36

  test "UUID tire pozisyonları doğru":
    let b = yeniBaglanti(nil)
    check b.id[8]  == '-'
    check b.id[13] == '-'
    check b.id[18] == '-'
    check b.id[23] == '-'

  test "yeniBaglanti başlangıçta bağlı":
    let b = yeniBaglanti(nil)
    check b.bagliMi == true

  test "yeniBaglanti odaları boş":
    let b = yeniBaglanti(nil)
    check b.odalar.len == 0

  test "Birden fazla bağlantı benzersiz ID":
    let b1 = yeniBaglanti(nil)
    let b2 = yeniBaglanti(nil)
    let b3 = yeniBaglanti(nil)
    check b1.id != b2.id
    check b2.id != b3.id

  test "Odaya katılma":
    let b = yeniBaglanti(nil)
    b.odayaKatil("sohbet")
    check "sohbet" in b.odalar

  test "Çoklu oda":
    let b = yeniBaglanti(nil)
    b.odayaKatil("sohbet")
    b.odayaKatil("oyun")
    check b.odalar.len == 2

  test "Odadan ayrılma":
    let b = yeniBaglanti(nil)
    b.odayaKatil("sohbet")
    b.odayaKatil("oyun")
    b.odadenCik("sohbet")
    check "sohbet" notin b.odalar
    check "oyun" in b.odalar

  test "Bağlantı tablosu yönetimi":
    var tablo = initTable[string, WsBaglanti]()
    let b1 = yeniBaglanti(nil)
    let b2 = yeniBaglanti(nil)
    tablo[b1.id] = b1
    tablo[b2.id] = b2
    check tablo.len == 2
    tablo.del(b1.id)
    check tablo.len == 1
    check b1.id notin tablo

  test "Bağlantı kapatma işareti":
    let b = yeniBaglanti(nil)
    b.bagliMi = false
    check b.bagliMi == false

suite "WebSocket Entegrasyon Testleri":

  test "Lokal el sıkışması + maskeli mesajlaşma":
    var alinanlar: seq[string] = @[]
    var elSikisildi = false

    proc sunucu() {.async.} =
      let srv = newAsyncSocket()
      srv.setSockOpt(OptReuseAddr, true)
      srv.bindAddr(Port(19877))
      srv.listen()
      let soket = await srv.accept()
      var http = ""
      while not http.endsWith("\r\n\r\n"):
        http &= await soket.recv(1)
      var wsKey = ""
      for satir in http.split("\r\n"):
        if satir.toLowerAscii().startsWith("sec-websocket-key:"):
          wsKey = satir.split(":")[1].strip()
      let kabul = wsAcceptAnahtari(wsKey)
      await soket.send("HTTP/1.1 101 Switching Protocols\r\n" &
                       "Upgrade: websocket\r\nConnection: Upgrade\r\n" &
                       "Sec-WebSocket-Accept: " & kabul & "\r\n\r\n")
      elSikisildi = true
      for _ in 0..1:
        let veri = await wsMesajOku(soket)
        if veri.len > 0:
          alinanlar.add(veri)
          await wsMesajGonder(soket, "ECHO: " & veri)
      soket.close(); srv.close()

    proc istemci() {.async.} =
      await sleepAsync(120)
      let soket = newAsyncSocket()
      await soket.connect("127.0.0.1", Port(19877))
      let key = "dGhlIHNhbXBsZSBub25jZQ=="
      await soket.send("GET /ws HTTP/1.1\r\nHost: localhost\r\n" &
                       "Upgrade: websocket\r\nConnection: Upgrade\r\n" &
                       "Sec-WebSocket-Key: " & key & "\r\n" &
                       "Sec-WebSocket-Version: 13\r\n\r\n")
      var yanit = ""
      while not yanit.endsWith("\r\n\r\n"):
        yanit &= await soket.recv(1)
      check "101 Switching Protocols" in yanit
      # Maskeli frame gönder (maske=0, xor etki yok)
      for mesaj in ["merhaba", "dunya"]:
        var frame = ""
        frame.add(chr(0x81))
        frame.add(chr(0x80 or mesaj.len))
        frame.add(chr(0)); frame.add(chr(0))
        frame.add(chr(0)); frame.add(chr(0))
        frame &= mesaj
        await soket.send(frame)
        discard await wsMesajOku(soket)
      soket.close()

    waitFor all(sunucu(), istemci())
    check elSikisildi == true
    check alinanlar.len == 2
    check alinanlar[0] == "merhaba"
    check alinanlar[1] == "dunya"

when isMainModule:
  echo ""
  echo "WebSocket testleri tamamlandı."
