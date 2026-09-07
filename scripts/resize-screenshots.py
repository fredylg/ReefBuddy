#!/usr/bin/env python3
"""
Resize screenshots to exact App Store requirements.
Usage: python3 resize-screenshots.py <input-screenshot.png> [output-dir]
"""

import sys
from pathlib import Path
from PIL import Image

# App Store screenshot sizes (width, height)
SCREENSHOT_SIZES = {
    'iphone_67_portrait': (1284, 2778),   # iPhone 14/15 Pro Max Portrait
    'iphone_67_landscape': (2778, 1284),  # iPhone 14/15 Pro Max Landscape
    'iphone_65_portrait': (1242, 2688),   # iPhone 11 Pro Max, XS Max Portrait
    'iphone_65_landscape': (2688, 1242),  # iPhone 11 Pro Max, XS Max Landscape
}

def resize_screenshot(input_path, output_dir=None, view_name='screenshot'):
    """Resize a screenshot to all App Store required sizes."""
    input_path = Path(input_path)
    
    if not input_path.exists():
        print(f"❌ Error: File not found: {input_path}")
        return False
    
    # Load image
    try:
        img = Image.open(input_path)
        print(f"✓ Loaded: {input_path} ({img.size[0]}x{img.size[1]})")
    except Exception as e:
        print(f"❌ Error loading image: {e}")
        return False
    
    # Determine output directory
    if output_dir:
        output_dir = Path(output_dir)
    else:
        output_dir = Path('assets/upload-store/real-screenshots')
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Resize to each required size
    success_count = 0
    for size_name, (width, height) in SCREENSHOT_SIZES.items():
        output_path = output_dir / f"{size_name}_{view_name}.png"
        
        try:
            # Resize with high-quality resampling
            resized = img.resize((width, height), Image.Resampling.LANCZOS)
            resized.save(output_path, 'PNG', optimize=True)
            
            # Verify dimensions
            verify = Image.open(output_path)
            if verify.size == (width, height):
                print(f"✓ Created: {output_path} ({width}x{height})")
                success_count += 1
            else:
                print(f"⚠ Warning: {output_path} has wrong size: {verify.size}")
        except Exception as e:
            print(f"❌ Error creating {output_path}: {e}")
    
    print(f"\n✅ Successfully created {success_count}/{len(SCREENSHOT_SIZES)} screenshots")
    print(f"📁 Output directory: {output_dir}")
    return success_count == len(SCREENSHOT_SIZES)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 resize-screenshots.py <input-screenshot.png> [view-name] [output-dir]")
        print("\nExample:")
        print("  python3 resize-screenshots.py ~/Desktop/screenshot.png tank-list")
        print("\nThis will create:")
        for size_name, (w, h) in SCREENSHOT_SIZES.items():
            print(f"  - {size_name}_tank-list.png ({w}x{h})")
        sys.exit(1)
    
    input_file = sys.argv[1]
    view_name = sys.argv[2] if len(sys.argv) > 2 else 'screenshot'
    output_dir = sys.argv[3] if len(sys.argv) > 3 else None
    
    print("📸 App Store Screenshot Resizer")
    print("=" * 40)
    print(f"Input: {input_file}")
    print(f"View name: {view_name}")
    print()
    
    success = resize_screenshot(input_file, output_dir, view_name)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
