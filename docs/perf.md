# Performans notları

Bütçe (orta seviye telefon, Medium profil): 60 FPS, < 150 draw call, < 300k görünür üçgen, kare < 16 ms.

| Tarih | Aşama | Cihaz | Profil | FPS | Draw call | Üçgen | Not |
|---|---|---|---|---|---|---|---|
| 2026-10-28 | M1 | llvmpipe (yazılımsal, referans değil) | High | 6 | 31 | 51k | Yer tutucu şehir, tüm harita görünür |
| 2026-10-28 | M1 | llvmpipe | Low | 11 | 31 | 34k | DOF/glow kapalı, %45 ağaç |
| 2026-10-28 | M2 | masaüstü CPU (headless) | — | — | — | — | Sim: 329 bina, 2016 tick = 504 ms (0,25 ms/tick) |

Cihaz ölçümleri M6'da (Android export) eklenecek. Yazılımsal render FPS'i sadece göreli karşılaştırma içindir.
