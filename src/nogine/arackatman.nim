# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine middleware (arackatman) sistemi.

import std/asyncdispatch
import ./tipler

type
  ZincirRef = ref object
    arackatmanlar: seq[ArackatmanProc]
    isleyici: IsleyiciProc
    istek: Istek
    yanit: Yanit
    konum: int

proc adimAt(z: ZincirRef): Future[void] {.async, gcsafe.}

proc adimAt(z: ZincirRef): Future[void] {.async, gcsafe.} =
  if z.yanit.gonderildi:
    return
  if z.konum < z.arackatmanlar.len:
    let mevcut = z.arackatmanlar[z.konum]
    inc z.konum
    let zRef = z
    let sonraki: SonrakiProc = proc(): Future[void] {.gcsafe.} =
      result = adimAt(zRef)
    await mevcut(z.istek, z.yanit, sonraki)
  else:
    if not z.yanit.gonderildi:
      await z.isleyici(z.istek, z.yanit)

proc zincirleCalistir*(
    arackatmanlar: seq[ArackatmanProc],
    isleyici: IsleyiciProc,
    istek: Istek,
    yanit: Yanit
): Future[void] {.async, gcsafe.} =
  let z = ZincirRef(
    arackatmanlar: arackatmanlar,
    isleyici: isleyici,
    istek: istek,
    yanit: yanit,
    konum: 0
  )
  await adimAt(z)