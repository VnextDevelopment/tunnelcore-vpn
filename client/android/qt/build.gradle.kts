plugins {
    id(libs.plugins.android.library.get().pluginId)
    id("property-delegate")
}

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(17))
}

val qtAndroidDir: String by gradleProperties
val androidCompileSdkVersion: String by gradleProperties

// Qt 6.10 ships QtDisplayManager as bytecode inside Qt6Android.jar, while
// qtAndroidDir/src only contains the three application/Activity wrappers.
// Patch a COPY of the prebuilt jar so the developer's Qt installation and
// the original androiddeployqt output remain untouched.
val originalQtJar = file("../libs/Qt6Android.jar")
val platformJar = file("${android.sdkDirectory}/platforms/$androidCompileSdkVersion/android.jar")
val patchedQtJar = layout.buildDirectory.file("generated/qt/Qt6Android.jar")
val patchQtAndroidJar = tasks.register<Exec>("patchQtAndroidJar") {
    val patchScript = file("patch_qt_android_sources.py")
    val qtDisplayManagerSource = file("qt-6.10.1/QtDisplayManager.java")
    inputs.file(originalQtJar)
    inputs.file(platformJar)
    inputs.file(patchScript)
    inputs.file(qtDisplayManagerSource)
    outputs.file(patchedQtJar)
    commandLine(
        "python3", patchScript.absolutePath,
        originalQtJar.absolutePath, platformJar.absolutePath,
        patchedQtJar.get().asFile.absolutePath
    )
}

android {
    namespace = "org.qtproject.qt.android.binding"

    sourceSets {
        getByName("main") {
            java.setSrcDirs(listOf("$qtAndroidDir/src"))
            res.setSrcDirs(listOf("$qtAndroidDir/res"))
        }
    }
}

dependencies {
    // Exactly one Qt6Android jar on the runtime/compile classpaths: the
    // patched binary. Keep all the other Qt module jars without changes.
    api(fileTree(mapOf(
        "dir" to "../libs",
        "include" to listOf("*.jar"),
        "exclude" to listOf("Qt6Android.jar")
    )))
    api(files(patchedQtJar).builtBy(patchQtAndroidJar))
}
