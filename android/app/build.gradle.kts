plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// ---------------------------------------------------------------------------
// Backend config → BuildConfig (integrator-owned; see docs/android-parity.md 3.0)
// ---------------------------------------------------------------------------
// One source of truth: the production values are parsed from the iOS
// SocialConfig.swift at configuration time, so nobody copies the Supabase key
// by hand. Gradle properties override them (local stacks). Values are never
// logged or printed.
val iosSocialConfig: String = rootProject.file("../ios/HandStrudel/HandStrudel/Social/SocialConfig.swift")
    .takeIf { it.isFile }?.readText() ?: ""

fun swiftConstant(name: String): String =
    Regex("""static\s+let\s+$name\s*=\s*"([^"]*)"""").find(iosSocialConfig)?.groupValues?.get(1) ?: ""

fun configValue(property: String, fallback: String, env: String? = null): String {
    val fromProperty = (project.findProperty(property) as String?)?.takeIf { it.isNotBlank() }
    val fromEnv = env?.let { System.getenv(it) }?.takeIf { it.isNotBlank() }
    return fromProperty ?: fromEnv ?: fallback
}

fun buildConfigString(value: String): String =
    "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

android {
    namespace = "com.handstrudel"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.handstrudel.app"
        // 29: AudioPlaybackCaptureConfiguration (app-audio recording/loops) and
        // scoped MediaStore writes without storage permission.
        minSdk = 29
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        buildConfigField("String", "SUPABASE_URL",
            buildConfigString(configValue("handstrudel.supabaseUrl", swiftConstant("productionURL"))))
        buildConfigField("String", "SUPABASE_ANON_KEY",
            buildConfigString(configValue("handstrudel.supabaseAnonKey", swiftConstant("productionAnonKey"))))
        buildConfigField("String", "MEDIA_BASE_URL",
            buildConfigString(configValue("handstrudel.mediaBaseUrl", swiftConstant("productionMediaBase"))))
        buildConfigField("String", "CLIP_MEDIA_BASE_URL",
            buildConfigString(configValue("handstrudel.clipMediaBaseUrl", swiftConstant("productionClipMediaBase"))))
        buildConfigField("String", "REVENUECAT_API_KEY",
            buildConfigString(configValue("handstrudel.revenuecatApiKey", "", env = "REVENUECAT_ANDROID_API_KEY")))
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID",
            buildConfigString(configValue("handstrudel.googleWebClientId", "")))

        // Build the TinySoundFont JNI wrapper (`libhandstrudel_tsf.so`) for
        // every ABI we ship. The .cpp lives in src/main/cpp and shares the
        // abiFilters declared in the `ndk { ... }` block above with the Rust
        // core's jniLibs.
        externalNativeBuild {
            cmake { cppFlags += listOf("-std=c++17") }
        }
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    testOptions {
        // JVM unit tests run against android.jar stubs; never load the :core .so.
        unitTests.isReturnDefaultValues = true
    }

    packaging {
        resources {
            excludes += setOf("/META-INF/{AL2.0,LGPL2.1}", "/META-INF/INDEX.LIST", "/META-INF/io.netty.versions.properties")
        }
    }
}

// ---------------------------------------------------------------------------
// Workstream-owned Gradle tasks go in their own marked blocks.
// ---------------------------------------------------------------------------

// --- engine (assets) ---
// The Strudel engine (HTML, bundle, sampled instruments) is the iOS one, copied
// at build time into generated assets under `strudel/` (served to the WebView
// by StrudelAssets). Nothing is duplicated in git. The bundle is rebuilt with
// `node ios/bundle-strudel.mjs` only if it is missing.
val iosResources = rootProject.file("../ios/HandStrudel/HandStrudel/Resources")
val strudelAssetsOut = layout.buildDirectory.dir("generated/assets/strudel")
val generateStrudelAssets by tasks.registering(Copy::class) {
    description = "Copies the iOS Strudel engine and instrument samples into Android assets."
    doFirst {
        if (!File(iosResources, "strudel-bundle.js").isFile) {
            val iosDir = rootProject.file("../ios")
            val proc = ProcessBuilder("node", "bundle-strudel.mjs").directory(iosDir).inheritIO().start()
            check(proc.waitFor() == 0) { "node ios/bundle-strudel.mjs failed" }
        }
    }
    from(iosResources) {
        include("strudel-engine.html", "strudel-bundle.js", "instrument-samples/**")
    }
    into(strudelAssetsOut.map { it.dir("strudel") })
}
android.sourceSets.getByName("main").assets.srcDir(strudelAssetsOut)
tasks.named("preBuild") { dependsOn(generateStrudelAssets) }
// --- end engine (assets) ---

dependencies {
    // --- integrator ---
    // Shared music logic compiled from Rust via UniFFI.
    implementation(project(":core"))

    // Compose
    val composeBom = platform("androidx.compose:compose-bom:2024.10.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")

    // CameraX
    val cameraVersion = "1.4.0"
    implementation("androidx.camera:camera-core:$cameraVersion")
    implementation("androidx.camera:camera-camera2:$cameraVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraVersion")
    implementation("androidx.camera:camera-view:$cameraVersion")

    // MediaPipe hand landmarks
    implementation("com.google.mediapipe:tasks-vision:0.10.18")

    // Core
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    // JVM unit tests (AT/). Pure Kotlin only: never load the :core .so here.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    testImplementation("org.json:json:20240303")
    // --- end integrator ---

    // The versions below were resolved and compiled together against
    // Kotlin 2.0.21 / AGP 8.7.0 in Phase 0. Each WS edits only its own block.

    // --- shell ---
    implementation("androidx.datastore:datastore-preferences:1.1.1")
    implementation("com.google.android.play:review-ktx:2.0.2")
    implementation("androidx.browser:browser:1.8.0")
    // --- end shell ---

    // --- engine ---
    implementation("androidx.webkit:webkit:1.12.1")
    // --- end engine ---

    // --- studio-ui ---
    implementation("androidx.compose.material:material-icons-extended")
    // --- end studio-ui ---

    // --- capture ---
    implementation("androidx.media3:media3-transformer:1.4.1")
    implementation("androidx.media3:media3-effect:1.4.1")
    implementation("androidx.media3:media3-exoplayer:1.4.1")
    implementation("androidx.media3:media3-ui:1.4.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.google.zxing:core:3.5.3")
    implementation("androidx.lifecycle:lifecycle-service:2.8.7")
    // --- end capture ---

    // --- social ---
    // supabase-kt 3.0.2 is the newest release built with Kotlin 2.0.21 (3.0.3+ needs 2.1).
    implementation(platform("io.github.jan-tennert.supabase:bom:3.0.2"))
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:functions-kt")
    implementation("io.ktor:ktor-client-okhttp:3.0.1")
    implementation("androidx.media3:media3-exoplayer:1.4.1")
    implementation("androidx.media3:media3-ui:1.4.1")
    implementation("androidx.media3:media3-datasource-okhttp:1.4.1")
    implementation("io.coil-kt.coil3:coil-compose:3.0.4")
    implementation("io.coil-kt.coil3:coil-network-okhttp:3.0.4")
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
    // PostgREST/Functions transport (SupabaseRest) and ExoPlayer's data source share one client.
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    // --- end social ---

    // --- store ---
    implementation("com.revenuecat.purchases:purchases:8.10.8")
    implementation("com.revenuecat.purchases:purchases-ui:8.10.8")
    // --- end store ---
}
