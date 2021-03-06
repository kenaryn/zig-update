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
SRV_RESPONSE=$(curl -s --write-out "%{http_code}\n" -L "${HOST}/" --output "/dev/null")

function get_last_num_version() {
    # Use `jq` to silently fetch last version or fallback to `grep` otherwise
    if whence jq > /dev/null; then
        API=(jq -r '.master.version')
    else
        API=(grep -Po '(?<="version": ")[^"]*')
    fi

    function {
        curl -fsSL "https://ziglang.org/download/index.json" | $@
    } ${API}
}

function download() {
    LAST_NUM_VERSION="$(get_last_num_version)"
    # `:l` modifier converts 'ARCH' value to lowercase letters.
    LAST_FILE_VERSION="zig-${ARCH:l}-${LAST_NUM_VERSION}.tar.xz"
    curl -O "https://ziglang.org/builds/${LAST_FILE_VERSION}"
}

function extract() {
    tar -xJf "${INSTALL_DIR}/${LAST_FILE_VERSION}"
}

function move() {
    # Take the longest match before '.tar' substring (i.e. strip off new dir from its extension)
    mv "${LAST_FILE_VERSION%%\.tar*}" 'zig'
    mv 'zig' "${HOME}/.local/bin"
}

if (( $SRV_RESPONSE == 200 )); then
    # If Zig is already installed
    if grep -qF '/bin/zig' "${HOME}/.zshrc"; then
        MYVERSION="$(zig version)"
        LASTVERSION="$(get_last_num_version)"
        if [[ ${MYVERSION} == "${LASTVERSION}" ]]; then
            print "Zig is already the newest version (${MYVERSION}).\nThere is nothing to upgrade.\n"
            exit 0
        fi

        # Check out if zig is running or runnable in the foreground, whether associated to
        # Test against 'build' sub-string to a case loop to include other zig's commands (e.g. fmt, cc, build-exe, etc.)
        print "There is a new version available (${LASTVERSION})."
        if ! ps -d -u ${USERNAME} -o stat,command | grep -q '^R+[[:blank:]]\+zig build'; then
            # TODO: make it an archive to stash it instead of removing it to reverse changes if installation fails
            rm -rf "${HOME}/.local/cache,bin/zig" && rm -rf "${HOME}/.local/bin/zig"
            download
            extract
            move
            source "${HOME}/.zshrc"

            # Trivial check before accomplishment.
            if zig version > /dev/null; then
                rm -f "${INSTALL_DIR}/${LAST_FILE_VERSION}"
                STATUS='Zig has been updated successfully.\n' # TODO: add a uninstallation' scenario
                print "${STATUS}Type 'zig --help' to try out available options.\n"
                exit 0
            else
                STATUS='Zig has not been properly updated.\n'
                print "{STATUS}Please try another method." >&2
                update_logging_book
                exit 2
            fi

        else
            printf '%s\\n' "Zig is currently running (or in is run queue). Hence, is it UNSAFE to perform any update for now. Please retry after the current zig process's completion." >&2
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
        move

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
    STATUS="The official server is offline or not working correctly."
    update_logging_book
    printf "${MSG}\nPlease retry later.\n"
    exit 1
fi

function update_logging_book() {
    local DATE="$(date -I'minutes')\n"
    printf "${USERNAME} at ${DATE}${STATUS}\n" >> "${INSTALL_DIR}/logging_book"
} ${STATUS}

#  TODO:
#  4)Add other available architectures to target a broader audience (e.g. x86_64-dragonfly, freebsd users)
#  6)Replace checking with $HOME/.zshrc file with PATH env variable (more robust in case a zig word
#+ unrelated to the language programming is in the same way found in the run-control file!).
#  7)Make the script system-wide executable by moving it to '/usr/bin' (see IPFS `install.sh`
#+ for further details).
#  8) Revert changes in case of installation's failure by stashing old binary (see ipfs-update
#+ tool for more details).