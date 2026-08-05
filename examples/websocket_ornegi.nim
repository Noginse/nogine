# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## WebSocket sohbet örneği.
## Çalıştırmak için: nim c -r examples/websocket_ornegi.nim

import std/[asyncdispatch, tables]
import ../src/nogine
import ../src/nogine/arackatmanlar/kors as korsmod

let uygulama = yeniNogine()
var baglantilar {.global.}: Table[string, WsBaglanti]

uygulama.kullan(korsmod.nogineKors())

proc anaSayfa(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
  await yanit.html("""<!DOCTYPE html>
<html lang="tr"><head><meta charset="UTF-8">
<title>Nogine WebSocket</title>
<style>body{font-family:sans-serif;max-width:600px;margin:2em auto}
#m{border:1px solid #ccc;height:300px;overflow-y:auto;padding:10px}
#g{width:80%}button{width:18%}</style>
</head><body>
<h2>Nogine - WebSocket Sohbet | noginse</h2>
<div id="m"></div><br>
<input id="g" placeholder="Mesaj yazin..."/>
<button onclick="gonder()">Gonder</button>
<script>
const ws=new WebSocket('ws://'+location.host+'/ws');
const k=document.getElementById('m');
ws.onmessage=e=>{k.innerHTML+='<p>'+e.data+'</p>';k.scrollTop=k.scrollHeight};
function gonder(){const g=document.getElementById('g');ws.send(g.value);g.value=''}
document.getElementById('g').onkeypress=e=>{if(e.key==='Enter')gonder()};
</script></body></html>""")

proc wsSohbet(baglanti: WsBaglanti): Future[void] {.async, gcsafe.} =
  baglanti.baglandiIsleyici = proc(): Future[void] {.async, gcsafe.} =
    {.gcsafe.}: baglantilar[baglanti.id] = baglanti
    let sayi = block:
      var n = 0
      {.gcsafe.}: n = baglantilar.len
      n
    await baglanti.gonder("Hos geldiniz! Toplam " & $sayi & " kisi bagli.")

  baglanti.mesajIsleyici = proc(veri: string): Future[void] {.async, gcsafe.} =
    let mesaj = "[" & baglanti.id[0..5] & "]: " & veri
    var gonderilecekler: seq[WsBaglanti]
    {.gcsafe.}:
      for id, diger in baglantilar:
        if diger.bagliMi: gonderilecekler.add(diger)
    for diger in gonderilecekler:
      await diger.gonder(mesaj)

  baglanti.kapatildiIsleyici = proc(): Future[void] {.async, gcsafe.} =
    echo "Ayrildi: " & baglanti.id[0..5]
    {.gcsafe.}: baglantilar.del(baglanti.id)

uygulama.al("/", anaSayfa)
uygulama.websocket("/ws", wsSohbet)

echo "WebSocket sohbet: http://localhost:8080"
waitFor uygulama.dinle(port = 8080)