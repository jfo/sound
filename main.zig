const std = @import("std");
const soundio = @import("./soundio.zig");

var scaling: f32 = 0.008;

fn sine(pitch: f32, offset: f32) f32 {
    var radians_per_second: f32 = (pitch * 2.0) * std.math.pi;
    return std.math.sin(offset * radians_per_second);
}

fn saw(pitch: f32, offset: f32) f32 {
    return sine(pitch, offset) +
        sine(2.0 * pitch, offset) +
        sine(3.0 * pitch, offset) +
        sine(4.0 * pitch, offset) +
        sine(5.0 * pitch, offset) +
        sine(6.0 * pitch, offset) +
        sine(7.0 * pitch, offset);
}

var prng = std.rand.DefaultPrng.init(0);
fn white() f32 {
    const random = prng.random();
    return (random.float(f32) * 2.0) - 1.0;
}

fn getSample(offset: f32) f32 {
    const w = white() * scaling;
    const base = sine(220.0, offset) * scaling;
    const s = saw(440.0, offset) * scaling * 5;
    return w + base + s;
}

pub fn main() !void {
    try soundio.initialize(getSample);
}
