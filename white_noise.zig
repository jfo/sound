const std = @import("std");
const c = @cImport({
    @cInclude("soundio/soundio.h");
});

pub var seconds_offset: f32 = 0.0;

fn sine(pitch: f32, frame: c_int, seconds_per_frame: f32) f32 {
    var radians_per_second: f32 = (pitch * 2.0) * std.math.pi;
    return std.math.sin((seconds_offset + (@intToFloat(f32, frame) * seconds_per_frame)) * radians_per_second);
}

var prng = std.rand.DefaultPrng.init(0);
fn white() f32 {
    const random = prng.random();
    return (random.float(f32) * 2.0) - 1.0;
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

fn write_callback(outstream: [*c]c.SoundIoOutStream, frame_count_min: c_int, frame_count_max: c_int) callconv(.C) void {
    var layout: [*c]const c.SoundIoChannelLayout = &outstream.*.layout;
    _ = frame_count_min;
    var float_sample_rate: f32 = @intToFloat(f32, outstream.*.sample_rate);
    var seconds_per_frame: f32 = 1.0 / float_sample_rate;
    var areas: [*c]c.SoundIoChannelArea = undefined;
    var frames_left: c_int = frame_count_max;
    var err: c_int = undefined;
    while (frames_left > @as(c_int, 0)) {
        var frame_count: c_int = frames_left;
        if ((blk: {
            const tmp = c.soundio_outstream_begin_write(outstream, &areas, &frame_count);
            err = tmp;
            break :blk tmp;
        }) != 0) {}
        if (!(frame_count != 0)) break;
        {
            var frame: c_int = 0;
            while (frame < frame_count) : (frame += @as(c_int, 1)) {
                {
                    var channel: c_int = 0;
                    while (channel < layout.*.channel_count) : (channel += @as(c_int, 1)) {
                        var ptr: [*c]f32 = @ptrCast([*c]f32, @alignCast(@import("std").meta.alignment(f32), (blk: {
                            const tmp = channel;
                            if (tmp >= 0) break :blk areas + @intCast(usize, tmp) else break :blk areas - ~@bitCast(usize, @intCast(isize, tmp) +% -1);
                        }).*.ptr + @bitCast(usize, @intCast(isize, (blk: {
                            const tmp = channel;
                            if (tmp >= 0) break :blk areas + @intCast(usize, tmp) else break :blk areas - ~@bitCast(usize, @intCast(isize, tmp) +% -1);
                        }).*.step * frame))));
                        // const base = 440.0;
                        // var sample = sine();
                        // var sample = sine(base, frame, seconds_per_frame);
                        const sample = white();
                        ptr.* = sample;
                    }
                }
            }
        }
        seconds_offset = @rem(seconds_offset + (seconds_per_frame * @intToFloat(f32, frame_count)), 1.0);
        if ((blk: {
            const tmp = c.soundio_outstream_end_write(outstream);
            err = tmp;
            break :blk tmp;
        }) != 0) {}
        frames_left -= frame_count;
    }
}

pub fn main() !void {
    const soundio = c.soundio_create();
    defer c.soundio_destroy(soundio);

    if (soundio == null) {
        return error.OutOfMemory;
    }

    var err: c_int = 0;
    err = c.soundio_connect(soundio);

    if (err > 0) {
        return error.ErrorConnecting;
    }

    c.soundio_flush_events(soundio);

    const default_out_device_index = c.soundio_default_output_device_index(soundio);
    if (default_out_device_index < 0) {
        return error.NoOutputDeviceFound;
    }

    const device = c.soundio_get_output_device(soundio, default_out_device_index);
    defer c.soundio_device_unref(device);
    if (device == null) {
        return error.OutOfMemory;
    }

    const outstream = c.soundio_outstream_create(device);
    defer c.soundio_outstream_destroy(outstream);

    outstream.*.format = c.SoundIoFormatFloat32NE;
    outstream.*.write_callback = write_callback;
    err = c.soundio_outstream_open(outstream);
    if (err > 0) {
        return error.UnableToOpenDevice;
    }

    err = c.soundio_outstream_start(outstream);
    if (err > 0) {
        return error.UnableToStartDevice;
    }

    while (true) {
        c.soundio_wait_events(soundio);
    }
}
