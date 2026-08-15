data "aws_ecr_repository" "weather_app" {
  name       = aws_ecr_repository.weather_app.name
  depends_on = [aws_ecr_repository.weather_app]
}

resource "aws_ecr_repository" "weather_app" {
  name                 = "weather_app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  depends_on = [time_sleep.wait_for_iam_propagation]
  
  tags = {
    Name = "weather_app_vpc"
  }
}

resource "aws_internet_gateway" "weather_app_gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "weather_app-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Create the custom route table inside VPC
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "weather_app_public_rt"
  }
}

# Add the default route out to the Internet Gateway
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.weather_app_gw.id
}

# Associate route table with public subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name       = "weather_app_cluster"
  depends_on = [time_sleep.wait_for_iam_propagation]
}

# ECS Task Definition
resource "aws_ecs_task_definition" "weather_app" {
  family                   = "weather_app-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  depends_on = [ aws_ecr_repository.weather_app ]

  container_definitions = jsonencode([
    {
      name      = "weather_app"
      image     = "${data.aws_ecr_repository.weather_app.repository_url}"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/weather_app"
          "awslogs-region"        = "eu-north-1"
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "weather_app_service" {
  name            = "weather_app_service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.weather_app.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_execution_policy]
}