# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine veritabanı katmanı.
## SQLite ve PostgreSQL desteği, query builder ve migration sistemi.

import std/[tables, strutils, json, sequtils, os, times]
import db_connector/db_sqlite
import ./hatalar

# PostgreSQL ayrı bir modülde (isteğe bağlı)
# import db_connector/db_postgres  # nogine/veritabani_pg ile etkinleştir

type
  ## Veritabanı türü
  VtTuru* = enum
    vtSQLite    = "sqlite"
    vtPostgres  = "postgres"

  ## Veritabanı bağlantısı
  VtBaglanti* = ref object
    tur*: VtTuru
    sqliteConn*: db_sqlite.DbConn   ## SQLite bağlantısı
    bagliMi*: bool
    sorguSayisi*: int
    dosyaYolu*: string              ## SQLite için dosya yolu

  ## Sıralı tablo - sorgu satırı
  VtSatir* = OrderedTable[string, string]

  ## Sorgu sonucu
  VtSonuc* = seq[VtSatir]

  ## Parametre listesi
  VtParametreler* = seq[string]

  ## Query builder
  SorguOlusturucu* = ref object
    tablo*: string
    secimler*: seq[string]
    kosullar*: seq[string]
    parametreler*: VtParametreler
    siralamaSutun*: string
    siralamaYon*: string
    limitDeger*: int
    offsetDeger*: int
    birlestirmeler*: seq[string]
    gruplamaAlanlari*: seq[string]

  ## Migration tanımı
  MigrationTanimi* = object
    id*: string
    aciklama*: string
    yukari*: string
    asagi*: string

  ## Migration yöneticisi
  MigrationYonetici* = ref object
    baglanti*: VtBaglanti
    migrations*: seq[MigrationTanimi]

# ─── Bağlantı ───────────────────────────────────────────────────────────────

## SQLite veritabanına bağlan
proc sqliteBaglan*(dosya: string = ":memory:"): VtBaglanti =
  try:
    let conn = open(dosya, "", "", "")
    result = VtBaglanti(
      tur: vtSQLite,
      sqliteConn: conn,
      bagliMi: true,
      sorguSayisi: 0,
      dosyaYolu: dosya
    )
    discard conn.tryExec(sql"PRAGMA journal_mode=WAL")
    discard conn.tryExec(sql"PRAGMA synchronous=NORMAL")
    discard conn.tryExec(sql"PRAGMA foreign_keys=ON")
  except DbError as e:
    raise newException(NogineHatasi, "SQLite bağlantı hatası: " & e.msg)

## Bağlantıyı kapat
proc kapat*(vt: VtBaglanti) =
  if not vt.bagliMi: return
  vt.sqliteConn.close()
  vt.bagliMi = false

# ─── Ham Sorgular ────────────────────────────────────────────────────────────

## SQL çalıştır (sonuç döndürmez: CREATE, INSERT, UPDATE, DELETE)
proc calistir*(vt: VtBaglanti, sorgu: string,
               params: VtParametreler = @[]): bool =
  inc vt.sorguSayisi
  try:
    result = vt.sqliteConn.tryExec(sql(sorgu), params)
  except DbError as e:
    raise newException(NogineHatasi,
      "Sorgu hatası: " & e.msg & "\nSorgu: " & sorgu[0..min(100, sorgu.len-1)])


## Son eklenen satırın ID'si
proc sonEklenenId*(vt: VtBaglanti): int64 =
  try:
    let row = vt.sqliteConn.getRow(sql"SELECT last_insert_rowid()")
    if row.len > 0 and row[0].len > 0:
      result = parseInt(row[0]).int64
  except: result = -1

## Scalar değer al (tek sayı/metin döndüren sorgular için)
proc scalar*(vt: VtBaglanti, sorgu: string,
             params: VtParametreler = @[]): string =
  inc vt.sorguSayisi
  try:
    let satir = vt.sqliteConn.getRow(sql(sorgu), params)
    if satir.len > 0: result = satir[0]
    else: result = ""
  except: result = ""

proc sutunAdlariniCikar*(sorgu: string): seq[string] =
  result = @[]
  let lower = sorgu.toLowerAscii()
  let selectIdx = lower.find("select ")
  let fromIdx = lower.find(" from ")
  if selectIdx < 0 or fromIdx < 0: return
  let secimKismi = sorgu[selectIdx+7..<fromIdx].strip()
  if secimKismi == "*": return
  for alan in secimKismi.split(","):
    let temiz = alan.strip()
    # "tablo.alan AS takma" → "takma"
    if " as " in temiz.toLowerAscii():
      result.add(temiz.split(" ")[^1].strip())
    # "tablo.alan" → "alan"
    elif "." in temiz:
      result.add(temiz.split(".")[^1].strip())
    else:
      result.add(temiz)

# ─── CRUD ───────────────────────────────────────────────────────────────────

