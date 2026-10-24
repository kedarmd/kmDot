#!/usr/bin/env bash
# SDR appearance adjustments, scoped by Hyprland's wl_output monitor ID.
set -euo pipefail
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/kmdot"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp/kmdot-$UID}/kmdot-display-color"
mkdir -p "$state_dir" "$runtime_dir"
chmod 700 "$runtime_dir"
exec 9>"$runtime_dir/lock"
flock 9
state_file="$state_dir/display-color.json"
values='{}'
if [[ -f "$state_file" ]]; then
  values=$(jq -ce '
    if type == "object" and all(.[];
      type == "object" and ([.contrast,.saturation,.gamma] | all(type == "number"))
      and .contrast >= 0.5 and .contrast <= 1.5
      and .saturation >= 0 and .saturation <= 2
      and .gamma >= 0.7 and .gamma <= 1.3)
    then . else error("Invalid color settings") end' "$state_file")
fi
monitors=$(hyprctl monitors all -j)
option=$(hyprctl getoption decoration:screen_shader -j 2>/dev/null || true)
if ! jq -e 'type == "object"' <<< "$option" >/dev/null 2>&1; then option='{}'; fi
current=$(jq -r '.str // ""' <<< "$option")
available=true
reason=''
if ! jq -e 'has("str")' <<< "$option" >/dev/null; then
  available=false; reason='Color adjustment is unavailable on this Hyprland version.'
elif [[ -n "$current" && "$current" != '[[EMPTY]]' && "$current" != "$runtime_dir/a.frag" && "$current" != "$runtime_dir/b.frag" ]]; then
  available=false; reason='Another screen filter is active. Turn it off to adjust colors here.'
fi
if [[ "${1:-refresh}" == set ]]; then
  [[ "$available" == true ]] || { echo "$reason" >&2; exit 1; }
  connector="${2:?Missing display}"
  jq -e --arg name "$connector" '.[] | select(.name == $name and .disabled != true and ((.colorManagementPreset // "srgb") | startswith("hdr") | not))' <<< "$monitors" >/dev/null
  # Keep useful, bounded ranges; never allow a black or inverted display.
  adjustment=$(jq -cn --argjson contrast "${3:?}" --argjson saturation "${4:?}" --argjson gamma "${5:?}" '
    if ([$contrast,$saturation,$gamma] | all(type == "number"))
      and $contrast >= 0.5 and $contrast <= 1.5
      and $saturation >= 0 and $saturation <= 2
      and $gamma >= 0.7 and $gamma <= 1.3
    then {contrast:$contrast,saturation:$saturation,gamma:$gamma} else error("Invalid adjustment") end')
  values=$(jq -c --arg name "$connector" --argjson v "$adjustment" '.[$name] = $v' <<< "$values")
fi
if [[ "$available" == true ]]; then
  shader=$(jq -nr --argjson values "$values" --argjson monitors "$monitors" '
    def glfloat: tostring | if test("[.eE]") then . else . + ".0" end;
    "#version 300 es\nprecision highp float;\nin vec2 v_texcoord;\nout vec4 fragColor;\nuniform sampler2D tex;\nuniform int wl_output;\nvoid main() {\n  vec4 pixel = texture(tex, v_texcoord);\n  vec3 rgb = pixel.rgb;",
    ($monitors[] | select(.disabled != true and ((.colorManagementPreset // "srgb") | startswith("hdr") | not)) |
      . as $m | ($values[.name] // {contrast:1,saturation:1,gamma:1}) as $v |
      select($v.contrast != 1 or $v.saturation != 1 or $v.gamma != 1) |
      "  if (wl_output == \($m.id)) {\n    float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));\n    rgb = mix(vec3(luma), rgb, \($v.saturation | glfloat));\n    rgb = (rgb - 0.5) * \($v.contrast | glfloat) + 0.5;\n    rgb = pow(clamp(rgb, 0.0, 1.0), vec3(1.0 / \($v.gamma | glfloat)));\n  }"),
    "  fragColor = vec4(rgb, pixel.a);\n}"
  ')
  target=''
  if [[ "$shader" == *'if (wl_output'* ]]; then
    target="$runtime_dir/a.frag"
    [[ "$current" == "$target" ]] && target="$runtime_dir/b.frag"
    # Alternating paths force Hyprland to reload changed shader contents.
    if [[ -f "$current" && ( "$current" == "$runtime_dir/a.frag" || "$current" == "$runtime_dir/b.frag" ) ]] && [[ "$(cat "$current")" == "$shader" ]]; then
      target="$current"
    else
      printf '%s\n' "$shader" > "$target"
    fi
  fi
  if [[ "$current" != "$target" && !( -z "$target" && ( -z "$current" || "$current" == '[[EMPTY]]' ) ) ]]; then
    lua_path=$(jq -Rn --arg path "$target" '$path')
    result=$(hyprctl eval "hl.config({ decoration = { screen_shader = $lua_path } })" 2>&1)
    if [[ "$result" != ok* ]] || [[ "$result" =~ [Ee]rror|[Ff]ailed ]]; then
      printf '%s\n' "$result" >&2; exit 1
    fi
  fi
fi
if [[ "${1:-refresh}" == set ]]; then
  printf '%s\n' "$values" > "$state_file.tmp"
  mv "$state_file.tmp" "$state_file"
fi
jq -cn --argjson values "$values" --argjson available "$available" --arg reason "$reason" '{values:$values, available:$available, reason:$reason}'
