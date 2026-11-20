import Contacts
import ContactsUI
import EventKit
import ExpoModulesCore
import Foundation
import MessageUI
import SwiftUI
import UIKit
#if canImport(AlarmKit)
import AlarmKit
#endif

// Reis eklentisi (gokhangeo/openbot fork'u; upstream dosyası değil).
// Ajanlar yanıtlarına ```reis {"tur": "...", ...}``` bloğu koyar; uygulama onu "eylem kartı" olarak gösterir,
// kullanıcı dokununca iş burada yapılır ve kısa sonuç metni döner. Protokol: apps/mobile/reis/BENIOKU.md
// Eski Asistan uygulamasının (gokhangeo/rea asistan-ios/App/Eylemler.swift) telefon işlerinin taşınmış hâli.

public class ReisTelefonModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ReisTelefon")

    /// Bir eylemi yapar. `json`: {"tur": "ara", "kisi": "Ahmet"} gibi. Kullanıcıya gösterilecek sonucu döndürür.
    AsyncFunction("yap") { (json: String) async -> String in
      await ReisYurutucu.yap(json: json)
    }

    /// Bilinen uygulama adları (ac / uygulamada_ara için).
    Function("uygulamalar") { () -> [String] in
      Array(ReisUygulamalar.semalar.keys).sorted()
    }
  }
}

// MARK: - Yürütücü

@MainActor
enum ReisYurutucu {
  static let magaza = EKEventStore()

  static func yap(json: String) async -> String {
    guard let d = json.data(using: .utf8),
          let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
          let tur = (o["tur"] as? String)?.lowercased() else {
      return "Müdürüm, eylem anlaşılamadı."
    }
    func s(_ k: String) -> String {
      if let v = o[k] as? String { return v.trimmingCharacters(in: .whitespacesAndNewlines) }
      if let v = o[k] { return "\(v)" }
      return ""
    }
    switch tur {
    case "ara":
      return await ara(kisi: s("kisi"), numara: s("numara"))
    case "mesaj":
      return await mesaj(kisi: s("kisi"), numara: s("numara"), metin: s("metin"), whatsapp: s("kanal").lowercased() == "whatsapp")
    case "alarm":
      guard let t = ReisTarih.iso(s("zaman")) else { return "Müdürüm, alarm saati anlaşılamadı." }
      return await ReisAlarm.kur(tarih: t, etiket: s("etiket").isEmpty ? "Alarm" : s("etiket"))
    case "zamanlayici":
      guard let n = Int(s("saniye")), n > 0 else { return "Müdürüm, süre anlaşılamadı." }
      let r = await ReisAlarm.kur(tarih: Date().addingTimeInterval(TimeInterval(n)), etiket: s("etiket").isEmpty ? "Süre doldu" : s("etiket"))
      return r.hasPrefix("Alarm kuruldu") ? "Zamanlayıcı kuruldu Müdürüm: \(sureMetni(n)) sonra çalacak." : r
    case "hatirlatici":
      guard !s("metin").isEmpty else { return "Müdürüm, hatırlatıcı metni boş." }
      return await hatirlatici(metin: s("metin"), tarih: ReisTarih.iso(s("zaman")))
    case "etkinlik":
      guard let t = ReisTarih.iso(s("zaman")), !s("baslik").isEmpty else { return "Müdürüm, etkinlik bilgisi eksik." }
      return await etkinlik(baslik: s("baslik"), bas: t, sureDk: Int(s("sure_dk")) ?? 60, yer: s("yer"))
    case "takvim":
      let gun = ReisTarih.gun(s("gun")) ?? Date()
      let cal = Calendar.current
      let bas = cal.startOfDay(for: gun)
      let ad = cal.isDateInToday(gun) ? "Bugün" : (cal.isDateInTomorrow(gun) ? "Yarın" : ReisTarih.gunMetni(gun))
      return await takvimOzet(bas: bas, son: cal.date(byAdding: .day, value: 1, to: bas)!, ad: ad)
    case "takvim_aralik":
      guard let b = ReisTarih.gun(s("bas")), let e = ReisTarih.gun(s("son")) else { return "Müdürüm, tarih aralığı anlaşılamadı." }
      return await takvimOzet(bas: b, son: Calendar.current.date(byAdding: .day, value: 1, to: e)!, ad: "Bu aralıkta")
    case "ac":
      return await ac(ad: s("uygulama"))
    case "uygulamada_ara":
      return await uygulamadaAra(ad: s("uygulama"), sorgu: s("sorgu"))
    case "yol":
      return await yol(hedef: s("hedef"), ulasim: s("ulasim"))
    case "muzik":
      return await muzik(sorgu: s("sorgu"), uri: s("uri"))
    case "url", "baglanti":
      guard let u = URL(string: s("url")), await UIApplication.shared.open(u) else { return "Müdürüm, bağlantı açılamadı." }
      return "Açıldı Müdürüm."
    default:
      return "Müdürüm, \"\(tur)\" türünde bir telefon işi tanımıyorum."
    }
  }

