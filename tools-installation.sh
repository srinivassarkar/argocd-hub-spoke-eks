#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

cat <<'EOF'

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     Installing Kubernetes & AWS CLI                      ║
║     ───────────────────────────────────────              ║
║                                                          ║
║     ✔  aws        → AWS CLI v2 (latest)                  ║
║     ✔  kubectl    → Official Kubernetes CLI (v1.31.x)    ║
║     ✔  eksctl     → Official Amazon EKS CLI (latest)     ║
║     ✔  argocd     → ArgoCD CLI (latest)                  ║
║                                                          ║
║     Works on: bare Ubuntu • Docker • CI/CD • EC2         ║
║     Zero sudo needed inside containers                   ║
╚══════════════════════════════════════════════════════════╝

EOF

echo "Updating system & installing prerequisites..."

# Install minimum required packages first (curl, ca-certificates, unzip, etc.)
apt-get update -qq >/dev/null
apt-get install -y -qq apt-utils >/dev/null 2>&1
apt-get install -y -qq curl ca-certificates unzip gnupg lsb-release >/dev/null

# Function to quietly install if missing
install_if_missing() {
  local name=$1
  local cmd=$2
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Installing $name..."
    eval "$3"
  else
    echo "$name already installed"
  fi
}

# 1. AWS CLI v2
install_if_missing "AWS CLI v2" aws '
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
  unzip -q awscliv2.zip
  ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update >/dev/null
  rm -rf aws awscliv2.zip
'

# 2. kubectl 
install_if_missing "kubectl" kubectl '
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key |
    gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" |
    tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
  apt-get update -qq >/dev/null
  apt-get install -y -qq kubectl >/dev/null
'

# 3. eksctl 
install_if_missing "eksctl" eksctl '
  curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" |
    tar -xzf - -C /tmp
  mv /tmp/eksctl /usr/local/bin/eksctl
'

# 4. ArgoCD CLI 
install_if_missing "argocd" argocd '
  curl -sL "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64" -o /usr/local/bin/argocd
  chmod +x /usr/local/bin/argocd
'

# Final output
echo "All tools installed successfully!"
echo "Versions:"
aws --version      | head -n1
eksctl version     | head -n1 || true
kubectl version --client --output=yaml | grep -E "gitVersion|gitCommit" || kubectl version --client
argocd version --client 2>/dev/null || echo "argocd: installed (no version output in minimal env)"