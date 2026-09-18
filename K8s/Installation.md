### docs:
- https://www.cherryservers.com/blog/install-kubernetes-on-ubuntu

```bash
sudo swapoff -a

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Remove old repository
sudo rm /etc/apt/sources.list.d/kubernetes.list


# Add the repository using an updated method
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.d/kubernetes.conf
sudo sysctl --system

# Update and install
sudo apt update
sudo apt install -y kubelet kubeadm kubectl

# prevent automatic updates (which may upset versioning)
sudo apt-mark hold kubelet kubeadm kubectl

sudo apt-get install -y containerd
```

```bash
sudo kubeadm init --control-plane-endpoint=192.168.10.100 \
                  --apiserver-advertise-address=192.168.10.100 \
                  --pod-network-cidr=192.168.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Watch nodes become ready
kubectl get nodes -w

# Check Calico pods are running
kubectl get pods -n kube-system -l k8s-app=calico-node
```

```bash
# run on worker nodes
sudo kubeadm join 192.168.10.100:6443 --token yvighv.05yn2nywuk7kftr8 \
        --discovery-token-ca-cert-hash sha256:fdab27274b490326730a4c7e0a0a7d486031777d169a2bd5c39e5b3f558e07ad
```