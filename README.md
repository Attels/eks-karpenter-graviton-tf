# EKS + Karpenter (x86 and Graviton, Spot)

Minimal Terraform to stand up an EKS cluster with Karpenter that can launch both x86_64 and arm64 Spot nodes.

## Deploy
```sh
terraform init
terraform apply
aws eks update-kubeconfig --name minimal-eks --region us-east-1
```

## Run the sample (arm/Graviton)
```sh
kubectl apply -f examples/
kubectl get pods -o wide
kubectl get svc arm64-hello-svc -o wide
```

## Destroy
```sh
terraform destroy
```