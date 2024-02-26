# Talos

I chose Cilium for a CNI because of its eBPF technology. With this cluster's deployment of Cilium, I chose to replace `kube-proxy` and enable `L2 Advertisement` feature.

Please see `nberlee's Talos fork` for a wonderful ASCII Cinema on deploying Talos on RK1 Turing Pi.

## Get Talos

```shell
wget https://github.com/nberlee/talos/releases/download/v1.6.4/metal-turing_rk1-arm64.raw.xz
xz -d metal-turing_rk1-arm64.raw.xz
```

## Flash Turing Pi

My Turning Pi BMC is configured with a static IP and a DNS entry in my router. I started with my 4th node.

```shell
tpi flash --node 4 -i metal-turing_rk1-arm64.raw
sleep 1
tpi power on -n 4; sleep 1; tpi uart get -n 4; sleep 2; tpi uart get -n 4
```

## Template Cilium

This is what I used to template **Cilium**. It is from [Example With Cilium](https://github.com/nberlee/talos/issues/1) and [Deploying Cilium CNI](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/). This will be placed at the end of `patch.yaml` Please see [Deploying Cilium CNI](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/) for those instructions.

> Note: It is recommended to template the cilium manifest using helm and use it as part of Talos machine config.
>
> - [Deploying Cilium CNI](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/)

So I went with that version. :)

```shell
helm template \
    cilium \
    cilium/cilium \
    --version 1.15.1 \
    --namespace kube-system \
    --set ipam.mode=kubernetes \
    --set=kubeProxyReplacement=true \
    --set=securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
    --set=securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
    --set=cgroup.autoMount.enabled=false \
    --set=cgroup.hostRoot=/sys/fs/cgroup \
    --set l2announcements.enabled=true \
    --set kubeProxyReplacement=true \
    --set loadBalancer.acceleration=native \
    --set k8sServiceHost=127.0.0.1  \
    --set k8sServicePort=7445 \
    --set bpf.masquerade=true \
    > cilium.yaml
```

## Setup Talos

Please look at `patch.yaml`. This includes modifications from **nberlee's Talos fork**, **How can I get Virtual / Shared IP running (on TuringPI2 / RK1)?**, and [Deploying Cilium CNI](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/). It turned out I had a very similar error after my cluster came online. I used patch to migrate the **controlPlane: endpoint:** to the VIP and add various aliases for certificate generation to prevent this issue.

I migrated my cluster to static IPs. When I generated my config, it was based on the IP that my node will have after the IP reassignment.

```shell
talosctl gen config trk https://172.16.116.34 --config-patch @patch.yaml --install-disk /dev/mmcblk0
talosctl apply-config --insecure -n $IP_ASSIGNED_BY_DHCP_SERVER -f controlplane.yaml
talosctl config merge ./talosconfig
```

Modify `~/.talos/config` to use correct endpoint and use static IP going forward.

```shell
talosctl get extensions -n 172.16.116.34
talosctl read /proc/cpuinfo -n 172.16.116.34
talosctl read /proc/modules -n 172.16.116.34
talosctl kubeconfig -n 172.16.116.34
# BOOTSTRAP etcd
talosctl bootstrap -n 172.16.116.34
```

These are commands to check to see how things are coming online. I had to modify my `~/.kube/config` even after I ran `talosctl kubeconfig -n 172.16.116.34`. Also, I copied `~/.kube/config` to the root of this repository so it could be loaded with `direnv`.

```shell
tpi uart -n 4 get
kubectl get nodes -w
kubectl get pods -A -w
# If in a tmux session, temporarily enable "export TERM=xterm-256color"
export TERM=xterm-256color
talsoctl dashboard -n 172.16.116.34
```

## Rinse and Repeat

After `rk1-4` comes online, I copied the generated `controlplane.yaml` file to `rk1-4.yaml`, `rk1-3.yaml` and `rk1-2.yaml`. Also I copied `worker.yaml` to `rk1-1.yaml`. Then I made the appropriate IP and hostname changes to them. This was to preserve them just in case I had to regenerate the configuration again.
| Description | IP | File |
|:---|:---:|---:|
| BMC | 172.16.116.30 | n/a |
| rk1-1 (node 1) | 172.16.116.31 | rk1-1.yaml |
| rk1-2 (node 2) | 172.16.116.32 | rk1-2.yaml |
| rk1-3 (node 3) | 172.16.116.33 | rk1-3.yaml |
| rk1-4 (node 4) | 172.16.116.34 | rk1-4.yaml |
| .. vip .. | 172.16.116.35 | n/a |

## References

- [nberlee's Talos fork](https://github.com/nberlee/talos)
- [Deploying Cilium CNI](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/)
  - [Method 4: Helm manifests inline install](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/#method-4-helm-manifests-inline-install)
  - [Example With Cilium](https://github.com/nberlee/talos/issues/1)
- [How can I get Virtual/Shared IP running (on TuringPI2/RK1)?](https://github.com/siderolabs/talos/discussions/8222)
