# kube-etcd-switch — AGENTS.md

## Structure

- `cluster.sh` — main entrypoint, menu-driven UI
- `utils.sh` — shared library, must be sourced first (`. utils.sh`) in every script
- `setup.conf` — single config file: etcd servers, masters, etcd version, paths
- `widgets/` — sub-menus (system-init, manage-etcd, snapshot select/save)
- `checks/` — status/validation scripts (cluster-state, endpoint-probe, etc.)
- `generated/` — runtime output (certs, systemd configs), gitignored
- `help/` — SSH key setup docs
- `tests/` — **manual** destructive scripts only; no test runner/framework

## Execution model

- **All operations run via SSH** from the host where this repo is checked out
- `remote_cmd`, `remote_script`, `remote_copy` in `utils.sh` wrap `ssh`/`scp`
- **SSH key access** to all nodes is a prerequisite (`help/ssh-*.txt`)
- Scripts use `. script.sh` (source, not subshell) to share variables/functions

## Key commands

| Action | Command |
|---|---|
| Start menu | `./cluster.sh` |
| Check cluster state | `. checks/cluster-state.sh` |
| Generate certs for one node | `. gen-cert.sh <hostname> <ip>` |
| Generate certs for all configured nodes | `. gen-certs.sh` |
| Snapshot save | `. save-snapshot.sh <name> <embedded\|external>` |
| Restore snapshot | `. restore-snapshot.sh <db> <dir> <token> <ip> <initial-cluster>` |
| Admit node to external cluster | `admit_etcd_cluster_node <hostname> <ip> external` |
| Remove node from external cluster | `remove_admitted_node <ip> external` |
| System initialization | `. system-init.sh <master-ip>` |

## Config (`setup.conf`)

- `etcd_servers` — space-separated `hostname:ip` pairs for external etcd nodes
- `masters` — space-separated `hostname:ip` pairs for kube control-plane nodes
- `etcd_version` — currently `3.4.14`
- After editing, call `read_setup` to re-export variables

## Paths

| Path | Purpose |
|---|---|
| `/etc/backup/` | Snapshot `.db` files |
| `$HOME/.kube_vault/` | State archives, paused manifests |
| `$HOME/.kube_vault/migration-archive/` | Saved cluster states (tar.gz) |
| `/etc/kubernetes/pki/etcd/` | CA + node certs |
| `generated/` | Temp certs, systemd configs |

## Certs (cfssl)

- Profiles: `client`, `server`, `peer` (defined in `ca-csr.json`)
- Template: `csr-template.json` — `#etcd-host#` placeholder
- Generated files: `{hostname}-{client,server,peer}.{crt,key}`
- `gen-cert.sh` generates for one node; `gen-certs.sh` for all configured

## Dependencies

- `fping` (auto-installed by `system-init.sh`)
- `cfssl` / `cfssljson` (`install-cfssl.sh`)
- `etcdctl` (`install_etcdctl()` in `utils.sh`)
- `etcd_cmd()` wraps `etcdctl` API v3 with cert paths

## Systemd etcd template

File: `etcd-systemd-config.template` — placeholders `#etcd-host#`, `#etcd-ip#`, `#data-dir#`, `#initial-cluster-token#`, `#initial-cluster#`. Replaced by `sed` in `gen_systemd_config()`.

## Notes

- No build, lint, typecheck, or formatter steps — pure bash
- No automated test suite; run `tests/destructive-script.sh` only on disposable clusters
- `$debug` env var enables verbose output (`export debug=1`)
- `console.sh` drops into interactive bash with `utils.sh` loaded
- `etcdctl` is installed to `/usr/local/bin/etcdctl`
