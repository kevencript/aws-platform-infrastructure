output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "IPv4 block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, by zone. For the load balancer."
  value       = { for zone, subnet in aws_subnet.public : zone => subnet.id }
}

output "app_subnet_ids" {
  description = "IDs of the private app subnets, by zone. For the EKS nodes and their pods."
  value       = { for zone, subnet in aws_subnet.app : zone => subnet.id }
}

output "data_subnet_ids" {
  description = "IDs of the private data subnets, by zone. For RDS, ElastiCache and MSK."
  value       = { for zone, subnet in aws_subnet.data : zone => subnet.id }
}