  // MARK: Arama ve mesaj

  static func ara(kisi: String, numara: String) async -> String {
    var ad = kisi
    var n = numara.filter { $0.isNumber || $0 == "+" }
    if n.isEmpty {
      guard !kisi.isEmpty, let k = await ReisRehber.kisi(kisi) else { return "Müdürüm, \(kisi) rehberde bulamadım." }
      guard let kn = k.numara else { return "Müdürüm, \(k.ad) için kayıtlı numara yok." }
      ad = k.ad; n = kn
    }
    guard let u = URL(string: "tel://\(n)"), await UIApplication.shared.open(u) else { return "Müdürüm, arama başlatılamadı." }
    return "\(ad.isEmpty ? n : ad) aranıyor Müdürüm."
  }

  static func mesaj(kisi: String, numara: String, metin: String, whatsapp: Bool) async -> String {
    var ad = kisi
    var n = numara.filter { $0.isNumber || $0 == "+" }
    if n.isEmpty {
      guard !kisi.isEmpty, let k = await ReisRehber.kisi(kisi), let kn = k.numara else { return "Müdürüm, \(kisi) rehberde bulamadım." }
      ad = k.ad; n = kn
    }
    if whatsapp {
      var rakam = n.filter(\.isNumber)
      if rakam.hasPrefix("0") { rakam = "9" + rakam }
      if rakam.count == 10 { rakam = "90" + rakam }
      let q = metin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
      if let u = URL(string: "whatsapp://send?phone=\(rakam)&text=\(q)"), await UIApplication.shared.open(u) {
        return "WhatsApp'ta \(ad) için mesaj hazır, göndermek için dokunun Müdürüm."
      }
      return "Müdürüm, WhatsApp açılamadı."
    }
    return await ReisMesajYazici.ac(numara: n, metin: metin)
      ? "\(ad) için mesaj hazır; Gönder'e basmanız yeterli Müdürüm."
      : "Müdürüm, bu cihazdan SMS hazırlanamıyor."
  }

  // MARK: Hatırlatıcı ve takvim

