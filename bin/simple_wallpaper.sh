#!/bin/bash

# ============================================================
# WALLPAPER CHOOSER SCRIPT - ENHANCED VERSION
# ============================================================
# A comprehensive wallpaper and theme management script for Arch Linux
# Features:
#   - Wallpaper selection with Rofi thumbnail previews
#   - Pywal color scheme generation with validation
#   - Theme updates for: Rofi, Polybar, wlogout, Dunst, Firefox, Discord, Zed
#   - Betterlockscreen cache management
#   - Automatic image format conversion
#   - Robust error handling and color validation
# ============================================================

set -o pipefail

# --- Configuration ---
readonly WALLPAPER_DIR="$HOME/Wallpapers"
readonly POLYBAR_CONFIG="$HOME/.config/polybar/mytheme.conf"
readonly POLYBAR_BAR="pywaltheme"
readonly FEH_RESTORE_SCRIPT="$HOME/.feh_restore.sh"
readonly LOG_FILE="$HOME/.wallpaper_chooser.log"
readonly STATUS_FILE="$HOME/.wallpaper_chooser.status"
readonly THUMBNAIL_CACHE_DIR="$HOME/.cache/wallpaper_thumbnails"
readonly THUMBNAIL_SIZE="500x500"
readonly WLOGOUT_STYLE_FILE="$HOME/.config/wlogout/style.css"
readonly ROFI_THEME_FILE="$HOME/.config/rofi/themes/tokyo.rasi"
readonly PYWAL_COLOR_SH="$HOME/.cache/wal/colors.sh"
readonly PYWAL_COLOR_JSON="$HOME/.cache/wal/colors.json"

# Zed theme wal location
readonly ZED_THEME_WAL_DIR="$HOME/zed-theme-wal"
readonly ZED_THEMES_DIR="$HOME/.config/zed/themes"

# Fallback colors (Tokyo Night inspired)
readonly FALLBACK_BG="#1a1b26"
readonly FALLBACK_FG="#c0caf5"
readonly FALLBACK_ACCENT="#7aa2f7"
readonly FALLBACK_URGENT="#f7768e"

# --- Global Color Variables ---
declare -g WAL_BG="" WAL_FG=""
declare -g WAL_COLOR0="" WAL_COLOR1="" WAL_COLOR2="" WAL_COLOR3=""
declare -g WAL_COLOR4="" WAL_COLOR5="" WAL_COLOR6="" WAL_COLOR7=""
declare -g WAL_COLOR8="" WAL_COLOR9="" WAL_COLOR10="" WAL_COLOR11=""
declare -g WAL_COLOR12="" WAL_COLOR13="" WAL_COLOR14="" WAL_COLOR15=""
declare -g COLORS_LOADED=false
declare -g DOMINANT_COLOR=""

# --- Environment Fixes ---
[[ -f "$HOME/.profile" ]] && source "$HOME/.profile" 2>/dev/null
export DISPLAY="${DISPLAY:-:0}"
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

# ============================================================
# UTILITY FUNCTIONS
# ============================================================

log() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

log_section() {
  log "------------------------------------------------------------"
  log "$*"
  log "------------------------------------------------------------"
}

notify() {
  notify-send "$1" "$2" 2>/dev/null || true
}

