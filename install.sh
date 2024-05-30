#!/bin/sh

# Unset these env vars that will be used locally
unset XIV_HELPTEXT
unset XIV_LOCAL
unset XIV_UNINSTALL
unset XIV_USE_RB
unset XIV_STEAM
unset XIV_STEAMFP
unset XIV_BADOPTION
unset XIV_FORCE
unset XIV_CLEARCACHE
unset XIV_DOWNLOAD
unset XIV_TEST

# Loop through the launch arguments
for i in "$@"; do
    case "$i" in
        --steam)
            XIV_STEAM=1
            ;;
        
        --steamflatpak)
            XIV_STEAMFP=1
            ;;
        
        --local)
            XIV_LOCAL=1
            ;;
        
        --uninstall)
            XIV_UNINSTALL=1
            ;;
        -u)
            XIV_UNINSTALL=1
            ;;
        
        --RB)
            XIV_USE_RB=1
            ;;

        --force)
            XIV_FORCE=1
            ;;

        -f)
            XIV_FORCE=1
            ;;

        --help)
            XIV_HELPTEXT=1
            ;;

        -h)
            XIV_HELPTEXT=1
            ;;

        --cc)
            XIV_CLEARCACHE=1
            ;;

        --download)
            XIV_DOWNLOAD=1
            ;;

        -d)
            XIV_DOWNLOAD=1
            ;;

        --test)
            XIV_TEST=1
            ;;
        
        *)
            XIV_HELPTEXT=1
            XIV_BADOPTION=$i
            ;;
    esac
done

# If --steam and --steamflatpak are not specified, assume local install
if [ -z "$XIV_STEAM" ] && [ -z "$XIV_STEAMFP" ] && [ -z "$XIV_LOCAL" ]; then
    XIV_LOCAL=1
fi

if [ -z "$XDG_DATA_HOME" ]; then
    XDG_DATA_HOME="$HOME/.local/share"
fi

if [ -z "$XDG_CACHE_HOME" ]; then
    XDG_CACHE_HOME="$HOME/.cache"
fi

if [ "$XIV_USE_RB" = "1" ]; then
    repo="rankynbass"
    name="xivlauncher-rb-local"
    title="RB-Patched"
    versioncheck="https://raw.githubusercontent.com/rankynbass/XIVLauncher.Core/RB-patched/version.txt"
else
    repo="goatcorp"
    name="xivlauncher-local"
    title="Official"
    versioncheck="https://raw.githubusercontent.com/goatcorp/xlcore-distrib/main/version.txt"
fi

scriptdir="$(realpath "$(dirname "$0")")"
xldir="$XDG_DATA_HOME/$name"
tempdir="$XDG_CACHE_HOME/XIVLocal-Installer"

VersionToNumber()
{
    if [ -z $1 ]; then
        echo "Error! No version number provided to VersionToNumber()"
        exit 1
    fi
    IFS='.'
    read -r FIRST SECOND THIRD FOURTH <<< $1
    expr ${FIRST:-0} '*' 1000000 + ${SECOND:-0} '*' 10000 + ${THIRD:-0} '*' 100 + ${FOURTH:-0}
}

VersionCheck() {
    mkdir -p "$tempdir"
    if [ "$XIV_DOWNLOAD" = "1" ]; then
        echo "Skipping version check. Downloading..."
        Download
        return
    fi
    echo "Checking for latest version..."
    latest=$(curl -L "$versioncheck")
    echo "Latest version of XIVLauncher.Core $title is $latest"
    echo "Checking cache..."
    if [ -f "$tempdir/version-$repo" ]; then
        current=$(awk 'NR==1 {print; exit}' < "$tempdir/version-$repo")
        echo "Cached version of XIVLauncher.Core $title is $current"
        testcurrent=$( VersionToNumber $current )
        testlatest=$( VersionToNumber $latest )
        if [ $testlatest -gt $testcurrent ]; then
            echo "Latest version $latest > $current Current version. Downloading..."
            current="$latest"
            echo "$current" > "$tempdir/version-$repo"
            Download
        else
            echo "Nothing to download."
        fi
    else
        echo "No version cached. Downloading..."
        current="$latest"
        echo "$current" > "$tempdir/version-$repo"
        Download
    fi
}

