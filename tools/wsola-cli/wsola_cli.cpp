// wsola-cli: time-stretches a WAV file with the WSOLA port used by the MLT
// "wsola" module, to compare by ear with Chrome's playbackRate.
//
//   wsola-cli input.wav [-o folder] [rate ...]     (default: 1.1 2)
//
// Writes <name>.<rate>x.wav for each rate. 16-bit input stays 16-bit,
// anything else is written as 32-bit float.

#include "wsola_algorithm.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

struct Wav
{
    int channels = 0;
    int sample_rate = 0;
    int bits = 0;
    bool is_float = false;
    std::vector<float> samples; // interleaved
    int frames() const { return channels ? static_cast<int>(samples.size() / channels) : 0; }
};

static uint32_t le32(const uint8_t *p)
{
    return p[0] | (p[1] << 8) | (p[2] << 16) | (uint32_t(p[3]) << 24);
}
static uint16_t le16(const uint8_t *p)
{
    return p[0] | (p[1] << 8);
}

static bool read_wav(const fs::path &path, Wav &wav, std::string &err)
{
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        err = "cannot open";
        return false;
    }
    std::vector<uint8_t> buf((std::istreambuf_iterator<char>(in)), {});
    if (buf.size() < 12 || memcmp(buf.data(), "RIFF", 4) || memcmp(buf.data() + 8, "WAVE", 4)) {
        err = "not a RIFF/WAVE file";
        return false;
    }
    int format = 0;
    const uint8_t *data = nullptr;
    size_t data_size = 0;
    for (size_t pos = 12; pos + 8 <= buf.size();) {
        const uint8_t *chunk = buf.data() + pos;
        size_t size = le32(chunk + 4);
        size_t avail = std::min(size, buf.size() - pos - 8);
        if (!memcmp(chunk, "fmt ", 4) && avail >= 16) {
            format = le16(chunk + 8);
            wav.channels = le16(chunk + 10);
            wav.sample_rate = le32(chunk + 12);
            wav.bits = le16(chunk + 22);
            if (format == 0xFFFE && avail >= 26)
                format = le16(chunk + 32); // SubFormat GUID starts with the format tag
        } else if (!memcmp(chunk, "data", 4)) {
            data = chunk + 8;
            data_size = avail;
        }
        pos += 8 + size + (size & 1);
    }
    if (!data || !wav.channels || !wav.sample_rate) {
        err = "fmt/data chunks missing";
        return false;
    }
    wav.is_float = format == 3;
    if (!(format == 1 && (wav.bits == 8 || wav.bits == 16 || wav.bits == 24 || wav.bits == 32))
        && !(format == 3 && (wav.bits == 32 || wav.bits == 64))) {
        err = "unsupported format (use PCM 8/16/24/32 or float 32/64)";
        return false;
    }
    const int bytes = wav.bits / 8;
    const size_t count = data_size / bytes / wav.channels * wav.channels;
    wav.samples.resize(count);
    for (size_t i = 0; i < count; ++i) {
        const uint8_t *p = data + i * bytes;
        float v = 0;
        if (format == 3) {
            if (bytes == 4) {
                memcpy(&v, p, 4);
            } else {
                double d;
                memcpy(&d, p, 8);
                v = static_cast<float>(d);
            }
        } else if (bytes == 1) {
            v = (p[0] - 128) / 128.0f;
        } else if (bytes == 2) {
            v = int16_t(le16(p)) / 32768.0f;
        } else if (bytes == 3) {
            int32_t s = (p[0] << 8) | (p[1] << 16) | (uint32_t(p[2]) << 24);
            v = s / 2147483648.0f;
        } else {
            v = int32_t(le32(p)) / 2147483648.0f;
        }
        wav.samples[i] = v;
    }
    return true;
}

static void put16(std::vector<uint8_t> &b, uint16_t v)
{
    b.push_back(v & 0xff);
    b.push_back(v >> 8);
}
static void put32(std::vector<uint8_t> &b, uint32_t v)
{
    put16(b, v & 0xffff);
    put16(b, v >> 16);
}

static bool write_wav(const fs::path &path, const Wav &wav)
{
    const bool pcm16 = !wav.is_float && wav.bits == 16;
    const int bytes = pcm16 ? 2 : 4;
    const uint32_t data_size = static_cast<uint32_t>(wav.samples.size() * bytes);
    std::vector<uint8_t> b;
    b.reserve(44 + data_size);
    b.insert(b.end(), {'R', 'I', 'F', 'F'});
    put32(b, 36 + data_size);
    b.insert(b.end(), {'W', 'A', 'V', 'E', 'f', 'm', 't', ' '});
    put32(b, 16);
    put16(b, pcm16 ? 1 : 3);
    put16(b, wav.channels);
    put32(b, wav.sample_rate);
    put32(b, wav.sample_rate * wav.channels * bytes);
    put16(b, wav.channels * bytes);
    put16(b, bytes * 8);
    b.insert(b.end(), {'d', 'a', 't', 'a'});
    put32(b, data_size);
    for (float v : wav.samples) {
        if (pcm16) {
            long s = std::lround(std::clamp(v, -1.0f, 1.0f) * 32767.0f);
            put16(b, static_cast<uint16_t>(static_cast<int16_t>(s)));
        } else {
            uint32_t u;
            memcpy(&u, &v, 4);
            put32(b, u);
        }
    }
    std::ofstream out(path, std::ios::binary);
    out.write(reinterpret_cast<const char *>(b.data()), b.size());
    return bool(out);
}

