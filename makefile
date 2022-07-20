sine:
	cc sine_example.c -lsoundio && ./a.out

white:
	 zig run -I libsoundio white_noise.zig -lsoundio

compile:
	 zig cc -I libsoundio sine_example.c -lsoundio

clean:
	 rm -r sine.wav zig-cache zig-out
