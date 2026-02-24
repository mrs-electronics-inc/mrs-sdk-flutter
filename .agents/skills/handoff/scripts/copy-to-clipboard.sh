#!/usr/bin/env bash
# Copies text to system clipboard
# Usage: echo "text" | ./copy-to-clipboard.sh
#    or: ./copy-to-clipboard.sh "text"

set -e

if [ -n "$1" ]; then
    TEXT="$1"
else
    TEXT=$(cat)
fi

if command -v wl-copy &> /dev/null; then
    echo -n "$TEXT" | wl-copy
elif command -v xclip &> /dev/null; then
    echo -n "$TEXT" | xclip -selection clipboard
elif command -v pbcopy &> /dev/null; then
    echo -n "$TEXT" | pbcopy
else
    echo "Error: No clipboard utility found (wl-copy, xclip, or pbcopy)" >&2
    exit 1
fi
