
resource "aws_ecr_repository" "weather_app" {
  name                 = "weather_app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

