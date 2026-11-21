// Reis: OpenBot mobil uygulamasının Gökhan için kişisel derlemesi (gokhangeo/openbot fork'u).
// Upstream app.json'a dokunmadan adı, paket kimliklerini, App Group'u ve Reis'in telefon izinlerini değiştirir.
// Lisans: PolyForm Noncommercial 1.0.0 (kök LICENSE, NOTICE). Yalnız kişisel, ticari olmayan kullanım.

const TAKIM = "RDYFR8KV2N";
const PAKET = "com.gokhan.asistan.RDYFR8KV2N"; // eski Asistan'ın kimliği: telefonda onun yerine kurulur
const GRUP = `group.${PAKET}`;
const OPENBOT_PAKET = "run.openbot.mobile";
const OPENBOT_GRUP = `group.${OPENBOT_PAKET}`;

/** Eklenti ayarlarındaki OpenBot kimliklerini Reis'inkilerle değiştirir. */
function kimlikDegistir(deger) {
  if (typeof deger === "string") {
    if (deger === OPENBOT_GRUP) return GRUP;
    if (deger.startsWith(`${OPENBOT_PAKET}.`)) return PAKET + deger.slice(OPENBOT_PAKET.length);
    return deger;
  }
  if (Array.isArray(deger)) return deger.map(kimlikDegistir);
  if (deger && typeof deger === "object") {
    return Object.fromEntries(Object.entries(deger).map(([k, v]) => [k, kimlikDegistir(v)]));
  }
  return deger;
}

const IZINLER = {
  NSContactsUsageDescription:
    "“Kızımı ara” gibi isteklerde kişiyi rehberinizde bulmak için kullanılır; rehber sunucuya gönderilmez.",
  NSCalendarsFullAccessUsageDescription: "Takviminizi okumak ve sizin isteğinizle etkinlik eklemek için kullanılır.",
  NSCalendarsUsageDescription: "Takviminizi okumak ve sizin isteğinizle etkinlik eklemek için kullanılır.",
  NSRemindersFullAccessUsageDescription: "Sizin isteğinizle hatırlatıcı eklemek için kullanılır.",
  NSRemindersUsageDescription: "Sizin isteğinizle hatırlatıcı eklemek için kullanılır.",
  NSAlarmKitUsageDescription: "Sizin isteğinizle alarm ve zamanlayıcı kurmak için kullanılır.",
  NSMicrophoneUsageDescription: "Ajanla sesli arama yapmak için mikrofon kullanılır.",
};

const SEMALAR = [
  "whatsapp", "spotify", "instagram", "youtube", "tg", "fb", "twitter", "comgooglemaps", "googlegmail", "ms-outlook",
  "yandexnavi", "nflx", "googlechrome", "trendyol", "getir", "hepsiburada", "yemeksepeti", "openbot",
];

/** @param {import('expo/config').ExpoConfig} config */
module.exports = (config) => {
  const yapi = process.env.REIS_YAPI; // Codemagic derleme numarası (CFBundleVersion)
  const ios = config.ios ?? {};
  const { associatedDomains: _yok, ...iosKalan } = ios;
  return {
    ...config,
    name: "Reis",
    scheme: ["openbot", "reis"],
    ios: {
      ...iosKalan,
      bundleIdentifier: PAKET,
      appleTeamId: TAKIM,
      ...(yapi ? { buildNumber: String(yapi) } : {}),
      infoPlist: {
        ...ios.infoPlist,
        ...IZINLER,
        UIBackgroundModes: ["voip", "audio", "fetch"],
        LSApplicationQueriesSchemes: [...new Set([...(ios.infoPlist?.LSApplicationQueriesSchemes ?? []), ...SEMALAR])],
      },
    },
    plugins: kimlikDegistir(config.plugins ?? []),
    // OpenBot'un kendi OTA sunucusu bu derlemeye güncelleme göndermesin; güncelleme imzalı sürümle gelir.
    updates: { enabled: false, checkAutomatically: "NEVER" },
  };
};
