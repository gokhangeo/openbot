// Reis: Kontrol Merkezi / kilit ekranı / Eylem tuşu düğmesi (iOS 18+). Reis'i açar.
// reis/kontrol-ekle.py bu dosyayı widget uzantısının index.swift'ine ekler.

@available(iOS 18.0, *)
struct ReisAcNiyeti: AppIntent {
  static var title: LocalizedStringResource = "Reis'i aç"
  static var description = IntentDescription("Reis'i açar.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult & OpensIntent {
    .result(opensIntent: OpenURLIntent(URL(string: "reis://")!))
  }
}

@available(iOS 18.0, *)
struct ReisKontrolu: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "com.gokhan.reis.ac") {
      ControlWidgetButton(action: ReisAcNiyeti()) {
        Label("Reis", systemImage: "bubble.left.and.bubble.right.fill")
      }
    }
    .displayName("Reis")
    .description("Reis'i açar.")
  }
}