  static func hatirlatici(metin: String, tarih: Date?) async -> String {
    do {
      guard try await magaza.requestFullAccessToReminders() else { return izinYok("Hatırlatıcılar") }
      let h = EKReminder(eventStore: magaza)
      h.title = metin
      h.calendar = magaza.defaultCalendarForNewReminders()
      if let tarih {
        h.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: tarih)
        h.addAlarm(EKAlarm(absoluteDate: tarih))
      }
      try magaza.save(h, commit: true)
      return tarih.map { "Hatırlatıcı eklendi Müdürüm: \(ReisTarih.saatMetni($0)) — \(metin)" } ?? "Hatırlatıcı eklendi Müdürüm: \(metin)"
    } catch {
      return "Müdürüm, hatırlatıcı eklenemedi: \(error.localizedDescription)"
    }
  }

  static func etkinlik(baslik: String, bas: Date, sureDk: Int, yer: String) async -> String {
    do {
      guard try await magaza.requestFullAccessToEvents() else { return izinYok("Takvim") }
      let ev = EKEvent(eventStore: magaza)
      ev.title = baslik
      ev.startDate = bas
      ev.endDate = bas.addingTimeInterval(TimeInterval(max(sureDk, 15) * 60))
      if !yer.isEmpty { ev.location = yer }
      ev.calendar = magaza.defaultCalendarForNewEvents
      ev.addAlarm(EKAlarm(relativeOffset: -15 * 60))
      try magaza.save(ev, span: .thisEvent, commit: true)
      return "Takvime eklendi Müdürüm: \(ReisTarih.saatMetni(bas)) — \(baslik)"
    } catch {
      return "Müdürüm, etkinlik eklenemedi: \(error.localizedDescription)"
    }
  }

  static func takvimOzet(bas: Date, son: Date, ad: String) async -> String {
    do {
      guard try await magaza.requestFullAccessToEvents() else { return izinYok("Takvim") }
    } catch {
      return "Müdürüm, takvim izni alınamadı."
    }
    let olaylar = magaza.events(matching: magaza.predicateForEvents(withStart: bas, end: son, calendars: nil))
      .sorted { $0.startDate < $1.startDate }
    if olaylar.isEmpty { return "\(ad) takviminiz boş Müdürüm." }
    let gf = DateFormatter()
    gf.locale = Locale(identifier: "tr_TR")
    gf.dateFormat = "d MMMM EEEE"
    let sf = DateFormatter()
    sf.dateFormat = "HH:mm"
    var satirlar: [String] = []
    var sonGun = ""
    let tekGun = (Calendar.current.dateComponents([.day], from: bas, to: son).day ?? 1) <= 1
    for o in olaylar.prefix(40) {
      let g = gf.string(from: o.startDate)
      if !tekGun && g != sonGun { satirlar.append("\n\(g)"); sonGun = g }
      let saat = o.isAllDay ? "Tüm gün" : sf.string(from: o.startDate)
      let yer = o.location ?? ""
      satirlar.append("• \(saat) \(o.title ?? "Etkinlik")" + (yer.isEmpty ? "" : " (\(yer))"))
    }
    let fazla = olaylar.count > 40 ? "\n…ve \(olaylar.count - 40) etkinlik daha." : ""
    return "\(ad) \(olaylar.count) etkinlik var Müdürüm:\n" + satirlar.joined(separator: "\n") + fazla
  }

  // MARK: Uygulama, yol, müzik

  static func ac(ad: String) async -> String {
    let anahtar = ReisUygulamalar.eslestir(ad) ?? ad.lowercased(with: Locale(identifier: "tr_TR"))
    let goster = anahtar.capitalized(with: Locale(identifier: "tr_TR"))
    if let s = ReisUygulamalar.semalar[anahtar], let u = URL(string: s), await UIApplication.shared.open(u) {
      return "\(goster) açıldı Müdürüm."
    }
    if let w = ReisUygulamalar.web[anahtar], let u = URL(string: w), await UIApplication.shared.open(u) {
      return "\(goster) açıldı Müdürüm."
    }
    return "Müdürüm, \(goster) açılamadı; telefonda kurulu olmayabilir."
  }

  static func uygulamadaAra(ad: String, sorgu: String) async -> String {
    let anahtar = ReisUygulamalar.eslestir(ad) ?? ad.lowercased(with: Locale(identifier: "tr_TR"))
    let goster = anahtar.capitalized(with: Locale(identifier: "tr_TR"))
    for adres in ReisUygulamalar.aramaAdresleri(anahtar, sorgu) {
      if let u = URL(string: adres), await UIApplication.shared.open(u) {
        return "\(goster)'da \"\(sorgu)\" arandı Müdürüm."
      }
    }
    return "Müdürüm, \(goster) içinde arama açılamadı."
  }

  static func yol(hedef: String, ulasim: String) async -> String {
    guard !hedef.isEmpty else { return "Müdürüm, hedef boş." }
    let q = hedef.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let kip: String
    switch ulasim.lowercased() {
    case "yuru", "yürü", "yurume", "yürüme", "w": kip = "w"
    case "toplu", "r", "otobus", "otobüs": kip = "r"
    default: kip = "d"
    }
    if let u = URL(string: "maps://?daddr=\(q)&dirflg=\(kip)"), await UIApplication.shared.open(u) {
      return "\(hedef) için yol tarifi açıldı Müdürüm."
    }
    return "Müdürüm, Haritalar açılamadı."
  }

  static func muzik(sorgu: String, uri: String) async -> String {
    if !uri.isEmpty, let u = URL(string: uri), await UIApplication.shared.open(u) {
      return "Spotify'da açıldı Müdürüm."
    }
    let q = sorgu.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
    let hedef = sorgu.isEmpty ? "spotify://" : "spotify:search:\(q)"
    if let u = URL(string: hedef), await UIApplication.shared.open(u) {
      return sorgu.isEmpty ? "Spotify açıldı Müdürüm." : "Spotify'da \"\(sorgu)\" açıldı Müdürüm."
    }
    if let u = URL(string: "music://"), await UIApplication.shared.open(u) { return "Spotify yok, Apple Müzik açıldı Müdürüm." }
    return "Müdürüm, müzik uygulaması açılamadı."
  }

  static func izinYok(_ ad: String) -> String {
    "Müdürüm, \(ad) izni kapalı. Ayarlar → Reis → \(ad) bölümünden tam erişim verirseniz hemen yaparım."
  }

  static func sureMetni(_ sn: Int) -> String {
    if sn >= 3600 { return "\(sn / 3600) saat" + (sn % 3600 >= 60 ? " \((sn % 3600) / 60) dakika" : "") }
    if sn >= 60 { return "\(sn / 60) dakika" + (sn % 60 > 0 ? " \(sn % 60) saniye" : "") }
    return "\(sn) saniye"
  }
}

