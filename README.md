# kube-etcd-switch

Move back end forth between embedded & external etcd for kubernetes. Start with a kubernetes cluster with embedded etcd - run a simple script - k8s will be sitting on external etcd cluster. Run another script - back on embedded etcd. Take back up & apply backup just by running simple script. Switch between last good states.
