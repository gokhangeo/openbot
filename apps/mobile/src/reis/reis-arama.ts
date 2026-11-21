// Reis eklentisi: modules/reis-arama yerel modülünün JavaScript köprüsü (CallKit arama).
import { type NativeModule, requireOptionalNativeModule } from "expo";

interface ReisAramaModule extends NativeModule {
  startCall(callId: string, handle: string, displayName: string): Promise<boolean>;
  endCall(callId: string): void;
  addListener(eventName: string, listener: (event: any) => void): { remove: () => void };
}

/** iOS dışında (ve Expo Go'da) modül yoktur; o zaman null. */
export const reisArama = requireOptionalNativeModule<ReisAramaModule>("ReisArama");
