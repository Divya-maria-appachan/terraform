# Configure AWS provider
provider "aws" {
  region  = "us-east-1"
}

# Create a custom VPC
resource "aws_vpc" "custom_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "your_custom_vpc"
  }
}

# Create an internet gateway for public subnet
resource "aws_internet_gateway" "custom_igw" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "your_internet_gateway"
  }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet"
  }
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.2.0/24"

  tags = {
    Name = "private_subnet"
  }
}

# Create security group for public subnet
resource "aws_security_group" "public_sg" {
  name        = "public_security_group"
  description = "Allow HTTP and SSH traffic for public subnet"
  vpc_id      = aws_vpc.custom_vpc.id

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
    Name = "public_security_group"
  }
}

# Create security group for private subnet
resource "aws_security_group" "private_sg" {
  name        = "private_security_group"
  description = "Allow outgoing traffic for private subnet"
  vpc_id      = aws_vpc.custom_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private_security_group"
  }
}
# Create a public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.custom_igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public_route_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Output the VPC ID
output "vpc_id" {
  value = aws_vpc.custom_vpc.id
}


# use data source to get a registered amazon linux 2 ami
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

# launch the ec2 instance and install website
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = "terraform"
  user_data = <<-EOF
    #cloud-config
    runcmd:
      - sudo yum update -y
      - sudo yum install -y httpd
      - sudo systemctl start httpd
      - sudo systemctl enable httpd
      - sudo mkdir -p /var/www/html
      - sudo wget https://github.com/learning-zone/website-templates/archive/master.zip
      - sudo unzip master.zip
      - sudo cp -r website-templates-master/victory-educational-institution-free-html5-bootstrap-template/* /var/www/html/
      - sudo chown -R apache:apache /var/www/html
      - sudo systemctl restart httpd
  EOF


  tags = {
    Name = "FIRST"
  }
}


# print the ec2's public ipv4 address
output "public_ipv4_address" {
  value = aws_instance.ec2_instance.public_ip
}
