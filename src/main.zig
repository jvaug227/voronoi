const std = @import("std");

const Pixel = struct {
    r: u8,
    g: u8,
    b: u8,
};
const Point = struct {
    x: f32,
    y: f32,
    v: f32,
    n: u32,
};

const GRID_WIDTH: usize = 1024;
const GRID_HEIGHT: usize = 1024;
const CANVAS_WIDTH: usize = GRID_WIDTH * 3;
const CANVAS_HEIGHT: usize = GRID_HEIGHT * 3;

// Worldgen Settings
const POINT_COUNT = 512;
const POINT_SPOT_THRESHOLD = 0.003;
const TOO_CLOSE_THRESHOLD_DISTANCE = 0.06;
const TOO_CLOSE_THRESHOLD_COUNT = 6;

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
        // Why does this actually work, shouldn't Pixel be aligned to u32?
        const pixel_bytes: []u8 = @ptrCast(pixels[start..end]);
        _ = try writer.write(pixel_bytes);
        // for (0..width) |x| {
        //     const pixel = pixels[x + y * width];
        //     try writer.print("{c}{c}{c}", .{ pixel.r, pixel.g, pixel.b });
        // }
    }
    try buf_writer.flush();
}

// Eudlidian: sqrt( x^2 + y^2 )
fn euclidian_distance(dx: f32, dy: f32) f32 {
    return @sqrt((dx * dx) + (dy * dy));
}

// Manhattan: sqrt( [(x + y)^2] => [x^2 + 2xy + y^2])
fn manhattan_distance(dx: f32, dy: f32) f32 {
    return dx + dy;
}

fn minkowski_distance(dx: f32, dy: f32, k: f32) f32 {
    const p = 1.0 + k;
    return std.math.pow(f32, std.math.pow(f32, dx, p) + std.math.pow(f32, dy, p), 1 / p);
}

fn weird_distance(dx: f32, dy: f32, k: f32) f32 {
    return @sqrt((dx * dx) + (dy * dy) + (k * 2.0 * dx * dy));
}

fn smin(a: f32, b: f32, k: f32) f32 {
    const m_k = k * 16.0 / 3.0;
    const h: f32 = @max(m_k - @abs(a - b), 0.0) / m_k;
    return @min(a, b) - h * h * h * (4.0 - h) * m_k * (1.0 / 16.0);
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
    // rand_seed = 340352070977;
    var prng = std.Random.DefaultPrng.init(rand_seed);
    std.debug.print("{}", .{rand_seed});
    const rand = prng.random();
    for (points) |*point| {
        point.x = rand.float(f32);
        point.y = rand.float(f32);
        std.log.info("Point: {d} {d}", .{ point.x, point.y });
    }
    for (points) |*point| {
        var num_points_too_close: usize = 0;
        for (points) |other_point| {
            const distance = euclidian_distance(@abs(point.x - other_point.x), @abs(point.y - other_point.y));
            if (distance < TOO_CLOSE_THRESHOLD_DISTANCE) {
                num_points_too_close += 1;
            }
        }
        point.v = if (num_points_too_close > TOO_CLOSE_THRESHOLD_COUNT) 1.0 else 0.0;
        point.n = @intCast(num_points_too_close);
    }

    const pixel_buffer = try alloc.alloc(Pixel, GRID_WIDTH * GRID_HEIGHT);
    defer alloc.free(pixel_buffer);

    // const falloff: f32 = 512.0;

    for (0..GRID_HEIGHT) |y| {
        const fy: f32 = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(GRID_HEIGHT));
        for (0..GRID_WIDTH) |x| {
            const fx: f32 = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(GRID_WIDTH));
            var min_distance: f32 = 1.0;
            var min_point: usize = 0;
            // var accumulated_distance: f32 = 0.0;
            for (0.., points) |idx, point| {
                const px: f32 = point.x;
                const py: f32 = point.y;
                const diff_x: f32 = @abs(fx - px);
                const diff_y: f32 = @abs(fy - py);
                const dx: f32 = if (diff_x > 0.5) 1.0 - diff_x else diff_x;
                const dy: f32 = if (diff_y > 0.5) 1.0 - diff_y else diff_y;
                const k: f32 = 0.3;
                const distance_to_point: f32 = weird_distance(dx, dy, k);
                // const sq_distance_to_point: f32 = (diff_x * diff_x) + (diff_y * diff_y);
                // accumulated_distance += @exp2(-falloff * @sqrt(sq_distance_to_point));
                // const sq_distance_to_point = std.math.pow(f32, (diff_x + diff_y), 2.0);
                if (distance_to_point < (min_distance)) {
                    // min_distance = (distance_to_point);
                    min_distance = @min(min_distance, distance_to_point);
                    min_point = idx;
                }
            }

            // accumulated_distance = -(1.0/falloff)*@log2(accumulated_distance);

            // const blue_modifier: f32 = if (min_distance <= POINT_THRESHOLD) 1.0 else 0.0;
            // const blue: f32 = 255.0 * blue_modifier;

            // const red: f32 = 255.0 * (1.0 - std.math.pow(f32, 1.0 - min_distance, 4.0)) * (1.0 - blue_modifier);
            // const red: f32 = 255.0 * 1.0 / (1.0 - @exp(-min_distance));
            // const red: f32 = 255.0 * (accumulated_distance);
            // const green: f32 = 255.0 * @as(f32, @floatFromInt(min_point)) / @as(f32, @floatFromInt(POINT_COUNT)) * (1.0 - blue_modifier);

            if (min_distance < POINT_SPOT_THRESHOLD) continue;

            min_distance = 1.0 - min_distance;
            min_distance = min_distance * min_distance;


            const blue_modifier: f32 = if (points[min_point].v < 0.60) 1.0 else 0.0;
            const blue: f32 = blue_modifier * 0.8 * 255 * min_distance;
            const red: f32 = 255.0 * @as(f32, @floatFromInt(points[min_point].n)) / 8;
            const green: f32 = 255 * (1.0 - blue_modifier) * min_distance;
            pixel_buffer[x + y * GRID_WIDTH] = Pixel{ .r = @intFromFloat(red), .g = @intFromFloat(green), .b = @intFromFloat(blue) };
        }
    }
    std.log.info("FINISHED_GENERATING", .{});

    const canvas_buffer = try alloc.alloc(Pixel, CANVAS_WIDTH * CANVAS_HEIGHT);
    defer alloc.free(canvas_buffer);

    for (0..3) |cy| {
        const canvas_start_y = cy * CANVAS_WIDTH * GRID_HEIGHT;
        for (0..3) |cx| {
            for (0..GRID_HEIGHT) |gh| {
                const pixel_start: usize = gh * GRID_WIDTH;
                const pixel_end: usize = pixel_start + GRID_WIDTH;
                const pixel_span = pixel_buffer[pixel_start..pixel_end];

                const canvas_start: usize = canvas_start_y + (cx * GRID_WIDTH) + (gh * CANVAS_WIDTH);
                const canvas_end: usize = canvas_start + GRID_WIDTH;
                const canvas_span = canvas_buffer[canvas_start..canvas_end];
                @memcpy(canvas_span, pixel_span);
            }
        }
    }

    write_pixels_to_file(canvas_buffer, CANVAS_WIDTH, CANVAS_HEIGHT, "output_3x3.ppm") catch |err| {
        std.log.err("Failed to write file: {}", .{err});
    };
    write_pixels_to_file(pixel_buffer, GRID_WIDTH, GRID_HEIGHT, "output.ppm") catch |err| {
        std.log.err("Failed to write file: {}", .{err});
    };
}
