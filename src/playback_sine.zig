const std = @import("std");
const zaudio = @import("zaudio");

const SAMPLE_RATE = 44100;

pub fn run() !void {
    zaudio.init(std.heap.smp_allocator);
    defer zaudio.deinit();

    var device_config = zaudio.Device.Config.init(.playback);
    device_config.playback.format = zaudio.Format.float32;
    device_config.playback.channels = 2;
    device_config.sample_rate = SAMPLE_RATE;
    device_config.data_callback = data_callback; // we will fill that with actual signal source

    const device = zaudio.Device.create(null, device_config) catch {
        @panic("Failed to open playback device");
    };
    defer device.destroy();

    zaudio.Device.start(device) catch {
        zaudio.Device.destroy(device);
        @panic("Failed to start playback device");
    };

    std.Thread.sleep(5e9);
}

const FREQ: f32 = 440;
const DELTA_TIME: f32 = 1.0 / @as(f32, @floatFromInt(SAMPLE_RATE));
var t: f32 = 0;

fn data_callback(_: *zaudio.Device, pOutput: ?*anyopaque, _: ?*const anyopaque, frame_count: u32) callconv(.c) void {
    var output: [*]f32 = @ptrCast(@alignCast(pOutput));

    for (0..frame_count) |i| {
        // 2pi * freq * t = tau * freq * t
        const y = @sin(std.math.tau * FREQ * t);

        // the original example mentioned that the tuning will be off
        // if it is running long enough, possibly a floating point error.
        // Thus, a wrap around function is used
        t = if (t > 2) 0 else t + DELTA_TIME;

        output[i * 2] = y * @sin(std.math.tau * 0.5 * t);
        output[i * 2 + 1] = y * @sin((std.math.tau * 0.5 * t) + std.math.pi / 2.0);
    }
}
