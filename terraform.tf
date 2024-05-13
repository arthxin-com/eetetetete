terraform {
  required_version = "~> 1.8"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# terraform {
#     backend "s3" {
#     #encrypt = true
#     bucket = "terraform-state-file-cmv1"
#     key    = "terraform.tfstate"
#     #dynamodb_table = "tf-lock"
#     region = "eu-central-1"
#     #kms_key_id = "arn:aws:kms:eu-central-1:039779453013"
#   }
# }

variable "token" {}

variable "github_org" {
  default = "arthxin-com"
}

variable "url" {
  default = "token.actions.githubusercontent.com"
}

provider "github" {
  owner = var.github_org
}

provider "aws" {
  region = "eu-central-1"
}

resource "github_repository" "repo1" {
  name       = "test-repo-auto"
  visibility = "private"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

resource "aws_s3_bucket" "remote_state" {
  bucket = "terraform-state-file-cmv"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://${var.url}"
  client_id_list  = ["sts.${data.aws_partition.current.dns_suffix}"]
}

resource "aws_iam_role" "github-oidc-role" {
  name = "github-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.url}"
          },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringLike": {
            "${var.url}:sub": "repo:${var.github_org}/*",
            "${var.url}:aud": "sts.${data.aws_partition.current.dns_suffix}"
            }
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}