check_dependencies() {
  local missing=()
  local deps=("rofi" "feh" "wal" "convert")

  for dep in "${deps[@]}"; do
    command -v "$dep" &>/dev/null || missing+=("$dep")
  done

  if ((${#missing[@]} > 0)); then
    log "ERROR: Missing required dependencies: ${missing[*]}"
    notify "Wallpaper Chooser" "Missing dependencies: ${missing[*]}"
    exit 1
  fi
}

# ============================================================
# COLOR VALIDATION & LOADING
# ============================================================

is_valid_hex() {
  local color="${1#\#}"
  [[ "$color" =~ ^[0-9A-Fa-f]{6}$ ]]
}

# Ensure color has # prefix
normalize_color() {
  local color="$1"
  color="${color#\#}" # Remove # if present
  if is_valid_hex "#$color"; then
    echo "#$color"
  else
    echo ""
  fi
}

load_pywal_colors() {
  log "ACTION: Loading pywal colors..."

  if [[ ! -f "$PYWAL_COLOR_SH" ]]; then
    log "ERROR: Pywal colors file not found: $PYWAL_COLOR_SH"
    return 1
  fi

  # Source in subshell to avoid polluting namespace, then extract
  local color_data
  color_data=$(
    source "$PYWAL_COLOR_SH" 2>/dev/null
    echo "BG=${background:-}"
    echo "FG=${foreground:-}"
    for i in {0..15}; do
      var="color$i"
      echo "C$i=${!var:-}"
    done
  )

  if [[ -z "$color_data" ]]; then
    log "ERROR: Failed to parse pywal colors"
    return 1
  fi

  # Parse the output
  local line
  while IFS='=' read -r key value; do
    value=$(normalize_color "$value")
    case "$key" in
    BG) WAL_BG="$value" ;;
    FG) WAL_FG="$value" ;;
    C0) WAL_COLOR0="$value" ;;
    C1) WAL_COLOR1="$value" ;;
    C2) WAL_COLOR2="$value" ;;
    C3) WAL_COLOR3="$value" ;;
    C4) WAL_COLOR4="$value" ;;
    C5) WAL_COLOR5="$value" ;;
    C6) WAL_COLOR6="$value" ;;
    C7) WAL_COLOR7="$value" ;;
    C8) WAL_COLOR8="$value" ;;
    C9) WAL_COLOR9="$value" ;;
    C10) WAL_COLOR10="$value" ;;
    C11) WAL_COLOR11="$value" ;;
    C12) WAL_COLOR12="$value" ;;
    C13) WAL_COLOR13="$value" ;;
    C14) WAL_COLOR14="$value" ;;
    C15) WAL_COLOR15="$value" ;;
    esac
  done <<<"$color_data"

  # Log raw values for debugging
  log "INFO: Pywal raw - BG:$WAL_BG C0:$WAL_COLOR0 C1:$WAL_COLOR1 C4:$WAL_COLOR4"

  # Apply fallbacks for missing colors
  [[ -z "$WAL_BG" ]] && WAL_BG="$FALLBACK_BG"
  [[ -z "$WAL_COLOR0" ]] && WAL_COLOR0="$WAL_BG"
  [[ -z "$WAL_FG" ]] && WAL_FG="$FALLBACK_FG"
  [[ -z "$WAL_COLOR1" ]] && WAL_COLOR1="$FALLBACK_URGENT"
  [[ -z "$WAL_COLOR4" ]] && WAL_COLOR4="$FALLBACK_ACCENT"
  [[ -z "$WAL_COLOR7" ]] && WAL_COLOR7="$WAL_FG"
  [[ -z "$WAL_COLOR8" ]] && WAL_COLOR8=$(darken_color "$WAL_FG" 30)

  # Fill remaining colors with derived values if empty
  for i in {2..15}; do
    local var="WAL_COLOR$i"
    if [[ -z "${!var}" ]]; then
      declare -g "$var"=$(lighten_color "$WAL_BG" $((i * 5 + 10)))
    fi
  done

  COLORS_LOADED=true
  log "SUCCESS: Colors loaded - BG:$WAL_BG FG:$WAL_FG C0:$WAL_COLOR0 C4:$WAL_COLOR4"
  return 0
}

ensure_colors_loaded() {
  if [[ "$COLORS_LOADED" != "true" ]]; then
    load_pywal_colors || return 1
  fi
  return 0
}

# ============================================================
# COLOR MANIPULATION FUNCTIONS
# ============================================================

hex_to_rgba() {
  local hex="${1#\#}"
  local alpha="${2:-1.0}"

  if ! is_valid_hex "#$hex"; then
    log "WARNING: Invalid hex color: $1, using fallback"
    echo "rgba(0, 0, 0, $alpha)"
    return 1
  fi

  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))

  printf "rgba(%d, %d, %d, %s)\n" "$r" "$g" "$b" "$alpha"
}

lighten_color() {
  local hex="${1#\#}"
  local percent="${2:-20}"

  if ! is_valid_hex "#$hex"; then
    echo "#$hex"
    return 1
  fi

  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))

  r=$((r + (255 - r) * percent / 100))
  g=$((g + (255 - g) * percent / 100))
  b=$((b + (255 - b) * percent / 100))

  ((r > 255)) && r=255
  ((g > 255)) && g=255
  ((b > 255)) && b=255

  printf "#%02x%02x%02x\n" "$r" "$g" "$b"
}

darken_color() {
  local hex="${1#\#}"
  local percent="${2:-20}"

  if ! is_valid_hex "#$hex"; then
    echo "#$hex"
    return 1
  fi

  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))

  r=$((r * (100 - percent) / 100))
  g=$((g * (100 - percent) / 100))
  b=$((b * (100 - percent) / 100))

  ((r < 0)) && r=0
  ((g < 0)) && g=0
  ((b < 0)) && b=0

  printf "#%02x%02x%02x\n" "$r" "$g" "$b"
}

get_brightness() {
  local hex="${1#\#}"

  if ! is_valid_hex "#$hex"; then
    echo "128" # Return mid-brightness as fallback
    return 1
  fi

  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))

  # Use perceived brightness formula (ITU-R BT.709)
  echo $(((r * 299 + g * 587 + b * 114) / 1000))
}

# Get color saturation (0-100)
get_saturation() {
  local hex="${1#\#}"

  if ! is_valid_hex "#$hex"; then
    echo "0"
    return 1
  fi

  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))

  local max=$r
  ((g > max)) && max=$g
  ((b > max)) && max=$b

  local min=$r
  ((g < min)) && min=$g
  ((b < min)) && min=$b

  if ((max == 0)); then
    echo "0"
  else
    echo $(((max - min) * 100 / max))
  fi
}

