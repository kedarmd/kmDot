set -gx LANG en_IN.UTF-8
set -gx LC_ALL en_IN.UTF-8

source $__fish_config_dir/secrets.fish

starship init fish | source
set -U fish_greeting ""

# Change the ANDROID_HOME path to the Arch default
set -gx ANDROID_HOME /opt/android-sdk

# Add the platform-tools to your path
fish_add_path $ANDROID_HOME/platform-tools

# Set Java Home for Arch
set -gx JAVA_HOME /usr/lib/jvm/java-17-openjdk
fish_add_path $JAVA_HOME/bin

# mise (sole Node provider): interactive shells get full activation,
# non-interactive ones get the shims dir (stable paths, no prompt hooks).
# Prefer a PATH-resolved mise, fall back to the install location.
if command -v mise >/dev/null
    if status is-interactive
        mise activate fish | source
    else
        mise activate fish --shims | source
    end
else if test -x ~/.local/bin/mise
    if status is-interactive
        ~/.local/bin/mise activate fish | source
    else
        ~/.local/bin/mise activate fish --shims | source
    end
end

alias lg="lazygit"

# herdr tab auto-titles: "<tab number>. <directory>" — see
# config/herdr/scripts/herdr-tab-title.mjs. Fires on every prompt but only
# does work when the directory changed, so the prompt stays fast.
function __kmdot_herdr_tab_title --on-event fish_prompt
    test -n "$HERDR_ENV"; or return
    test "$PWD" != "$_kmdot_herdr_tab_title_pwd"; or return
    set -g _kmdot_herdr_tab_title_pwd "$PWD"
    command node ~/.config/herdr/scripts/herdr-tab-title.mjs "$PWD"
end
