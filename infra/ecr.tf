resource "aws_ecr_repository" "app" {
  name                 = "device-monitor"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "device-monitor-ecr"
  }
}
