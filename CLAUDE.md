# CLAUDE.md — Şehir Nefes Alıyor

Mobil (Android + iOS), dikey ekran, tek elle oynanan, **gerçek zamanda yaşayan** modern şehir kurma oyunu.
Oyuncu belediye başkanıdır; şehir oyuncu yokken de yaşar. Uygulama açılınca geçen süre deterministik
olarak "yetiştirilir" (offline catch-up) ve oyuncu "sen yokken ne oldu"yu bir şehir gazetesi olarak okur.

Geliştirme planı ve aşamalar: [`docs/PLAN.md`](docs/PLAN.md). Bu dosya kalıcı kuralları içerir; plan değişir, kurallar nadiren.

---

## 1. Teknik yığın

| Katman | Seçim |
|---|---|
| Motor | Godot **4.4.x** (stable), GDScript, **Mobile** render yolu |
| Hedef | Android (API 24+), iOS 15+; dikey (portrait) ekran |
| Test | GUT 9.x (`addons/gut`), headless çalışır |
| Kayıt | `user://` altında sürüm numaralı JSON |
| Yapay zekâ metni | Ayrı backend: Cloudflare Worker (TypeScript), `backend/` klasöründe |
| Bildirim | Yerel bildirim eklentisi (Android/iOS), sadece önemli olaylar |

> **API anahtarı asla istemciye konmaz.** İstemci sadece kendi backend'imizle konuşur; anahtar Worker secret'ıdır.
> Backend yoksa / erişilemezse oyun **şablon tabanlı yedek metin** ile tam çalışır.

---

## 2. Mimari

### 2.1 Katmanlar (bağımlılık yönü sadece aşağı doğru)

```
 ┌──────────────────────────────────────────────┐
 │  Presentation (scenes/, view/)               │  Node3D, Control, shader, kamera, efekt
 │   - sim'i OKUR, sinyalleri DİNLER            │
 │   - kararları Command olarak sim'e GÖNDERİR  │
 ├──────────────────────────────────────────────┤
 │  App / Services (app/)                       │  Autoload'lar: zaman, kayıt, metin servisi,
 │   - sim'i sürer (tick), kaydeder, yükler     │  bildirim, ayarlar
 ├──────────────────────────────────────────────┤
 │  Sim Core (sim/)                             │  SADECE RefCounted/Resource. Node YOK.
 │   - saf, deterministik, test edilebilir      │  SceneTree, Time, OS, Input kullanılmaz.
 ├──────────────────────────────────────────────┤
 │  Data (data/)                                │  Bina, olay, vatandaş arketipi, metin şablonu
 └──────────────────────────────────────────────┘
```

**Kesin kurallar**
- `sim/` altındaki hiçbir dosya `Node`, `get_tree()`, `Time`, `OS`, `Input`, `randf()`/`randi()` (global RNG) veya
  `load()` ile sahne kullanmaz. Zaman ve rastgelelik **dışarıdan parametre** olarak gelir.
- `sim/` → `view/` veya `app/` import etmez. Ters yön serbesttir.
- Görsel katman sim durumunu **değiştirmez**; sadece `Command` nesneleri gönderir (`PlaceBuildingCommand`,
  `ChoosePolicyCommand`, `ReplyLetterCommand`...). Komutlar da kayda/günlüğe yazılır.

### 2.2 Zaman modeli ve determinizm

- **Sim adımı (tick) sabittir: 1 tick = 10 gerçek dakika.** (Varsayım — `SimConfig.TICK_SECONDS`.)
- Canlı oyunda da catch-up'ta da **aynı** `Simulation.step(tick_index)` fonksiyonu çalışır. "Canlı mod" sadece
  duvar saati tick sınırını geçtikçe `step` çağırmaktır; arada görsel katman enterpolasyon yapar.
- Şehir durumu = `f(başlangıç tohumu, komut listesi, tick sayısı)`. Aynı girdi → bit-bit aynı çıktı.
- **Rastgelelik:** global durumlu RNG yok. Her tick ve her alt sistem için tohum türetilir:
  `seed = hash(city_seed, tick_index, stream_id)` → `SimRng` (kendi PCG32/xorshift uygulamamız, tamsayı tabanlı).
  Böylece sonuç, adımların hangi oturumda çalıştırıldığından bağımsızdır.
- **Kayan nokta:** sim'de `sin/cos/pow/exp` gibi platforma göre farklı yuvarlanabilecek fonksiyonlar kullanılmaz.
  Para, nüfus, mutluluk tamsayı (veya sabit noktalı: ×1000) tutulur. Sadece `+ - * /` ile double aritmetiğine izin var.
