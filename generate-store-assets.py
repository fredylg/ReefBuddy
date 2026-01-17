#!/usr/bin/env python3
"""
Generate App Store assets for ReefBuddy iOS app.
Creates app icon and screenshots for all required device sizes.
"""

from PIL import Image, ImageDraw, ImageFont
import os
from pathlib import Path

# Design system colors (New Brutalist)
COLORS = {
    'white': (255, 255, 255),
    'black': (0, 0, 0),
    'aquamarine': (0, 255, 209),  # #00FFD1
    'orange': (255, 61, 0),       # #FF3D00
    'gray': (128, 128, 128),
    'light_gray': (240, 240, 240),
}

# Device screenshot sizes (width, height)
SCREENSHOT_SIZES = {
    'iphone_67': (1290, 2796),      # iPhone 14 Pro Max, 15 Pro Max
    'iphone_65': (1242, 2688),      # iPhone 11 Pro Max, XS Max
    'iphone_55': (1242, 2208),      # iPhone 8 Plus
    'ipad_129': (2048, 2732),       # iPad Pro 12.9" (3rd gen)
    'ipad_11': (1668, 2388),        # iPad Pro 11" (2nd gen)
}

def get_font(size, bold=False):
    """Get a font, falling back to default if system fonts unavailable."""
    try:
        if bold:
            # Try to use a bold system font
            try:
                return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", size)
            except:
                try:
                    return ImageFont.truetype("/Library/Fonts/Arial Bold.ttf", size)
                except:
                    pass
        else:
            try:
                return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", size)
            except:
                try:
                    return ImageFont.truetype("/Library/Fonts/Arial.ttf", size)
                except:
                    pass
    except:
        pass
    return ImageFont.load_default()

def draw_text_with_shadow(draw, text, position, font, text_color, shadow_color, shadow_offset=(5, 5)):
    """Draw text with hard shadow (no blur)."""
    # Draw shadow first
    shadow_pos = (position[0] + shadow_offset[0], position[1] + shadow_offset[1])
    draw.text(shadow_pos, text, font=font, fill=shadow_color)
    # Draw text on top
    draw.text(position, text, font=font, fill=text_color)

def draw_border(draw, bbox, width, color):
    """Draw a border around a bounding box."""
    x1, y1, x2, y2 = bbox
    # Top
    draw.rectangle([x1, y1, x2, y1 + width], fill=color)
    # Bottom
    draw.rectangle([x1, y2 - width, x2, y2], fill=color)
    # Left
    draw.rectangle([x1, y1, x1 + width, y2], fill=color)
    # Right
    draw.rectangle([x2 - width, y1, x2, y2], fill=color)

def create_app_icon():
    """Create the 1024x1024 app icon."""
    size = 1024
    img = Image.new('RGB', (size, size), COLORS['aquamarine'])
    draw = ImageDraw.Draw(img)
    
    # Border
    draw_border(draw, (0, 0, size, size), int(size * 0.03), COLORS['black'])
    
    # "RB" text with shadow
    font_size = int(size * 0.45)
    font = get_font(font_size, bold=True)
    
    # Calculate text position (centered)
    text = "RB"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (size - text_width) // 2
    y = (size - text_height) // 2
    
    # Draw shadow
    shadow_offset = int(size * 0.02)
    draw_text_with_shadow(
        draw, text, (x, y), font,
        COLORS['white'], COLORS['black'],
        shadow_offset=(shadow_offset, shadow_offset)
    )
    
    return img

