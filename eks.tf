locals {
  cluster_name = "NiceAC-EKS"
}

data "aws_vpc" "my_vpc" {
  default = module.vpc.vpc_id
}

data "aws_subnet" "private" {
  # Use filters to select the private subnets
  filter {
    name   = "tag:Name"
    values = ["PrivateSubnet*"]  # Replace with your naming convention
  }
}

resource "aws_security_group" "bastion_sg" {
  name_prefix = "source-sg-"
  vpc_id      = data.aws_vpc.my_vpc.id

  # Ingress rule to allow traffic from the specified CIDR block
  ingress {
    description = "Access to bastion host from external ip"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.source_cidr_block]
  }
}

resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "eks-cluster-sg-"
  vpc_id      = data.aws_vpc.my_vpc.id

  # Ingress rule to allow HTTPS access from the source security group to the control plane
  ingress {
    description     = "Access to control plan from bastion host"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
}

resource "aws_security_group" "eks_nodes_sg" {
  name_prefix = "eks-nodes-sg-"
  vpc_id      = data.aws_vpc.my_vpc.id

  # Ingress rule to allow HTTP traffic from the source security group
  ingress {
    description     = "Access to worker nodes from bastion host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
#  version = "18.2.0"

  cluster_name    = local.cluster_name
#  cluster_version = "1.21"

  vpc_id = data.aws_vpc.my_vpc.id
  subnet_ids   = data.aws_subnet.private.id

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # Associate the security groups with the EKS cluster and worker nodes
  security_group_id = [
    aws_security_group.eks_cluster_sg.id,
    aws_security_group.eks_nodes_sg.id,
    aws_security_group.bastion_sg.id
  ]


  cluster_addons = {
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    clusterAutoscaler = {
      most_recent = true
    }
    metricsserver = {
      most_recent = true
    } 
    aws-ebs-csi-driver = {
      most_recent = true
    } 
  }


  eks_managed_node_groups = {
    main = {
      min_size     = 1
      max_size     = 5
      desired_size = 2

      instance_types = ["t2.small"]
      labels = {
        Environment = "Demo"
      }
      tags = {
        ExtraTag = "NiceADemoWorkers"
      }
    }
  }
}

# Define the data sources

data "aws_eks_cluster" "NiceEKS" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "NiceEKS" {
  name = module.eks.cluster_id
}


# Output the Cluster endpoint and certificate

output "endpoint" {
  value = data.aws_eks_cluster.NiceEKS.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = data.aws_eks_cluster.NiceEKS.certificate_authority[0].data
}
