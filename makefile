default:
	 zig run -I libsoundio main.zig -lsoundio

input:
	zig cc ./libsoundio/example/sio_microphone.c -I libsoundio -lsoundio && ./a.out

compile:
	 zig cc -I libsoundio sine_example.c -lsoundio

clean:
	 rm -r sine.wav zig-cache zig-out
