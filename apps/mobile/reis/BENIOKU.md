# Reis

Reis, OpenBot mobil uygulamasının (nightly-labs/openbot, `apps/mobile`) Gökhan için kişisel derlemesidir.
Kaynak: https://github.com/gokhangeo/openbot (fork). Lisans: PolyForm Noncommercial 1.0.0 — depo kökündeki
`LICENSE` ve `NOTICE` aynen korunur; yalnız kişisel, ticari olmayan kullanım. App Store'a yüklenmez.

Required Notice: Copyright 2026 Synthetify Labs spółka z ograniczoną odpowiedzialnością (OpenBot). Reis değişiklikleri: gokhangeo.

## Reis'e ait dosyalar (upstream'de yok)

| Yer | Ne |
|---|---|
| `apps/mobile/reis/reis.config.js` | Ad "Reis", paket `com.gokhan.asistan.RDYFR8KV2N` (eski Asistan'ın yerine kurulur), App Group `group.com.gokhan.asistan.RDYFR8KV2N`, Takım RDYFR8KV2N, telefon izinleri, `reis://` şeması, OpenBot OTA kapalı |
| `apps/mobile/reis/hazirla.sh` | Derlemeden önce (yalnız derleme makinesinde) App Group adını değiştirir |
| `apps/mobile/reis/kontrol-ekle.py`, `reis/kontrol/` | `expo prebuild` sonrası widget uzantısına Kontrol Merkezi düğmesi (iOS 18+) |
| `apps/mobile/modules/reis-telefon/` | Yerel Expo modülü (Swift): arama, SMS/WhatsApp taslağı, alarm/zamanlayıcı (AlarmKit), hatırlatıcı, takvim, uygulama açma/uygulamada arama, Spotify, yol tarifi |
| `apps/mobile/src/reis/` | Eylem kartı, güncelleme denetimi |
| `.github/workflows/reis-upstream.yml` | Her gün upstream main'i birleştirir; çakışmada durur ve PR açar |

## Upstream dosyalarındaki küçük kancalar

- `apps/mobile/app.config.js`: ayarları `reis/reis.config.js`'den geçirir (`REIS=0` ile OpenBot ayarlarıyla derlenir).
- `apps/mobile/src/features/chat/components/chat-markdown.tsx`: dili `reis` olan kod bloğu → eylem kartı.
- `apps/mobile/src/features/app-update/model/app-update.ts`: OpenBot'un üstteki güncelleme şeridi App Store yerine
  imzalı Reis sürümünü gösterir; "Güncelle" iOS kurulum penceresini açar; puanlama sorusu kapalı.
- `apps/mobile/src/app/+native-intent.tsx`: `reis://...` bağlantıları `openbot://...` gibi işlenir
  (ör. `reis://mobile-connect?...` ile sunucuya bağlanma).

## Ajanların telefon işi yaptırması (eylem kartı)

Ajan yanıtına dili `reis` olan bir kod bloğu koyar; Reis bunu dokunulabilir bir kart olarak gösterir,
kullanıcı dokununca işi telefonda yapar ve sonucu kartın altına yazar. OpenBot'un sunucusuna dokunmak gerekmez;
ajanın talimatına (Ayarlar → Ajan → Talimatlar) aşağıdaki metni eklemek yeter.

```text
Telefon işleri (Reis): Kullanıcı arama, SMS/WhatsApp, alarm, zamanlayıcı, hatırlatıcı, takvim, uygulama açma,
uygulamada arama, yol tarifi ya da müzik isterse, yanıtına dili "reis" olan bir kod bloğu koy; içinde tek satır JSON:
{"tur":"ara","kisi":"Ahmet"} · {"tur":"ara","numara":"05xx..."} ·
{"tur":"mesaj","kisi":"kızım","metin":"...","kanal":"sms|whatsapp"} ·
{"tur":"alarm","zaman":"YYYY-MM-DDTHH:MM","etiket":"..."} · {"tur":"zamanlayici","saniye":600,"etiket":"..."} ·
{"tur":"hatirlatici","metin":"...","zaman":"YYYY-MM-DDTHH:MM"} ·
{"tur":"etkinlik","baslik":"...","zaman":"YYYY-MM-DDTHH:MM","sure_dk":60,"yer":"..."} ·
{"tur":"takvim","gun":"YYYY-MM-DD"} · {"tur":"takvim_aralik","bas":"YYYY-MM-DD","son":"YYYY-MM-DD"} ·
{"tur":"ac","uygulama":"spotify"} · {"tur":"uygulamada_ara","uygulama":"youtube","sorgu":"..."} ·
{"tur":"yol","hedef":"...","ulasim":"araba|yuru|toplu"} · {"tur":"muzik","sorgu":"..."} · {"tur":"url","url":"https://..."}
Saatler Türkiye saatiyle. Kişiyi kullanıcının dediği gibi yaz ("kızım", "Ahmet"); Reis rehberden bulur, bulamazsa bir kez seçtirir.
Kartın yanına kısa bir cümle yaz; "telefonunuzdan kendiniz yapın" deme.
```

## Güncelleme

- `.github/workflows/reis-upstream.yml` her gün 06:00 (TSİ) upstream'i birleştirir.
- gokhangeo/rea'daki `reis-gunluk.yml` her gün 07:00 (TSİ) `apps/mobile` değiştiyse `reis/kaynak.txt`'i günceller;
  bu, Codemagic'te `reis-ios` derlemesini başlatır (günde en fazla 1).
- Codemagic Ad Hoc imzalar ve `gokhangeo/apk` deposunun `reis-imzali` dalına koyar
  (kurulum: https://gokhangeo.github.io/imzali/). Uygulama açılışta denetler, üstte "Güncelle" şeridi çıkar.

## Bilinen sınırlar

- Bildirimler ve canlı etkinlik push'u OpenBot'un kendi uygulama kimliğine bağlı; Reis'e sunucu push'u gelmez.
- Telefonda resmi OpenBot uygulaması da kuruluysa `openbot://` bağlantıları (widget, paylaşım) ona gidebilir.
