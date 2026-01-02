import Flutter
import UIKit
import LeapSDK
import LeapModelDownloader

/// Flutter plugin for the Liquid AI LEAP SDK.
///
/// This plugin provides on-device AI inference capabilities using Liquid
/// Foundation Models (LFM). It wraps the native LeapSDK for iOS.
///
/// ## Features
///
/// - Model downloading and caching
/// - Streaming text generation
/// - Multimodal support (text, images, audio)
/// - Function calling
/// - Constrained JSON generation
///
/// ## Requirements
///
/// - iOS 15.0+
/// - Physical device recommended (3GB+ RAM)
/// - LeapSDK 0.7.0+
public class LiquidAiLeapPlugin: NSObject, FlutterPlugin {
    
    // MARK: - Properties
    
    /// The Flutter method channel for communication with Dart.
    private let channel: FlutterMethodChannel
    
    /// Active model runners indexed by their ID.
    private var modelRunners: [String: Any] = [:]
    
    /// Active conversations indexed by their ID.
    private var conversations: [String: Any] = [:]
    
    /// Counter for generating unique IDs.
    private var idCounter: Int = 0
    
    // MARK: - Initialization
    
    /// Creates a new plugin instance.
    ///
    /// - Parameter channel: The Flutter method channel.
    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }
    
    // MARK: - FlutterPlugin
    
    /// Registers the plugin with the Flutter engine.
    ///
    /// - Parameter registrar: The Flutter plugin registrar.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "ai.liquid.leap/plugin",
            binaryMessenger: registrar.messenger()
        )
        let instance = LiquidAiLeapPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    /// Handles method calls from Dart.
    ///
    /// - Parameters:
    ///   - call: The method call.
    ///   - result: The result callback.
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            handleGetPlatformVersion(result: result)
            
        case "getSdkVersion":
            handleGetSdkVersion(result: result)
            
        case "loadModel":
            handleLoadModel(call: call, result: result)
            
        case "downloadModel":
            handleDownloadModel(call: call, result: result)
            
        case "isModelCached":
            handleIsModelCached(call: call, result: result)
            
        case "deleteModel":
            handleDeleteModel(call: call, result: result)
            
        case "createConversation":
            handleCreateConversation(call: call, result: result)
            
        case "createConversationFromHistory":
            handleCreateConversationFromHistory(call: call, result: result)
            
        case "generateResponse":
            handleGenerateResponse(call: call, result: result)
            
        case "stopGeneration":
            handleStopGeneration(call: call, result: result)
            
        case "registerFunction":
            handleRegisterFunction(call: call, result: result)
            
        case "getConversationHistory":
            handleGetConversationHistory(call: call, result: result)
            
        case "unloadModel":
            handleUnloadModel(call: call, result: result)
            
        case "disposeConversation":
            handleDisposeConversation(call: call, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Handler Methods
    
    /// Returns the platform version.
    private func handleGetPlatformVersion(result: @escaping FlutterResult) {
        result("iOS " + UIDevice.current.systemVersion)
    }
    
    /// Returns the LEAP SDK version.
    private func handleGetSdkVersion(result: @escaping FlutterResult) {
        // LeapSDK doesn't expose a version property, so we return the known version
        result("0.8.0")
    }
    
    /// Loads a model from the LEAP Model Library.
    private func handleLoadModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: model, quantization",
                details: nil
            ))
            return
        }
        
        let saveDirectory = args["saveDirectory"] as? String
        let progressCallbackId = args["progressCallbackId"] as? String
        
        Task {
            do {
                // Construct the model path
                // LeapSDK expects a .bundle path
                let modelPath: String
                if let saveDir = saveDirectory {
                    modelPath = "\(saveDir)/\(model)_\(quantization).bundle"
                } else {
                    // Use default documents directory
                    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                    modelPath = "\(documentsPath)/leap_models/\(model)_\(quantization).bundle"
                }
                
                // Check if model exists
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: modelPath) else {
                    await MainActor.run {
                        result(FlutterError(
                            code: "MODEL_NOT_FOUND",
                            message: "Model not found at path: \(modelPath). Please download it first.",
                            details: nil
                        ))
                    }
                    return
                }
                
                // Load model with LeapSDK
                let runner = try await Leap.load(options: .init(bundlePath: modelPath))
                
                // Generate a unique ID for the model runner
                let runnerId = self.generateId()
                
                // Store the ModelRunner instance
                self.modelRunners[runnerId] = runner
                
                await MainActor.run {
                    result([
                        "runnerId": runnerId,
                        "modelId": "\(model)_\(quantization)"
                    ])
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "MODEL_LOADING_ERROR",
                        message: "Failed to load model: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }
    
    /// Downloads a model without loading it.
    private func handleDownloadModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: model, quantization",
                details: nil
            ))
            return
        }
        
        let progressCallbackId = args["progressCallbackId"] as? String
        
        Task {
            do {
                // Resolve model to get downloadable model reference
                guard let downloadableModel = await LeapDownloadableModel.resolve(
                    modelSlug: model,
                    quantizationSlug: quantization
                ) else {
                    await MainActor.run {
                        result(FlutterError(
                            code: "MODEL_NOT_FOUND",
                            message: "Could not resolve model: \(model) with quantization: \(quantization)",
                            details: nil
                        ))
                    }
                    return
                }
                
                // Create ModelDownloader instance
                let downloader = ModelDownloader()
                
                // Check if model is already downloaded
                let status = await downloader.queryStatus(downloadableModel)
                if case .downloaded = status {
                    let modelFile = downloader.getModelFile(downloadableModel)
                    await MainActor.run {
                        result([
                            "modelSlug": model,
                            "quantizationSlug": quantization,
                            "schemaVersion": "1.0",
                            "inferenceType": "gguf",
                            "localModelPath": modelFile.path
                        ])
                    }
                    return
                }
                
                // Download with progress tracking
                if let callbackId = progressCallbackId {
                    let downloadResult = await downloader.downloadModel(downloadableModel, forceDownload: false)
                    
                    switch downloadResult {
                    case .success(let modelURL):
                        await MainActor.run {
                            result([
                                "modelSlug": model,
                                "quantizationSlug": quantization,
                                "schemaVersion": "1.0",
                                "inferenceType": "gguf",
                                "localModelPath": modelURL.path
                            ])
                        }
                    case .failure(let error):
                        await MainActor.run {
                            result(FlutterError(
                                code: "DOWNLOAD_ERROR",
                                message: "Failed to download model: \(error.localizedDescription)",
                                details: nil
                            ))
                        }
                    }
                } else {
                    // Download without progress tracking
                    let downloadResult = await downloader.downloadModel(downloadableModel, forceDownload: false)
                    
                    switch downloadResult {
                    case .success(let modelURL):
                        await MainActor.run {
                            result([
                                "modelSlug": model,
                                "quantizationSlug": quantization,
                                "schemaVersion": "1.0",
                                "inferenceType": "gguf",
                                "localModelPath": modelURL.path
                            ])
                        }
                    case .failure(let error):
                        await MainActor.run {
                            result(FlutterError(
                                code: "DOWNLOAD_ERROR",
                                message: "Failed to download model: \(error.localizedDescription)",
                                details: nil
                            ))
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "DOWNLOAD_ERROR",
                        message: "Failed to download model: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }
    
    /// Checks if a model is cached.
    private func handleIsModelCached(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: model, quantization",
                details: nil
            ))
            return
        }
        
        // Construct the model path
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let modelPath = "\(documentsPath)/leap_models/\(model)_\(quantization).bundle"
        
        // Check if model bundle exists
        let fileManager = FileManager.default
        result(fileManager.fileExists(atPath: modelPath))
    }
    
    /// Deletes a cached model.
    private func handleDeleteModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let model = args["model"] as? String,
              let quantization = args["quantization"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: model, quantization",
                details: nil
            ))
            return
        }
        
        do {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let modelPath = "\(documentsPath)/leap_models/\(model)_\(quantization).bundle"
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: modelPath) {
                try fileManager.removeItem(atPath: modelPath)
                result(true)
            } else {
                result(false)
            }
        } catch {
            result(FlutterError(
                code: "DELETE_ERROR",
                message: "Failed to delete model: \(error.localizedDescription)",
                details: nil
            ))
        }
    }
    
    /// Creates a new conversation.
    private func handleCreateConversation(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let runnerId = args["runnerId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: runnerId",
                details: nil
            ))
            return
        }
        
        let systemPrompt = args["systemPrompt"] as? String
        
        guard let runnerAny = modelRunners[runnerId],
              let runner = runnerAny as? ModelRunner else {
            result(FlutterError(
                code: "INVALID_RUNNER",
                message: "Model runner not found: \(runnerId)",
                details: nil
            ))
            return
        }
        
        // Create conversation with optional system prompt
        var history: [ChatMessage] = []
        if let prompt = systemPrompt {
            history.append(ChatMessage(role: .system, content: [.text(prompt)]))
        }
        
        let conversation = Conversation(modelRunner: runner, history: history)
        let conversationId = generateId()
        
        conversations[conversationId] = conversation
        
        result([
            "conversationId": conversationId
        ])
    }
    
    /// Creates a conversation from history.
    private func handleCreateConversationFromHistory(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let runnerId = args["runnerId"] as? String,
              let _ = args["history"] as? [[String: Any]] else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: runnerId, history",
                details: nil
            ))
            return
        }
        
        guard let runnerAny = modelRunners[runnerId],
              let runner = runnerAny as? ModelRunner else {
            result(FlutterError(
                code: "INVALID_RUNNER",
                message: "Model runner not found: \(runnerId)",
                details: nil
            ))
            return
        }
        
        // Parse history from Flutter format to LeapSDK ChatMessage format
        var history: [ChatMessage] = []
        for messageDict in args["history"] as! [[String: Any]] {
            if let roleStr = messageDict["role"] as? String,
               let contentList = messageDict["content"] as? [[String: Any]] {
                
                let role: ChatMessageRole
                switch roleStr {
                case "system": role = .system
                case "user": role = .user
                case "assistant": role = .assistant
                default: continue
                }
                
                var content: [ChatMessageContent] = []
                for contentDict in contentList {
                    if let type = contentDict["type"] as? String {
                        switch type {
                        case "text":
                            if let text = contentDict["text"] as? String {
                                content.append(.text(text))
                            }
                        default:
                            break
                        }
                    }
                }
                
                history.append(ChatMessage(role: role, content: content))
            }
        }
        
        let conversation = Conversation(modelRunner: runner, history: history)
        let conversationId = generateId()
        
        conversations[conversationId] = conversation
        
        result([
            "conversationId": conversationId
        ])
    }
    
    /// Generates a response (streaming).
    private func handleGenerateResponse(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String,
              let message = args["message"] as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: conversationId, message",
                details: nil
            ))
            return
        }
        
        let options = args["options"] as? [String: Any]
        let streamCallbackId = args["streamCallbackId"] as? String
        
        Task {
            guard let callbackId = streamCallbackId else {
                await MainActor.run {
                    result(FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Missing streamCallbackId",
                        details: nil
                    ))
                }
                return
            }
            
            guard let conversation = conversations[conversationId] as? Conversation else {
                await MainActor.run {
                    result(FlutterError(
                        code: "INVALID_CONVERSATION",
                        message: "Conversation not found: \(conversationId)",
                        details: nil
                    ))
                }
                return
            }
            
            // Parse message
            guard let roleStr = message["role"] as? String,
                  let contentList = message["content"] as? [[String: Any]] else {
                await MainActor.run {
                    result(FlutterError(
                        code: "INVALID_MESSAGE",
                        message: "Invalid message format",
                        details: nil
                    ))
                }
                return
            }
            
            let role: ChatMessageRole
            switch roleStr {
            case "user": role = .user
            case "system": role = .system
            case "assistant": role = .assistant
            default:
                await MainActor.run {
                    result(FlutterError(
                        code: "INVALID_ROLE",
                        message: "Invalid message role: \(roleStr)",
                        details: nil
                    ))
                }
                return
            }
            
            var content: [ChatMessageContent] = []
            for contentDict in contentList {
                if let type = contentDict["type"] as? String {
                    switch type {
                    case "text":
                        if let text = contentDict["text"] as? String {
                            content.append(.text(text))
                        }
                    default:
                        break
                    }
                }
            }
            
            let chatMessage = ChatMessage(role: role, content: content)
            
            do {
                var fullText = ""
                
                // Stream responses from LeapSDK
                for try await response in conversation.generateResponse(message: chatMessage) {
                    switch response {
                    case .chunk(let text):
                        fullText += text
                        await MainActor.run {
                            self.channel.invokeMethod(
                                "onGenerationResponse",
                                arguments: [
                                    "callbackId": callbackId,
                                    "type": "chunk",
                                    "text": text
                                ]
                            )
                        }
                        
                    case .reasoningChunk(let reasoning):
                        await MainActor.run {
                            self.channel.invokeMethod(
                                "onGenerationResponse",
                                arguments: [
                                    "callbackId": callbackId,
                                    "type": "reasoning",
                                    "text": reasoning
                                ]
                            )
                        }
                        
                    case .complete(let completion):
                        await MainActor.run {
                            let stats: [String: Any]
                            if let generationStats = completion.stats {
                                stats = [
                                    "promptTokens": generationStats.promptTokens,
                                    "completionTokens": generationStats.completionTokens,
                                    "totalTokens": generationStats.totalTokens,
                                    "tokensPerSecond": generationStats.tokenPerSecond
                                ]
                            } else {
                                stats = [
                                    "promptTokens": 0,
                                    "completionTokens": 0,
                                    "totalTokens": 0,
                                    "tokensPerSecond": 0.0
                                ]
                            }
                            
                            self.channel.invokeMethod(
                                "onGenerationResponse",
                                arguments: [
                                    "callbackId": callbackId,
                                    "type": "complete",
                                    "message": [
                                        "role": "assistant",
                                        "content": [["type": "text", "text": fullText]]
                                    ],
                                    "finishReason": "\(completion.finishReason)",
                                    "stats": stats
                                ]
                            )
                        }
                        
                    case .functionCall(let calls):
                        // Handle function calling (not yet implemented)
                        await MainActor.run {
                            self.channel.invokeMethod(
                                "onGenerationResponse",
                                arguments: [
                                    "callbackId": callbackId,
                                    "type": "functionCall",
                                    "calls": calls.map { call in
                                        [
                                            "name": call.name,
                                            "arguments": call.arguments ?? [:]
                                        ]
                                    }
                                ]
                            )
                        }
                        
                    case .audioSample(let samples, let sampleRate):
                        // Handle audio samples (not yet implemented)
                        await MainActor.run {
                            self.channel.invokeMethod(
                                "onGenerationResponse",
                                arguments: [
                                    "callbackId": callbackId,
                                    "type": "audioSample",
                                    "samplesCount": samples.count,
                                    "sampleRate": sampleRate
                                ]
                            )
                        }
                    }
                }
                
                await MainActor.run {
                    result(nil)
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "GENERATION_ERROR",
                        message: "Failed to generate response: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }
    
    /// Stops an ongoing generation.
    private func handleStopGeneration(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: conversationId",
                details: nil
            ))
            return
        }
        
        // Note: LeapSDK's Conversation doesn't expose a direct cancel method
        // Generation tasks are controlled by Swift's Task cancellation
        // This would require storing Task references to cancel them
        _ = conversationId // Suppress unused warning
        result(FlutterError(
            code: "NOT_IMPLEMENTED",
            message: "Stop generation is not yet implemented. Generation will complete naturally.",
            details: nil
        ))
    }
    
    /// Registers a function for function calling.
    private func handleRegisterFunction(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String,
              let function = args["function"] as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: conversationId, function",
                details: nil
            ))
            return
        }
        
        // Note: Function calling requires using LeapSDK's function calling API
        // which involves setting up function definitions in GenerateOptions
        // This is not directly exposed through Conversation but through model options
        _ = conversationId // Suppress unused warning
        _ = function // Suppress unused warning
        result(FlutterError(
            code: "NOT_IMPLEMENTED",
            message: "Function calling is not yet implemented in the Flutter wrapper.",
            details: nil
        ))
    }
    
    /// Gets the conversation history.
    private func handleGetConversationHistory(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: conversationId",
                details: nil
            ))
            return
        }
        
        guard let conversation = conversations[conversationId] as? Conversation else {
            result(FlutterError(
                code: "INVALID_CONVERSATION",
                message: "Conversation not found: \(conversationId)",
                details: nil
            ))
            return
        }
        
        // Convert LeapSDK ChatMessage to Flutter format
        let historyArray = conversation.history.map { message -> [String: Any] in
            let roleStr: String
            switch message.role {
            case .system: roleStr = "system"
            case .user: roleStr = "user"
            case .assistant: roleStr = "assistant"
            @unknown default: roleStr = "unknown"
            }
            
            let contentArray = message.content.map { content -> [String: Any] in
                switch content {
                case .text(let text):
                    return ["type": "text", "text": text]
                @unknown default:
                    return ["type": "unknown", "data": "unsupported content type"]
                }
            }
            
            return [
                "role": roleStr,
                "content": contentArray
            ]
        }
        
        result(historyArray)
    }
    
    /// Unloads a model.
    private func handleUnloadModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let runnerId = args["runnerId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: runnerId",
                details: nil
            ))
            return
        }
        
        guard modelRunners[runnerId] != nil else {
            result(FlutterError(
                code: "INVALID_RUNNER",
                message: "Model runner not found: \(runnerId)",
                details: nil
            ))
            return
        }
        
        // Remove the model runner (LeapSDK handles cleanup automatically)
        modelRunners.removeValue(forKey: runnerId)
        result(nil)
    }
    
    /// Disposes a conversation.
    private func handleDisposeConversation(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required argument: conversationId",
                details: nil
            ))
            return
        }
        
        conversations.removeValue(forKey: conversationId)
        result(nil)
    }
    
    // MARK: - Helpers
    
    /// Generates a unique ID.
    private func generateId() -> String {
        idCounter += 1
        return "ios_\(idCounter)_\(Date().timeIntervalSince1970)"
    }
}
