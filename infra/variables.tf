variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# cluster_name previously used for EKS. Keep variable only if you still manage an EKS cluster.
# If you no longer use EKS, you can remove this variable and any references.
variable "cluster_name" {
  type    = string
  default = ""  # empty by default; set only if you still create/use an EKS cluster via Terraform
}
