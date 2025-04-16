#!/usr/bin/env sh
set -e

# This must be portal accross different shell version!
# DO NOT make any modern simplifications. They can break
# on MacOS.

AWS_REGION=${AWS_REGION:-us-east-1}
AWS_PROFILE=${AWS_PROFILE:-platform}

NAMESPACE_ARANGODB=${NAMESPACE_ARANGODB:-arangodb}

REINSTALL=${REINSTALL:-0}

CLUSTER=arangodb
NUKE_CLUSTER=${NUKE_CLUSTER:-0}
REUSE_CLUSTER=${REUSE_CLUSTER:-${REINSTALL}}

USE_MINIKUBE=0
REINSTALL_MINIKUBE=${REINSTALL_MINIKUBE:-${REINSTALL}}

VERSION_KIND=0.27.0
REINSTALL_KIND=${REINSTALL_KIND:-${REINSTALL}}

VERSION_OPERATOR=1.2.47

VERSION_AOP=1.2.47
REINSTALL_AOP=${REINSTALL_AOP:-${REINSTALL}}

REINSTALL_KUBECTL=${REINSTALL_KUBECTL:-${REINSTALL}}
REINSTALL_HELM=${REINSTALL_HELM:-${REINSTALL}}

NAMESPACE_CERT=cert-manager
VERSION_CERT=1.17.1

REINSTALL_AWS=${REINSTALL_AWS:-0}

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

INSTALL_DIR=`mktemp -d`
chmod 700 $INSTALL_DIR
info "using install directory '$INSTALL_DIR'"

CURRENT_DIR=`pwd`

echo "============================================================================="
echo "Checking environment"
echo "============================================================================="

IS_DARWIN=0

if test `uname` = "Darwin"; then
    info "running on darwin"
    IS_DARWIN=1
fi

echo

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
echo "Checking if homebrew is available"
echo "============================================================================="

if test $IS_DARWIN -eq 1; then
    if command_exists brew; then
	info "good, brew command is available"
    else
	fatal "brew command not found, please install homebrew first"
    fi

    echo
fi

if test $USE_MINIKUBE -eq 1; then

    echo "============================================================================="
    echo "Checking if minikube is installed"
    echo "============================================================================="

    INSTALL_MINIKUBE=0

    install_minikube_darwin() {
	info "installing minikube"
	brew install minikube
    }

    if command_exists minikube; then
	info "found minikube command"

	if test $REINSTALL_MINIKUBE -eq 1; then
	    info "reinstalling minikube"
	    INSTALL_MINIKUBE=1
	fi
    else
	info "missing minikube command, trying to install"
	INSTALL_MINIKUBE=1
    fi

    if test $INSTALL_MINIKUBE -eq 1; then
	install_minikube_darwin
    fi

    MINIKUBE=`which minikube`

    echo