def create_screenshot_tank_list(width, height):
    """Create a screenshot of the tank list view."""
    img = Image.new('RGB', (width, height), COLORS['white'])
    draw = ImageDraw.Draw(img)
    
    # Status bar area (notch/safe area)
    status_height = int(height * 0.06)
    draw.rectangle([0, 0, width, status_height], fill=COLORS['white'])
    
    # Header
    header_height = int(height * 0.12)
    header_y = status_height
    draw.rectangle([0, header_y, width, header_y + header_height], fill=COLORS['white'])
    
    # Title
    title_font = get_font(int(width * 0.08), bold=True)
    title = "REEFBUDDY"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    title_x = int(width * 0.05)
    title_y = header_y + (header_height - (bbox[3] - bbox[1])) // 2
    draw.text((title_x, title_y), title, font=title_font, fill=COLORS['black'])
    
    # Free tier badge
    badge_x = width - int(width * 0.25)
    badge_y = header_y + int(header_height * 0.3)
    badge_w = int(width * 0.2)
    badge_h = int(header_height * 0.4)
    draw.rectangle([badge_x, badge_y, badge_x + badge_w, badge_y + badge_h], fill=COLORS['aquamarine'])
    draw_border(draw, (badge_x, badge_y, badge_x + badge_w, badge_y + badge_h), 3, COLORS['black'])
    badge_font = get_font(int(width * 0.03), bold=True)
    draw.text((badge_x + 10, badge_y + 5), "FREE", font=badge_font, fill=COLORS['black'])
    
    # Content area
    content_y = header_y + header_height
    content_height = height - content_y - int(height * 0.1)  # Leave space for tab bar
    
    # Tank cards
    card_spacing = int(height * 0.03)
    card_height = int(content_height * 0.25)
    card_width = width - int(width * 0.1)
    card_x = int(width * 0.05)
    
    tanks = [
        ("Reef Tank 1", "125 gal", "Active"),
        ("Nano Reef", "30 gal", "Active"),
        ("Frag Tank", "40 gal", "Inactive"),
    ]
    
    for i, (name, volume, status) in enumerate(tanks):
        card_y = content_y + (card_height + card_spacing) * i + int(height * 0.02)
        
        # Card background with shadow
        shadow_offset = 5
        draw.rectangle(
            [card_x + shadow_offset, card_y + shadow_offset,
             card_x + card_width + shadow_offset, card_y + card_height + shadow_offset],
            fill=COLORS['black']
        )
        draw.rectangle(
            [card_x, card_y, card_x + card_width, card_y + card_height],
            fill=COLORS['white']
        )
        draw_border(draw, (card_x, card_y, card_x + card_width, card_y + card_height), 3, COLORS['black'])
        
        # Tank name
        name_font = get_font(int(width * 0.05), bold=True)
        draw.text((card_x + 20, card_y + 15), name, font=name_font, fill=COLORS['black'])
        
        # Volume
        volume_font = get_font(int(width * 0.035))
        draw.text((card_x + 20, card_y + 50), volume, font=volume_font, fill=COLORS['gray'])
        
        # Status badge
        if status == "Active":
            status_x = card_x + card_width - int(width * 0.15)
            status_y = card_y + 15
            status_w = int(width * 0.12)
            status_h = int(card_height * 0.25)
            draw.rectangle([status_x, status_y, status_x + status_w, status_y + status_h], fill=COLORS['aquamarine'])
            draw_border(draw, (status_x, status_y, status_x + status_w, status_y + status_h), 2, COLORS['black'])
            status_font = get_font(int(width * 0.025), bold=True)
            draw.text((status_x + 5, status_y + 3), "ACTIVE", font=status_font, fill=COLORS['black'])
    
    # Tab bar
    tab_y = height - int(height * 0.1)
    tab_height = int(height * 0.1)
    draw.rectangle([0, tab_y, width, height], fill=COLORS['white'])
    draw_border(draw, (0, tab_y, width, height), 3, COLORS['black'])
    
    tabs = ["TANKS", "MEASURE", "HISTORY", "SETTINGS"]
    tab_width = width // len(tabs)
    tab_font = get_font(int(width * 0.025), bold=True)
    for i, tab in enumerate(tabs):
        tab_x = i * tab_width
        if i == 0:  # Selected
            draw.rectangle([tab_x, tab_y, tab_x + tab_width, height], fill=COLORS['aquamarine'])
        draw.text((tab_x + tab_width // 4, tab_y + 10), tab, font=tab_font, fill=COLORS['black'])
    
    return img

def create_screenshot_analysis(width, height):
    """Create a screenshot of the AI analysis view."""
    img = Image.new('RGB', (width, height), COLORS['white'])
    draw = ImageDraw.Draw(img)
    
    # Status bar
    status_height = int(height * 0.06)
    
    # Header
    header_height = int(height * 0.1)
    header_y = status_height
    draw.rectangle([0, header_y, width, header_y + header_height], fill=COLORS['white'])
    
    # Back button
    back_font = get_font(int(width * 0.04), bold=True)
    draw.text((int(width * 0.05), header_y + 20), "← BACK", font=back_font, fill=COLORS['black'])
    
    # Title
    title_font = get_font(int(width * 0.06), bold=True)
    title = "AI ANALYSIS"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    title_x = (width - (bbox[2] - bbox[0])) // 2
    draw.text((title_x, header_y + 15), title, font=title_font, fill=COLORS['black'])
    
    # Content
    content_y = header_y + header_height
    scroll_y = content_y
    
    # Parameter status grid
    grid_title_font = get_font(int(width * 0.05), bold=True)
    draw.text((int(width * 0.05), scroll_y + 20), "PARAMETER STATUS", font=grid_title_font, fill=COLORS['black'])
    scroll_y += int(height * 0.08)
    
    # Parameter cards
    params = [
        ("pH", "8.2", "✓", COLORS['aquamarine']),
        ("Alkalinity", "8.5 dKH", "✓", COLORS['aquamarine']),
        ("Calcium", "420 ppm", "✓", COLORS['aquamarine']),
        ("Nitrate", "5 ppm", "⚠", COLORS['orange']),
    ]
    
    card_w = int(width * 0.42)
    card_h = int(height * 0.12)
    card_spacing = int(width * 0.03)
    
    for i, (name, value, status, color) in enumerate(params):
        row = i // 2
        col = i % 2
        card_x = int(width * 0.05) + col * (card_w + card_spacing)
        card_y = scroll_y + row * (card_h + card_spacing)
        
        # Shadow
        shadow_offset = 5
        draw.rectangle(
            [card_x + shadow_offset, card_y + shadow_offset,
             card_x + card_w + shadow_offset, card_y + card_h + shadow_offset],
            fill=COLORS['black']
        )
        
        # Card
        draw.rectangle([card_x, card_y, card_x + card_w, card_y + card_h], fill=COLORS['white'])
        draw_border(draw, (card_x, card_y, card_x + card_w, card_y + card_h), 3, COLORS['black'])
        
        # Parameter name
        name_font = get_font(int(width * 0.035), bold=True)
        draw.text((card_x + 15, card_y + 10), name, font=name_font, fill=COLORS['black'])
        
        # Value
        value_font = get_font(int(width * 0.04))
        draw.text((card_x + 15, card_y + 40), value, font=value_font, fill=COLORS['gray'])
        
        # Status icon
        status_font = get_font(int(width * 0.05), bold=True)
        draw.text((card_x + card_w - 40, card_y + 20), status, font=status_font, fill=color)
    
    scroll_y += int(height * 0.3)
    
    # Recommendations section
    draw.text((int(width * 0.05), scroll_y + 20), "RECOMMENDATIONS", font=grid_title_font, fill=COLORS['black'])
    scroll_y += int(height * 0.08)
    
    rec_card_w = width - int(width * 0.1)
    rec_card_h = int(height * 0.12)
    rec_card_x = int(width * 0.05)
    rec_card_y = scroll_y
    
    # Shadow
    shadow_offset = 5
    draw.rectangle(
        [rec_card_x + shadow_offset, rec_card_y + shadow_offset,
         rec_card_x + rec_card_w + shadow_offset, rec_card_y + rec_card_h + shadow_offset],
        fill=COLORS['black']
    )
    
    # Card
    draw.rectangle([rec_card_x, rec_card_y, rec_card_x + rec_card_w, rec_card_y + rec_card_h], fill=COLORS['white'])
    draw_border(draw, (rec_card_x, rec_card_y, rec_card_x + rec_card_w, rec_card_y + rec_card_h), 3, COLORS['black'])
    
    rec_font = get_font(int(width * 0.035))
    draw.text((rec_card_x + 15, rec_card_y + 20), "• Increase water changes to reduce nitrate", font=rec_font, fill=COLORS['black'])
    
    return img

def create_screenshot_measurement(width, height):
    """Create a screenshot of the measurement entry view."""
    img = Image.new('RGB', (width, height), COLORS['white'])
    draw = ImageDraw.Draw(img)
    
    # Status bar
    status_height = int(height * 0.06)
    
    # Header
    header_height = int(height * 0.1)
    header_y = status_height
    draw.rectangle([0, header_y, width, header_y + header_height], fill=COLORS['white'])
    
    # Title
    title_font = get_font(int(width * 0.06), bold=True)
    title = "ENTER MEASUREMENTS"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    title_x = (width - (bbox[2] - bbox[0])) // 2
    draw.text((title_x, header_y + 15), title, font=title_font, fill=COLORS['black'])
    
    # Content
    content_y = header_y + header_height
    scroll_y = content_y + int(height * 0.02)
    
    # Parameter inputs
    params = [
        ("pH", "8.2", "Target: 8.1-8.4"),
        ("Alkalinity (dKH)", "8.5", "Target: 8-12 dKH"),
        ("Calcium (ppm)", "420", "Target: 400-450 ppm"),
        ("Magnesium (ppm)", "1350", "Target: 1300-1400 ppm"),
    ]
    
    input_h = int(height * 0.08)
    input_w = width - int(width * 0.1)
    input_x = int(width * 0.05)
    input_spacing = int(height * 0.02)
    
    for i, (label, value, target) in enumerate(params):
        input_y = scroll_y + i * (input_h + input_spacing)
        
        # Label
        label_font = get_font(int(width * 0.035), bold=True)
        draw.text((input_x, input_y), label, font=label_font, fill=COLORS['black'])
        
        # Input field
        field_y = input_y + int(height * 0.04)
        draw.rectangle([input_x, field_y, input_x + input_w, field_y + input_h], fill=COLORS['white'])
        draw_border(draw, (input_x, field_y, input_x + input_w, field_y + input_h), 3, COLORS['black'])
        
        # Value
        value_font = get_font(int(width * 0.04))
        draw.text((input_x + 15, field_y + 15), value, font=value_font, fill=COLORS['black'])
        
        # Target range
        target_font = get_font(int(width * 0.025))
        draw.text((input_x, field_y + input_h + 5), target, font=target_font, fill=COLORS['gray'])
    
    # Analyze button
    button_y = scroll_y + len(params) * (input_h + input_spacing) + int(height * 0.05)
    button_h = int(height * 0.08)
    button_w = width - int(width * 0.1)
    button_x = int(width * 0.05)
    
    # Shadow
    shadow_offset = 5
    draw.rectangle(
        [button_x + shadow_offset, button_y + shadow_offset,
         button_x + button_w + shadow_offset, button_y + button_h + shadow_offset],
        fill=COLORS['black']
    )
    
    # Button
    draw.rectangle([button_x, button_y, button_x + button_w, button_y + button_h], fill=COLORS['aquamarine'])
    draw_border(draw, (button_x, button_y, button_x + button_w, button_y + button_h), 3, COLORS['black'])
    
    button_font = get_font(int(width * 0.045), bold=True)
    button_text = "ANALYZE PARAMETERS"
    bbox = draw.textbbox((0, 0), button_text, font=button_font)
    button_text_x = button_x + (button_w - (bbox[2] - bbox[0])) // 2
    button_text_y = button_y + (button_h - (bbox[3] - bbox[1])) // 2
    draw.text((button_text_x, button_text_y), button_text, font=button_font, fill=COLORS['black'])
    
    return img

def create_screenshot_chart(width, height):
    """Create a screenshot of the chart/history view."""
    img = Image.new('RGB', (width, height), COLORS['white'])
    draw = ImageDraw.Draw(img)
    
    # Status bar
    status_height = int(height * 0.06)
    
    # Header
    header_height = int(height * 0.1)
    header_y = status_height
    draw.rectangle([0, header_y, width, header_y + header_height], fill=COLORS['white'])
    
    # Title
    title_font = get_font(int(width * 0.06), bold=True)
    title = "HISTORY & TRENDS"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    title_x = (width - (bbox[2] - bbox[0])) // 2
    draw.text((title_x, header_y + 15), title, font=title_font, fill=COLORS['black'])
    
    # Content
    content_y = header_y + header_height
    
    # Chart area
    chart_y = content_y + int(height * 0.03)
    chart_h = int(height * 0.4)
    chart_w = width - int(width * 0.1)
    chart_x = int(width * 0.05)
    
    # Chart background
    draw.rectangle([chart_x, chart_y, chart_x + chart_w, chart_y + chart_h], fill=COLORS['white'])
    draw_border(draw, (chart_x, chart_y, chart_x + chart_w, chart_y + chart_h), 3, COLORS['black'])
    
    # Simple line chart (jagged brutalist style)
    line_points = []
    for i in range(10):
        x = chart_x + int((i / 9) * chart_w)
        y = chart_y + chart_h - int((0.3 + (i % 3) * 0.1) * chart_h)
        line_points.append((x, y))
    
    # Draw line
    for i in range(len(line_points) - 1):
        draw.line([line_points[i], line_points[i + 1]], fill=COLORS['black'], width=4)
    
    # Axis labels
    label_font = get_font(int(width * 0.025))
    draw.text((chart_x + 10, chart_y + 10), "pH", font=label_font, fill=COLORS['black'])
    draw.text((chart_x + 10, chart_y + chart_h - 20), "8.0", font=label_font, fill=COLORS['gray'])
    draw.text((chart_x + chart_w - 50, chart_y + chart_h - 20), "8.4", font=label_font, fill=COLORS['gray'])
    
    # Recent measurements
    list_y = chart_y + chart_h + int(height * 0.05)
    list_title_font = get_font(int(width * 0.04), bold=True)
    draw.text((chart_x, list_y), "RECENT MEASUREMENTS", font=list_title_font, fill=COLORS['black'])
    list_y += int(height * 0.06)
    
    measurements = [
        ("Jan 15, 2024", "pH: 8.2 | Alk: 8.5 | Ca: 420"),
        ("Jan 12, 2024", "pH: 8.1 | Alk: 8.3 | Ca: 415"),
        ("Jan 10, 2024", "pH: 8.3 | Alk: 8.4 | Ca: 425"),
    ]
    
    item_h = int(height * 0.06)
    item_spacing = int(height * 0.02)
    
    for i, (date, params) in enumerate(measurements):
        item_y = list_y + i * (item_h + item_spacing)
        
        # Item card
        item_w = chart_w
        draw.rectangle([chart_x, item_y, chart_x + item_w, item_y + item_h], fill=COLORS['white'])
        draw_border(draw, (chart_x, item_y, chart_x + item_w, item_y + item_h), 2, COLORS['black'])
        
        # Date
        date_font = get_font(int(width * 0.03), bold=True)
        draw.text((chart_x + 10, item_y + 10), date, font=date_font, fill=COLORS['black'])
        
        # Parameters
        param_font = get_font(int(width * 0.025))
        draw.text((chart_x + 10, item_y + 35), params, font=param_font, fill=COLORS['gray'])
    
    return img

def main():
    """Generate all App Store assets."""
    output_dir = Path('assets/upload-store')
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print("Generating App Store assets...")
    
    # App Icon
    print("  Creating app icon (1024x1024)...")
    icon = create_app_icon()
    icon.save(output_dir / 'AppIcon-1024.png', 'PNG')
    
    # Screenshots for each device size
    screenshot_configs = [
        ('iphone_67', 'iPhone 6.7"', create_screenshot_tank_list),
        ('iphone_65', 'iPhone 6.5"', create_screenshot_tank_list),
        ('iphone_55', 'iPhone 5.5"', create_screenshot_tank_list),
        ('ipad_129', 'iPad Pro 12.9"', create_screenshot_tank_list),
        ('ipad_11', 'iPad Pro 11"', create_screenshot_tank_list),
    ]
    
    screenshot_views = [
        ('tank-list', 'Tank List', create_screenshot_tank_list),
        ('analysis', 'Analysis', create_screenshot_analysis),
        ('measurement', 'Measurement Entry', create_screenshot_measurement),
        ('chart', 'History & Charts', create_screenshot_chart),
    ]
    
    for device_key, device_name, _ in screenshot_configs:
        width, height = SCREENSHOT_SIZES[device_key]
        device_dir = output_dir / device_key
        device_dir.mkdir(exist_ok=True)
        
        print(f"  Creating screenshots for {device_name} ({width}x{height})...")
        
        # Generate multiple screenshots showing different views
        for view_key, view_name, view_func in screenshot_views:
            screenshot = view_func(width, height)
            filename = f"{device_key}_{view_key}.png"
            screenshot.save(device_dir / filename, 'PNG')
            print(f"    ✓ {filename}")
    
    print(f"\n✅ All assets generated in {output_dir}/")
    print("\nAsset structure:")
    print("  assets/upload-store/")
    print("    ├── AppIcon-1024.png")
    print("    ├── iphone_67/")
    print("    ├── iphone_65/")
    print("    ├── iphone_55/")
    print("    ├── ipad_129/")
    print("    └── ipad_11/")

if __name__ == '__main__':
    main()
