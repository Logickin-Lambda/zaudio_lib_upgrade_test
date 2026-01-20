const std = @import("std");
const builtin = @import("builtin");
const zaudio = @import("zaudio");
const expectEqual = std.testing.expectEqual;

pub fn run() !void {
    zaudio.init(std.heap.smp_allocator);
    defer zaudio.deinit();

    // Align the decoder based on the audio configuration of my sawtooth file such that I can verify the file is properly read
    const decoder_config = zaudio.Decoder.Config.init(.unsigned8, 1, 44100);
    var decoder_saw = try zaudio.Decoder.createFromFile("testing_media/test sawtooth.wav", decoder_config);
    defer decoder_saw.destroy();

    // my file should have 256 samples, so a u8 buffer of 256 slot should obtain all the audio information.
    var saw_wave = std.mem.zeroes([256]u8);
    const frame_out: *anyopaque = @ptrCast(&saw_wave);

    _ = try decoder_saw.readPCMFrames(frame_out, saw_wave.len);

    // Data Converter take place fom here, and I am going to double the sample rate
    // and turn my sawtooth from mono to stereo, in higher format resolution.
    var data_conv_fig = zaudio.DataConverter.Config.init(.unsigned8, .float32, 1, 2, 44100, 88200);
    try expectEqual(zaudio.Format.unsigned8, data_conv_fig.format_in);
    try expectEqual(zaudio.Format.float32, data_conv_fig.format_out);
    try expectEqual(1, data_conv_fig.channels_in);
    try expectEqual(2, data_conv_fig.channels_out);
    try expectEqual(44100, data_conv_fig.sample_rate_in);
    try expectEqual(88200, data_conv_fig.sample_rate_out);

    // removes the lowpass filter effect for verification
    data_conv_fig.resampling.linear.lpf_order = 0;

    var converter = try zaudio.DataConverter.create(data_conv_fig);
    defer converter.destroy();

    // due to the doubled sample rate and channels,
    // the array size is quadrupled.
    var saw_wave_new = std.mem.zeroes([1024]f32);
    const frame_out_new: *anyopaque = @ptrCast(&saw_wave_new);

    var frames_count_in: u64 = saw_wave.len;
    var frames_count_out: u64 = try converter.getExpectedOutputFrameCount(frames_count_in);

    try converter.processPcmFrames(frame_out, &frames_count_in, frame_out_new, &frames_count_out);

    // here is the validations for the converter
    try expectEqual(512, frames_count_out);
    try expectEqual(saw_wave.len, try converter.getRequiredInputFrameCount(frames_count_out));

    // to validate the result samples, since the conversion process has latency, we need to offset the samples by the latency value, thus
    const input_latency = converter.getInputLatency();
    const output_latency = converter.getOutPutLatency();
    var prev_sample = -std.math.floatMax(f32);

    for ((input_latency + output_latency)..saw_wave_new.len) |i| {
        // we don't know the behavior of the converter, but we know our sample is a upward ramp for sure,
        // so if the current value is larger than the previous value, this means the converter has successfully
        // converted the ramp into other format. Besides, since we originally have a mono sample, we can compare
        // both odd and even items such that they should be identical after they have been converted into stereo.
        if (i % 2 == 0) {
            try std.testing.expect(prev_sample < saw_wave_new[i]);
            try std.testing.expect(saw_wave_new[i] == saw_wave_new[i + 1]);
            prev_sample = saw_wave_new[i];
        }
    }
}
