# Nogine - A Nim Web Framework
# Created by noginse
# https://github.com/noginse/nogine

## Nogine Admin Paneli.
## Otomatik CRUD arayüzü, kullanıcı yönetimi, dashboard.
## Herhangi bir veritabanı tablosunu tek satırla admin paneline ekle.

import std/[tables, strutils, json, asyncdispatch, sequtils]
import ../tipler
import ../yanit
import ../istek
import ../veritabani
import ../oturum
import ../hatalar
import ../yonlendirici

type
  ## Admin tablo tanımı
  AdminTablo* = ref object
    ad*: string               ## Tablo adı (veritabanında)
    gorunumAdi*: string       ## Görüntü adı (Türkçe)
    sutunlar*: seq[AdminSutun]
    aramaAlanlari*: seq[string]
    sayfaBoyutu*: int
    duzenlenebilir*: bool
    silinebilir*: bool
    eklenebilir*: bool

  ## Admin sütun tanımı
  AdminSutun* = object
    ad*: string
    etiket*: string
    tur*: string       ## text, number, email, password, date, bool, textarea, select
    zorunlu*: bool
    listede*: bool     ## Liste görünümünde göster
    formda*: bool      ## Form görünümünde göster
    seçenekler*: seq[tuple[deger: string, etiket: string]]

  ## Admin paneli yapılandırması
  AdminPanel* = ref object
    baslik*: string
    urlPrefix*: string
    tablolar*: seq[AdminTablo]
    vt*: VtBaglanti
    oturumDepo*: OturumDepo
    adminKullanici*: string
    adminSifre*: string   ## Gerçekte hash saklanmalı

## Yeni admin paneli oluştur
proc yeniAdminPanel*(vt: VtBaglanti, prefix: string = "/admin"): AdminPanel =
  result = AdminPanel(
    baslik: "Nogine Admin",
    urlPrefix: prefix,
    tablolar: @[],
    vt: vt,
    oturumDepo: yeniOturumDepo(),
    adminKullanici: "admin",
    adminSifre: "admin123"
  )

## Admin tablosu ekle
proc tabloEkle*(panel: AdminPanel, tablo: AdminTablo) =
  panel.tablolar.add(tablo)

## Hızlı tablo tanımı
proc hizliTablo*(ad: string, gorunumAdi: string,
                 sutunlar: seq[AdminSutun]): AdminTablo =
  result = AdminTablo(
    ad: ad,
    gorunumAdi: gorunumAdi,
    sutunlar: sutunlar,
    aramaAlanlari: @[],
    sayfaBoyutu: 20,
    duzenlenebilir: true,
    silinebilir: true,
    eklenebilir: true
  )

## Sütun tanımı yardımcısı
proc sutun*(ad, etiket, tur: string,
            zorunlu: bool = false,
            listede: bool = true,
            formda: bool = true): AdminSutun =
  AdminSutun(
    ad: ad, etiket: etiket, tur: tur,
    zorunlu: zorunlu, listede: listede, formda: formda,
    seçenekler: @[]
  )

# ─── HTML Şablonları ─────────────────────────────────────────────────────────

