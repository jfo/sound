const std = @import("std");
const soundio = @import("./soundio.zig");

var scaling: f32 = 0.0125;

fn sine(pitch: f32, frame: c_int, seconds_per_frame: f32, seconds_offset: f32) f32 {
    var radians_per_second: f32 = (pitch * 2.0) * std.math.pi;
    return std.math.sin((seconds_offset + (@intToFloat(f32, frame) * seconds_per_frame)) * radians_per_second);
}

fn saw(pitch: f32, frame: c_int, seconds_per_frame: f32) f32 {
    return sine(pitch, frame, seconds_per_frame) +
        sine(2.0 * pitch, frame, seconds_per_frame) +
        sine(3.0 * pitch, frame, seconds_per_frame) +
        sine(4.0 * pitch, frame, seconds_per_frame) +
        sine(5.0 * pitch, frame, seconds_per_frame) +
        sine(6.0 * pitch, frame, seconds_per_frame) +
        sine(7.0 * pitch, frame, seconds_per_frame);
}

var prng = std.rand.DefaultPrng.init(0);
fn white() f32 {
    const random = prng.random();
    return (random.float(f32) * 2.0) - 1.0;
}

fn getSample(seconds_offset: f32) f32 {
    _ = seconds_offset;
    return white() * scaling;
}

pub fn main() !void {
    try soundio.initialize(getSample);
}
