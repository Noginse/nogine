# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine benchmark sunucusu.
## Kullanım:
##   nim c -d:release benchmarks/hiz_testi.nim
##   ./hiz_testi &
##   ab -n 10000 -c 200 http://localhost:9090/
##   ab -n 10000 -c 200 http://localhost:9090/kullanicilar/42

import std/[asyncdispatch, json]
import ../src/nogine

let uygulama = yeniNogine()

# --- Benchmark rotaları ---

let jsonH: IsleyiciProc =
  proc(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
    await yanit.json(%*{"mesaj": "Merhaba Dünya", "framework": "Nogine", "yazar": "noginse"})

let dinamikH: IsleyiciProc =
  proc(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
    let id = istek.param("id")
    await yanit.json(%*{"id": id, "isim": "Test Kullanicisi " & id})

let metinH: IsleyiciProc =
  proc(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
    await yanit.metin("pong")

let bosH: IsleyiciProc =
  proc(istek: Istek, yanit: Yanit): Future[void] {.async, gcsafe.} =
    await yanit.bos()

uygulama.al("/", jsonH)
uygulama.al("/kullanicilar/:id", dinamikH)
uygulama.al("/ping", metinH)
uygulama.al("/bos", bosH)

echo "╔════════════════════════════════════════╗"
echo "║  Nogine Benchmark Sunucusu             ║"
echo "║  Created by noginse                    ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "  Port: 9090"
echo "  Test komutları:"
echo "    ab -n 10000 -c 200 http://localhost:9090/"
echo "    ab -n 10000 -c 200 http://localhost:9090/kullanicilar/42"
echo "    ab -n 10000 -c 200 http://localhost:9090/ping"
echo ""
waitFor uygulama.dinle(port = 9090)