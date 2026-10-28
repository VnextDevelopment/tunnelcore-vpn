plugins {
    id(libs.plugins.android.library.get().pluginId)
    id("property-delegate")
}

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(17))
}

val qtAndroidDir: String by gradleProperties

// Qt 6.10's source can still reset decor fitting and includes deprecated
// system-bar color APIs. Stage an SDK-independent patched copy for :qt,
// leaving the developer's installed Qt (and native libraries) untouched.
val patchedQtSources = layout.buildDirectory.dir("generated/qt-android-src")
val prepareQtAndroidSources = tasks.register<Exec>("prepareQtAndroidSources") {
    val qtSourceDir = file("$qtAndroidDir/src")
    val patchScript = file("patch_qt_android_sources.py")
    inputs.dir(qtSourceDir)
    inputs.file(patchScript)
    outputs.dir(patchedQtSources)
    commandLine(
        "python3", patchScript.absolutePath,
        qtSourceDir.absolutePath, patchedQtSources.get().asFile.absolutePath
    )
}

tasks.withType<JavaCompile>().configureEach {
    dependsOn(prepareQtAndroidSources)
}

android {
    namespace = "org.qtproject.qt.android.binding"

    sourceSets {
        getByName("main") {
            java.setSrcDirs(listOf(patchedQtSources.get().asFile))
            res.setSrcDirs(listOf("$qtAndroidDir/res"))
        }
    }
}

dependencies {
    api(fileTree(mapOf("dir" to "../libs", "include" to listOf("*.jar"))))
}