## Tüm satırları getir
proc tumSatirlar*(vt: VtBaglanti, sorgu: string,
                  params: VtParametreler = @[]): VtSonuc =
  inc vt.sorguSayisi
  result = @[]
  try:
    let satirlar = vt.sqliteConn.getAllRows(sql(sorgu), params)
    let sutunlar = sutunAdlariniCikar(sorgu)
    for satir in satirlar:
      var vtSatir = initOrderedTable[string, string]()
      for i, deger in satir:
        let ad = if i < sutunlar.len: sutunlar[i] else: $i
        vtSatir[ad] = deger
      result.add(vtSatir)
  except DbError as e:
    raise newException(NogineHatasi, "Sorgu hatası: " & e.msg)


## Tek satır getir
proc tekSatir*(vt: VtBaglanti, sorgu: string,
               params: VtParametreler = @[]): VtSatir =
  result = initOrderedTable[string, string]()
  let tumü = vt.tumSatirlar(sorgu, params)
  if tumü.len > 0: result = tumü[0]

## Yeni kayıt ekle
proc ekle*(vt: VtBaglanti, tabloAdi: string,
           veri: Table[string, string]): int64 =
  let sutunlar = toSeq(veri.keys)
  let degerler = sutunlar.mapIt(veri[it])
  let yer = sutunlar.mapIt("?").join(", ")
  let sorgu = "INSERT INTO " & tabloAdi &
              " (" & sutunlar.join(", ") & ") VALUES (" & yer & ")"
  discard vt.calistir(sorgu, degerler)
  result = vt.sonEklenenId()

## Kayıt güncelle
proc guncelle*(vt: VtBaglanti, tabloAdi: string,
               veri: Table[string, string],
               kosul: string, params: VtParametreler = @[]): bool =
  var setler: seq[string] = @[]
  var degerler: seq[string] = @[]
  for k, v in veri:
    setler.add(k & " = ?")
    degerler.add(v)
  for p in params: degerler.add(p)
  let sorgu = "UPDATE " & tabloAdi &
              " SET " & setler.join(", ") & " WHERE " & kosul
  result = vt.calistir(sorgu, degerler)

## Kayıt sil
proc sil*(vt: VtBaglanti, tabloAdi: string,
          kosul: string, params: VtParametreler = @[]): bool =
  result = vt.calistir("DELETE FROM " & tabloAdi & " WHERE " & kosul, params)

## Kayıt say
proc say*(vt: VtBaglanti, tabloAdi: string,
          kosul: string = "", params: VtParametreler = @[]): int =
  var sorgu = "SELECT COUNT(*) FROM " & tabloAdi
  if kosul.len > 0: sorgu &= " WHERE " & kosul
  let s = vt.scalar(sorgu, params)
  try: result = parseInt(s)
  except: result = 0

## ID ile tek kayıt bul
proc bul*(vt: VtBaglanti, tabloAdi: string, id: int): VtSatir =
  result = vt.tekSatir("SELECT * FROM " & tabloAdi & " WHERE id = ?", @[$id])

## Tüm kayıtları getir
proc hepsiniGetir*(vt: VtBaglanti, tabloAdi: string,
                   limit: int = 100, offset: int = 0): VtSonuc =
  result = vt.tumSatirlar(
    "SELECT * FROM " & tabloAdi & " LIMIT ? OFFSET ?",
    @[$limit, $offset]
  )

# ─── Query Builder ───────────────────────────────────────────────────────────

## Yeni sorgu oluşturucu
proc tablo*(tabloAdi: string): SorguOlusturucu =
  result = SorguOlusturucu(
    tablo: tabloAdi,
    secimler: @["*"],
    kosullar: @[],
    parametreler: @[],
    siralamaSutun: "",
    siralamaYon: "ASC",
    limitDeger: -1,
    offsetDeger: 0,
    birlestirmeler: @[],
    gruplamaAlanlari: @[]
  )

proc sec*(q: SorguOlusturucu, sutunlar: varargs[string]): SorguOlusturucu =
  q.secimler = toSeq(sutunlar)
  result = q

proc nerede*(q: SorguOlusturucu, kosul: string,
             params: varargs[string]): SorguOlusturucu =
  q.kosullar.add(kosul)
  for p in params: q.parametreler.add(p)
  result = q

proc ve*(q: SorguOlusturucu, kosul: string,
         params: varargs[string]): SorguOlusturucu =
  result = q.nerede(kosul, params)

proc veya*(q: SorguOlusturucu, kosul: string,
           params: varargs[string]): SorguOlusturucu =
  if q.kosullar.len > 0: q.kosullar.add("OR (" & kosul & ")")
  else: q.kosullar.add(kosul)
  for p in params: q.parametreler.add(p)
  result = q

proc sirala*(q: SorguOlusturucu, sutun: string,
             yon: string = "ASC"): SorguOlusturucu =
  q.siralamaSutun = sutun
  q.siralamaYon = yon
  result = q