proc adminCss(): string = """
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
       background: #f0f2f5; color: #333; }
.admin-wrap { display: flex; min-height: 100vh; }
.sidebar { width: 240px; background: #1a1a2e; color: #eee; padding: 0;
           position: fixed; top: 0; left: 0; height: 100vh; overflow-y: auto; }
.sidebar .logo { padding: 20px; background: #16213e; font-size: 18px;
                  font-weight: bold; color: #e94560; border-bottom: 1px solid #0f3460; }
.sidebar .logo small { display: block; font-size: 11px; color: #888; margin-top: 2px; }
.sidebar nav a { display: block; padding: 12px 20px; color: #ccc;
                  text-decoration: none; border-left: 3px solid transparent;
                  transition: all 0.2s; font-size: 14px; }
.sidebar nav a:hover, .sidebar nav a.aktif {
  background: #16213e; color: #e94560; border-left-color: #e94560; }
.sidebar nav .grup-baslik { padding: 16px 20px 4px; font-size: 10px;
                              color: #666; text-transform: uppercase; letter-spacing: 1px; }
.main { margin-left: 240px; padding: 0; flex: 1; }
.topbar { background: white; padding: 15px 30px; border-bottom: 1px solid #e0e0e0;
          display: flex; justify-content: space-between; align-items: center;
          position: sticky; top: 0; z-index: 100; box-shadow: 0 1px 4px rgba(0,0,0,.06); }
.topbar h1 { font-size: 20px; font-weight: 600; }
.topbar .user { font-size: 13px; color: #666; }
.content { padding: 30px; }
.card { background: white; border-radius: 8px; padding: 24px;
        box-shadow: 0 1px 4px rgba(0,0,0,.08); margin-bottom: 24px; }
.card h2 { font-size: 16px; font-weight: 600; margin-bottom: 16px;
            padding-bottom: 12px; border-bottom: 1px solid #f0f0f0; }
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; }
.stat-card { background: white; border-radius: 8px; padding: 20px;
             box-shadow: 0 1px 4px rgba(0,0,0,.08); }
.stat-card .sayi { font-size: 32px; font-weight: 700; color: #e94560; }
.stat-card .etiket { font-size: 13px; color: #888; margin-top: 4px; }
table { width: 100%; border-collapse: collapse; font-size: 14px; }
th { text-align: left; padding: 10px 12px; background: #f8f9fa;
     font-weight: 600; font-size: 12px; text-transform: uppercase;
     letter-spacing: .5px; color: #666; border-bottom: 2px solid #e0e0e0; }
td { padding: 10px 12px; border-bottom: 1px solid #f0f0f0; }
tr:hover td { background: #fafafa; }
.btn { display: inline-flex; align-items: center; gap: 6px; padding: 8px 16px;
       border-radius: 6px; border: none; cursor: pointer; font-size: 13px;
       font-weight: 500; text-decoration: none; transition: all .2s; }
.btn-primary { background: #e94560; color: white; }
.btn-primary:hover { background: #c73652; }
.btn-sm { padding: 5px 10px; font-size: 12px; }
.btn-danger { background: #dc3545; color: white; }
.btn-danger:hover { background: #c82333; }
.btn-secondary { background: #6c757d; color: white; }
.btn-secondary:hover { background: #5a6268; }
.btn-success { background: #28a745; color: white; }
.btn-success:hover { background: #218838; }
.badge { display: inline-block; padding: 3px 8px; border-radius: 12px;
         font-size: 11px; font-weight: 600; }
.badge-success { background: #d4edda; color: #155724; }
.badge-danger { background: #f8d7da; color: #721c24; }
.toolbar { display: flex; gap: 10px; align-items: center; margin-bottom: 16px; flex-wrap: wrap; }
.search-box { flex: 1; min-width: 200px; }
.search-box input { width: 100%; padding: 8px 12px; border: 1px solid #ddd;
                     border-radius: 6px; font-size: 14px; }
.search-box input:focus { outline: none; border-color: #e94560; }
.pagination { display: flex; gap: 4px; align-items: center; justify-content: flex-end;
              margin-top: 16px; }
.pagination a, .pagination span {
  padding: 6px 12px; border: 1px solid #ddd; border-radius: 4px;
  font-size: 13px; text-decoration: none; color: #333; }
.pagination a:hover { background: #f0f0f0; }
.pagination .aktif { background: #e94560; color: white; border-color: #e94560; }
form .form-grup { margin-bottom: 16px; }
form label { display: block; font-size: 13px; font-weight: 500;
              color: #555; margin-bottom: 4px; }
form input, form textarea, form select {
  width: 100%; padding: 9px 12px; border: 1px solid #ddd; border-radius: 6px;
  font-size: 14px; font-family: inherit; }
form input:focus, form textarea:focus, form select:focus {
  outline: none; border-color: #e94560; box-shadow: 0 0 0 3px rgba(233,69,96,.1); }
form textarea { min-height: 100px; resize: vertical; }
.alert { padding: 12px 16px; border-radius: 6px; margin-bottom: 16px; font-size: 14px; }
.alert-success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
.alert-danger { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
.login-wrap { display: flex; align-items: center; justify-content: center;
               min-height: 100vh; background: #1a1a2e; }
.login-box { background: white; border-radius: 12px; padding: 40px; width: 360px;
              box-shadow: 0 20px 60px rgba(0,0,0,.3); }
.login-box h1 { text-align: center; color: #e94560; margin-bottom: 8px; font-size: 24px; }
.login-box p { text-align: center; color: #888; font-size: 13px; margin-bottom: 28px; }
.empty { text-align: center; padding: 40px; color: #999; font-size: 14px; }
</style>
"""

