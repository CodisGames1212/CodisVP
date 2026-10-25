#include "decoder.hpp"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>
extern "C" {
#include <libavutil/imgutils.h>
#include <libavutil/pixdesc.h>
#include <libavutil/opt.h>
}

static std::string av_error(int code) {
    char buffer[AV_ERROR_MAX_STRING_SIZE];
    av_strerror(code, buffer, sizeof(buffer));
    return buffer;
}

int Decoder::read(void *opaque, uint8_t *data, int size) {
    auto *self = static_cast<Decoder *>(opaque);
    if (self->cancel) return AVERROR_EXIT;
    auto bytes = self->file->get_buffer(size);
    if (bytes.is_empty()) return AVERROR_EOF;
    std::memcpy(data, bytes.ptr(), bytes.size());
    return int(bytes.size());
}

int64_t Decoder::seek_io(void *opaque, int64_t offset, int whence) {
    auto &file = static_cast<Decoder *>(opaque)->file;
    if (whence & AVSEEK_SIZE) return int64_t(file->get_length());
    whence &= ~AVSEEK_FORCE;
    int64_t target = offset;
    if (whence == SEEK_CUR) target += int64_t(file->get_position());
    else if (whence == SEEK_END) target += int64_t(file->get_length());
    else if (whence != SEEK_SET) return AVERROR(EINVAL);
    if (target < 0 || uint64_t(target) > file->get_length()) return AVERROR(EINVAL);
    file->seek(target);
    return int64_t(file->get_position());
}

AVPixelFormat Decoder::choose_format(AVCodecContext *ctx, const AVPixelFormat *formats) {
    auto *self = static_cast<Decoder *>(ctx->opaque);
    for (auto p = formats; *p != AV_PIX_FMT_NONE; ++p)
        if (*p == self->hw_format) return *p;
    for (auto p = formats; *p != AV_PIX_FMT_NONE; ++p) {
        auto desc = av_pix_fmt_desc_get(*p);
        if (desc && !(desc->flags & AV_PIX_FMT_FLAG_HWACCEL)) {
            std::lock_guard<std::mutex> lock(self->mutex);
            self->backend = "software";
            return *p;
        }
    }
    return AV_PIX_FMT_NONE;
}

bool Decoder::open_video(bool hardware) {
    avcodec_free_context(&video);
    const AVCodec *codec = avcodec_find_decoder(format->streams[video_index]->codecpar->codec_id);
#if defined(__ANDROID__)
    if (hardware && codec) {
        std::string name = std::string(avcodec_get_name(codec->id)) + "_mediacodec";
        if (const AVCodec *ndk = avcodec_find_decoder_by_name(name.c_str())) codec = ndk;
    }
#endif
    if (!codec) { error = "No FFmpeg decoder for this video codec"; return false; }
    video = avcodec_alloc_context3(codec);
    if (!video) { error = "Cannot allocate video decoder"; return false; }
    int result = avcodec_parameters_to_context(video, format->streams[video_index]->codecpar);
    if (result < 0) { error = av_error(result); return false; }
    video->thread_count = 2;
    backend = "software";
    hw_format = AV_PIX_FMT_NONE;
#if defined(__ANDROID__)
    if (hardware && std::strstr(codec->name, "mediacodec")) {
        // NDK byte-buffer decoding avoids requiring a Java VM or a Surface.
        av_opt_set_int(video->priv_data, "ndk_codec", 1, 0);
        backend = "mediacodec";
    }
#else
    if (hardware) {
#if defined(_WIN32)
        const AVHWDeviceType types[] = {AV_HWDEVICE_TYPE_CUDA, AV_HWDEVICE_TYPE_D3D11VA};
#elif defined(__APPLE__)
        const AVHWDeviceType types[] = {AV_HWDEVICE_TYPE_VIDEOTOOLBOX};
#else
        const AVHWDeviceType types[] = {AV_HWDEVICE_TYPE_VAAPI, AV_HWDEVICE_TYPE_CUDA};
#endif
        for (auto type : types) {
            for (int i = 0; ; ++i) {
                const AVCodecHWConfig *config = avcodec_get_hw_config(codec, i);
                if (!config) break;
                if (config->device_type != type || !(config->methods & AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX)) continue;
                AVBufferRef *device = nullptr;
                if (av_hwdevice_ctx_create(&device, type, nullptr, nullptr, 0) < 0) continue;
                video->hw_device_ctx = device;
                video->opaque = this;
                video->get_format = choose_format;
                hw_format = config->pix_fmt;
                backend = av_hwdevice_get_type_name(type);
                break;
            }
            if (video->hw_device_ctx) break;
        }
    }
#endif
    result = avcodec_open2(video, codec, nullptr);
    if (result < 0 && hardware) return open_video(false);
    if (result < 0) { error = av_error(result); return false; }
    return true;
}