// MARK: - Tarih

enum ReisTarih {
  static func iso(_ s: String) -> Date? {
    guard !s.isEmpty else { return nil }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    for k in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mmXXXXX"] {
      f.dateFormat = k
      if let d = f.date(from: s) { return d }
    }
    return nil
  }

  static func gun(_ s: String) -> Date? {
    guard !s.isEmpty else { return nil }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: s)
  }

  static func gunMetni(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "tr_TR")
    f.dateFormat = "d MMMM EEEE"
    return f.string(from: d)
  }

  static func saatMetni(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "tr_TR")
    let cal = Calendar.current
    f.dateFormat = cal.isDateInToday(d) ? "'bugün' HH:mm" : (cal.isDateInTomorrow(d) ? "'yarın' HH:mm" : "d MMMM EEEE HH:mm")
    return f.string(from: d)
  }
}

// MARK: - Alarm (iOS 26+ AlarmKit; eskisinde hatırlatıcı)

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct ReisAlarmVerisi: AlarmMetadata {}
#endif

@MainActor
enum ReisAlarm {
  static func kur(tarih: Date, etiket: String) async -> String {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      do {
        let yonetici = AlarmManager.shared
        var durum = yonetici.authorizationState
        if durum == .notDetermined { durum = try await yonetici.requestAuthorization() }
        if durum == .authorized {
          let uyari = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: etiket),
            stopButton: AlarmButton(text: "Durdur", textColor: .white, systemImageName: "stop.circle.fill"))
          let nitelik = AlarmAttributes<ReisAlarmVerisi>(
            presentation: AlarmPresentation(alert: uyari), metadata: ReisAlarmVerisi(), tintColor: .orange)
          let ayar = AlarmManager.AlarmConfiguration<ReisAlarmVerisi>(
            countdownDuration: nil, schedule: .fixed(tarih), attributes: nitelik,
            stopIntent: nil, secondaryIntent: nil, sound: .default)
          _ = try await yonetici.schedule(id: UUID(), configuration: ayar)
          return "Alarm kuruldu Müdürüm: \(ReisTarih.saatMetni(tarih))."
        }
      } catch {
        // hatırlatıcıya düş
      }
    }
    #endif
    let r = await ReisYurutucu.hatirlatici(metin: "⏰ \(etiket)", tarih: tarih)
    return r.hasPrefix("Hatırlatıcı eklendi") ? "Alarm kuruldu Müdürüm (hatırlatıcı olarak): \(ReisTarih.saatMetni(tarih))." : r
  }
}

// MARK: - Rehber

struct ReisKisi {
  let ad: String
  let numara: String?
}

