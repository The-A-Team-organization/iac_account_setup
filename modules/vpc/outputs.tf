
output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "public_subnet_ip" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet_ids" {
  value = [
    aws_subnet.private_subnet_consul.id
  ]
}

output "private_consul_subnet_id" {

   value =  aws_subnet.private_subnet_consul.id
}

output "private_route_table_id" {
  value = aws_route_table.private_route_table.id
}


output "internet_gateway_id" {
  value = aws_internet_gateway.main_igw.id
}

