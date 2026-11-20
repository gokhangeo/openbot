// Reis eklentisi: ajan yanıtındaki ```reis {...}``` bloğunu dokunulabilir bir telefon eylemi kartı olarak gösterir.
// Protokol ve ajan talimatı: apps/mobile/reis/BENIOKU.md
import AlarmClock from "lucide-react-native/icons/alarm-clock";
import AppWindow from "lucide-react-native/icons/app-window";
import Bell from "lucide-react-native/icons/bell";
import Calendar from "lucide-react-native/icons/calendar";
import CalendarPlus from "lucide-react-native/icons/calendar-plus";
import Link from "lucide-react-native/icons/link";
import MessageCircle from "lucide-react-native/icons/message-circle";
import Music from "lucide-react-native/icons/music";
import Navigation from "lucide-react-native/icons/navigation";
import Phone from "lucide-react-native/icons/phone";
import Search from "lucide-react-native/icons/search";
import Timer from "lucide-react-native/icons/timer";
import { createContext, useContext, useEffect, useRef, useState } from "react";
import { ActivityIndicator, Linking, Pressable, Text, View } from "react-native";
import { reisTelefon } from "./reis-telefon";

type Eylem = Record<string, unknown> & { tur?: string };

function oku(metin: string): Eylem | null {
  try {
    const o = JSON.parse(metin.trim()) as unknown;
    if (o && typeof o === "object" && !Array.isArray(o)) return o as Eylem;
  } catch {}
  return null;
}

function s(e: Eylem, k: string): string {
  const v = e[k];
  return v === undefined || v === null ? "" : String(v);
}

