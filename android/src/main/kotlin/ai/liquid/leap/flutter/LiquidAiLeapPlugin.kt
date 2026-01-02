package ai.liquid.leap.flutter

import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import ai.liquid.leap.LeapClient
import ai.liquid.leap.ModelRunner
import ai.liquid.leap.Conversation
import ai.liquid.leap.GenerationOptions
import ai.liquid.leap.message.ChatMessage
import ai.liquid.leap.message.ChatMessageContent
import ai.liquid.leap.message.MessageResponse
import ai.liquid.leap.function.LeapFunction
import ai.liquid.leap.function.LeapFunctionParameter
import ai.liquid.leap.function.LeapFunctionParameterType
import ai.liquid.leap.function.LeapFunctionCall
import java.io.File

/**
 * Flutter plugin for the Liquid AI LEAP SDK.
 *
 * This plugin provides on-device AI inference capabilities using Liquid
 * Foundation Models (LFM). It wraps the native LeapSDK for Android.
 *
 * ## Features
 *
 * - Model downloading and caching
 * - Streaming text generation
 * - Multimodal support (text, images, audio)
 * - Function calling
 * - Constrained JSON generation
 *
 * ## Requirements
 *
 * - Android API 31+ (Android 12)
 * - arm64-v8a ABI support
 * - Physical device recommended (3GB+ RAM)
 * - LeapSDK 0.8.0+
 */
class LiquidAiLeapPlugin : FlutterPlugin, MethodCallHandler {

    // MARK: - Properties

    /** The Flutter method channel for communication with Dart. */
    private lateinit var channel: MethodChannel

    /** The application context. */
    private lateinit var context: Context

    /** Coroutine scope for async operations. */
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    /** Active model runners indexed by their ID. */
    private val modelRunners = mutableMapOf<String, ModelRunner>()

    /** Active conversations indexed by their ID. */
    private val conversations = mutableMapOf<String, Conversation>()

    /** Active generation jobs indexed by conversation ID. */
    private val generationJobs = mutableMapOf<String, Job>()

    /** Counter for generating unique IDs. */
    private var idCounter = 0

    // MARK: - FlutterPlugin