# Find the best accent color from pywal (brightest with good saturation)
# Sets global DOMINANT_COLOR variable
find_dominant_color() {
  local best_color=""
  local best_brightness=0

  log "INFO: Finding dominant accent color from pywal palette..."

  for i in 1 2 3 4 5 6; do
    local var="WAL_COLOR$i"
    local color="${!var}"

    if [[ -n "$color" ]] && is_valid_hex "$color"; then
      local bright=$(get_brightness "$color")
      local sat=$(get_saturation "$color")

      log "DEBUG: color$i=$color brightness=$bright saturation=$sat"

      # Prefer brighter colors with decent saturation
      if ((bright > best_brightness && sat > 15)); then
        best_brightness=$bright
        best_color="$color"
      fi
    fi
  done

  # Fallback to color6 (usually brightest) or color4
  if [[ -z "$best_color" ]]; then
    best_color="${WAL_COLOR6:-${WAL_COLOR4:-$FALLBACK_ACCENT}}"
  fi

  DOMINANT_COLOR="$best_color"
  log "INFO: Dominant color selected: $DOMINANT_COLOR (brightness: $best_brightness)"
}

# ============================================================
# THUMBNAIL FUNCTIONS
# ============================================================

generate_thumbnail() {
  local wallpaper_path="$1"
  local filename="${wallpaper_path##*/}"
  local thumbnail_path="$THUMBNAIL_CACHE_DIR/${filename%.*}_thumb.jpg"

  mkdir -p "$THUMBNAIL_CACHE_DIR"

  if [[ ! -f "$thumbnail_path" ]] || [[ "$wallpaper_path" -nt "$thumbnail_path" ]]; then
    convert "$wallpaper_path" -thumbnail "$THUMBNAIL_SIZE" -quality 85 "$thumbnail_path" 2>/dev/null
  fi
  echo "$thumbnail_path"
}

generate_all_thumbnails() {
  local -n files_ref=$1
  local max_jobs="${2:-4}"
  local job_count=0

  log "ACTION: Generating thumbnails (max $max_jobs parallel jobs)..."

  for filepath in "${files_ref[@]}"; do
    generate_thumbnail "$filepath" >/dev/null &
    ((job_count++))
    if ((job_count >= max_jobs)); then
      wait -n 2>/dev/null || wait
      ((job_count--))
    fi
  done
  wait
  log "SUCCESS: Thumbnails cached"
}

# ============================================================
# UI FUNCTIONS
# ============================================================

show_status_menu() {
  local status_message="$1"
  local has_errors="$2"
  local prompt_text="  STATUS: $status_message"
  local options

  if [[ "$has_errors" == "true" ]]; then
    options="   Change Again\n   View Logs\n   Exit"
  else
    options="   Change Again\n   Exit"
  fi

  echo -e "$options" | rofi -dmenu -i -p "$prompt_text" \
    -theme-str 'listview { lines: 3; }' \
    -theme-str 'inputbar { children: [prompt]; }'
}

# ============================================================
# THEME UPDATE FUNCTIONS
# ============================================================

update_rofi_theme() {
  log "ACTION: Starting Rofi theme update..."

  ensure_colors_loaded || return 1

  mkdir -p "$(dirname "$ROFI_THEME_FILE")"

  # Use color4 - pywal's PRIMARY accent color (the main color from wallpaper)
  local accent_color="${WAL_COLOR4:-$FALLBACK_ACCENT}"
  local accent_brightness=$(get_brightness "$accent_color")

  log "INFO: Using pywal primary color (color4): $accent_color (brightness: $accent_brightness)"

  # Darken the primary color significantly for background
  local bg0_color
  bg0_color=$(darken_color "$accent_color" 70)

  local final_brightness=$(get_brightness "$bg0_color")

  # Ensure VERY dark (brightness <= 25)
  while ((final_brightness > 25)); do
    bg0_color=$(darken_color "$bg0_color" 30)
    final_brightness=$(get_brightness "$bg0_color")
  done

  log "INFO: Rofi background: $bg0_color (brightness: $final_brightness)"

  # Generate background variants
  local bg1_color bg2_color bg3_color selected_color

  bg1_color=$(lighten_color "$bg0_color" 5)
  bg2_color=$(lighten_color "$bg0_color" 10)
  bg3_color=$(lighten_color "$bg0_color" 15)
  selected_color=$(lighten_color "$bg0_color" 12)

  log "INFO: Rofi palette - bg0:$bg0_color bg1:$bg1_color accent:$accent_color"

  cat >"$ROFI_THEME_FILE" <<EOF
/**
 * Pywal Color Variables for Rofi
 * Generated from: ${FULL_PATH:-wallpaper}
 * Generated at: $(date)
 * Primary color (color4): $accent_color
 * Background: $bg0_color (brightness: $final_brightness)
 */

* {
    /* Background colors - dark, tinted with primary wallpaper color */
    bg0:      ${bg0_color};
    bg1:      ${bg1_color};
    bg2:      ${bg2_color};
    bg3:      ${bg3_color};

    /* Foreground colors */
    fg0:      ${WAL_FG};
    fg1:      ${WAL_COLOR7};
    fg2:      ${WAL_COLOR8};

    /* Accent color - primary wallpaper color */
    accent:   ${accent_color};
    
    /* Urgent color */
    urgent:   ${WAL_COLOR1};

    /* Selection color */
    selected: ${selected_color};

    /* Full pywal palette */
    background: ${bg0_color};
    foreground: ${WAL_FG};
    color0:   ${WAL_COLOR0};
    color1:   ${WAL_COLOR1};
    color2:   ${WAL_COLOR2};
    color3:   ${WAL_COLOR3};
    color4:   ${WAL_COLOR4};
    color5:   ${WAL_COLOR5};
    color6:   ${WAL_COLOR6};
    color7:   ${WAL_COLOR7};
    color8:   ${WAL_COLOR8};
    color9:   ${WAL_COLOR9};
    color10:  ${WAL_COLOR10};
    color11:  ${WAL_COLOR11};
    color12:  ${WAL_COLOR12};
    color13:  ${WAL_COLOR13};
    color14:  ${WAL_COLOR14};
    color15:  ${WAL_COLOR15};
}
EOF

  if [[ $? -eq 0 ]]; then
    log "SUCCESS: Rofi theme updated - bg:$bg0_color accent:$accent_color"
    return 0
  else
    log "ERROR: Failed to write Rofi theme"
    return 1
  fi
}