@MainActor
enum ReisRehber {
  static let depo = CNContactStore()
  private static let anahtar = "reisKisiTakmaAdlari"

  static var takmaAdlar: [String: String] {
    get { UserDefaults.standard.dictionary(forKey: anahtar) as? [String: String] ?? [:] }
    set { UserDefaults.standard.set(newValue, forKey: anahtar) }
  }

  static let akrabalik = ["kızım", "oğlum", "eşim", "karım", "kocam", "annem", "babam", "ablam", "abim", "kardeşim",
                          "anneannem", "babaannem", "dedem", "teyzem", "halam", "dayım", "amcam", "patronum", "müdürüm"]

  static func kisi(_ ham: String) async -> ReisKisi? {
    do {
      guard try await depo.requestAccess(for: .contacts) else { return nil }
    } catch {
      return nil
    }
    let tr = Locale(identifier: "tr_TR")
    var ad = ham.lowercased(with: tr).replacingOccurrences(of: "’", with: "'")
    if let i = ad.firstIndex(of: "'") { ad = String(ad[..<i]) }
    ad = ad.trimmingCharacters(in: .whitespaces)
    var adaylar = [ad]
    for ek in ["yı", "yi", "yu", "yü", "ı", "i", "u", "ü", "ya", "ye", "a", "e", "la", "le", "yla", "yle"]
    where ad.hasSuffix(ek) && ad.count > ek.count + 2 {
      adaylar.append(String(ad.dropLast(ek.count)))
    }
    let anahtarlar: [CNKeyDescriptor] = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey,
                                         CNContactPhoneNumbersKey, CNContactOrganizationNameKey] as [CNKeyDescriptor]
      + [CNContactFormatter.descriptorForRequiredKeys(for: .fullName)]
    for a in adaylar {
      if let id = takmaAdlar[a], let c = try? depo.unifiedContact(withIdentifier: id, keysToFetch: anahtarlar) {
        return donustur(c)
      }
    }
    for a in adaylar where !akrabalik.contains(a) {
      if let c = ara(a, anahtarlar) { return donustur(c) }
    }
    // Bulunamadı ya da "kızım" gibi bir yakınlık: bir kez seçtir, sonra hep hatırla.
    guard let secilen = await ReisKisiSecici.sec() else { return nil }
    var t = takmaAdlar
    t[adaylar.last ?? ad] = secilen.identifier
    t[ad] = secilen.identifier
    takmaAdlar = t
    let c = (try? depo.unifiedContact(withIdentifier: secilen.identifier, keysToFetch: anahtarlar)) ?? secilen
    return donustur(c)
  }

  private static func ara(_ ad: String, _ anahtarlar: [CNKeyDescriptor]) -> CNContact? {
    guard let liste = try? depo.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: ad), keysToFetch: anahtarlar),
          !liste.isEmpty else { return nil }
    let tr = Locale(identifier: "tr_TR")
    return liste.first { ($0.givenName + " " + $0.familyName).lowercased(with: tr).hasPrefix(ad) } ?? liste.first
  }

  private static func donustur(_ c: CNContact) -> ReisKisi {
    let ad = CNContactFormatter.string(from: c, style: .fullName) ?? c.nickname
    let cep = c.phoneNumbers.first { ($0.label ?? "").lowercased().contains("mobile") || ($0.label ?? "").contains("iPhone") }
      ?? c.phoneNumbers.first
    let n = cep?.value.stringValue.filter { $0.isNumber || $0 == "+" }
    return ReisKisi(ad: ad.isEmpty ? "Kişi" : ad, numara: (n?.isEmpty ?? true) ? nil : n)
  }
}

// MARK: - UIKit köprüleri

@MainActor
enum ReisUstEkran {
  static func bul() -> UIViewController? {
    let sahneler = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let pencere = sahneler.flatMap(\.windows).first { $0.isKeyWindow } ?? sahneler.first?.windows.first
    var vc = pencere?.rootViewController
    while let p = vc?.presentedViewController { vc = p }
    return vc
  }
}

@MainActor
final class ReisKisiSecici: NSObject, CNContactPickerDelegate {
  private var devam: CheckedContinuation<CNContact?, Never>?
  private static var etkin: ReisKisiSecici?