- **Catch-up limiti:** en fazla **14 gün** (2016 tick) yetiştirilir; fazlası "şehir uykuya daldı" olarak özetlenir. (Varsayım.)
- **Saat hilesi:** cihaz saati geri giderse sim geri sarılmaz, sadece bekler. İleri atlama limitle kırpılır.
- Gün/gece görseli gerçek **yerel** saate bağlıdır; sim takvimi de gerçek tarihten türetilir (mevsim = gerçek ay).

### 2.3 Sinyaller ve olay akışı

- Sim çekirdeği Godot sinyali yerine **olay günlüğü** üretir: `step()` sonunda `Array[SimEvent]` döner ve
  `EventLog`'a eklenir. (Saf veri; test edilebilir; gazete bunun üzerine kurulur.)
- `app/SimRunner` bu olayları Godot sinyallerine çevirir: `EventBus.sim_event_emitted(event)`,
  `EventBus.tick_advanced(tick)`, `EventBus.catch_up_finished(summary)`.
- Sistemler birbirini doğrudan çağırmaz; `EventBus` sinyallerine bağlanır. Sinyal adları **geçmiş zaman**:
  `building_placed`, `letter_received`, `day_started`.

### 2.4 Autoload'lar (sadece gerçekten global servisler)

| Autoload | Görev |
|---|---|
| `EventBus` | Uygulama geneli sinyaller (sadece sinyal tanımları, mantık yok) |
| `Clock` | Duvar saati soyutlaması (testte sahte saat enjekte edilir) |
| `SimRunner` | Simulation örneğini tutar, tick'leri sürer, catch-up başlatır |
| `SaveService` | Kayıt/yükleme, sürüm göçü (migration), atomik yazma |
| `TextService` | Gazete/mektup metni: önce backend, olmazsa şablon (M4: şablon; saf `app/text/NewsDesk` + `TemplateWriter`) |
| `Settings` | Grafik kalitesi, ses, bildirim tercihleri |

Yeni autoload eklemek **mimari değişikliktir** → önce sor.

### 2.5 Veri odaklı içerik

