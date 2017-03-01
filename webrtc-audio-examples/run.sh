#!/bin/sh


if [ ! -d webrtc-audio-processing ];then
  git clone git://anongit.freedesktop.org/pulseaudio/webrtc-audio-processing
fi

if [ ! -d webrtc-audio-processing/release ];then
  cd webrtc-audio-processing
  mv RELEASE release.txt >/dev/null
  ./autogen.sh --prefix=`pwd`/release && make -j && make install && cd -
fi

mkdir -p bin; cd bin; cmake ../; make; cd -

set -e

sox data/speech_16k.wav -p synth whitenoise vol 0.02 | sox -m data/speech_16k.wav - data/addednoise.wav

echo "============= WebRTC ANC ============="
rm -f data/*webrtc_anc*
sox data/addednoise.wav data/addednoise.raw || exit 1;
for x in 0 1 2 3;do
  echo -n "WebRTC ANC $x: "
  ./bin/webrtc-audio-process -anc $x data/addednoise.raw data/addednoise_webrtc_anc_$x.raw || exit 1;
  sox -r 16k -t raw -b 16 -c 1 -e signed-intege data/addednoise_webrtc_anc_$x.raw data/addednoise_webrtc_anc_$x.wav || exit 1;
  rm data/addednoise_webrtc_anc_$x.raw
done


echo "============= WebRTC AGC ============="
sox data/speech_16k.wav data/speech_16k.raw
rm -f data/*webrtc_agc*
for x in 0 1 2;do
  echo -n "WebRTC AGC $x: "
  ./bin/webrtc-audio-process -agc $x data/speech_16k.raw data/speech_16k_webrtc_agc_$x.raw || exit 1;
  sox -r 16k -t raw -b 16 -c 1 -e signed-intege data/speech_16k_webrtc_agc_$x.raw \
    data/speech_16k_webrtc_agc_$x.wav || exit 1;
  rm -f data/speech_16k_webrtc_agc_$x.raw
done

echo "============= WebRTC AEC ============="
rm -f data/*webrtc_aec*
rm -f data/speech_16k_echo.wav data/speech_16k_echo.raw
delay=1500
sox data/speech_16k.wav data/speech_16k_echo.wav echo 0.8 0.2 $delay 0.3
sox data/speech_16k_echo.wav data/speech_16k_echo.raw

for x in 0 1 2;do
  echo -n "WebRTC AEC $x: "
  ./bin/webrtc-audio-process -aec $x data/speech_16k_echo.raw data/speech_16k_webrtc_aec_$x.raw \
      $delay data/speech_16k.raw || exit 1;
  sox -r 16k -t raw -b 16 -c 1 -e signed-intege data/speech_16k_webrtc_aec_$x.raw \
      data/speech_16k_webrtc_aec_$x.wav || exit 1;
  rm -f data/speech_16k_webrtc_aec_$x.raw
done
