#!/usr/bin/env sh
set -e

command_exists() {
    if command -v "$1" >/dev/null 2>&1; then
	return 0
    else
	return 1
    fi
}

info() {
    echo "INFO: $*"
}

warn() {
    echo "WARN: $*"
}

fatal() {
    echo "FATAL: $*"
    exit 1
}

echo "============================================================================="
echo "Checking if docker is available"
echo "============================================================================="

if command_exists docker; then
  info "good, docker command is available"
else
  fatal "docker command not found, please install docker first"
fi

echo

echo "============================================================================="
echo "Checking if kind is installed"
echo "============================================================================="

INSTALL_KIND=0
VERSION_KIND=0.27.0
REINSTALL_KIND=${REINSTALL_KIND:-0}
KIND=/usr/local/bin/kind

install_kind() {
    sudo mkdir -p /usr/local/bin
    info "downloading kind version ${VERSION_KIND}" 
    wget -q -O /tmp/kind.$$ \
	 https://github.com/kubernetes-sigs/kind/releases/download/v${VERSION_KIND}/kind-linux-amd64 \
	|| fatal "download failed"
    sudo mv /tmp/kind.$$ /usr/local/bin/kind
    sudo chmod 755 /usr/local/bin/kind
    sudo chown root:root /usr/local/bin/kind
    info "installed /usr/local/bin/kind"
    ls -l /usr/local/bin/kind
    if test `which kind` != ${KIND}; then
      warn "cannot locate kind, ensure that '/usr/local/bin' is in the PATH"
    fi
}

if command_exists kind; then
    info "found kind command"

    if test "$REINSTALL_KIND" = "1"; then
	info "reinstalling kind"
	INSTALL_KIND=1
    fi
else
    info "missing kind command, trying to install"
    INSTALL_KIND=1
fi

if test "$INSTALL_KIND" = "1"; then
    install_kind
fi

echo

echo "============================================================================="
echo "Checking if kubectl is installed"
echo "============================================================================="

INSTALL_KUBECTL=0
REINSTALL_KUBECTL=${REINSTALL_KUBECTL:-0}

install_kubectl() {
    info "using snap install"
    sudo snap install --classic kubectl
    info "installed kubectl"
}

if command_exists kubectl; then
    info "found kubectl command"

    if test "$REINSTALL_KUBECTL" = "1"; then
	info "reinstalling kubectl"
	INSTALL_KUBECTL=1
    fi
else
    info "missing kubectl command, trying to install"
    INSTALL_KUBECTL=1
fi

if test "$INSTALL_KUBECTL" = "1"; then
    install_kubectl
fi

KUBECTL=`which kubectl`

echo

echo "============================================================================="
echo "Checking if helm is installed"
echo "============================================================================="

INSTALL_HELM=0
REINSTALL_HELM=${REINSTALL_HELM:-0}

install_helm() {
    info "using snap install"
    sudo snap install --classic helm
    info "installed helm"
}

if command_exists helm; then
    info "found helm command"

    if test "$REINSTALL_HELM" = "1"; then
	info "reinstalling helm"
	INSTALL_HELM=1
    fi
else
    info "missing helm command, trying to install"
    INSTALL_HELM=1
fi

if test "$INSTALL_HELM" = "1"; then
    install_helm
fi

HELM=`which helm`

echo

echo "============================================================================="
echo "Checking if arangodb_operator_platform is installed"
echo "============================================================================="

INSTALL_AOP=0
VERSION_AOP=1.2.47
REINSTALL_AOP=${REINSTALL_AOP:-0}
AOP=/usr/local/bin/arangodb_operator_platform

install_aop() {
    sudo mkdir -p /usr/local/bin
    info "downloading arangodb_operator_platform version ${VERSION_AOP}"
    wget -q -O /tmp/aop.$$ \
	 https://github.com/arangodb/kube-arangodb/releases/download/${VERSION_AOP}/arangodb_operator_platform_linux_amd64 \
	 || fatal "download failed"
    sudo mv /tmp/aop.$$ /usr/local/bin/arangodb_operator_platform
    sudo chmod 755 /usr/local/bin/arangodb_operator_platform
    sudo chown root:root /usr/local/bin/arangodb_operator_platform
    sudo rm -f /usr/local/bin/aop
    sudo ln -s /usr/local/bin/arangodb_operator_platform /usr/local/bin/aop
    info "installed /usr/local/bin/arangodb_operator_platform"
    ls -l /usr/local/bin/arangodb_operator_platform
    if test `which arangodb_operator_platform` != ${AOP}; then
      warn "cannot locate arangodb_operator_platform, ensure that '/usr/local/bin' is in the PATH"
    fi
}

if command_exists arangodb_operator_platform; then
    info "found arangodb_operator_platform command"

    if test "$REINSTALL_AOP" = "1"; then
	info "reinstalling arangodb_operator_platform"
	INSTALL_AOP=1
    fi
else
    info "missing arangodb_operator_platform command, trying to install"
    INSTALL_AOP=1
fi

