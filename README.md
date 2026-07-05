# kube-etcd-switch

Switch a Kubernetes control plane between **embedded etcd** (kubeadm-style static pod)
and **external etcd** (standalone systemd service on dedicated nodes) — and back
again — without rebuilding the cluster.

> For a step-by-step walkthrough with screenshots — from cluster creation to
> snapshot, disaster simulation, external etcd recovery, node repair, and
> switching back — see the accompanying blog post:
> [*Migrate kubernetes embedded etcd to external etcd — easy back and forth switch*](https://ratulb.github.io/techcottage/2021/07/migrate-kubernetes-embedded-etcd-to-external-etcd-easy-back-and-forth-switch/)

---

## Why external etcd?

A standard kubeadm cluster runs etcd as a **static pod** on the same machines as
`kube-apiserver`. This is simple to bootstrap but has real downsides:

| Problem | Impact |
|---|---|
| **Shared fate** | A control-plane node failure takes down both the API server and its local etcd member. With 3 masters you lose 1/3 of quorum immediately. |
| **Resource contention** | etcd is fsync-sensitive and latency-critical. Master nodes running many API workloads (scheduling, controllers, webhooks) compete for the same CPU, memory, and disk I/O. |
| **Coupled lifecycle** | etcd cannot be upgraded, scaled, or reconfigured independently from the control plane. An etcd update requires touching every master. |
| **No independent data plane** | You cannot add etcd members beyond the number of master nodes, making fault-domain separation harder. |

**External etcd decouples the data plane.** Dedicated etcd nodes:

- Eliminate resource contention between etcd and the API server
- Allow independent scaling, upgrade, and backup of the data layer
- Provide failure isolation — losing a master no longer directly threatens
  etcd quorum
- Make it possible to run etcd in different failure domains (racks, AZs) than
  control-plane nodes

This project exists to make the transition **safe and reversible** — snapshot,
switch, and switch back if needed — without cluster rebuild or manual
certificate gymnastics.

---

## Architecture

```
                 ┌─────────────────────────────┐
                 │     kube-apiserver.yaml     │
                 │  --etcd-servers=...         │
                 └──────────┬──────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
   ┌─────────────────────┐    ┌──────────────────────┐
   │  Embedded etcd      │    │  External etcd       │
   │  (static pod)        │    │  (systemd service)  │
   │  /etc/kubernetes/    │    │  /etc/systemd/system│
   │  manifests/etcd.yaml │    │  etcd.service       │
   └─────────────────────┘    └──────────────────────┘
         ▲                              ▲
         │                              │
         └──────────┬───────────────────┘
                    │
         ┌──────────┴──────────┐
         │   setup.conf        │
         │   etcd_servers=     │
         │   masters=          │
         └─────────────────────┘
```

All operations are driven from **a single admin machine** (where this repo is
cloned). Remote nodes are reached exclusively via SSH. No agent runs on the
targets.

---

## Prerequisites

1. **SSH key access** to every machine involved (masters and etcd nodes).
   See `help/ssh-setup.txt` and `help/copy-ssh-key.txt`.

2. A working Kubernetes cluster (kubeadm), or use `setup-kube-cluster.sh`
   which delegates to [k8s-easy-install](https://github.com/ratulb/k8s-easy-install).

3. One or more dedicated machines for the external etcd cluster —
   these can be the masters themselves (for a 3-node etcd on 3 masters) or
   separate VMs/bare metal.

4. The admin machine must have `bash`, `ssh`, `scp`, `fping`, `cfssl`,
   `cfssljson`, `etcdctl`, and access to `kubectl`. The `system-init.sh` script
   installs missing dependencies automatically.

---

## Getting started

### 1. Clone and configure

```bash
git clone <this-repo> && cd kube-etcd-switch
```

Edit `setup.conf`:

```ini
# External etcd nodes (hostname:ip)
etcd_servers=lb:10.148.15.202 w-1:10.148.15.205

# Kubernetes control-plane nodes (hostname:ip)
masters=m-1:10.148.15.203 m-2:10.148.15.204

etcd_version=3.4.14
```

After editing, `read_setup` re-exports all variables into the shell.

### 2. Initialize the admin machine

```bash
./cluster.sh
# → "System init"
```

`system-init.sh` does the following against the first master:

1. Verifies SSH access to the master
2. Installs `kubectl` pointed at the cluster
3. Queries the Kubernetes API for all control-plane nodes
4. Installs dependencies: `fping`, `cfssl`, `cfssljson`, `etcdctl`, `tree`, `wget`
5. Creates the working directories:
   - `~/.kube_vault/` — cluster state archives, paused manifests
   - `~/.kube_vault/migration-archive/` — saved state tarballs
   - `/etc/backup/` — snapshot `.db` files
   - `generated/` — temporary certs and systemd configs (gitignored)
6. Generates the shared etcd CA (`ca.crt` / `ca.key`)
7. Generates **client, server, and peer certs** for the admin machine
8. Writes `masters=hostname:ip ...` back to `setup.conf`

### 3. Understanding the two modes

#### Embedded etcd (default kubeadm)

- etcd runs as a static pod (`/etc/kubernetes/manifests/etcd.yaml`)
- The API server points at `https://127.0.0.1:2379` and the master's IP
- All control-plane nodes run their own etcd member
- **To pause**: `suspend-embedded-etcd.sh` moves `etcd.yaml` to `~/.kube_vault/`
- **To resume**: `resume-embedded-etcd.sh` moves it back

#### External etcd

- etcd runs as a `systemd` service on dedicated nodes
- etcd certs (client, server, peer) are generated per node
- The API server points at `https://<ext-ip>:2379,...`
- One systemd unit per node, templated from `etcd-systemd-config.template`

### 4. Deploy external etcd

From the **Manage external etcd** menu (or via the "Fresh setup" option):

```bash
./cluster.sh → "Manage external etcd" → "Fresh setup"
```

Or directly:

```bash
. setup-etcd-cluster.sh   # uses etcd_servers from setup.conf
```

`setup-etcd-cluster.sh`:

1. Generates certs for every node in `etcd_servers` (via `gen-certs.sh`)
2. Installs the `etcd` binary on each node (`install-etcd.script`)
3. Copies certs to each node (`copy-certs.sh`)
4. Creates backup and restore directories (`prepare-etcd-dirs.script`)
5. Builds systemd unit files from `etcd-systemd-config.template`
6. Writes the etcd server list to `setup.conf`

---

## The switch: embedded → external

A dedicated menu item is **not** provided — the switch is an explicit sequence
that gives you control:

```
1. Save a snapshot (optional but recommended)
2. Save the current cluster state
3. Deploy external etcd nodes (Fresh setup)
4. Add etcd members (if not done by Fresh setup)
5. Start the external etcd cluster
6. Suspend embedded etcd on the master(s)
7. Sync API server endpoints to point at external etcd
```

Because the system does **not** combine these steps into a single "switch"
action, you can verify each stage and abort if something goes wrong.

---

## Snapshots

### Save

```bash
. save-snapshot.sh <name> <embedded|external>
```

- Connects to the target cluster's etcd endpoint
- Runs `etcdctl snapshot save` to `/etc/backup/<name>-snapshot#<N>.db`
- Embedded snapshots are suffixed `-em`, external ones `-ext`

### Restore to embedded

```bash
. restore-snapshot@masters.sh <snapshot-file>
```

1. Saves the current state (auto-backup)
2. Copies the snapshot to each master
3. Runs `etcdctl snapshot restore` with a fresh cluster token
4. Updates each master's `etcd.yaml` manifest (data-dir, token, initial-cluster)
5. Waits for the embedded cluster to come back

### Restore to external

```bash
. restore-snapshot@ext-etcd-nodes.sh <snapshot-file>
```

1. Saves the current state (auto-backup)
2. Generates fresh systemd configs for every external node
3. Copies the snapshot to each etcd node
4. Runs `etcdctl snapshot restore` with a new token
5. Stops embedded etcd, starts external etcd, syncs endpoints

---

## State management

A **state** is a full-cluster backup: manifests (`etcd.yaml`,
`kube-apiserver.yaml`) and systemd unit files from every node, bundled into a
tar.gz in `~/.kube_vault/migration-archive/`.

### Save state

```bash
. save-state.sh <name>
```

Archives `archive.script` runs on every accessible node (masters + etcd
servers), collecting:
- `/etc/kubernetes/manifests/etcd.yaml` (if present)
- `/etc/kubernetes/manifests/kube-apiserver.yaml`
- `/etc/systemd/system/etcd.service` (if present)

The tarball is named `<cluster_state>#<name>@<timestamp>.tar.gz` so you can
tell at a glance what mode the cluster was in when saved.

### Restore state

```bash
. restore-state.sh <state-name-or-prefix>
```

1. Stops whatever etcd is currently running (embedded or external)
2. Extracts the state archive across all nodes via `unarchive.script`
3. Restarts the appropriate etcd (determined by the `embedded-up`/`external-up`
   prefix in the archive name)

This is the **primary recovery mechanism** — as long as a saved state exists,
you can return the cluster to a known-good configuration.

---

## Menu structure

```
cluster.sh (main)
├── System init           # First-time setup on admin machine
├── Setup kubernetes      # Launch k8s cluster (delegates to k8s-easy-install)
├── Manage external etcd  # widget: manage-etcd.sh
│   ├── Add node
│   ├── Remove node
│   ├── Start/Stop cluster
│   ├── Etcd cluster status
│   └── Fresh setup        # Full external etcd deployment
├── Suspend embedded etcd  # Pause etcd static pod on one master
├── Resume embedded etcd   # Restore etcd static pod on one master
├── Snapshot view          → snapshots.sh
├── State view             → states.sh
├── Cluster state          # Probe current mode
├── System pods state      # Check kube-system pod health
├── Restart runtime        # Restart docker + kubelet on nodes
└── Console                # Interactive shell with utils.sh loaded
```

---

## File reference

| File | Purpose |
|---|---|
| `cluster.sh` | Main menu entrypoint |
| `utils.sh` | Shared library — source before everything |
| `setup.conf` | Single configuration file |
| `system-init.sh` | First-time initialization against a master |
| `gen-cert.sh` | Generate cfssl certs for one node |
| `gen-certs.sh` | Generate cfssl certs for all configured nodes |
| `setup-etcd-cluster.sh` | Full external etcd deployment |
| `save-snapshot.sh` | etcd snapshot save |
| `restore-snapshot.sh` | etcd snapshot restore (single node) |
| `restore-snapshot@masters.sh` | Restore snapshot to embedded cluster |
| `restore-snapshot@ext-etcd-nodes.sh` | Restore snapshot to external cluster |
| `save-state.sh` | Cluster-wide state save |
| `restore-state.sh` | Cluster-wide state restore |
| `suspend-embedded-etcd.sh` | Move etcd.yaml out of manifests/ |
| `resume-embedded-etcd.sh` | Move etcd.yaml back to manifests/ |
| `start-external-etcds.sh` | systemctl start on external etcd nodes |
| `stop-external-etcds.sh` | systemctl stop on external etcd nodes |
| `admit-etcd-cluster-node.sh` | Add a node to running etcd cluster |
| `remove-admitted-node.sh` | Remove a node from a running etcd cluster |
| `synch-etcd-endpoints.sh` | Update kube-apiserver etcd-servers on one master |
| `switch-to-etcd-cluster.sh` | Start external etcd + sync endpoints |
| `etcd-systemd-config.template` | Systemd unit template with `#etcd-host#` etc. |
| `csr-template.json` | CSR template with `#etcd-host#` placeholder |
| `ca-csr.json` | CA signing profiles: client, server, peer |
| `ca-config.json` | CA config with 8760h expiry |
| `install-etcd.script` | Downloads etcd binary to /usr/local/bin |
| `start-etcd.script` | systemctl daemon-reload + enable + restart |
| `stop-etcd.script` | systemctl stop + disable |
| `etcd-restore.script` | Shell-level snapshot restore command |
| `archive.script` | Collects manifests into tar.gz |
| `unarchive.script` | Extracts manifest tar.gz across nodes |
| `copy-certs.sh` | scp certs from generated/ to target node |
| `copy-snapshot.sh` | scp snapshot file to target node |
| `copy-systemd-config.sh` | scp systemd unit to target node |
| `etcd-cluster-status.sh` | Runs etcd-status.script on each etcd node |
| `external-etcd-status.sh` | systemctl status on each etcd node |
| `install-cfssl.sh` | Installs cfssl and cfssljson |
| `setup-kubectl.sh` | Configures kubectl from master's kubeconfig |
| `setup-kube-cluster.sh` | Delegates to k8s-easy-install |
| `restart-runtime.sh` | Restarts docker + kubelet on nodes |
| `show-init-info.sh` | Displays initialization summary |
| `uninstall-node-etcd.sh` | Removes etcd binary, service, and data |
| `etcd-status.script` | etcdctl endpoint health + member list |
| `prepare-etcd-dirs.script` | Creates backup and restore directories |
| `console.sh` | Interactive bash with utils.sh loaded |

---

## SSH and remote execution

All remote operations use three wrappers from `utils.sh`:

| Function | What it does |
|---|---|
| `remote_cmd <host> <cmd>` | `ssh -q -o StrictHostKeyChecking=no <host> <cmd>` |
| `remote_script <host> <file>` | `ssh -q <host> < <file>` (stdin redirect) |
| `remote_copy <from> <to>` | `scp -q -o StrictHostKeyChecking=no <from> <to>` |

Connection timeout is 3 seconds. Host key checking is disabled.
`sudo -u $usr` is prepended to run as the invoking user.

Debug tip: `export debug=1` before running any script enables verbose output
showing every SSH command, file transfer, and state lookup.

---

## Certificates

The project uses **cfssl** to generate a three-tier etcd certificate set.

### Profiles (defined in `ca-csr.json`)

| Profile | SANs | Used by |
|---|---|---|
| `client` | hostname only | etcdctl, API server → etcd |
| `server` | hostname, IP, 127.0.0.1, localhost | etcd's serving TLS |
| `peer` | hostname, IP, 127.0.0.1, localhost | etcd peer-to-peer TLS |

### Generated files

All output lands in `generated/`:

```
{hostname}-client.crt / .key
{hostname}-server.crt / .key
{hostname}-peer.crt   / .key
```

cfssl outputs `.pem` files; the scripts rename them to `.crt` / `.key`.

The CA files live at `/etc/kubernetes/pki/etcd/ca.{crt,key}` and are copied
to every node that needs them.

### One node vs. all nodes

```bash
. gen-cert.sh <hostname> <ip>      # single node
. gen-certs.sh                     # all nodes in etcd_servers (or $@)
```

The single-node version (`gen-cert.sh`) does **not** pass hostname/IP as SANs
to the client profile (only peer and server get SANs). The bulk version
(`gen-certs.sh`) passes hostname/IP SANs to **all** three profiles.
This is a known inconsistency — both work because etcd client connections
typically do not enforce SAN matching.

---

## Configuration reference

### `setup.conf`

```
etcd_servers=host:ip host:ip ...    # External etcd nodes
masters=host:ip host:ip ...         # Control-plane nodes
etcd_version=3.4.14                 # etcd binary version
etcd_ca=/etc/kubernetes/pki/etcd/ca.crt
etcd_key=/etc/kubernetes/pki/etcd/ca.key
default_backup_loc=/etc/backup      # Snapshot storage
default_restore_path=/var/lib/etcd-restore
sleep_time=3                        # Wait interval between operations
kube_install_git_repo=https://github.com/ratulb/k8s-easy-install.git
```

`read_setup` parses this file and exports:
- `$etcd_servers`, `$etcd_ips`, `$etcd_names`
- `$masters`, `$master_ips`, `$master_names`, `$master_address`
- `$gendir` → `$(pwd)/generated`
- `$kube_vault` → `$HOME/.kube_vault`

### Template placeholders

File `etcd-systemd-config.template` uses `sed`-replaced placeholders:

| Placeholder | Replaced with |
|---|---|
| `#etcd-host#` | Node hostname |
| `#etcd-ip#` | Node IP address |
| `#data-dir#` | Snapshot restore path |
| `#initial-cluster-token#` | Token or `state=existing` |
| `#initial-cluster#` | `host=https://ip:2380,...` |

---

## Debugging

### Enable verbose output

```bash
export debug=1
```

Every script checks `$debug` and prints SSH commands, endpoint lookups,
cert paths, and intermediate state via the `debug()` function.

### Key diagnostics

```bash
. checks/cluster-state.sh                   # What mode is the cluster in?
. checks/endpoint-liveness-cluster.sh       # Are etcd endpoints reachable?
. checks/system-pod-state.sh                # Are kube-system pods healthy?
. checks/ssh-access.sh                      # Can we SSH to all nodes?
. checks/endpoint-probe.sh                  # Probe etcd via API server URL
```

`cluster-state.sh` sets `$cluster_state` to one of:

| Value | Meaning |
|---|---|
| `embedded-up` | Cluster running, API server pointing at 127.0.0.1:2379 |
| `external-up` | Cluster running, API server pointing at external etcd |
| `emdown` | Cluster down but etcd.yaml present |
| `ukdown` | Cluster down and no etcd.yaml |

### Common failure modes

| Symptom | Likely cause |
|---|---|
| "Can not access address" | SSH key not deployed; run `help/copy-ssh-key.txt` steps |
| "Empty end point list" | `etcd_servers` in `setup.conf` is empty or nodes unreachable |
| "Has the system been initialized?" | Missing CA at `/etc/kubernetes/pki/etcd/ca.crt`; run System init |
| "Certificate issue" on snapshot | Missing client cert for the target cluster's endpoint |
| etcd service won't start | Systemd config has stale `#placeholder#`; check `generated/*.service` |
| Cluster stuck on "not running" after switch | API server cannot reach the new etcd endpoints; check firewall / DNS |
|---

## Operational notes

- **There is no single "switch" button.** The project deliberately exposes
  individual steps (deploy certs, start etcd, suspend embedded, sync
  endpoints) so you can verify at every stage.

- **Always take a snapshot before a switch or restore.** The scripts do
  auto-save state during restore operations, but a manual snapshot gives you
  the lightest rollback path.

- **State archives are your safety net.** Save state before any significant
  operation. Restoring a state is the most comprehensive recovery path.

- **The `generated/` directory is ephemeral.** Everything in it can be
  regenerated. It is in `.gitignore`. Certificates are copied to nodes and
  persist there.

- **etcdctl is installed to `/usr/local/bin/etcdctl`** on every node that runs
  etcd. The `etcd_cmd()` wrapper function (`utils.sh:709`) always passes
  `ETCDCTL_API=3` and the correct cert paths.

- **System init must run before any other operation.** It creates the CA
  and installs `kubectl` — everything else depends on both.

- **External etcd must be started before syncing endpoints.** The API server
  probes its `--etcd-servers` on startup; if external etcd is not ready, the
  API server will fail to come back.

- **Supported OS**: Debian Buster, Ubuntu 16.04/18.04/20.04.

---

## Recovery procedures

### Recovery from a bad switch

```bash
. stop-external-etcds.sh                 # Stop external etcd if running
. resume-embedded-etcd.sh <master-ip>    # Restore etcd static pod
```

Then use `states.sh` → "Restore last good embedded etcd state" if you saved
one.

### Full cluster recovery from saved state

```bash
. checks/cluster-state.sh                # Determine current state
. restore-state.sh <saved-state-name>    # Full automated recovery
```

The state archive encodes the mode (`embedded-up#...` or `external-up#...`)
and `restore-state.sh` automatically handles stopping the other mode and
starting the correct one.

### Destroy and rebuild (test clusters only)

```bash
# CAUTION: deletes ALL kube resources
source tests/destructive-script.sh
```

This script deletes all deployments, pods, daemonsets, configmaps, secrets,
roles, rolebindings, clusterroles, and clusterrolebindings across all
namespaces. Use only on disposable clusters.
