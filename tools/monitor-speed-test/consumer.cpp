// Plays a project through the real sdl2_audio consumer, set up like the Catavan monitor (FilteredConsumer +
// monitorspeed attached after connect, real_time 1, scrub_audio), for a few seconds at a speed.
// Run with SDL_AUDIODRIVER=disk SDL_DISKAUDIOFILE=out.raw to record what would be heard (float stereo 48 kHz).
// Usage: consumer <project.kdenlive|file> <speed> <preserve_pitch> <seconds> [start_frame]
#include <mlt++/Mlt.h>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <thread>
int main(int argc, char **argv)
{
    Mlt::Factory::init();
    if (getenv("DBG")) mlt_log_set_level(MLT_LOG_DEBUG);
    Mlt::Profile profile(getenv("PROFILE") ? getenv("PROFILE") : "atsc_1080p_25");
    double speed = atof(argv[2]);
    Mlt::Producer prod(profile, nullptr, argv[1]);
    if (argc > 5) prod.seek(atoi(argv[5]));
    Mlt::FilteredConsumer consumer(profile, "sdl2_audio");
    consumer.set("real_time", 1);
    consumer.set("channels", 2);
    consumer.set("frequency", 48000);
    consumer.set("terminate_on_pause", 0);
    // Same settings as the Catavan monitor (VideoWidget::reconfigure)
    int fps = (int) profile.fps();
    consumer.set("buffer", fps > 25 ? fps : 25);
    consumer.set("prefill", 6);
    consumer.set("drop_max", fps / 4);
    consumer.set("audio_buffer", 2048);
    consumer.connect(prod);
    Mlt::Filter filter(profile, "monitorspeed");
    filter.set("preserve_pitch", atoi(argv[3]));
    if (consumer.attach(filter) != 0) { fprintf(stderr, "attach failed\n"); return 1; }
    consumer.set("scrub_audio", speed != 1.0 ? 1 : 0);
    prod.set_speed(speed);
    consumer.start();
    if (getenv("SPEEDS")) {
        // Speed changes during the playback, like Catavan does (VideoWidget::switchPlay): "1.25,1.5,2" every SPEED_STEP s
        double step = getenv("SPEED_STEP") ? atof(getenv("SPEED_STEP")) : 2.0;
        std::string list = getenv("SPEEDS");
        size_t pos = 0;
        while (pos != std::string::npos) {
            std::this_thread::sleep_for(std::chrono::milliseconds((int) (step * 1000)));
            size_t next = list.find(',', pos);
            double s = atof(list.substr(pos, next == std::string::npos ? std::string::npos : next - pos).c_str());
            consumer.set("scrub_audio", 1);
            prod.set_speed(s);
            consumer.purge();
            prod.seek(consumer.position() + (s > 0. ? 1 : -1));   // as VideoWidget::switchPlay with the speed filter
            fprintf(stderr, "speed %.2f at consumer position %d\n", s, consumer.position());
            pos = next == std::string::npos ? next : next + 1;
        }
    }
    std::this_thread::sleep_for(std::chrono::milliseconds((int) (atof(argv[4]) * 1000)));
    int dropped = consumer.get_int("drop_count");
    consumer.stop();
    printf("dropped video frames: %d\n", dropped);
    return 0;
}
