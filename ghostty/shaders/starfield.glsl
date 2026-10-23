// starfield: twinkling stars drift outward from the center, drawn only on dark cells
// loaded by custom-shader in ../config

#define LAYERS        3
#define DENSITY       20.0
#define STAR_SIZE     0.06
#define BRIGHTNESS    0.6
#define STAR_COLOR    vec3(0.9, 0.93, 1.0)
#define BLEND_THRESH  0.5

#define FLY_SPEED     0.01  // how fast you're moving forward

float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float starCell(vec2 cellID, vec2 cellUV, float layer, float t) {
    vec2 seed = cellID + vec2(layer * 17.3, layer * 5.7);
    vec2 pos = vec2(0.2 + hash(seed) * 0.6, 0.2 + hash(seed + 0.5) * 0.6);

    float dist = length(cellUV - pos);
    float size = STAR_SIZE * (0.4 + hash(seed + 2.0) * 0.6);

    float twinkleSpeed = 0.3 + hash(seed + 5.0) * 0.5;
    float twinklePhase = hash(seed + 6.0) * 6.28318;
    float twinkle = 0.75 + 0.25 * sin(t * twinkleSpeed + twinklePhase);

    float alpha = (0.5 + hash(seed + 3.0) * 0.5) * BRIGHTNESS * twinkle;

    return alpha * (1.0 - smoothstep(size * 0.1, size * 0.5, dist));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;

    // center the UV so origin is middle of screen
    vec2 centeredUV = (uv - 0.5) * vec2(aspect, 1.0);

    float t = iTime;
    float brightness = 0.0;

    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);

        // each layer zooms at a different depth — parallax
        float depth = 0.4 + fi * 0.5;
        float scale = DENSITY * (1.0 + fi * 0.4);

        // fade out stars as they fly past the edges
        float edgeFade = 1.0 - smoothstep(0.3, 0.8, length(centeredUV));

        // two copies of the layer, half a zoom cycle apart: each fades in after
        // its reset and out before the next, and sin² + cos² = 1 keeps the sum
        // steady, so the zoom never visibly jumps back
        for (int j = 0; j < 2; j++) {
            float phase = t * FLY_SPEED * depth + float(j) * 0.5;
            float p = fract(phase);
            float zoom = 1.0 + p;
            float cycleFade = pow(sin(p * 3.14159), 2.0);

            // expand UV outward from center over time
            vec2 gridUV = centeredUV / zoom * scale;
            vec2 cellID = floor(gridUV);
            vec2 cellUV = fract(gridUV);

            // new stars every cycle, so the same pattern doesn't come back
            float seedLayer = fi + floor(phase) * 3.7 + float(j) * 11.0;

            brightness += starCell(cellID, cellUV, seedLayer, t)
                * (1.0 - fi * 0.2) * edgeFade * cycleFade;
        }
    }

    vec4 term = texture(iChannel0, uv);
    float luma = dot(term.rgb, vec3(0.299, 0.587, 0.114));
    float blend = smoothstep(BLEND_THRESH * 0.4, BLEND_THRESH, 1.0 - luma);
    float star = brightness * blend;
    vec3 col = term.rgb + STAR_COLOR * star;

    // background-opacity makes the empty background see-through (low term.a);
    // raise the alpha where a star is so it shows over the glass too
    fragColor = vec4(col, max(term.a, clamp(star, 0.0, 1.0)));
}
