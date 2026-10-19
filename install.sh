#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/dotfiles-pre-restore-$(date +%Y%m%d-%H%M%S)"

echo "=== Arch Linux dotfiles restore ==="
echo "This will install packages and restore your saved configs."
read -r -p "Continue? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

command -v pacman >/dev/null 2>&1 || {
  echo "Error: this script requires Arch Linux."
  exit 1
}

# Back up existing configurations.
mkdir -p "$BACKUP_DIR"
for path in \
  .config/hypr .config/kitty .config/fastfetch \
  .config/serpantinum .config/nvim .config/cava \
  .config/easyeffects .config/environment.d \
  .config/gpu-screen-recorder .config/gtk-3.0 \
  .config/qt5ct .config/qt6ct .config/starship.toml .zshrc; do
  if [[ -e "$HOME/$path" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$path")"
    cp -a "$HOME/$path" "$BACKUP_DIR/$path"
  fi
done

# Install official repository packages.
sudo pacman -Syu --needed curl git base-devel
sudo pacman -S --needed - <"$DOTFILES_DIR/packages-official.txt"

# Install yay if necessary.
if ! command -v yay >/dev/null 2>&1; then
  TEMP_DIR="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"
  (cd "$TEMP_DIR/yay" && makepkg -si --noconfirm)
  rm -rf "$TEMP_DIR"
fi

# Install AUR packages, excluding yay and its debug package.
mapfile -t AUR_PACKAGES < <(
  grep -Ev '^(yay|yay-debug)$' "$DOTFILES_DIR/packages-aur.txt"
)

if ((${#AUR_PACKAGES[@]})); then
  yay -S --needed "${AUR_PACKAGES[@]}"
fi

# Install Serpantinum using its official interactive installer.
# Download the official Serpantinum installer for inspection.
INSTALLER="$(mktemp)"
trap 'rm -f "$INSTALLER"' EXIT

curl -fsSL \
  https://raw.githubusercontent.com/ilyamiro/serpantinum/master/install/install.sh \
  -o "$INSTALLER"

echo "Serpantinum installer downloaded to: $INSTALLER"
echo "Review it before running it."
read -r -p "Run the Serpantinum installer? [y/N] " run_installer

if [[ "$run_installer" =~ ^[Yy]$ ]]; then
  bash "$INSTALLER"
fi

rm -f "$INSTALLER"
trap - EXIT

# Restore configs AFTER installing Serpantinum.
mkdir -p "$HOME/.config"
cp -a "$DOTFILES_DIR/.config/." "$HOME/.config/"
cp -a "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

# Expand home-relative paths in the restored JSON configs.
sed -i "s|\"source\": \"~/|\"source\": \"$HOME/|" \
  "$HOME/.config/fastfetch/config.jsonc"
sed -i "s|\"avatarPath\": \"~/|\"avatarPath\": \"$HOME/|" \
  "$HOME/.config/serpantinum/settings.json"
sed -i "s|\"soundFile\": \"~/|\"soundFile\": \"$HOME/|" \
  "$HOME/.config/serpantinum/settings.json"

# Restore the custom Serpantinum sound.
mkdir -p "$HOME/.local/share/serpantinum"
cp -a "$DOTFILES_DIR/.local/share/serpantinum/." \
  "$HOME/.local/share/serpantinum/"

# Restore profile pictures.
mkdir -p "$HOME/Pictures/pfp"
cp -a "$DOTFILES_DIR/Pictures/pfp/." "$HOME/Pictures/pfp/"

echo
echo "Restore finished."
echo "Backup of previous configs: $BACKUP_DIR"
echo "Review any errors above, then log out and back in if needed."
