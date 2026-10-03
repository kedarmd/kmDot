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
if test -x ~/.local/bin/mise
    if status is-interactive
        ~/.local/bin/mise activate fish | source
    else
        ~/.local/bin/mise activate fish --shims | source
    end
end

function ollama-remote
    set -gx OLLAMA_HOST $OLLAMA_REMOTE_IP:11434
    echo "Ollama is now pointing to the RTX 3060 server 🚀"
end

function ollama-local
    set -e OLLAMA_HOST
    echo "Ollama is back to local mode 🏠"
end
