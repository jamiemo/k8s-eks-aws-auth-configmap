# 1. Find cluster based on tags
data "aws_resourcegroupstaggingapi_resources" "cluster" {
  resource_type_filters = ["eks:cluster"]

  tag_filter {
    key    = "Environment"
    values = ["dev"]
  }

  tag_filter {
    key    = "Project"
    values = ["jamiemo"]
  }
}

# 2. Extract cluster name
locals {
  cluster_arn      = data.aws_resourcegroupstaggingapi_resources.cluster.resource_tag_mapping_list[0].resource_arn
  cluster_name     = regex("^arn:aws:eks:.+:\\d+:cluster\\/(.+)$", local.cluster_arn)[0] 
}

# 3. Create EKS data sources with cluster name
data "aws_eks_cluster" "eks" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = local.cluster_name
}

# 4. Create kubernetes provider with EKS data sources
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

# 5. Create IAM role and policy e.g. codebuild
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "service_role" {
  name               = "service-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# 6. Create servicec role permissions
locals {
  new_role_yaml = <<-EOF
    - groups:
      - system:masters
      rolearn: ${aws_iam_role.service_role.arn}
      username: ${aws_iam_role.service_role.name}
    EOF
}

# 7. Get aws-auth config map data source
data "kubernetes_config_map" "aws_auth" {
  metadata {
    name = "aws-auth"
    namespace = "kube-system"
  }
}

# 8. Update aws-auth configmap
resource "kubernetes_config_map_v1_data" "aws_auth" {
  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    # Convert to list, make distinict to remove duplicates, and convert to yaml as mapRoles is a yaml string.
    # replace() remove double quotes on "strings" in yaml output.
    # distinct() only apply the change once, not append every run.
    mapRoles = replace(yamlencode(distinct(concat(yamldecode(data.kubernetes_config_map.aws_auth.data.mapRoles), yamldecode(local.new_role_yaml)))), "\"", "")
  }

  lifecycle {
    ignore_changes = []
  }
}
