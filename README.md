# k8s-eks-aws-auth-configmap

There does not appear to be a readily available and complete example of [identity mapping of IAM roles](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html) for an existing EKS cluster using terraform.

Typically this would be achieved via [eksctl](https://eksctl.io/usage/iam-identity-mappings/):
```bash
eksctl get iamidentitymapping --cluster <clusterName> --region=<region>
```

If using [manage_aws_auth_configmap](https://github.com/terraform-aws-modules/terraform-aws-eks#input_manage_aws_auth_configmap) with the  [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks) module, the aws-auth config map can be managed as per this [example](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest#usage).

This terraform searches for the existing EKS cluster via tags, and then creates a data source for the cluster and the aws-auth config map. Using distinct(concat()) ensures that the config map is only updated once, even when using `terraform apply` multiple times.

Before:
```bash
kubectl get configmap aws-auth -n kube-system -o yaml
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::999999999999:role/jamiemo-dev-NodeInstanceRole-QaTaYdYbA5Hg
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers: |
    []
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
```

Apply the example:
```bash
terraform init
terraform apply
```

After:
```bash
kubectl get configmap aws-auth -n kube-system -o yaml
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::999999999999:role/jamiemo-dev-NodeInstanceRole-QaTaYdYbA5Hg
      username: system:node:{{EC2PrivateDNSName}}
    - groups:
      - system:masters
      rolearn: arn:aws:iam::999999999999:role/service-role
      username: service-role
  mapUsers: |
    []
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
```