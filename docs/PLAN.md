# Geliştirme Planı — Şehir Nefes Alıyor

Durum: **Plan onaylandı. M0 ✅ M1 ✅ — sıradaki: M2.**
Repo başlangıçta tamamen boştu (commit yok, dosya yok).

![M1 gün döngüsü: 08:00, 13:00, 17:23, 21:00](images/m1_day_cycle.png)
Kalıcı kurallar için bkz. [`../CLAUDE.md`](../CLAUDE.md).

Her aşama: küçük commit'ler → aşama sonunda testler + headless çalıştırma → kısa özet.
`VARSAYIM:` etiketli maddeler onayınızı veya düzeltmenizi bekleyen kararlardır.

---

## M0 — İskelet (M1'in ilk commit'leri)

- `project.godot` (Mobile renderer, portrait, 1080×1920 taban, `canvas_items` stretch), `.gitignore`, `.gitattributes`.
- Boş klasör yapısı, autoload iskeletleri (`EventBus`, `Clock`, `Settings`).
- GUT eklentisi + ilk "duman" testi, `tools/` altında test çalıştırma script'i.
- GitHub Actions: headless Godot ile testleri çalıştıran CI.

**Kabul:** `godot --headless` ile proje hatasız açılıyor, GUT 1 test geçiyor, CI yeşil.

---

## M1 — İzometrik sahne + kamera + gün/gece döngüsü

1. `scenes/city.tscn`: zemin, ızgara (VARSAYIM: **kare ızgara, 1 hücre = 8 m, başlangıç haritası 32×32**), birkaç yer tutucu low-poly bina.
2. **Dokunmatik kamera** (`view/camera/city_camera.gd`):
   tek parmak sürükle (pan), iki parmak pinch zoom + twist döndürme, ataletli yavaşlama, sınırlar,
   editörde fare ile test (sağ tık döndür, tekerlek zoom). Pitch sabit aralıkta (35–55°).
3. **Gün/gece** (`view/environment/day_night.gd`): gerçek yerel saatten güneş açısı, gökyüzü gradyanı
   (şafak/gün/gün batımı/gece paleti `data/` içinde), ambient renk, güneş enerjisi. Sim'den bağımsız saf fonksiyon
   `SunModel.sample(local_time, day_of_year) -> SunState` (test edilebilir).
4. Pencere ışıkları (emissive maske, saate göre yanma oranı) ve sokak lambaları (MultiMesh + gece emissive).
5. Tilt-shift (DOF) + yumuşak gölge + kalite profili (low/medium/high) ilk sürümü.
6. Debug paneli: saati hızlandır/ayarla (sadece debug build), FPS/draw call göstergesi.

**Kabul:** Masaüstünde ve Android'de sahne açılıyor; kamera akıcı; debug ile saati kaydırınca gün→gece geçişi
yumuşak; `SunModel` testleri geçiyor.

---

## M2 — Bina yerleştirme + temel simülasyon

1. `sim/core`: `SimState`, `SimConfig`, `SimRng` (PCG32, tamsayı), `Simulation.step(tick)`, `SimState.hash()`.
2. `sim/content/ContentDb` + `data/buildings/*.json` (konut, kafe, ofis, park, metro istasyonu, gökdelen, çatı bahçesi...)
   ve şema doğrulama (`tools/validate_data.gd`).
3. `sim/commands`: `PlaceBuildingCommand`, `DemolishCommand` (doğrulama: yer, bütçe, yol bağlantısı).
4. Sistemler (ilk basit hâlleri): nüfus, ekonomi (gelir/gider/vergi), mutluluk, trafik yoğunluğu (bölge bazlı,
   saate göre talep eğrisi), çevre (yeşil alan/kirlilik).
5. Görsel: yerleştirme modu (hayalet bina, geçerli/geçersiz renk, büyük dokunma onayı), bina MultiMesh'leri,
   cam efektli HUD (para, nüfus, mutluluk).
6. Testler: her sistem birim testi + ilk determinizm testi.

