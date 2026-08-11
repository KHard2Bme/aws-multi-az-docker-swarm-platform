############################################
# iam.tf
# IAM resources for CloudWatch Agent
############################################

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudwatch_agent_role" {
  name               = "${var.project_name}-cloudwatch-agent-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-cloudwatch-agent-role"
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cloudwatch_agent_profile" {
  name = "${var.project_name}-cloudwatch-agent-profile"
  role = aws_iam_role.cloudwatch_agent_role.name
}

############################################
# Additional CloudWatch permissions
############################################

resource "aws_iam_role_policy" "cloudwatch_dashboard_policy" {
  name = "${var.project_name}-cloudwatch-dashboard-policy"
  role = aws_iam_role.cloudwatch_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "cloudwatch:GetDashboard",
          "cloudwatch:PutDashboard",
          "cloudwatch:ListDashboards",
          "cloudwatch:DeleteDashboards",

          "cloudwatch:DescribeAlarms",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",

          "logs:DescribeLogGroups",
          "logs:DescribeMetricFilters",
          "logs:PutMetricFilter"
        ]

        Resource = "*"
      }
    ]
  })
}