Download() {
    echo "Downloading latest XIVLauncher.Core $title..."
    curl -L "https://github.com/$repo/XIVLauncher.Core/releases/latest/download/XIVLauncher.Core.tar.gz" -o "$tempdir/$title.tar.gz"
}

DownloadAria2() {
    if [ -e "$tempdir/aria2-static.tar.gz" ] && [ "$XIV_DOWNLOAD" != "1" ]; then
        echo "Aria2 already cached. Skipping download."
    else
        echo "Downloading static aria2 build..."
        curl -L "https://github.com/rankynbass/aria2-static-build/releases/latest/download/aria2-static.tar.gz" -o "$tempdir/aria2-static.tar.gz"
    fi
}

InstallLocal() {
    if [ -e "$xldir/version" ]; then
        installed=$(awk 'NR==1 {print; exit}' < "$xldir/version")
        echo "Local installed version is XIVLauncher.Core $title $installed"
        testinstalled=$( VersionToNumber $installed )
        if [ $testcurrent -le $testinstalled ] && [ "$XIV_FORCE" != "1" ]; then
            echo "Current installed version is up-to-date. Exiting."
            return 0
        fi
    fi
    echo "Creating $xldir"
    mkdir -p "$xldir"
    echo "Installing to $xldir"
    tar -xf "$tempdir/aria2-static.tar.gz" -C "$xldir"
    tar -xvf "$tempdir/$title.tar.gz" -C "$xldir"
    echo "$current" > "$xldir/version"

    echo "Copying additional files..."
    cp "$scriptdir/resources/xivlauncher.sh" "$xldir/$name"
    sed -i "s|XDG_DATA_HOME/NAME|$XDG_DATA_HOME/$name|" "$xldir/$name"
    mkdir -p "$HOME/.local/bin"
    ln -s "$xldir/$name" "$HOME/.local/bin/$name"

    cp "$scriptdir/resources/openssl_fix.cnf" "$xldir/openssl_fix.cnf"

    cp "$scriptdir/resources/xivlauncher.png" "$xldir/xivlauncher.png"

    cp "$scriptdir/resources/COPYING.GPL2" "$xldir/COPYING.GPL2"

    cp "$scriptdir/resources/COPYING.GPL3" "$xldir/COPYING.GPL3"

    echo "Making desktop file entry"
    mkdir -p "$XDG_DATA_HOME/applications"
    cp "$scriptdir/resources/XIVLauncher.desktop" "$XDG_DATA_HOME/applications/$name.desktop"
    sed -i "s|Name=TITLE|Name=$title|"  "$XDG_DATA_HOME/applications/$name.desktop"
    sed -i "s|Exec=|Exec=$xldir/$name|" "$XDG_DATA_HOME/applications/$name.desktop"
    sed -i "s|Icon=|Icon=$xldir/xivlauncher.png|" "$XDG_DATA_HOME/applications/$name.desktop"

    echo "Trying to update desktop menu..."
    xdg-desktop-menu forceupdate
    
    echo "Installation complete. You may need to update your \$PATH variable to include \$HOME/.local/bin if you want to launch from the terminal with \"xivlauncher-local\"."
}

UninstallLocal() {
    echo "Removing XIVLauncher.Core $title local directory at $xldir"
    rm -rf "$xldir"
    echo "Removing terminal launcher script from $HOME/.local/bin/$name"
    rm "$HOME/.local/bin/$name"
    echo "Removing .desktop file"
    rm "$XDG_DATA_HOME/applications/$name.desktop"
    echo "Trying to update desktop menu..."
    xdg-desktop-menu forceupdate

echo "XIVLauncher.Core $title local install removed."
}