update_wlogout() {
  log "ACTION: Starting wlogout theme update..."

  ensure_colors_loaded || return 1

  mkdir -p "$(dirname "$WLOGOUT_STYLE_FILE")"

  # Use color4 (primary) for wlogout too
  local accent_color="${WAL_COLOR4:-$FALLBACK_ACCENT}"

  # Very dark background with color tint
  local wlogout_bg
  wlogout_bg=$(darken_color "$accent_color" 85)

  local bg_brightness=$(get_brightness "$wlogout_bg")
  while ((bg_brightness > 20)); do
    wlogout_bg=$(darken_color "$wlogout_bg" 30)
    bg_brightness=$(get_brightness "$wlogout_bg")
  done

  log "INFO: Wlogout background: $wlogout_bg (brightness: $bg_brightness)"

  # Button colors
  local button_base
  button_base=$(lighten_color "$wlogout_bg" 20)

  # MORE TRANSPARENT - alpha 0.7 for window, 0.75 for buttons
  local window_bg button_bg button_hover_bg button_active_bg

  window_bg=$(hex_to_rgba "$wlogout_bg" "0.7")
  button_bg=$(hex_to_rgba "$button_base" "0.75")
  button_hover_bg=$(hex_to_rgba "$accent_color" "0.85")
  button_active_bg=$(hex_to_rgba "$accent_color" "1.0")

  cat >"$WLOGOUT_STYLE_FILE" <<EOF
/**
 * wlogout GTK3 CSS - Pywal Generated
 * Generated at: $(date)
 * Primary color: $accent_color
 * Background: $wlogout_bg (transparent)
 */

* {
    background-image: none;
    font-family: "JetBrains Mono", "monospace";
}

window {
    background-color: ${window_bg};
}

#layout {
    padding: 0px;
    margin: 0px;
}

button {
    border-radius: 12px;
    background-color: ${button_bg};
    border: 2px solid #ffffff;
    color: ${WAL_FG};
    margin: 6px;
    padding: 0px;
    background-repeat: no-repeat;
    background-position: center center;
    background-size: 28%;
    text-shadow: none;
}

button label {
    margin-top: 85px;
    font-size: 12px;
    color: ${WAL_FG};
}

button:hover,
button:focus {
    background-color: ${button_hover_bg};
    border: 2px solid #ffffff;
    color: #ffffff;
}

button:hover label,
button:focus label {
    color: #ffffff;
}

button:active {
    background-color: ${button_active_bg};
    border: 2px solid #ffffff;
    color: #ffffff;
}

button:active label {
    color: #ffffff;
}

#lock {
    background-image: url("/usr/share/wlogout/icons/lock.png");
}

#logout {
    background-image: url("/usr/share/wlogout/icons/logout.png");
}

#suspend {
    background-image: url("/usr/share/wlogout/icons/suspend.png");
}

#hibernate {
    background-image: url("/usr/share/wlogout/icons/hibernate.png");
}

#shutdown {
    background-image: url("/usr/share/wlogout/icons/shutdown.png");
}

#reboot {
    background-image: url("/usr/share/wlogout/icons/reboot.png");
}

#windows {
    background-image: url("${HOME}/.local/share/wlogout/icons/windows.png");
}
EOF

  log "SUCCESS: Wlogout theme updated - transparent bg with white borders"
  return 0
}

