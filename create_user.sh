
#!/bin/bash
NAMESPACE=default
ACCOUNT_NAME=$1

kubectl create serviceaccount $ACCOUNT_NAME --namespace $NAMESPACE

TOKEN_NAME=$(kubectl get serviceAccounts $ACCOUNT_NAME --namespace $NAMESPACE  -o jsonpath="{.secrets[0].name}")
TOKEN=$(kubectl describe secrets $TOKEN_NAME --namespace $NAMESPACE | grep 'token:' | rev | cut -d ' ' -f1 | rev)
CERTIFICATE_AUTHORITY_DATA=$(kubectl config view --flatten --minify -o jsonpath="{.clusters[0].cluster.certificate-authority-data}")
SERVER_URL=$(kubectl config view --flatten --minify -o jsonpath="{.clusters[0].cluster.server}")
CLUSTER_NAME=$(kubectl config view --flatten --minify -o jsonpath="{.clusters[0].name}")

cat <<EOF > $ACCOUNT_NAME-kube.conf
apiVersion: v1
kind: Config
users:
- name: $ACCOUNT_NAME
  user:
    token: $TOKEN
clusters:
- cluster:
    certificate-authority-data: $CERTIFICATE_AUTHORITY_DATA
    server: $SERVER_URL
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: $ACCOUNT_NAME
  name: $CLUSTER_NAME-$ACCOUNT_NAME-context
current-context: $CLUSTER_NAME-$ACCOUNT_NAME-context
EOF


cat <<EOF > $ACCOUNT_NAME-ClusterRoleBinding.yaml ; kubectl apply -f $ACCOUNT_NAME-ClusterRoleBinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $ACCOUNT_NAME-clusterrolebinding
subjects:
- kind: User
  name: system:serviceaccount:default:$ACCOUNT_NAME
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
