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
        CAPPluginMethod(name: "weeklyInsight", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "coachNote", returnType: CAPPluginReturnPromise)
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

    private static let weeklyInstructions = """
    You write a short, kind weekly habit insight (max 3 sentences) using only the habit summary given. \
    Do not give medical, health, financial or other factual advice. Do not invent data.
    """

    private static let coachInstructions = """
    You are a supportive habit coach. From the habits and goals given, write at most 3 short sentences: \
    one specific, practical suggestion the person may not have thought of, tied to one named goal or habit from the data. \
    Use only the data given. Do not give medical, health, financial or other factual advice. Do not invent data or numbers. \
    Never shame the person. If there are no goals, suggest one small adjustment to a habit.
    """

    @objc func weeklyInsight(_ call: CAPPluginCall) { generate(call, Self.weeklyInstructions) }

    @objc func coachNote(_ call: CAPPluginCall) { generate(call, Self.coachInstructions) }

    private func generate(_ call: CAPPluginCall, _ instructions: String) {
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
                    let session = LanguageModelSession(instructions: instructions)
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
        NSLog("ArcInsight bridge view controller loaded, registering plugin")
        bridge?.registerPluginInstance(ArcInsightPlugin())
    }
}
