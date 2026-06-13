#!/usr/bin/env bash

# Source quickshell caching module
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/caching.sh"
qs_ensure_cache "wallpaper_picker"

SRC_DIR="$HOME/Pictures/Wallpapers"
THUMB_DIR="$QS_CACHE_WALLPAPER_PICKER/thumbs"
PREP_LOCK="$QS_RUN_DIR/wallpaper_prep.lock"
MANIFEST="$THUMB_DIR/.manifest"

export MAGICK_THREAD_LIMIT=1
mkdir -p "$THUMB_DIR"

# Ensure single instance execution
if [ -f "$PREP_LOCK" ]; then
    if kill -0 "$(cat "$PREP_LOCK")" 2>/dev/null; then
        exit 0
    fi
fi
echo $BASHPID > "$PREP_LOCK"

# Rebuild manifest if source dir changed
THUMB_SOURCE_FILE="$THUMB_DIR/.source_dir"
if [ -f "$THUMB_SOURCE_FILE" ]; then
    read -r CACHED_SRC < "$THUMB_SOURCE_FILE"
    if [ "$CACHED_SRC" != "$SRC_DIR" ]; then
        find "$THUMB_DIR" -maxdepth 1 -type f ! -name '.source_dir' ! -name '.manifest' -delete
        echo "$SRC_DIR" > "$THUMB_SOURCE_FILE"
        > "$MANIFEST"
    fi
else
    echo "$SRC_DIR" > "$THUMB_SOURCE_FILE"
    > "$MANIFEST"
fi

if [ ! -f "$MANIFEST" ]; then
    find "$THUMB_DIR" -maxdepth 1 -type f ! -name '.source_dir' ! -name '.manifest' -printf "%f\n" | sort > "$MANIFEST"
fi

SRC_LIST=$(mktemp)
find "$SRC_DIR" -maxdepth 1 -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
       -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.mkv" \
       -o -iname "*.mov" -o -iname "*.webm" \) \
    -printf "%f\n" | sort > "$SRC_LIST"

# Clean orphaned thumbnails
comm -23 <(sed 's/^000_//' "$MANIFEST" | sort) "$SRC_LIST" | while read -r orphan; do
    rm -f "$THUMB_DIR/$orphan" "$THUMB_DIR/000_$orphan"
    sed -i "/^${orphan}$/d;/^000_${orphan}$/d" "$MANIFEST"
done

# Generate missing thumbnails for local wallpapers and videos
while IFS= read -r filename; do
    img="$SRC_DIR/$filename"
    [ -f "$img" ] || continue

    extension="${filename##*.}"

    if [[ "${extension,,}" == "webp" ]]; then
        new_img="${img%.*}.jpg"
        magick "$img" "$new_img" && rm -f "$img"
        img="$new_img"
        filename="$(basename "$img")"
        extension="jpg"
    fi

    if [[ "${extension,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
        thumb="$THUMB_DIR/000_$filename"
        [ -f "$THUMB_DIR/$filename" ] && rm -f "$THUMB_DIR/$filename"
        if [ ! -f "$thumb" ]; then
            ffmpeg -y -ss 00:00:05 -i "$img" -vframes 1 -threads 1 -f image2 -q:v 2 "$thumb" >/dev/null 2>&1
            echo "000_$filename" >> "$MANIFEST"
        fi
    else
        thumb="$THUMB_DIR/$filename"
        if [ ! -f "$thumb" ]; then
            magick "$img" -resize x420 -quality 70 "$thumb"
            echo "$filename" >> "$MANIFEST"
        fi
    fi
done < <(comm -23 "$SRC_LIST" <(sed 's/^000_//' "$MANIFEST" | sort))

rm -f "$SRC_LIST" "$PREP_LOCK"
