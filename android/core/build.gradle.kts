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
// UniFFI's Kotlin bindgen. Outputs land under `build/generated/...` so the
// Android Gradle plugin can wire them as generated sources — that's what makes
// the downstream merge / packaging tasks invalidate properly when the Rust
// crate changes.

abstract class CargoNdkBuild @Inject constructor(private val execOps: ExecOperations) : DefaultTask() {

    @get:org.gradle.api.tasks.InputFiles
    @get:org.gradle.api.tasks.PathSensitive(org.gradle.api.tasks.PathSensitivity.RELATIVE)
    abstract val rustSources: org.gradle.api.file.ConfigurableFileTree

    @get:org.gradle.api.tasks.OutputDirectory
    abstract val jniLibsOutDir: org.gradle.api.file.DirectoryProperty

    @get:org.gradle.api.tasks.OutputDirectory
    abstract val kotlinBindingsOutDir: org.gradle.api.file.DirectoryProperty

    @get:org.gradle.api.tasks.Internal
    abstract val rustCrateDir: org.gradle.api.file.DirectoryProperty

    @TaskAction
    fun build() {
        val rustDir = rustCrateDir.get().asFile
        val jniOut = jniLibsOutDir.get().asFile
        val ktOut = kotlinBindingsOutDir.get().asFile

        jniOut.mkdirs()
        ktOut.mkdirs()

        // The brew-installed Android NDK isn't in the SDK tree, so point
        // cargo-ndk at it explicitly when ANDROID_NDK_HOME isn't already set.
        val ndkHome = System.getenv("ANDROID_NDK_HOME")
            ?: "/opt/homebrew/share/android-ndk"
        val rustupBin = "/opt/homebrew/opt/rustup/bin"
        val cargoBin = "${System.getProperty("user.home")}/.cargo/bin"
        val extendedPath = "$rustupBin:$cargoBin:${System.getenv("PATH") ?: ""}"

        execOps.exec {
            workingDir = rustDir
            environment("ANDROID_NDK_HOME", ndkHome)
            environment("PATH", extendedPath)
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

        val soPath = jniOut.resolve("arm64-v8a/libhandstrudel_core.so")
        execOps.exec {
            workingDir = rustDir
            environment("PATH", extendedPath)
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

val rustCrateRoot = file("../../core")

val buildRustCore = tasks.register<CargoNdkBuild>("buildRustCore") {
    rustCrateDir.set(rustCrateRoot)
    // Track every file under `core/handstrudel-core/src/` and the Cargo manifests.
    // Excluding target/ avoids triggering rebuilds on cargo's own output.
    rustSources.setDir(rustCrateRoot)
    rustSources.include("Cargo.toml", "handstrudel-core/Cargo.toml", "handstrudel-core/src/**")
    jniLibsOutDir.set(layout.buildDirectory.dir("generated/jniLibs"))
    kotlinBindingsOutDir.set(layout.buildDirectory.dir("generated/uniffi-kotlin"))
}

androidComponents {
    onVariants { variant ->
        // Wire the generated outputs directly to the variant's sources so the
        // merge/packaging tasks correctly depend on buildRustCore and invalidate
        // when its outputs change.
        variant.sources.jniLibs?.addGeneratedSourceDirectory(
            buildRustCore,
            CargoNdkBuild::jniLibsOutDir,
        )
        variant.sources.java?.addGeneratedSourceDirectory(
            buildRustCore,
            CargoNdkBuild::kotlinBindingsOutDir,
        )
    }
}
