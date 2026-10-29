// seekacc <file> <first> <count> <step> [frames]: fetches the audio of `frames` frames at first, first+step, ... (step < 0: backwards,
// each fetch is a seek) and writes it to stdout as float32 stereo
#include <Mlt.h>
#include <cstdio>
#include <cstdlib>
int main(int argc, char **argv)
{
    Mlt::Factory::init();
    Mlt::Profile profile("atsc_1080p_30");
    Mlt::Producer prod(profile, nullptr, argv[1]);
    int first = atoi(argv[2]), count = atoi(argv[3]), step = atoi(argv[4]), k = argc > 5 ? atoi(argv[5]) : 1;
    for (int i = 0; i < count; i++) {
        int p = first + i * step;
        prod.seek(p);
        Mlt::Frame *f = prod.get_frame();
        mlt_audio_format fmt = mlt_audio_float;
        int freq = 48000, ch = 2, n = 1600 * k;
        if (k > 1 || getenv("MS")) f->set("producer_consumer_fps", 30.0 / k);
        float *a = (float *) f->get_audio(fmt, freq, ch, n);
        // planar float -> interleaved
        for (int s = 0; s < n; s++) { float v[2] = {a[s], a[n + s]}; fwrite(v, 4, 2, stdout); }
        fprintf(stderr, "%d:%d ", p, n);
        delete f;
    }
    return 0;
}