proc adminLayout(baslik, icerik: string, panel: AdminPanel,
                 aktifTablo: string = ""): string =
  var nav = ""
  nav.add("<div class='grup-baslik'>Tablolar</div>\n")
  for t in panel.tablolar:
    let cls = if t.ad == aktifTablo: " aktif" else: ""
    nav.add("<a href='" & panel.urlPrefix & "/tablo/" & t.ad &
            "' class='" & cls & "'>" & t.gorunumAdi & "</a>\n")
  let dashCls = if aktifTablo == "": " aktif" else: ""
  var html = "<!DOCTYPE html>\n<html lang='tr'>\n<head>\n"
  html.add("  <meta charset='UTF-8'>\n")
  html.add("  <meta name='viewport' content='width=device-width'>\n")
  html.add("  <title>" & baslik & " — " & panel.baslik & "</title>\n")
  html.add(adminCss())
  html.add("</head>\n<body>\n<div class='admin-wrap'>\n")
  html.add("  <div class='sidebar'>\n    <div class='logo'>\n")
  html.add("      <strong>" & panel.baslik & "</strong><br><small>Nogine</small>\n")
  html.add("    </div>\n    <nav>\n")
  html.add("      <a href='" & panel.urlPrefix & "' class='" & dashCls & "'>Anasayfa</a>\n")
  html.add(nav)
  html.add("      <a href='" & panel.urlPrefix & "/cikis'>Cikis Yap</a>\n")
  html.add("    </nav>\n  </div>\n")
  html.add("  <div class='main'>\n")
  html.add("    <div class='topbar'><h1>" & baslik & "</h1></div>\n")
  html.add("    <div class='content'>\n" & icerik & "\n    </div>\n")
  html.add("  </div>\n</div>\n</body>\n</html>")
  result = html


proc loginSayfasi(panel: AdminPanel, hata: string = ""): string =
  let hataHtml = if hata.len > 0:
                   "<div class='alert alert-danger'>" & hata & "</div>"
                 else: ""
  result = """<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <title>Giriş — """ & panel.baslik & """</title>
""" & adminCss() & """
</head>
<body>
<div class="login-wrap">
  <div class="login-box">
    <h1>⚡ """ & panel.baslik & """</h1>
    <p>Yönetici paneline giriş yapın</p>
    """ & hataHtml & """
    <form method="POST" action="/admin/giris">
      <div class="form-grup">
        <label>Kullanıcı Adı</label>
        <input type="text" name="kullanici" required autofocus>
      </div>
      <div class="form-grup">
        <label>Şifre</label>
        <input type="password" name="sifre" required>
      </div>
      <button type="submit" class="btn btn-primary" style="width:100%;justify-content:center;">
        Giriş Yap
      </button>
    </form>
  </div>
</div>
</body>
</html>"""

