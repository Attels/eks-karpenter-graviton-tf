# EKS + Karpenter (x86 and Graviton, Spot)

Minimal Terraform to stand up an EKS cluster with Karpenter that can launch both x86_64 and arm64 Spot nodes.

## Deploy
```bash

export AWS_ACCESS_KEY_ID=***
export AWS_SECRET_ACCESS_KEY=***

# Step 1: Build infrastructure
terraform apply -target=module.infra

# Step 2: Deploy Karpenter Helm chart
aws eks update-kubeconfig --name minimal-eks --region us-east-1
terraform apply -target=module.karpenter

# Step 3: Create Karpenter node pools and classes
terraform apply -target=module.karpenter_resources
```

## Run the sample (arm/Graviton)
```sh
kubectl apply -f examples/
kubectl get pods -o wide
kubectl get svc arm64-hello-svc -o wide
```

## Destroy
```sh
kubectl delete pod arm64-hello
kubectl delete svc arm64-hello-svc
kubectl delete nginx-html
terraform destroy
```