VARSAYIM: Yol ağı ilk sürümde **otomatik** (binalar ızgara yollarına bağlanır); serbest yol çizimi M6 sonrası.

**Kabul:** Bina yerleştirilebiliyor, istatistikler tick'lerle değişiyor, sim testleri yeşil.

---

## M3 — Offline catch-up + kayıt

1. `app/Clock` (gerçek/sahte saat), `app/SimRunner` (canlı tick + catch-up, arka planda dilimlenmiş çalıştırma —
   arayüz donmasın; ilerleme göstergesi).
2. Catch-up limiti (14 gün), saat geri/ileri hile koruması.
3. `sim/save`: serialize/deserialize, `SaveMigrations`, `SaveService` (atomik yazma, yedek, bozuk kayıttan kurtarma).
   Kaydetme zamanları: uygulama arka plana geçince, her N tick'te, kritik komuttan sonra.
4. "Sen yokken" özet verisi (`CatchUpSummary`: değişen istatistikler, olay sayıları) — metni M4'te gelir.
5. **Determinizm test paketi:** tek sefer vs parçalı vs kaydet/yükle/devam; 2016 tick catch-up süresi ölçümü
   (hedef: orta telefonda < 1,5 sn).

**Kabul:** Uygulamayı kapat → sahte saatle 3 gün ileri → aç: aynı tohumla her seferinde aynı sonuç; testler yeşil.

---

## M4 — Olay motoru + gazete (şablonlu)

