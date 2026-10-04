package ph.turaista.turaista

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.util.concurrent.Executors

/**
 * Copies the intent model bundled in the APK (uncompressed asset) to a real
 * file, because llama.cpp needs a file path. Streams in 1 MB chunks on a
 * background thread, so the 530 MB model never sits in memory.
 */
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "turaista/model")
            .setMethodCallHandler { call, result ->
                if (call.method != "copyBundledModel") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                val dest = call.argument<String>("dest")
                if (name == null || dest == null) {
                    result.error("args", "name and dest are required", null)
                    return@setMethodCallHandler
                }
                io.execute {
                    val copied = try {
                        copyAsset(name, File(dest))
                    } catch (e: Exception) {
                        false
                    }
                    runOnUiThread { result.success(copied) }
                }
            }
    }

    /** True when [dest] holds the full model; false when it is not bundled. */
    private fun copyAsset(name: String, dest: File): Boolean {
        val size = try {
            assets.openFd(name).use { it.length }
        } catch (e: FileNotFoundException) {
            return false
        }
        if (dest.exists() && dest.length() == size) return true
        dest.parentFile?.mkdirs()
        val temp = File(dest.path + ".tmp")
        assets.open(name).use { input ->
            temp.outputStream().use { output -> input.copyTo(output, 1 shl 20) }
        }
        if (temp.length() != size) {
            temp.delete()
            return false
        }
        return temp.renameTo(dest)
    }
}
