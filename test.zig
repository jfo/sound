const c = @cImport({
    @cInclude("soundio/soundio.h");
});

pub fn main() !void {
    c.soundio_outstream_begin_write;
}
