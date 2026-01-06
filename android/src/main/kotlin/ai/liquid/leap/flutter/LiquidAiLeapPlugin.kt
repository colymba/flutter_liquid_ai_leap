package ai.liquid.leap.flutter

import android.app.Activity
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
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
import ai.liquid.leap.downloader.LeapModelDownloader
import ai.liquid.leap.downloader.LeapDownloadableModel
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
class LiquidAiLeapPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    // MARK: - Properties

    /** The Flutter method channel for communication with Dart. */
    private lateinit var channel: MethodChannel

    /** The application context. */
    private lateinit var context: Context

    /** The current activity (needed for model downloads). */
    private var activity: Activity? = null

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

    // MARK: - ActivityAware Implementation

    /**
     * Called when the plugin is attached to an Activity.
     */
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    /**
     * Called when the plugin is detached from Activity for config changes.
     */
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    /**
     * Called when the plugin is reattached to an Activity for config changes.
     */
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    /**
     * Called when the plugin is detached from an Activity.
     */
    override fun onDetachedFromActivity() {
        activity = null
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
                // If multiple .gguf files exist (e.g. main model + projector), 
                // prioritize .bundle, then largest .gguf that doesn't contain "mmproj"
                var bundleFile: File? = null
                var projectorFile: File? = null
                
                // 1. Look for .bundle files
                val bundleFiles = modelDir.listFiles { _, name -> name.endsWith(".bundle") }
                if (!bundleFiles.isNullOrEmpty()) {
                    bundleFile = bundleFiles[0]
                }
                
                // 2. If no bundle, look for .gguf files
                if (bundleFile == null) {
                    val ggufFiles = modelDir.listFiles { _, name -> name.endsWith(".gguf") }
                    if (!ggufFiles.isNullOrEmpty()) {
                        // Separate main models from projector files
                        // Heuristic: files with "mmproj" in name are projectors
                        val mainModels = ggufFiles.filter { !it.name.contains("mmproj", ignoreCase = true) }
                        val projectorModels = ggufFiles.filter { it.name.contains("mmproj", ignoreCase = true) }
                        
                        if (mainModels.isNotEmpty()) {
                            // Pick the largest main model file
                            bundleFile = mainModels.maxByOrNull { it.length() }
                        } else {
                            // Fallback to largest GGUF if all contain mmproj or none match filter
                            bundleFile = ggufFiles.maxByOrNull { it.length() }
                        }
                        
                        // Pick projector file if available (usually only one)
                        if (projectorModels.isNotEmpty()) {
                            projectorFile = projectorModels.maxByOrNull { it.length() }
                        }
                    }
                }
                
                val modelPath = bundleFile?.absolutePath ?: modelDir.absolutePath
                val projectorPath = projectorFile?.absolutePath
                
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
                
                // Load model using LeapClient with projector if available
                val runner = if (projectorPath != null) {
                    LeapClient.loadModel(modelPath, projectorPath)
                } else {
                    LeapClient.loadModel(modelPath)
                }

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
     * Uses the LeapModelDownloader from the SDK to download models from the
     * Leap Model Library. If the model is not in the library (e.g., VL models),
     * falls back to direct URL download from HuggingFace.
     * Progress updates are sent via method channel callbacks.
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

        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "NO_ACTIVITY",
                "Download functionality requires an active Activity context. Please try again when the app is in the foreground.",
                null
            )
            return
        }

        val progressCallbackId = call.argument<String>("progressCallbackId")
        
        // Support both single URL and list of URLs
        val directUrl = call.argument<String>("url") 
        val directUrls = call.argument<List<String>>("urls")
        
        val saveDirectory = call.argument<String>("saveDirectory")

        scope.launch {
            try {
                // First try to resolve from Leap Model Library (only if no direct URLs provided)
                var downloadableModel: LeapDownloadableModel? = null
                if (directUrl == null && directUrls == null) {
                    downloadableModel = LeapDownloadableModel.resolve(model, quantization)
                }
                
                if (downloadableModel != null) {
                    // Use SDK's model downloader
                    downloadViaLeapModelLibrary(
                        downloadableModel,
                        currentActivity,
                        progressCallbackId,
                        model,
                        quantization,
                        result
                    )
                } else if (directUrls != null && directUrls.isNotEmpty()) {
                    // Download multiple files from URLs
                    downloadViaDirectUrls(
                        directUrls,
                        model,
                        quantization,
                        saveDirectory,
                        progressCallbackId,
                        result
                    )
                } else if (directUrl != null) {
                    // Fallback to single direct URL download
                    downloadViaDirectUrls(
                        listOf(directUrl),
                        model,
                        quantization,
                        saveDirectory,
                        progressCallbackId,
                        result
                    )
                } else {
                    result.error(
                        "MODEL_NOT_FOUND",
                        "Model '$model' with quantization '$quantization' not found in Leap Model Library. " +
                        "For VL models, provide direct download URL(s).",
                        null
                    )
                }
            } catch (e: Exception) {
                result.error(
                    "DOWNLOAD_ERROR",
                    "Failed to download model: ${e.message}",
                    null
                )
            }
        }
    }
    
    /**
     * Downloads a model using the LeapModelDownloader from the SDK.
     */
    private suspend fun downloadViaLeapModelLibrary(
        downloadableModel: LeapDownloadableModel,
        activity: android.app.Activity,
        progressCallbackId: String?,
        model: String,
        quantization: String,
        result: Result
    ) {
        val modelDownloader = LeapModelDownloader(activity)
        
        // Start the download
        modelDownloader.requestDownloadModel(downloadableModel)

        // Poll for download status
        var isDownloadComplete = false
        while (!isDownloadComplete) {
            val status = modelDownloader.queryStatus(downloadableModel)
            
            when (status) {
                LeapModelDownloader.ModelDownloadStatus.NotOnLocal -> {
                    // Download hasn't started yet, waiting...
                    progressCallbackId?.let { callbackId ->
                        withContext(Dispatchers.Main) {
                            channel.invokeMethod(
                                "onDownloadProgress",
                                mapOf(
                                    "callbackId" to callbackId,
                                    "progress" to 0.0,
                                    "bytesPerSecond" to 0
                                )
                            )
                        }
                    }
                }

                is LeapModelDownloader.ModelDownloadStatus.DownloadInProgress -> {
                    if (status.totalSizeInBytes > 0) {
                        val progress = status.downloadedSizeInBytes.toDouble() / status.totalSizeInBytes
                        progressCallbackId?.let { callbackId ->
                            withContext(Dispatchers.Main) {
                                channel.invokeMethod(
                                    "onDownloadProgress",
                                    mapOf(
                                        "callbackId" to callbackId,
                                        "progress" to progress,
                                        "bytesPerSecond" to 0
                                    )
                                )
                            }
                        }
                    }
                }

                is LeapModelDownloader.ModelDownloadStatus.Downloaded -> {
                    isDownloadComplete = true
                    progressCallbackId?.let { callbackId ->
                        withContext(Dispatchers.Main) {
                            channel.invokeMethod(
                                "onDownloadProgress",
                                mapOf(
                                    "callbackId" to callbackId,
                                    "progress" to 1.0,
                                    "bytesPerSecond" to 0
                                )
                            )
                        }
                    }
                }
            }
            
            if (!isDownloadComplete) {
                delay(500) // Poll every 500ms
            }
        }

        // Get the downloaded model file path
        val modelFile = modelDownloader.getModelFile(downloadableModel)

        result.success(
            mapOf(
                "modelPath" to modelFile.absolutePath,
                "modelId" to "${model}_${quantization}",
                "model" to model,
                "quantization" to quantization
            )
        )
    }
    
    /**
     * Downloads a model directly from a URL (e.g., HuggingFace).
     * Used for VL models and other models not in the Leap Model Library.
     */
    /**
     * Downloads models directly from a list of URLs (e.g., HuggingFace).
     * Used for VL models (split files) and other models not in the Leap Model Library.
     */
    private suspend fun downloadViaDirectUrls(
        urls: List<String>,
        model: String,
        quantization: String,
        saveDirectory: String?,
        progressCallbackId: String?,
        result: Result
    ) {
        withContext(Dispatchers.IO) {
            var lastModelPath = ""
            val totalFiles = urls.size
            
            try {
                // Determine the save path (shared for all files)
                val baseDir = if (saveDirectory != null) {
                    File(saveDirectory)
                } else {
                    File(context.filesDir, "leap_models")
                }
                
                // Create model directory - use model/quantization structure
                val modelDir = File(baseDir, "$model/$quantization")
                if (!modelDir.exists()) {
                    modelDir.mkdirs()
                }

                // Calculate cumulative progress
                // We'll give each file an equal share of the progress bar for simplicity
                val progressPerFile = 1.0 / totalFiles
                
                for ((index, url) in urls.withIndex()) {
                    val currentFileBaseProgress = index * progressPerFile
                    
                    var urlConnection: java.net.HttpURLConnection? = null
                    var tempFile: File? = null
                    
                    try {
                        // Determine filename from URL or use default
                        val fileName = url.substringAfterLast("/").substringBefore("?")
                            .ifEmpty { "${model}_${quantization}_$index.gguf" }
                        val outputFile = File(modelDir, fileName)
                        
                        // Track the last file path as the return value (usually safe enough if single file, 
                        // or just one of them if multiple)
                        if (fileName.endsWith(".gguf") && !fileName.contains("mmproj")) {
                            lastModelPath = outputFile.absolutePath
                        } else if (lastModelPath.isEmpty()) {
                            lastModelPath = outputFile.absolutePath
                        }
                        
                        // Skip if already downloaded
                        if (outputFile.exists() && outputFile.length() > 0) {
                            // Update progress for skipped file
                            progressCallbackId?.let { callbackId ->
                                withContext(Dispatchers.Main) {
                                    channel.invokeMethod(
                                        "onDownloadProgress",
                                        mapOf(
                                            "callbackId" to callbackId,
                                            "progress" to (currentFileBaseProgress + progressPerFile),
                                            "bytesPerSecond" to 0
                                        )
                                    )
                                }
                            }
                            continue
                        }
                        
                        // Download the file
                        urlConnection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
                        urlConnection.requestMethod = "GET"
                        urlConnection.setRequestProperty("User-Agent", "LiquidAI-Leap-Flutter/1.0")
                        urlConnection.connect()
                        
                        val responseCode = urlConnection.responseCode
                        if (responseCode !in 200..299) {
                            throw Exception("Server returned HTTP $responseCode for URL: $url")
                        }

                        val totalSize = urlConnection.contentLengthLong
                        var downloadedSize = 0L
                        var lastProgressUpdate = System.currentTimeMillis()
                        var lastDownloadedSize = 0L
                        
                        tempFile = File(outputFile.parent, "${outputFile.name}.tmp")
                        
                        urlConnection.inputStream.use { input ->
                            java.io.FileOutputStream(tempFile).use { output ->
                                val buffer = ByteArray(8192)
                                var bytesRead: Int
                                
                                while (input.read(buffer).also { bytesRead = it } != -1) {
                                    output.write(buffer, 0, bytesRead)
                                    downloadedSize += bytesRead
                                    
                                    // Update progress every 100ms
                                    val now = System.currentTimeMillis()
                                    if (now - lastProgressUpdate >= 100) {
                                        val fileProgress = if (totalSize > 0) {
                                            downloadedSize.toDouble() / totalSize
                                        } else {
                                            0.0
                                        }
                                        
                                        // Map file progress to overall progress
                                        val totalProgress = currentFileBaseProgress + (fileProgress * progressPerFile)
                                        
                                        val elapsedSeconds = (now - lastProgressUpdate) / 1000.0
                                        val bytesPerSecond = if (elapsedSeconds > 0) {
                                            ((downloadedSize - lastDownloadedSize) / elapsedSeconds).toLong()
                                        } else {
                                            0L
                                        }
                                        
                                        progressCallbackId?.let { callbackId ->
                                            withContext(Dispatchers.Main) {
                                                channel.invokeMethod(
                                                    "onDownloadProgress",
                                                    mapOf(
                                                        "callbackId" to callbackId,
                                                        "progress" to totalProgress,
                                                        "bytesPerSecond" to bytesPerSecond
                                                    )
                                                )
                                            }
                                        }
                                        
                                        lastProgressUpdate = now
                                        lastDownloadedSize = downloadedSize
                                    }
                                }
                            }
                        }
                        
                        // Rename temp file to final file
                        tempFile.renameTo(outputFile)
                        
                    } catch (e: Exception) {
                        // Clean up temp file on error
                        tempFile?.let { if (it.exists()) it.delete() }
                        throw e
                    } finally {
                        urlConnection?.disconnect()
                    }
                }
                
                // Final progress update
                progressCallbackId?.let { callbackId ->
                    withContext(Dispatchers.Main) {
                        channel.invokeMethod(
                            "onDownloadProgress",
                            mapOf(
                                "callbackId" to callbackId,
                                "progress" to 1.0,
                                "bytesPerSecond" to 0
                            )
                        )
                    }
                }
                
                result.success(
                    mapOf(
                        "modelPath" to lastModelPath,
                        "modelId" to "${model}_${quantization}",
                        "model" to model,
                        "quantization" to quantization
                    )
                )

            } catch (e: Exception) {
                result.error(
                    "DOWNLOAD_ERROR",
                    "Failed to download from URL(s): ${e.message}",
                    null
                )
            }
        }
    }

    /**
     * Checks if a model is cached.
     * 
     * Checks both the local leap_models directory and the LeapModelDownloader cache.
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
        val currentActivity = activity

        scope.launch {
            try {
                // First check if model is in custom save directory
                val baseDir = if (saveDirectory != null) {
                    saveDirectory
                } else {
                    File(context.filesDir, "leap_models").absolutePath
                }
                
                val modelPath = File(baseDir, "$model/$quantization")
                var isCached = modelPath.exists() && modelPath.isDirectory
                
                // If not found locally and we have activity context, check via LeapModelDownloader
                if (!isCached && currentActivity != null) {
                    try {
                        val downloadableModel = LeapDownloadableModel.resolve(model, quantization)
                        if (downloadableModel != null) {
                            val modelDownloader = LeapModelDownloader(currentActivity)
                            val status = modelDownloader.queryStatus(downloadableModel)
                            isCached = status is LeapModelDownloader.ModelDownloadStatus.Downloaded
                        }
                    } catch (e: Exception) {
                        // Ignore errors from downloader check, fall back to local check
                    }
                }
                
                result.success(isCached)
            } catch (e: Exception) {
                result.error(
                    "CACHE_CHECK_ERROR",
                    "Failed to check cache status: ${e.message}",
                    null
                )
            }
        }
    }

    /**
     * Deletes a cached model.
     * 
     * Deletes from both the local directory and the LeapModelDownloader cache.
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
        val currentActivity = activity

        scope.launch {
            try {
                var deleted = false
                
                // Delete from custom save directory
                val baseDir = if (saveDirectory != null) {
                    saveDirectory
                } else {
                    File(context.filesDir, "leap_models").absolutePath
                }
                
                val modelPath = File(baseDir, "$model/$quantization")
                if (modelPath.exists()) {
                    deleted = modelPath.deleteRecursively()
                }
                
                // Also try to delete from LeapModelDownloader cache
                if (currentActivity != null) {
                    try {
                        val downloadableModel = LeapDownloadableModel.resolve(model, quantization)
                        if (downloadableModel != null) {
                            val modelDownloader = LeapModelDownloader(currentActivity)
                            val modelFile = modelDownloader.getModelFile(downloadableModel)
                            if (modelFile.exists()) {
                                deleted = modelFile.deleteRecursively() || deleted
                            }
                        }
                    } catch (e: Exception) {
                        // Ignore errors from downloader delete
                    }
                }
                
                result.success(deleted)
            } catch (e: Exception) {
                result.error(
                    "DELETE_ERROR",
                    "Failed to delete model: ${e.message}",
                    null
                )
            }
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
                    "image_url" -> {
                        val imageUrlMap = contentMap["image_url"] as? Map<*, *> ?: return@mapNotNull null
                        val url = imageUrlMap["url"] as? String ?: return@mapNotNull null
                        
                        // Handle data URL format: data:image/jpeg;base64,...
                        if (url.startsWith("data:image")) {
                            val base64Data = url.substringAfter("base64,")
                            try {
                                val jpegBytes = android.util.Base64.decode(base64Data, android.util.Base64.DEFAULT)
                                ChatMessageContent.Image(jpegBytes)
                            } catch (e: Exception) {
                                null
                            }
                        } else {
                            null
                        }
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
        val options = GenerationOptions()
        (map["temperature"] as? Number)?.let { options.temperature = it.toFloat() }
        (map["topP"] as? Number)?.let { options.topP = it.toFloat() }
        (map["minP"] as? Number)?.let { options.minP = it.toFloat() }
        (map["repetitionPenalty"] as? Number)?.let { options.repetitionPenalty = it.toFloat() }
        (map["jsonSchemaConstraint"] as? String)?.let { options.jsonSchemaConstraint = it }
        return options
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
