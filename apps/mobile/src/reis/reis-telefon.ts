// Reis eklentisi: modules/reis-telefon yerel modülünün JavaScript köprüsü.
import { type NativeModule, requireOptionalNativeModule } from "expo";

interface ReisTelefonModule extends NativeModule {
  yap(json: string): Promise<string>;
  uygulamalar(): string[];
}

/** iOS dışında (ve Expo Go'da) modül yoktur; o zaman null. */
export const reisTelefon = requireOptionalNativeModule<ReisTelefonModule>("ReisTelefon");
