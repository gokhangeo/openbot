// Reis eklentisi: imzalı (Ad Hoc) sürüm güncellemesi.
// Codemagic her derlemede gokhangeo/apk deposunun "reis-imzali" dalına Reis.ipa, Reis.plist ve surum.json koyar.
// Uygulama açılışta ve öne gelince surum.json'u okur; yapı numarası telefondakinden büyükse OpenBot'un
// üstteki güncelleme şeridi "Güncelle" ile bu sürümü gösterir, dokununca iOS kurulum penceresi açılır.
import { useQuery } from "@tanstack/react-query";
import * as Application from "expo-application";
import { Linking } from "react-native";

export const REIS_SURUM_ADRESI = "https://raw.githubusercontent.com/gokhangeo/apk/reis-imzali/surum.json";
export const REIS_SAYFA = "https://gokhangeo.github.io/imzali/";

export interface ReisSurum {
  surum: string;
  yapi: number;
  manifest: string;
  notlar?: string;
}

let sonManifest: string | null = null;

async function surumOku(): Promise<ReisSurum | null> {
  const yanit = await fetch(`${REIS_SURUM_ADRESI}?t=${Date.now()}`, { cache: "no-store" });
  if (!yanit.ok) return null;
  const j = (await yanit.json()) as { surum?: string; yapi?: string | number; manifest?: string; notlar?: string };
  const yapi = Number(j.yapi);
  if (!j.manifest || !Number.isFinite(yapi)) return null;
  return { surum: String(j.surum ?? yapi), yapi, manifest: j.manifest, notlar: j.notlar };
}

/** Telefondaki yapı numarası (CFBundleVersion). */
export function reisYapi(): number {
  const n = Number(Application.nativeBuildVersion);
  return Number.isFinite(n) ? n : 0;
}

/** Yeni Reis sürümü varsa onu döndürür (açılışta ve her 30 dakikada bir denetlenir). */
export function useReisGuncelleme(): ReisSurum | null {
  const { data } = useQuery({
    queryKey: ["reis", "surum"],
    queryFn: surumOku,
    staleTime: 30 * 60_000,
    refetchInterval: 30 * 60_000,
    refetchOnWindowFocus: true,
    retry: 1,
  });
  if (!data || data.yapi <= reisYapi()) return null;
  sonManifest = data.manifest;
  return data;
}

/** iOS kurulum penceresini açar (itms-services). Bilinen bir sürüm yoksa kurulum sayfasını açar. */
export async function reisKur(): Promise<void> {
  if (sonManifest) {
    await Linking.openURL(`itms-services://?action=download-manifest&url=${encodeURIComponent(sonManifest)}`);
    return;
  }
  await Linking.openURL(REIS_SAYFA);
}
