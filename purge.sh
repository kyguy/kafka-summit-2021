kubectl delete kafka -n myproject --all
kubectl delete deployments -n myproject --all
kubectl delete kafka,deployments,clusterroles,clusterrolebindings,rolebindings,crds,services,pods,serviceaccounts,configmaps -n myproject -l app=strimzi
kubectl delete kafka,deployments,clusterroles,clusterrolebindings,rolebindings,crds,services,pods,serviceaccounts,configmaps -n default -l app=strimzi