proc dashboardHtml(panel: AdminPanel): string =
  var istatistikler = ""
  for t in panel.tablolar:
    let sayi = panel.vt.say(t.ad)
    istatistikler &= """
    <div class="stat-card">
      <div class="sayi">""" & $sayi & """</div>
      <div class="etiket">""" & t.gorunumAdi & """</div>
    </div>"""

  let icerik = """
<div class="card">
  <h2>📊 Genel Bakış</h2>
  <div class="stats">""" & istatistikler & """</div>
</div>
<div class="card">
  <h2>ℹ️ Sistem Bilgisi</h2>
  <table>
    <tr><td><b>Framework</b></td><td>Nogine 0.1.0</td></tr>
    <tr><td><b>Oluşturan</b></td><td>noginse</td></tr>
    <tr><td><b>Tablo Sayısı</b></td><td>""" & $panel.tablolar.len & """</td></tr>
    <tr><td><b>Veritabanı</b></td><td>SQLite</td></tr>
  </table>
</div>"""
  result = adminLayout("Dashboard", icerik, panel)

proc tabloListeHtml(panel: AdminPanel, tablo: AdminTablo,
                    sayfa: int = 1, arama: string = ""): string =
  let boyut = tablo.sayfaBoyutu
  let offset = (sayfa - 1) * boyut
  
  var sorgu = "SELECT * FROM " & tablo.ad
  var params: seq[string] = @[]
  
  if arama.len > 0 and tablo.aramaAlanlari.len > 0:
    var aramaKosullar: seq[string] = @[]
    for alan in tablo.aramaAlanlari:
      aramaKosullar.add(alan & " LIKE ?")
      params.add("%" & arama & "%")
    sorgu &= " WHERE " & aramaKosullar.join(" OR ")
  
  sorgu &= " LIMIT ? OFFSET ?"
  params.add($boyut)
  params.add($offset)
  
  let satirlar = panel.vt.tumSatirlar(sorgu, params)
  let aramaKosul = if arama.len > 0 and tablo.aramaAlanlari.len > 0:
                     tablo.aramaAlanlari.mapIt(it & " LIKE ?").join(" OR ")
                   else: ""
  let aramaParams = if arama.len > 0 and tablo.aramaAlanlari.len > 0:
                      tablo.aramaAlanlari.mapIt("%" & arama & "%")
                    else: newSeq[string]()
  let toplam = panel.vt.say(tablo.ad, aramaKosul, aramaParams)
  
  # Başlık satırı
  var thlar = "<th>#</th>"
  for s in tablo.sutunlar:
    if s.listede: thlar &= "<th>" & s.etiket & "</th>"
  thlar &= "<th>İşlemler</th>"
  
  # Veri satırları
  var tdler = ""
  if satirlar.len == 0:
    let sutunSayisi = tablo.sutunlar.filterIt(it.listede).len + 2
    tdler = "<tr><td colspan='" & $sutunSayisi & "' class='empty'>Kayıt bulunamadı</td></tr>"
  else:
    for satir in satirlar:
      let id = satir.getOrDefault("id", satir.getOrDefault("0", "?"))
      tdler &= "<tr><td>" & id & "</td>"
      for s in tablo.sutunlar:
        if s.listede:
          var deger = satir.getOrDefault(s.ad, "")
          if s.tur == "bool":
            deger = if deger in ["1","true","t"]:
                      "<span class='badge badge-success'>Evet</span>"
                    else:
                      "<span class='badge badge-danger'>Hayır</span>"
          elif deger.len > 50:
            deger = deger[0..47] & "..."
          tdler &= "<td>" & deger & "</td>"
      tdler &= "<td><a href='" & panel.urlPrefix & "/tablo/" & tablo.ad &
               "/" & id & "/duzenle' class='btn btn-sm btn-secondary'>Düzenle</a> "
      if tablo.silinebilir:
        tdler &= "<form method='POST' action='" & panel.urlPrefix & "/tablo/" &
                 tablo.ad & "/" & id & "/sil' style='display:inline'>" &
                 "<button type='submit' class='btn btn-sm btn-danger' " &
                 "onclick=\"return confirm('Silmek istediğinize emin misiniz?')\">Sil</button></form>"
      tdler &= "</td></tr>\n"
  
  # Sayfalama
  let toplamSayfaSayisi = toplamSayfa(toplam, boyut)
  var sayfalama = ""
  if toplamSayfaSayisi > 1:
    sayfalama = "<div class='pagination'>"
    if sayfa > 1:
      sayfalama &= "<a href='?sayfa=" & $(sayfa-1) &
                   (if arama.len>0: "&ara=" & arama else: "") & "'>‹</a>"
    for i in max(1, sayfa-2)..min(toplamSayfaSayisi, sayfa+2):
      let cls = if i == sayfa: " aktif" else: ""
      sayfalama &= "<a href='?sayfa=" & $i &
                   (if arama.len>0: "&ara=" & arama else: "") &
                   "' class='" & cls & "'>" & $i & "</a>"
    if sayfa < toplamSayfaSayisi:
      sayfalama &= "<a href='?sayfa=" & $(sayfa+1) &
                   (if arama.len>0: "&ara=" & arama else: "") & "'>›</a>"
    sayfalama &= "</div>"
  
  let icerik = """
<div class="card">
  <h2>""" & tablo.gorunumAdi & " <small style='color:#999;font-size:13px'>(" & $toplam & """ kayıt)</small></h2>
  <div class="toolbar">
    <div class="search-box">
      <form method="GET">
        <input type="text" name="ara" placeholder="Ara..." value='""" & arama & """'>
      </form>
    </div>
    """ & (if tablo.eklenebilir:
             "<a href='" & panel.urlPrefix & "/tablo/" & tablo.ad & "/yeni' class='btn btn-primary'>+ Yeni Ekle</a>"
           else: "") & """
  </div>
  <table>
    <thead><tr>""" & thlar & """</tr></thead>
    <tbody>""" & tdler & """</tbody>
  </table>
  """ & sayfalama & """
</div>"""
  result = adminLayout(tablo.gorunumAdi, icerik, panel, tablo.ad)