if test "$INSTALL_AOP" = "1"; then
    install_aop
fi

echo

echo "============================================================================="
echo "create a new K8S cluster"
echo "============================================================================="

CLUSTER=arangodb
NUKE_CLUSTER=${NUKE_CLUSTER:-0}
REUSE_CLUSTER=${REUSE_CLUSTER:-0}
CREATE_CLUSTER=1

info "checking if a cluster ${CLUSTER} already exists"

if $KIND get clusters | grep -s "^${CLUSTER}$"; then
    info "a cluster '${CLUSTER}' already exists"

    if test "$NUKE_CLUSTER" = "1"; then
	info "nuking this cluster"
	$KIND delete cluster --name ${CLUSTER}
    elif test "$REUSE_CLUSTER" != "1"; then
        fatal "cluster with name '${CLUSTER}' already exists. Use CLUSTER=...
       to use a different namespace. Use NUKE_CLUSTER=1 to nuke and
       reinstall this namespace. Use REUSE_CLUSTER=1 to reuse this cluster,
       you need to ensure that there are no leftovers from previous runs."
    else
	info "reusing cluster '${CLUSTER}', please make sure it is cleaned."
	CREATE_CLUSTER=0
    fi
fi

if test "$CREATE_CLUSTER" = "1"; then
    info "creatign cluster '${CLUSTER}'"
    $KIND create cluster --name ${CLUSTER}
fi

$KUBECTL cluster-info --context kind-${CLUSTER}

echo

echo "============================================================================="
echo "Installing the certificate manager"
echo "============================================================================="

NAMESPACE_CERT=cert-manager
VERSION_CERT=1.17.1

install_cert_manager() {
    info "adding jetstack repository"
    $HELM repo add jetstack https://charts.jetstack.io
    $HELM repo update

    info "deleting old CRD"
    $KUBECTL delete crd --all

    info "installing the cert-manager"
    $HELM install cert-manager jetstack/cert-manager \
	 --namespace ${NAMESPACE_CERT} \
	 --create-namespace \
	 --version v${VERSION_CERT} \
	 --set crds.enabled=true

}

if test `$KUBECTL get pods -n cert-manager | fgrep Running | wc -l` -ge 3; then
    info "cert-manager appears to be already running";
else
    install_cert_manager
fi

$KUBECTL get pods -n ${NAMESPACE_CERT}

echo

echo "============================================================================="
echo "Installing the ARANGODB operator"
echo "============================================================================="

NAMESPACE_ARANGODB=arangodb
VERSION_OPERATOR=1.2.47

info "installing/upgrading operator in version ${VERSION_OPERATOR}"
$HELM upgrade -n ${NAMESPACE_ARANGODB} --create-namespace -i operator \
     https://github.com/arangodb/kube-arangodb/releases/download/${VERSION_OPERATOR}/kube-arangodb-${VERSION_OPERATOR}.tgz \
     --set "webhooks.enabled=true" \
     --set "certificate.enabled=true" \
     --set "operator.args[0]=--deployment.feature.gateway=true"

$KUBECTL get pods -n ${NAMESPACE_ARANGODB}

echo

echo "============================================================================="
echo "Installing a profile with credentials"
echo "============================================================================="

cat > /tmp/profile.$$.yaml <<'EOF'
apiVersion: scheduler.arangodb.com/v1beta1
kind: ArangoProfile
metadata:
  name: deployment-pull
spec:
  selectors:
    label:
      matchLabels: {}
  template:
    pod:
      imagePullSecrets:
        - arangodb-secret
    priority: 129
EOF

info "installing profile /tmp/profile.$$.yaml"
$KUBECTL apply -f /tmp/profile.$$.yaml
rm -f /tmp/profile.$$.yaml

echo

echo "============================================================================="
echo "Installing registry"
echo "============================================================================="

info "installing platform registry"
$AOP -n $NAMESPACE_ARANGODB registry install \
    https://github.com/arangodb/arangodb-platform-config/blob/development/configuration.yml

$AOP -n $NAMESPACE_ARANGODB registry install arangodb-platform-ui

echo

echo "============================================================================="
echo "Creating simple deployment"
echo "============================================================================="

info "creating simple deployment"
cat > /tmp/simple.$$.yaml <<'EOF'
apiVersion: "database.arangodb.com/v1"
kind: "ArangoDeployment"
metadata:
  name: "platform-simple-single"
spec:
  mode: Single
  image: 'arangodb/enterprise:3.12.2'
  gateway:
    enabled: true
    dynamic: true
  gateways:
    count: 1
EOF
info "created /tmp/simple.$$.yaml"

info "installing platform-simple-single"

$KUBECTL apply -n $NAMESPACE_ARANGODB -f /tmp/simple.$$.yaml

echo

echo "============================================================================="
echo "Enable Platform UI"
echo "============================================================================="

info "enabling platform ui"
$AOP -n $NAMESPACE_ARANGODB service enable-service platform-simple-single arangodb-platform-ui

echo

$KUBECTL -n $NAMESPACE_ARANGODB get pods

echo
