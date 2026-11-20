#!/usr/bin/env python3
"""Reis: Kontrol Merkezi (ve kilit ekranı / Eylem tuşu) düğmesini widget uzantısına ekler.
"expo prebuild"dan SONRA çalışır: expo-widgets'ın ürettiği ios/ExpoWidgetsTarget/index.swift dosyasına
reis/kontrol/ReisKontrol.swift içeriğini ekler ve WidgetBundle'a ReisKontrolu'nu koyar (iOS 18+).
Kullanım: python3 reis/kontrol-ekle.py ios"""
import pathlib, sys

ios = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "ios")
hedef = ios / "ExpoWidgetsTarget" / "index.swift"
kaynak = pathlib.Path(__file__).parent / "kontrol" / "ReisKontrol.swift"
s = hedef.read_text()
if "ReisKontrolu" in s:
    print("Zaten ekli"); sys.exit(0)
eski = "WidgetLiveActivity()"
if s.count(eski) != 1:
    sys.exit("index.swift beklenen biçimde değil (WidgetLiveActivity() bulunamadı)")
s = s.replace(eski, eski + "\n    if #available(iOS 18.0, *) {\n      ReisKontrolu()\n    }", 1)
s = "import AppIntents\n" + s + "\n\n" + kaynak.read_text()
hedef.write_text(s)
print("Kontrol Merkezi düğmesi eklendi:", hedef)