// Feeds the whole input through the algorithm the way Chrome's renderer does:
// input is enqueued in decoder-sized chunks and output is pulled in 10 ms
// device-sized chunks.
static Wav stretch(const Wav &in, double rate)
{
    wsola::AudioRendererAlgorithm algo;
    algo.Initialize(in.channels, in.sample_rate);

    const int total_in = in.frames();
    const int expected_out = static_cast<int>(std::lround(total_in / rate));
    const int in_chunk = 4096;
    const int out_chunk = std::max(1, in.sample_rate / 100);

    Wav out = in;
    out.samples.assign(static_cast<size_t>(expected_out) * in.channels, 0.0f);

    auto bus = wsola::AudioBus::Create(in.channels, out_chunk);
    int fed = 0;
    int produced = 0;
    bool padded = false;
    int stalls = 0;
    while (produced < expected_out) {
        int want = std::min(out_chunk, expected_out - produced);
        int got = algo.FillBuffer(bus.get(), 0, want, rate);
        for (int i = 0; i < got; ++i)
            for (int ch = 0; ch < in.channels; ++ch)
                out.samples[(size_t(produced) + i) * in.channels + ch] = bus->channel(ch)[i];
        produced += got;
        if (got == want) {
            stalls = 0;
            continue;
        }
        // Starved: feed more input, or silence once the file is exhausted so
        // that the last windows can be completed.
        if (fed < total_in) {
            int n = std::min(in_chunk, total_in - fed);
            algo.EnqueueInterleaved(in.samples.data() + size_t(fed) * in.channels, n);
            fed += n;
        } else if (!padded || ++stalls < 4) {
            std::vector<float> zeros(size_t(algo.LookaheadFrames() + algo.ola_window_size())
                                         * in.channels,
                                     0.0f);
            algo.EnqueueInterleaved(zeros.data(), algo.LookaheadFrames() + algo.ola_window_size());
            padded = true;
        } else {
            break;
        }
    }
    return out;
}

static std::string rate_label(double rate)
{
    char buf[32];
    snprintf(buf, sizeof buf, "%g", rate);
    return buf;
}

int main(int argc, char **argv)
{
    fs::path input;
    fs::path outdir;
    std::vector<double> rates;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "-h" || a == "--help") {
            printf("usage: %s input.wav [-o folder] [rate ...]   (default: 1.1 2)\n", argv[0]);
            return 0;
        } else if (a == "-o" && i + 1 < argc) {
            outdir = argv[++i];
        } else if (input.empty()) {
            input = a;
        } else {
            char *end = nullptr;
            double r = strtod(a.c_str(), &end);
            if (!end || *end || !(r > 0.0)) {
                fprintf(stderr, "invalid rate: %s\n", a.c_str());
                return 2;
            }
            rates.push_back(r);
        }
    }
    if (input.empty()) {
        fprintf(stderr, "usage: %s input.wav [-o folder] [rate ...]\n", argv[0]);
        return 2;
    }
    if (rates.empty())
        rates = {1.1, 2.0};
    if (outdir.empty())
        outdir = input.parent_path().empty() ? fs::path(".") : input.parent_path();

    Wav wav;
    std::string err;
    if (!read_wav(input, wav, err)) {
        fprintf(stderr, "%s: %s\n", input.c_str(), err.c_str());
        return 1;
    }
    printf("%s: %d channels, %d Hz, %d bits%s, %.2f s\n",
           input.filename().c_str(),
           wav.channels,
           wav.sample_rate,
           wav.bits,
           wav.is_float ? " float" : "",
           wav.frames() / double(wav.sample_rate));

    for (double rate : rates) {
        Wav out = stretch(wav, rate);
        fs::path path = outdir / (input.stem().string() + "." + rate_label(rate) + "x.wav");
        if (!write_wav(path, out)) {
            fprintf(stderr, "cannot write %s\n", path.c_str());
            return 1;
        }
        printf("  %sx -> %s (%.2f s)\n", rate_label(rate).c_str(), path.c_str(),
               out.frames() / double(out.sample_rate));
    }
    return 0;
}
