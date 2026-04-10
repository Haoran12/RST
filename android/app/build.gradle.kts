import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val rustCrateDir = projectDir.resolve("../../rust").canonicalFile
val rustJniLibsDir = projectDir.resolve("src/main/jniLibs")
val rustLibraryStem = "rst_core"
val rustAndroidPlatform = "21"
val rustAbiTargets = mapOf(
    "arm64-v8a" to "aarch64-linux-android",
    "armeabi-v7a" to "armv7-linux-androideabi",
    "x86_64" to "x86_64-linux-android",
)

fun registerRustBuildTask(taskName: String, profile: String) {
    tasks.register(taskName) {
        group = "build"
        description = "Build Rust native library for Android ($profile)."
        inputs.files(
            fileTree(rustCrateDir.resolve("src")),
            rustCrateDir.resolve("Cargo.toml"),
            rustCrateDir.resolve("Cargo.lock"),
        )
        outputs.dir(rustJniLibsDir)

        doLast {
            if (!rustCrateDir.exists()) {
                throw GradleException("Rust crate directory not found: ${rustCrateDir.absolutePath}")
            }

            rustAbiTargets.forEach { (abi, targetTriple) ->
                val command = mutableListOf(
                    "cargo",
                    "ndk",
                    "--target",
                    targetTriple,
                    "--platform",
                    rustAndroidPlatform,
                    "build",
                    "--lib",
                )
                if (profile == "release") {
                    command.add("--release")
                }

                exec {
                    workingDir = rustCrateDir
                    commandLine(command)
                }

                val rustProfileDir = if (profile == "release") "release" else "debug"
                val builtLibrary = rustCrateDir.resolve(
                    "target/$targetTriple/$rustProfileDir/lib$rustLibraryStem.so",
                )
                if (!builtLibrary.exists()) {
                    throw GradleException("Rust output not found: ${builtLibrary.absolutePath}")
                }

                val abiOutputDir = rustJniLibsDir.resolve(abi)
                abiOutputDir.mkdirs()
                builtLibrary.copyTo(
                    abiOutputDir.resolve("lib$rustLibraryStem.so"),
                    overwrite = true,
                )
            }
        }
    }
}

registerRustBuildTask(taskName = "buildRustAndroidDebug", profile = "debug")
registerRustBuildTask(taskName = "buildRustAndroidRelease", profile = "release")

tasks.named("preBuild") {
    val isReleaseBuild = gradle.startParameter.taskNames.any {
        it.contains("Release", ignoreCase = true)
    }
    dependsOn(if (isReleaseBuild) "buildRustAndroidRelease" else "buildRustAndroidDebug")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { stream ->
        keystoreProperties.load(stream)
    }
}

android {
    namespace = "com.rst.app.rst"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rst.app.rst"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
