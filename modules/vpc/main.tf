
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}


resource "aws_subnet" "private_subnet_consul" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = var.available_zones_list[2]

  depends_on = [aws_vpc.main_vpc]

  tags = {
    Name = "private-subnet-consul"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.6.0/24"
  availability_zone = var.available_zones_list[2]
  map_public_ip_on_launch = true

  depends_on = [aws_vpc.main_vpc]


  tags = {
    Name = "public-subnet-jenkins"
  }
}


resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-internet-gateway"
  }
}


resource "aws_eip" "main_eip" {
  domain = "vpc"
  tags = {
    Name = "main-eip"
  }
}


resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.main_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "jenkins-nat-gateway"
  }
}



resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_nat.id
  }

  tags = {
    Name = "private-route-table"
  }
}


resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_consul.id
  route_table_id = aws_route_table.private_route_table.id
}

