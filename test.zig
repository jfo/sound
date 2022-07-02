const c = @cImport({
    @cInclude("/Volumes/InternalNVME/jeff/code/sound/libsoundio/soundio/soundio.h");
});

pub fn main() !void {
    const thing = c.soundio_outstream_begin_write;

    @import("std").debug.print("{}", .{thing});
    // !!!!
    // fn([*c].cimport:1:11.struct_SoundIoOutStream, [*c][*c].cimport:1:11.struct_SoundIoChannelArea, [*c]c_int) callconv(.C) c_int@1042b5f70⏎
}
