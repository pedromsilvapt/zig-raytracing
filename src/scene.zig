const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Vec3 = @import("utils.zig").Vec3;
const Ray = @import("utils.zig").Ray;
const RayHit = @import("utils.zig").RayHit;
const Camera = @import("utils.zig").Camera;

const Material = @import("materials.zig").Material;

pub const SceneObject = union(enum) {
    sphere: struct {
        center: Vec3,
        radius: f64,
        material: *Material,
    },

    pub fn initSphere(center: Vec3, radius: f64, material: *Material) SceneObject {
        return SceneObject{
            .sphere = .{
                .center = center,
                .radius = radius,
                .material = material,
            },
        };
    }

    pub fn hit(self: SceneObject, ray: Ray, t_min: f64, t_max: f64) ?RayHit {
        switch (self) {
            .sphere => |sphere| {
                const oc: Vec3 = ray.origin.sub(sphere.center);

                const a: f64 = ray.direction.dot(ray.direction);
                const b: f64 = oc.dot(ray.direction);
                const c: f64 = oc.dot(oc) - sphere.radius * sphere.radius;

                const descriminant: f64 = b * b - a * c;

                if (descriminant > 0) {
                    var temp: f64 = (-b - std.math.sqrt(descriminant)) / a;

                    if (temp > t_min and temp < t_max) {
                        const point = ray.pointAtParameter(temp);

                        return RayHit{
                            .t = temp,
                            .point = point,
                            .normal = point.sub(sphere.center).divF(sphere.radius),
                            .material = sphere.material,
                        };
                    }

                    temp = (-b + std.math.sqrt(descriminant)) / a;

                    if (temp > t_min and temp < t_max) {
                        const point = ray.pointAtParameter(temp);

                        return RayHit{
                            .t = temp,
                            .point = point,
                            .normal = point.sub(sphere.center).divF(sphere.radius),
                            .material = sphere.material,
                        };
                    }
                }

                return null;
            },
        }
    }
};

pub const Scene = struct {
    allocator: *Allocator,
    objects: ArrayList(SceneObject),
    materials: ArrayList(*Material),
    camera: Camera,

    pub fn init(allocator: *Allocator, camera: Camera) Scene {
        return Scene{
            .allocator = allocator,
            .objects = ArrayList(SceneObject).init(allocator),
            .materials = ArrayList(*Material).init(allocator),
            .camera = camera,
        };
    }

    pub fn deinit(self: *Scene) void {
        self.objects.deinit();

        var i: usize = 0;
        while (i < self.materials.items.len) : (i += 1) {
            self.allocator.destroy(self.materials.items[i]);
        }

        self.materials.deinit();
    }

    pub fn hit(self: *const Scene, ray: Ray, t_min: f64, t_max: f64) ?RayHit {
        var ray_hit: ?RayHit = null;
        var closest_so_far: f64 = t_max;

        var i: usize = 0;

        while (i < self.objects.items.len) : (i += 1) {
            if (self.objects.items[i].hit(ray, t_min, closest_so_far)) |temp_hit| {
                ray_hit = temp_hit;
                closest_so_far = temp_hit.t;
            }
        }

        return ray_hit;
    }

    pub fn addMaterial(self: *Scene, material: Material) !*Material {
        var ptr = try self.allocator.create(Material);
        errdefer self.allocator.destroy(ptr);

        ptr.* = material;

        try self.materials.append(ptr);

        return ptr;
    }
};