  static func sec() async -> CNContact? {
    guard let ust = ReisUstEkran.bul() else { return nil }
    let s = ReisKisiSecici()
    etkin = s
    return await withCheckedContinuation { c in
      s.devam = c
      let p = CNContactPickerViewController()
      p.delegate = s
      p.displayedPropertyKeys = [CNContactPhoneNumbersKey]
      p.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
      ust.present(p, animated: true)
    }
  }

  nonisolated func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
    Task { @MainActor in self.bitir(contact) }
  }

  nonisolated func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    Task { @MainActor in self.bitir(nil) }
  }

  private func bitir(_ c: CNContact?) {
    devam?.resume(returning: c)
    devam = nil
    ReisKisiSecici.etkin = nil
  }
}

@MainActor
final class ReisMesajYazici: NSObject, MFMessageComposeViewControllerDelegate {
  private static var etkin: ReisMesajYazici?

  static func ac(numara: String, metin: String) async -> Bool {
    guard MFMessageComposeViewController.canSendText(), let ust = ReisUstEkran.bul() else {
      let q = metin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
      if let u = URL(string: "sms:\(numara)&body=\(q)") { return await UIApplication.shared.open(u) }
      return false
    }
    let y = ReisMesajYazici()
    etkin = y
    let vc = MFMessageComposeViewController()
    vc.recipients = [numara]
    vc.body = metin
    vc.messageComposeDelegate = y
    ust.present(vc, animated: true)
    return true
  }

  nonisolated func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    Task { @MainActor in
      controller.dismiss(animated: true)
      ReisMesajYazici.etkin = nil
    }
  }
}

// MARK: - Uygulamalar

enum ReisUygulamalar {
  static let semalar: [String: String] = [
    "whatsapp": "whatsapp://", "spotify": "spotify://", "instagram": "instagram://", "youtube": "youtube://",
    "telegram": "tg://", "facebook": "fb://", "twitter": "twitter://", "x": "twitter://", "tiktok": "snssdk1233://",
    "gmail": "googlegmail://", "outlook": "ms-outlook://", "haritalar": "maps://", "harita": "maps://",
    "google haritalar": "comgooglemaps://", "google maps": "comgooglemaps://", "yandex": "yandexnavi://",
    "yandex navigasyon": "yandexnavi://", "netflix": "nflx://", "chrome": "googlechrome://", "safari": "https://www.google.com",
    "müzik": "music://", "apple müzik": "music://", "takvim": "calshow://", "notlar": "mobilenotes://",
    "mail": "message://", "posta": "message://", "mesajlar": "sms:", "fotoğraflar": "photos-redirect://",
    "app store": "itms-apps://", "hatırlatıcılar": "x-apple-reminderkit://", "trendyol": "trendyol://",
    "getir": "getir://", "hepsiburada": "hepsiburada://", "yemeksepeti": "yemeksepeti://", "uber": "uber://",
    "bitaksi": "bitaksi://", "linkedin": "linkedin://", "pinterest": "pinterest://", "snapchat": "snapchat://",
    "discord": "discord://", "zoom": "zoomus://", "teams": "msteams://", "github": "github://",
    "chatgpt": "chatgpt://", "claude": "claude://", "shazam": "shazam://", "kısayollar": "shortcuts://",
    "dosyalar": "shareddocuments://", "ayarlar": "app-settings:", "e-devlet": "edevlet://",
    "edevlet": "edevlet://", "papara": "papara://", "enpara": "enpara://", "iş bankası": "isbank://",
    "işcep": "isbank://", "vakıfbank": "vakifbank://", "qnb": "qnbfinansbank://", "hark": "hark://",
    "google takvim": "googlecalendar://", "google calendar": "googlecalendar://", "google": "google://",
    "kamera": "camera://", "saat": "clock-alarm://", "hesap makinesi": "calc://", "telefon": "mobilephone://",
    "rehber": "contacts://", "sahibinden": "sahibinden://", "n11": "n11://", "amazon": "com.amazon.mobile.shopping://",
    "marti": "marti://", "turkcell": "turkcell://", "ziraat": "ziraatmobil://", "garanti": "garantibbva://",
    "akbank": "akbank://", "yapı kredi": "yapikredi://", "mhrs": "mhrs://", "trendyol yemek": "trendyolgo://",
    "openbot": "openbot://",
  ]

