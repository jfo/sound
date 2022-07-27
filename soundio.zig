const std = @import("std");
const c = @cImport({
    @cInclude("soundio/soundio.h");
});

var seconds_offset: f32 = 0.0;
var getSample: fn (f32) f32 = undefined;

fn read_callback(instream: [*c]c.SoundIoInStream, frame_count_min: c_int, frame_count_max: c_int) callconv(.C) void {
    _ = instream;
    _ = frame_count_max;
    _ = frame_count_min;
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
                        const offset = seconds_offset + (@intToFloat(f32, frame) * seconds_per_frame);
                        const sample = getSample(offset);

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

fn initializeOutstream(soundio: [*c]c.SoundIo) ![*c]c.SoundIoOutStream {
    const default_out_device_index = c.soundio_default_output_device_index(soundio);
    if (default_out_device_index < 0) {
        return error.NoOutputDeviceFound;
    }

    const out_device = c.soundio_get_output_device(soundio, default_out_device_index);
    defer c.soundio_device_unref(out_device);
    if (out_device == null) {
        return error.OutOfMemory;
    }

    std.debug.print("Output device: {s}\n", .{out_device.*.name});

    const outstream = c.soundio_outstream_create(out_device);

    outstream.*.format = c.SoundIoFormatFloat32NE;
    outstream.*.write_callback = write_callback;

    const err = c.soundio_outstream_open(outstream);
    if (err > 0) {
        return error.UnableToOpenOutputDevice;
    }

    return outstream;
}

fn initializeInstream(soundio: [*c]c.SoundIo) ![*c]c.SoundIoInStream {
    const default_in_device_index = c.soundio_default_input_device_index(soundio);
    if (default_in_device_index < 0) {
        return error.NoInputDeviceFound;
    }

    const in_device = c.soundio_get_input_device(soundio, default_in_device_index);
    defer c.soundio_device_unref(in_device);
    if (in_device == null) {
        return error.OutOfMemory;
    }

    std.debug.print("Input device: {s}\n", .{in_device.*.name});

    const instream = c.soundio_instream_create(in_device);

    instream.*.format = c.SoundIoFormatFloat32NE;
    instream.*.sample_rate = 48000;
    instream.*.software_latency = 2.0;
    instream.*.read_callback = read_callback;

    var err = c.soundio_instream_open(instream);
    if (err > 0) {
        std.debug.print("errcode: {s}\n", .{c.soundio_strerror(err)});
        return error.UnableToOpenInputDevice;
    }
    return instream;
}

pub fn initialize(function: fn (f32) f32) !void {
    var err: c_int = 0;
    getSample = function;
    const microphone_latency: f32 = 0.002; // seconds

    const soundio = c.soundio_create();
    if (soundio == null) {
        return error.OutOfMemory;
    }
    defer c.soundio_destroy(soundio);

    err = c.soundio_connect(soundio);
    if (err > 0) {
        return error.ErrorConnecting;
    }

    c.soundio_flush_events(soundio);

    const outstream = try initializeOutstream(soundio);
    defer c.soundio_outstream_destroy(outstream);

    const instream = try initializeInstream(soundio);
    defer c.soundio_instream_destroy(instream);

    const capacity = microphone_latency * @intToFloat(f32, 2 * instream.*.sample_rate * instream.*.bytes_per_frame);
    const ring_buffer = c.soundio_ring_buffer_create(soundio, @floatToInt(c_int, capacity));
    if (ring_buffer == null) {
        return error.OutOfMemory;
    }

    const buf = c.soundio_ring_buffer_write_ptr(ring_buffer);
    const fill_count: usize = @floatToInt(usize, microphone_latency * @intToFloat(f32, outstream.*.sample_rate * outstream.*.bytes_per_frame));
    _ = buf;
    _ = fill_count;
    std.mem.set(u8, buf[0..fill_count], 0);
    c.soundio_ring_buffer_advance_write_ptr(ring_buffer, @intCast(c_int, fill_count));

    err = c.soundio_outstream_start(outstream);
    if (err > 0) {
        return error.UnableToStartDevice;
    }

    err = c.soundio_instream_start(instream);
    if (err > 0) {
        return error.UnableToStartDevice;
    }

    while (true) {
        c.soundio_wait_events(soundio);
    }
}
