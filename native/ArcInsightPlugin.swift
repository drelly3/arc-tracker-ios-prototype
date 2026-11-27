import Foundation
import Capacitor
#if canImport(FoundationModels)
import FoundationModels
#endif

// Spike: on-device weekly insight. Compile proof only. No network, no accounts.
@objc(ArcInsightPlugin)
public class ArcInsightPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ArcInsightPlugin"
    public let jsName = "ArcInsight"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "availability", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "weeklyInsight", returnType: CAPPluginReturnPromise)
    ]

    private func report(_ status: String, _ call: CAPPluginCall) {
        NSLog("ArcInsight availability=%@ canImportFoundationModels=%@", status, Self.compiledWithFoundationModels ? "yes" : "no")
        call.resolve(["status": status])
    }

    #if canImport(FoundationModels)
    static let compiledWithFoundationModels = true
    #else
    static let compiledWithFoundationModels = false
    #endif

    @objc func availability(_ call: CAPPluginCall) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                report("available", call)
            case .unavailable(.deviceNotEligible):
                report("deviceNotEligible", call)
            case .unavailable(.modelNotReady):
                report("modelNotReady", call)
            case .unavailable:
                report("unavailable", call)
            }
            return
        }
        #endif
        report("unsupported", call)
    }

    @objc func weeklyInsight(_ call: CAPPluginCall) {
        guard let summary = call.getString("summary"), !summary.isEmpty else {
            call.reject("summary required")
            return
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                call.reject("model unavailable")
                return
            }
            Task {
                do {
                    let session = LanguageModelSession(instructions: """
                    You write a short, kind weekly habit insight (max 3 sentences) using only the habit summary given. \
                    Do not give medical, health, financial or other factual advice. Do not invent data.
                    """)
                    let response = try await session.respond(to: summary)
                    call.resolve(["text": response.content])
                } catch {
                    call.reject("generation failed")
                }
            }
            return
        }
        #endif
        call.reject("unsupported")
    }
}

// Registers the plugin with the bridge (the app has no other native code).
class ArcBridgeViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(ArcInsightPlugin())
    }
}
