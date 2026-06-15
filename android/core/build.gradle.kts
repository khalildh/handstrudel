import org.gradle.process.ExecOperations
import javax.inject.Inject

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.handstrudel.core"
    compileSdk = 35

    defaultConfig {
        minSdk = 26
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }

    sourceSets {
        getByName("main") {
            // Kotlin bindings + .so files are populated by the buildRustCore task.
            java.srcDirs("src/main/kotlin")
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}

dependencies {
    // UniFFI-generated Kotlin uses JNA. JNA needs the @aar variant on Android
    // (the plain jar has no JNI libs for Android targets).
    implementation("net.java.dev.jna:jna:5.14.0@aar")
}

// ---------------------------------------------------------------------------
// Rust cross-compile glue
// ---------------------------------------------------------------------------
// Runs `cargo ndk` to build the Rust core for every Android ABI, then runs
// the UniFFI bindgen to (re)generate the Kotlin wrappers. The Android library
// compile depends on this task so the binaries and Kotlin sources are always
// in sync with the Rust crate.

abstract class CargoNdkBuild @Inject constructor(private val execOps: ExecOperations) : DefaultTask() {

    @get:org.gradle.api.tasks.InputDirectory
    abstract val rustCrateDir: org.gradle.api.file.DirectoryProperty

    @get:org.gradle.api.tasks.OutputDirectory
    abstract val jniLibsOutDir: org.gradle.api.file.DirectoryProperty

    @get:org.gradle.api.tasks.OutputDirectory
    abstract val kotlinBindingsOutDir: org.gradle.api.file.DirectoryProperty

    @TaskAction
    fun build() {
        val rustDir = rustCrateDir.get().asFile
        val jniOut = jniLibsOutDir.get().asFile
        val ktOut = kotlinBindingsOutDir.get().asFile

        // The brew-installed Android NDK isn't in the SDK tree, so point
        // cargo-ndk at it explicitly.
        val ndkHome = System.getenv("ANDROID_NDK_HOME")
            ?: "/opt/homebrew/share/android-ndk"
        val rustupBin = "/opt/homebrew/opt/rustup/bin"
        val cargoBin = "${System.getProperty("user.home")}/.cargo/bin"

        execOps.exec {
            workingDir = rustDir
            environment("ANDROID_NDK_HOME", ndkHome)
            environment(
                "PATH",
                "$rustupBin:$cargoBin:${System.getenv("PATH") ?: ""}"
            )
            commandLine(
                "cargo", "ndk",
                "-t", "arm64-v8a",
                "-t", "armeabi-v7a",
                "-t", "x86_64",
                "-t", "x86",
                "-o", jniOut.absolutePath,
                "build", "--release"
            )
        }

        // Use the freshly built arm64 .so as the source of truth for binding
        // generation (any ABI works — they all share the same FFI surface).
        val soPath = jniOut.resolve("arm64-v8a/libhandstrudel_core.so")
        ktOut.mkdirs()
        execOps.exec {
            workingDir = rustDir
            environment(
                "PATH",
                "$rustupBin:$cargoBin:${System.getenv("PATH") ?: ""}"
            )
            commandLine(
                "cargo", "run", "--quiet", "-p", "handstrudel-core",
                "--bin", "uniffi-bindgen", "--",
                "generate",
                "--library", soPath.absolutePath,
                "--language", "kotlin",
                "--out-dir", ktOut.absolutePath
            )
        }
    }
}

val buildRustCore = tasks.register<CargoNdkBuild>("buildRustCore") {
    rustCrateDir.set(file("../../core"))
    jniLibsOutDir.set(file("src/main/jniLibs"))
    kotlinBindingsOutDir.set(file("src/main/kotlin"))
}

androidComponents {
    onVariants { variant ->
        variant.sources.jniLibs?.addStaticSourceDirectory(file("src/main/jniLibs").absolutePath)
    }
}

tasks.named("preBuild") { dependsOn(buildRustCore) }
