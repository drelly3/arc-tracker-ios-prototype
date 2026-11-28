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
    You are a practical habit coach. Write 2 short, plain sentences (3 only if you add a sentence on the real pattern). \
    Sentence 1: one specific tactic that makes a listed habit easier to start or keep, for example tie it to something the person already does every day, shrink it to a two-minute version, set it out the night before, or pick one fixed place and time. Do not just repeat the habit back to them. \
    Sentence 2: one short reason that tactic helps. \
    If the data shows completions, you may open with one sentence on the real pattern, using only the numbers given. If no completions are recorded, say nothing about progress or history. \
    The habits listed are the person's real habits: never say they have not set a habit or goal. Never invent data, times or dates about the person. \
    Do not give medical, health, financial or other factual advice. Never shame the person. Keep their habits and Main Quests as they wrote them.
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
                NSLog("ArcInsight generate rejected: model not available")
                call.reject("model unavailable")
                return
            }
            Task {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: summary)
                    call.resolve(["text": response.content])
                } catch {
                    // Diagnostic only: error type and message, never the prompt or response.
                    let ns = error as NSError
                    NSLog("ArcInsight generation error domain=%@ code=%ld", ns.domain, ns.code)
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
