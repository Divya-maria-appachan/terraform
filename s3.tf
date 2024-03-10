# Configure AWS provider
provider "aws" {
  region  = "us-east-1"
}
# Create an S3 bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "youruniquebucketname11180080"  # Replace with your desired bucket name
  

 }
resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.my_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_public_access_block" "my_bucket" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

  resource "aws_s3_bucket_acl" "example" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.my_bucket
     ]
  
  bucket = aws_s3_bucket.my_bucket.id
  acl    = "public-read"
}
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.my_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

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
  availability_zone        = "us-east-1a"
  tags = {
    Name = "public_subnet1"
  }
}
# Create a public subnet
resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.custom_vpc1.id
  cidr_block              = "10.0.3.0/24"
  availability_zone        = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet2"
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

# Create security group for public sub
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


# Create a public route table
resource "aws_route_table" "public_route_table1" {
  vpc_id = aws_vpc.custom_vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.custom_igw1.id
  }

  tags = {
    Name = "public_route_table"
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


# Associate the public route table with the public subnet
resource "aws_route_table_association" "public_route_association1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_route_table1.id
}
# Associate the public route table with the public subnet
resource "aws_route_table_association" "public_route_association2" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_route_table1.id
}
# Upload a file to the S3 bucket
resource "aws_s3_object" "my_object" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "index.html"  # Replace with your desired file name
  source = "/home/ec2-user/index.html"  # Replace with the local path to your file
  acl    = "public-read"
}
resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    "${aws_security_group.public_sg1.id}"
  ]
  subnets = [
    "${aws_subnet.public_subnet1.id}",
    "${aws_subnet.public_subnet2.id}"
  ]
cross_zone_load_balancing   = true
health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target   = "HTTP:80/index.html"
  }
listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
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


resource "aws_launch_configuration" "web" {
  name_prefix = "web-"
  image_id       = data.aws_ami.amazon_linux_2.id 
  instance_type = "t2.micro"
  key_name = "terraform"
  security_groups = [aws_security_group.public_sg1.id]
  associate_public_ip_address = true
   user_data = <<-EOF
     #cloud-config
     runcmd:
       - sudo yum update -y
       - sudo yum install -y httpd
       - sudo systemctl start httpd
       - sudo systemctl enable httpd
       - sudo mkdir -p /var/www/html
       - sudo curl -o /var/www/html/index.html https://youruniquebucketname11180080.s3.amazonaws.com/index.html
       - sudo chmod 644 /var/www/html/index.html
       - sudo systemctl restart httpd
  EOF
lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"
  min_size             = 1
  desired_capacity     = 1
  max_size             = 2
  
  health_check_type    = "ELB"
  load_balancers = [
    "${aws_elb.web_elb.id}"
  ]
launch_configuration = "${aws_launch_configuration.web.name}"
enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
metrics_granularity = "1Minute"
vpc_zone_identifier  = [
    "${aws_subnet.public_subnet1.id}",
    "${aws_subnet.public_subnet2.id}"
  ]
# Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }
tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }
}
resource "aws_autoscaling_policy" "web_policy_up" {
  name = "web_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.web.name}"
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "70"
dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.web.name}"
  }
alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ "${aws_autoscaling_policy.web_policy_up.arn}" ]
}
resource "aws_autoscaling_policy" "web_policy_down" {
  name = "web_policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.web.name}"
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "30"
dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.web.name}"
  }
alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ "${aws_autoscaling_policy.web_policy_down.arn}" ]
}
# Launch the EC2 instance and install website
resource "aws_instance" "ec2_instance1" {
  ami              ="ami-0e731c8a588258d0d" 
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
      - sudo curl -o /var/www/html/index.html https://youruniquebucketname1118008.s3.amazonaws.com/index.html
      - sudo chmod 644 /var/www/html/index.html
      - sudo systemctl restart httpd
  EOF
  tags = {
    Name = "FIRST1"
  }
}
