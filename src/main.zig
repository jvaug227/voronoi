const std = @import("std");

const Pixel = struct {
    r: u8,
    g: u8,
    b: u8,
};
const Point = struct {
    x: f32,
    y: f32,
};
const GRID_WIDTH = 1024;
const GRID_HEIGHT = 1024;
const POINT_COUNT = 64;
const POINT_THRESHOLD = 0.005;

fn write_pixels_to_file(pixels: []Pixel, width: usize, height: usize, name: []const u8) !void {
    const out_file = try std.fs.cwd().createFile(name, .{ .truncate = true });
    defer out_file.close();

    // const writer = out_file.writer();
    var buf_writer = std.io.bufferedWriter(out_file.writer());
    const writer = buf_writer.writer();
    try writer.print("P6 {} {} 255\n", .{ width, height });
    for (0..height) |y| {
        const start = y * width;
        const end = start + width;
        const pixel_bytes: []u8 = @ptrCast(pixels[start..end]);
        _ = try writer.write(pixel_bytes);
        // for (0..width) |x| {
        //     const pixel = pixels[x + y * width];
        //     try writer.print("{c}{c}{c}", .{ pixel.r, pixel.g, pixel.b });
        // }
    }
    try buf_writer.flush();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    const points = try alloc.alloc(Point, POINT_COUNT);
    defer alloc.free(points);

    var rand_seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&rand_seed));
    var prng = std.Random.DefaultPrng.init(rand_seed);
    const rand = prng.random();
    for (points) |*point| {
        point.x = rand.float(f32);
        point.y = rand.float(f32);
        std.log.info("Point: {d} {d}", .{ point.x, point.y });
    }

    const pixel_buffer = try alloc.alloc(Pixel, GRID_WIDTH * GRID_HEIGHT);
    defer alloc.free(pixel_buffer);

    for (0..GRID_HEIGHT) |y| {
        const fy: f32 = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(GRID_HEIGHT));
        for (0..GRID_WIDTH) |x| {
            const fx: f32 = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(GRID_WIDTH));
            var min_distance: f32 = 1.0;
            var min_point: usize = 0;
            for (0.., points) |idx, point| {
                const px: f32 = point.x;
                const py: f32 = point.y;
                // Eudlidian: sqrt( x^2 + y^2 )
                const diff_x: f32 = @abs(fx - px);
                const diff_y: f32 = @abs(fy - py);
                const sq_distance_to_point: f32 = (diff_x*diff_x) + (diff_y*diff_y);
                // Manhattan: sqrt( (x + y)^2 => x^2 + 2xy + y^2)
                // const sq_distance_to_point = std.math.pow(f32, (diff_x + diff_y), 2.0);
                if (sq_distance_to_point < (min_distance * min_distance)) {
                    min_distance = @sqrt(sq_distance_to_point);
                    min_point = idx;
                }
            }

            const blue_modifier: f32 = if (min_distance <= POINT_THRESHOLD) 1.0 else 0.0;
            const blue: f32 = 255.0 * blue_modifier;

            const red: f32 = 255.0 * (1.0 - min_distance) * (1.0 - blue_modifier);
            const green: f32 = 255.0 * @as(f32, @floatFromInt(min_point)) / @as(f32, @floatFromInt(POINT_COUNT)) * (1.0 - blue_modifier);

            pixel_buffer[x + y * GRID_WIDTH] = Pixel{ .r = @intFromFloat(red), .g = @intFromFloat(green), .b = @intFromFloat(blue) };
        }
    }
    std.log.info("FINISHED_GENERATING", .{});

    write_pixels_to_file(pixel_buffer, GRID_WIDTH, GRID_HEIGHT, "output.ppm") catch |err| {
        std.log.err("Failed to write file: {}", .{err});
    };
}
