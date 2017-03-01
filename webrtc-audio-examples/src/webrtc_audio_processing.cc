#include <string>
#include <iostream>

#include "webrtc/modules/audio_processing/include/audio_processing.h"
#include "webrtc/modules/interface/module_common_types.h"

#define EXPECT_OP(op, val1, val2)                                       \
  do {                                                                  \
    if (!((val1) op (val2))) {                                          \
      fprintf(stderr, "Check failed: %s %s %s\n", #val1, #op, #val2);   \
      exit(1);                                                          \
    }                                                                   \
  } while (0)

#define EXPECT_EQ(val1, val2)  EXPECT_OP(==, val1, val2)
#define EXPECT_NE(val1, val2)  EXPECT_OP(!=, val1, val2)
#define EXPECT_GT(val1, val2)  EXPECT_OP(>, val1, val2)
#define EXPECT_LT(val1, val2)  EXPECT_OP(<, val1, val2)

int usage() {
    std::cout <<
              "Usage: webrtc-audio-process -anc|-agc|-aec value input.wav output.wav [delay_ms echo_in.wav]"
              << std::endl;
    return 1;
}

bool ReadFrame(FILE* file, webrtc::AudioFrame* frame) {
    // The files always contain stereo audio.
    size_t frame_size = frame->samples_per_channel_;
    size_t read_count = fread(frame->data_,
                              sizeof(int16_t),
                              frame_size,
                              file);
    if (read_count != frame_size) {
        // Check that the file really ended.
        EXPECT_NE(0, feof(file));
        return false;  // This is expected.
    }
    return true;
}

bool WriteFrame(FILE* file, webrtc::AudioFrame* frame) {
    // The files always contain stereo audio.
    size_t frame_size = frame->samples_per_channel_;
    size_t read_count = fwrite (frame->data_,
                                sizeof(int16_t),
                                frame_size,
                                file);
    if (read_count != frame_size) {
        return false;  // This is expected.
    }
    return true;
}

int main(int argc, char **argv) {
    if (argc != 5 && argc != 7) {
        return usage();
    }

    bool is_echo_cancel = false;
    FILE *echo_in = NULL;
    int level, delay_ms = -1;
    level = atoi(argv[2]);

    // Usage example, omitting error checking:
    webrtc::AudioProcessing* apm = webrtc::AudioProcessing::Create();
    apm->high_pass_filter()->Enable(true);
    if (std::string(argv[1]) == "-anc") {
        std::cout << "ANC: level " << level << std::endl;
        apm->noise_suppression()->Enable(true);
        switch (level) {
        case 0:
            apm->noise_suppression()->set_level(webrtc::NoiseSuppression::kLow);
            break;
        case 1:
            apm->noise_suppression()->set_level(webrtc::NoiseSuppression::kModerate);
            break;
        case 2:
            apm->noise_suppression()->set_level(webrtc::NoiseSuppression::kHigh);
            break;
        case 3:
            apm->noise_suppression()->set_level(webrtc::NoiseSuppression::kVeryHigh);
            break;
        default:
            apm->noise_suppression()->set_level(webrtc::NoiseSuppression::kVeryHigh);
        }
        apm->voice_detection()->Enable(true);
    } else if (std::string(argv[1]) == "-agc") {
        std::cout << "AGC: model " << level << std::endl;
        apm->gain_control()->Enable(true);
        apm->gain_control()->set_analog_level_limits(0, 255);
        switch (level) {
        case 0:
            apm->gain_control()->set_mode(webrtc::GainControl::kAdaptiveAnalog);
            break;
        case 1:
            apm->gain_control()->set_mode(webrtc::GainControl::kAdaptiveDigital);
            break;
        case 2:
            apm->gain_control()->set_mode(webrtc::GainControl::kFixedDigital);
            break;
        default:
            apm->gain_control()->set_mode(webrtc::GainControl::kAdaptiveAnalog);
        }
    } else if (std::string(argv[1]) == "-aec") {
        webrtc::EchoCancellation *echo_canell = apm->echo_cancellation();
        is_echo_cancel = true;
        echo_canell->enable_drift_compensation(false);
        echo_canell->Enable(true);
        std::cout << "AEC: level " << level << std::endl;
        switch (level) {
            case 0:
                echo_canell->set_suppression_level(webrtc::EchoCancellation::kLowSuppression);
                break;
            case 1:
                echo_canell->set_suppression_level(webrtc::EchoCancellation::kModerateSuppression);
                break;
            case 2:
                echo_canell->set_suppression_level(webrtc::EchoCancellation::kHighSuppression);
        }
        delay_ms = atoi(argv[5]);
        apm->set_stream_delay_ms(delay_ms);
        EXPECT_NE(echo_in = fopen(argv[6], "rb"), NULL);
    } else {
        delete apm;
        return usage();
    }

    webrtc::AudioFrame *frame = new webrtc::AudioFrame();
    float frame_step = 10;  // ms
    frame->sample_rate_hz_ = 16000;
    frame->samples_per_channel_ = frame->sample_rate_hz_ * frame_step / 1000.0;

    frame->num_channels_ = 1;
    webrtc::AudioFrame *echo_frame = NULL;
    if (is_echo_cancel) {
        echo_frame = new webrtc::AudioFrame();
    }

    FILE *wav_in = fopen(argv[3], "rb");
    FILE *wav_out = fopen(argv[4], "wb");
    EXPECT_NE(wav_in, NULL);
    EXPECT_NE(wav_out, NULL);
    int num_frame = 0;
    while (ReadFrame(wav_in, frame)) {
        num_frame += 1;
        apm->ProcessStream(frame);
        if (is_echo_cancel && (num_frame * frame_step > delay_ms)) {
            if (ReadFrame(echo_in, echo_frame))
                apm->ProcessReverseStream(echo_frame);
        }
        WriteFrame(wav_out, frame);
    }
    fclose(wav_in);
    fclose(wav_out);
    fclose(echo_in);

    delete frame;
    if (is_echo_cancel)
        delete echo_frame;

    delete apm;

    return 0;
}
