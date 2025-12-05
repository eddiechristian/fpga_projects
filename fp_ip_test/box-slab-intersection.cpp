#include <algorithm>
#include <cmath>
#include <limits>

// Assume basic Vector3 and Ray structures exist.
struct Vector3 {
    float x, y, z;
    // Overload operators as needed for basic math operations
    Vector3 operator-(const Vector3& other) const {
        return {x - other.x, y - other.y, z - other.z};
    }
    Vector3 operator*(const Vector3& other) const {
        return {x * other.x, y * other.y, z * other.z};
    }
};

struct Ray {
    Vector3 origin;
    Vector3 direction;
    Vector3 inv_direction; // Precomputed 1.0 / direction
    // Constructor would compute inv_direction, handling 0 safely
};

// Box structure
struct BBox {
    Vector3 min_bound;
    Vector3 max_bound;
};

// Function to check for intersection
bool intersect(const Ray& r, const BBox& box, float& t_near, float& t_far) {
    // Compute intersection t values for each slab
    Vector3 tmin_vec = (box.min_bound - r.origin) * r.inv_direction;
    Vector3 tmax_vec = (box.max_bound - r.origin) * r.inv_direction;

    // Use std::min and std::max to order t values correctly for each axis, 
    // ensuring t1 is the near intersection and t2 is the far.
    Vector3 t1 = {std::min(tmin_vec.x, tmax_vec.x), std::min(tmin_vec.y, tmax_vec.y), std::min(tmin_vec.z, tmax_vec.z)};
    Vector3 t2 = {std::max(tmin_vec.x, tmax_vec.x), std::max(tmin_vec.y, tmax_vec.y), std::max(tmin_vec.z, tmax_vec.z)};

    // Find the max of all near intersections (t_near) and the min of all far intersections (t_far)
    t_near = std::max({t1.x, t1.y, t1.z});
    t_far = std::min({t2.x, t2.y, t2.z});

    // Intersection occurs if t_near is less than t_far
    // We also typically require t_far > 0 for a valid intersection *in front* of the ray origin
    return t_near <= t_far && t_far > 0;
}
