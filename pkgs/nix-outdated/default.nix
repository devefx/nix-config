{ pkgs }:
# A local, read-only web UI over the packages this host declares.
#
# The page answers two questions:
#   - what does `environment.systemPackages` (+ `home.packages`) contain?
#   - for each of those, is the version in the current nixpkgs older than the
#     version in the latest nixpkgs?
#
# Nothing here writes flake.lock, builds a system closure or switches: the
# check resolves the inputs into a throwaway copy with `nix flake update`,
# then evaluates the configuration twice with `nix eval` (once per lock) and
# diffs the package versions. That needs Nix >= 2.34 for
# `--reference-lock-file`, which is what NixOS 26.11 ships.
#
# The HTTP process only serves the cached JSON and runs the check script on
# demand, so it stays small and the expensive part is visible in the terminal
# that started `just update-check`.
let
  indexHtml = pkgs.writeText "nix-outdated-index.html" (builtins.readFile ./nix-outdated.html);

  # Expression handed to `nix eval --apply`. It is deliberately defensive:
  # home.packages can contain derivations without `pname` or without `meta`.
  applyExpr = ''
    pkgs: map (p:
      let
        r = builtins.tryEval (
          let
            meta = p.meta or { };
            homepage = let h = meta.homepage or ""; in
              if builtins.isList h then builtins.concatStringsSep " " h else h;
          in {
            name = p.pname or (builtins.parseDrvName p.name).name;
            version = p.version or "";
            fullName = p.name;
            description = meta.description or "";
            inherit homepage;
            changelog = meta.changelog or "";
            position = meta.position or "";
          }
        );
      in
      if r.success then r.value else {
        failed = true;
        name = "";
        version = "";
        fullName = "";
        description = "";
        homepage = "";
        changelog = "";
        position = "";
      }
    ) pkgs
  '';

  # Turns the old and new lock into the input table: every root input with its
  # old/new revision, date, and a GitHub compare link when both ends are known.
  inputsJq = pkgs.writeText "nix-outdated-inputs.jq" ''
    def d:
      if . == null or . == 0 then "unknown"
      else gmtime | strftime("%Y-%m-%d")
      end;

    $oldLock[0] as $ol
    | $newLock[0] as $nl
    | [ $ol.nodes.root.inputs | to_entries[]
        | select(.value | type == "string")
        | .key as $name
        | .value as $onode
        | ($nl.nodes.root.inputs[$name] // "") as $nnode
        | ($ol.nodes[$onode].locked // {}) as $oldInput
        | ($nl.nodes[$nnode].locked // {}) as $newInput
        | {
            name: $name,
            type: ($oldInput.type // ""),
            oldRev: ($oldInput.rev // ""),
            newRev: ($newInput.rev // ""),
            oldDate: ($oldInput.lastModified | d),
            newDate: ($newInput.lastModified | d),
            status: (
              if ($oldInput.rev // "") == ($newInput.rev // "") then "current" else "updated" end
            ),
            url: (
              if ($oldInput.type // "") == "github"
              then "https://github.com/\($oldInput.owner)/\($oldInput.repo)"
              else ""
              end
            ),
            compare: (
              if ($oldInput.type // "") == "github" and ($oldInput.rev // "") != ($newInput.rev // "")
              then "https://github.com/\($oldInput.owner)/\($oldInput.repo)/compare/\($oldInput.rev)...\($newInput.rev)"
              else ""
              end
            )
          }
      ]
  '';

  # Joins the package lists from the old and new lock. `$inputs` is the output
  # of inputsJq, so the full check and the inputs-only check share one input
  # table.
  joinJq = pkgs.writeText "nix-outdated-join.jq" ''
    $old[0] as $o
    | $new[0] as $n
    | ($o
       | unique_by([.source, .fullName])
       | map(
           . as $p
           | ([$n[] | select(.name == $p.name)] | .[0]) as $np
           | (($p.source == "system" and $systemFailed == "1") or ($p.source == "home" and $homeFailed == "1")) as $failed
           | {
               name: $p.name,
               source: $p.source,
               version: $p.version,
               latest: (if $failed or ($p.failed // false) or ($np.failed // false) or $np == null then null else $np.version end),
               status: (
                 if $failed or ($p.failed // false) or ($np.failed // false) then "unknown"
                 elif $np == null then "removed"
                 elif $np.version == $p.version then "current"
                 else "outdated"
                 end
               ),
               description: $p.description,
               homepage: $p.homepage,
               changelog: $p.changelog,
               position: $p.position
             }
         )) as $pkgs
    | {
        generatedAt: $generatedAt,
        flake: $flake,
        attr: $attr,
        nixosVersion: $nixosVersion,
        nixpkgs: {
          oldRev: $oldRev,
          newRev: $newRev,
          oldDate: $oldDate,
          newDate: $newDate
        },
        counts: {
          total: ($pkgs | length),
          outdated: ($pkgs | map(select(.status == "outdated")) | length),
          removed: ($pkgs | map(select(.status == "removed")) | length),
          unknown: ($pkgs | map(select(.status == "unknown")) | length),
          current: ($pkgs | map(select(.status == "current")) | length)
        },
        warnings: $warnings[0],
        inputs: $inputs[0],
        packages: $pkgs
      }
  '';

  check = pkgs.writeShellApplication {
    name = "nix-outdated-check";
    runtimeInputs = with pkgs; [
      coreutils
      git
      jq
      # `nix` is put on PATH by the wrapper instead of relying on the unit's
      # `path`: NixOS appends `/bin` to every `path` entry, so a literal
      # `/run/current-system/sw/bin` there becomes `.../bin/bin`.
      nix
    ];
    text = ''
      set -euo pipefail

      state="''${STATE_DIRECTORY:-/var/lib/nix-outdated}"
      flake_dir="''${FLAKE_DIR:?FLAKE_DIR is not set}"
      # `~/...` is expanded against $HOME, so a checkout under the user's home
      # needs no absolute path.
      case "$flake_dir" in
        \~/*) flake_dir="$HOME/''${flake_dir#\~/}" ;;
      esac
      flake_attr="''${FLAKE_ATTR:?FLAKE_ATTR is not set}"
      nixpkgs_input="''${NIXPKGS_INPUT:-nixpkgs}"
      skip_inputs="''${SKIP_INPUTS:-}"
      hm_user="''${HM_USER:-}"
      include_home="''${INCLUDE_HOME:-1}"
      # `all` (default) checks inputs and packages; `inputs` only resolves the
      # flake inputs and keeps the existing package list untouched.
      scope="''${SCOPE:-all}"

      out="$state/packages.json"
      work="$state/.work"
      mkdir -p "$work"
      trap 'rm -rf "$work"' EXIT

      log() { printf '%s\n' "$*" >&2; }

      format_date() {
        case "$1" in
          "" | 0) printf 'unknown' ;;
          *[!0-9]*) printf 'unknown' ;;
          *) date -u -d "@$1" '+%Y-%m-%d' ;;
        esac
      }

      apply='${applyExpr}'

      eval_attr() {
        local ref="$1"
        local attr="$2"
        local args=()
        if [ -n "$ref" ]; then
          args=(--reference-lock-file "$ref")
        fi
        nix eval "''${args[@]}" --json \
          "$flake_dir#nixosConfigurations.$flake_attr.config.$attr" \
          --apply "$apply"
      }

      # Resolve every input in a throwaway copy of flake.nix/flake.lock. The
      # real lock is never written; the copy feeds both the input table and the
      # package comparison. Inputs in `skipInputs` (mysecrets is git+ssh and
      # unreadable for an unattended service) stay at their locked revision.
      log "resolving flake inputs in a throwaway copy"
      rm -rf "$work/flake"
      mkdir -p "$work/flake"
      cp "$flake_dir/flake.nix" "$work/flake/flake.nix"
      cp "$flake_dir/flake.lock" "$work/flake/flake.lock"
      # Store copies are read-only; the update needs to rewrite the lock.
      chmod u+w "$work/flake/flake.lock"

      while IFS= read -r input; do
        [ -n "$input" ] || continue
        case " $skip_inputs " in
          *" $input "*)
            log "skip: $input"
            continue
            ;;
        esac
        if nix flake update --flake "$work/flake" "$input" >"$work/update-$input.log" 2>&1; then
          :
        else
          log "warning: $input update failed: $(tail -n 1 "$work/update-$input.log")"
        fi
      done < <(jq -r '.nodes.root.inputs | to_entries[] | select(.value | type == "string") | .key' "$work/flake/flake.lock")

      new_lock="$work/flake/flake.lock"

      old_node="$(jq -r --arg i "$nixpkgs_input" '.nodes.root.inputs[$i]' "$flake_dir/flake.lock")"
      old_rev="$(jq -r --arg n "$old_node" '.nodes[$n].locked.rev // ""' "$flake_dir/flake.lock")"
      old_ts="$(jq -r --arg n "$old_node" '.nodes[$n].locked.lastModified // 0' "$flake_dir/flake.lock")"
      new_node="$(jq -r --arg i "$nixpkgs_input" '.nodes.root.inputs[$i]' "$new_lock")"
      new_rev="$(jq -r --arg n "$new_node" '.nodes[$n].locked.rev // ""' "$new_lock")"
      new_ts="$(jq -r --arg n "$new_node" '.nodes[$n].locked.lastModified // 0' "$new_lock")"

      nixos_version="$(nixos-version --json | jq -r '.nixosVersion')"

      inputs_json="$work/inputs.json"
      jq -n \
        --slurpfile oldLock "$flake_dir/flake.lock" \
        --slurpfile newLock "$new_lock" \
        -f "${inputsJq}" >"$inputs_json"

      if [ "$scope" = "inputs" ]; then
        # Keep the package table from the last full check; only refresh the
        # input table and the nixpkgs revision shown in the header.
        log "inputs-only check: keeping the existing package list"
        prev="$work/prev.json"
        if [ -f "$out" ]; then
          cp "$out" "$prev"
        else
          printf '%s\n' '{"packages":[],"counts":{"total":0,"outdated":0,"removed":0,"unknown":0,"current":0},"warnings":[]}' >"$prev"
        fi

        jq -n \
          --arg generatedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
          --arg flake "$flake_dir" \
          --arg attr "$flake_attr" \
          --arg nixosVersion "$nixos_version" \
          --arg oldRev "$old_rev" \
          --arg newRev "$new_rev" \
          --arg oldDate "$(format_date "$old_ts")" \
          --arg newDate "$(format_date "$new_ts")" \
          --slurpfile prev "$prev" \
          --slurpfile inputs "$inputs_json" \
          '($prev[0] // {}) as $p
           | {
               generatedAt: $generatedAt,
               flake: $flake,
               attr: $attr,
               nixosVersion: $nixosVersion,
               nixpkgs: {
                 oldRev: $oldRev,
                 newRev: $newRev,
                 oldDate: $oldDate,
                 newDate: $newDate
               },
               counts: ($p.counts // {}),
               warnings: ($p.warnings // []),
               inputs: $inputs[0],
               packages: ($p.packages // [])
             }' >"$work/packages.json"
      else
        log "evaluating $flake_attr against the current lock"
        eval_attr "" "environment.systemPackages" >"$work/old-system.json"

        if [ "$include_home" = "1" ] && [ -n "$hm_user" ]; then
          if ! eval_attr "" "home-manager.users.$hm_user.home.packages" >"$work/old-home.json" 2>"$work/old-home.err"; then
            log "warning: home packages unavailable, skipping: $(tail -n 1 "$work/old-home.err")"
            printf '[]\n' >"$work/old-home.json"
          fi
        else
          printf '[]\n' >"$work/old-home.json"
        fi

        printf '[]\n' >"$work/warnings.json"
        system_failed=0
        home_failed=0

        add_warning() {
          jq --arg source "$1" --arg message "$2" '. + [{source: $source, message: $message}]' \
            "$work/warnings.json" >"$work/warnings.tmp"
          mv "$work/warnings.tmp" "$work/warnings.json"
        }

        extract_error() {
          local line
          line="$(grep -i 'error:' "$1" | tail -n 1 || true)"
          if [ -z "$line" ]; then
            line="$(tail -n 1 "$1")"
          fi
          printf '%s' "$line"
        }

        log "evaluating $flake_attr against the updated lock"
        if ! eval_attr "$new_lock" "environment.systemPackages" >"$work/new-system.json" 2>"$work/new-system.err"; then
          system_failed=1
          add_warning "system" "$(extract_error "$work/new-system.err")"
          cp "$work/old-system.json" "$work/new-system.json"
        fi

        if [ "$include_home" = "1" ] && [ -n "$hm_user" ]; then
          if ! eval_attr "$new_lock" "home-manager.users.$hm_user.home.packages" >"$work/new-home.json" 2>"$work/new-home.err"; then
            home_failed=1
            add_warning "home" "$(extract_error "$work/new-home.err")"
            cp "$work/old-home.json" "$work/new-home.json"
          fi
        else
          printf '[]\n' >"$work/new-home.json"
        fi

        jq -s '. as $all | ($all[0] | map(. + {source: "system"})) + ($all[1] | map(. + {source: "home"}))' \
          "$work/old-system.json" "$work/old-home.json" >"$work/old.json"
        jq -s '. as $all | ($all[0] | map(. + {source: "system"})) + ($all[1] | map(. + {source: "home"}))' \
          "$work/new-system.json" "$work/new-home.json" >"$work/new.json"

        # A package whose evaluation failed is filled from the old lock at the
        # same position, so only that package becomes `unknown` instead of the
        # whole home-manager list.
        jq -s '
          .[0] as $o | .[1] as $n
          | [ range(0; $o | length) as $i
              | ($n[$i] // { }) as $q
              | if $q.failed then $o[$i] + { failed: true } else $q end
            ]
        ' "$work/old.json" "$work/new.json" >"$work/new-fixed.json"
        mv "$work/new-fixed.json" "$work/new.json"

        jq -n \
          --arg generatedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
          --arg flake "$flake_dir" \
          --arg attr "$flake_attr" \
          --arg nixosVersion "$nixos_version" \
          --arg oldRev "$old_rev" \
          --arg newRev "$new_rev" \
          --arg oldDate "$(format_date "$old_ts")" \
          --arg newDate "$(format_date "$new_ts")" \
          --arg systemFailed "$system_failed" \
          --arg homeFailed "$home_failed" \
          --slurpfile old "$work/old.json" \
          --slurpfile new "$work/new.json" \
          --slurpfile inputs "$inputs_json" \
          --slurpfile warnings "$work/warnings.json" \
          -f "${joinJq}" >"$work/packages.json"
      fi

      # Mark packages that live under this checkout's pkgs/: those are the ones
      # `nix-update` can bump. nixpkgs' own packages also carry a /pkgs/ path in
      # meta.position, so existence under $flake_dir is the discriminator.
      : >"$work/custom-names.txt"
      jq -r '.packages[] | select(.position != "") | "\(.name)\t\(.position)"' "$work/packages.json" |
        while IFS=$'\t' read -r name pos; do
          rel="''${pos%%:*}"
          rel="''${rel#*/pkgs/}"
          if [ -f "$flake_dir/pkgs/$rel" ]; then
            printf '%s\n' "$name"
          fi
        done >"$work/custom-names.txt"

      jq --rawfile custom "$work/custom-names.txt" '
        ($custom | split("\n") | map(select(. != ""))) as $names
        | .packages |= map(. as $pkg | . + {custom: ($names | index($pkg.name) != null)})
      ' "$work/packages.json" >"$work/packages-marked.json"
      mv "$work/packages-marked.json" "$work/packages.json"

      mv "$work/packages.json" "$out"
      log "wrote $out"
    '';
  };

  server = pkgs.writeShellApplication {
    name = "nix-outdated";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./nix-outdated.py}
    '';
  };

  # `nix run .#nix-outdated` entry point: starts the server, triggers a check and
  # opens the browser. Nothing here is installed into a system, and the command
  # blocks until you stop it (Ctrl+C).
  launcher = pkgs.writeShellApplication {
    name = "nix-outdated";
    runtimeInputs = with pkgs; [
      coreutils
      inetutils
      nix
      nix-update
      xdg-utils
    ];
    text = ''
      set -euo pipefail

      flake_dir="''${FLAKE_DIR:-$PWD}"
      flake_attr="''${FLAKE_ATTR:-$(hostname)}"
      hm_user="''${HM_USER:-$(id -un)}"
      skip_inputs="''${SKIP_INPUTS:-mysecrets}"
      nixpkgs_input="''${NIXPKGS_INPUT:-nixpkgs}"
      include_home="''${INCLUDE_HOME:-1}"
      port="''${NIX_OUTDATED_PORT:-30143}"

      state="''${NIX_OUTDATED_STATE:-/var/lib/nix-outdated}"
      if [ ! -w "$state" ]; then
        state="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-outdated"
      fi
      mkdir -p "$state"

      STATE_DIRECTORY="$state" \
      INDEX_HTML="${indexHtml}" \
      BIND=127.0.0.1 PORT="$port" \
      CHECK_COMMAND="${check}/bin/nix-outdated-check" \
      AUTO_CHECK=1 \
      NIX_UPDATE="${pkgs.nix-update}/bin/nix-update" \
      NIX_BIN="${pkgs.nix}/bin/nix" \
      FLAKE_DIR="$flake_dir" FLAKE_ATTR="$flake_attr" \
      NIXPKGS_INPUT="$nixpkgs_input" SKIP_INPUTS="$skip_inputs" \
      HM_USER="$hm_user" INCLUDE_HOME="$include_home" \
        "${server}/bin/nix-outdated" &
      pid=$!
      trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT INT TERM

      sleep 1
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "http://127.0.0.1:$port" >/dev/null 2>&1 || true
      else
        printf 'open http://127.0.0.1:%s\n' "$port"
      fi
      wait "$pid"
    '';
  };
in
launcher
