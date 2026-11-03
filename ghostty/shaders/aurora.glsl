// aurora: northern-lights curtains snaking across the whole sky, drawn only on dark cells
// loaded by custom-shader in ../config
//
// what makes it look natural:
//   - each band is a ribbon whose lower edge meanders in big S-folds that slowly change shape
//   - rays are vertical streaks that flicker in place (not slide), each with its own length
//   - where a fold turns, you see the curtain edge-on, so it glows brighter
//   - farther bands sit higher, are thinner, dimmer and fold less (perspective)
//   - green at the lower edge, fading to violet higher up, with a faint haze around it

#define BANDS         2
#define BRIGHTNESS    0.3
#define HEIGHT        0.64   // lower edge of the nearest band (0 = bottom, 1 = top)
#define SPREAD        0.1    // each farther band sits this much higher
#define FOLD_AMP      0.13   // how far the S-folds swing up and down
#define FOLD_FREQ     1.5    // how many big folds fit across the screen
#define TILT          -0.3   // band descends toward the right (flip sign to descend left, 0 = flat)
#define DRIFT         0.003  // how fast the folds slide sideways
#define MORPH         0.004  // how fast the folds change shape
#define FADE_UP       2.5    // higher = shorter curtains
#define RAY_DENSITY   14.0   // rays per screen height
#define RAY_CONTRAST  0.35   // how much rays stand out from the curtain (0 = smooth glow)
#define SHIMMER       0.03   // how fast rays brighten and fade (keep low: motion pulls the eye)
#define PULSE         0.005  // how fast bright patches travel along the bands
#define FOLD_GLOW     0.5    // extra brightness where a fold turns edge-on
#define SOFTEN        1.5    // tames the brightest parts only; dim glow stays as is (0 = off)
#define HAZE          0.06   // soft diffuse glow around each band
#define LEFT_STRENGTH 0.25   // aurora strength on the left (code) side; 1 = even everywhere
#define TOP_ONLY      vec2(0.42, 0.6)  // aurora fades in between these heights (0 = bottom)
#define EDGE_COLOR    vec3(0.15, 1.0, 0.55)  // green lower edge
#define TOP_COLOR     vec3(0.4, 0.18, 0.75)  // faint violet fringe on top of each curtain
#define GREEN_DEPTH   0.2    // how tall the green part is before it turns violet
#define SKY_VIOLET    0.25   // upper part of the screen leans violet (0 = off)
#define BREATHE_SPEED 0.01   // how fast the whole display brightens and dims
#define BLEND_THRESH  0.5
#define PANEL_GLOW    0.3    // aurora strength behind nvim panels (blurred: no rays)
// frost: the whole aurora seen through frosted glass (FROST_BLUR 0, FROST_EDGE 0, FROST_GLOW 1 = off)
#define FROST_BLUR    0.7    // how much the rays smooth into an even glow (1 = like nvim panels)
#define FROST_EDGE    0.05   // how soft the curtains' sharp lower edge gets
#define FROST_GLOW    0.85   // aurora strength through the glass (it takes a little light)
#define PANEL_DEBUG   0      // 1 = tint detected panels red, to check the detection

// nvim floats and sidebars paint this exact bg (bg_panel in nvim/lua/eti/core/palette.lua)
#define PANEL_BG      (vec3(14.0, 7.0, 25.0) / 255.0)

bool isPanelBg(vec2 fragCoord) {
    vec3 c = texture(iChannel0, fragCoord / iResolution.xy).rgb;
    return all(lessThan(abs(c - PANEL_BG), vec3(2.5 / 255.0)));
}

