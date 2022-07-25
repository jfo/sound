default:
	 zig run -I libsoundio main.zig -lsoundio

sine:
	cc sine_example.c -lsoundio && ./a.out

compile:
	 zig cc -I libsoundio sine_example.c -lsoundio

clean:
	 rm -r sine.wav zig-cache zig-out