proc formHtml(panel: AdminPanel, tablo: AdminTablo,
              deger: VtSatir = initOrderedTable[string,string](),
              hata: string = ""): string =
  let baslik = if deger.len > 0: "Düzenle" else: "Yeni Ekle"
  let id = deger.getOrDefault("id", "")
  let action = if id.len > 0:
                 panel.urlPrefix & "/tablo/" & tablo.ad & "/" & id & "/kaydet"
               else:
                 panel.urlPrefix & "/tablo/" & tablo.ad & "/kaydet"
  
  let hataHtml = if hata.len > 0:
                   "<div class='alert alert-danger'>" & hata & "</div>"
                 else: ""
  
  var alanlar = ""
  for s in tablo.sutunlar:
    if not s.formda or s.ad == "id": continue
    let mevcut = deger.getOrDefault(s.ad, "")
    alanlar &= "<div class='form-grup'><label>" & s.etiket
    if s.zorunlu: alanlar &= " <span style='color:red'>*</span>"
    alanlar &= "</label>"
    
    case s.tur
    of "textarea":
      alanlar &= "<textarea name='" & s.ad & "'>" & mevcut & "</textarea>"
    of "select":
      alanlar &= "<select name='" & s.ad & "'>"
      for sec in s.seçenekler:
        let sel = if sec.deger == mevcut: " selected" else: ""
        alanlar &= "<option value='" & sec.deger & "'" & sel & ">" & sec.etiket & "</option>"
      alanlar &= "</select>"
    of "bool":
      let chk = if mevcut in ["1","true","t"]: " checked" else: ""
      alanlar &= "<input type='checkbox' name='" & s.ad & "' value='1'" & chk & ">"
    else:
      let tip = block:
        if s.tur == "password": "password"
        elif s.tur == "email": "email"
        elif s.tur == "number": "number"
        else: "text"
      alanlar &= "<input type='" & tip & "' name='" & s.ad & "'" &
                 " value='" & mevcut & "'" &
                 (if s.zorunlu: " required" else: "") & ">"
    alanlar &= "</div>"
  
  let icerik = """
<div class="card">
  <h2>""" & baslik & " — " & tablo.gorunumAdi & """</h2>
  """ & hataHtml & """
  <form method="POST" action='""" & action & """'>
    """ & alanlar & """
    <div style="display:flex;gap:10px;margin-top:8px">
      <button type="submit" class="btn btn-primary">💾 Kaydet</button>
      <a href='""" & panel.urlPrefix & "/tablo/" & tablo.ad & """' class="btn btn-secondary">İptal</a>
    </div>
  </form>
</div>"""
  result = adminLayout(baslik & " — " & tablo.gorunumAdi, icerik, panel, tablo.ad)

