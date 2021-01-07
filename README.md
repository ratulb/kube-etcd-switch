# kube-etcd-switch

Move back end forth between embedded & external etcd for kubernetes.

Run /cluster.sh and you are ready to go. Everything is menu driven.

All that is needed - a set of machines with SSH access from one machine(where this repository is checked out to) - Set up a kubernetes cluster(or integrate with one if you already have), take a snapshot, jump from embedded etcd to external etcd and back and forth, Save state of the cluster - go back to a previously saved state - all from the comformt of menu selection.

Switch between cluster view <-> snapshot view <-> state view <-> External etcd view. 

Destroy your cluster by running test
