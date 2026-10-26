modern-ympd
===========

A modernized fork of [ympd](https://github.com/SuperBFG7/ympd), the lightweight
MPD web client written in C. It keeps ympd's simple WebSocket-based playback
controls and adds a responsive dark interface, composer and bitrate display,
automatic random queue filling, and a macOS LaunchAgent installer.

The original ympd project is at [ympd.org](http://www.ympd.org). This fork
retains its GPLv2 license and Git history.

## Dependencies

-   libmpdclient 2: http://www.musicpd.org/libs/libmpdclient/
-   CMake: https://cmake.org/
-   OpenSSL: https://www.openssl.org/

## Unix Build Instructions

1. install dependencies. cmake, libmpdclient (dev), and OpenSSL (dev) are available from all major distributions.
2. create build directory `cd /path/to/src; mkdir build; cd build`
3. create makefile `cmake .. -DCMAKE_INSTALL_PREFIX:PATH=/usr`
4. build `make`
5. install `sudo make install` or just run with `./ympd`

## Run flags

```
Usage: ./ympd [OPTION]...

 -D, --digest <htdigest>       path to htdigest file for authorization
                               (realm ympd) [no authorization]
 -h, --host <host>             connect to mpd at host [localhost]
 -p, --port <port>             connect to mpd at port [6600]
 -w, --webport [ip:]<port>     listen interface/port for webserver [8080]
 -u, --user <username>         drop priviliges to user after socket bind
 -v, --version                 get version
 --help                        this help
```

## SSL Support

To run ympd with SSL support:

-   create a certificate (key and cert in the same file), example:

```
# openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 1000 -nodes
# cat key.pem cert.pem > ssl.pem
```

-   tell ympd to use a webport using SSL and where to find the certificate:

```
# ./ympd -w "ssl://8081:/path/to/ssl.pem"
```

## Automatic playlist fill

In **Settings**, enable **Fill playlist to** and choose a target from 1 to 500.
ympd adds random songs from the MPD library whenever the queue falls below that
number, including when no browser tab is open. It prefers songs that are not
already queued. If the library has too few distinct songs, repeats are used to
reach the target. It never removes songs when the queue is above the target.

The setting is stored in `$XDG_CONFIG_HOME/ympd/settings`, or
`$HOME/.config/ympd/settings` when `XDG_CONFIG_HOME` is unset. The process must
be able to write there. Set `YMPD_SETTINGS_FILE` to use a different path.

## macOS background service

The user-level LaunchAgent installer builds ympd with embedded web assets,
copies the executable to `~/Library/Application Support/ympd/bin`, and starts
it at login. It runs while that user is logged in and does not need `sudo`.
Install the build dependencies with Homebrew if needed:

```sh
brew install cmake libmpdclient openssl pkgconf
```

Stop any manually started ympd instance on port 6090, then run from the source
directory:

```sh
./tools/ympd-macos-service.sh install
./tools/ympd-macos-service.sh status
```

The web interface is available at `http://127.0.0.1:6090/`. To use another web
port, pass it to `install`, for example `install 8080`. The installer connects
to MPD at `127.0.0.1:6600` by default. Set `YMPD_MPD_HOST`, `YMPD_MPD_PORT`, or
`YMPD_WEB_BIND` for other addresses before running `install`. Re-run `install`
after rebuilding or changing these values. The LaunchAgent, logs, and executable
live in the user's Library directory; playlist-fill settings stay in the
configuration location described above.

```sh
./tools/ympd-macos-service.sh uninstall
```

Uninstalling keeps the logs and playlist-fill settings.

## Copyright

2013-2014 <andy@ndyk.de>
