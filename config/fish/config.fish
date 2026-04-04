set -gx LANG en_IN.UTF-8
set -gx LC_ALL en_IN.UTF-8

starship init fish | source
set -U fish_greeting ""
