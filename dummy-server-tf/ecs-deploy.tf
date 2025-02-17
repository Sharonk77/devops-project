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

  tags = { Name = "public_subnet_1" }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.dummy-server-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = { Name = "public_subnet_2" }
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
    security_groups = [aws_security_group.alb_sg.id]  # Only allow traffic from ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow outbound traffic
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
          hostPort      = 0,
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.dummy-server-vpc.id
  name   = "alb-security-group"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from anywhere
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTPS from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow outbound traffic
  }

  tags = { Name = "alb-sg" }
}


resource "aws_lb" "dummy_alb" {
  name               = "dummy-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets           = [
    aws_subnet.public_subnet.id,
    aws_subnet.public_subnet_2.id
  ]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.dummy_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.dummy_tg.arn
  }
}

resource "aws_lb_target_group" "dummy_tg" {
  name     = "dummy-tg"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = aws_vpc.dummy-server-vpc.id
  target_type = "ip"
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
    security_groups = [aws_security_group.alb_sg.id]
    assign_public_ip = true

  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dummy_tg.arn
    container_name   = "dummy-server-container"
    container_port   = 3001
  }

}
