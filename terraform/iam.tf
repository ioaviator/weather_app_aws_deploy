data "aws_caller_identity" "current" {}

locals {
  caller_name = element(split("/", data.aws_caller_identity.current.arn), length(split("/", data.aws_caller_identity.current.arn)) - 1)
}

# Single, comprehensive policy containing all required permissions explicitly
resource "aws_iam_policy" "weather_app_master_policy" {
  name        = "weather_app_master_management"
  description = "Comprehensive policy to manage IAM, ECS, and VPC resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowIAMManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
          "iam:PassRole", "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies", "iam:CreatePolicy", "iam:DeletePolicy",
          "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions",
          "iam:ListPolicies", "iam:AttachRolePolicy", "iam:DetachRolePolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowECSLifecycleAndDescribe"
        Effect = "Allow"
        Action = [
          "ecs:CreateCluster", "ecs:DescribeClusters", "ecs:DeleteCluster",
          "ecs:UpdateCluster", "ecs:ListClusters", "ecs:TagResource",
          "ecs:UntagResource", "ecs:ListTagsForResource",
          "ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition",
          "ecs:DeregisterTaskDefinition", "ecs:ListTaskDefinitions",
          "ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService",
          "ecs:DescribeServices", "ecs:ListServices", "ecs:ListTasks", "ecs:DescribeTasks"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2VPCAndDescribe"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs", "ec2:ModifyVpcAttribute", "ec2:DescribeVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets", "ec2:ModifySubnetAttribute",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway", "ec2:DescribeInternetGateways",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:DescribeRouteTables",
          "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "ec2:CreateTags", "ec2:DeleteTags", "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "attach_master_policy" {
  user       = local.caller_name
  policy_arn = aws_iam_policy.weather_app_master_policy.arn
}

resource "time_sleep" "wait_for_iam_propagation" {
  depends_on      = [aws_iam_user_policy_attachment.attach_master_policy]
  create_duration = "40s"
}


resource "aws_iam_policy" "ecs_policy" {
  name        = "weather_app_ecs_policy"
  description = "Allows ECS execution role to create and write CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}


# IAM Roles for ECS Execution & Task
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs_weather_app_execution_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  depends_on         = [time_sleep.wait_for_iam_propagation]
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_policy.arn
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "weather_app_task_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}