InstallSteamTool() {
    steamdir="$XDG_DATA_HOME/Steam/compatibilitytools.d/xlcore"
    if [ -e "$steamdir/version" ]; then
        # If the version file is incorrectly formatted, just skip the check
        linecount=$(wc -l < "$steamdir/version")
        if [ $linecount -eq 2 ]; then
            installed=$(awk 'NR==1 {print; exit}' < "$steamdir/version")
            release=$(awk 'NR==2 {print; exit}' < "$steamdir/version")
            echo "Flatpak Steam Compatiblity Tool version is $release $installed"
            if [ "$release" != "$title" ] && [ "$XIV_FORCE" != "1" ]; then
                echo "There is already a version of XIVLauncher.Core $release installed. If you want to replace it with XIVLauncher.Core $title, use --force."
                return
            fi
            testinstalled=$( VersionToNumber $installed )
            if [ $testcurrent -le $testinstalled ] && [ "$XIV_FORCE" != "1" ]; then
                echo "Current installed version is up-to-date. Exiting."
                return
            fi
        fi
    fi
    rm -rf "$steamdir/XIVLauncher"
    rm -rf "$steamdir/bin"
    echo "Installing Steam Comptibility Tool to native Steam: $steamdir"
    mkdir -p "$steamdir/XIVLauncher"
    mkdir -p "$steamdir/bin"
    echo "$current" > "$steamdir/version"
    echo "$title" >> "$steamdir/version"
    cp "$scriptdir/resources/"* "$steamdir/XIVLauncher"
    tar -xvf "$tempdir/aria2-static.tar.gz" -C "$steamdir/bin"
    tar -xvf "$tempdir/$title.tar.gz" -C "$steamdir/XIVLauncher"
    mv "$steamdir/XIVLauncher/xlcore" "$steamdir"
    mv "$steamdir/XIVLauncher/toolmanifest.vdf" "$steamdir"
    mv "$steamdir/XIVLauncher/compatibilitytool.vdf" "$steamdir"
    mv "$steamdir/XIVLauncher/openssl_fix.cnf" "$steamdir"
    if [ "$XIV_TEST" = "1" ]; then
        rm "$steamdir/XIVLauncher/update"
        mv "$steamdir/XIVLauncher/update-test" "$steamdir/update"
        sed -i "s|LOCALREPO|\"${scriptdir}\"/*|" "$steamdir/update"
    else
        rm "$steamdir/XIVLauncher/update-test"
        mv "$steamdir/XIVLauncher/update" "$steamdir"
    fi
    sed -i "s|release=RELEASE|release=$title|" "$steamdir/xlcore"
    sed -i "s|updateurl=UPDATEURL|updateurl=$versioncheck|" "$steamdir/xlcore"
    sed -i "s|release=RELEASE|release=$title|" "$steamdir/update"
    sed -i "s|updateurl=UPDATEURL|updateurl=$versioncheck|" "$steamdir/update"
    sed -i "s|flatpak=FLATPAK|flatpak=0|" "$steamdir/update"
    echo "You need to restart steam for changes to take effect."
}

UninstallSteamTool() {
    steamdir="$XDG_DATA_HOME/Steam/compatibilitytools.d/xlcore"
    echo "Uninstalling Steam Compatibility Tool from $steamdir."
    rm -rf "$steamdir"
    echo "You need to restart steam for changes to take effect."
}

