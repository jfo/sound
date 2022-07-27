default:
	 zig run -I libsoundio main.zig -lsoundio

input:
	zig cc ./libsoundio/example/sio_microphone.c -I libsoundio -lsoundio && ./a.out

compile:
	 zig cc -I libsoundio sine_example.c -lsoundio

translate:
	 zig translate-c -I libsoundio libsoundio/example/sio_microphone.c -lsoundio

mic:
	 zig run mic_translated.zig  -lsoundio

clean:
	 rm -r sine.wav zig-cache zig-out
