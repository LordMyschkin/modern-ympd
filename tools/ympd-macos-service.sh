#!/bin/sh
# Install ympd as a per-user macOS launchd service.
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This installer requires macOS." >&2
    exit 1
fi

label="org.ympd.web"
uid="$(id -u)"
domain="gui/$uid"
service="$domain/$label"
repo="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
build="$repo/build"
install_dir="$HOME/Library/Application Support/ympd"
binary="$install_dir/bin/ympd"
agent_dir="$HOME/Library/LaunchAgents"
plist="$agent_dir/$label.plist"
log_dir="$HOME/Library/Logs/ympd"
action="${1:-install}"
web_port="${2:-6090}"
mpd_host="${YMPD_MPD_HOST:-127.0.0.1}"
mpd_port="${YMPD_MPD_PORT:-6600}"
web_bind="${YMPD_WEB_BIND:-127.0.0.1}"

xml_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

validate_port() {
    case "$1" in
        ''|*[!0-9]*) echo "Invalid port: $1" >&2; exit 2 ;;
    esac
    if [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        echo "Port must be between 1 and 65535." >&2
        exit 2
    fi
}

print_plist() {
    cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(xml_escape "$binary")</string>
        <string>-h</string><string>$(xml_escape "$mpd_host")</string>
        <string>-p</string><string>$mpd_port</string>
        <string>-w</string><string>$(xml_escape "$web_bind"):$web_port</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key><string>$(xml_escape "$HOME")</string>
    </dict>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ThrottleInterval</key><integer>10</integer>
    <key>StandardOutPath</key><string>$(xml_escape "$log_dir/stdout.log")</string>
    <key>StandardErrorPath</key><string>$(xml_escape "$log_dir/stderr.log")</string>
</dict>
</plist>
PLIST
}

case "$action" in
    install|print-plist)
        validate_port "$web_port"
        validate_port "$mpd_port"
        ;;
    status|uninstall)
        if [ "$#" -gt 1 ]; then
            echo "Usage: $0 {install [web-port]|status|uninstall|print-plist [web-port]}" >&2
            exit 2
        fi
        ;;
    *)
        echo "Usage: $0 {install [web-port]|status|uninstall|print-plist [web-port]}" >&2
        exit 2
        ;;
esac

case "$action" in
    print-plist)
        print_plist
        ;;
    status)
        launchctl print "$service"
        ;;
    uninstall)
        if [ -f "$plist" ]; then
            launchctl bootout "$service" 2>/dev/null || true
            rm -f "$plist"
        fi
        rm -f "$binary"
        echo "ympd LaunchAgent removed. Settings and logs were kept."
        ;;
    install)
        command -v cmake >/dev/null || { echo "Install CMake first." >&2; exit 1; }
        command -v pkg-config >/dev/null || { echo "Install pkgconf first." >&2; exit 1; }
        if ! launchctl print "$domain" >/dev/null 2>&1; then
            echo "Log in to the macOS desktop before installing this LaunchAgent." >&2
            exit 1
        fi
        cmake -S "$repo" -B "$build" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DWITH_SSL=ON -DWITH_DYNAMIC_ASSETS=OFF
        cmake --build "$build" -j 2

        mkdir -p "$install_dir/bin" "$agent_dir" "$log_dir"
        temporary_plist="$plist.tmp.$$"
        trap 'rm -f "$temporary_plist"' EXIT HUP INT TERM
        print_plist > "$temporary_plist"
        plutil -lint "$temporary_plist" >/dev/null

        had_agent=0
        if [ -f "$plist" ]; then
            had_agent=1
            launchctl bootout "$service" 2>/dev/null || true
        fi
        if lsof -nP -iTCP:"$web_port" -sTCP:LISTEN >/dev/null 2>&1; then
            if [ "$had_agent" -eq 1 ]; then
                launchctl bootstrap "$domain" "$plist" 2>/dev/null || true
            fi
            echo "Port $web_port is in use. Stop the foreground ympd process before installing." >&2
            exit 1
        fi

        cp "$build/ympd" "$binary.tmp.$$"
        chmod 755 "$binary.tmp.$$"
        mv -f "$binary.tmp.$$" "$binary"
        mv -f "$temporary_plist" "$plist"
        trap - EXIT HUP INT TERM
        launchctl enable "$service"
        launchctl bootstrap "$domain" "$plist"
        launchctl kickstart -k "$service"
        echo "ympd installed and started at http://$web_bind:$web_port/"
        echo "Status: $0 status"
        echo "Logs: $log_dir"
        ;;
esac
