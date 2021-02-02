# kube-etcd-switch

Move back end forth between embedded & external etcd for kubernetes.

Run /cluster.sh and you are ready to go. Everything is menu driven.

All that is needed - a set of machines with SSH access from one machine(where this repository is checked out to) - Set up a kubernetes cluster(or integrate with one if you already have), take a snapshot, jump from embedded etcd to external etcd and back and forth, Save state of the cluster - go back to a previously saved state - all from the comfort of menu choices.

Switch between cluster view <-> snapshot view <-> state view <-> External etcd view. 

Destroy your cluster by running tests/destructive-script.sh(It will delete everything - a complete zero out) - But worry not - As long as you a have saved a state or a snapshot - you will be back where you were. 

Save as many states, snapshots - list them, view them, delete them, restore them.

And nodes to external etcd cluster, remove them - setup another etcd cluster - your kubernetes cluster will be safe.

Verified for debian buster,ubuntu-16.04 and 18.04, ubuntu-20.04.
