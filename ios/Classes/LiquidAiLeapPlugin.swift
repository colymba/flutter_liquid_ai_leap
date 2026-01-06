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
    
    /// Registered functions indexed by conversation ID.
    private var registeredFunctions: [String: [LeapFunction]] = [:]
    
    /// Active generation tasks indexed by conversation ID.
    private var generationTasks: [String: Task<Void, Never>] = [:]
    
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
                let modelPath: String
                if let saveDir = saveDirectory {
                    modelPath = "\(saveDir)/\(model)/\(quantization)"
                } else {
                    // Use default documents directory
                    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                    modelPath = "\(documentsPath)/leap_models/\(model)/\(quantization)"
                }
                
                // Look for model file (.bundle or .gguf) and optional projector
                let fileManager = FileManager.default
                var modelURL: URL? = nil
                var projectorURL: URL? = nil
                
                // Check if path exists as directory
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: modelPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        // Look for .bundle or .gguf files in directory
                        if let contents = try? fileManager.contentsOfDirectory(atPath: modelPath) {
                            var ggufFiles: [String] = []
                            
                            for file in contents {
                                if file.hasSuffix(".bundle") {
                                    modelURL = URL(fileURLWithPath: modelPath).appendingPathComponent(file)
                                    break
                                } else if file.hasSuffix(".gguf") {
                                    ggufFiles.append(file)
                                }
                            }
                            
                            // If no bundle found, process .gguf files
                            if modelURL == nil && !ggufFiles.isEmpty {
                                // Separate main model from projector files
                                let mainFiles = ggufFiles.filter { !$0.lowercased().contains("mmproj") }
                                let projectorFiles = ggufFiles.filter { $0.lowercased().contains("mmproj") }
                                
                                // Pick main model (largest if multiple)
                                if !mainFiles.isEmpty {
                                    let mainFile = mainFiles.max { f1, f2 in
                                        let url1 = URL(fileURLWithPath: modelPath).appendingPathComponent(f1)
                                        let url2 = URL(fileURLWithPath: modelPath).appendingPathComponent(f2)
                                        let size1 = (try? fileManager.attributesOfItem(atPath: url1.path)[.size] as? Int64) ?? 0
                                        let size2 = (try? fileManager.attributesOfItem(atPath: url2.path)[.size] as? Int64) ?? 0
                                        return size1 < size2
                                    }
                                    if let mainFile = mainFile {
                                        modelURL = URL(fileURLWithPath: modelPath).appendingPathComponent(mainFile)
                                    }
                                } else if !ggufFiles.isEmpty {
                                    // Fallback to largest .gguf
                                    modelURL = URL(fileURLWithPath: modelPath).appendingPathComponent(ggufFiles[0])
                                }
                                
                                // Pick projector file if available (usually only one)
                                if !projectorFiles.isEmpty {
                                    projectorURL = URL(fileURLWithPath: modelPath).appendingPathComponent(projectorFiles[0])
                                }
                            }
                        }
                        // If no bundle/gguf found, use directory itself
                        if modelURL == nil {
                            modelURL = URL(fileURLWithPath: modelPath)
                        }
                    } else {
                        // Path is a file
                        modelURL = URL(fileURLWithPath: modelPath)
                    }
                }
                
                // Also check for direct .bundle path
                let bundlePath = "\(modelPath).bundle"
                if modelURL == nil && fileManager.fileExists(atPath: bundlePath) {
                    modelURL = URL(fileURLWithPath: bundlePath)
                }
                
                guard let finalModelURL = modelURL, fileManager.fileExists(atPath: finalModelURL.path) else {
                    await MainActor.run {
                        result(FlutterError(
                            code: "MODEL_NOT_FOUND",
                            message: "Model not found at path: \(modelPath). Please download it first.",
                            details: nil
                        ))
                    }
                    return
                }
                
                // Load model with LeapSDK using URL-based API with optional projector
                let runner: Any
                if let projectorURL = projectorURL {
                    runner = try await Leap.load(url: finalModelURL, multimodalProjectorURL: projectorURL)
                } else {
                    runner = try await Leap.load(url: finalModelURL)
                }
                
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
        let directUrl = args["url"] as? String
        let saveDirectory = args["saveDirectory"] as? String
        
        Task {
            // First try to resolve from Leap Model Library
            if let downloadableModel = await LeapDownloadableModel.resolve(
                modelSlug: model,
                quantizationSlug: quantization
            ) {
                await downloadViaLeapModelLibrary(
                    downloadableModel: downloadableModel,
                    model: model,
                    quantization: quantization,
                    progressCallbackId: progressCallbackId,
                    result: result
                )
            } else if let url = directUrl, let downloadURL = URL(string: url) {
                // Fallback to direct URL download for VL models
                await downloadViaDirectUrl(
                    url: downloadURL,
                    model: model,
                    quantization: quantization,
                    saveDirectory: saveDirectory,
                    progressCallbackId: progressCallbackId,
                    result: result
                )
            } else {
                await MainActor.run {
                    result(FlutterError(
                        code: "MODEL_NOT_FOUND",
                        message: "Model '\(model)' with quantization '\(quantization)' not found in Leap Model Library. For VL models, provide a direct download URL.",
                        details: nil
                    ))
                }
            }
        }
    }
    
    /// Downloads a model using the LeapModelDownloader from the SDK.
    private func downloadViaLeapModelLibrary(
        downloadableModel: LeapDownloadableModel,
        model: String,
        quantization: String,
        progressCallbackId: String?,
        result: @escaping FlutterResult
    ) async {
        do {
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
                        "localModelPath": modelFile.path,
                        "modelPath": modelFile.path
                    ])
                }
                return
            }
            
            // Download the model
            let downloadResult = await downloader.downloadModel(downloadableModel, forceDownload: false)
            
            switch downloadResult {
            case .success(let modelURL):
                await MainActor.run {
                    result([
                        "modelSlug": model,
                        "quantizationSlug": quantization,
                        "schemaVersion": "1.0",
                        "inferenceType": "gguf",
                        "localModelPath": modelURL.path,
                        "modelPath": modelURL.path
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
    
    /// Downloads a model directly from a URL (e.g., HuggingFace).
    /// Used for VL models and other models not in the Leap Model Library.
    private func downloadViaDirectUrl(
        url: URL,
        model: String,
        quantization: String,
        saveDirectory: String?,
        progressCallbackId: String?,
        result: @escaping FlutterResult
    ) async {
        do {
            // Determine save path
            let fileManager = FileManager.default
            let baseDir: URL
            if let saveDir = saveDirectory {
                baseDir = URL(fileURLWithPath: saveDir)
            } else {
                let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                baseDir = documentsDir.appendingPathComponent("leap_models")
            }
            
            // Create model directory - use model/quantization structure to match loadModel
            let modelDir = baseDir.appendingPathComponent(model).appendingPathComponent(quantization)
            try? fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true)
            
            // Determine filename from URL
            var fileName = url.lastPathComponent
            if let queryIndex = fileName.firstIndex(of: "?") {
                fileName = String(fileName[..<queryIndex])
            }
            if fileName.isEmpty {
                fileName = "\(model)_\(quantization).bundle"
            }
            let outputFile = modelDir.appendingPathComponent(fileName)
            
            // Skip if already downloaded
            if fileManager.fileExists(atPath: outputFile.path) {
                let attrs = try? fileManager.attributesOfItem(atPath: outputFile.path)
                if let fileSize = attrs?[.size] as? Int64, fileSize > 0 {
                    if let callbackId = progressCallbackId {
                        await MainActor.run {
                            self.channel.invokeMethod("onDownloadProgress", arguments: [
                                "callbackId": callbackId,
                                "progress": 1.0,
                                "bytesPerSecond": 0
                            ])
                        }
                    }
                    
                    await MainActor.run {
                        result([
                            "modelSlug": model,
                            "quantizationSlug": quantization,
                            "schemaVersion": "1.0",
                            "inferenceType": "bundle",
                            "localModelPath": outputFile.path,
                            "modelPath": outputFile.path
                        ])
                    }
                    return
                }
            }
            
            // Download the file
            var request = URLRequest(url: url)
            request.setValue("LiquidAI-Leap-Flutter/1.0", forHTTPHeaderField: "User-Agent")
            
            let (tempURL, response) = try await URLSession.shared.download(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    result(FlutterError(
                        code: "DOWNLOAD_ERROR",
                        message: "Failed to download from URL: HTTP error",
                        details: nil
                    ))
                }
                return
            }
            
            // Move temp file to final location
            if fileManager.fileExists(atPath: outputFile.path) {
                try? fileManager.removeItem(at: outputFile)
            }
            try fileManager.moveItem(at: tempURL, to: outputFile)
            
            // Final progress update
            if let callbackId = progressCallbackId {
                await MainActor.run {
                    self.channel.invokeMethod("onDownloadProgress", arguments: [
                        "callbackId": callbackId,
                        "progress": 1.0,
                        "bytesPerSecond": 0
                    ])
                }
            }
            
            await MainActor.run {
                result([
                    "modelSlug": model,
                    "quantizationSlug": quantization,
                    "schemaVersion": "1.0",
                    "inferenceType": "bundle",
                    "localModelPath": outputFile.path,
                    "modelPath": outputFile.path
                ])
            }
        } catch {
            await MainActor.run {
                result(FlutterError(
                    code: "DOWNLOAD_ERROR",
                    message: "Failed to download from URL: \(error.localizedDescription)",
                    details: nil
                ))
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
                case "tool": role = .tool
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
        
        // Cancel any existing generation for this conversation
        generationTasks[conversationId]?.cancel()
        
        let task = Task {
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
            case "tool": role = .tool
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
            
            // Build generation options
            var generationOptions = GenerationOptions()
            
            // Parse additional options if provided
            if let optionsDict = options {
                if let temperature = optionsDict["temperature"] as? Double {
                    generationOptions.temperature = Float(temperature)
                }
                if let topP = optionsDict["topP"] as? Double {
                    generationOptions.topP = Float(topP)
                }
                if let minP = optionsDict["minP"] as? Double {
                    generationOptions.minP = Float(minP)
                }
                if let repetitionPenalty = optionsDict["repetitionPenalty"] as? Double {
                    generationOptions.repetitionPenalty = Float(repetitionPenalty)
                }
            }
            
            do {
                var fullText = ""
                
                // Stream responses from LeapSDK
                let responseStream = conversation.generateResponse(
                    message: chatMessage,
                    generationOptions: generationOptions
                )
                
                for try await response in responseStream {
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
            } catch is CancellationError {
                // Generation was cancelled - this is expected
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
            
            // Clean up task reference
            await MainActor.run {
                self.generationTasks.removeValue(forKey: conversationId)
            }
        }
        
        // Store the task for potential cancellation
        generationTasks[conversationId] = task
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
        
        // Cancel the generation task if it exists
        if let task = generationTasks[conversationId] {
            task.cancel()
            generationTasks.removeValue(forKey: conversationId)
        }
        
        result(nil)
    }
    
    /// Registers a function for function calling.
    private func handleRegisterFunction(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let conversationId = args["conversationId"] as? String,
              let functionDict = args["function"] as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments: conversationId, function",
                details: nil
            ))
            return
        }
        
        // Verify conversation exists
        guard conversations[conversationId] != nil else {
            result(FlutterError(
                code: "INVALID_CONVERSATION",
                message: "Conversation not found: \(conversationId)",
                details: nil
            ))
            return
        }
        
        // Parse the function definition
        guard let leapFunction = parseLeapFunction(from: functionDict) else {
            result(FlutterError(
                code: "INVALID_FUNCTION",
                message: "Failed to parse function definition",
                details: nil
            ))
            return
        }
        
        // Store the function for this conversation
        if registeredFunctions[conversationId] == nil {
            registeredFunctions[conversationId] = []
        }
        registeredFunctions[conversationId]?.append(leapFunction)
        
        result(nil)
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
            case .tool: roleStr = "tool"
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
        registeredFunctions.removeValue(forKey: conversationId)
        
        // Cancel and remove any active generation task
        if let task = generationTasks[conversationId] {
            task.cancel()
            generationTasks.removeValue(forKey: conversationId)
        }
        
        result(nil)
    }
    
    // MARK: - Helpers
    
    /// Generates a unique ID.
    private func generateId() -> String {
        idCounter += 1
        return "ios_\(idCounter)_\(Date().timeIntervalSince1970)"
    }
    
    /// Parses a Flutter function definition into a LeapFunction.
    private func parseLeapFunction(from dict: [String: Any]) -> LeapFunction? {
        guard let name = dict["name"] as? String,
              let description = dict["description"] as? String,
              let parametersArray = dict["parameters"] as? [[String: Any]] else {
            return nil
        }
        
        var parameters: [LeapFunctionParameter] = []
        for paramDict in parametersArray {
            guard let paramName = paramDict["name"] as? String,
                  let paramTypeDict = paramDict["type"] as? [String: Any],
                  let paramType = parseLeapFunctionParameterType(from: paramTypeDict) else {
                continue
            }
            
            let paramDescription = paramDict["description"] as? String ?? ""
            let paramOptional = paramDict["optional"] as? Bool ?? false
            
            let parameter = LeapFunctionParameter(
                name: paramName,
                type: paramType,
                description: paramDescription,
                optional: paramOptional
            )
            parameters.append(parameter)
        }
        
        return LeapFunction(
            name: name,
            description: description,
            parameters: parameters
        )
    }
    
    /// Parses a Flutter parameter type into a LeapFunctionParameterType.
    private func parseLeapFunctionParameterType(from dict: [String: Any]) -> LeapFunctionParameterType? {
        guard let typeName = dict["type"] as? String else {
            return nil
        }
        
        let description = dict["description"] as? String
        
        switch typeName {
        case "string":
            let enumValues = dict["enumValues"] as? [String]
            return .string(StringType(description: description, enumValues: enumValues))
            
        case "number":
            let enumValues = dict["enumValues"] as? [Double]
            return .number(NumberType(description: description, enumValues: enumValues))
            
        case "integer":
            let enumValues = dict["enumValues"] as? [Int]
            return .integer(IntegerType(description: description, enumValues: enumValues))
            
        case "boolean":
            return .boolean(BooleanType(description: description))
            
        case "null":
            // NullType has no public initializer in SDK 0.8.0, return nil as unsupported
            return nil
            
        case "array":
            guard let itemTypeDict = dict["itemType"] as? [String: Any],
                  let itemType = parseLeapFunctionParameterType(from: itemTypeDict) else {
                return nil
            }
            return .array(ArrayType(description: description, itemType: itemType))
            
        case "object":
            guard let propertiesDict = dict["properties"] as? [String: [String: Any]] else {
                return nil
            }
            
            var properties: [String: LeapFunctionParameterType] = [:]
            for (key, valueDict) in propertiesDict {
                if let valueType = parseLeapFunctionParameterType(from: valueDict) {
                    properties[key] = valueType
                }
            }
            
            let required = dict["required"] as? [String] ?? []
            return .object(ObjectType(description: description, properties: properties, required: required))
            
        default:
            return nil
        }
    }
}