function saat(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString("tr-TR", { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
}

function tanim(e: Eylem): { baslik: string; ayrinti: string; Simge: typeof Phone; dugme: string } {
  const tur = s(e, "tur").toLowerCase();
  switch (tur) {
    case "ara":
      return { baslik: `Ara: ${s(e, "kisi") || s(e, "numara")}`, ayrinti: s(e, "numara"), Simge: Phone, dugme: "Ara" };
    case "mesaj":
      return {
        baslik: `${s(e, "kanal").toLowerCase() === "whatsapp" ? "WhatsApp" : "SMS"}: ${s(e, "kisi") || s(e, "numara")}`,
        ayrinti: s(e, "metin"),
        Simge: MessageCircle,
        dugme: "Taslağı aç",
      };
    case "alarm":
      return { baslik: `Alarm: ${saat(s(e, "zaman"))}`, ayrinti: s(e, "etiket"), Simge: AlarmClock, dugme: "Kur" };
    case "zamanlayici": {
      const n = Number(s(e, "saniye"));
      const sure = n >= 3600 ? `${Math.floor(n / 3600)} sa ${Math.floor((n % 3600) / 60)} dk` : n >= 60 ? `${Math.floor(n / 60)} dk` : `${n} sn`;
      return { baslik: `Zamanlayıcı: ${sure}`, ayrinti: s(e, "etiket"), Simge: Timer, dugme: "Başlat" };
    }
    case "hatirlatici":
      return {
        baslik: `Hatırlatıcı: ${s(e, "metin")}`,
        ayrinti: s(e, "zaman") ? saat(s(e, "zaman")) : "",
        Simge: Bell,
        dugme: "Ekle",
      };
    case "etkinlik":
      return {
        baslik: `Takvime ekle: ${s(e, "baslik")}`,
        ayrinti: [saat(s(e, "zaman")), s(e, "yer")].filter(Boolean).join(" · "),
        Simge: CalendarPlus,
        dugme: "Ekle",
      };
    case "takvim":
    case "takvim_aralik":
      return {
        baslik: "Takvimi oku",
        ayrinti: tur === "takvim" ? s(e, "gun") || "bugün" : `${s(e, "bas")} – ${s(e, "son")}`,
        Simge: Calendar,
        dugme: "Göster",
      };
    case "ac":
      return { baslik: `Aç: ${s(e, "uygulama")}`, ayrinti: "", Simge: AppWindow, dugme: "Aç" };
    case "uygulamada_ara":
      return { baslik: `${s(e, "uygulama")}: “${s(e, "sorgu")}”`, ayrinti: "", Simge: Search, dugme: "Ara" };
    case "yol":
      return { baslik: `Yol tarifi: ${s(e, "hedef")}`, ayrinti: "", Simge: Navigation, dugme: "Başlat" };
    case "muzik":
      return { baslik: `Spotify: ${s(e, "sorgu") || "aç"}`, ayrinti: "", Simge: Music, dugme: "Çal" };
    default:
      return { baslik: s(e, "baslik") || "Bağlantı", ayrinti: s(e, "url"), Simge: Link, dugme: "Aç" };
  }
}

// Kartın içinde bulunduğu mesajın zamanı (chat-message-list sağlar). Yeni mesajdaki kart kendiliğinden çalışır.
export const ReisMesajZamani = createContext<string | undefined>(undefined);
const YENI_SAYILIR_MS = 2 * 60 * 1000;

function yeniMi(zaman: string | undefined): boolean {
  if (!zaman) return false;
  const t = Date.parse(zaman);
  return Number.isFinite(t) && Math.abs(Date.now() - t) < YENI_SAYILIR_MS;
}

// Bu oturumda kendiliğinden çalıştırılan bloklar (kart yeniden çizilince ikinci kez çalışmasın).
const calistirilanlar = new Set<string>();

export function ReisEylemKarti({ metin, renk, canli = false }: { metin: string; renk?: string; canli?: boolean }) {
  const [durum, setDurum] = useState<"bos" | "calisiyor" | "bitti">("bos");
  const [sonuc, setSonuc] = useState("");
  const eylem = oku(metin);
  // Yanıt ekranda akarken gelen kart kendiliğinden çalışır; eski sohbetlerdeki kartlar yalnız dokununca.
  const mesajZamani = useContext(ReisMesajZamani);
  const akarkenGoruldu = useRef(canli || !eylem || yeniMi(mesajZamani));
  if (canli || !eylem) akarkenGoruldu.current = true;
  const anahtar = `${mesajZamani ?? ""}|${metin.trim()}`;
  useEffect(() => {
    if (!eylem || !akarkenGoruldu.current || calistirilanlar.has(anahtar)) return;
    if (eylem.otomatik === false) return;
    calistirilanlar.add(anahtar);
    void yap();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [anahtar, Boolean(eylem)]);
  if (!eylem) {
    // Akış sürerken blok yarımdır; tamamlanınca kart görünür.
    return <Text style={{ color: renk, opacity: 0.6 }}>…</Text>;
  }
  const { baslik, ayrinti, Simge, dugme } = tanim(eylem);
  async function yap() {
    if (!eylem) return;
    if (durum === "calisiyor") return;
    setDurum("calisiyor");
    try {
      if (reisTelefon) {
        setSonuc(await reisTelefon.yap(JSON.stringify(eylem)));
      } else if (s(eylem, "url")) {
        await Linking.openURL(s(eylem, "url"));
        setSonuc("Açıldı Müdürüm.");
      } else {
        setSonuc("Bu telefon işi yalnız Reis iPhone uygulamasında çalışır.");
      }
    } catch (hata) {
      setSonuc(`Müdürüm, olmadı: ${hata instanceof Error ? hata.message : String(hata)}`);
    }
    setDurum("bitti");
  }
  return (
    <View
      style={{
        borderRadius: 16,
        borderWidth: 1,
        borderColor: "rgba(127,127,127,0.28)",
        backgroundColor: "rgba(127,127,127,0.10)",
        padding: 12,
        gap: 8,
        marginVertical: 4,
      }}
    >
      <View style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
        <Simge size={20} color={renk ?? "#888"} />
        <View style={{ flex: 1 }}>
          <Text style={{ color: renk, fontWeight: "600", fontSize: 15 }} numberOfLines={2}>
            {baslik}
          </Text>
          {ayrinti ? (
            <Text style={{ color: renk, opacity: 0.7, fontSize: 13 }} numberOfLines={3}>
              {ayrinti}
            </Text>
          ) : null}
        </View>
        <Pressable
          onPress={yap}
          accessibilityRole="button"
          style={({ pressed }) => ({
            backgroundColor: "#6960F1",
            borderRadius: 999,
            paddingHorizontal: 14,
            paddingVertical: 8,
            opacity: pressed ? 0.7 : 1,
          })}
        >
          {durum === "calisiyor" ? (
            <ActivityIndicator size="small" color="#fff" />
          ) : (
            <Text style={{ color: "#fff", fontWeight: "600" }}>{durum === "bitti" ? "Tekrar" : dugme}</Text>
          )}
        </Pressable>
      </View>
      {sonuc ? <Text style={{ color: renk, fontSize: 14 }}>{sonuc}</Text> : null}
    </View>
  );
}
