#!/bin/bash
# Setup script for ReefBuddy git hooks
# Run this to enable pre-commit validation

set -e

echo "🔧 Setting up git hooks for ReefBuddy..."

# Make the pre-commit hook executable
if [ -f ".git/hooks/pre-commit" ]; then
    chmod +x .git/hooks/pre-commit
    echo "✅ Made pre-commit hook executable"
else
    echo "❌ Pre-commit hook not found at .git/hooks/pre-commit"
    exit 1
fi

echo "🟢 Git hooks setup complete!"
echo ""
echo "The pre-commit hook will now:"
echo "- Validate Xcode project file syntax"
echo "- Check for UUID collisions"
echo "- Verify Swift file references"
echo "- Prevent commits that could break the Xcode project"