# Create a custom VPC
resource "aws_vpc" "custom_vpc1" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "your_custom_vpc1"
  }
}

# Create an internet gateway for public subnet
resource "aws_internet_gateway" "custom_igw1" {
  vpc_id = aws_vpc.custom_vpc1.id
  tags = {
    Name = "your_internet_gateway1"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.custom_vpc1.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet1"
  }
}

# Create a private subnet
resource "aws_subnet" "private_subnet1" {
  vpc_id                  = aws_vpc.custom_vpc1.id
  cidr_block              = "10.0.2.0/24"
  tags = {
    Name = "private_subnet1"
  }
}

# Create security group for public subnet
resource "aws_security_group" "public_sg1" {
  name        = "public_security_group"
  description = "Allow HTTP and SSH traffic for public subnet"
  vpc_id      = aws_vpc.custom_vpc1.id
  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "public_security_group1"
  }
}

# Create security group for private subnet
resource "aws_security_group" "private_sg1" {
  name        = "private_security_group"
  description = "Allow outgoing traffic for private subnet"
  vpc_id      = aws_vpc.custom_vpc1.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "private_security_group1"
  }
}

# Create a public route table
resource "aws_route_table" "public_route_table1" {
  vpc_id = aws_vpc.custom_vpc1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.custom_igw1.id
  }
  tags = {
    Name = "public_route_table1"
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public_route_association1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_route_table1.id
}

# Use data source to get a registered Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

# Create S3 bucket for website files
resource "aws_s3_bucket" "website_bucket" {
  bucket = "websitebucket09"
}

# Set ACL for the S3 bucket
resource "aws_s3_bucket_acl" "website_bucket_acl" {
  bucket = aws_s3_bucket.website_bucket.bucket

}

# Upload website files to S3 bucket
resource "aws_s3_object" "website_index_html" {
  bucket = aws_s3_bucket.website_bucket.bucket
  key    = "index.html"
  source = "/home/ec2-user/index.html"
 
}


# Launch the EC2 instance and install website
resource "aws_instance" "ec2_instance1" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet1.id
  vpc_security_group_ids = [aws_security_group.public_sg1.id]
  key_name               = "terraform"
  user_data = <<-EOF
    #cloud-config
    runcmd:
      - sudo yum update -y
      - sudo yum install -y httpd
      - sudo systemctl start httpd
      - sudo systemctl enable httpd
      - sudo mkdir -p /var/www/html
      - sudo aws s3 cp s3://your_bucket_name/path/to/index.html /var/www/html/index.html
      - sudo chown apache:apache /var/www/html/index.html
      - sudo systemctl restart httpd
  EOF
  tags = {
    Name = "FIRST1"
  }
}

# Print the EC2's public IPv4 address
output "public_ipv4_address" {
  value = aws_instance.ec2_instance.public_ip
}