  static let web: [String: String] = [
    "trendyol": "https://www.trendyol.com", "gmail": "https://mail.google.com", "instagram": "https://www.instagram.com",
    "youtube": "https://www.youtube.com", "facebook": "https://www.facebook.com", "twitter": "https://x.com", "x": "https://x.com",
    "tiktok": "https://www.tiktok.com", "hepsiburada": "https://www.hepsiburada.com", "getir": "https://getir.com",
    "yemeksepeti": "https://www.yemeksepeti.com", "linkedin": "https://www.linkedin.com", "spotify": "https://open.spotify.com",
    "netflix": "https://www.netflix.com", "github": "https://github.com", "chatgpt": "https://chatgpt.com",
    "claude": "https://claude.ai", "google takvim": "https://calendar.google.com", "google calendar": "https://calendar.google.com",
    "outlook": "https://outlook.live.com", "sahibinden": "https://www.sahibinden.com", "n11": "https://www.n11.com",
    "amazon": "https://www.amazon.com.tr", "e-devlet": "https://www.turkiye.gov.tr", "edevlet": "https://www.turkiye.gov.tr",
    "google": "https://www.google.com", "pinterest": "https://www.pinterest.com", "telegram": "https://web.telegram.org",
    "whatsapp": "https://web.whatsapp.com", "mhrs": "https://www.mhrs.gov.tr",
  ]

  static func eslestir(_ ad: String) -> String? {
    let a = ad.lowercased(with: Locale(identifier: "tr_TR")).trimmingCharacters(in: .whitespaces)
    if a.isEmpty { return nil }
    if semalar[a] != nil { return a }
    for ek in ["ı", "i", "u", "ü", "yı", "yi", "yu", "yü", "'ı", "'i", "'u", "'ü"] where a.hasSuffix(ek) {
      let k = String(a.dropLast(ek.count))
      if semalar[k] != nil { return k }
    }
    if let k = semalar.keys.first(where: { a.hasPrefix($0 + " ") }) { return k }
    return nil
  }

  static func aramaAdresleri(_ ad: String, _ sorgu: String) -> [String] {
    let q = sorgu.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sorgu
    let k = sorgu.replacingOccurrences(of: " ", with: "").lowercased()
    switch ad {
    case "instagram": return ["instagram://user?username=\(k)", "https://www.instagram.com/explore/search/keyword/?q=\(q)"]
    case "youtube": return ["youtube://results?search_query=\(q)", "https://www.youtube.com/results?search_query=\(q)"]
    case "spotify": return ["spotify:search:\(q)"]
    case "trendyol": return ["https://www.trendyol.com/sr?q=\(q)"]
    case "hepsiburada": return ["https://www.hepsiburada.com/ara?q=\(q)"]
    case "twitter", "x": return ["twitter://search?query=\(q)", "https://x.com/search?q=\(q)"]
    case "tiktok": return ["https://www.tiktok.com/search?q=\(q)"]
    case "amazon": return ["https://www.amazon.com.tr/s?k=\(q)"]
    case "n11": return ["https://www.n11.com/arama?q=\(q)"]
    case "sahibinden": return ["https://www.sahibinden.com/arama?query_text=\(q)"]
    case "github": return ["https://github.com/search?q=\(q)"]
    case "haritalar", "harita": return ["maps://?q=\(q)"]
    case "google haritalar", "google maps": return ["comgooglemaps://?q=\(q)", "https://www.google.com/maps/search/\(q)"]
    case "pinterest": return ["https://www.pinterest.com/search/pins/?q=\(q)"]
    case "app store": return ["itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=\(q)"]
    case "netflix": return ["https://www.netflix.com/search?q=\(q)"]
    case "linkedin": return ["https://www.linkedin.com/search/results/all/?keywords=\(q)"]
    default: return ["https://www.google.com/search?q=\(q)"]
    }
  }
}
