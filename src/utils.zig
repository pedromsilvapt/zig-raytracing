const std = @import("std");
const Random = std.rand.Random;
const Material = @import("materials.zig").Material;

pub const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn init(x: f64, y: f64, z: f64) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn initF(value: f64) Vec3 {
        return Vec3{ .x = value, .y = value, .z = value };
    }

    pub fn initZero() Vec3 {
        return Vec3.init(0, 0, 0);
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x + other.x, self.y + other.y, self.z + other.z);
    }

    pub fn addF(self: Vec3, value: f64) Vec3 {
        return Vec3.init(self.x + value, self.y + value, self.z + value);
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x - other.x, self.y - other.y, self.z - other.z);
    }

    pub fn subF(self: Vec3, value: f64) Vec3 {
        return Vec3.init(self.x - value, self.y - value, self.z - value);
    }

    pub fn div(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x / other.x, self.y / other.y, self.z / other.z);
    }

    pub fn divF(self: Vec3, value: f64) Vec3 {
        return Vec3.init(self.x / value, self.y / value, self.z / value);
    }

    pub fn mul(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x * other.x, self.y * other.y, self.z * other.z);
    }

    pub fn mulF(self: Vec3, value: f64) Vec3 {
        return Vec3.init(self.x * value, self.y * value, self.z * value);
    }

    pub fn dot(self: Vec3, other: Vec3) f64 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(
            self.y * other.z - self.z * other.y,
            self.z * other.x - self.x * other.z,
            self.x * other.y - self.y * other.x,
        );
    }

    pub fn length(self: Vec3) f64 {
        return std.math.sqrt(self.lengthSquared());
    }

    pub fn lengthSquared(self: Vec3) f64 {
        return self.dot(self);
    }

    pub fn normalize(self: Vec3) Vec3 {
        return self.divF(self.length());
    }
};

pub const Ray = struct {
    origin: Vec3,
    direction: Vec3,

    pub fn initZero() Ray {
        return Ray{
            .origin = Vec3.initZero(),
            .direction = Vec3.initZero(),
        };
    }

    pub fn init(origin: Vec3, direction: Vec3) Ray {
        return Ray{
            .origin = origin,
            .direction = direction,
        };
    }

    pub fn pointAtParameter(self: *const Ray, t: f64) Vec3 {
        return self.origin.add(self.direction.mulF(t));
    }
};

fn randomInUnitDisk(random: *Random) Vec3 {
    var p = Vec3.initZero();

    while (p.lengthSquared() == 0 or p.lengthSquared() >= 1.0) {
        p = Vec3.init(random.float(f64), random.float(f64), 0).mulF(2).sub(Vec3.init(1, 1, 0));
    }

    return p;
}

pub const Camera = struct {
    origin: Vec3,
    lower_left_corner: Vec3,
    vertical: Vec3,
    horizontal: Vec3,
    w: Vec3,
    u: Vec3,
    v: Vec3,
    lens_radius: f64,

    /// vfov is top to bottom in degrees
    pub fn init(origin: Vec3, look_at: Vec3, up: Vec3, vfov: f64, aspect: f64, aperture: f64, focus_dist: f64) Camera {
        const theta = vfov * std.math.pi / 180.0;
        const half_height = std.math.tan(theta / 2.0);
        const half_width = aspect * half_height;

        const w = origin.sub(look_at).normalize();
        const u = up.cross(w).normalize();
        const v = w.cross(u);

        var lower_left_corner = Vec3.init(-half_width, -half_height, -1);
        lower_left_corner = origin.sub(u.mulF(half_width * focus_dist)).sub(v.mulF(half_height * focus_dist)).sub(w.mulF(focus_dist));

        return Camera{
            .origin = origin,
            .lower_left_corner = lower_left_corner,
            .horizontal = u.mulF(2 * half_width * focus_dist),
            .vertical = v.mulF(2 * half_height * focus_dist),
            .w = w,
            .u = u,
            .v = v,
            .lens_radius = aperture / 2,
        };
    }

    pub fn getRay(self: Camera, random: *Random, u: f64, v: f64) Ray {
        const rd = randomInUnitDisk(random).mulF(self.lens_radius);
        const offset = self.u.mulF(rd.x).add(self.v.mulF(rd.y));

        const hor = self.horizontal.mulF(u);
        const ver = self.vertical.mulF(v);
        return Ray.init(
            self.origin.add(offset),
            self.lower_left_corner.add(hor).add(ver).sub(self.origin).sub(offset),
        );
    }
};

pub const RayHit = struct {
    t: f64,
    point: Vec3,
    normal: Vec3,
    material: *Material,
};
