// aurora: northern-lights curtains drifting across the top of the screen, drawn only on dark cells
// loaded by custom-shader in ../config

#define LAYERS        3
#define BRIGHTNESS    0.35
#define SPEED         0.01   // how fast the curtains drift sideways
#define PULSE_SPEED   0.08   // how fast the brightness wave travels along them
#define HEIGHT        0.85   // edge height at mid-screen; with CLIMB it sets where the band enters
                             // (it meets the right side at HEIGHT + CLIMB / 2 = 0.3)
#define WAVE          0.25   // how much the lower edge folds up and down
#define FADE_UP       5.0    // higher = shorter curtains
#define CLIMB         -1.1  // band climbs from the screen edge to the top right (0 = flat, flip sign to mirror)
#define LEFT_FADE     vec2(0.4, 0.5)   // safety cutoff on the code side, in screen widths
#define SLANT         -0.5   // rays lean left as they go up, like \  (0 = vertical)
#define RISE_SPEED    0.15   // how fast light climbs up the rays (0 = still)
#define EDGE_COLOR    vec3(0.15, 1.0, 0.55)  // bright green lower edge
#define TOP_COLOR     vec3(0.55, 0.25, 1.0)  // violet upper fringe
#define BLEND_THRESH  0.5
#define PANEL_GLOW    0.3    // aurora strength behind nvim panels (blurred: no rays)
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

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

// smooth 1D value noise
float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash(i), hash(i + 1.0), f);
}

float fbm(float x) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(x);
        x *= 2.03;
        a *= 0.5;
    }
    return v;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    float x = uv.x * aspect;

    float panel = panelMask(fragCoord);
    vec3 aurora = vec3(0.0);

    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        float t = iTime * SPEED * (1.0 + fi * 0.3);

        // the lower edge folds like a hanging curtain; each layer sits a bit higher
        float fold = fbm(x * 1.5 + t + fi * 10.0);
        float base = HEIGHT + fi * 0.07 + (fold - 0.5) * WAVE + (uv.x - 0.5) * CLIMB;
        float d = uv.y - base;

        // sharp lower edge, long exponential fade upward
        float curtain = smoothstep(-0.015, 0.01, d) * exp(-max(d, 0.0) * FADE_UP);

        // rays: fine noise along x, offset by the fold so the rays bend with it;
        // shifting x by the height tilts them into a backslash shape
        float rx = x - d * SLANT;
        float rays = fbm(rx * 14.0 + fold * 4.0 + t * 3.0 + fi * 5.0);
        rays = 0.3 + 1.4 * rays * rays;

        // bright knots that climb up each ray: noise along the height, scrolling upward
        float rise = noise(d * 18.0 - iTime * RISE_SPEED + rx * 6.0 + fi * 3.0);
        rays *= 0.5 + rise;
        // behind a panel the rays and knots blur away into an even glow
        rays = mix(rays, 1.0, panel);

        // slow brightness wave travelling along the curtain
        float pulse = 0.55 + 0.45 * sin(x * 2.0 - iTime * PULSE_SPEED + fi * 2.1);

        vec3 col = mix(EDGE_COLOR, TOP_COLOR, smoothstep(0.0, 0.3, d));
        aurora += col * curtain * rays * pulse * (1.0 - fi * 0.25);
    }

    aurora *= BRIGHTNESS * mix(1.0, PANEL_GLOW, panel);
    aurora *= smoothstep(LEFT_FADE.x, LEFT_FADE.y, uv.x);

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
