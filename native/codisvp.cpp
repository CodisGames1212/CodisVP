#include "decoder.hpp"
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/resource_format_loader.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/video_stream.hpp>
#include <godot_cpp/classes/video_stream_playback.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <memory>

using namespace godot;

class VideoStreamPlaybackCodisVP : public VideoStreamPlayback {
    GDCLASS(VideoStreamPlaybackCodisVP, VideoStreamPlayback)
    std::unique_ptr<Decoder> decoder;
    Ref<ImageTexture> texture;
    String path, last_error;
    std::atomic<bool> playing{false}, paused{false};
    bool hardware = true, retried = false;
    int track = 0;
    double position = 0, last_frame_end = 0;
    void report(const String &message) {
        last_error = message;
        playing = false;
        UtilityFunctions::push_error("CodisVP: ", message);
        emit_signal("playback_error", message);
    }
    void upload(const VideoFrame &frame) {
        PackedByteArray bytes;
        bytes.resize(frame.rgba.size());
        std::memcpy(bytes.ptrw(), frame.rgba.data(), frame.rgba.size());
        auto image = Image::create_from_data(frame.width, frame.height, false, Image::FORMAT_RGBA8, bytes);
        if (texture->get_width() == frame.width && texture->get_height() == frame.height) texture->update(image);
        else texture->set_image(image);
        last_frame_end = frame.pts + 1.0 / 30.0;
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("get_last_error"), &VideoStreamPlaybackCodisVP::get_last_error);
        ClassDB::bind_method(D_METHOD("get_decoder_backend"), &VideoStreamPlaybackCodisVP::get_decoder_backend);
        ClassDB::bind_method(D_METHOD("get_decoded_audio_channels"), &VideoStreamPlaybackCodisVP::get_decoded_audio_channels);
        ClassDB::bind_method(D_METHOD("get_decoded_audio_track_count"), &VideoStreamPlaybackCodisVP::get_decoded_audio_track_count);
        ClassDB::bind_method(D_METHOD("set_audio_track", "track"), &VideoStreamPlaybackCodisVP::set_audio_track);
        ADD_SIGNAL(MethodInfo("playback_error", PropertyInfo(Variant::STRING, "message")));
    }
public:
    VideoStreamPlaybackCodisVP() { texture.instantiate(); }
    bool initialize(const String &file, bool use_hardware) {
        path = file; hardware = use_hardware;
        decoder = std::make_unique<Decoder>();
        if (!decoder->open(path, hardware, track)) { report(String(decoder->error.c_str())); return false; }
        auto image = Image::create(decoder->width, decoder->height, false, Image::FORMAT_RGBA8);
        image->fill(Color(0, 0, 0, 1));
        texture->set_image(image);
        decoder->start();
        return true;
    }
    String get_last_error() const { return last_error; }
    String get_decoder_backend() const {
        if (!decoder) return String();
        std::lock_guard<std::mutex> lock(decoder->mutex);
        return String(decoder->backend.c_str());
    }
    int get_decoded_audio_channels() const { return decoder ? decoder->channels : 0; }
    int get_decoded_audio_track_count() const { return decoder ? decoder->audio_track_count : 0; }
    void set_audio_track(int32_t value) { _set_audio_track(value); }
    void _play() override {
        if (!decoder || !last_error.is_empty()) return;
        if (decoder->duration > 0 && position >= decoder->duration) _seek(0);
        playing = true;
    }
    void _stop() override {
        playing = false; paused = false;
        if (decoder && last_error.is_empty()) _seek(0);
    }
    bool _is_playing() const override { return playing; }
    void _set_paused(bool value) override { paused = value; }
    bool _is_paused() const override { return paused; }
    double _get_length() const override { return decoder ? decoder->duration : 0; }
    double _get_playback_position() const override { return position; }
    void _seek(double seconds) override {
        if (!decoder || !std::isfinite(seconds)) return;
        seconds = std::max(0.0, seconds);
        if (decoder->duration > 0) seconds = std::min(seconds, decoder->duration);
        if (!decoder->seek(seconds)) { report(String(decoder->error.c_str())); return; }
        position = seconds; last_frame_end = seconds;
        last_error = String();
    }
    void _set_audio_track(int32_t value) override {
        if (track == value || !decoder) return;
        track = value;
        if (!decoder->set_track(track, position)) report(String(decoder->error.c_str()));
    }
    Ref<Texture2D> _get_texture() const override { return texture; }
    int32_t _get_channels() const override { return decoder ? decoder->channels : 0; }
    int32_t _get_mix_rate() const override { return Decoder::mix_rate; }
    void _update(double delta) override {
        if (!playing || paused || !decoder || !std::isfinite(delta)) return;
        std::unique_lock<std::mutex> lock(decoder->mutex);
        if (!decoder->error.empty()) {
            String message(decoder->error.c_str());
            bool retry = hardware && !retried && decoder->backend != "software";
            lock.unlock();
            if (retry) {
                retried = true;
                decoder.reset();
                decoder = std::make_unique<Decoder>();
                if (decoder->open(path, false, track) && decoder->seek(position)) return;
                message = String(decoder->error.c_str());
            }
            report(message);
            return;
        }
        // Hold the media clock during startup/decoder starvation, so a slow
        // decoder does not leave audio and picture behind the playback clock.
        if (decoder->frames.empty() && !decoder->eof && last_frame_end <= position) return;
        position += std::max(0.0, delta);
        VideoFrame newest;
        bool have_frame = false;
        while (!decoder->frames.empty() && decoder->frames.front().pts <= position) {
            newest = std::move(decoder->frames.front()); decoder->frames.pop_front(); have_frame = true;
        }
        // Feed timestamped audio with a short lead. Preserve partial writes
        // when VideoStreamPlayer's audio ring buffer is full.
        while (!decoder->sound.empty()) {
            auto &sound = decoder->sound.front();
            double timestamp = sound.pts + double(sound.offset / 2) / Decoder::mix_rate;
            if (timestamp > position + 0.05) break;
            if (timestamp < position - 0.10) {
                size_t skip = size_t((position - timestamp) * Decoder::mix_rate) * 2;
                sound.offset = std::min(sound.samples.size(), sound.offset + skip);
                timestamp = sound.pts + double(sound.offset / 2) / Decoder::mix_rate;
            }
            int count = int((sound.samples.size() - sound.offset) / 2);
            count = std::min(count, std::max(0, int((position + 0.05 - timestamp) * Decoder::mix_rate)));
            if (sound.offset == sound.samples.size()) { decoder->sound.pop_front(); continue; }
            if (count <= 0) break;
            PackedFloat32Array samples;
            samples.resize(count * 2);
            std::memcpy(samples.ptrw(), sound.samples.data() + sound.offset, size_t(count) * 2 * sizeof(float));
            int mixed = mix_audio(count, samples, 0);
            // Standalone playback objects have no player mixing callback.
            if (mixed < 0) mixed = count;
            if (mixed == 0) break;
            sound.offset += size_t(mixed) * 2;
            if (sound.offset == sound.samples.size()) decoder->sound.pop_front();
        }
        bool done = decoder->eof && decoder->frames.empty() && decoder->sound.empty();
        double duration = decoder->duration;
        lock.unlock();
        decoder->wake();
        if (have_frame) upload(newest);
        if (done && position >= (duration > 0 ? duration : last_frame_end)) playing = false;
    }
};

