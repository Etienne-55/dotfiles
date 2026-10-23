package ui

import (
	"fmt"
	"math"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/charmbracelet/lipgloss"
)

// bigLogo is HEX in ANSI Shadow letters.
var bigLogo = []string{
	"██╗  ██╗███████╗██╗  ██╗",
	"██║  ██║██╔════╝╚██╗██╔╝",
	"███████║█████╗   ╚███╔╝ ",
	"██╔══██║██╔══╝   ██╔██╗ ",
	"██║  ██║███████╗██╔╝ ██╗",
	"╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝",
}

// miniLogo is the same two rows high, for
// terminals too short for the big one.
var miniLogo = []string{
	"█ █ █▀▀ ▀▄▀",
	"█▀█ ██▄ █ █",
}

var (
	logoFrom   = hexRGB("#2fa561") // top left: witch-fire
	logoTo     = hexRGB("#0c3d22") // bottom right: nearly spent
	logoShadow = lipgloss.Color("#040d08")
)

// flameMsg advances the logo's flames by a frame.
type flameMsg struct{}

func flameTick() tea.Cmd {
	return tea.Tick(90*time.Millisecond, func(time.Time) tea.Msg { return flameMsg{} })
}

// flicker is how far the flames push a cell's color along the gradient at
// a frame, between -1 and 1. Every wave moves up the rows as the frames go,
// so the fire rises; the column terms keep the tongues apart.
func flicker(c, r, frame int) float64 {
	x, y, f := float64(c), float64(r), float64(frame)
	return 0.5*math.Sin(0.9*x+1.1*y+0.45*f) +
		0.3*math.Sin(-0.37*x+2.3*y+0.21*f) +
		0.2*math.Sin(1.7*x+0.6*y+0.8*f)
}

// renderLogo draws a logo's letters in a dark green fading toward black
// from the top left, burning: the flames of the frame move each letter
// cell along that same gradient, never past its two ends. Their box-drawn
// shadows are black. The terminal's background is see-through, so the
// black shadows still show against it.
func renderLogo(rows []string, frame int) string {
	width := lipgloss.Width(rows[0])
	out := make([]string, len(rows))
	for r, line := range rows {
		var b strings.Builder
		for c, ch := range []rune(line) {
			switch ch {
			case ' ':
				b.WriteRune(ch)
			case '█', '▀', '▄':
				t := float64(c) / float64(max(width-1, 1))
				if len(rows) > 1 {
					t = (t + float64(r)/float64(len(rows)-1)) / 2
				}
				t = math.Max(0, math.Min(1, t+0.35*flicker(c, r, frame)))
				color := fmt.Sprintf("#%02x%02x%02x",
					lerp(logoFrom[0], logoTo[0], t), lerp(logoFrom[1], logoTo[1], t), lerp(logoFrom[2], logoTo[2], t))
				b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color(color)).Render(string(ch)))
			default:
				b.WriteString(lipgloss.NewStyle().Foreground(logoShadow).Render(string(ch)))
			}
		}
		out[r] = b.String()
	}
	return strings.Join(out, "\n")
}

func hexRGB(hex string) [3]int {
	var rgb [3]int
	fmt.Sscanf(strings.TrimPrefix(hex, "#"), "%02x%02x%02x", &rgb[0], &rgb[1], &rgb[2])
	return rgb
}

func lerp(a, b int, t float64) int {
	return a + int(float64(b-a)*t+0.5)
}
