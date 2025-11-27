#!/usr/bin/env bash
# Creates a test repo with merge conflicts for testing ydiffconflicts
# Usage: ./make-conflicts.sh [directory]

set -e

DIR="${1:-/tmp/test-conflicts}"
rm -rf "$DIR"
mkdir -p "$DIR"
cd "$DIR"

git init
git config user.email "test@test.com"
git config user.name "Test"
git config merge.conflictStyle zdiff3

# Create initial file
cat > poem.txt << 'EOF'
Roses are red,
Violets are blue,
Sugar is sweet,
And so are you.
EOF

git add poem.txt
git commit -m "Initial poem"

# Create branch with changes
git checkout -b feature
cat > poem.txt << 'EOF'
Roses are red,
Violets are purple,
Sugar is sweet,
And so is maple surple.
EOF
git commit -am "Feature: purple violets"

# Create conflicting changes on main
git checkout main
cat > poem.txt << 'EOF'
Roses are crimson,
Violets are blue,
Honey is sweet,
And so are you.
EOF
git commit -am "Main: crimson roses, honey"

# Attempt merge (will conflict)
echo ""
echo "=== Creating merge conflict ==="
git merge feature || true

echo ""
echo "=== Conflict created in: $DIR ==="
echo "Run: cd $DIR && git mergetool"
