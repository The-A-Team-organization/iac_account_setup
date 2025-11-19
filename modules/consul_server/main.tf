resource "aws_iam_role" "consul_role" {
  name = "consul_role"


  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy_attachment" "consul_ssm" {
  role       = aws_iam_role.consul_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_role_policy_attachment" "consul_ecr" {
  role       = aws_iam_role.consul_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}


resource "aws_iam_instance_profile" "consul_profile" {
  name = "consul_profile"
  role = aws_iam_role.consul_role.name
}


resource "aws_instance" "consul_server" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.sg_id]
  associate_public_ip_address = false
  iam_instance_profile   = aws_iam_instance_profile.consul_profile.name

  tags = {
    Name = "Consul Server"
  }
}


resource "aws_route53_zone" "internal" {
  name = "internal"
  vpc {
    vpc_id = var.main_vpc_id
    vpc_region = var.aws_region
  }
}


resource "aws_route53_record" "consul_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "consul.internal"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.consul_server.private_ip]
}