# Performans notları

Bütçe (orta seviye telefon, Medium profil): 60 FPS, < 150 draw call, < 300k görünür üçgen, kare < 16 ms.

| Tarih | Aşama | Cihaz | Profil | FPS | Draw call | Üçgen | Not |
|---|---|---|---|---|---|---|---|
| 2026-10-28 | M1 | llvmpipe (yazılımsal, referans değil) | High | 6 | 31 | 51k | Yer tutucu şehir, tüm harita görünür |
| 2026-10-28 | M1 | llvmpipe | Low | 11 | 31 | 34k | DOF/glow kapalı, %45 ağaç |
| 2026-10-28 | M2 | masaüstü CPU (headless) | — | — | — | — | Sim: 329 bina, 2016 tick = 504 ms (0,25 ms/tick) |
| 2026-10-30 | M4 | masaüstü CPU (headless) | — | — | — | — | Sim + hava + olaylar: 329 bina, 2016 tick = 695 ms (0,35 ms/tick) |
| 2026-10-30 | M6 | llvmpipe | High | — | 96 | 203k | Dolu şehir (329 bina) + sokak hayatı, tüm harita; kare 169 ms (yazılımsal) |
| 2026-10-30 | M6 | llvmpipe | High, yakın | — | 97 | 210k | Zoom 200; MultiMesh örnek bazında kırpılmıyor, üçgen sayısı benzer |
| 2026-10-30 | M6 | llvmpipe | Medium | — | 96 | 165k | kare 117 ms (yazılımsal) |
| 2026-10-30 | M6 | llvmpipe | Low | — | 96 | 103k | kare 52 ms (yazılımsal); DOF/glow kapalı, 30 FPS sınırı |

Ölçüm: `xvfb-run -a godot --path . --rendering-method mobile --resolution 540x960 -s tools/perf_probe.gd`.
Bütçe (< 150 draw call, < 300k üçgen) dolu şehirde bile karşılanıyor. İlk oturumda `PerfWatch` FPS < 45 ise kaliteyi
bir kademe düşürür (bir kez; elle seçim her zaman kazanır).

Cihaz ölçümleri M6'da (Android export) eklenecek. Yazılımsal render FPS'i sadece göreli karşılaştırma içindir.
