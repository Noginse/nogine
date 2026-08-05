# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine WebSocket desteği.
## RFC 6455 uyumlu WebSocket el sıkışması, frame encode/decode,
## mesaj gönderme/alma ve bağlantı yaşam döngüsü yönetimi.

import std/[asyncnet, asyncdispatch, sha1, base64, strutils, tables, random]
import ./tipler
import ./yardimcilar

# ─── Opcode Tanımları ────────────────────────────────────────────────────────

type
  WsOpCode* = enum
    ## RFC 6455 WebSocket opcode değerleri
    wocDevam  = 0x0  ## Devam frame'i
    wocMetin  = 0x1  ## UTF-8 metin frame'i
    wocIkili  = 0x2  ## İkili veri frame'i
    wocKapat  = 0x8  ## Bağlantıyı kapat
    wocPing   = 0x9  ## Ping (canlılık kontrolü)
    wocPong   = 0xA  ## Pong (ping yanıtı)

# ─── Frame Encode / Decode ───────────────────────────────────────────────────

proc wsFrameKodla*(veri: string, opcode: WsOpCode,
                   masked: bool = false): string =
  ## RFC 6455 uyumlu WebSocket frame oluştur.
  ## Sunucudan istemciye: masked=false, İstemciden sunucuya: masked=true.
  let uzunluk = veri.len
  var frame = ""

  # İlk byte: FIN=1 + RSV=0 + opcode
  frame.add(char(0x80 or opcode.int))

  # Maskeleme biti + payload uzunluk
  let maskBit = if masked: 0x80 else: 0x00

  if uzunluk < 126:
    frame.add(char(maskBit or uzunluk))
  elif uzunluk < 65536:
    frame.add(char(maskBit or 126))
    frame.add(char((uzunluk shr 8) and 0xFF))
    frame.add(char(uzunluk and 0xFF))
  else:
    frame.add(char(maskBit or 127))
    for i in countdown(7, 0):
      frame.add(char((uzunluk shr (i * 8)) and 0xFF))

  if masked:
    # 4 byte rastgele maskeleme anahtarı
    var maskKey = newString(4)
    for i in 0..3:
      maskKey[i] = char(rand(255))
    frame &= maskKey
    # Veriyi maskele
    for i in 0..<uzunluk:
      frame.add(char(veri[i].uint8 xor maskKey[i mod 4].uint8))
  else:
    frame &= veri

  result = frame

proc wsFrameCoz*(veri: string): tuple[opcode: WsOpCode, payload: string, tamamMi: bool] =
  ## Ham byte dizisini WebSocket frame'e çözümle.
  result.tamamMi = false
  result.payload = ""
  result.opcode = wocMetin

  if veri.len < 2:
    return

  let byte0 = veri[0].uint8
  let byte1 = veri[1].uint8

  # let fin = (byte0 and 0x80) != 0  # FIN biti (şimdilik tek frame varsayımı)
  let opInt = byte0 and 0x0F
  result.opcode = WsOpCode(opInt)

  let masked = (byte1 and 0x80) != 0
  var payloadLen = (byte1 and 0x7F).int
  var offset = 2

  if payloadLen == 126:
    if veri.len < 4: return
    payloadLen = (veri[2].uint8.int shl 8) or veri[3].uint8.int
    offset = 4
  elif payloadLen == 127:
    if veri.len < 10: return
    payloadLen = 0
    for i in 0..7:
      payloadLen = (payloadLen shl 8) or veri[2 + i].uint8.int
    offset = 10

  var maskKey = newString(4)
  if masked:
    if veri.len < offset + 4: return
    for i in 0..3:
      maskKey[i] = veri[offset + i]
    offset += 4

  if veri.len < offset + payloadLen: return

  result.payload = newString(payloadLen)
  for i in 0..<payloadLen:
    if masked:
      result.payload[i] = char(veri[offset + i].uint8 xor maskKey[i mod 4].uint8)
    else:
      result.payload[i] = veri[offset + i]

  result.tamamMi = true

# ─── WebSocket El Sıkışması ──────────────────────────────────────────────────

proc wsAcceptAnahtari*(clientKey: string): string =
  ## RFC 6455 Sec-WebSocket-Accept başlık değerini hesapla.
  let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  result = encode($secureHash(clientKey & magic))

proc wsElSikismasi*(soket: AsyncSocket, istek: Istek): Future[bool] {.async.} =
  ## HTTP Upgrade isteğini WebSocket'e yükselt (101 Switching Protocols).
  let wsKey = istek.basliklar.getOrDefault("sec-websocket-key", "")
  if wsKey.len == 0:
    return false

  let acceptKey = wsAcceptAnahtari(wsKey)
  let yanit = "HTTP/1.1 101 Switching Protocols\r\n" &
              "Upgrade: websocket\r\n" &
              "Connection: Upgrade\r\n" &
              "Sec-WebSocket-Accept: " & acceptKey & "\r\n\r\n"
  try:
    await soket.send(yanit)
    return true
  except:
    return false

# ─── Mesaj Gönderme / Alma ───────────────────────────────────────────────────

