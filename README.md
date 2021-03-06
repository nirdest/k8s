# k8s

kubectl api-resources -o wide - Список Kubernetes apiGroups



https://github.com/3sergey/kubernetes-practice/tree/master/6_users_service-accouts_roles_role-bindings
1) Pre-requisit:
## specify user, namespace, role-name
ACCOUNT_NAME=petya
NAMESPACE=roletest
ROLENAME=read-exec-pods-svc-ing

kubectl create ns $NAMESPACE

2) Create k8s config
2.1) create service accout
kubectl create serviceaccount $ACCOUNT_NAME --namespace $NAMESPACE 
2.2)  run commands one by one - all variables are taken from ACCOUNT_NAME and NAMESPACE

TOKEN_NAME=$(kubectl get serviceAccounts $ACCOUNT_NAME --namespace $NAMESPACE  -o jsonpath="{.secrets[0].name}")
TOKEN=$(kubectl describe secrets $TOKEN_NAME --namespace $NAMESPACE | grep 'token:' | rev | cut -d ' ' -f1 | rev)
CERTIFICATE_AUTHORITY_DATA=$(kubectl config view --flatten --minify -o jsonpath="{.clusters[0].cluster.certificate-authority-data}")
SERVER_URL=$(kubectl config view --flatten --minify -o jsonpath="{.clusters[0].cluster.server}")
CLUSTER_NAME=$(kubectl config view --flatten --minify -o jsonpath="{.clusters[0].name}")

2.3) create kube config

cat <<EOF > $CLUSTER_NAME-$ACCOUNT_NAME-kube.conf
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


2.4) Make a test to verify that you create config correctly:

kubectl --kubeconfig=$CLUSTER_NAME-$ACCOUNT_NAME-kube.conf get po -n $NAMESPACE

#You should get error like:
#Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:firstnamespace:test-service-account" cannot list resource "pods" in API group "" in the namespace "firstnamespace"


3) Create role
# Note that in this section we use ACCOUNT_NAME, NAMESPACE and ROLENAME that was specified in p.1:

cat <<EOF > $ROLENAME-role.yaml ; kubectl apply -f $ROLENAME-role.yaml -n $NAMESPACE
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $NAMESPACE
  name: $ROLENAME
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "describe"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
EOF


4) Create RoleBinding and assign role to client
# Note that in this section we use ACCOUNT_NAME, NAMESPACE and ROLENAME that was specified in p.1:

cat <<EOF > $ROLENAME-rolebinding.yaml ; kubectl apply -f $ROLENAME-rolebinding.yaml -n $NAMESPACE
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $ACCOUNT_NAME-$ROLENAME-rolebinding
  namespace: $NAMESPACE
subjects:
- kind: User
  name: system:serviceaccount:$NAMESPACE:$ACCOUNT_NAME # Name is case sensitive
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role #this must be Role or ClusterRole
  name: $ROLENAME # this must match the name of the Role or ClusterRole you wish to bind to
  apiGroup: rbac.authorization.k8s.io
EOF

5) Test
#Note that in this section we use ACCOUNT_NAME, NAMESPACE and ROLENAME that was specified in p.1:

5.1) Test itself:

kubectl --kubeconfig=$CLUSTER_NAME-$ACCOUNT_NAME-kube.conf get po -n $NAMESPACE

6)  items to provide to a developer:
find the commands example that should run developer:
echo "kubectl --kubeconfig=$CLUSTER_NAME-$ACCOUNT_NAME-kube.conf get po -n $NAMESPACE"
echo "kubectl --kubeconfig=$CLUSTER_NAME-$ACCOUNT_NAME-kube.conf get ing -n $NAMESPACE"





###########
########### Cluster role
###########


ACCOUNT_NAME=vasya
ROLENAME=read-exec-pods-svc-ing-global


### create service account
kubectl create serviceaccount $ACCOUNT_NAME

### get variables for further usage
TOKEN_NAME=$(kubectl get serviceAccounts $ACCOUNT_NAME  -o jsonpath="{.secrets[0].name}")
TOKEN=$(kubectl describe secrets $TOKEN_NAME  | grep 'token:' | rev | cut -d ' ' -f1 | rev)
CERTIFICATE_AUTHORITY_DATA=$(kubectl config view --flatten --minify -o jsonpath="{.clusters[0].cluster.certificate-authority-data}")
SERVER_URL=$(kubectl config view --flatten --minify -o jsonpath="{.clusters[0].cluster.server}")
CLUSTER_NAME=$(kubectl config view --flatten --minify -o jsonpath="{.clusters[0].name}")

### create k8s config

cat <<EOF > $CLUSTER_NAME-$ACCOUNT_NAME-kube.conf
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

### create cluster role

cat <<EOF > $ROLENAME-role.yaml ; kubectl apply -f $ROLENAME-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  namespace: $NAMESPACE
  name: $ROLENAME
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "describe"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
EOF

### creat clusterRoleBinding

cat <<EOF > $ROLENAME-rolebinding.yaml ; kubectl apply -f $ROLENAME-rolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $ACCOUNT_NAME-$ROLENAME-rolebinding
subjects:
- kind: User
  name: system:serviceaccount:default:$ACCOUNT_NAME # default it is namaspase
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole #this must be Role or ClusterRole
  name: $ROLENAME # this must match the name of the Role or ClusterRole you wish to bind to
  apiGroup: rbac.authorization.k8s.io
EOF



### test 

kubectl --kubeconfig=$CLUSTER_NAME-$ACCOUNT_NAME-kube.conf get po -A
