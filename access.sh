#!/usr/bin/env sh

AWS_REGION=${AWS_REGION:-us-east-1}
AWS_PROFILE=${AWS_PROFILE:-platform}

NAMESPACE_ARANGODB=${NAMESPACE_ARANGODB:-arangodb}
REINSTALL_AWS=${REINSTALL_AWS:-0}

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

INSTALL_DIR=`mktemp -d`
chmod 700 $INSTALL_DIR
info "using install directory '$INSTALL_DIR'"

CURRENT_DIR=`pwd`

echo "============================================================================="
echo "Checking if aws is available"
echo "============================================================================="

INSTALL_AWS=0

install_aws() {
    cd $INSTALL_DIR
    info "using apt install"
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    info "installed aws"
    cd $CURRENT_DIR
}

if command_exists aws; then
    info "found aws command"

    if test "$REINSTALL_AWS" = "1"; then
	info "reinstalling aws"
	INSTALL_AWS=1
    fi
else
    info "missing aws command, trying to install"
    INSTALL_AWS=1
fi

if test "$INSTALL_AWS" = "1"; then
    install_aws
fi

AWS=`which kubectl`

echo

AWS=`which aws`

echo "============================================================================="
echo "Checking access to ECR"
echo "============================================================================="

AWS_REGION=$AWS_REGION \
    AWS_PROFILE=$AWS_PROFILE \
    $AWS ecr list-images --repository-name release/dev/platform-ui/ui --output text || \
    (
	echo
	info "ensure that your ~/.aws/credential contains"
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
AUTH=$(echo -n "AWS:$TOKEN" | base64 -w 0)
info "ECR token generated"

cd $INSTALL_DIR
echo -n "{\"auths\":{\"889010145541.dkr.ecr.us-east-1.amazonaws.com\":{\"auth\":\"$AUTH\"}}}" > token.json

TOKEN64=`base64 -w 0 token.json`

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
kubectl -n $NAMESPACE_ARANGODB apply -f secret.yaml

cd $CURRENT_DIR
rm -rf $INSTALL_DIR

echo

echo "============================================================================="
echo "DONE: secret 'arangodb-ecr-secret' has been created"
echo "============================================================================="

