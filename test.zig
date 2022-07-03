const c = @cImport({
    @cInclude("/Volumes/InternalNVME/jeff/code/sound/libsoundio/soundio/soundio.h");
});

fn write_callback(outstream: [*c]c.SoundIoOutStream, frame_count_min: c_int, frame_count_max: c_int) callconv(.C) void {
    _ = frame_count_min;

    const layout = outstream.*.layout;
    var frames_left = frame_count_max;
    var areas: [*c]c.SoundIoChannelArea = undefined;

    while (frames_left > 0) {
        var frame_count = frames_left;
        _ = c.soundio_outstream_begin_write(outstream, &areas, &frame_count);

        if (frame_count <= 0) {
            break;
        }

        var frame: u32 = 0;
        while (frame < frame_count) {
            const sample: f32 = 1.0;
            _ = sample;

            var channel: u32 = 0;
            while (channel < layout.channel_count) {
                // float *ptr = (float*)(areas[channel].ptr + areas[channel].step * frame);
                // *ptr = sample;
                channel += 1;
            }

            frame += 1;
        }

        _ = c.soundio_outstream_end_write(outstream);
        frames_left -= frame_count;
    }
}

pub fn main() !void {
    const soundio = c.soundio_create();
    _ = c.soundio_connect(soundio);
    c.soundio_flush_events(soundio);
    const default_out_device_index = c.soundio_default_output_device_index(soundio);
    const device = c.soundio_get_output_device(soundio, default_out_device_index);
    const outstream = c.soundio_outstream_create(device);
    outstream.*.format = c.SoundIoFormatFloat32NE;
    outstream.*.write_callback = write_callback;
    _ = c.soundio_outstream_open(outstream);

    while (true) {
        c.soundio_wait_events(soundio);
    }
}
