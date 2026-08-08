/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Swiss Editorial App Palette (Light Paper / Dark Inverted)
        paper: '#FFFFFF',
        paperAlt: '#FBFBFB',
        ink: '#111111',
        inkMuted: '#666666',
        inkLight: '#888888',
        hairline: '#E5E5E5',
        hairlineDark: '#D0D0D0',
        klein: '#002FA7',        // Klein Blue primary
        signal: '#FF4400',       // Signal Red (variance / danger)
        posted: '#067647',       // Financial green (posted / success)
        pending: '#B54708',      // Amber (HITL review / pending)

        // Dark variant tokens for Swiss App
        darkPaper: '#0F0F0F',
        darkSurface: '#1A1A1A',
        darkHairline: '#2A2A2A',
        darkInk: '#E5E5E5',
        darkInkMuted: '#999999',
        darkKlein: '#2E5BFF',

        // Cinematic Landing Palette (Graphite default / Light inverted)
        graphite: '#0A0A0A',
        graphiteLight: '#141414',
        graphiteCard: '#0F0F0F',
        warmWhite: '#FAFAF7',
        warmMuted: '#999994',
        landingHairline: '#1F1F1F',
        landingHairlineHover: '#333333',
        electric: '#2E5BFF',
        amberGlow: '#F59E0B',

        // Light landing variant tokens
        lightLandingBg: '#FAFAF7',
        lightLandingText: '#111111',
        lightLandingHairline: '#E5E5E5',
        lightElectric: '#0066FF',
        lightAmber: '#D97706',
      },
      fontFamily: {
        display: ['"Space Grotesk Variable"', '"Space Grotesk"', 'sans-serif'],
        body: ['"Inter Variable"', 'Inter', 'sans-serif'],
        mono: ['"IBM Plex Mono"', 'monospace'],
        serifDisplay: ['"Instrument Serif"', 'serif'],
      },
      borderRadius: {
        DEFAULT: '0px',
        none: '0px',
        sm: '2px',
        md: '2px',
        lg: '2px',
        xl: '4px',
        '2xl': '4px',
      },
      letterSpacing: {
        micro: '0.08em',
        tightest: '-0.04em',
        tighter: '-0.02em',
      },
      borderWidth: {
        hairline: '1px',
      }
    },
  },
  plugins: [],
}
