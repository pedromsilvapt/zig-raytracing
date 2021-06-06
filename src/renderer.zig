const std = @import("std");
const fmt = std.fmt;
const Random = std.rand.Random;

const Ray = @import("utils.zig").Ray;
const Vec3 = @import("utils.zig").Vec3;
const Scene = @import("scene.zig").Scene;

pub const Renderer = struct {
    width: i32 = 300,
    height: i32 = 150,
    samples: i32 = 20,
    file: []const u8,

    fn color(random: *Random, ray: Ray, scene: *const Scene, depth: usize) Vec3 {
        if (scene.hit(ray, 0.001, std.math.f64_max)) |hit| {
            if (depth >= 10) return Vec3.initZero();

            if (hit.material.scatter(random, ray, hit)) |scatter| {
                return color(random, scatter.scattered, scene, depth + 1).mul(scatter.attenuation);
            } else {
                return Vec3.initZero();
            }
        }

        const unit_direction: Vec3 = ray.direction.normalize();

        const t = 0.5 * (unit_direction.y + 1.0);

        return Vec3.init(1, 1, 1).mulF(1 - t).add(Vec3.init(0.5, 0.7, 1).mulF(t));
    }

    pub fn run(self: *Renderer, scene: *const Scene, random: *Random) !void {
        var file = try std.fs.cwd().createFile(self.file, .{ .truncate = true });
        defer file.close();

        var writer = file.writer();

        try fmt.format(writer, "P3\n{} {}\n255\n", .{ self.width, self.height });

        var j: i32 = self.height - 1;

        var progress = std.Progress{};
        const root_node = progress.start("Render", @intCast(usize, self.height * self.width)) catch unreachable;

        var pixel_name_buf = [_]u8{0} ** 100;
        var pixel_name: []u8 = &pixel_name_buf;

        const width_f = @intToFloat(f64, self.width);
        const height_f = @intToFloat(f64, self.height);

        while (j >= 0) : (j -= 1) {
            var i: i32 = 0;

            while (i < self.width) : (i += 1) {
                pixel_name = try fmt.bufPrint(&pixel_name_buf, "Pixel {}x{}", .{ i, j });
                var pixel = root_node.start(pixel_name, 0);
                pixel.activate();
                progress.maybeRefresh();

                var col: Vec3 = Vec3.initZero();

                var s: i32 = 0;

                while (s < self.samples) : (s += 1) {
                    const u = (@intToFloat(f64, i) + random.float(f64)) / width_f;
                    const v = (@intToFloat(f64, j) + random.float(f64)) / height_f;

                    const ray: Ray = scene.camera.getRay(random, u, v);

                    col = col.add(color(random, ray, scene, 0));
                }

                col = col.divF(@intToFloat(f64, self.samples));
                col = Vec3.init(std.math.sqrt(col.x), std.math.sqrt(col.y), std.math.sqrt(col.z));

                var ir: i32 = @floatToInt(i32, 255.99 * col.x);
                var ig: i32 = @floatToInt(i32, 255.99 * col.y);
                var ib: i32 = @floatToInt(i32, 255.99 * col.z);

                try fmt.format(writer, "{} {} {}\n", .{ ir, ig, ib });
                pixel.end();
                progress.maybeRefresh();
            }
        }

        progress.refresh();
    }
};
