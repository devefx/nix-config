# secrets

**English** | [简体中文](./README.zh-CN.md)

The agenix wiring: ciphertext lives in the private repo `devefx/nix-secrets` (flake input
`mysecrets`); this directory declares what gets decrypted and for whom.

## Creating and updating

| Recipe                        | Decrypts the old value | sudo | When                        |
| ----------------------------- | ---------------------- | ---- | --------------------------- |
| `just secrets-replace <name>` | no                     | no   | new secret, or full replace |
| `just secrets-edit <name>`    | yes                    | yes  | edit an existing value      |

```bash
just secrets-replace my-service-token < plaintext
printf '%s' "$TOKEN" | just secrets-replace my-service-token
EDITOR=code just secrets-edit my-service-token
```

Multi-line values work — a whole systemd `EnvironmentFile`, for example:

```bash
just secrets-replace pi-web <<'EOF'
PI_WEB_PASSWORD=correct horse battery staple
PI_WEB_ALLOWED_HOSTS=pi.example.com
EOF
```

systemd parses that file, not a shell: no `export`, no `$VAR` expansion, no line continuation, and
`KEY = value` puts a space in the key. Quote values containing spaces or `#`.

## Using a secret

```bash
cd ../nix-secrets && git add my-service-token.age && git commit -m "Add token" && git push
cd ../nix-config && just secrets-lock   # mysecrets pins a commit, not the worktree
```

Then declare it in [`nixos.nix`](./nixos.nix) and gate it on the host:

```nix
# secrets/nixos.nix
age.secrets.my-service-token = {
  file = "${mysecrets}/my-service-token.age";
  owner = myvars.username;
  mode = "0600";
};

# hosts/faex1/default.nix
modules.secrets.myService.enable = true;
```

Consumers read the decrypted path — `/run/agenix/<name>`, tmpfs, owner-only:

```nix
modules.aiAgents.piWeb.environmentFile = osConfig.age.secrets.pi-web.path;
```

Finally `just switch`.

## What exists

`smb-credentials` and `smb-credentials-wd20t` (SMB mounts), `hf-token` (`HF_TOKEN`), `pi-web`
(`EnvironmentFile` for the Pi Web user service). The only recipient is this host's SSH key —
`just host-age` prints it, and `NIX_SECRETS_EXTRA_RECIPIENTS` adds more for a single run.

## Pitfalls

- An uncommitted `.age` is invisible to the build: `flake = false` reads git, not the worktree.
- Pushing without `just secrets-lock` keeps the old ciphertext in play.
- Never `builtins.readFile` a decrypted path — that copies the plaintext into `/nix/store`.
- `/run/agenix` is tmpfs; activation recreates it.

## Troubleshooting

```bash
journalctl -b | grep -B2 -A5 agenix
AGE=$(nix build --no-link --print-out-paths nixpkgs#age)/bin/age
cd ../nix-secrets && sudo "$AGE" -d -i /etc/ssh/ssh_host_ed25519_key pi-web.age
```
