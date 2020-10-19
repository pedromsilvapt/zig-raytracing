const std = @import("std");
const fmt = std.fmt;
const Random = std.rand.Random;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils_module = @import("utils.zig");
const Vec3 = utils_module.Vec3;
const Ray = utils_module.Ray;
const Camera = utils_module.Camera;

const scene_module = @import("scene.zig");
const Scene = scene_module.Scene;
const SceneObject = scene_module.SceneObject;

const Material = @import("materials.zig").Material;
const Renderer = @import("renderer.zig").Renderer;

pub fn sceneSimple(allocator: *Allocator, nx: i32, ny: i32) !Scene {
    const camera_origin = Vec3.init(3, 3, 2);
    const camera_look_At = Vec3.init(0, 0, -1);

    var camera: Camera = Camera.init(
        camera_origin,
        camera_look_At,
        Vec3.init(0, 1, 0),
        20,
        @intToFloat(f64, nx) / @intToFloat(f64, ny),
        2.0,
        camera_origin.sub(camera_look_At).length(),
    );

    var scene = Scene.init(allocator, camera);

    var material1 = try scene.addMaterial(Material.initDiffuse(Vec3.init(0.1, 0.2, 0.5)));
    var material2 = try scene.addMaterial(Material.initDiffuse(Vec3.init(0.8, 0.8, 0.0)));
    var material3 = try scene.addMaterial(Material.initMetal(Vec3.init(0.8, 0.6, 0.2), 0.3));
    var material4 = try scene.addMaterial(Material.initDialectric(1.5));

    try scene.objects.append(SceneObject.initSphere(Vec3.init(0, 0, -1), 0.5, material1));
    try scene.objects.append(SceneObject.initSphere(Vec3.init(0, -100.5, -1), 100, material2));
    try scene.objects.append(SceneObject.initSphere(Vec3.init(1, 0, -1), 0.5, material3));
    try scene.objects.append(SceneObject.initSphere(Vec3.init(-1, 0, -1), 0.5, material4));

    return scene;
}

pub fn sceneCover(allocator: *Allocator, random: *Random, nx: i32, ny: i32) !Scene {
    const camera_origin = Vec3.init(14, 2, 3);
    const camera_look_At = Vec3.init(4, 0.5, 1);

    var camera: Camera = Camera.init(
        camera_origin,
        camera_look_At,
        Vec3.init(0, 1, 0),
        20,
        @intToFloat(f64, nx) / @intToFloat(f64, ny),
        0.15,
        camera_origin.sub(camera_look_At).length(),
    );

    var scene = Scene.init(allocator, camera);
    errdefer scene.deinit();

    try scene.objects.append(SceneObject.initSphere(
        Vec3.init(0, -1000, 0),
        1000,
        try scene.addMaterial(Material.initDiffuse(Vec3.initF(0.5))),
    ));

    var a: i32 = -11;

    while (a < 11) : (a += 1) {
        var b: i32 = -11;

        while (b < 11) : (b += 1) {
            var choose_mat = random.float(f64);

            const center = Vec3.init(
                @intToFloat(f64, a) + 0.9 * random.float(f64),
                0.2,
                @intToFloat(f64, b) + 0.9 * random.float(f64),
            );

            if (center.sub(Vec3.init(4, 0.2, 0)).length() > 0.9) {
                if (choose_mat < 0.8) {
                    try scene.objects.append(SceneObject.initSphere(
                        center,
                        0.2,
                        try scene.addMaterial(Material.initDiffuse(Vec3.init(
                            random.float(f64) * random.float(f64),
                            random.float(f64) * random.float(f64),
                            random.float(f64) * random.float(f64),
                        ))),
                    ));
                } else if (choose_mat < 0.95) {
                    try scene.objects.append(SceneObject.initSphere(
                        center,
                        0.2,
                        try scene.addMaterial(Material.initMetal(Vec3.init(
                            1 + random.float(f64),
                            1 + random.float(f64),
                            1 + random.float(f64),
                        ).mulF(0.5), 0.5 * random.float(f64))),
                    ));
                } else {
                    try scene.objects.append(SceneObject.initSphere(
                        center,
                        0.2,
                        try scene.addMaterial(Material.initDialectric(1.5)),
                    ));
                }
            }
        }
    }

    try scene.objects.append(SceneObject.initSphere(Vec3.init(-4, 1, 0), 1, try scene.addMaterial(Material.initDiffuse(Vec3.init(0.4, 0.2, 0.1)))));
    try scene.objects.append(SceneObject.initSphere(Vec3.init(0, 1, 0), 1, try scene.addMaterial(Material.initDialectric(1.5))));
    try scene.objects.append(SceneObject.initSphere(Vec3.init(4, 1, 0), 1, try scene.addMaterial(Material.initMetal(Vec3.init(0.7, 0.6, 0.5), 0))));

    return scene;
}

pub fn main() !void {
    var buf = [_]u8{0} ** (1024 * 1024);
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var arena = std.heap.ArenaAllocator.init(&fba.allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var prng = std.rand.DefaultPrng.init(20);
    var random = &prng.random;

    var renderer = Renderer {
        .width = 1080,
        .height = 720,
        .samples = 100,
        .file = "image.ppm"
    };

    // var scene = try sceneSimple(allocator, nx, ny);
    var scene = try sceneCover(allocator, random, renderer.width, renderer.height);
    defer scene.deinit();

    try renderer.run(&scene, random);
}
