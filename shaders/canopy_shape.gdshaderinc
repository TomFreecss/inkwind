// The shape of a tree crown, shared by the foliage shader and its pencil
// outline so the two always move together. Needs wind.gdshaderinc included
// first, and render_mode world_vertex_coords.

// Where a crown vertex ends up: lumpy, leaning with the gusts, rustling.
// `origin` is the centre of the blob; everything is in world space.
vec3 canopy_shape(vec3 vertex, vec3 normal, vec3 origin, float fluff) {
	// Leafy lumps: push the sphere surface in and out.
	float lump = fbm(vertex.xz * 1.9 + vertex.y * 1.3);
	vertex += normal * (lump - 0.45) * fluff * 2.0;

	// Whole crown leans with the gusts...
	float gust = wind_gust(origin.xz, TIME);
	float lean = (0.05 + gust * 0.22) * wind_strength;
	float wobble = sin(TIME * 1.6 + origin.x * 0.7 + origin.z * 0.5);
	vertex.xz += wind_dir() * lean * (1.0 + 0.35 * wobble);
	// ...and the surface rustles.
	vertex += normal * sin(TIME * 5.5 + dot(vertex, vec3(3.1, 2.7, 3.7))) * 0.018 * (0.4 + gust);
	return vertex;
}