- Bina, olay, vatandaş arketipi, politika ve metin şablonları `data/` altında **JSON** dosyalarıdır.
- `sim/content/ContentDb` bunları yükleyip doğrular (şema kontrolü, eksik alan → açık hata mesajı).
- Kodda içerik kimliği sabitlenmez (`"cafe_small"` gibi string'ler yalnızca data ve testlerde geçer).
- Her içerik kaydının `id` (snake_case, benzersiz) ve `version` alanı vardır.
- `ContentDb.from_dicts()` saftır (testler fixture verir); dosya okuyan tek yer `ContentDb.load_default()`.
- Yeni bina = `data/buildings/<id>.json` + `assets/i18n/strings.csv` içinde `BLD_<ID>` ve `BLD_<ID>_DESC` anahtarları.
- Yeni olay = `data/events/<id>.json` + her iki dilde `story.<id>` gazete şablonu; yeni karar = `data/policies/<id>.json`
  + `POL_<ID>`/`POL_<ID>_DESC`. Format ve kurallar: [`docs/events.md`](docs/events.md).
- Gazete metni sim'i etkilemez; baskılar kaydın `meta` alanında veri olarak saklanır, okunurken yazıya dökülür.

### 2.6 Kayıt

- Konum: `user://saves/city.json`, yedek: `city.json.bak`. Yazma: `city.json.tmp` → `rename` (atomik).
- Kök alanlar: `{"save_version": N, "game_version": "x.y.z", "city_seed": ..., "last_tick": ..., "last_wall_time": ..., "state": {...}, "commands": [...]}`
- Göç zinciri: `SaveMigrations.migrate(data)` → `v1→v2→…→güncel`. **Eski göç fonksiyonları asla silinmez.**
- Her `save_version` artışında `tests/fixtures/saves/` altına örnek kayıt eklenir ve göç testi yazılır.
- Dosyada `state_hash` vardır; uyuşmazlık = bozuk kayıt → yedek denenir. Format dönüşümü saf `sim/save/SaveCodec`,
  dosya işlemleri `app/SaveService`. Test ve araçlar `SEHIR_SAVE_DIR` ile ayrı klasör kullanır, gerçek kayda dokunmaz.
- Zaman atlamaları (uyku, saat geri alma) `RealignClockCommand` olarak komut günlüğüne yazılır; yeniden oynatma bozulmaz.

### 2.7 Görsel / performans

- İzometrik his: dar FOV'lu (≈25°) perspektif kamera, ~35–45° eğim, döndürülebilir. Tilt-shift = `CameraAttributesPractical` DOF.
- Binalar ve tekrar eden nesneler (ağaç, lamba, araba, insan) **MultiMesh** ile çizilir. Hareket shader/vertex animasyonu veya MultiMesh transform güncellemesi ile.
- Gün/gece dinamik güneş gerektirdiği için tam `LightmapGI` kullanılmaz; "baked ışık" = modellere **pişirilmiş AO (vertex color / doku)** + emissive pencere maskesi. Tek kademeli gölge.
- Kalite profilleri (`Settings.graphics_quality`: low/medium/high): gölge, DOF, MSAA, render ölçeği, kalabalık yoğunluğu, hava parçacıkları.
- **Bütçe (orta seviye telefon, 60 FPS):** < 150 draw call, < 300k üçgen görünür, frame < 16 ms. Profil sonuçları `docs/perf.md`'ye.

---

## 3. Klasör yapısı

```
project.godot
CLAUDE.md
docs/                 PLAN.md, perf.md, kararlar (ADR) ve tasarım notları
addons/               gut/ ve diğer 3. taraf eklentiler (değiştirilmez)
sim/                  SAF SİMÜLASYON ÇEKİRDEĞİ (Node yok)
  core/               Simulation, SimState, SimRng, SimConfig, SimClockMath
  systems/            population, economy, happiness, traffic, environment
  events/             EventEngine, SimEvent, koşul/etki değerlendirici
  citizens/           Citizen, Personality, Memory
  commands/           Command tabanı ve somut komutlar
  content/            ContentDb, şema doğrulama
  save/               serialize/deserialize, SaveMigrations
app/                  Autoload servisler (EventBus, Clock, SimRunner, SaveService, TextService, Settings)
view/                 Görsel katman script'leri
  city/               şehir sahnesi, bina görselleri, MultiMesh yöneticileri
  camera/             dokunmatik kamera
  environment/        gün/gece, gökyüzü, hava durumu, mevsim
  life/               araç, yaya, tramvay
  ui/                 cam paneller, gazete, mektup, HUD
scenes/               .tscn dosyaları (main.tscn, city.tscn, ui/*.tscn)
assets/               models/, textures/, materials/, shaders/, fonts/, audio/, i18n/ (strings.csv: keys,tr,en)
data/                 buildings/, events/, citizens/, policies/, text_templates/  (JSON)
tests/                unit/ (sim), integration/ (app servisleri), fixtures/
backend/              Cloudflare Worker (TypeScript) — gazete/mektup üretimi
tools/                yardımcı script'ler (veri doğrulama, determinizm karşılaştırma)
```

---

## 4. Kodlama kuralları (GDScript)

- **Statik tip her yerde:** `var x: int = 0`, `func f(a: Vector3) -> void`, `Array[Building]`. `untyped` uyarıları hata kabul edilir.
- Dosya = `snake_case.gd`, sınıf = `class_name PascalCase`, sabit = `UPPER_SNAKE`, özel üye `_on_`/`_` öneki.
- Sim sınıfları `extends RefCounted` (veya veri için `Resource`). `extends Node` **yalnızca** `app/` ve `view/`.
- Her sim durumu sınıfında `to_dict() -> Dictionary` ve `static func from_dict(d: Dictionary)` olur.
- `get_node("../../X")` gibi kırılgan yollar yok; `@export` veya `%UniqueName` kullan.
- `_process` içinde ayırma (allocation) yok; nesne havuzu kullan. Sim `_process`'te değil, `SimRunner`'da tick ile çalışır.
- Kullanıcıya görünen tüm metinler `tr()` ile; birincil dil **Türkçe**, anahtarlar İngilizce (`"UI_NEWSPAPER_TITLE"`).
  İstisna: sadece debug build'de görünen geliştirici araçları (`DebugPanel`).
- Görsel katmandaki saf hesaplar (güneş, palet, kamera jest matematiği) `static func` olarak yazılır ve birim test edilir.
- Yorumlar kısa; "neden"i açıklar. Kod tanımlayıcıları İngilizce.
- Sihirli sayı yok: denge değerleri `data/` veya `SimConfig` içinde.
- **`sim/` içinde `const` Array/Dictionary yok** (yalnızca yükleme anı doğrulama dosyaları hariç). Godot 4.4.1'de tick
  başına çalışan statik koddan sabit tipli diziyi dolaşmak yığını bozdu (rastgele "double free"; M4'te bulundu).
  Yerine `match`, düz sözlük sabiti (literal) veya `SimConfig` int sabitleri. `tests/unit/test_sim_code_rules.gd` denetler.
- Sınıflar arası enum yerine `SimConfig` int sabitleri (ör. RNG akış kimlikleri `STREAM_*`; numaralar asla değişmez).

### Test kuralları
- Her sim sistemi için `tests/unit/test_<sistem>.gd`.
- **Determinizm testi zorunlu:** aynı tohum + aynı komutlarla (a) N tick tek seferde, (b) parçalı/kesintili çalıştırma,
  (c) kaydet→yükle→devam senaryoları aynı durum hash'ini vermeli (`SimState.hash()`).
- Kayıt göçü için fixture testleri. Hata ayıklanan her bug için önce kırmızı test.

---

## 5. Komutlar

```bash
# Godot ikilisi PATH'te "godot" olarak varsayılır (4.4.x).
godot --path . --editor                      # editörü aç
godot --path .                               # oyunu çalıştır
godot --headless --path . --import           # ilk kurulumda/CI'da kaynakları içe aktar

# Testler (GUT, headless) — kısa yol: ilk seferde import da eder
tools/run_tests.sh
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Tek test dosyası
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_determinism.gd -gexit

# Görsel kontrol: belirli saatlerde ekran görüntüsü (GPU yoksa xvfb-run + lavapipe ile)
xvfb-run -a godot --path . --rendering-method mobile --resolution 540x960 -s tools/capture.gd -- --out=/tmp/shots --hours=8,13,18,22 --quality=2

# Senaryolu görüntü: bina kur, sim'i ilerlet, yerleştirme modu / seçim / inşa çekmecesi
xvfb-run -a godot --path . --rendering-method mobile --resolution 540x960 -s tools/capture.gd -- --out=/tmp/shots --hours=11 --build="office_tower@19,19" --advance=100 --placing=cafe --zoom=210 --focus=15,16

# Sim hız ölçümü (14 günlük catch-up)
godot --headless --path . -s tools/bench_sim.gd

# Kayıt determinizm kontrolü: kaydı tohum + komutlardan baştan oynat, hash'i karşılaştır
godot --headless --path . -s tools/verify_save.gd -- user://saves/city.json

# Yeni kayıt sürümü için fixture (sadece SaveMigrations.CURRENT artınca; eskisini asla yeniden üretme)
godot --headless --path . -s tools/make_save_fixture.gd

# Yetiştirme özeti görüntüsü: şehri kur, 50 saat "uygulama kapalı", yeniden aç
xvfb-run -a godot --path . --rendering-method mobile --resolution 540x960 -s tools/capture.gd -- --out=/tmp/shots --hours=10 --away=50

# Veri doğrulama (tüm data/*.json şema kontrolü)
godot --headless --path . -s tools/validate_data.gd

# Dışa aktarma (export_presets.cfg gerekli)
godot --headless --path . --export-release "Android" build/android/sehir.apk
godot --headless --path . --export-release "iOS" build/ios/sehir.ipa

# Backend
cd backend && npm install && npx wrangler dev       # yerel
cd backend && npm test                              # birim testleri
cd backend && npx wrangler secret put ANTHROPIC_API_KEY
cd backend && npx wrangler deploy
```

---

## 6. Çalışma şekli (Claude için)

- Aşamalar `docs/PLAN.md`'deki sırayla; her aşama **küçük, anlamlı commit'ler** halinde.
- Commit mesajı: `M<n>: <kısa açıklama>` (örn. `M2: add PlaceBuildingCommand and zoning validation`).
- Aşama sonunda: testleri çalıştır, oyunu headless başlatıp hata olmadığını doğrula, kısa özet yaz.
- Belirsiz noktada makul varsayım yap ve **`VARSAYIM:`** etiketiyle koda/plana/özete işaretle.
- **Büyük mimari değişiklikte önce sor:** yeni autoload, katman kuralını delmek, kayıt formatında kırıcı değişiklik,
  render yolu değişimi, yeni 3. taraf bağımlılık.
- `addons/` altındaki 3. taraf koda dokunma; gerekiyorsa sarmalayıcı yaz.
- Gizli anahtarları, kişisel verileri asla repoya koyma. `.env`, `*.keystore`, `export_credentials.cfg` `.gitignore`'da.
