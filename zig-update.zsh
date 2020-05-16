#!/usr/bin/env zsh
#: Description : Install or update Zig's pre-built binaries for x86_64-linux target using zsh.
#: Author      : "Aurélien Plazzotta <aurelien.plazzotta@protonmail.com>"
#: Version     : 0.0.1

# The shell shall immediately exit when any command fails.
set -e

# Used ONLY for debugging (i.e. print all executed commands in stdout).
set -x

INSTALL_DIR="$(dirname $0)"
HOST="ziglang.org"
ARCH="$(uname --kernel-name --machine | sed 's/\s/-/')" # Outputs 'Linux-x86_64'
SRV_RESPONSE=$(curl --silent --write-out "%{http_code}\n" --location "${HOST}/" \
    --output "/dev/null")

function download() {
    # Use `jq` to silently fetch last version or fallback to `grep` otherwise
    if whence jq > /dev/null; then
        API=(jq -r '.master.version')
    else
        API=(grep -Po '(?<="version": ")[^"]*')
    fi

    function {
        local JSON='https://ziglang.org/download/index.json'
        curl -fsSL "$JSON" | $@
    } ${API}

    # `:l` modifier converts 'ARCH' value to lowercase letters.
    FILE="${ARCH:l}-${FILE}.tar.xz"
    curl -O "https://ziglang.org/builds/${FILE}"

}

function extract() {
    tar -xJf "${INSTALL_DIR}/${FILE}"
    # Take the longest match before '.tar' substring (i.e. strip off new dir from its extension)
    mv "${FILE%%\.tar*}" 'zig'
    mv 'zig' "${HOME}/.local/bin"
}

if [[ ($SRV_RESPONSE == (200 || 403) ]]; then
    if grep -qF '/bin/zig' "${HOME}/.zshrc"; then # If Zig already installed
        MYVERSION="$(zig version)"
        if ( $MYVERSION == "${FILE%%\.tar*}"); then
            print "Zig is already the newest version (${MYVERSION}).\n \
            There is nothing to upgrade.\n"
            exit 0
        fi

        # Check out if zig is running or runnable in the foreground, whether associated to
        # the terminal or not, before cleaning up the cache and removing the compiler old's version
        # Test against 'build' sub-string to a case loop to include other zig's commands (e.g. fmt, cc, build-exe, etc.)
        if [[ -d "${HOME}/.local/cache/zig" ]] && \
        [[ -z "$(ps -d -u ${USERNAME} -o stat,command | grep '^R+[[:blank:]]\+zig build')" ]]; then
            rm -rf "${HOME}/.local/{cache,bin}/zig" # TODO: make it an archive to stash it instead of removing it to reverse changes if installation fails

            download
            extract

            source "${HOME}/.zshrc"

            # Last check
            if zig version > /dev/null; then
                rm -f "${INSTALL_DIR}/${FILE}"
                STATUS='Zig has been updated successfully.\n' # TODO: add a uninstallation' scenario
                print "${STATUS}Type 'zig --help' to try out available options.\n"
                exit 0
            else
                STATUS='Zig has not been properly updated.\n'
                print "{STATUS}Your downloaded archive has been preserved. Please try another method." >&2
                exit 2
            fi

        else
            printf '%s\\n' "Zig is currently running (or in is run queue). Hence, is it UNSAFE to \
            perform any update for now. Please retry after the current zig process's \
            completion." >&2
            exit 1
        fi

    else
        if [[ ! -d "${HOME}/.local/bin" ]]; then
            mkdir -p "${HOME}/.local/bin"
        fi
        if [[ ! -w "${HOME}/.local/bin" ]]; then
            chmod u+x "${HOME}/.local/bin"
        fi

        download
        extract

        # run-control file do not have access to $HOME, that's why the path is replaced with '~'
        printf '%s\\n' "path+=('~/.local/bin/zig')" >> "${HOME}/.zshrc"
        printf '%s\\n' "typeset -TUx PATH path" >> "${HOME}/.zshrc"
        source "${HOME}/.zshrc"
        chmod u+x "${HOME}/.local/bin/zig/zig"
        STATUS='Zig has been installed successfully.\n'
        print "${STATUS}"
        exit 0
    fi
else
    # TODO: make the logging book a function to be reused for each non-null exit codes.
    DATE="$(date -I'minutes')\n"
    OFFLINE_MSG="The official server is offline or not working correctly."
    printf "${OFFLINE_MSG}\nPlease retry later.\n"
    printf "${USERNAME} at ${DATE}${OFFLINE_MSG}\n" >> "${INSTALL_DIR}/logging_book"
    exit 1
fi

#  TODO:
#  4)Add other available architectures to target a broader audience (e.g. x86_64-dragonfly, freebsd users)
#  6)Replace checking with $HOME/.zshrc file with PATH env variable (more robust in case a zig word
#+ unrelated to the language programming is in the same way found in the run-control file!).
#  7)Make the script system-wide executable by moving it to '/usr/bin' (see IPFS `install.sh`
#+ for further details).
#  8) Revert changes in case of installation's failure by stashing old binary (see ipfs-update
#+ tool for more details).