update_polybar_colors() {
  log "ACTION: Starting Polybar color update..."

  ensure_colors_loaded || return 1

  if [[ ! -f "$POLYBAR_CONFIG" ]]; then
    log "WARNING: Polybar config not found: $POLYBAR_CONFIG"
    return 1
  fi

  # Use dominant color for polybar
  [[ -z "$DOMINANT_COLOR" ]] && find_dominant_color

  local polybar_bg
  polybar_bg=$(darken_color "$DOMINANT_COLOR" 90)

  # Ensure it's very dark
  local bg_brightness
  bg_brightness=$(get_brightness "$polybar_bg")
  while ((bg_brightness > 20)); do
    polybar_bg=$(darken_color "$polybar_bg" 35)
    bg_brightness=$(get_brightness "$polybar_bg")
  done

  log "INFO: Polybar background: $polybar_bg (brightness: $bg_brightness)"

  # Backup config if not already backed up
  [[ ! -f "${POLYBAR_CONFIG}.backup" ]] && cp "$POLYBAR_CONFIG" "${POLYBAR_CONFIG}.backup"

  local temp_config="${POLYBAR_CONFIG}.tmp"

  if grep -q "^\[colors\]" "$POLYBAR_CONFIG"; then
    awk -v newbg="$polybar_bg" '
            /^\[colors\]/ { in_colors=1 }
            /^\[/ && !/^\[colors\]/ { in_colors=0 }
            in_colors && /^background[[:space:]]*=/ {
                print "background = " newbg
                next
            }
            { print }
        ' "$POLYBAR_CONFIG" >"$temp_config"

    if [[ -s "$temp_config" ]]; then
      mv "$temp_config" "$POLYBAR_CONFIG"
      log "SUCCESS: Polybar background updated to $polybar_bg"
      return 0
    fi
  fi

  rm -f "$temp_config"
  log "WARNING: Failed to update Polybar colors"
  return 1
}

update_dunst() {
  log "ACTION: Updating Dunst theme..."

  ensure_colors_loaded || return 1

  local dunst_config="$HOME/.config/dunst/dunstrc"

  if [[ ! -f "$dunst_config" ]]; then
    log "INFO: No dunst config found"
    echo " Dunst: NO CONFIG" >>"$STATUS_FILE"
    return 1
  fi

  [[ ! -f "${dunst_config}.backup" ]] && cp "$dunst_config" "${dunst_config}.backup"

  local temp_dunst="${dunst_config}.tmp"

  # Use dominant color for dunst
  [[ -z "$DOMINANT_COLOR" ]] && find_dominant_color

  local dunst_bg
  dunst_bg=$(darken_color "$DOMINANT_COLOR" 85)

  local bg_brightness=$(get_brightness "$dunst_bg")
  while ((bg_brightness > 25)); do
    dunst_bg=$(darken_color "$dunst_bg" 30)
    bg_brightness=$(get_brightness "$dunst_bg")
  done

  awk -v bg="$dunst_bg" -v fg="$WAL_FG" -v frame="$DOMINANT_COLOR" -v urgent="$WAL_COLOR1" '
        /^\[urgency_low\]/ { section="low" }
        /^\[urgency_normal\]/ { section="normal" }
        /^\[urgency_critical\]/ { section="critical" }
        /^\[/ && !/urgency/ { section="" }
        
        section && /^[[:space:]]*background[[:space:]]*=/ {
            print "    background = \"" bg "\""
            next
        }
        section && /^[[:space:]]*foreground[[:space:]]*=/ {
            print "    foreground = \"" fg "\""
            next
        }
        section == "critical" && /^[[:space:]]*frame_color[[:space:]]*=/ {
            print "    frame_color = \"" urgent "\""
            next
        }
        section && section != "critical" && /^[[:space:]]*frame_color[[:space:]]*=/ {
            print "    frame_color = \"" frame "\""
            next
        }
        { print }
    ' "$dunst_config" >"$temp_dunst"

  if [[ -s "$temp_dunst" ]]; then
    mv "$temp_dunst" "$dunst_config"
    log "SUCCESS: Dunst config updated"

    # Restart dunst
    pkill dunst 2>/dev/null
    sleep 0.2
    command -v dunst &>/dev/null && {
      dunst &>/dev/null &
      disown
    }

    echo " Dunst: SUCCESS" >>"$STATUS_FILE"
    return 0
  fi

  rm -f "$temp_dunst"
  log "ERROR: Failed to update Dunst config"
  echo " Dunst: FAILED" >>"$STATUS_FILE"
  return 1
}

update_pywalfox() {
  log "ACTION: Updating Firefox theme..."

  if ! command -v pywalfox &>/dev/null; then
    log "INFO: pywalfox not installed"
    echo " Pywalfox: NOT INSTALLED" >>"$STATUS_FILE"
    return 1
  fi

  if pywalfox update >>"$LOG_FILE" 2>&1; then
    log "SUCCESS: Pywalfox updated"
    echo " Pywalfox: SUCCESS" >>"$STATUS_FILE"
    return 0
  else
    log "ERROR: Pywalfox failed"
    echo " Pywalfox: FAILED" >>"$STATUS_FILE"
    return 1
  fi
}

update_pywal_discord() {
  log "ACTION: Updating Discord theme..."

  if ! command -v pywal-discord &>/dev/null; then
    log "INFO: pywal-discord not installed"
    echo " Pywal-Discord: NOT INSTALLED" >>"$STATUS_FILE"
    return 1
  fi

  if pywal-discord >>"$LOG_FILE" 2>&1; then
    log "SUCCESS: pywal-discord updated"
    echo " Pywal-Discord: SUCCESS" >>"$STATUS_FILE"
    return 0
  else
    log "ERROR: pywal-discord failed"
    echo " Pywal-Discord: FAILED" >>"$STATUS_FILE"
    return 1
  fi
}

update_zed_theme() {
  log "ACTION: Updating Zed editor theme..."

  local generate_script="$ZED_THEME_WAL_DIR/generate_theme"

  if [[ ! -d "$ZED_THEME_WAL_DIR" ]]; then
    log "INFO: zed-theme-wal not installed at $ZED_THEME_WAL_DIR"
    echo " Zed Theme: NOT INSTALLED" >>"$STATUS_FILE"
    return 1
  fi

  if [[ ! -f "$generate_script" ]]; then
    log "ERROR: generate_theme script not found"
    echo " Zed Theme: SCRIPT MISSING" >>"$STATUS_FILE"
    return 1
  fi

  [[ ! -x "$generate_script" ]] && chmod +x "$generate_script"

  if [[ ! -f "$PYWAL_COLOR_JSON" ]]; then
    log "ERROR: Pywal colors.json not found"
    echo " Zed Theme: NO COLORS" >>"$STATUS_FILE"
    return 1
  fi

  # Run generate_theme from its directory
  if (cd "$ZED_THEME_WAL_DIR" && ./generate_theme >>"$LOG_FILE" 2>&1); then
    log "SUCCESS: Zed theme generated"

    mkdir -p "$ZED_THEMES_DIR"

    # Find and copy theme file
    local theme_file=""
    for loc in "$ZED_THEME_WAL_DIR/themes/pywal.json" \
      "$ZED_THEME_WAL_DIR/pywal.json" \
      "$ZED_THEME_WAL_DIR/theme.json"; do
      if [[ -f "$loc" ]]; then
        theme_file="$loc"
        break
      fi
    done

    if [[ -n "$theme_file" ]]; then
      cp "$theme_file" "$ZED_THEMES_DIR/pywal.json" 2>/dev/null
      log "INFO: Theme copied to $ZED_THEMES_DIR/pywal.json"
    fi

    echo " Zed Theme: SUCCESS" >>"$STATUS_FILE"

    if pgrep -x "zed\|Zed" &>/dev/null; then
      notify "Zed Theme Updated" "Select 'Pywal' theme in Zed if not auto-applied"
    fi

    return 0
  else
    log "ERROR: Zed theme generation failed"
    echo " Zed Theme: FAILED" >>"$STATUS_FILE"
    return 1
  fi
}

# ============================================================
# IMAGE CONVERSION
# ============================================================

convert_incompatible_images() {
  log "ACTION: Checking for incompatible image formats..."
  local converted_count=0

  while IFS= read -r -d '' filepath; do
    local filename="${filepath##*/}"
    local basename_noext="${filename%.*}"
    local output_file="$WALLPAPER_DIR/${basename_noext}.jpg"

    if [[ ! -f "$output_file" ]]; then
      log "INFO: Converting $filename to JPG..."
      if convert "$filepath" "$output_file" 2>>"$LOG_FILE"; then
        log "SUCCESS: Converted $filename"
        rm -f "$filepath"
        ((converted_count++))
      else
        log "ERROR: Failed to convert $filename"
      fi
    fi
  done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" \
    -o -iname "*.tiff" -o -iname "*.tif" -o -iname "*.avif" \
    -o -iname "*.heic" \) -print0 2>/dev/null)

  if ((converted_count > 0)); then
    log "SUCCESS: Converted $converted_count image(s)"
    notify "Wallpaper Converter" "Converted $converted_count image(s) to JPG"
  fi
}

# ============================================================
# POLYBAR MANAGEMENT
# ============================================================

restart_polybar() {
  log "ACTION: Restarting Polybar..."

  if pgrep -x polybar &>/dev/null; then
    killall -q polybar
    local wait_count=0
    while pgrep -x polybar &>/dev/null && ((wait_count < 20)); do
      sleep 0.1
      ((wait_count++))
    done
  fi

  if [[ -f "$POLYBAR_CONFIG" ]]; then
    sleep 0.3
    polybar -c "$POLYBAR_CONFIG" "$POLYBAR_BAR" >>"$LOG_FILE" 2>&1 &
    disown
    log "SUCCESS: Polybar launched"
    echo " Polybar: SUCCESS" >>"$STATUS_FILE"
  else
    log "WARNING: Polybar config not found"
    echo " Polybar: CONFIG NOT FOUND" >>"$STATUS_FILE"
  fi
}

# ============================================================
# MAIN SCRIPT LOGIC
# ============================================================

main() {
  # Initialize log files
  : >"$LOG_FILE"
  : >"$STATUS_FILE"

  log_section "WALLPAPER CHOOSER SCRIPT STARTED"
  log "INFO: Running as $(whoami) on display ${DISPLAY}"

  check_dependencies

  # Ensure wallpaper directory exists
  if [[ ! -d "$WALLPAPER_DIR" ]]; then
    log "INFO: Creating wallpaper directory: $WALLPAPER_DIR"
    mkdir -p "$WALLPAPER_DIR"
    notify "Wallpaper Chooser" "Created wallpaper directory at $WALLPAPER_DIR"
  fi

  convert_incompatible_images

  # Main loop
  while true; do
    : >"$STATUS_FILE"
    COLORS_LOADED=false # Reset colors for new selection
    DOMINANT_COLOR=""   # Reset dominant color

    # Find wallpaper files
    log "ACTION: Scanning for wallpapers..."
    mapfile -d '' WALLPAPER_FILES < <(
      find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) \
        -print0 2>/dev/null | sort -z
    )

    if ((${#WALLPAPER_FILES[@]} == 0)); then
      log "ERROR: No wallpapers found in $WALLPAPER_DIR"
      notify "Wallpaper Chooser" "No wallpapers found"
      exit 1
    fi

    log "INFO: Found ${#WALLPAPER_FILES[@]} wallpaper(s)"

    # Generate thumbnails in parallel
    generate_all_thumbnails WALLPAPER_FILES 4

    # Build Rofi input
    log "ACTION: Launching Rofi wallpaper selector..."
    local rofi_input=""
    for filepath in "${WALLPAPER_FILES[@]}"; do
      local filename="${filepath##*/}"
      local thumbnail_path
      thumbnail_path=$(generate_thumbnail "$filepath")
      rofi_input+="${filename}\0icon\x1f${thumbnail_path}\n"
    done

    # Show Rofi selector
    CHOICE=$(echo -en "$rofi_input" | rofi -dmenu -i -p "  Select Wallpaper:" \
      -show-icons \
      -theme-str 'element { children: [element-icon]; border-radius: 15px; }' \
      -theme-str 'element-icon { size: 8em; border-radius: 10px; }' \
      -theme-str 'listview { lines: 3; columns: 4; spacing: 10px; }' \
      -theme-str 'window { width: 75%; border-radius: 20px; }' \
      -theme-str 'mainbox { padding: 10px; }')

    if [[ -z "$CHOICE" ]]; then
      log "EXIT: User cancelled selection"
      exit 0
    fi

    FULL_PATH="$WALLPAPER_DIR/$CHOICE"
    log "INFO: Selected: $FULL_PATH"

    if [[ ! -f "$FULL_PATH" ]]; then
      log "ERROR: File not found: $FULL_PATH"
      notify "Wallpaper Error" "File not found!"
      continue
    fi

    HAS_ERRORS=false

    # ============================================================
    # APPLY THEME CHANGES
    # ============================================================

    # --- 1. Betterlockscreen Cache ---
    log "ACTION: [1/11] Updating betterlockscreen cache..."
    local bls_cache="$HOME/.cache/betterlockscreen/current"
    local bls_marker="$bls_cache/.wallpaper_path"

    if command -v betterlockscreen &>/dev/null; then
      local needs_update=true
      if [[ -f "$bls_marker" ]]; then
        local cached_wp
        cached_wp=$(cat "$bls_marker" 2>/dev/null)
        [[ "$cached_wp" == "$FULL_PATH" ]] && needs_update=false &&
          log "INFO: Betterlockscreen cache is current" &&
          echo " Betterlockscreen: CACHED" >>"$STATUS_FILE"
      fi

      if [[ "$needs_update" == "true" ]]; then
        mkdir -p "$bls_cache"
        if betterlockscreen -u "$FULL_PATH" --fx dim >>"$LOG_FILE" 2>&1; then
          echo "$FULL_PATH" >"$bls_marker"
          log "SUCCESS: Betterlockscreen cache updated"
          echo " Betterlockscreen: SUCCESS" >>"$STATUS_FILE"
        else
          log "ERROR: Betterlockscreen update failed"
          echo " Betterlockscreen: FAILED" >>"$STATUS_FILE"
          HAS_ERRORS=true
        fi
      fi
    else
      log "INFO: Betterlockscreen not installed"
      echo " Betterlockscreen: NOT INSTALLED" >>"$STATUS_FILE"
    fi

    # --- 2. Pywal Colors ---
    log "ACTION: [2/11] Generating pywal colors..."
    local wal_backend=""
    python3 -c "import colorthief" 2>/dev/null && wal_backend="colorthief"

    local wal_cmd="wal -i \"$FULL_PATH\""
    [[ -n "$wal_backend" ]] && wal_cmd+=" --backend $wal_backend"

    if eval "$wal_cmd" >>"$LOG_FILE" 2>&1; then
      log "SUCCESS: Pywal colors generated"
      echo " Pywal: SUCCESS" >>"$STATUS_FILE"

      # Load colors immediately after pywal generates them
      if load_pywal_colors; then
        log "SUCCESS: Colors loaded into memory"

        # Find dominant color once for all theme updates
        find_dominant_color

        log "DEBUG: Loaded colors:"
        log "DEBUG:   Dominant=$DOMINANT_COLOR"
        log "DEBUG:   color1=$WAL_COLOR1"
        log "DEBUG:   color2=$WAL_COLOR2"
        log "DEBUG:   color3=$WAL_COLOR3"
        log "DEBUG:   color4=$WAL_COLOR4"
        log "DEBUG:   color5=$WAL_COLOR5"
        log "DEBUG:   color6=$WAL_COLOR6"
      else
        log "WARNING: Could not load pywal colors"
        HAS_ERRORS=true
      fi
    else
      log "ERROR: Pywal failed"
      echo " Pywal: FAILED" >>"$STATUS_FILE"
      HAS_ERRORS=true
    fi

    # --- 3-9. Theme Updates ---
    local -a update_tasks=(
      "3:Rofi Theme:update_rofi_theme"
      "4:Wlogout Theme:update_wlogout"
      "5:Polybar Colors:update_polybar_colors"
      "6:Dunst:update_dunst"
      "7:Pywalfox:update_pywalfox"
      "8:Pywal-Discord:update_pywal_discord"
      "9:Zed Theme:update_zed_theme"
    )

    for task in "${update_tasks[@]}"; do
      IFS=':' read -r num name func <<<"$task"
      log "ACTION: [$num/11] Updating $name..."
      if $func; then
        [[ ! "$name" =~ ^(Dunst|Pywalfox|Pywal-Discord|Zed) ]] &&
          echo " $name: SUCCESS" >>"$STATUS_FILE"
      else
        [[ ! "$name" =~ ^(Dunst|Pywalfox|Pywal-Discord|Zed) ]] &&
          echo " $name: FAILED" >>"$STATUS_FILE"
        HAS_ERRORS=true
      fi
    done

    # --- 10. Set Wallpaper with feh ---
    log "ACTION: [10/11] Setting wallpaper..."
    if feh --bg-fill "$FULL_PATH" 2>>"$LOG_FILE"; then
      log "SUCCESS: Wallpaper set"
      echo " Wallpaper: SUCCESS" >>"$STATUS_FILE"
    else
      log "ERROR: feh failed"
      echo " Wallpaper: FAILED" >>"$STATUS_FILE"
      HAS_ERRORS=true
    fi

    # --- 11. Persistence Script ---
    log "ACTION: [11/11] Creating persistence script..."
    cat >"$FEH_RESTORE_SCRIPT" <<EOF
#!/bin/bash
# Auto-generated by wallpaper-chooser
# Wallpaper: $FULL_PATH
# Generated: $(date)
feh --bg-fill "$FULL_PATH"
EOF
    chmod +x "$FEH_RESTORE_SCRIPT"
    log "SUCCESS: Persistence script created"
    echo " Persistence: SUCCESS" >>"$STATUS_FILE"

    # Restart Polybar
    restart_polybar

    # Send notification
    if [[ "$HAS_ERRORS" == "true" ]]; then
      notify "Wallpaper Applied" "Theme updated with some errors"
    else
      notify "Wallpaper Applied" "Theme updated successfully"
    fi

    # ============================================================
    # STATUS MENU
    # ============================================================

    local status_message
    [[ "$HAS_ERRORS" == "true" ]] && status_message="Completed with errors" || status_message="Success"

    local next_action
    next_action=$(show_status_menu "$status_message" "$HAS_ERRORS")
    next_action="${next_action#"${next_action%%[![:space:]]*}"}" # Trim leading whitespace

    case "$next_action" in
    *"View Logs"*)
      log "ACTION: Opening logs"
      if command -v kitty &>/dev/null && command -v nvim &>/dev/null; then
        kitty nvim "$LOG_FILE" &
      elif command -v xdg-open &>/dev/null; then
        xdg-open "$LOG_FILE" &
      fi
      disown 2>/dev/null
      exit 0
      ;;
    *"Exit"* | "")
      log "EXIT: User selected Exit"
      exit 0
      ;;
    *"Change Again"*)
      log "INFO: User selected Change Again"
      continue
      ;;
    *)
      log "INFO: Unknown action: $next_action"
      continue
      ;;
    esac
  done

  log_section "WALLPAPER CHOOSER SCRIPT ENDED"
}

# Run main function
main "$@"