class VideoStreamCodisVP : public VideoStream {
    GDCLASS(VideoStreamCodisVP, VideoStream)
    bool hardware_decoding = true;
    uint64_t last_playback_id = 0;
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("set_hardware_decoding", "enabled"), &VideoStreamCodisVP::set_hardware_decoding);
        ClassDB::bind_method(D_METHOD("get_hardware_decoding"), &VideoStreamCodisVP::get_hardware_decoding);
        ClassDB::bind_method(D_METHOD("get_last_playback"), &VideoStreamCodisVP::get_last_playback);
        ADD_PROPERTY(PropertyInfo(Variant::BOOL, "hardware_decoding"), "set_hardware_decoding", "get_hardware_decoding");
    }
public:
    void set_hardware_decoding(bool enabled) { hardware_decoding = enabled; }
    bool get_hardware_decoding() const { return hardware_decoding; }
    Ref<VideoStreamPlaybackCodisVP> get_last_playback() const {
        return Ref<VideoStreamPlaybackCodisVP>(Object::cast_to<VideoStreamPlaybackCodisVP>(ObjectDB::get_instance(last_playback_id)));
    }
    Ref<VideoStreamPlayback> _instantiate_playback() override {
        Ref<VideoStreamPlaybackCodisVP> playback;
        playback.instantiate();
        if (!playback->initialize(get_file(), hardware_decoding)) return Ref<VideoStreamPlayback>();
        last_playback_id = playback->get_instance_id();
        return playback;
    }
};

class CodisVPFormatLoader : public ResourceFormatLoader {
    GDCLASS(CodisVPFormatLoader, ResourceFormatLoader)
protected:
    static void _bind_methods() {}
public:
    PackedStringArray _get_recognized_extensions() const override {
        PackedStringArray result;
        for (const char *ext : {"mp4", "m4v", "webm", "mkv", "avi", "mov", "mpeg", "mpg", "ts", "m2ts", "flv", "wmv"}) result.push_back(ext);
        return result;
    }
    bool _handles_type(const StringName &type) const override {
        return type == StringName("VideoStream") || type == StringName("VideoStreamCodisVP");
    }
    String _get_resource_type(const String &path) const override {
        return _get_recognized_extensions().has(path.get_extension().to_lower()) ? "VideoStreamCodisVP" : "";
    }
    Variant _load(const String &path, const String &, bool, int32_t) const override {
        if (!FileAccess::file_exists(path)) return ERR_FILE_NOT_FOUND;
        Ref<VideoStreamCodisVP> stream;
        stream.instantiate(); stream->set_file(path);
        return stream;
    }
};

static Ref<CodisVPFormatLoader> loader;
static void initialize(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    ClassDB::register_class<VideoStreamPlaybackCodisVP>();
    ClassDB::register_class<VideoStreamCodisVP>();
    ClassDB::register_class<CodisVPFormatLoader>();
    loader.instantiate();
    ResourceLoader::get_singleton()->add_resource_format_loader(loader, true);
}
static void uninitialize(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    ResourceLoader::get_singleton()->remove_resource_format_loader(loader);
    loader.unref();
}
extern "C" {
GDExtensionBool GDE_EXPORT codisvp_library_init(GDExtensionInterfaceGetProcAddress get_proc_address,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize);
    init.register_terminator(uninitialize);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
