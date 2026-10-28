# Just recipes for this flake.
# Usage: `just <recipe>`; `just` lists recipes.

default:
    @just --list

# Build and switch to a host config (default: current hostname).
switch host=`hostname`:
    sudo nixos-rebuild switch --flake ".#{{host}}"

# Dry-build a host config without switching.
build host=`hostname`:
    nixos-rebuild build --flake ".#{{host}}"

# Update all flake inputs.
update:
    nix flake update

# Shared settings for the recipes below. Both are explicit for a reason:
#
# identity -- the host key is the only age identity on this machine and it is
#   root-readable only, which is why every recipe that has to *decrypt* runs
#   under sudo. It never leaves the host.
# editor   -- `sudo` resets the environment, so the caller's $EDITOR never
#   reaches agenix; resolve it here and pass it explicitly. `sudo -E` would
#   reach the same result by trusting whatever the caller exported, which is
#   the worse trade.
identity := "/etc/ssh/ssh_host_ed25519_key"
editor := env("EDITOR", "vi")

# Print the absolute path of the private secrets checkout.
#
# The location is deliberately not hard-coded: it is a sibling of this repo on
# some machines and somewhere else on others. Resolution order is
# NIX_SECRETS_DIR, ../nix-secrets, ~/nix-secrets, and a candidate is rejected if
# its `origin` remote is not nix-secrets -- a lookalike directory must not be
# edited by mistake. The checkout has to be *writable* because agenix rewrites
# ciphertext in place, so the flake input's /nix/store copy is never usable.
[private]
_secrets-dir:
    #!/usr/bin/env bash
    set -euo pipefail

    resolve() {
        local cand=$1 url
        [ -d "$cand/.git" ] || return 1
        url=$(git -C "$cand" remote get-url origin 2>/dev/null || true)
        case "$url" in
            "" | *nix-secrets*) ;;
            *)
                printf 'ignoring %s: origin is %s, not nix-secrets\n' "$cand" "$url" >&2
                return 1
                ;;
        esac
        ( cd "$cand" && pwd )
    }

    if [ -n "${NIX_SECRETS_DIR:-}" ]; then
        candidates=("$NIX_SECRETS_DIR")
    else
        candidates=("../nix-secrets" "$HOME/nix-secrets")
    fi

    for cand in "${candidates[@]}"; do
        if dir=$(resolve "$cand"); then
            printf '%s\n' "$dir"
            exit 0
        fi
    done

    printf 'No writable nix-secrets checkout found (tried: %s).\n' "${candidates[*]}" >&2
    printf 'Set NIX_SECRETS_DIR to a checkout of\n  ssh://git@github.com/devefx/nix-secrets.git\n' >&2
    exit 1

# Print a throwaway agenix rules file for each NAME read from stdin.
#
# agenix 0.15 has no `-r <recipient>` flag, so the recipients have to come from a
# rules file. This recipe builds that file in /tmp instead of keeping one in
# nix-secrets: the recipient is this host's own SSH public key, which is exactly
# what the old `agenix -e <file> -r <pubkey>` line meant -- only the pubkey is
# read from disk instead of being pasted by hand.
#
# Additional recipients (another host, an offline recovery key) are appended with
# NIX_SECRETS_EXTRA_RECIPIENTS, one ssh-ed25519 line each:
#   NIX_SECRETS_EXTRA_RECIPIENTS='ssh-ed25519 AAAA… k@offline' just secrets-rekey
#
# The caller owns the file and deletes it on exit.
[private]
_secrets-rules:
    #!/usr/bin/env bash
    set -euo pipefail
    rules=$(mktemp --suffix=.nix)

    # Names come in on stdin, one per line: just does not hand recipe parameters
    # to a shebang script as $@.
    {
        printf '{\n'
        while IFS= read -r name; do
            [ -n "$name" ] || continue
            printf '  "%s.age".publicKeys = [\n' "$name"
            printf '    "%s"\n' "$(cat {{identity}}.pub)"
            if [ -n "${NIX_SECRETS_EXTRA_RECIPIENTS:-}" ]; then
                while IFS= read -r line; do
                    [ -n "$line" ] || continue
                    printf '    "%s"\n' "$line"
                done <<< "$NIX_SECRETS_EXTRA_RECIPIENTS"
            fi
            printf '  ];\n'
        done
        printf '}\n'
    } > "$rules"

    printf '%s\n' "$rules"

