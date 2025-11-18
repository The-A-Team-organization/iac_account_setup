
terraform {
  required_version = ">= 1.5.0"
  backend "s3" {}
}


provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn     = var.role_arn
    session_name = "jenkins-terraform"
  }
}

resource "tls_private_key" "sskeygen-execution" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins-key-pair" {
  depends_on = [tls_private_key.sskeygen-execution]
  key_name   = "jenkins-public"
  public_key = tls_private_key.sskeygen-execution.public_key_openssh
}

module "vpc" {
  source               = "./vpc"
  available_zones_list = var.available_zones_list
}


module "sg" {
  source      = "./security_group"
  main_vpc_id = module.vpc.vpc_id
}

module "iam_ssm" {
  source = "./iam_ssm"
  count  = var.enable_iam_ssm ? 1 : 0
}

module "consul_server" {
  source            = "./consul_server"
  ami_id            = var.ami_id
  main_vpc_id       = module.vpc.vpc_id
  sg_id             = module.sg.sg_id
  aws_region        = var.aws_region
  private_subnet_id = module.vpc.private_consul_subnet_id
  count             = var.enable_consul ? 1 : 0
}


module "jenkins" {
  source            = "git::https://github.com/The-A-Team-organization/iac_core.git//modules/jenkins?ref=TAT-86-Create-Stage-Infrastructure-Terraform-Jenkins-ECR-SonarQube-IAM-Cross-Account-Policies"
  region            = var.aws_region
  vpc_id            = module.vpc.vpc_id
  igw_id            = module.vpc.internet_gateway_id
  env               = "stage"
  ami               = var.jenkins_ami_id
  instance_type     = "t3.medium"
  availability_zone = "eu-central-1a"
  subnet_cidr       = "10.0.1.0/24"
  count             = var.enable_jenkins ? 1 : 0
}


# module "eks" {
#   source = "git::https://github.com/The-A-Team-organization/illuminati_eks.git?ref=main"
#
#   cluster_availability_zone_1 = var.cluster_availability_zone_1
#   cluster_availability_zone_2 = var.cluster_availability_zone_2
#   private_subnet_cidr_block_1 = var.private_subnet_cidr_block_1
#   private_subnet_cidr_block_2 = var.private_subnet_cidr_block_2
#   public_subnet_cidr_block_1  = var.public_subnet_cidr_block_1
#   public_subnet_cidr_block_2  = var.public_subnet_cidr_block_2
#
#   min_size     = var.min_size
#   max_size     = var.max_size
#   desired_size = var.desired_size
#
#   eks_cluster_name        = var.eks_cluster_name
#   environment_name        = var.environment_name
#   eks_cluster_k8s_version = var.eks_cluster_k8s_version
#
#   node_instance_types = var.node_instance_types
#
#   vpc_id                = var.vpc_id
#   public_route_table_id = var.public_route_table_id
#   region                = var.aws_region
# }


module "ecr" {
  source = "git::https://github.com/The-A-Team-organization/iac_core.git//modules/ecr?ref=main"
  env = "stage"
  repositories = [
    "eks_infra",
    "front",
    "back",
    "go1",
    "go2"
  ]
}


module "lb" {
  source               = "git::https://github.com/The-A-Team-organization/iac_birdwatching.git//modules/lb?ref=main"
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.internet_gateway_id
  availability_zone    = var.availability_zone
  common_tags          = { env = "stage" }
  env                  = var.env
  ami                  = var.birdwatching_ami_id
  instance_type        = "t3.micro"
  key_name             = aws_key_pair.jenkins-key-pair.key_name
  dns_name             = var.birdwatching_dns_name
  public_subnet_cidr   = "10.0.3.0/24"
  iam_instance_profile = module.iam_ssm[0].ssm_instance_profile_name
  count                = var.enable_lb ? 1 : 0
}

module "web" {
  source                  = "git::https://github.com/The-A-Team-organization/iac_birdwatching.git//modules/web?ref=main"
  vpc_id                  = module.vpc.vpc_id
  availability_zone       = var.availability_zone
  common_tags             = { env = "stage" }
  env                     = var.env
  ami                     = var.birdwatching_ami_id
  instance_type           = "t3.micro"
  key_name                = aws_key_pair.jenkins-key-pair.key_name
  private_web_subnet_cidr = "10.0.4.0/24"
  nat_gateway_id          = module.lb[0].nat_gateway_id
  allowed_cidrs = [
    module.lb[0].security_group_id,
    module.sg.sg_id
  ]
  count = var.enable_web ? 1 : 0
}

module "db" {
  source            = "git::https://github.com/The-A-Team-organization/iac_birdwatching.git//modules/db?ref=main"
  vpc_id            = module.vpc.vpc_id
  availability_zone = var.availability_zone
  common_tags       = { env = "stage" }
  env               = var.env
  ami               = var.birdwatching_ami_id
  instance_type     = "t3.micro"
  key_pair          = aws_key_pair.jenkins-key-pair.key_name
  db_subnet_cidr    = "10.0.5.0/24"
  nat_gateway_id    = module.lb[0].nat_gateway_id
  allowed_cidrs = [
    module.web[0].security_group_id,
    module.sg.sg_id
  ]
  iam_instance_profile = module.iam_ssm[0].ssm_instance_profile_name
  count                = var.enable_db ? 1 : 0
}

# module "sonarqube" {
#   source = "url"
#   vpc_id = module.vpc.vpc_id
#   sg_id  = module.sg.sg_id
#   count  = var.enable_sonarqube ? 1 : 0
# }
