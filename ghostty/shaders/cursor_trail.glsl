// cursor trail: a short smear from where the cursor was to where it jumped
// loaded as the 2nd custom-shader in ../config, so iChannel0 is sky.glsl's output
// iCurrentCursor / iPreviousCursor: xy = top-left corner in pixels (y up), zw = width, height

// seconds for the trail to shrink back into the cursor
const float DURATION = 0.18;
// the trail grows with the jump: none at 1 cell (typing, hjkl), full strength from FULL_AT cells
const float FULL_AT = 8.0;
// trail strength at its thick end, for a full-strength jump
const float OPACITY = 0.75;

// distance from p to segment a-b; t = where along it (0 at a, 1 at b)
float segDist(vec2 p, vec2 a, vec2 b, out float t) {
    vec2 pa = p - a, ba = b - a;
    t = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * t);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    // no trail to or from a bar cursor: nvim insert mode, which is where the
    // telescope prompt lives, so opening/closing a picker doesn't smear
    if (iCurrentCursorStyle == CURSORSTYLE_BAR || iPreviousCursorStyle == CURSORSTYLE_BAR) return;
    // hidden cursor (lazygit, peaclock, hex): the trail would lead to nothing
    if (iCursorVisible == 0) return;
    // color changed with the jump: a tmux popup opened or closed (tmux/popup-cursor
    // tags the color inside popups), so the jump is across layers, not a real move
    if (any(greaterThan(abs(iCurrentCursorColor.rgb - iPreviousCursorColor.rgb), vec3(0.001)))) return;

    vec2 size = iCurrentCursor.zw;
    vec2 head = iCurrentCursor.xy + vec2(0.5, -0.5) * size;
    vec2 start = iPreviousCursor.xy + vec2(0.5, -0.5) * iPreviousCursor.zw;

    // jump length in cells (columns or rows, whichever is more)
    vec2 cells = abs(head - start) / size;
    float strength = clamp((max(cells.x, cells.y) - 1.0) / (FULL_AT - 1.0), 0.0, 1.0);
    if (strength <= 0.0) return;

    float p = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    if (p >= 1.0) return;
    // ease-out cubic: the tail catches up fast, then settles
    vec2 tail = mix(start, head, 1.0 - pow(1.0 - p, 3.0));

    float t;
    float d = segDist(fragCoord, tail, head, t);
    // thin at the tail, half the cursor height at the head
    float radius = mix(0.1, 0.5, t) * size.y;
    float mask = 1.0 - smoothstep(radius - 1.0, radius + 1.0, d);

    // leave the cursor cell itself alone (the char under a block cursor stays readable)
    vec2 q = abs(fragCoord - head) - 0.5 * size;
    if (max(q.x, q.y) < 0.0) mask = 0.0;

    float alpha = mask * OPACITY * strength * mix(0.25, 1.0, t) * (1.0 - p);
    fragColor.rgb = mix(fragColor.rgb, iCurrentCursorColor.rgb, alpha);
}