bool Decoder::open_audio(int track) {
    avcodec_free_context(&audio);
    swr_free(&resampler);
    audio_index = -1;
    channels = 0;
    int ordinal = 0;
    for (unsigned i = 0; i < format->nb_streams; ++i) {
        if (format->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO && ordinal++ == track) {
            audio_index = int(i); break;
        }
    }
    if (audio_index < 0) return true;
    auto parameters = format->streams[audio_index]->codecpar;
    const AVCodec *codec = avcodec_find_decoder(parameters->codec_id);
    if (!codec) { error = "No FFmpeg decoder for the selected audio track"; return false; }
    audio = avcodec_alloc_context3(codec);
    if (!audio) { error = "Cannot allocate audio decoder"; return false; }
    int result = avcodec_parameters_to_context(audio, parameters);
    if (result >= 0) result = avcodec_open2(audio, codec, nullptr);
    if (result < 0) { error = av_error(result); return false; }
    AVChannelLayout stereo = AV_CHANNEL_LAYOUT_STEREO;
    result = swr_alloc_set_opts2(&resampler, &stereo, AV_SAMPLE_FMT_FLT, mix_rate,
        &audio->ch_layout, audio->sample_fmt, audio->sample_rate, 0, nullptr);
    if (result >= 0) result = swr_init(resampler);
    if (result < 0) { error = av_error(result); return false; }
    channels = 2;
    return true;
}

