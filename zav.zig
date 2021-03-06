const std = @import("std");
const File = std.fs.File;
const sin = std.math.sin;

const SAMPLE_RATE: u32 = 44100;
const CHANNELS: u32 = 1;
const HEADER_SIZE: u32 = 36;
const SUBCHUNK1_SIZE: u32 = 16;
const AUDIO_FORMAT: u16 = 1;
const BIT_DEPTH: u32 = 8;
const BYTE_SIZE: u32 = 8;
const PI: f64 = 3.14159265358979323846264338327950288;

fn write_u16(n: u16, file: File) !void {
    const arr = [_]u8{ @truncate(u8, n), @truncate(u8, n >> 8) };
    _ = try file.write(arr[0..]);
}

fn write_u32(n: u32, file: File) !void {
    const arr = [_]u8{ @truncate(u8, n), @truncate(u8, n >> 8), @truncate(u8, n >> 16), @truncate(u8, n >> 24) };
    _ = try file.write(arr[0..]);
}

fn write_header(seconds: u32, file: File) !void {
    const numsamples: u32 = SAMPLE_RATE * seconds;
    _ = try file.write("RIFF");
    try write_u32(HEADER_SIZE + numsamples, file);
    _ = try file.write("WAVEfmt ");
    try write_u32(SUBCHUNK1_SIZE, file);
    try write_u16(AUDIO_FORMAT, file);
    try write_u16(@truncate(u16, CHANNELS), file);
    try write_u32(SAMPLE_RATE, file);
    try write_u32(SAMPLE_RATE * CHANNELS * (BIT_DEPTH / BYTE_SIZE), file);
    try write_u16(@truncate(u16, (CHANNELS * (BIT_DEPTH / BYTE_SIZE))), file);
    try write_u16(@truncate(u16, BIT_DEPTH), file);
    _ = try file.write("data");
    try write_u32(numsamples * CHANNELS * (BIT_DEPTH / BYTE_SIZE), file);
}

fn sine_wave(seconds: u32, file: File, freq: f64) !void {
    var idx: u32 = 0;
    while (idx < seconds * SAMPLE_RATE) {
        const sample = ((sin(((@intToFloat(f64, idx) * 2.0 * PI) / @intToFloat(f64, SAMPLE_RATE)) * freq) + 1.0) / 2.0) * 255.0;
        const arr = [_]u8{@floatToInt(u8, sample)};
        _ = try file.write(arr[0..]);
        idx += 1;
    }
}

pub fn main() !void {
    const cwd = std.fs.cwd();
    var file = try cwd.createFile("sine.wav", .{});
    try write_header(3, file);
    try sine_wave(3, file, 440.0);
    _ = file.close();
}
