// JNI wrapper around TinySoundFont for com.handstrudel.engine.audio.TinySoundFont.
// Uses TSF's MIDI channel API so the Kotlin SoundFontEngine can mirror iOS
// AVAudioUnitSampler channel routing (one sustained voice per channel, a
// one-shot channel for accents, CC120-style hard stops per channel).

#include <jni.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <mutex>

#define TSF_IMPLEMENTATION
#include "tsf.h"
#include "sampler_levels.h"
#include <cmath>

namespace {

struct SfHandle {
    tsf* synth = nullptr;
    // TSF isn't thread-safe: the main thread posts note events while the
    // audio thread renders.
    std::mutex mu;
};

inline SfHandle* fromPtr(jlong h) { return reinterpret_cast<SfHandle*>(h); }

} // namespace

#define TSF_FN(name) Java_com_handstrudel_engine_audio_TinySoundFont_##name
#define LOCKED(h) SfHandle* sh = fromPtr(h); if (sh == nullptr || sh->synth == nullptr) return; std::lock_guard<std::mutex> lock(sh->mu)
#define LOCKED_RET(h, r) SfHandle* sh = fromPtr(h); if (sh == nullptr || sh->synth == nullptr) return r; std::lock_guard<std::mutex> lock(sh->mu)

namespace {
jlong finishLoad(tsf* s, jint sampleRate, jfloat gainDb) {
    if (s == nullptr) return 0L;
    tsf_set_output(s, TSF_STEREO_INTERLEAVED, static_cast<int>(sampleRate), gainDb);
    tsf_set_max_voices(s, 96);
    // Allocate all 16 MIDI channels up front (GM bank 0, program 0).
    for (int ch = 0; ch < 16; ch++) tsf_channel_set_bank_preset(s, ch, 0, 0);
    auto* h = new SfHandle{};
    h->synth = s;
    return reinterpret_cast<jlong>(h);
}
} // namespace

// Reads the .sf2 straight from the APK in native memory, so the ~32 MB font never
// lands on the Java heap (Android 10 devices can cap apps at 48 MB of heap).
extern "C" JNIEXPORT jlong JNICALL
TSF_FN(nativeLoadAsset)(JNIEnv* env, jclass, jobject assetManager, jstring path, jint sampleRate, jfloat gainDb) {
    if (assetManager == nullptr || path == nullptr) return 0L;
    AAssetManager* am = AAssetManager_fromJava(env, assetManager);
    if (am == nullptr) return 0L;
    const char* cpath = env->GetStringUTFChars(path, nullptr);
    if (cpath == nullptr) return 0L;
    AAsset* asset = AAssetManager_open(am, cpath, AASSET_MODE_BUFFER);
    env->ReleaseStringUTFChars(path, cpath);
    if (asset == nullptr) return 0L;
    const void* buf = AAsset_getBuffer(asset);
    off_t len = AAsset_getLength(asset);
    tsf* s = (buf != nullptr && len > 0) ? tsf_load_memory(buf, static_cast<int>(len)) : nullptr;
    AAsset_close(asset);
    return finishLoad(s, sampleRate, gainDb);
}

extern "C" JNIEXPORT jlong JNICALL
TSF_FN(nativeLoad)(JNIEnv* env, jclass, jbyteArray sf2Bytes, jint sampleRate, jfloat gainDb) {
    if (sf2Bytes == nullptr) return 0L;
    jsize len = env->GetArrayLength(sf2Bytes);
    jbyte* data = env->GetByteArrayElements(sf2Bytes, nullptr);
    if (data == nullptr) return 0L;
    tsf* s = tsf_load_memory(data, static_cast<int>(len));
    env->ReleaseByteArrayElements(sf2Bytes, data, JNI_ABORT);
    if (s == nullptr) return 0L;
    tsf_set_output(s, TSF_STEREO_INTERLEAVED, static_cast<int>(sampleRate), gainDb);
    tsf_set_max_voices(s, 96);
    // Allocate all 16 MIDI channels up front (GM bank 0, program 0).
    for (int ch = 0; ch < 16; ch++) tsf_channel_set_bank_preset(s, ch, 0, 0);
    auto* h = new SfHandle{};
    h->synth = s;
    return reinterpret_cast<jlong>(h);
}

extern "C" JNIEXPORT void JNICALL
TSF_FN(nativeClose)(JNIEnv*, jclass, jlong handle) {
    SfHandle* h = fromPtr(handle);
    if (h == nullptr) return;
    {
        std::lock_guard<std::mutex> lock(h->mu);
        if (h->synth) tsf_close(h->synth);
        h->synth = nullptr;
    }
    delete h;
}

/** Sets `program` (GM bank 0) on every channel; returns false if the font lacks it. */
extern "C" JNIEXPORT jboolean JNICALL
TSF_FN(nativeSetProgram)(JNIEnv*, jclass, jlong handle, jint program) {
    LOCKED_RET(handle, JNI_FALSE);
    if (tsf_get_presetindex(sh->synth, 0, program) < 0) return JNI_FALSE;
    // Match iOS AVAudioUnitSampler's level for this instrument (see sampler_levels.h).
    const float trim = (program >= 0 && program < 128) ? std::pow(10.0f, kSamplerLevelTrimDb[program] / 20.0f) : 1.0f;
    for (int ch = 0; ch < 16; ch++) {
        tsf_channel_set_bank_preset(sh->synth, ch, 0, program);
        tsf_channel_set_volume(sh->synth, ch, trim);
    }
    return JNI_TRUE;
}

extern "C" JNIEXPORT void JNICALL
TSF_FN(nativeChannelNoteOn)(JNIEnv*, jclass, jlong handle, jint channel, jint key, jfloat velocity) {
    LOCKED(handle);
    tsf_channel_note_on(sh->synth, channel, key, velocity);
}

extern "C" JNIEXPORT void JNICALL
TSF_FN(nativeChannelNoteOff)(JNIEnv*, jclass, jlong handle, jint channel, jint key) {
    LOCKED(handle);
    tsf_channel_note_off(sh->synth, channel, key);
}

/** MIDI CC 120 (All Sound Off): cut every voice on the channel immediately. */
extern "C" JNIEXPORT void JNICALL
TSF_FN(nativeChannelSoundsOff)(JNIEnv*, jclass, jlong handle, jint channel) {
    LOCKED(handle);
    tsf_channel_sounds_off_all(sh->synth, channel);
}

/** MIDI CC 123 (All Notes Off): release with the normal envelope. */
extern "C" JNIEXPORT void JNICALL
TSF_FN(nativeChannelNotesOff)(JNIEnv*, jclass, jlong handle, jint channel) {
    LOCKED(handle);
    tsf_channel_note_off_all(sh->synth, channel);
}

extern "C" JNIEXPORT jint JNICALL
TSF_FN(nativeActiveVoices)(JNIEnv*, jclass, jlong handle) {
    LOCKED_RET(handle, 0);
    return tsf_active_voice_count(sh->synth);
}

extern "C" JNIEXPORT void JNICALL
TSF_FN(nativeRender)(JNIEnv* env, jclass, jlong handle, jfloatArray outBuffer, jint frames) {
    SfHandle* h = fromPtr(handle);
    if (h == nullptr) return;
    jfloat* out = env->GetFloatArrayElements(outBuffer, nullptr);
    if (out == nullptr) return;
    {
        std::lock_guard<std::mutex> lock(h->mu);
        if (h->synth) tsf_render_float(h->synth, out, static_cast<int>(frames), 0);
    }
    env->ReleaseFloatArrayElements(outBuffer, out, 0);
}
