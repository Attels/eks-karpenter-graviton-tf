aws eks update-kubeconfig --name minimal-eks --region us-east-1
infracost breakdown --path .
kubectl delete configmap nginx-html
kubectl delete pod amd64-hello
kubectl apply -f examples/