#!/bin/bash
# Script to capture and process App Store screenshots from iOS Simulator
# Usage: ./scripts/capture-app-screenshots.sh [simulator-name] [view-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# App Store screenshot sizes (width x height)
# key=WIDTHxHEIGHT pairs (plain array: macOS ships bash 3.2, which has no associative arrays)
SCREENSHOT_SIZES=(
    "iphone_67_portrait=1284x2778"
    "iphone_67_landscape=2778x1284"
    "iphone_65_portrait=1242x2688"
    "iphone_65_landscape=2688x1242"
)

# size_for KEY -> WIDTHxHEIGHT
size_for() {
    local entry
    for entry in "${SCREENSHOT_SIZES[@]}"; do
        if [ "${entry%%=*}" = "$1" ]; then
            echo "${entry#*=}"
            return 0
        fi
    done
    return 1
}

OUTPUT_DIR="assets/upload-store/real-screenshots"
SIMULATOR_NAME="${1:-iPhone 15 Pro Max}"
VIEW_NAME="${2:-tank-list}"

echo -e "${GREEN}📸 App Store Screenshot Capture${NC}"
echo "=================================="
echo ""

# Check if xcrun simctl is available
if ! command -v xcrun &> /dev/null; then
    echo -e "${RED}❌ Error: xcrun not found. Xcode Command Line Tools required.${NC}"
    exit 1
fi

# Check if ImageMagick or sips is available for image processing
HAS_SIPS=false
HAS_MAGICK=false

if command -v sips &> /dev/null; then
    HAS_SIPS=true
    echo -e "${GREEN}✓${NC} Found sips (macOS built-in image tool)"
fi

if command -v convert &> /dev/null; then
    HAS_MAGICK=true
    echo -e "${GREEN}✓${NC} Found ImageMagick"
fi

if [ "$HAS_SIPS" = false ] && [ "$HAS_MAGICK" = false ]; then
    echo -e "${YELLOW}⚠ Warning: No image processing tool found.${NC}"
    echo "Screenshots will be saved as-is. Install ImageMagick for automatic resizing:"
    echo "  brew install imagemagick"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo ""
echo "📱 Simulator: $SIMULATOR_NAME"
echo "📄 View: $VIEW_NAME"
echo "📁 Output: $OUTPUT_DIR"
echo ""

# Instructions for manual capture
echo -e "${YELLOW}📋 Instructions:${NC}"
echo "1. Open Xcode and run the app in the iOS Simulator"
echo "2. Navigate to the view you want to screenshot: $VIEW_NAME"
echo "3. In Simulator, go to: Device → Screenshot → [Device Name]"
echo "   OR press Cmd+S to take a screenshot"
echo "4. Screenshots are saved to Desktop by default"
echo ""
echo -e "${YELLOW}Or use automated capture:${NC}"
echo "  xcrun simctl io booted screenshot screenshot.png"
echo ""

# Function to process screenshot
process_screenshot() {
    local input_file="$1"
    local size_key="$2"
    local size
    size=$(size_for "$size_key")
    local width=$(echo $size | cut -d'x' -f1)
    local height=$(echo $size | cut -d'x' -f2)
    local output_file="$OUTPUT_DIR/${size_key}_${VIEW_NAME}.png"
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}❌ Input file not found: $input_file${NC}"
        return 1
    fi
    
    echo "Processing: $input_file → $output_file ($width x $height)"
    
    if [ "$HAS_SIPS" = true ]; then
        # Use sips (macOS built-in)
        sips -z $height $width "$input_file" --out "$output_file" > /dev/null 2>&1
        echo -e "${GREEN}✓${NC} Resized using sips"
    elif [ "$HAS_MAGICK" = true ]; then
        # Use ImageMagick
        convert "$input_file" -resize "${width}x${height}!" "$output_file"
        echo -e "${GREEN}✓${NC} Resized using ImageMagick"
    else
        # Just copy the file
        cp "$input_file" "$output_file"
        echo -e "${YELLOW}⚠${NC} Copied without resizing (install ImageMagick for auto-resize)"
    fi
    
    # Verify dimensions
    if [ "$HAS_SIPS" = true ]; then
        actual_size=$(sips -g pixelWidth -g pixelHeight "$output_file" 2>/dev/null | grep -E "pixelWidth|pixelHeight" | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo "  Actual size: $actual_size"
    fi
}

# Interactive mode: ask user to provide screenshots
echo -e "${GREEN}📥 Interactive Mode${NC}"
echo "Please provide the path to your screenshot file(s):"
echo ""
echo "Option 1: Drag and drop screenshot file(s) here, then press Enter"
echo "Option 2: Type the path to screenshot file(s), one per line"
echo "Option 3: Press Enter to skip and process files later"
echo ""

read -p "Screenshot file path (or Enter to skip): " screenshot_path

if [ -n "$screenshot_path" ] && [ -f "$screenshot_path" ]; then
    # Process for each required size
    for entry in "${SCREENSHOT_SIZES[@]}"; do
        process_screenshot "$screenshot_path" "${entry%%=*}"
    done
    echo ""
    echo -e "${GREEN}✅ Screenshots processed!${NC}"
else
    echo ""
    echo -e "${YELLOW}⏭ Skipping processing.${NC}"
    echo ""
    echo "To process screenshots later, run:"
    echo "  ./scripts/capture-app-screenshots.sh"
    echo ""
    echo "Or manually resize screenshots using:"
    echo "  sips -z 2778 1284 input.png --out output.png"
    echo ""
fi

# Generate helper script for batch processing
cat > "$OUTPUT_DIR/resize-screenshots.sh" << 'EOF'
#!/bin/bash
# Helper script to resize screenshots to App Store requirements
# Usage: ./resize-screenshots.sh input.png

if [ $# -eq 0 ]; then
    echo "Usage: $0 <screenshot-file>"
    exit 1
fi

INPUT="$1"
BASENAME=$(basename "$INPUT" .png)

# App Store sizes
sips -z 2778 1284 "$INPUT" --out "${BASENAME}_iphone_67_portrait.png"
sips -z 1284 2778 "$INPUT" --out "${BASENAME}_iphone_67_landscape.png"
sips -z 2688 1242 "$INPUT" --out "${BASENAME}_iphone_65_portrait.png"
sips -z 1242 2688 "$INPUT" --out "${BASENAME}_iphone_65_landscape.png"

echo "✅ Resized screenshots created!"
EOF

chmod +x "$OUTPUT_DIR/resize-screenshots.sh"

echo ""
echo -e "${GREEN}📋 Next Steps:${NC}"
echo "1. Take screenshots in iOS Simulator (Cmd+S or Device → Screenshot)"
echo "2. Run this script again with screenshot path, OR"
echo "3. Use the helper script: $OUTPUT_DIR/resize-screenshots.sh <screenshot.png>"
echo ""
echo "Required App Store screenshot sizes:"
for entry in "${SCREENSHOT_SIZES[@]}"; do
    echo "  - ${entry%%=*}: ${entry#*=}"
done
echo ""
