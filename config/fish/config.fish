set -gx LANG en_IN.UTF-8
set -gx LC_ALL en_IN.UTF-8

starship init fish | source
set -U fish_greeting ""

# Change the ANDROID_HOME path to the Arch default
set -gx ANDROID_HOME /opt/android-sdk

# Add the platform-tools to your path
fish_add_path $ANDROID_HOME/platform-tools

# Set Java Home for Arch
set -gx JAVA_HOME /usr/lib/jvm/java-17-openjdk
fish_add_path $JAVA_HOME/bin