# ─── Ana Kayıt Fonksiyonu ─────────────────────────────────────────────────────


# ─── Ana Kayıt Fonksiyonu ─────────────────────────────────────────────────────

proc adminPanelKaydet*(uygulama: Nogine, panel: AdminPanel) =
  ## Admin paneli route'larını uygulamaya kaydet
  let p = panel.urlPrefix
  let ap = panel

  uygulama.rotaEkle(hmGET, p & "/giris",
    proc(istek: Istek, yanit: Yanit): Future[void] {.async.} =
      let oturum = ap.oturumDepo.oturumAl(istek)
      if oturum.girisYapmisMi():
        await yanit.yonlendir(p)
      else:
        await yanit.html(ap.loginSayfasi()))

  uygulama.rotaEkle(hmPOST, p & "/giris",
    proc(istek: Istek, yanit: Yanit): Future[void] {.async.} =
      let kullanici = istek.form("kullanici")
      let sifre = istek.form("sifre")
      let oturum = ap.oturumDepo.oturumAl(istek)
      if kullanici == ap.adminKullanici and sifre == ap.adminSifre:
        oturum.girisYap("admin")
        ap.oturumDepo.oturumKaydet(oturum, yanit, varsayilanOturumAyarlari())
        await yanit.yonlendir(p)
      else:
        await yanit.html(ap.loginSayfasi("Kullanıcı adı veya şifre hatalı!")))

  uygulama.rotaEkle(hmGET, p & "/cikis",
    proc(istek: Istek, yanit: Yanit): Future[void] {.async.} =
      let oturum = ap.oturumDepo.oturumAl(istek)
      oturum.cikisYap()
      ap.oturumDepo.oturumKaydet(oturum, yanit, varsayilanOturumAyarlari())
      await yanit.yonlendir(p & "/giris"))

  uygulama.rotaEkle(hmGET, p,
    proc(istek: Istek, yanit: Yanit): Future[void] {.async.} =
      let oturum = ap.oturumDepo.oturumAl(istek)
      if not oturum.girisYapmisMi():
        await yanit.yonlendir(p & "/giris")
        return
      await yanit.html(ap.dashboardHtml()))

  uygulama.rotaEkle(hmGET, p & "/tablo/:tablo",
    proc(istek: Istek, yanit: Yanit): Future[void] {.async.} =
      let oturum = ap.oturumDepo.oturumAl(istek)
      if not oturum.girisYapmisMi():
        await yanit.yonlendir(p & "/giris")
        return
      let tabloAdi = istek.param("tablo")
      var bulundu = false
      for t in ap.tablolar:
        if t.ad == tabloAdi:
          let sayfa = try: parseInt(istek.sorgu("sayfa", "1")) except: 1
          let arama = istek.sorgu("ara")
          await yanit.html(ap.tabloListeHtml(t, sayfa, arama))
          bulundu = true
          break
      if not bulundu:
        await yanit.durum(404).metin("Tablo bulunamadı: " & tabloAdi))

  uygulama.rotaEkle(hmGET, p & "/tablo/:tablo/yeni",
    proc(istek: Istek, yanit: Yanit): Future[void] {.async.} =
      let oturum = ap.oturumDepo.oturumAl(istek)
      if not oturum.girisYapmisMi():
        await yanit.yonlendir(p & "/giris")
        return
      let tabloAdi = istek.param("tablo")
      for t in ap.tablolar:
        if t.ad == tabloAdi:
          await yanit.html(ap.formHtml(t))
          return
      await yanit.durum(404).metin("Tablo bulunamadı"))

  uygulama.rotaEkle(hmPOST, p & "/tablo/:tablo/kaydet",
    proc(istek: Istek, yanit: Yanit): Future[void] {.async.} =
      let oturum = ap.oturumDepo.oturumAl(istek)
      if not oturum.girisYapmisMi():
        await yanit.yonlendir(p & "/giris")
        return
      let tabloAdi = istek.param("tablo")
      for t in ap.tablolar:
        if t.ad == tabloAdi:
          var veri = initTable[string, string]()
          for s in t.sutunlar:
            if s.ad != "id" and s.formda:
              veri[s.ad] = istek.form(s.ad)
          discard ap.vt.ekle(tabloAdi, veri)
          await yanit.yonlendir(p & "/tablo/" & tabloAdi)
          return
      await yanit.durum(404).metin("Tablo bulunamadı"))

  uygulama.rotaEkle(hmGET, p & "/tablo/:tablo/:id/duzenle",
    proc(istek: Istek, yanit: Yanit): Future[void] {.async.} =
      let oturum = ap.oturumDepo.oturumAl(istek)
      if not oturum.girisYapmisMi():
        await yanit.yonlendir(p & "/giris")
        return
      let tabloAdi = istek.param("tablo")
      let id = istek.param("id")
      for t in ap.tablolar:
        if t.ad == tabloAdi:
          let idInt = try: parseInt(id) except ValueError: 0
          let satir = ap.vt.bul(tabloAdi, idInt)
          await yanit.html(ap.formHtml(t, satir))
          return
      await yanit.durum(404).metin("Tablo bulunamadı"))

  uygulama.rotaEkle(hmPOST, p & "/tablo/:tablo/:id/kaydet",
    proc(istek: Istek, yanit: Yanit): Future[void] {.async.} =
      let oturum = ap.oturumDepo.oturumAl(istek)
      if not oturum.girisYapmisMi():
        await yanit.yonlendir(p & "/giris")
        return
      let tabloAdi = istek.param("tablo")
      let id = istek.param("id")
      for t in ap.tablolar:
        if t.ad == tabloAdi:
          var veri = initTable[string, string]()
          for s in t.sutunlar:
            if s.ad != "id" and s.formda:
              veri[s.ad] = istek.form(s.ad)
          discard ap.vt.guncelle(tabloAdi, veri, "id = ?", @[id])
          await yanit.yonlendir(p & "/tablo/" & tabloAdi)
          return
      await yanit.durum(404).metin("Tablo bulunamadı"))

  uygulama.rotaEkle(hmPOST, p & "/tablo/:tablo/:id/sil",
    proc(istek: Istek, yanit: Yanit): Future[void] {.async.} =
      let oturum = ap.oturumDepo.oturumAl(istek)
      if not oturum.girisYapmisMi():
        await yanit.yonlendir(p & "/giris")
        return
      let tabloAdi = istek.param("tablo")
      let id = istek.param("id")
      for t in ap.tablolar:
        if t.ad == tabloAdi and t.silinebilir:
          discard ap.vt.sil(tabloAdi, "id = ?", @[id])
          await yanit.yonlendir(p & "/tablo/" & tabloAdi)
          return
      await yanit.durum(403).metin("Silme izni yok"))
