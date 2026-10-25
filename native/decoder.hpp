#pragma once
#include <godot_cpp/classes/file_access.hpp>
#include <atomic>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/hwcontext.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
}

struct VideoFrame { double pts = 0; int width = 0, height = 0; std::vector<uint8_t> rgba; };
struct AudioFrame { double pts = 0; std::vector<float> samples; size_t offset = 0; };

// FFmpeg contexts belong to the worker while it is running. Godot textures
// and audio mixing are handled exclusively by the main thread.
class Decoder {
    godot::Ref<godot::FileAccess> file;
    AVFormatContext *format = nullptr;
    AVIOContext *io = nullptr;
    AVCodecContext *video = nullptr, *audio = nullptr;
    SwsContext *scaler = nullptr;
    SwrContext *resampler = nullptr;
    int video_index = -1, audio_index = -1;
    AVPixelFormat hw_format = AV_PIX_FMT_NONE;
    std::thread worker;
    std::atomic<bool> cancel{false};
    std::condition_variable ready;
    double origin = 0, discard_before = 0, next_video_pts = 0, next_audio_pts = 0;
    static int read(void *opaque, uint8_t *data, int size);
    static int64_t seek_io(void *opaque, int64_t offset, int whence);
    static AVPixelFormat choose_format(AVCodecContext *ctx, const AVPixelFormat *formats);
    bool open_video(bool hardware);
    bool open_audio(int track);
    void run();
    bool receive(AVCodecContext *ctx, bool is_video);
    bool push_video(AVFrame *frame);
    bool push_audio(AVFrame *frame);
    void fail(const std::string &message);
public:
    std::mutex mutex;
    std::deque<VideoFrame> frames;
    std::deque<AudioFrame> sound;
    bool eof = false;
    std::string error, backend = "software";
    double duration = 0;
    int width = 0, height = 0, channels = 0, audio_track_count = 0;
    static constexpr int mix_rate = 48000;
    ~Decoder();
    bool open(const godot::String &path, bool hardware, int track);
    bool seek(double seconds);
    bool set_track(int track, double seconds);
    void start();
    void stop_worker();
    void wake() { ready.notify_all(); }
};
