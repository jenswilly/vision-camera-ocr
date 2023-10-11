package com.visioncameraocr

import android.annotation.SuppressLint
import android.graphics.*
import android.media.Image
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableNativeArray
import com.facebook.react.bridge.WritableNativeMap
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.mrousavy.camera.frameprocessor.Frame
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

class OCRFrameProcessorPlugin(private val context: ReactApplicationContext?): FrameProcessorPlugin() {
    private fun getBlockArray(blocks: MutableList<Text.TextBlock>): WritableNativeArray {
        val blockArray = WritableNativeArray()

        for (block in blocks) {
            val blockMap = WritableNativeMap()

            blockMap.putString("text", block.text)
            blockMap.putArray("recognizedLanguages", getRecognizedLanguages(block.recognizedLanguage))
            blockMap.putArray("cornerPoints", block.cornerPoints?.let { getCornerPoints(it) })
            blockMap.putMap("frame", getFrame(block.boundingBox))
            blockMap.putArray("lines", getLineArray(block.lines))

            blockArray.pushMap(blockMap)
        }
        return blockArray
    }

    private fun getLineArray(lines: MutableList<Text.Line>): WritableNativeArray {
        val lineArray = WritableNativeArray()

        for (line in lines) {
            val lineMap = WritableNativeMap()

            lineMap.putString("text", line.text)
            lineMap.putArray("recognizedLanguages", getRecognizedLanguages(line.recognizedLanguage))
            lineMap.putArray("cornerPoints", line.cornerPoints?.let { getCornerPoints(it) })
            lineMap.putMap("frame", getFrame(line.boundingBox))
            lineMap.putArray("elements", getElementArray(line.elements))

            lineArray.pushMap(lineMap)
        }
        return lineArray
    }

    private fun getElementArray(elements: MutableList<Text.Element>): WritableNativeArray {
        val elementArray = WritableNativeArray()

        for (element in elements) {
            val elementMap = WritableNativeMap()

            elementMap.putString("text", element.text)
            elementMap.putArray("cornerPoints", element.cornerPoints?.let { getCornerPoints(it) })
            elementMap.putMap("frame", getFrame(element.boundingBox))
        }
        return elementArray
    }

    private fun getRecognizedLanguages(recognizedLanguage: String): WritableNativeArray {
        val recognizedLanguages = WritableNativeArray()
        recognizedLanguages.pushString(recognizedLanguage)
        return recognizedLanguages
    }

    private fun getCornerPoints(points: Array<Point>): WritableNativeArray {
        val cornerPoints = WritableNativeArray()

        for (point in points) {
            val pointMap = WritableNativeMap()
            pointMap.putInt("x", point.x)
            pointMap.putInt("y", point.y)
            cornerPoints.pushMap(pointMap)
        }
        return cornerPoints
    }

    private fun getFrame(boundingBox: Rect?): WritableNativeMap {
        val frame = WritableNativeMap()

        if (boundingBox != null) {
            frame.putDouble("x", boundingBox.left.toDouble())
            frame.putDouble("y", boundingBox.top.toDouble())
            frame.putInt("width", boundingBox.width())
            frame.putInt("height", boundingBox.height())
            frame.putInt("boundingCenterX", boundingBox.centerX())
            frame.putInt("boundingCenterY", boundingBox.centerY())
        }
        return frame
    }

    /**
     * New callback function
     */
    override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any? {
        frame.orientation
        params?.let { options ->
            return oldCallback(frame, Array<Any>(1) { options })
        }

        // Fallthrough
        return null
    }

    /**
     * Original callback function
     */
    fun oldCallback(frame: Frame, params: Array<Any>): Any? {
        val result = WritableNativeMap()

        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

        @SuppressLint("UnsafeOptInUsageError")
        val mediaImage: Image? = frame.getImage()

        if (mediaImage != null) {
            var imagePath: String? = null;
            val fileNameOpt = (params[0] as? ReadableMap)?.getString("fileName");
            fileNameOpt?.let { fileName ->
                context?.let { context ->
                    val path = context.filesDir
                    val ocrDirectory = File(path, "modesto")
                    ocrDirectory.mkdirs()

                    val file = File(ocrDirectory, fileName + ".jpg")
                    if (file.exists()) {
                        file.delete()
                    }
                    imagePath = file.absolutePath
                    // Log.w("JWJ:", "Filepath:" + imagePath);


                    val yBuffer: ByteBuffer = mediaImage.planes.get(0).getBuffer()
                    val uBuffer: ByteBuffer = mediaImage.planes.get(1).getBuffer()
                    val vBuffer: ByteBuffer = mediaImage.planes.get(2).getBuffer()

                    val ySize: Int = yBuffer.remaining()
                    val uSize: Int = uBuffer.remaining()
                    val vSize: Int = vBuffer.remaining()

                    val nv21 = ByteArray(ySize + uSize + vSize)
                    yBuffer.get(nv21, 0, ySize)
                    vBuffer.get(nv21, ySize, vSize)
                    uBuffer.get(nv21, ySize + vSize, uSize)

                    val yuvImage = YuvImage(nv21, ImageFormat.NV21, mediaImage.getWidth(), mediaImage.getHeight(), null)
                    val byteArrayOut = ByteArrayOutputStream()
                    yuvImage.compressToJpeg(Rect(0, 0, yuvImage.getWidth(), yuvImage.getHeight()), 75, byteArrayOut)

                    val imageBytes: ByteArray = byteArrayOut.toByteArray()
                    val bm: Bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)

                    // Save
                    val out = FileOutputStream(file)
                    bm.compress(Bitmap.CompressFormat.JPEG, 90, out)
                    out.flush()
                    out.close()
                    // Log.w("JWJ:", "saved");
                }
            }

            // Convert rotation string to degrees
            val rotationDegrees = when(frame.orientation) {
                "portrait" -> 0
                "landscape-right" -> 90
                "portrait-upside-down" -> 180
                "landscape-left" -> 270
                else -> 0
            }

            val image = InputImage.fromMediaImage(mediaImage, rotationDegrees)
            val task: Task<Text> = recognizer.process(image)
            try {
                val text: Text = Tasks.await<Text>(task)
                result.putString("text", text.text)
                result.putArray("blocks", getBlockArray(text.textBlocks))
                result.putString("imagePath", imagePath)
                result.putInt("width", mediaImage.width)
                result.putInt("height", mediaImage.height)
                result.putInt("rotation", rotationDegrees);
            } catch (e: Exception) {
                return null
            }
        }

        val data = WritableNativeMap()
        data.putMap("result", result)
        return data
    }
}