else

    echo "============================================================================="
    echo "Checking if kind is installed"
    echo "============================================================================="

    INSTALL_KIND=0
    KIND=/usr/local/bin/kind

    install_kind_ubuntu() {
	cd $INSTALL_DIR
	sudo mkdir -p /usr/local/bin
	info "downloading kind version ${VERSION_KIND}" 
	wget -q -O kind.exe --no-check-certificate \
	     https://github.com/kubernetes-sigs/kind/releases/download/v${VERSION_KIND}/kind-linux-amd64 \
	    || fatal "download failed"
	sudo mv kind.exe /usr/local/bin/kind
	sudo chmod 755 /usr/local/bin/kind
	sudo chown root:root /usr/local/bin/kind
	info "installed /usr/local/bin/kind"
	ls -l /usr/local/bin/kind
	if test `which kind` != ${KIND}; then
	    warn "cannot locate kind, ensure that '/usr/local/bin' is in the PATH"
	fi
	cd $CURRENT_DIR
    }

    install_kind_darwin() {
	cd $INSTALL_DIR
	sudo mkdir -p /usr/local/bin
	info "downloading kind version ${VERSION_KIND}" 
	wget -q -O kind.exe --no-check-certificate \
	     https://github.com/kubernetes-sigs/kind/releases/download/v${VERSION_KIND}/kind-darwin-arm64 \
	    || fatal "download failed"
	sudo mv kind.exe /usr/local/bin/kind
	sudo chmod 755 /usr/local/bin/kind
	sudo chown root:wheel /usr/local/bin/kind
	info "installed /usr/local/bin/kind"
	ls -l /usr/local/bin/kind
	if test `which kind` != ${KIND}; then
	    warn "cannot locate kind, ensure that '/usr/local/bin' is in the PATH"
	fi
	cd $CURRENT_DIR
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
	if test $IS_DARWIN -eq 1; then
	    install_kind_darwin
	else
	    install_kind_ubuntu
	fi
    fi

    echo
fi

echo "============================================================================="
echo "Checking if kubectl is installed"
echo "============================================================================="

INSTALL_KUBECTL=0

install_kubectl_ubuntu() {
    info "using snap install"
    sudo snap install --classic kubectl
    info "installed kubectl"
}

install_kubectl_darwin() {
    info "using brew install"
    brew install kubectl
    info "installed kubectl"
}

if command_exists kubectl; then
    info "found kubectl command"

    if test $REINSTALL_KUBECTL -eq 1; then
	info "reinstalling kubectl"
	INSTALL_KUBECTL=1
    fi
else
    info "missing kubectl command, trying to install"
    INSTALL_KUBECTL=1
fi

if test $INSTALL_KUBECTL -eq 1; then
    if test $IS_DARWIN -eq 1; then
	install_kubectl_darwin
    else
	install_kubectl_ubuntu
    fi
fi

KUBECTL=`which kubectl`

echo

echo "============================================================================="
echo "Checking if helm is installed"
echo "============================================================================="

INSTALL_HELM=0

install_helm_ubuntu() {
    info "using snap install"
    sudo snap install --classic helm
    info "installed helm"
}

install_helm_darwin() {
    info "using brew install"
    brew install helm
    info "installed helm"
}

if command_exists helm; then
    info "found helm command"

    if test $REINSTALL_HELM -eq 1; then
	info "reinstalling helm"
	INSTALL_HELM=1
    fi
else
    info "missing helm command, trying to install"
    INSTALL_HELM=1
fi

if test $INSTALL_HELM -eq 1; then
    if test $IS_DARWIN -eq 1; then
	install_helm_darwin
    else
	install_helm_ubuntu
    fi
fi

HELM=`which helm`

echo

echo "============================================================================="
echo "Checking if arangodb_operator_platform is installed"
echo "============================================================================="

INSTALL_AOP=0
AOP=/usr/local/bin/arangodb_operator_platform

install_aop_ubuntu() {
    cd $INSTALL_DIR
    sudo mkdir -p /usr/local/bin
    info "downloading arangodb_operator_platform version ${VERSION_AOP}"
    wget -q -O aop.exe --no-check-certificate \
	 https://github.com/arangodb/kube-arangodb/releases/download/${VERSION_AOP}/arangodb_operator_platform_linux_amd64 \
	 || fatal "download failed"
    sudo mv aop.exe /usr/local/bin/arangodb_operator_platform
    sudo chmod 755 /usr/local/bin/arangodb_operator_platform
    sudo chown root:root /usr/local/bin/arangodb_operator_platform
    sudo rm -f /usr/local/bin/aop
    sudo ln -s /usr/local/bin/arangodb_operator_platform /usr/local/bin/aop
    info "installed /usr/local/bin/arangodb_operator_platform"
    ls -l /usr/local/bin/arangodb_operator_platform
    if test `which arangodb_operator_platform` != ${AOP}; then
      warn "cannot locate arangodb_operator_platform, ensure that '/usr/local/bin' is in the PATH"
    fi
    cd $CURRENT_DIR
}

install_aop_darwin() {
    cd $INSTALL_DIR
    sudo mkdir -p /usr/local/bin
    info "downloading arangodb_operator_platform version ${VERSION_AOP}"
    wget -q -O aop.exe --no-check-certificate \
	 https://github.com/arangodb/kube-arangodb/releases/download/${VERSION_AOP}/arangodb_operator_platform_darwin_arm64 \
	 || fatal "download failed"
    sudo mv aop.exe /usr/local/bin/arangodb_operator_platform
    sudo chmod 755 /usr/local/bin/arangodb_operator_platform
    sudo chown root:wheel /usr/local/bin/arangodb_operator_platform
    sudo rm -f /usr/local/bin/aop
    sudo ln -s /usr/local/bin/arangodb_operator_platform /usr/local/bin/aop
    info "installed /usr/local/bin/arangodb_operator_platform"
    ls -l /usr/local/bin/arangodb_operator_platform
    if test `which arangodb_operator_platform` != ${AOP}; then
      warn "cannot locate arangodb_operator_platform, ensure that '/usr/local/bin' is in the PATH"
    fi
    cd $CURRENT_DIR
}

if command_exists arangodb_operator_platform; then
    info "found arangodb_operator_platform command"

    if test $REINSTALL_AOP -eq 1; then
	info "reinstalling arangodb_operator_platform"
	INSTALL_AOP=1
    fi
else
    info "missing arangodb_operator_platform command, trying to install"
    INSTALL_AOP=1
fi

if test $INSTALL_AOP -eq 1; then
    if test $IS_DARWIN -eq 1; then
	install_aop_darwin
    else
	install_aop_ubuntu
    fi
fi

echo

echo "============================================================================="
echo "Checking if aws is available"
echo "============================================================================="

INSTALL_AWS=0

install_aws_ubuntu() {
    cd $INSTALL_DIR
    info "using wget install"
    wget -O "awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    info "installed aws"
    cd $CURRENT_DIR
}

install_aws_darwin() {
    info "using brew install"
    brew install awscli
    info "installed aws"
}

if command_exists aws; then
    info "found aws command"

    if test $REINSTALL_AWS -eq 1; then
	info "reinstalling aws"
	INSTALL_AWS=1
    fi
else
    info "missing aws command, trying to install"
    INSTALL_AWS=1
fi

if test $INSTALL_AWS -eq 1; then
    if test $IS_DARWIN -eq 1; then
	install_aws_darwin
    else
	install_aws_ubuntu
    fi
fi

AWS=`which aws`

echo

echo "============================================================================="
echo "create a new K8S cluster"
echo "============================================================================="

CREATE_CLUSTER=1

if test $USE_MINIKUBE -eq 1; then
    $MINIKUBE start
else
    info "checking if a cluster ${CLUSTER} already exists"

    if $KIND get clusters | grep -s "^${CLUSTER}$"; then
	info "a cluster '${CLUSTER}' already exists"

	if test $NUKE_CLUSTER -eq 1; then
	    info "nuking this cluster"
	    $KIND delete cluster --name ${CLUSTER}
	elif test $REUSE_CLUSTER -ne 1; then
            fatal "cluster with name '${CLUSTER}' already exists. Use CLUSTER=...
       to use a different namespace. Use NUKE_CLUSTER=1 to nuke and
       reinstall this namespace. Use REUSE_CLUSTER=1 to reuse this cluster,
       you need to ensure that there are no leftovers from previous runs."
	else
	    info "reusing cluster '${CLUSTER}', please make sure it is cleaned."
	    CREATE_CLUSTER=0
	fi
    fi

    if test $CREATE_CLUSTER -eq 1; then
	info "creating cluster '${CLUSTER}'"
	$KIND create cluster --name ${CLUSTER}
    fi
fi

$KUBECTL cluster-info --context kind-${CLUSTER}

echo

echo "============================================================================="
echo "Checking access to ECR"
echo "============================================================================="

AWS_REGION=$AWS_REGION \
    AWS_PROFILE=$AWS_PROFILE \
    $AWS ecr list-images --repository-name release/dev/platform-ui/ui --output text || \
    (
	echo
	info 'ensure that your ~/.aws/credentials contains'
	echo
	echo "[platform]"
	echo "aws_access_key_id     = ..."
	echo "aws_secret_access_key = ..."
	echo
        fatal "cannot access ECR"
     )

echo

echo "============================================================================="
echo "Generating TOKEN"
echo "============================================================================="

info "generating ECR token"
TOKEN=$(aws --profile $AWS_PROFILE ecr get-login-password --region $AWS_REGION)
AUTH=$(echo "AWS:$TOKEN" | tr -d "\n" | base64 | tr -d "\n")
info "ECR token generated"

cd $INSTALL_DIR
echo "{\"auths\":{\"889010145541.dkr.ecr.us-east-1.amazonaws.com\":{\"auth\":\"$AUTH\"}}}" > token.json

TOKEN64=`tr -d "\n" < token.json | base64 | tr -d "\n"`

cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: arangodb-ecr-secret
  namespace: $NAMESPACE_ARANGODB
data:
  .dockerconfigjson: $TOKEN64
type: kubernetes.io/dockerconfigjson
EOF

info "creating secret 'arangodb-ecr-secret'"
kubectl create namespace $NAMESPACE_ARANGODB
kubectl -n $NAMESPACE_ARANGODB apply -f secret.yaml

cd $CURRENT_DIR

echo

echo "============================================================================="
echo "Installing the certificate manager"
echo "============================================================================="

install_cert_manager() {
    info "adding jetstack repository"
    $HELM repo add jetstack https://charts.jetstack.io
    $HELM repo update

    info "deleting old CRD"
    $KUBECTL delete crd --all

    info "installing the cert-manager (might take a few minutes)"
    $HELM install cert-manager jetstack/cert-manager \
	 --namespace ${NAMESPACE_CERT} --create-namespace \
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

info "installing/upgrading operator in version ${VERSION_OPERATOR}"
if test $IS_DARWIN -eq 1; then
    $HELM upgrade -n ${NAMESPACE_ARANGODB} -i operator \
	  https://github.com/arangodb/kube-arangodb/releases/download/${VERSION_OPERATOR}/kube-arangodb-${VERSION_OPERATOR}.tgz \
	  --set "webhooks.enabled=true" \
	  --set "certificate.enabled=true" \
	  --set "operator.args[0]=--deployment.feature.gateway=true" \
	  --set "operator.architectures={arm64}"
else
    $HELM upgrade -n ${NAMESPACE_ARANGODB} -i operator \
	  https://github.com/arangodb/kube-arangodb/releases/download/${VERSION_OPERATOR}/kube-arangodb-${VERSION_OPERATOR}.tgz \
	  --set "webhooks.enabled=true" \
	  --set "certificate.enabled=true" \
	  --set "operator.args[0]=--deployment.feature.gateway=true"
fi

$KUBECTL get pods -n ${NAMESPACE_ARANGODB}

while $KUBECTL -n $NAMESPACE_ARANGODB get pods | fgrep arango-operator | fgrep -q ContainerCreating; do
    echo
    $KUBECTL -n $NAMESPACE_ARANGODB get pods
    sleep 15
done

echo
$KUBECTL -n $NAMESPACE_ARANGODB get pods

echo

echo "============================================================================="
echo "Installing a profile with credentials"
echo "============================================================================="

cd $INSTALL_DIR

cat > profile.yaml <<'EOF'
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
        - arangodb-ecr-secret
    priority: 129
EOF

info "installing profile `pwd`/profile.yaml"
$KUBECTL -n $NAMESPACE_ARANGODB apply -f profile.yaml

cd $CURRENT_PWD

echo

echo "============================================================================="
echo "Installing registry"
echo "============================================================================="

info "installing platform registry"
$AOP -n $NAMESPACE_ARANGODB registry install \
    https://github.com/arangodb/arangodb-platform-config/blob/development/configuration.yml

info "installing platform ui (might take a few minutes)"
$AOP -n $NAMESPACE_ARANGODB registry install arangodb-platform-ui

echo

echo "============================================================================="
echo "Creating simple deployment"
echo "============================================================================="

cd $INSTALL_DIR

info "creating simple deployment"
if test $IS_DARWIN -eq 1; then
    cat > simple.yaml <<'EOF'
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
  architecture:
    - arm64
EOF
else
    cat > simple.yaml <<'EOF'
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
fi
info "created simple.yaml"

info "installing platform-simple-single"

$KUBECTL apply -n $NAMESPACE_ARANGODB -f simple.yaml

cd $CURRENT_DIR

echo

echo "============================================================================="
echo "Enable Platform UI"
echo "============================================================================="

info "enabling platform ui"
$AOP -n $NAMESPACE_ARANGODB service enable-service platform-simple-single arangodb-platform-ui

echo

info "waiting for pods to show up"
while test `$KUBECTL -n $NAMESPACE_ARANGODB get pods | wc -l` -lt 5; do
    echo
    $KUBECTL -n $NAMESPACE_ARANGODB get pods
    sleep 15
done

echo
$KUBECTL -n $NAMESPACE_ARANGODB get pods

if $KUBECTL -n $NAMESPACE_ARANGODB get pods | grep "\(ErrImagePull\|ImagePullBackOff\)"; then
  echo
  info "check 'kubectl -n $NAMESPACE_ARANGODB logs POD'"
  fatal "cannot pull image"
fi

echo
info "waiting for pods to run"

while test `$KUBECTL -n $NAMESPACE_ARANGODB get pods | fgrep Running | wc -l` -lt 4; do
    echo
    $KUBECTL -n $NAMESPACE_ARANGODB get pods
    sleep 15
done

echo
$KUBECTL -n $NAMESPACE_ARANGODB get pods

echo
info "waiting for service to appear"

while ! `$KUBECTL -n $NAMESPACE_ARANGODB get svc | fgrep NodePort | fgrep -v pending | fgrep -q -- -ea`; do
    echo
    $KUBECTL -n $NAMESPACE_ARANGODB get svc
    sleep 15
done

echo
$KUBECTL -n $NAMESPACE_ARANGODB get svc

echo

echo "============================================================================="
echo "Platform started"
echo "============================================================================="

IP=`kubectl get nodes -o wide | fgrep arangodb-control-plane | awk '{print $6}'`
PORT=`kubectl -n $NAMESPACE_ARANGODB get svc | fgrep -- -ea | awk '{print $5}' | awk -F: '{print $2}' | awk -F/ '{print $1}'`

info "In case you can reach the kind node directly, use the URL:"
echo "https://$IP:$PORT/ui/"

echo
info "Use 'root' with no password for login"

echo
info "Otherwise use ssh and port forwarding:"
info "Forwarding via SSH: ssh -N -L 8529:$IP:$PORT HOST"
info "Forwaring URL: https://localhost:8529/ui/"