1. `data/events/*.json`: koşullar (mevsim, saat, gün, istatistik eşikleri, bina varlığı, önceki olay bayrakları),
   ağırlık/nadirlik, bekleme süresi (cooldown), etkiler, **zincir** (`follow_ups` + gecikme tick'i).
2. `sim/events/EventEngine`: deterministik seçim, gecikmeli sonuç kuyruğu (kararların "günler sonra" etkisi).
3. Politika/proje kararları (`data/policies`): `ChoosePolicyCommand`, gecikmeli etkiler.
4. Gazete: `EventLog` → öne çıkan olay seçimi (önem puanı) → **şablon metin** (`data/text_templates/newspaper_tr.json`,
   değişkenli, varyantlı, sıcak/esprili ton) → gazete arayüzü (manşet, 2–4 haber, hava durumu köşesi).
5. Hava durumu ve mevsim (sim tarafında deterministik hava; görselde yağmur/sis/kar parçacıkları).

**Kabul:** 7 günlük catch-up sonrası tutarlı ve tekrarlanabilir bir gazete; olay motoru testleri yeşil.

---

## M5 — Yapay zekâ backend + vatandaş mektupları

1. `sim/citizens`: kişilik özellikleri, ilgi alanları, ruh hali, **hafıza** (oyuncu kararlarına referanslar).
   VARSAYIM: Simüle edilen "adlı" vatandaş sayısı **~50–200** (geri kalan nüfus istatistiksel); mektup yazanlar bunlar.
2. Mektup tetikleyicileri (olay + kişilik + hafıza), `ReplyLetterCommand` (hazır cevap seçenekleri, sonuçlu).
3. `backend/` Cloudflare Worker (TypeScript):
   - `POST /v1/newspaper`, `POST /v1/letter` — istemci **yapılandırılmış olay verisi** yollar, serbest prompt değil.
   - Anthropic API anahtarı Worker secret'ı; model adı ortam değişkeni ile ayarlanır (varsayılan: küçük/hızlı model).
   - Anonim cihaz kimliği + hız sınırı (KV/Durable Object), yanıt önbelleği, çıktı uzunluk/içerik kontrolü.
4. `app/TextService`: backend'e zaman aşımlı istek → başarısızsa şablon; üretilen metin kayda yazılır
   (aynı gazete tekrar istenmez). **Metin sim durumunu etkilemez** → determinizm bozulmaz.
5. Testler: Worker birim testleri (sahte API), istemci tarafı yedek-metin testleri.

VARSAYIM: Oyuncunun serbest metin cevabı **yok**, sadece seçenekli cevaplar (prompt-injection ve moderasyon riski
düşük). Serbest metin istenirse ayrı karar.

**Kabul:** Backend açıkken yapay zekâ metni, kapalıyken şablon metni geliyor; anahtar istemci derlemesinde yok.

---

## M6 — Cilalama, bildirimler, performans

1. Yaşayan detaylar: araç/yaya/tramvay akışları (MultiMesh, saat ve trafik verisine göre yoğunluk), bisikletler.
2. Yerel bildirimler (eklenti; Android + iOS), sadece önemli olaylar, günde en fazla 2–3, sessiz saatler.
   Bildirimler kayıt sırasında **catch-up simülasyonu önceden koşularak** zamanlanır (sim deterministik olduğu için mümkün).
3. Oturum akışı: açılış → catch-up animasyonu → gazete → 1–2 karar → çıkış (günde 2–4 kısa oturum).
4. Performans: profil, LOD, MultiMesh birleştirme, gölge mesafesi, kalite profilinin otomatik önerisi; `docs/perf.md`.
5. UI cilası (cam paneller, geçişler, haptik), ses, erişilebilirlik (yazı boyutu), Türkçe/İngilizce dil dosyaları.
6. Android/iOS export ayarları, ikon, açılış ekranı.

**Kabul:** Hedef orta seviye cihazda 60 FPS (medium), bildirimler cihazda test edildi.

---

## Varsayımlar (onaylandı)

1. **Godot 4.4.x + Mobile renderer** — uygun mu? (4.5/4.6 kullanıyorsanız söyleyin.)
2. **Tick = 10 dakika, catch-up limiti 14 gün** — denge ve pil açısından makul buluyorum.
3. **Kare ızgara + otomatik yol ağı** (M2). Serbest yol çizimi sonraya.
4. **"Baked ışık"** yorumu: dinamik güneş zorunlu olduğundan tam lightmap yerine pişirilmiş AO + emissive pencereler.
5. **Adlı vatandaş sayısı ~50–200**, gerisi istatistiksel nüfus.
6. **Mektuplara seçenekli cevap** (serbest metin yok).
7. **3D modeller:** başlangıçta prosedürel/yer tutucu low-poly (kod/CSG/basit mesh). Kendi model kütüphaneniz veya
   tercih ettiğiniz bir CC0 paket var mı?
8. **Dil:** birincil Türkçe, İngilizce ikincil.
9. **Godot ortamda kurulu değil** — CI'da GitHub Actions indiriyor; yerelde (bulut ortamı) Godot 4.4.1 + lavapipe
   (yazılımsal Vulkan) ile gerçek Mobile renderer görüntüsü alınabiliyor (`tools/capture.gd`).
10. **Şehrin kurgusal adresi/konumu** (`data/environment/city_location.json`): "Ihlamur Sokağı No: 17, Çınaraltı
    Mahallesi, 34712 Nefeskent", enlem 40.74°. Güneşin yolu bu enleme göre, saat cihazın yerel saatine göre.
    Backend için de M5'te yer tutucu adres `https://sehir-nefes-api.example.workers.dev` (ayardan değişir).

## Aşama notları

### M1 (tamamlandı)
- Yapılan: dokunmatik kamera (pan/pinch/twist/atalet/sınırlar, fare desteği), gerçek saate bağlı güneş/ay,
  gökyüzü, sis, pencere ve sokak lambası ışıkları, tilt-shift DOF, kalite profilleri, cam efektli debug paneli
  (saat kaydırma, hızlı akış, kalite, FPS/draw call). Yer tutucu şehir tamamen MultiMesh ile (~31 draw call, ~51k üçgen).
- VARSAYIM: Saat "güneş saati" kabul edildi (boylam/yaz saati düzeltmesi yok). Düşük kalite 30 FPS sınırlı (pil).
- VARSAYIM: Ay ışığı sabit 42° yükseklikten, güneşin karşı yönünden gelir; ışık geçişi güneş −4°'deyken yapılır.
- Bilinen eksik: cihazda (Android/iOS) FPS ölçümü yapılmadı — export ayarları M6'da. Gerçek low-poly modeller yok.
