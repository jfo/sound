const std = @import("std");
const c = @cImport({
    @cInclude("/Volumes/InternalNVME/jeff/code/sound/libsoundio/soundio/soundio.h");
});

fn write_callback(outstream: [*c]c.SoundIoOutStream, frame_count_min: c_int, frame_count_max: c_int) callconv(.C) void {
    _ = frame_count_min;

    const layout = outstream.*.layout;
    var frames_left = frame_count_max;
    var areas: [*c]c.SoundIoChannelArea = undefined;
    var rng = &std.rand.Isaac64.init(0);

    while (frames_left > 0) {
        var frame_count = frames_left;
        _ = c.soundio_outstream_begin_write(outstream, &areas, &frame_count);

        if (frame_count <= 0) {
            break;
        }

        var frame: c_int = 0;
        while (frame < frame_count) {
            const sample: f32 = std.rand.Isaac64.random(rng).float(f32);
            _ = sample;
            var channel: u32 = 0;

            while (channel < layout.channel_count) {

                // translated from c version
                var ptr: [*c]f32 = @ptrCast([*c]f32, @alignCast(@import("std").meta.alignment(f32), (blk: {
                    const tmp = channel;
                    if (tmp >= 0) {
                        break :blk areas + @intCast(usize, tmp);
                    }
                    break :blk areas - ~@bitCast(usize, @intCast(isize, tmp) +% -1);
                }).*.ptr + @bitCast(usize, @intCast(isize, (blk: {
                    const tmp = channel;
                    if (tmp >= 0) {
                        break :blk areas + @intCast(usize, tmp);
                    }
                    break :blk areas - ~@bitCast(usize, @intCast(isize, tmp) +% -1);
                }).*.step * frame))));

                ptr.* = sample;
                //

                channel += 1;
            }

            frame += 1;
        }

        var err: c_int = 0;
        err = c.soundio_outstream_end_write(outstream);
        if (err > 0) {}

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
