import AVFoundation
import CallKit
import ExpoModulesCore
import Foundation

public class ReisAramaModule: Module {
  private var provider: CXProvider?
  private var controller: CXCallController?
  private var currentCall: UUID?
  private var startedAt: Date?

  public func definition() -> ModuleDefinition {
    Name("ReisArama")

    Events("onCallStarted", "onCallEnded", "onCallFailed")

    AsyncFunction("startCall") { (callId: String, handle: String, displayName: String) async -> Bool in
      await MainActor.run { self.baslat(callId: callId, handle: handle, displayName: displayName) }
    }

    AsyncFunction("endCall") { (callId: String) async in
      await MainActor.run { self.bitir(callId: callId) }
    }
  }

  @MainActor
  private func baslat(callId: String, handle: String, displayName: String) {
    let uuid = UUID(uuidString: callId) ?? UUID()
    currentCall = uuid
    startedAt = Date()

    if provider == nil {
      let yapilandirma = CXProviderConfiguration(localizedName: "Reis")
      yapilandirma.supportsVideo = false
      yapilandirma.maximumCallGroups = 1
      yapilandirma.maximumCallsPerCallGroup = 1
      yapilandirma.supportedHandleTypes = [.generic]
      let p = CXProvider(configuration: yapilandirma)
      p.setDelegate(self, queue: nil)
      provider = p
      controller = CXCallController()
    }

    let islem = CXStartCallAction(call: uuid, handle: CXHandle(type: .generic, value: handle.isEmpty ? displayName : handle))
    islem.isVideo = false
    let islemKaydi = CXTransaction(action: islem)
    controller?.request(islemKaydi) { [weak self] hata in
      Task { @MainActor in
        guard let self else { return }
        if let hata {
          self.sendEvent("onCallFailed", ["callId": callId, "error": hata.localizedDescription])
          return
        }
        self.provider?.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
        self.provider?.reportOutgoingCall(with: uuid, connectedAt: Date())
        self.sendEvent("onCallStarted", ["callId": callId])
      }
    }
  }

  @MainActor
  private func bitir(callId: String) {
    guard let uuid = currentCall else { return }
    let islem = CXEndCallAction(call: uuid)
    controller?.request(CXTransaction(action: islem)) { _ in }
  }

  @MainActor
  fileprivate func cagriBitti(uuid: UUID) {
    let sure = startedAt.map { Date().timeIntervalSince($0) } ?? 0
    if uuid == currentCall {
      currentCall = nil
      startedAt = nil
    }
    sendEvent("onCallEnded", ["callId": uuid.uuidString, "duration": sure])
  }
}

extension ReisAramaModule: CXProviderDelegate {
  public func providerDidReset(_ provider: CXProvider) {}

  public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    let oturum = AVAudioSession.sharedInstance()
    do {
      try oturum.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
      try oturum.setActive(true)
    } catch {}
    action.fulfill()
  }

  public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {}

  public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}

  public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    action.fulfill()
    Task { @MainActor in
      self.cagriBitti(uuid: action.callUUID)
    }
  }

  public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
    action.fulfill()
  }

  public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    action.fulfill()
  }
}
