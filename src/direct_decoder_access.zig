const std = @import("std");
const builtin = @import("builtin");
const zaudio = @import("zaudio");
const expectEqual = std.testing.expectEqual;

pub fn run() !void {
    zaudio.init(std.heap.smp_allocator);
    defer zaudio.deinit();

    // Align the decoder based on the audio configuration of my sawtooth file such that I can verify the file is properly read
    const decoder_config = zaudio.Decoder.Config.init(.unsigned8, 1, 44100);
    std.debug.print("decoder_config allocator callback: {any}\n", .{decoder_config.allocation_callbacks});

    var decoder_saw = try zaudio.Decoder.createFromFile("testing_media/test sawtooth.wav", decoder_config);
    defer decoder_saw.destroy();

    // my file should have 256 samples, so a u8 buffer of 256 slot should obtain all the audio information.
    var saw_wave = std.mem.zeroes([256]u8);
    const frame_out: *anyopaque = @ptrCast(&saw_wave);
    const frames_read: u64 = try decoder_saw.readPCMFrames(frame_out, 1000);

    // Here are the test to ensure the decoder works properly
    // Since the wav file only has 256 samples, it only has 256 instead of 1000 as the frames_count has stated
    try expectEqual(256, frames_read);

    // I have taken all the frames from the previous read, so I won't have any frames left, thus 0
    try expectEqual(0, decoder_saw.getAvailableFrames());

    // The decoder should have configs aligns to our init function, with a known backend which is wav:
    var format: zaudio.Format = undefined;
    var channels: u32 = undefined;
    var sample_rate: u32 = undefined;

    var channel_map = std.mem.zeroes([4]zaudio.Channel);
    const channel_map_ptr: []zaudio.Channel = @ptrCast(&channel_map);

    try decoder_saw.getDataFormat(&format, &channels, &sample_rate, channel_map_ptr);

    try expectEqual(zaudio.Format.unsigned8, format);
    try expectEqual(1, channels);
    try expectEqual(44100, sample_rate);

    // My os is windows, and based on the Xaudio2 mapping, my mono sample
    // will fill the first slot of the channel_map array to 1, leaving the following items 0.
    // This suggests that my device only supports mode 1 (mono mode) for this sample.
    // Different operating system and samples will have different results.
    if (builtin.os.tag == .windows) {
        try expectEqual(1, channel_map[0]);
        try expectEqual(0, channel_map[1]);
        try expectEqual(0, channel_map[2]);
        try expectEqual(0, channel_map[3]);
    }

    // my saw sample was a perfect from 0 to 255 ramp, so this is to ensure
    // that my functions retrieve the correct sample.
    // This also means that we can access the raw samples and load them into
    // the user data in the devices such that we can play samples without decode it
    // during the callback functions.
    for (saw_wave, 0..) |sample, i| {
        try expectEqual(i, sample);
    }
}
