sine:
	cc sine_example.c -lsoundio && ./a.out

white:
	 zig run white_noise.zig -lsoundio

translate:
	 zig cc -I libsoundio -L libsoundio/build sine_example.c -lsoundio
