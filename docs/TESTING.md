# Telefonda test kılavuzu (Android)

## 1. APK'yı indir ve kur
1. GitHub → **Actions** → en son yeşil **tests** çalışması → sayfanın altındaki **Artifacts** →
   `sehir-nefes-aliyor-debug-apk` (zip). Her `main` gönderiminde yenisi üretilir, 14 gün saklanır.
2. Zip'i aç → `sehir-debug.apk` dosyasını telefona at (kablo, Drive, Telegram…).
3. Telefonda dosyaya dokun. "Bilinmeyen kaynaklardan yükleme" izni sorulursa o uygulama için izin ver.
   Debug imzalı olduğu için Play Protect uyarı verebilir: "Yine de yükle".
4. Önceki bir sürüm kuruluysa üstüne kurulur; şehir korunur.

## 2. İlk açılışta bakılacaklar
- Şehir 3 boyutlu görünüyor, gün/gece gerçek saate göre.
- Gazete kendiliğinden açılıyor, ilk sayı "Yeni belediye başkanı göreve başladı".
- Kapatınca "Bugünün gündemi" kartı çıkıyor.
- Tek parmakla kaydır, iki parmakla yakınlaştır/döndür.
- İnşa et → bir kart seç → haritayı kaydır → Yerleştir.

## 3. Bildirim testi
1. ⚙ (sağ üst) → **Bildirimler: Açık** olsun.
2. **Test bildirimi (10 sn sonra)** düğmesine bas (sadece bu test sürümünde var).
   Android 13+ ise izin penceresi çıkar → **İzin ver**.
3. Uygulamayı arka plana al (ana ekrana dön). ~10 saniye (Android bazen birkaç dakika geciktirebilir).
4. "Nefeskent — Bildirimler çalışıyor!" bildirimi gelmeli. Dokununca oyun açılmalı.
5. Gerçek bildirimler: uygulama arka plana geçince önümüzdeki 24 saat planlanır
   (mektup, kararın yürürlüğe girmesi, nüfus eşiği, büyük açılış, sabah gazetesi; günde en fazla 3,
   22:00–08:00 arası sessiz). Uygulamayı açınca bekleyenler iptal edilir.

## 4. Performans ölçümü
1. ⚙ → **Performans testi (~40 sn)**. Telefonu bu sürede elleme.
   Kendi şehrin değişmez; test geçici, dolu bir şehirde yapılır.
2. Bitince sonuç ekranı: her kalite (Yüksek/Orta/Düşük) için uzak ve yakın görünümde FPS, %1 düşük FPS,
   kare süresi, çizim çağrısı. Altta **Önerilen kalite**.
3. **Sonucu kopyala** → bana yapıştır. Ben `docs/perf.md`'ye işleyip ayarları buna göre düzeltirim.
4. İstersen **Öneriyi uygula** ile kaliteyi ayarla.

## 5. Zamanı hızlandırarak deneme (test sürümünde)
Üstteki saat şeridine dokun → geliştirici paneli açılır:
- **+1 sa / +1 gün / +1 ay**: saati ileri al → "Şehir uyanıyor…" ve gazete görünür (bir ay = 14 gün simülasyon + uyku).
- **Hızlı akış**: gün/gece döngüsünü hızlı izle.
- **Kalite**: grafik profilini değiştir.
- **Yeni şehir**: baştan başla (mevcut şehir silinir).

## 6. Bilinen durumlar
- Yapay zekâ metni kapalı (backend yayında değil); gazete ve mektuplar şablon metinlerle gelir. Bu beklenen durum.
- Ses yok.
- Telefon yeniden başlatılırsa planlanmış bildirimler silinir; oyunu bir kez açıp kapatınca yeniden planlanır.
- iOS: kod hazır ve CI'da derleniyor, ancak Apple geliştirici hesabı olmadan iPhone'a kurulamaz.

Bir sorun görürsen: ne yaptın, ne bekledin, ne oldu + mümkünse ekran görüntüsü.
