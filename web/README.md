# ReefBuddy Promotional Website

Single-page promotional website for the ReefBuddy iOS app, built with the New Brutalist design system.

## Live URL

**Production:** https://reefbuddy-site.pages.dev

## Design System

The website matches the iOS app's New Brutalist design:

| Element | Value |
|---------|-------|
| Background | `#FFFFFF` (Pure White) |
| Text | `#000000` (Pure Black) |
| Action Color | `#00FFD1` (Electric Aquamarine) |
| Warning Color | `#FF3D00` (Safety Orange) |
| Border Width | 3-4pt solid black |
| Border Radius | 0px (sharp corners only) |
| Shadows | Hard offset 5px 5px, no blur |
| Typography | Space Grotesk (grotesque sans-serif) |

## File Structure

```
web/
├── index.html    # Single-page promotional site
├── style.css     # New Brutalist CSS design system
└── README.md     # This file
```

## Sections

1. **Navigation** - Fixed header with logo and anchor links
2. **Hero** - Bold title, tagline, CTA buttons, phone mockup
3. **Features** - 6 feature cards with icons
4. **Parameters** - Showcase of 9 tracked water parameters
5. **How It Works** - 4-step process explanation
6. **Pricing** - Free tier + IAP credit packages
7. **Quote** - Motivational reef-keeping quote
8. **Download** - App Store button and CTA
9. **Footer** - Links and branding

## Local Development

Open `index.html` directly in a browser:

```bash
open web/index.html
```

Or use a local server:

```bash
npx serve web
```

## Deployment

The site is hosted on Cloudflare Pages.

### Deploy to Production

```bash
npx wrangler pages deploy web --project-name reefbuddy-site
```

### First-Time Setup

If the Pages project doesn't exist:

```bash
# Create the project
npx wrangler pages project create reefbuddy-site --production-branch main

# Deploy
npx wrangler pages deploy web --project-name reefbuddy-site
```

## Features

- **Responsive** - Mobile, tablet, and desktop layouts
- **Accessible** - Focus styles, semantic HTML, ARIA labels
- **Fast** - No JavaScript frameworks, minimal dependencies
- **Interactive** - Hover animations, smooth scrolling, mobile menu

## Dependencies

- **Google Fonts** - Space Grotesk (loaded via CDN)
- **No build tools required** - Pure HTML/CSS/JS

## Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## Customization

### Colors

Edit CSS variables in `style.css`:

```css
:root {
    --white: #FFFFFF;
    --black: #000000;
    --aquamarine: #00FFD1;
    --orange: #FF3D00;
}
```

### Content

Edit `index.html` directly. Key sections:
- Hero text: `.hero-title`, `.hero-subtitle`
- Features: `.feature-card` elements
- Pricing: `.pricing-card` elements
- Download links: `.app-store-btn`

## Related Documentation

- [`../CLAUDE.md`](../CLAUDE.md) - Design system specifications
- [`../iOS/README.md`](../iOS/README.md) - iOS app documentation
