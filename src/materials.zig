const std = @import("std");
const Random = std.rand.Random;

const Vec3 = @import("utils.zig").Vec3;
const Ray = @import("utils.zig").Ray;
const RayHit = @import("utils.zig").RayHit;

fn randomInUnitSphere(random: *Random) Vec3 {
    var p = Vec3.initZero();

    while (p.lengthSquared() == 0 or p.lengthSquared() >= 1.0) {
        p = Vec3.init(random.float(f64), random.float(f64), random.float(f64)).mulF(2).sub(Vec3.initF(1));
    }

    return p;
}

fn reflect(v: Vec3, n: Vec3) Vec3 {
    return v.sub(n.mulF(2 * v.dot(n)));
}

fn refract(v: Vec3, n: Vec3, ni_over_nt: f64) ?Vec3 {
    const uv = v.normalize();

    const dt = uv.dot(n);

    const discriminant = 1 - ni_over_nt * ni_over_nt * (1 - dt * dt);

    if (discriminant > 0) {
        return uv.sub(n.mulF(dt)).mulF(ni_over_nt).sub(n.mulF(std.math.sqrt(discriminant)));
    }

    return null;
}

fn schlick(cosine: f64, refraction_index: f64) f64 {
    var r0 = (1 - refraction_index) / (1 + refraction_index);

    r0 = r0 * r0;

    return r0 + (1 - r0) * std.math.pow(f64, 1 - cosine, 5);
}

pub const Material = union(enum) {
    diffuse: struct {
        albedo: Vec3,
    },
    metal: struct {
        albedo: Vec3,
        fuzz: f64,
    },
    dialectric: struct {
        refraction_index: f64,
    },

    pub fn initDiffuse(albedo: Vec3) Material {
        return Material{
            .diffuse = .{
                .albedo = albedo,
            },
        };
    }

    pub fn initMetal(albedo: Vec3, fuzz: f64) Material {
        return Material{
            .metal = .{
                .albedo = albedo,
                .fuzz = fuzz,
            },
        };
    }

    pub fn initDialectric(refraction_index: f64) Material {
        return Material{
            .dialectric = .{
                .refraction_index = refraction_index,
            },
        };
    }

    pub fn scatter(self: Material, random: *Random, ray: Ray, hit: RayHit) ?ScatteredHit {
        switch (self) {
            .diffuse => |diffuse| {
                const target = hit.point.add(hit.normal).add(randomInUnitSphere(random));

                return ScatteredHit{
                    .scattered = Ray.init(hit.point, target.sub(hit.point)),
                    .attenuation = diffuse.albedo,
                };
            },
            .metal => |metal| {
                const reflected = reflect(ray.direction.normalize(), hit.normal);

                const scattered = Ray.init(hit.point, reflected.add(randomInUnitSphere(random).mulF(metal.fuzz)));

                if (scattered.direction.dot(hit.normal) > 0) {
                    return ScatteredHit{
                        .scattered = scattered,
                        .attenuation = metal.albedo,
                    };
                }
            },
            .dialectric => |dialectric| {
                var outward_normal = Vec3.initZero();
                var ni_over_nt: f64 = 0;
                var cosine:f64 = undefined;
                
                if (ray.direction.dot(hit.normal) > 0) {
                    outward_normal = hit.normal.mulF(-1);
                    ni_over_nt = dialectric.refraction_index;
                    cosine = dialectric.refraction_index * ray.direction.dot(hit.normal) / ray.direction.length();
                } else {
                    outward_normal = hit.normal;
                    ni_over_nt = 1.0 / dialectric.refraction_index;
                    cosine = - ray.direction.dot(hit.normal) / ray.direction.length();
                }

                if (refract(ray.direction, outward_normal, ni_over_nt)) |refracted| {
                    const reflect_prob = schlick(cosine, dialectric.refraction_index);

                    if (random.float(f64) >= reflect_prob) {
                        return ScatteredHit{
                            .scattered = Ray.init(hit.point, refracted),
                            .attenuation = Vec3.init(1, 1, 1),
                        };
                    }
                } else {
                    return ScatteredHit {
                        .scattered = Ray.init(hit.point, reflect(ray.direction, hit.normal)),
                        .attenuation = Vec3.init(1, 1, 1),
                    };
                }
            },
        }

        return null;
    }
};

pub const ScatteredHit = struct {
    attenuation: Vec3,
    scattered: Ray,
};
