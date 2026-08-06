# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine middleware (arackatman) sistemi.
## Middleware zinciri oluşturma ve yönetme.

import std/asyncdispatch
import ./tipler

type
  ## Middleware zinciri için ref nesnesi (gcsafe uyumlu)
  ZincirRef = ref object
    arackatmanlar: seq[ArackatmanProc]
    isleyici: IsleyiciProc
    istek: Istek
    yanit: Yanit
    konum: int

proc adimAt(z: ZincirRef): Future[void] {.async.} =
  if z.yanit.gonderildi:
    return
  if z.konum < z.arackatmanlar.len:
    let mevcut = z.arackatmanlar[z.konum]
    inc z.konum
    let zRef = z
    let sonraki: SonrakiProc = proc(): Future[void] {.async.} =
      await adimAt(zRef)
    await mevcut(z.istek, z.yanit, sonraki)
  else:
    if not z.yanit.gonderildi:
      await z.isleyici(z.istek, z.yanit)

## Middleware zinciri oluştur ve çalıştır
proc zincirleCalistir*(
    arackatmanlar: seq[ArackatmanProc],
    isleyici: IsleyiciProc,
    istek: Istek,
    yanit: Yanit
): Future[void] {.async.} =
  if arackatmanlar.len == 0:
    await isleyici(istek, yanit)
    return
  let z = ZincirRef(
    arackatmanlar: arackatmanlar,
    isleyici: isleyici,
    istek: istek,
    yanit: yanit,
    konum: 0
  )
  await adimAt(z)