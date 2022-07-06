sine:
	cc sine_example.c -lsoundio && ./a.out

zigtest:
	 zig run test.zig -lsoundio

translate:
	 zig cc -I libsoundio -L libsoundio/build sine_example.c -lsoundio