bool Decoder::open(const godot::String &path, bool hardware, int track) {
    file = godot::FileAccess::open(path, godot::FileAccess::READ);
    if (file.is_null()) { error = "Cannot open video file: " + std::string(path.utf8().get_data()); return false; }
    auto buffer = static_cast<uint8_t *>(av_malloc(32768));
    if (!buffer) { error = "Cannot allocate file buffer"; return false; }
    io = avio_alloc_context(buffer, 32768, 0, this, read, nullptr, seek_io);
    if (!io) { av_free(buffer); error = "Cannot allocate file reader"; return false; }
    format = avformat_alloc_context();
    if (!format) { error = "Cannot allocate demuxer"; return false; }
    format->pb = io;
    format->flags |= AVFMT_FLAG_CUSTOM_IO;
    int result = avformat_open_input(&format, nullptr, nullptr, nullptr);
    if (result >= 0) result = avformat_find_stream_info(format, nullptr);
    if (result < 0) { error = av_error(result); return false; }
    audio_track_count = 0;
    for (unsigned i = 0; i < format->nb_streams; ++i) {
        if (format->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) ++audio_track_count;
    }
    video_index = av_find_best_stream(format, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (video_index < 0) { error = "File has no playable video stream"; return false; }
    origin = format->start_time == AV_NOPTS_VALUE ? 0 : double(format->start_time) / AV_TIME_BASE;
    duration = format->duration == AV_NOPTS_VALUE ? 0 : std::max(0.0, double(format->duration) / AV_TIME_BASE);
    if (!open_video(hardware) || !open_audio(track)) return false;
    width = video->width; height = video->height;
    if (width <= 0 || height <= 0 || int64_t(width) * height > 67108864) { error = "Invalid or oversized video dimensions"; return false; }
    return true;
}

void Decoder::fail(const std::string &message) {
    std::lock_guard<std::mutex> lock(mutex);
    error = message;
    eof = true;
}

bool Decoder::push_video(AVFrame *source) {
    double pts = source->best_effort_timestamp == AV_NOPTS_VALUE ? next_video_pts :
        source->best_effort_timestamp * av_q2d(format->streams[video_index]->time_base) - origin;
    auto rate = av_guess_frame_rate(format, format->streams[video_index], nullptr);
    next_video_pts = pts + (rate.num > 0 ? av_q2d(av_inv_q(rate)) : 1.0 / 30.0);
    if (pts + 0.0001 < discard_before) return true;
    AVFrame *transferred = nullptr;
    AVFrame *frame = source;
    if (source->format == hw_format && hw_format != AV_PIX_FMT_NONE) {
        transferred = av_frame_alloc();
        int result = transferred ? av_hwframe_transfer_data(transferred, source, 0) : AVERROR(ENOMEM);
        if (result < 0) { av_frame_free(&transferred); fail("Hardware frame transfer: " + av_error(result)); return false; }
        frame = transferred;
    }
    if (frame->width <= 0 || frame->height <= 0 || int64_t(frame->width) * frame->height > 67108864) {
        av_frame_free(&transferred); fail("Invalid decoded dimensions"); return false;
    }
    VideoFrame output;
    output.pts = std::max(0.0, pts); output.width = frame->width; output.height = frame->height;
    output.rgba.resize(size_t(frame->width) * frame->height * 4);
    scaler = sws_getCachedContext(scaler, frame->width, frame->height, AVPixelFormat(frame->format),
        frame->width, frame->height, AV_PIX_FMT_RGBA, SWS_BILINEAR, nullptr, nullptr, nullptr);
    if (!scaler) { av_frame_free(&transferred); fail("Cannot allocate color converter"); return false; }
    int colorspace = frame->colorspace == AVCOL_SPC_BT709 ? SWS_CS_ITU709 :
        (frame->colorspace == AVCOL_SPC_BT2020_NCL ? SWS_CS_BT2020 : SWS_CS_DEFAULT);
    const int *coefficients = sws_getCoefficients(colorspace);
    sws_setColorspaceDetails(scaler, coefficients, frame->color_range == AVCOL_RANGE_JPEG,
        coefficients, 1, 0, 1 << 16, 1 << 16);
    uint8_t *planes[] = {output.rgba.data(), nullptr, nullptr, nullptr};
    int strides[] = {frame->width * 4, 0, 0, 0};
    int result = sws_scale(scaler, frame->data, frame->linesize, 0, frame->height, planes, strides);
    av_frame_free(&transferred);
    if (result <= 0) { fail("Cannot convert video frame"); return false; }
    std::unique_lock<std::mutex> lock(mutex);
    ready.wait(lock, [&] { return cancel || frames.size() < 8; });
    if (cancel) return false;
    frames.push_back(std::move(output));
    return true;
}

bool Decoder::push_audio(AVFrame *frame) {
    double pts = frame->best_effort_timestamp == AV_NOPTS_VALUE ? next_audio_pts :
        frame->best_effort_timestamp * av_q2d(format->streams[audio_index]->time_base) - origin;
    int count = int(av_rescale_rnd(swr_get_delay(resampler, audio->sample_rate) + frame->nb_samples,
        mix_rate, audio->sample_rate, AV_ROUND_UP));
    AudioFrame output;
    output.pts = pts - double(swr_get_delay(resampler, mix_rate)) / mix_rate;
    output.samples.resize(size_t(count) * 2);
    uint8_t *data = reinterpret_cast<uint8_t *>(output.samples.data());
    count = swr_convert(resampler, &data, count, const_cast<const uint8_t **>(frame->extended_data), frame->nb_samples);
    if (count < 0) { fail("Audio resampling: " + av_error(count)); return false; }
    output.samples.resize(size_t(count) * 2);
    next_audio_pts = output.pts + double(count) / mix_rate;
    if (next_audio_pts <= discard_before || count == 0) return true;
    if (output.pts < discard_before) output.offset = std::min(size_t(count), size_t(std::ceil((discard_before - output.pts) * mix_rate))) * 2;
    std::unique_lock<std::mutex> lock(mutex);
    ready.wait(lock, [&] { return cancel || sound.size() < 96; });
    if (cancel) return false;
    sound.push_back(std::move(output));
    return true;
}

bool Decoder::receive(AVCodecContext *ctx, bool is_video) {
    AVFrame *frame = av_frame_alloc();
    if (!frame) { fail("Cannot allocate decoded frame"); return false; }
    int result;
    bool ok = true;
    while (!cancel && (result = avcodec_receive_frame(ctx, frame)) >= 0) {
        ok = is_video ? push_video(frame) : push_audio(frame);
        av_frame_unref(frame);
        if (!ok) break;
    }
    if (ok && !cancel && result != AVERROR(EAGAIN) && result != AVERROR_EOF) { fail("Decode: " + av_error(result)); ok = false; }
    av_frame_free(&frame);
    return ok && !cancel;
}

void Decoder::run() {
    AVPacket *packet = av_packet_alloc();
    if (!packet) { fail("Cannot allocate packet"); return; }
    int result = 0;
    bool ok = true;
    while (!cancel && (result = av_read_frame(format, packet)) >= 0) {
        AVCodecContext *ctx = packet->stream_index == video_index ? video :
            (packet->stream_index == audio_index ? audio : nullptr);
        if (ctx) {
            int sent = avcodec_send_packet(ctx, packet);
            if (sent == AVERROR(EAGAIN)) {
                ok = receive(ctx, ctx == video);
                if (ok) sent = avcodec_send_packet(ctx, packet);
            }
            if (ok && sent < 0) { fail("Decode packet: " + av_error(sent)); ok = false; }
            if (ok) ok = receive(ctx, ctx == video);
        }
        av_packet_unref(packet);
        if (!ok) break;
    }
    if (!cancel && ok) {
        if (result != AVERROR_EOF) fail("Read packet: " + av_error(result));
        else {
            avcodec_send_packet(video, nullptr); receive(video, true);
            if (audio && !cancel) { avcodec_send_packet(audio, nullptr); receive(audio, false); }
            std::lock_guard<std::mutex> lock(mutex);
            eof = true;
        }
    }
    av_packet_free(&packet);
}

void Decoder::start() { cancel = false; worker = std::thread(&Decoder::run, this); }
void Decoder::stop_worker() { cancel = true; ready.notify_all(); if (worker.joinable()) worker.join(); cancel = false; }

bool Decoder::seek(double seconds) {
    stop_worker();
    int result = avformat_seek_file(format, -1, std::numeric_limits<int64_t>::min(),
        int64_t((seconds + origin) * AV_TIME_BASE), std::numeric_limits<int64_t>::max(), AVSEEK_FLAG_BACKWARD);
    if (result < 0) { error = "Seek: " + av_error(result); return false; }
    avcodec_flush_buffers(video);
    if (audio) avcodec_flush_buffers(audio);
    if (resampler) { swr_close(resampler); swr_init(resampler); }
    { std::lock_guard<std::mutex> lock(mutex); frames.clear(); sound.clear(); eof = false; error.clear(); }
    discard_before = seconds; next_video_pts = seconds; next_audio_pts = seconds;
    start();
    return true;
}

bool Decoder::set_track(int track, double seconds) {
    stop_worker();
    if (!open_audio(track)) return false;
    return seek(seconds);
}

Decoder::~Decoder() {
    stop_worker();
    avcodec_free_context(&video); avcodec_free_context(&audio);
    swr_free(&resampler); sws_freeContext(scaler);
    avformat_close_input(&format);
    if (io) { av_freep(&io->buffer); avio_context_free(&io); }
}
