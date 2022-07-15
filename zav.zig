const std = @import("std");
const File = std.fs.File;

const SAMPLE_RATE: u32 = 44100;
const CHANNELS: u32 = 1;
const HEADER_SIZE: u32 = 36;
const SUBCHUNK1_SIZE: u32 = 16;
const AUDIO_FORMAT: u32 = 1;
const BIT_DEPTH: u32 = 8;
const BYTE_SIZE: u32 = 8;

fn write_header(seconds: u32, file: File) !void {
    const numsamples: u32 = SAMPLE_RATE * seconds;
    const x = HEADER_SIZE + numsamples;
    _ = try file.write("RIFF");
    _ = try file.write(x[0..4]);
}

pub fn main() !void {
    const cwd = std.fs.cwd();
    var file = try cwd.createFile("sine.wav", .{});
    try write_header(3, file);
    _ = file.close();
}

// x[n..y]