# `identity` is defined above; the .pub half needs no sudo and no private key
# material. agenix hands each recipient to `age -r`, so the entry has to be the
# ssh-ed25519 line itself -- not the age1… conversion `ssh-to-age` prints. Only
# the ssh form produces an ssh-ed25519 stanza that the SSH identity in
# age.identityPaths can open; an age1… X25519 recipient would need a native age
# key file, and the failure only shows up at activation as "no identity matched
# any of the recipients".
#
# Print this host's SSH public key -- the recipient every recipe encrypts to.
host-age:
    @cat {{identity}}.pub

# The file is deleted first, so agenix has nothing to decrypt and only encrypts
# to the recipients -- no sudo, no host key, and the old plaintext is never
# brought back up. `agenix` picks `cp /dev/stdin` as the editor when stdin is not
# a tty, so this is the non-interactive path:
#
#   just secrets-replace my-service-token < plaintext
#
# Use `just secrets-edit` instead when only part of an existing value changes.
#
# Create or fully replace a secret from plaintext piped on stdin.
secrets-replace name:
    #!/usr/bin/env bash
    set -euo pipefail
    rules=$(printf '%s\n' "{{name}}" | just _secrets-rules)
    trap 'rm -f "$rules"' EXIT
    cd "$(just _secrets-dir)"
    file="{{name}}.age"
    rm -f "$file"
    RULES="$rules" agenix -e "$file"
    echo "-> $PWD/$file : commit/push there, then: just secrets-lock"

# Runs as root because the only recipient is the host key ({{identity}},
# mode 0600): agenix must decrypt the current ciphertext before re-encrypting
# the edited plaintext. The result is chowned back so the checkout stays
# editable without sudo. Plaintext sits in a mktemp dir for the duration of
# $EDITOR and agenix's trap removes it.
#
# Edit an existing secret interactively.
secrets-edit name:
    #!/usr/bin/env bash
    set -euo pipefail
    rules=$(printf '%s\n' "{{name}}" | just _secrets-rules)
    trap 'rm -f "$rules"' EXIT
    cd "$(just _secrets-dir)"
    file="{{name}}.age"
    sudo env EDITOR="{{editor}}" RULES="$rules" agenix -i {{identity}} -e "$file"
    sudo chown "$(id -u):$(id -g)" "$file"
    echo "-> $PWD/$file : commit/push there, then: just secrets-lock"

# Run when the recipient set changes (a new host, a retired key): pass the extra
# ones via NIX_SECRETS_EXTRA_RECIPIENTS. Root for the same reason as
# `secrets-edit`: every file must be decrypted first. The rules file is built
# from the *.age files actually present in the checkout, so nothing here needs to
# be kept in sync by hand.
#
# Re-key every secret to this host's key plus NIX_SECRETS_EXTRA_RECIPIENTS.
secrets-rekey:
    #!/usr/bin/env bash
    set -euo pipefail
    dir=$(just _secrets-dir)
    shopt -s nullglob
    names=()
    for f in "$dir"/*.age; do
        names+=("$(basename "${f%.age}")")
    done
    if [ ${#names[@]} -eq 0 ]; then
        printf 'no .age files in %s\n' "$dir" >&2
        exit 1
    fi
    rules=$(printf '%s\n' "${names[@]}" | just _secrets-rules)
    trap 'rm -f "$rules"' EXIT
    cd "$dir"
    sudo env RULES="$rules" agenix -r -i {{identity}}
    sudo chown "$(id -u):$(id -g)" -- *.age

# Move the `mysecrets` flake input to the nix-secrets HEAD.
secrets-lock:
    nix flake update mysecrets


# Format all nix files.
fmt:
    nix fmt

# Run pre-commit checks (nixfmt + typos + prettier) and evaluate every host.
check:
    nix flake check
