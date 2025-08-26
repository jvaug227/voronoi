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
const GRID_WIDTH = 512;
const GRID_HEIGHT = 512;
const POINT_COUNT = 8;

fn write_pixels_to_file(pixels: []Pixel, width: usize, height: usize, name: []const u8) !void {
    const out_file = try std.fs.cwd().createFile(name, .{ .truncate = true });
    defer out_file.close();

    const writer = out_file.writer();
    try writer.print("P6 {} {} 255\n", .{ width, height });
    for (0..height) |y| {
        for (0..width) |x| {
            const pixel = pixels[x + y * width];
            try writer.print("{c}{c}{c}", .{ pixel.r, pixel.g, pixel.b });
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    const pixel_buffer = try alloc.alloc(Pixel, GRID_WIDTH * GRID_HEIGHT);
    defer alloc.free(pixel_buffer);

    const points = try alloc.alloc(Point, POINT_COUNT);
    defer alloc.free(points);

    var rand_seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&rand_seed));
    var prng = std.Random.DefaultPrng.init(rand_seed);
    const rand = prng.random();
    for (points) |*point| {
        point.x = rand.float(f32);
        point.y = rand.float(f32);
        std.log.info("Point: {d} {d}", .{point.x, point.y});
    }

    for (0..GRID_HEIGHT) |y| {
        for (0..GRID_WIDTH) |x| {
            var min_distance: usize = 1000;
            const fx: f32 = @floatFromInt(x);
            const fy: f32 = @floatFromInt(y);
            for (points) |point| {
                const px: f32 = @floor(point.x * @as(f32, @floatFromInt(GRID_WIDTH)));
                const py: f32 = @floor(point.y * @as(f32, @floatFromInt(GRID_HEIGHT)));
                const distance_to_point: usize = @intFromFloat(@abs(fx - px) + @abs(fy - py));
                min_distance = @min(min_distance, distance_to_point);
            }
            if (min_distance <= 2) {
                pixel_buffer[x + y * GRID_WIDTH] = Pixel{ .r = 0, .g = 0, .b = 255 };
            } else {
                pixel_buffer[x + y * GRID_WIDTH] = Pixel{ .r = 50, .g = 20, .b = 20 };
            }
        }
    }

    write_pixels_to_file(pixel_buffer, GRID_WIDTH, GRID_HEIGHT, "output.ppm") catch |err| {
        std.log.err("Failed to write file: {}", .{err});
    };
}