// 1.0 inside a panel; text and selected rows don't have the panel bg, so a pixel also
// counts when the bg shows on both sides of it (left+right a glyph apart, up+down a row apart)
float panelMask(vec2 fragCoord) {
    if (isPanelBg(fragCoord)) return 1.0;
    bool lr = isPanelBg(fragCoord + vec2(12.0, 0.0)) && isPanelBg(fragCoord - vec2(12.0, 0.0));
    bool ud = isPanelBg(fragCoord + vec2(0.0, 40.0)) && isPanelBg(fragCoord - vec2(0.0, 40.0));
    return (lr || ud) ? 1.0 : 0.0;
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// smooth 2D value noise; one axis is usually time, so things morph instead of sliding
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

// big S-folds of a band's lower edge, 0..1
float fold(float x, float fi) {
    return fbm(vec2(x * FOLD_FREQ + iTime * DRIFT + fi * 13.0, iTime * MORPH + fi * 7.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    float x = uv.x * aspect;
    float y = 1.0 - uv.y;   // ghostty puts fragCoord y = 0 at the top; flip so 0 = bottom

    float panel = panelMask(fragCoord);
    vec3 aurora = vec3(0.0);

    for (int i = 0; i < BANDS; i++) {
        float fi = float(i);
        float near = 1.0 - fi * 0.3;   // farther bands: smaller folds, thinner, dimmer

        // lower edge and its slope (finite difference) to find where folds turn edge-on
        float e = 0.02;
        float f = fold(x, fi);
        float slope = (fold(x + e, fi) - fold(x - e, fi)) / (2.0 * e);
        float amp = 2.0 * FOLD_AMP * near;
        float base = HEIGHT + fi * SPREAD + (f - 0.5) * amp + (uv.x - 0.5) * TILT;
        float d = y - base;

        // rays: vertical streaks that flicker in place; they bunch up where the fold moves
        float rx = x + f * 2.0;
        float r1 = noise(vec2(rx * RAY_DENSITY + fi * 31.0, iTime * SHIMMER + fi * 3.0));
        float r2 = noise(vec2(rx * RAY_DENSITY * 2.7 + fi * 17.0, iTime * SHIMMER * 1.7));
        float soft = max(panel, FROST_BLUR);   // frosted everywhere, fully even behind panels
        float rays = mix(1.0 + RAY_CONTRAST * (2.0 * r1 * r2 - 0.5), 1.0, soft);

        // each ray reaches its own height
        float len = mix(1.0 + RAY_CONTRAST * (r1 - 0.5), 1.0, soft);
        float fadeUp = FADE_UP * (1.0 + fi * 0.5) / len;

        // lower edge (softened by FROST_EDGE), long exponential fade upward
        float curtain = smoothstep(-0.012 - FROST_EDGE, 0.004 + FROST_EDGE, d) * exp(-max(d, 0.0) * fadeUp);

        // bright patches drifting along the band, and extra glow where a fold turns
        float glowPatch = 0.4 + 0.9 * noise(vec2(x * 2.5 - iTime * PULSE, fi * 5.0 + iTime * MORPH * 2.0));
        float edgeOn = 1.0 + FOLD_GLOW * smoothstep(0.15, 0.6, abs(slope * amp));

        // green low on the curtain, violet above it; the top of the screen leans violet too,
        // so a farther band's green edge never sits above a nearer band's violet
        float violet = max(smoothstep(0.02, GREEN_DEPTH, d),
                           SKY_VIOLET * smoothstep(0.6, 1.0, y));
        vec3 col = mix(EDGE_COLOR, TOP_COLOR, violet);
        float haze = HAZE * exp(-abs(d) * 8.0);
        aurora += (col * curtain * rays * glowPatch * edgeOn + EDGE_COLOR * haze) * near;
    }

    // the whole display slowly breathes brighter and dimmer
    float breathe = 0.8 + 0.2 * noise(vec2(iTime * BREATHE_SPEED, 0.0));
    aurora *= BRIGHTNESS * breathe * mix(1.0, PANEL_GLOW, panel) * FROST_GLOW;
    // soft knee: bright spots lose ~40%, faint glow barely changes; scaled by the brightest
    // channel so the color doesn't shift
    aurora /= 1.0 + SOFTEN * max(aurora.r, max(aurora.g, aurora.b));
    aurora *= mix(LEFT_STRENGTH, 1.0, smoothstep(0.15, 0.75, uv.x));
    aurora *= smoothstep(TOP_ONLY.x, TOP_ONLY.y, y - (uv.x - 0.5) * TILT);   // cutoff follows the tilt

    vec4 term = texture(iChannel0, uv);
    float luma = dot(term.rgb, vec3(0.299, 0.587, 0.114));
    float blend = smoothstep(BLEND_THRESH * 0.4, BLEND_THRESH, 1.0 - luma);
    aurora *= blend;
    vec3 col = term.rgb + aurora;
    if (PANEL_DEBUG == 1) col = mix(col, vec3(1.0, 0.0, 0.0), panel * 0.5);

    // same trick as starfield: raise alpha where the aurora glows so it shows over the glass
    float glow = max(aurora.r, max(aurora.g, aurora.b));
    fragColor = vec4(col, max(term.a, clamp(glow, 0.0, 1.0)));
}