proc wsMesajGonder*(soket: AsyncSocket, veri: string,
                    opcode: WsOpCode = wocMetin): Future[void] {.async.} =
  ## WebSocket mesajı gönder (sunucu→istemci, maskesiz).
  let frame = wsFrameKodla(veri, opcode, masked = false)
  try:
    await soket.send(frame)
  except:
    discard

proc wsMesajOku*(soket: AsyncSocket): Future[string] {.async.} =
  ## Tek WebSocket frame oku ve payload döndür.
  ## Ping alınırsa otomatik Pong gönder.
  ## Kapatma frame'i alınırsa boş string döndür.
  try:
    # İlk 2 byte oku
    let baslik = await soket.recv(2)
    if baslik.len < 2:
      return ""

    let byte1 = baslik[1].uint8
    let masked = (byte1 and 0x80) != 0
    var payloadLen = (byte1 and 0x7F).int

    var tamVeri = baslik

    # Uzunluk alanını oku
    if payloadLen == 126:
      let uzunlukVerisi = await soket.recv(2)
      tamVeri &= uzunlukVerisi
      payloadLen = (uzunlukVerisi[0].uint8.int shl 8) or uzunlukVerisi[1].uint8.int
    elif payloadLen == 127:
      let uzunlukVerisi = await soket.recv(8)
      tamVeri &= uzunlukVerisi
      payloadLen = 0
      for i in 0..7:
        payloadLen = (payloadLen shl 8) or uzunlukVerisi[i].uint8.int

    # Maskeleme anahtarı
    if masked:
      let maskVerisi = await soket.recv(4)
      tamVeri &= maskVerisi

    # Payload
    if payloadLen > 0:
      let payload = await soket.recv(payloadLen)
      tamVeri &= payload

    let (opcode, payload, tamamMi) = wsFrameCoz(tamVeri)
    if not tamamMi:
      return ""

    case opcode
    of wocKapat:
      return ""
    of wocPing:
      # Otomatik Pong
      await wsMesajGonder(soket, payload, wocPong)
      return await wsMesajOku(soket)  # Bir sonraki mesajı oku
    of wocPong:
      return await wsMesajOku(soket)  # Pong'u yoksay, devam et
    of wocMetin, wocIkili, wocDevam:
      return payload

  except:
    return ""

# ─── Bağlantı Yaşam Döngüsü ──────────────────────────────────────────────────

proc yeniBaglanti*(soket: AsyncSocket): WsBaglanti =
  ## Yeni bir WebSocket bağlantısı oluştur.
  result = WsBaglanti(
    id: uuidUret(),
    soket: soket,
    odalar: @[],
    bagliMi: true,
    baglandiIsleyici: nil,
    mesajIsleyici: nil,
    kapatildiIsleyici: nil
  )

proc gonder*(baglanti: WsBaglanti, veri: string): Future[void] {.async.} =
  ## Bağlantıya metin mesajı gönder.
  if not baglanti.bagliMi or baglanti.soket.isNil:
    return
  await wsMesajGonder(baglanti.soket, veri, wocMetin)

proc gonderIkili*(baglanti: WsBaglanti, veri: string): Future[void] {.async.} =
  ## Bağlantıya ikili mesaj gönder.
  if not baglanti.bagliMi or baglanti.soket.isNil:
    return
  await wsMesajGonder(baglanti.soket, veri, wocIkili)

proc kapat*(baglanti: WsBaglanti): Future[void] {.async.} =
  ## WebSocket bağlantısını düzgünce kapat.
  if not baglanti.bagliMi or baglanti.soket.isNil:
    return
  baglanti.bagliMi = false
  try:
    await wsMesajGonder(baglanti.soket, "", wocKapat)
    baglanti.soket.close()
  except:
    discard

proc odayaKatil*(baglanti: WsBaglanti, odaAdi: string) =
  ## Bağlantıyı bir odaya ekle.
  if odaAdi notin baglanti.odalar:
    baglanti.odalar.add(odaAdi)

proc odadenCik*(baglanti: WsBaglanti, odaAdi: string) =
  ## Bağlantıyı bir odadan çıkar.
  let idx = baglanti.odalar.find(odaAdi)
  if idx >= 0:
    baglanti.odalar.del(idx)

proc baglantiYonet*(baglanti: WsBaglanti): Future[void] {.async.} =
  ## Bağlantı yaşam döngüsünü yönet.
  ## baglandiIsleyici → mesaj döngüsü → kapatildiIsleyici sırası.

  # Bağlantı kuruldu
  if not baglanti.baglandiIsleyici.isNil:
    try:
      await baglanti.baglandiIsleyici()
    except:
      discard

  # Mesaj döngüsü
  while baglanti.bagliMi:
    let veri = await wsMesajOku(baglanti.soket)
    if veri.len == 0:
      baglanti.bagliMi = false
      break
    if not baglanti.mesajIsleyici.isNil:
      try:
        await baglanti.mesajIsleyici(veri)
      except:
        discard

  # Bağlantı kapandı
  if not baglanti.kapatildiIsleyici.isNil:
    try:
      await baglanti.kapatildiIsleyici()
    except:
      discard

  # Soketi temizle
  if not baglanti.soket.isNil:
    try: baglanti.soket.close()
    except: discard