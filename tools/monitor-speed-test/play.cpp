// Plays WAVs in a tractor at a given speed through the monitorspeed filter, like the monitor consumer,
// and writes the first channel (float raw). Modes: single, mix (second track with a mix transition), timewarp (clip at 2x)
#include <mlt++/Mlt.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>
int main(int argc, char **argv) {
    Mlt::Factory::init();
    if (getenv("DBG")) mlt_log_set_level(MLT_LOG_DEBUG);
    Mlt::Profile profile(getenv("PROFILE") ? getenv("PROFILE") : "atsc_1080p_25");
    const double fps = profile.fps();
    const char *mode = argv[1];
    double speed = atof(argv[3]);
    int preserve = atoi(argv[4]);
    int frames = atoi(argv[5]);
    Mlt::Tractor tractor(profile);
    Mlt::Producer *clip;
    if (!strcmp(mode, "xml")) {
        // a whole Kdenlive project (read only), played like the project monitor plays the timeline
        clip = new Mlt::Producer(profile, "xml", argv[2]);
    } else if (!strcmp(mode, "timewarp")) {
        std::string res = std::string("timewarp:2:") + argv[2];
        clip = new Mlt::Producer(profile, nullptr, res.c_str());
    } else {
        clip = new Mlt::Producer(profile, nullptr, argv[2]);
    }
    tractor.set_track(*clip, 0);
    Mlt::Producer *tone = nullptr;
    if (!strcmp(mode, "mix")) {
        tone = new Mlt::Producer(profile, nullptr, argv[7]);
        tractor.set_track(*tone, 1);
        Mlt::Transition mix(profile, "mix");
        mix.set("always_active", 1);
        mix.set("sum", 1);
        tractor.plant_transition(mix, 0, 1);
    }
    Mlt::Filter filter(profile, "monitorspeed");
    filter.set("preserve_pitch", preserve);
    if (!getenv("NOFILTER")) tractor.attach(filter);
    if (getenv("START")) tractor.seek(atoi(getenv("START")));
    tractor.set_speed(speed);
    FILE *out = fopen(argv[6], "wb");
    for (int i = 0; i < frames; i++) {
        Mlt::Frame *f = tractor.get_frame();
        mlt_audio_format fmt = mlt_audio_float;
        int freq = 48000, ch = 2;
        int n = mlt_audio_calculate_frame_samples(fps, 48000, i);
        void *pcm = f->get_audio(fmt, freq, ch, n);
        std::vector<float> m(n, 0.f);
        if (pcm && fmt == mlt_audio_float) memcpy(m.data(), pcm, n * sizeof(float));
        else if (pcm && fmt == mlt_audio_s16) for (int k = 0; k < n; k++) m[k] = ((int16_t *) pcm)[k * ch] / 32768.f;
        else if (pcm && fmt == mlt_audio_f32le) for (int k = 0; k < n; k++) m[k] = ((float *) pcm)[k * ch];
        fwrite(m.data(), sizeof(float), n, out);
        delete f;
    }
    fclose(out);
    return 0;
}