    /**
     * Called when the plugin is attached to the Flutter engine.
     *
     * @param flutterPluginBinding The binding to the Flutter engine.
     */
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ai.liquid.leap/plugin")
        channel.setMethodCallHandler(this)
    }

    /**
     * Handles method calls from Dart.
     *
     * @param call The method call.
     * @param result The result callback.
     */
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> handleGetPlatformVersion(result)
            "getSdkVersion" -> handleGetSdkVersion(result)
            "loadModel" -> handleLoadModel(call, result)
            "downloadModel" -> handleDownloadModel(call, result)
            "isModelCached" -> handleIsModelCached(call, result)
            "deleteModel" -> handleDeleteModel(call, result)
            "createConversation" -> handleCreateConversation(call, result)
            "createConversationFromHistory" -> handleCreateConversationFromHistory(call, result)
            "generateResponse" -> handleGenerateResponse(call, result)
            "stopGeneration" -> handleStopGeneration(call, result)
            "registerFunction" -> handleRegisterFunction(call, result)
            "getConversationHistory" -> handleGetConversationHistory(call, result)
            "unloadModel" -> handleUnloadModel(call, result)
            "disposeConversation" -> handleDisposeConversation(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Called when the plugin is detached from the Flutter engine.
     *
     * @param binding The binding to the Flutter engine.
     */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        
        // Clean up resources
        modelRunners.clear()
        conversations.clear()
        generationJobs.values.forEach { it.cancel() }
        generationJobs.clear()
    }

    // MARK: - Handler Methods

    /**
     * Returns the platform version.
     */
    private fun handleGetPlatformVersion(result: Result) {
        result.success("Android ${Build.VERSION.RELEASE}")
    }

    /**
     * Returns the LEAP SDK version.
     */
    private fun handleGetSdkVersion(result: Result) {
        // TODO: Get actual SDK version from LeapSDK
        result.success("0.8.0")
    }

    /**
     * Loads a model from a local path.
     * 
     * For now, this implementation loads from a local file path.
     * The model must already be present on the device.
     */
    private fun handleLoadModel(call: MethodCall, result: Result) {
        val model = call.argument<String>("model")
        val quantization = call.argument<String>("quantization")

        if (model == null || quantization == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: model, quantization",
                null
            )
            return
        }

        val saveDirectory = call.argument<String>("saveDirectory")
        val progressCallbackId = call.argument<String>("progressCallbackId")

        scope.launch {
            try {
                // Determine the model directory
                val baseDir = if (saveDirectory != null) {
                    saveDirectory
                } else {
                    File(context.filesDir, "leap_models").absolutePath
                }
                
                // Look for model bundle in the expected location
                val modelDir = File(baseDir, "$model/$quantization")
                
                // Find the bundle file (either .bundle or .gguf)
                val bundleFile = modelDir.listFiles()?.find { 
                    it.name.endsWith(".bundle") || it.name.endsWith(".gguf") 
                }
                
                val modelPath = bundleFile?.absolutePath ?: modelDir.absolutePath
                
                // Report progress start
                progressCallbackId?.let { callbackId ->
                    channel.invokeMethod(
                        "onDownloadProgress",
                        mapOf(
                            "callbackId" to callbackId,
                            "progress" to 0.5,
                            "bytesPerSecond" to 0
                        )
                    )
                }
                
                // Load model using LeapClient
                val runner = LeapClient.loadModel(modelPath)

                val runnerId = generateId()
                modelRunners[runnerId] = runner
                
                // Report progress complete
                progressCallbackId?.let { callbackId ->
                    channel.invokeMethod(
                        "onDownloadProgress",
                        mapOf(
                            "callbackId" to callbackId,
                            "progress" to 1.0,
                            "bytesPerSecond" to 0
                        )
                    )
                }

                result.success(
                    mapOf(
                        "runnerId" to runnerId,
                        "modelId" to "${model}_${quantization}"
                    )
                )
            } catch (e: Exception) {
                result.error(
                    "MODEL_LOADING_ERROR",
                    "Failed to load model: ${e.message}",
                    null
                )
            }
        }
    }

    /**
     * Downloads a model without loading it.
     * 
     * Note: The current LEAP SDK for Android does not provide a public download API.
     * Models should be pushed to the device or downloaded using Android's download manager.
     * This returns an error for now - use loadModel with a pre-existing model path instead.
     */
    private fun handleDownloadModel(call: MethodCall, result: Result) {
        val model = call.argument<String>("model")
        val quantization = call.argument<String>("quantization")

        if (model == null || quantization == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: model, quantization",
                null
            )
            return
        }

        // The LEAP SDK for Android uses LeapModelDownloader for DownloadManager-based downloads
        // but it requires activity context. For now, return not implemented.
        result.error(
            "NOT_IMPLEMENTED",
            "Download functionality requires activity context. Use loadModel with a pre-existing model path.",
            null
        )
    }

    /**
     * Checks if a model is cached.
     */
    private fun handleIsModelCached(call: MethodCall, result: Result) {
        val model = call.argument<String>("model")
        val quantization = call.argument<String>("quantization")

        if (model == null || quantization == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: model, quantization",
                null
            )
            return
        }

        val saveDirectory = call.argument<String>("saveDirectory")

        try {
            // Check if model directory exists
            val baseDir = if (saveDirectory != null) {
                saveDirectory
            } else {
                File(context.filesDir, "leap_models").absolutePath
            }
            
            // Models are stored in: baseDir/model/quantization/
            val modelPath = File(baseDir, "$model/$quantization")
            val isCached = modelPath.exists() && modelPath.isDirectory
            
            result.success(isCached)
        } catch (e: Exception) {
            result.error(
                "CACHE_CHECK_ERROR",
                "Failed to check cache status: ${e.message}",
                null
            )
        }
    }

    /**
     * Deletes a cached model.
     */
    private fun handleDeleteModel(call: MethodCall, result: Result) {
        val model = call.argument<String>("model")
        val quantization = call.argument<String>("quantization")

        if (model == null || quantization == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: model, quantization",
                null
            )
            return
        }

        val saveDirectory = call.argument<String>("saveDirectory")

        try {
            // Delete model directory
            val baseDir = if (saveDirectory != null) {
                saveDirectory
            } else {
                File(context.filesDir, "leap_models").absolutePath
            }
            
            val modelPath = File(baseDir, "$model/$quantization")
            val deleted = modelPath.deleteRecursively()
            
            result.success(deleted)
        } catch (e: Exception) {
            result.error(
                "DELETE_ERROR",
                "Failed to delete model: ${e.message}",
                null
            )
        }
    }

    /**
     * Creates a new conversation.
     */
    private fun handleCreateConversation(call: MethodCall, result: Result) {
        val runnerId = call.argument<String>("runnerId")

        if (runnerId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: runnerId",
                null
            )
            return
        }

        val systemPrompt = call.argument<String>("systemPrompt")

        try {
            // Get the model runner
            val runner = modelRunners[runnerId]
            if (runner == null) {
                result.error(
                    "RUNNER_NOT_FOUND",
                    "Model runner not found: $runnerId",
                    null
                )
                return
            }

            // Create conversation with optional system prompt
            val conversation = runner.createConversation(systemPrompt)

            val conversationId = generateId()
            conversations[conversationId] = conversation
            
            result.success(
                mapOf("conversationId" to conversationId)
            )
        } catch (e: Exception) {
            result.error(
                "CONVERSATION_ERROR",
                "Failed to create conversation: ${e.message}",
                null
            )
        }
    }

    /**
     * Creates a conversation from history.
     */
    private fun handleCreateConversationFromHistory(call: MethodCall, result: Result) {
        val runnerId = call.argument<String>("runnerId")
        val history = call.argument<List<Map<String, Any>>>("history")

        if (runnerId == null || history == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: runnerId, history",
                null
            )
            return
        }

        try {
            // Get the model runner
            val runner = modelRunners[runnerId]
            if (runner == null) {
                result.error(
                    "RUNNER_NOT_FOUND",
                    "Model runner not found: $runnerId",
                    null
                )
                return
            }

            // Parse history into ChatMessage list
            val chatMessages = history.mapNotNull { message ->
                parseChatMessage(message)
            }

            // Create conversation from history
            val conversation = runner.createConversationFromHistory(chatMessages)

            val conversationId = generateId()
            conversations[conversationId] = conversation

            result.success(
                mapOf("conversationId" to conversationId)
            )
        } catch (e: Exception) {
            result.error(
                "CONVERSATION_ERROR",
                "Failed to create conversation from history: ${e.message}",
                null
            )
        }
    }

    /**
     * Generates a response (streaming).
     */
    private fun handleGenerateResponse(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")
        val message = call.argument<Map<String, Any>>("message")
        val streamCallbackId = call.argument<String>("streamCallbackId")

        if (conversationId == null || message == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: conversationId, message",
                null
            )
            return
        }

        val options = call.argument<Map<String, Any>>("options")

        if (streamCallbackId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing streamCallbackId",
                null
            )
            return
        }

        // Cancel any existing generation for this conversation
        generationJobs[conversationId]?.cancel()

        // Implement actual generation with LeapSDK
        val job = scope.launch {
            try {
                // Get the conversation
                val conversation = conversations[conversationId]
                if (conversation == null) {
                    result.error(
                        "CONVERSATION_NOT_FOUND",
                        "Conversation not found: $conversationId",
                        null
                    )
                    return@launch
                }

                // Parse the chat message
                val chatMessage = parseChatMessage(message)
                if (chatMessage == null) {
                    result.error(
                        "INVALID_MESSAGE",
                        "Failed to parse message",
                        null
                    )
                    return@launch
                }

                // Parse generation options if provided
                val generationOptions = options?.let { parseGenerationOptions(it) }

                // Generate response using Flow
                conversation.generateResponse(chatMessage, generationOptions)
                    .onEach { response ->
                        when (response) {
                            is MessageResponse.Chunk -> {
                                channel.invokeMethod(
                                    "onGenerationResponse",
                                    mapOf(
                                        "callbackId" to streamCallbackId,
                                        "type" to "chunk",
                                        "text" to response.text
                                    )
                                )
                            }
                            is MessageResponse.ReasoningChunk -> {
                                channel.invokeMethod(
                                    "onGenerationResponse",
                                    mapOf(
                                        "callbackId" to streamCallbackId,
                                        "type" to "reasoningChunk",
                                        "reasoning" to response.reasoning
                                    )
                                )
                            }
                            is MessageResponse.FunctionCalls -> {
                                val calls = response.functionCalls.map { call ->
                                    mapOf(
                                        "name" to call.name,
                                        "arguments" to call.arguments
                                    )
                                }
                                channel.invokeMethod(
                                    "onGenerationResponse",
                                    mapOf(
                                        "callbackId" to streamCallbackId,
                                        "type" to "functionCall",
                                        "calls" to calls
                                    )
                                )
                            }
                            is MessageResponse.AudioSample -> {
                                channel.invokeMethod(
                                    "onGenerationResponse",
                                    mapOf(
                                        "callbackId" to streamCallbackId,
                                        "type" to "audioSample",
                                        "samples" to response.samples.toList(),
                                        "sampleRate" to response.sampleRate
                                    )
                                )
                            }
                            is MessageResponse.Complete -> {
                                // Convert ChatMessage to map
                                val messageMap = chatMessageToMap(response.fullMessage)
                                val statsMap = response.stats?.let {
                                    mapOf(
                                        "promptTokens" to it.promptTokens,
                                        "completionTokens" to it.completionTokens,
                                        "totalTokens" to it.totalTokens,
                                        "tokensPerSecond" to it.tokenPerSecond
                                    )
                                }

                                channel.invokeMethod(
                                    "onGenerationResponse",
                                    mapOf(
                                        "callbackId" to streamCallbackId,
                                        "type" to "complete",
                                        "message" to messageMap,
                                        "finishReason" to response.finishReason.toString().lowercase(),
                                        "stats" to statsMap
                                    )
                                )
                            }
                        }
                    }
                    .onCompletion {
                        // Flow completed
                    }
                    .catch { e ->
                        result.error(
                            "GENERATION_ERROR",
                            "Generation failed: ${e.message}",
                            null
                        )
                    }
                    .collect()

                result.success(null)
            } catch (e: Exception) {
                if (e !is CancellationException) {
                    result.error(
                        "GENERATION_ERROR",
                        "Generation failed: ${e.message}",
                        null
                    )
                }
            } finally {
                generationJobs.remove(conversationId)
            }
        }

        generationJobs[conversationId] = job
    }

    /**
     * Stops an ongoing generation.
     */
    private fun handleStopGeneration(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")

        if (conversationId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: conversationId",
                null
            )
            return
        }

        generationJobs[conversationId]?.cancel()
        generationJobs.remove(conversationId)
        result.success(null)
    }

    /**
     * Registers a function for function calling.
     */
    private fun handleRegisterFunction(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")
        val function = call.argument<Map<String, Any>>("function")

        if (conversationId == null || function == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required arguments: conversationId, function",
                null
            )
            return
        }

        try {
            // Get the conversation
            val conversation = conversations[conversationId]
            if (conversation == null) {
                result.error(
                    "CONVERSATION_NOT_FOUND",
                    "Conversation not found: $conversationId",
                    null
                )
                return
            }

            // Parse the function definition
            val leapFunction = parseLeapFunction(function)
            if (leapFunction == null) {
                result.error(
                    "INVALID_FUNCTION",
                    "Failed to parse function definition",
                    null
                )
                return
            }

            // Register the function with the conversation
            conversation.registerFunction(leapFunction)

            result.success(null)
        } catch (e: Exception) {
            result.error(
                "REGISTER_FUNCTION_ERROR",
                "Failed to register function: ${e.message}",
                null
            )
        }
    }

    /**
     * Gets the conversation history.
     */
    private fun handleGetConversationHistory(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")

        if (conversationId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: conversationId",
                null
            )
            return
        }

        try {
            // Get the conversation
            val conversation = conversations[conversationId]
            if (conversation == null) {
                result.error(
                    "CONVERSATION_NOT_FOUND",
                    "Conversation not found: $conversationId",
                    null
                )
                return
            }

            // Convert history to map list
            val history = conversation.history.map { chatMessage ->
                chatMessageToMap(chatMessage)
            }

            result.success(history)
        } catch (e: Exception) {
            result.error(
                "HISTORY_ERROR",
                "Failed to get history: ${e.message}",
                null
            )
        }
    }

    /**
     * Unloads a model.
     */
    private fun handleUnloadModel(call: MethodCall, result: Result) {
        val runnerId = call.argument<String>("runnerId")

        if (runnerId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: runnerId",
                null
            )
            return
        }

        scope.launch {
            try {
                // Get the model runner
                val runner = modelRunners[runnerId]
                if (runner != null) {
                    // Unload the model
                    runner.unload()
                    modelRunners.remove(runnerId)
                }
                result.success(null)
            } catch (e: Exception) {
                result.error(
                    "UNLOAD_ERROR",
                    "Failed to unload model: ${e.message}",
                    null
                )
            }
        }
    }

    /**
     * Disposes a conversation.
     */
    private fun handleDisposeConversation(call: MethodCall, result: Result) {
        val conversationId = call.argument<String>("conversationId")

        if (conversationId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Missing required argument: conversationId",
                null
            )
            return
        }

        // Cancel any ongoing generation
        generationJobs[conversationId]?.cancel()
        generationJobs.remove(conversationId)
        
        conversations.remove(conversationId)
        result.success(null)
    }

    // MARK: - Helpers

    /**
     * Generates a unique ID.
     */
    private fun generateId(): String {
        idCounter++
        return "android_${idCounter}_${System.currentTimeMillis()}"
    }

    /**
     * Parses a Flutter map into a ChatMessage.
     */
    private fun parseChatMessage(map: Map<String, Any>): ChatMessage? {
        try {
            val roleStr = map["role"] as? String ?: return null
            val role = when (roleStr) {
                "system" -> ChatMessage.Role.SYSTEM
                "user" -> ChatMessage.Role.USER
                "assistant" -> ChatMessage.Role.ASSISTANT
                "tool" -> ChatMessage.Role.TOOL
                else -> return null
            }

            val contentList = map["content"] as? List<*> ?: return null
            val content = contentList.mapNotNull { item ->
                val contentMap = item as? Map<*, *> ?: return@mapNotNull null
                val type = contentMap["type"] as? String

                when (type) {
                    "text" -> {
                        val text = contentMap["text"] as? String ?: return@mapNotNull null
                        ChatMessageContent.Text(text)
                    }
                    "image" -> {
                        val jpegBytes = contentMap["jpegData"] as? ByteArray ?: return@mapNotNull null
                        ChatMessageContent.Image(jpegBytes)
                    }
                    // Audio content is not supported in input for now
                    else -> null
                }
            }

            return ChatMessage(
                role = role,
                content = content
            )
        } catch (e: Exception) {
            return null
        }
    }

    /**
     * Converts a ChatMessage to a Flutter map.
     */
    private fun chatMessageToMap(chatMessage: ChatMessage): Map<String, Any?> {
        val content = chatMessage.content.map { contentItem ->
            when (contentItem) {
                is ChatMessageContent.Text -> {
                    mapOf(
                        "type" to "text",
                        "text" to contentItem.text
                    )
                }
                is ChatMessageContent.Image -> {
                    mapOf(
                        "type" to "image",
                        "jpegData" to null  // Image data not accessible for reading back
                    )
                }
                else -> {
                    mapOf("type" to "unknown")
                }
            }
        }

        return mapOf(
            "role" to chatMessage.role.toString().lowercase(),
            "content" to content
        )
    }

    /**
     * Parses generation options from a Flutter map.
     */
    private fun parseGenerationOptions(map: Map<String, Any>): GenerationOptions {
        return GenerationOptions.build {
            (map["temperature"] as? Number)?.let { temperature = it.toFloat() }
            (map["topP"] as? Number)?.let { topP = it.toFloat() }
            (map["minP"] as? Number)?.let { minP = it.toFloat() }
            (map["repetitionPenalty"] as? Number)?.let { repetitionPenalty = it.toFloat() }
            (map["jsonSchemaConstraint"] as? String)?.let { jsonSchemaConstraint = it }
        }
    }

    /**
     * Parses a Flutter function definition map into LeapFunction.
     */
    private fun parseLeapFunction(map: Map<String, Any>): LeapFunction? {
        try {
            val name = map["name"] as? String ?: return null
            val description = map["description"] as? String ?: return null
            val parametersMap = map["parameters"] as? List<*> ?: return null

            val parameters = parametersMap.mapNotNull { param ->
                val paramMap = param as? Map<*, *> ?: return@mapNotNull null
                val paramName = paramMap["name"] as? String ?: return@mapNotNull null
                val paramDescription = paramMap["description"] as? String ?: ""
                val paramOptional = paramMap["optional"] as? Boolean ?: false
                val paramType = paramMap["type"] as? Map<*, *> ?: return@mapNotNull null

                val type = parseLeapFunctionParameterType(paramType) ?: return@mapNotNull null

                LeapFunctionParameter(
                    name = paramName,
                    type = type,
                    description = paramDescription,
                    optional = paramOptional
                )
            }

            return LeapFunction(
                name = name,
                description = description,
                parameters = parameters
            )
        } catch (e: Exception) {
            return null
        }
    }

    /**
     * Parses a Flutter parameter type map into LeapFunctionParameterType.
     */
    private fun parseLeapFunctionParameterType(map: Map<*, *>): LeapFunctionParameterType? {
        try {
            val typeName = map["type"] as? String ?: return null
            val description = map["description"] as? String

            return when (typeName) {
                "string" -> {
                    val enumValues = (map["enumValues"] as? List<*>)?.mapNotNull { it as? String }
                    LeapFunctionParameterType.String(enumValues, description)
                }
                "number" -> {
                    val enumValues = (map["enumValues"] as? List<*>)?.mapNotNull { it as? Number }
                    LeapFunctionParameterType.Number(enumValues, description)
                }
                "integer" -> {
                    val enumValues = (map["enumValues"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
                    LeapFunctionParameterType.Integer(enumValues, description)
                }
                "boolean" -> {
                    LeapFunctionParameterType.Boolean(description)
                }
                "null" -> {
                    LeapFunctionParameterType.Null()
                }
                "array" -> {
                    val itemTypeMap = map["itemType"] as? Map<*, *> ?: return null
                    val itemType = parseLeapFunctionParameterType(itemTypeMap) ?: return null
                    LeapFunctionParameterType.Array(itemType, description)
                }
                "object" -> {
                    val propertiesMap = map["properties"] as? Map<*, *> ?: return null
                    val properties = propertiesMap.mapNotNull { (key, value) ->
                        val propName = key as? String ?: return@mapNotNull null
                        val propTypeMap = value as? Map<*, *> ?: return@mapNotNull null
                        val propType = parseLeapFunctionParameterType(propTypeMap) ?: return@mapNotNull null
                        propName to propType
                    }.toMap()

                    val required = (map["required"] as? List<*>)?.mapNotNull { it as? String } ?: listOf()

                    LeapFunctionParameterType.Object(properties, required, description)
                }
                else -> null
            }
        } catch (e: Exception) {
            return null
        }
    }
}
