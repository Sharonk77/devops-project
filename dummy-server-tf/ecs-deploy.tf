provider "aws" {
  region = "us-east-1"
}


terraform {
  backend "s3" {}

}

variable "aws_account_id" {
  type      = string
  sensitive = true
}

variable "ghcr_token" {
  type      = string
  sensitive = true
}



resource "aws_vpc" "dummy-server-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "dummy-server-vpc" }
}

resource "aws_internet_gateway" "dummy-server-gw" {
  vpc_id = aws_vpc.dummy-server-vpc.id
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.dummy-server-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = { Name = "dummy-server-public-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.dummy-server-vpc.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dummy-server-gw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.dummy-server-vpc.id
  name   = "ecs-security-group"


  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ecs-sg" }
}

# ECS Cluster
resource "aws_ecs_cluster" "dummy-server-cluster" {
  name = "dummy-server-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_ecs_task_definition" "dummy_server_task" {
  family                   = "dummy_server_task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name  = "dummy-server-container",
      image = "ghcr.io/sharonk77/devops-project:latest",
      essential = true,

      portMappings = [
        {
          containerPort = 3001,
          hostPort      = 3001,
          protocol      = "tcp"
        }
      ]
    }
  ])
}

#  Create an ECS Service (Fargate Spot for Cheaper Costs)
resource "aws_ecs_service" "dummy-service" {
  name            = "dummy-service"
  cluster         = aws_ecs_cluster.dummy-server-cluster.id
  task_definition = aws_ecs_task_definition.dummy_server_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.public_subnet.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true

  }
}