proc sinirla*(q: SorguOlusturucu, n: int): SorguOlusturucu =
  q.limitDeger = n
  result = q

proc atla*(q: SorguOlusturucu, n: int): SorguOlusturucu =
  q.offsetDeger = n
  result = q

proc birlestir*(q: SorguOlusturucu, tabloAdi: string,
                kosul: string, tur: string = "INNER"): SorguOlusturucu =
  q.birlestirmeler.add(tur & " JOIN " & tabloAdi & " ON " & kosul)
  result = q

proc grupla*(q: SorguOlusturucu, sutunlar: varargs[string]): SorguOlusturucu =
  for s in sutunlar: q.gruplamaAlanlari.add(s)
  result = q

## SQL string'e dönüştür
proc sqlOlustur*(q: SorguOlusturucu): string =
  result = "SELECT " & q.secimler.join(", ") & " FROM " & q.tablo
  for b in q.birlestirmeler: result &= " " & b
  if q.kosullar.len > 0:
    var kk = ""
    for i, k in q.kosullar:
      if i == 0: kk &= k
      elif k.startsWith("OR "): kk &= " " & k
      else: kk &= " AND " & k
    result &= " WHERE " & kk
  if q.gruplamaAlanlari.len > 0:
    result &= " GROUP BY " & q.gruplamaAlanlari.join(", ")
  if q.siralamaSutun.len > 0:
    result &= " ORDER BY " & q.siralamaSutun & " " & q.siralamaYon
  if q.limitDeger > 0: result &= " LIMIT " & $q.limitDeger
  if q.offsetDeger > 0: result &= " OFFSET " & $q.offsetDeger

## Sorguyu çalıştır
proc getir*(q: SorguOlusturucu, vt: VtBaglanti): VtSonuc =
  result = vt.tumSatirlar(q.sqlOlustur(), q.parametreler)

proc getOrDefault*(s: VtSonuc, idx: int, def: VtSatir): VtSatir =
  if idx < s.len: result = s[idx]
  else: result = def

proc tekGetir*(q: SorguOlusturucu, vt: VtBaglanti): VtSatir =
  let satirlar = q.sinirla(1).getir(vt)
  result = satirlar.getOrDefault(0, initOrderedTable[string,string]())

## Sayfalama
proc sayfala*(q: SorguOlusturucu, sayfa: int,
              boyut: int = 20): SorguOlusturucu =
  result = q.sinirla(boyut).atla((sayfa - 1) * boyut)

# ─── Migration ───────────────────────────────────────────────────────────────

proc yeniMigrationYonetici*(vt: VtBaglanti): MigrationYonetici =
  result = MigrationYonetici(baglanti: vt, migrations: @[])
  discard vt.calistir("""
    CREATE TABLE IF NOT EXISTS nogine_migrations (
      id TEXT PRIMARY KEY,
      aciklama TEXT NOT NULL,
      tarih TEXT NOT NULL
    )
  """)

proc migration*(ym: MigrationYonetici, id, aciklama, yukari: string,
                asagi: string = "") =
  ym.migrations.add(MigrationTanimi(
    id: id, aciklama: aciklama, yukari: yukari, asagi: asagi
  ))

proc yapilmislariGetir(ym: MigrationYonetici): seq[string] =
  result = @[]
  for satir in ym.baglanti.tumSatirlar(
      "SELECT id FROM nogine_migrations ORDER BY tarih"):
    result.add(satir.getOrDefault("id", satir.getOrDefault("0", "")))

proc migrasyonYukari*(ym: MigrationYonetici): int =
  let yapilmis = ym.yapilmislariGetir()
  result = 0
  for m in ym.migrations:
    if m.id notin yapilmis:
      discard ym.baglanti.calistir(m.yukari)
      discard ym.baglanti.calistir(
        "INSERT INTO nogine_migrations VALUES (?, ?, ?)",
        @[m.id, m.aciklama, $now()])
      inc result
      echo "✓ Migration: " & m.id & " — " & m.aciklama

proc migrasyonAsagi*(ym: MigrationYonetici): bool =
  let yapilmis = ym.yapilmislariGetir()
  if yapilmis.len == 0: return false
  let sonId = yapilmis[^1]
  for m in ym.migrations:
    if m.id == sonId and m.asagi.len > 0:
      discard ym.baglanti.calistir(m.asagi)
      discard ym.baglanti.sil("nogine_migrations", "id = ?", @[sonId])
      echo "↓ Migration geri alındı: " & m.id
      return true

# ─── Yardımcılar ────────────────────────────────────────────────────────────

proc satirJsonYap*(satir: VtSatir): JsonNode =
  result = newJObject()
  for k, v in satir: result[k] = %v

proc sonucJsonYap*(sonuc: VtSonuc): JsonNode =
  result = newJArray()
  for satir in sonuc: result.add(satirJsonYap(satir))

proc toplamSayfa*(toplam, boyut: int): int =
  result = (toplam + boyut - 1) div boyut