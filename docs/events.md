# Olaylar, kararlar ve gazete — veri formatı

Hepsi JSON; `tools/validate_data.gd` ve testler şemayı, çapraz referansları ve şablon kapsamını denetler.

## Olay (`data/events/<id>.json`)

```jsonc
{
  "id": "street_festival", "version": 1,
  "category": "culture",          // serbest etiket (gazete bölümü, istatistik)
  "importance": 65,               // 0-100, gazetede manşet sırası
  "weight": 30,                   // aynı yuvadaki uygun olaylar arasında ağırlık
  "check": "daily",               // daily (balance.events.daily_hour'da) | hourly | follow_up (sadece zincirle)
  "cooldown_days": 12,            // tekrar için en az bekleme
  "once": false,                  // true: şehrin ömründe bir kez
  "conditions": {
    "season": ["spring", "summer"], "weather": ["clear", "cloudy"],
    "hour_between": [10, 20],       // [başlangıç, bitiş) yerel saat; gece yarısını sarabilir: [22, 5]
    "weekdays": [6, 7],             // 1 = Pazartesi … 7 = Pazar
    "min": {"population": 150}, "max": {"traffic": 400},   // population, happiness, traffic, pollution, green, money, employed, unemployment, buildings
    "has_building": {"category:park": 1, "cafe": 1},       // sadece tamamlanmış binalar
    "flags_all": [], "flags_none": [], "policies_all": [], "policies_none": []
  },
  "effects": [
    {"type": "modifier", "stat": "happiness", "amount": 45, "hours": 36},   // ModifierSet.STATS
    {"type": "money", "amount": -3000},                                     // lira
    {"type": "flag", "name": "x"}, {"type": "unflag", "name": "x"},
    {"type": "follow_up", "event": "festival_cleanup", "hours": 20, "chance": 700}  // binde olasılık
  ],
  "vars": {"district": "random_built"}   // random_built | busiest | greenest → mahalle adı
}
```

- Yuva başına zar: `balance.events.daily_chance_permille` / `hourly_chance_permille`. Rastgelelik tick'ten türetilir
  (`SimConfig.STREAM_EVENTS`), yani canlı oyun ile catch-up aynı hikâyeleri üretir.
- Takip olayı zamanı gelince koşullarını yeniden kontrol eder (ör. park yıkıldıysa düşer).
- **Her olayın gazete şablonu zorunlu:** `news_tr.json` ve `news_en.json` içinde `stories["story.<id>"]` (test eder).

## Karar / politika (`data/policies/<id>.json`)

```jsonc
{ "id": "bike_lanes", "version": 1, "name_key": "POL_BIKE_LANES", "desc_key": "POL_BIKE_LANES_DESC",
  "setup_cost": 30000, "cost_per_day": 200,  // lira; günlük maliyet hemen başlar
  "delay_hours": 72,                         // etkiler bu kadar sonra devreye girer
  "effects": {"traffic_relief": 120, "happiness": 15, "pollution": -10},
  "conflicts": ["..."], "min_population": 0 }
```

## Hava (`data/environment/weather.json`, görsel: `weather_visuals.json`)

6 saatlik dilimler, mevsime göre ağırlıklar, `persistence_permille` ile süreklilik. Etkiler değiştirici olarak sisteme
girer. Tahmin, gerçek zarla aynı fonksiyonu kullanır (VARSAYIM: şimdilik hep doğru).

## Gazete (`data/text_templates/`)

- `editorial.json`: haber türlerinin önem puanları, en fazla/en az haber sayısı.
- `news_<dil>.json`: künye, tarih biçimi, ay/gün adları, hava adları ve `stories` şablonları.
  Her şablon `title`/`body` varyant dizileri; birleşmiş haberler için `title_many`/`body_many`.
  Değişkenler: `{building}`, `{count}`, `{district}`, `{population}`, `{policy}`. Türkçe ek uyumu için değişkenin
  arkasına sabit bir kelime koyun: `{district} Mahallesi'nde`.
- Varyant seçimi baskı numarası + haber anahtarından türetilir: aynı baskı her zaman aynı okunur.
- Eksik İngilizce anahtar Türkçeye düşer.
