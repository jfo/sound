const std = @import("std");
const c = @cImport({
    @cInclude("soundio/soundio.h");
});

var seconds_offset: f32 = 0.0;
var getSample: fn (f32) f32 = undefined;

var ring_buffer: ?*c.SoundIoRingBuffer = null;

fn read_callback(instream: [*c]c.SoundIoInStream, frame_count_min: c_int, frame_count_max: c_int) callconv(.C) void {
    var areas: [*c]c.SoundIoChannelArea = undefined;
    var err: c_int = undefined;
    var write_ptr = c.soundio_ring_buffer_write_ptr(ring_buffer);
    _ = write_ptr;
    _ = err;
    _ = areas;
    _ = frame_count_max;
    _ = frame_count_min;
    _ = instream;
    const free_bytes: c_int = c.soundio_ring_buffer_free_count(ring_buffer);
    const free_count: c_int = @divExact(free_bytes, instream.*.bytes_per_frame);

    if (frame_count_min > free_count) {
        // panic("ring buffer overflow");
    }

    const write_frames: c_int = if (free_count < frame_count_max) free_count else frame_count_max;
    var frames_left = write_frames;
    _ = frames_left;

    while (true) {
        var frame_count: c_int = frames_left;

        err = c.soundio_instream_begin_read(instream, &areas, &frame_count);
        if (err > 0) {
            break;
            //     if ((err = c.soundio_instream_begin_read(instream, &areas, &frame_count)))
            //         panic("begin read error: %s", soundio_strerror(err));
        }

        if (frame_count == 0)
            break;

        if (areas == undefined) {
            //         // Due to an overflow there is a hole. Fill the ring buffer with
            //         // silence for the size of the hole.
            // std.mem.set(c_int, write_ptr[0..write_ptr], 0);
            // memset(write_ptr, 0, frame_count * instream->bytes_per_frame);
            // fprintf(stderr, "Dropped %d frames due to internal overflow\n", frame_count);
        } else {
            // for (int frame = 0; frame < frame_count; frame += 1) {
            //             for (int ch = 0; ch < instream->layout.channel_count; ch += 1) {
            //                 memcpy(write_ptr, areas[ch].ptr, instream->bytes_per_sample);
            //                 areas[ch].ptr += areas[ch].step;
            //                 write_ptr += instream->bytes_per_sample;
            //             }
            // }
        }

        //     if ((err = soundio_instream_end_read(instream)))
        //         panic("end read error: %s", soundio_strerror(err));

        frames_left -= frame_count;
        if (frames_left <= 0)
            break;
    }

    // int advance_bytes = write_frames * instream->bytes_per_frame;
    // soundio_ring_buffer_advance_write_ptr(ring_buffer, advance_bytes);
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

pub fn initialize(function: fn (f32) f32) !void {
    getSample = function;
    const microphone_latency: f32 = 0.002; // seconds
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

    const out_device = c.soundio_get_output_device(soundio, default_out_device_index);
    defer c.soundio_device_unref(out_device);
    if (out_device == null) {
        return error.OutOfMemory;
    }

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
    std.debug.print("Output device: {s}\n", .{out_device.*.name});

    // ---------------
    const instream = c.soundio_instream_create(in_device);
    defer c.soundio_instream_destroy(instream);

    instream.*.format = c.SoundIoFormatFloat32NE;
    instream.*.sample_rate = 48000;
    instream.*.software_latency = 2.0;
    instream.*.read_callback = read_callback;

    err = c.soundio_instream_open(instream);
    if (err > 0) {
        std.debug.print("errcode: {s}\n", .{c.soundio_strerror(err)});
        return error.UnableToOpenInputDevice;
    }

    // ---------------
    const outstream = c.soundio_outstream_create(out_device);
    defer c.soundio_outstream_destroy(outstream);

    outstream.*.format = c.SoundIoFormatFloat32NE;
    outstream.*.write_callback = write_callback;
    err = c.soundio_outstream_open(outstream);
    if (err > 0) {
        return error.UnableToOpenOutputDevice;
    }

    const capacity: f32 = microphone_latency * 2.0 * @intToFloat(f32, instream.*.sample_rate) * @intToFloat(f32, instream.*.bytes_per_frame);
    ring_buffer = c.soundio_ring_buffer_create(soundio, @floatToInt(c_int, capacity));
    if (ring_buffer == null) {
        return error.OutOfMemory;
    }

    err = c.soundio_instream_start(instream);
    if (err > 0) {
        return error.UnableToStartDevice;
    }

    // err = c.soundio_outstream_start(outstream);
    // if (err > 0) {
    //     return error.UnableToStartDevice;
    // }

    // ---------------

    while (true) {
        c.soundio_wait_events(soundio);
    }
}
