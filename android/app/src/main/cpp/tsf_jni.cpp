// JNI wrapper around TinySoundFont — lets Kotlin load a SoundFont, fire
// noteOn/noteOff, and render PCM blocks into a short[] buffer for the
// existing SynthEngine audio thread to mix.

#include <jni.h>
#include <mutex>
#include <string>

#define TSF_IMPLEMENTATION
#include "tsf.h"

namespace {

struct SfHandle {
    tsf* synth = nullptr;
    // tsf_note_on/off are not safe across threads — guard with a mutex so
    // the Kotlin UI thread can post note events while the audio thread is
    // rendering.
    std::mutex mu;
};

inline SfHandle* fromPtr(jlong h) {
    return reinterpret_cast<SfHandle*>(h);
}

} // anonymous namespace

extern "C"
JNIEXPORT jlong JNICALL
Java_com_handstrudel_engine_synth_SoundFontEngine_nativeLoad(
        JNIEnv* env, jclass, jbyteArray sf2Bytes, jint sampleRate, jfloat gainDb) {
    if (sf2Bytes == nullptr) return 0L;
    jsize len = env->GetArrayLength(sf2Bytes);
    jbyte* data = env->GetByteArrayElements(sf2Bytes, nullptr);
    if (data == nullptr) return 0L;

    tsf* s = tsf_load_memory(data, static_cast<int>(len));
    env->ReleaseByteArrayElements(sf2Bytes, data, JNI_ABORT);
    if (s == nullptr) return 0L;

    // Stereo interleaved short output, with the requested sample rate and
    // master gain. Setting gain slightly below unity prevents clipping when
    // many voices stack (each voice is ~1.0-ish in TSF's float pipeline).
    tsf_set_output(s, TSF_STEREO_INTERLEAVED, static_cast<int>(sampleRate), gainDb);
    tsf_set_max_voices(s, 64);

    auto* h = new SfHandle{};
    h->synth = s;
    return reinterpret_cast<jlong>(h);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_handstrudel_engine_synth_SoundFontEngine_nativeClose(
        JNIEnv*, jclass, jlong handle) {
    SfHandle* h = fromPtr(handle);
    if (h == nullptr) return;
    std::lock_guard<std::mutex> lock(h->mu);
    if (h->synth) tsf_close(h->synth);
    h->synth = nullptr;
    delete h;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_handstrudel_engine_synth_SoundFontEngine_nativeNoteOn(
        JNIEnv*, jclass, jlong handle, jint preset, jint midi, jfloat velocity) {
    SfHandle* h = fromPtr(handle);
    if (h == nullptr || h->synth == nullptr) return;
    std::lock_guard<std::mutex> lock(h->mu);
    tsf_note_on(h->synth, static_cast<int>(preset), static_cast<int>(midi), velocity);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_handstrudel_engine_synth_SoundFontEngine_nativeNoteOff(
        JNIEnv*, jclass, jlong handle, jint preset, jint midi) {
    SfHandle* h = fromPtr(handle);
    if (h == nullptr || h->synth == nullptr) return;
    std::lock_guard<std::mutex> lock(h->mu);
    tsf_note_off(h->synth, static_cast<int>(preset), static_cast<int>(midi));
}

extern "C"
JNIEXPORT void JNICALL
Java_com_handstrudel_engine_synth_SoundFontEngine_nativeAllNotesOff(
        JNIEnv*, jclass, jlong handle) {
    SfHandle* h = fromPtr(handle);
    if (h == nullptr || h->synth == nullptr) return;
    std::lock_guard<std::mutex> lock(h->mu);
    tsf_note_off_all(h->synth);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_handstrudel_engine_synth_SoundFontEngine_nativeRender(
        JNIEnv* env, jclass, jlong handle, jshortArray outBuffer, jint sampleCount, jboolean mix) {
    SfHandle* h = fromPtr(handle);
    if (h == nullptr || h->synth == nullptr) return;
    jshort* out = env->GetShortArrayElements(outBuffer, nullptr);
    if (out == nullptr) return;
    {
        std::lock_guard<std::mutex> lock(h->mu);
        // sampleCount is the number of stereo frames; TSF writes
        // sampleCount * 2 interleaved shorts.
        tsf_render_short(h->synth, out, static_cast<int>(sampleCount), mix ? 1 : 0);
    }
    env->ReleaseShortArrayElements(outBuffer, out, 0);
}
