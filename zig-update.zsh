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

function move_zig() {
    mv 'zig' "${HOME}/.local/bin"
}

if [[ ($SRV_RESPONSE == (200 || 403) ]]; then
    if grep -qF '/bin/zig' "${HOME}/.zshrc"; then
        MYVERSION="$(zig version)"
        if ( MYVERSION == FILE); then
            print "Zig is already the newest version (${MYVERSION}).\n \
            There is nothing to upgrade.\n"
            exit 0
        fi
    else
        # Check out if zig is running or runnable in the foreground, whether associated to
        # the terminal or not, before cleaning up the cache and removing the compiler old's version
        # move 'build' sub-string to a case to test other commands like fmt, cc, build-exe, etc.
        if [[ -d "${HOME}/.local/cache/zig" ]] && \
        [[ -z "$(ps -d -u ${USERNAME} -o stat,command | grep '^R+[[:blank:]]\+zig build')" ]]; then
            rm -rf "${HOME}/.local/{cache,bin}/zig"
            STATUS='updated'
        else
            printf %s\\n "Zig is currently running (or in is run queue). Hence, is it UNSAFE to \
            perform any update for now. Please retry after the current zig process's \
            completion." >&2
                exit 1
        fi

        # Use `jq` to silently fetch last version or fallback to `grep` otherwise
        # if the former is not installed
        if whence jq > /dev/null; then
            API=(jq -r '.master.version')
        else
            API=(grep -Po '(?<="version": ")[^"]*')
        fi

        function {
            local JSON='https://ziglang.org/download/index.json'
            curl -fsSL "$JSON" | $@
        } ${API}

        # `:l` modifier converts 'ARCH' to lowercase letters.
        FILE="${ARCH:l}-${FILE}.tar.xz"
        curl -O "https://ziglang.org/builds/${FILE}"
        tar -xJf "${INSTALL_DIR}/${FILE}"
        # Take the longest match before '.tar' substring (i.e. strip off new dir from its extension)
        mv "${FILE%%\.tar*}" 'zig'
        if [[ ! -d "${HOME}/.local/bin" ]]; then
            mkdir -p "${HOME}/.local/bin"
            move_zig
        fi
        if [[ ! -w "${HOME}/.local/bin" ]]; then
            chmod u+x "${HOME}/.local/bin"
            move_zig
        fi
        chmod u+x "${HOME}/.local/bin/zig/zig"

        # In case of very first Zig's installation
        if ! grep -qF '/bin/zig' "${HOME}/.zshrc"; then # Reversed test already exist, MAY be moved to a clause elif?
            # Replace the line below by superior zsh syntax (i.e. path+=() and typeset)
            printf %s\\n "export PATH=${PATH}:${HOME}/.local/bin/zig" >> "${HOME}/.zshrc"
            STATUS='installed'
        fi

        source "${HOME}/.zshrc"
        rm -f "${INSTALL_DIR}/${FILE}"
        print "Zig has been ${STATUS} successfully.\nType 'zig --help' to try out \
        available options.\n"
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
#  2)Check for various shell to make it more widely usable (e.g. `if .bashrc || .tcshrc`).
#  3)Add standard error outputs redirection for logging purpose.
#  4)Add other available architectures to target a broader audience (e.g. x86_64-freebsd users
#+ in the JSON download-related online file, `setenv` instead of `export` for tcsh, `curl` won't
#+ work on Windows, etc.).
#  6)Replace checking with $HOME/.zshrc file with PATH env variable (more robust in case a zig word
#+ unrelated to the language programming is in the same way found in the run-control file!).
#  7)Make the script system-wide executable by moving it to '/usr/bin' (see IPFS `install.sh`
#+ for further details).
#  8) Revert changes in case of installation's failure by stashing old binary (see ipfs-update
#+ tool for more details).