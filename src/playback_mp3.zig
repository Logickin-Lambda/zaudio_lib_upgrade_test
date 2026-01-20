const std = @import("std");
const zaudio = @import("zaudio");
const expectEqual = std.testing.expectEqual;

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

    std.Thread.sleep(22e9);
}

fn data_callback(device: *zaudio.Device, pOutput: ?*anyopaque, _: ?*const anyopaque, frame_count: u32) callconv(.c) void {
    const decoder_opt: ?*zaudio.Decoder = @ptrCast(device.getUserData());

    if (decoder_opt) |decoder| {

        // Since the databack function is powered by the c based miniaudio library, we can't pass the zig error within the callback function
        // thus, we need to explicitly handle the error within the function like so. It can be returning an error log,
        // or a substitute value, depends on your applications.
        const frames_read = decoder.readPCMFrames(pOutput.?, frame_count) catch |err| {
            std.debug.print("ERROR: {any}", .{err});
            return;
        };

        // Loop the mp3 sample by seeking it from the beginning
        // if the returned frames_read count is less than the suggested frame_count of the current iteration.
        if (frames_read < frame_count) {
            decoder.seekToPCMFrames(0) catch {
                @panic("cannot seek");
            };
        }
    } else {
        return;
    }
}
