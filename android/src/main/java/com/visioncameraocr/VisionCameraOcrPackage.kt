package com.visioncameraocr

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin


class VisionCameraOcrPackage : ReactPackage {
    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
        // https://www.dynamsoft.com/codepool/react-native-vision-camera-label-recognition-plugin-android.html
        val plugin = OCRFrameProcessorPlugin();
        plugin.context = reactContext
        FrameProcessorPlugin.register(plugin)

        return emptyList()
    }

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
        return emptyList()
    }
}