InstallSteamFPTool() {
    steamdir="$HOME/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d/xlcore"
    if [ -e "$steamdir/version" ]; then
        # If the version file is incorrectly formatted, just skip the check
        linecount=$(wc -l < "$steamdir/version")
        if [ $linecount -eq 2 ]; then
            installed=$(awk 'NR==1 {print; exit}' < "$steamdir/version")
            release=$(awk 'NR==2 {print; exit}' < "$steamdir/version")
            echo "Flatpak Steam Compatiblity Tool version is $release $installed"
            if [ "$release" != "$title" ] && [ "$XIV_FORCE" != "1" ]; then
                echo "There is already a version of XIVLauncher.Core $release installed. If you want to replace it with XIVLauncher.Core $title, use --force."
                return
            fi
            testinstalled=$( VersionToNumber $installed )
            if [ $testcurrent -le $testinstalled ] && [ "$XIV_FORCE" != "1" ]; then
                echo "Current installed version is up-to-date. Exiting."
                return
            fi
        fi
    fi
    rm -rf "$steamdir"
    echo "Installing Steam Comptibility Tool to flatpak Steam: $steamdir"
    mkdir -p "$steamdir/XIVLauncher"
    mkdir -p "$steamdir/bin"
    echo "$current" > "$steamdir/version"
    echo "$title" >> "$steamdir/version"
    cp "$scriptdir/resources/"* "$steamdir/XIVLauncher"
    tar -xvf "$tempdir/aria2-static.tar.gz" -C "$steamdir/bin"
    tar -xvf "$tempdir/$title.tar.gz" -C "$steamdir/XIVLauncher"
    mv "$steamdir/XIVLauncher/xlcore" "$steamdir"
    mv "$steamdir/XIVLauncher/toolmanifest.vdf" "$steamdir"
    mv "$steamdir/XIVLauncher/compatibilitytool.vdf" "$steamdir"
    mv "$steamdir/XIVLauncher/openssl_fix.cnf" "$steamdir"
    if [ "$XIV_TEST" = "1" ]; then
        rm "$steamdir/XIVLauncher/update"
        mv "$steamdir/XIVLauncher/update-test" "$steamdir/update"
        sed -i "s|LOCALREPO|\"${scriptdir}\"/*|" "$steamdir/update"
    else
        rm "$steamdir/XIVLauncher/update-test"
        mv "$steamdir/XIVLauncher/update" "$steamdir"
    fi
    sed -i "s|release=RELEASE|release=$title|" "$steamdir/xlcore"
    sed -i "s|updateurl=UPDATEURL|updateurl=$versioncheck|" "$steamdir/xlcore"
    sed -i "s|release=RELEASE|release=$title|" "$steamdir/update"
    sed -i "s|updateurl=UPDATEURL|updateurl=$versioncheck|" "$steamdir/update"
    echo "You need to restart steam for changes to take effect."
}

UninstallSteamFPTool() {
    steamdir="$HOME/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d/xlcore"
    echo "Uninstalling Steam Compatibility Tool from $steamdir."
    rm -rf "$steamdir"
    echo "You need to restart steam for changes to take effect."
}

ClearCache() {
    rm -rf $XDG_CACHE_HOME/XIVLocal-Installer
}

HelpText() {
    if [ -n "$XIV_BADOPTION" ]; then
        echo "Unknown option: $XIV_BADOPTION" >&2
        echo " "
    fi
    echo "Local install script for XIVLauncher.Core."
    echo "    --help, -h        Print this help text."
    echo "    --local           Install locally. Default option if nothing else is set."
    echo "    --steam           Install as steam compatibility tool"
    echo "    --steamflatpak    Install as steam compatibility tool for flatpak steam"
    echo "    --uninstall, -u   Uninstall. Works with the above options."
    echo "    --RB              Use XIVLauncher-RB instead of the official XIVLauncher.Core."
    echo "    --force, -f       Force install even if the current version is up-to-date."
    echo "    --download, -d    Download the files even if they are cached."
    echo "    --cc              Clear the cached files on exit."
    echo " "
    if [ -n "$XIV_BADOPTION" ]; then
        exit 1
    fi
}

# For debugging
# echo "XIV_HELPTEXT=$XIV_HELPTEXT"
# echo "XIV_LOCAL=$XIV_LOCAL"
# echo "XIV_STEAM=$XIV_STEAM"
# echo "XIV_STEAMFP=$XIV_STEAMFP"
# echo "XIV_UNINSTALL=$XIV_UNINSTALL"
# echo "XIV_USE_RB=$XIV_USE_RB"
# echo "XIV_FORCE=$XIV_FORCE"

if [ "$XIV_HELPTEXT" = "1" ]; then
    HelpText
    exit
fi

if [ "$XIV_UNINSTALL" != "1" ]; then
    echo ""
    VersionCheck
    echo ""
    DownloadAria2
fi

if [ "$XIV_LOCAL" = "1" ]; then
    echo ""
    if [ "$XIV_UNINSTALL" = "1" ]; then
        UninstallLocal
    else
        InstallLocal
    fi
fi

if [ "$XIV_STEAM" = "1" ]; then
    echo ""
    if [ "$XIV_UNINSTALL" = "1" ]; then
        UninstallSteamTool
    else
        InstallSteamTool
    fi
fi

if [ "$XIV_STEAMFP" = "1" ]; then
    echo ""
    if [ "$XIV_UNINSTALL" = "1" ]; then
        UninstallSteamFPTool
    else
        InstallSteamFPTool
    fi
fi

if [ "$XIV_CLEARCACHE" = "1" ]; then
    ClearCache
fi
