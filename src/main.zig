const std = @import("std");

// all examples:
const playback_sine_stereo = @import("playback_sine.zig");
const playback_mp3 = @import("playback_mp3.zig");
const direct_decoder_access = @import("direct_decoder_access.zig");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    // I will breakdown each test case as different examples such that
    // the code will also be doubled as low level examples for reference.
    // These example codes are based on the original C example:
    // https://miniaud.io/docs/examples/custom_decoder.html
    // with different variants for testing the validity of the decoder
    // (or possibly the Encoder in the future)
    // But first, let start a control test without any Decoder, with
    // generating a sine wave just to ensure everything works.

    try playback_sine_stereo.run();
    try playback_mp3.run();
    try direct_decoder_access.run();
}
