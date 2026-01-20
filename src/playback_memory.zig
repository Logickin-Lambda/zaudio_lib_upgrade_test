const std = @import("std");
const zaudio = @import("zaudio");
const expectEqual = std.testing.expectEqual;

const SAMPLE_RATE = 44100;

pub fn run() !void {
    zaudio.init(std.heap.smp_allocator);
    defer zaudio.deinit();

    // read the sample file into heap:
    var file = try std.fs.cwd().openFile("testing_media/Accipiter Supersaw Key Demo.flac", .{});
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer arena.deinit();

    const file_content = try file.readToEndAlloc(arena.allocator(), try file.getEndPos());

    // load samples with decoder
    const decoder_config = zaudio.Decoder.Config.initDefault();
    var raw_decoder = zaudio.Decoder.createFromMemory(file_content.ptr, file_content.len, decoder_config) catch |err| {
        std.debug.print("ERROR: {any}", .{err});
        return;
    };

    defer raw_decoder.destroy();

    // device
    var device_config = zaudio.Device.Config.init(.playback);
    device_config.playback.format = zaudio.Format.float32;
    device_config.playback.channels = 2;
    device_config.sample_rate = SAMPLE_RATE;
    device_config.data_callback = data_callback; // we will fill that with actual signal source
    device_config.user_data = raw_decoder;

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
        _ = decoder.readPCMFrames(pOutput.?, frame_count) catch |err| {
            // flac works differently comparing with mp3 since it throws an at end error instead of creating an empty frames.
            switch (err) {
                error.AtEnd => decoder.seekToPCMFrames(0) catch {
                    @panic("cannot seek");
                },
                else => {
                    std.debug.print("ERROR: {any}", .{err});
                    return;
                },
            }
        };
    } else {
        return;
    }
}
