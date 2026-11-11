# The layers of the images the nodes pull from ECR are stored in S3. A
# gateway endpoint on the app route tables keeps that traffic inside the AWS
# network and off the NAT gateways, which charge for every gigabyte. Gateway
# endpoints themselves cost nothing.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for table in aws_route_table.app : table.id]

  tags = {
    Name = "${var.name_prefix}-s3"
  }
}
