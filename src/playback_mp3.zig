const std = @import("std");
const zaudio = @import("zaudio");

const SAMPLE_RATE = 44100;

pub fn run() !void {
    zaudio.init(std.heap.smp_allocator);
    defer zaudio.deinit();

    // load samples with decoder
    const decoder_config = zaudio.Decoder.Config.initDefault();
    var mp3_decoder = try zaudio.Decoder.createFromFile("testing_media/Accipiter Supersaw Demo.mp3", decoder_config);
    defer mp3_decoder.destroy();

    // device
    var device_config = zaudio.Device.Config.init(.playback);
    device_config.playback.format = zaudio.Format.float32;
    device_config.playback.channels = 2;
    device_config.sample_rate = SAMPLE_RATE;
    device_config.data_callback = data_callback; // we will fill that with actual signal source
    device_config.user_data = mp3_decoder;

    const device = zaudio.Device.create(null, device_config) catch {
        @panic("Failed to open playback device");
    };
    defer device.destroy();

    zaudio.Device.start(device) catch {
        zaudio.Device.destroy(device);
        @panic("Failed to start playback device");
    };

    // add another thread to trace the frames_read:
    _ = try std.Thread.spawn(.{}, print_audio_thread_debug_in_seconds, .{});

    std.Thread.sleep(20e9);
}

var frames_read: u64 = 0;

fn data_callback(device: *zaudio.Device, pOutput: ?*anyopaque, _: ?*const anyopaque, frame_count: u32) callconv(.c) void {
    const decoder_opt: ?*zaudio.Decoder = @ptrCast(device.getUserData());

    if (decoder_opt) |decoder| {
        decoder.readPCMFrames(pOutput.?, frame_count, &frames_read) catch {
            return;
        };
    } else {
        return;
    }
}

fn print_audio_thread_debug_in_seconds() void {
    for (0..20) |_| {
        std.debug.print("frames_read: {}\n", .{frames_read});
        std.Thread.sleep(1e9);
    }
}
