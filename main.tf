terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-northeast-2"
}

resource "aws_vpc" tutorial_vpc {
  cidr_block = "10.0.0.0/20"
  tags = {
    Name = "tutorial-${var.vpc-name}"
  }
}

resource "aws_vpc_dhcp_options" "tutorial_dhcp" {
  domain_name = "ap-northeast-2.compute.internal"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = {
    Name = "terraform-test-dhcp"
  }
}

resource "aws_vpc_dhcp_options_association" "a" {
  vpc_id = aws_vpc.tutorial_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.tutorial_dhcp.id
}

resource "aws_security_group" "tutorial_sg" {
  name        = "terraform-test-sg"
  description = "terraform-test-sg"
  vpc_id      = aws_vpc.tutorial_vpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = "${var.server_port}"
    to_port          = "${var.server_port}"
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-test-sg"
  }
}

resource "aws_subnet" "tutorial-subnet-public-a" {
  vpc_id = aws_vpc.tutorial_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "terraform-subnet-public-ap-northeast-2a"
  }
}

resource "aws_subnet" "tutorial-subnet-public-c" {
  vpc_id = aws_vpc.tutorial_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = {
    Name = "terraform-subnet-public-ap-northeast-2c"
  }
}

resource "aws_subnet" "tutorial-subnet-private-a" {
  vpc_id = aws_vpc.tutorial_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = false
  tags = {
    Name = "terraform-subnet-private-ap-northeast-2a"
  }
}

resource "aws_subnet" "tutorial-subnet-private-c" {
  vpc_id = aws_vpc.tutorial_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-northeast-2c"
  map_public_ip_on_launch = false
  tags = {
    Name = "terraform-subnet-private-ap-northeast-2c"
  }
}

resource "aws_internet_gateway" "terraform-igw" {
  vpc_id = aws_vpc.tutorial_vpc.id

  tags = {
    Name = "terraform-igw"
  }
}

resource "aws_route_table" "terraform-rtb-private-subnet" {
  vpc_id = aws_vpc.tutorial_vpc.id

  tags = {
    Name = "terraform-rtb-private-subnet"
  }
}

resource "aws_route_table_association" "private-a" {
  subnet_id      = aws_subnet.tutorial-subnet-private-a.id 
  route_table_id = aws_route_table.terraform-rtb-private-subnet.id
}

resource "aws_route_table_association" "private-c" {
  subnet_id      = aws_subnet.tutorial-subnet-private-c.id
  route_table_id = aws_route_table.terraform-rtb-private-subnet.id
}

resource "aws_route_table" "terraform-rtb-public" {
  vpc_id = aws_vpc.tutorial_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform-igw.id
  }

  tags = {
    Name = "terraform-rtb-public"
  }
}

resource "aws_route_table_association" "public-a" {
  subnet_id      = aws_subnet.tutorial-subnet-public-a.id
  route_table_id = aws_route_table.terraform-rtb-public.id
}

resource "aws_route_table_association" "public-c" {
  subnet_id      = aws_subnet.tutorial-subnet-public-c.id
  route_table_id = aws_route_table.terraform-rtb-public.id
}

resource "aws_instance" "terraform_ec2" {
  ami           = "ami-0cb1d752d27600adb"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.tutorial-subnet-public-a.id
  security_groups = ["${aws_security_group.tutorial_sg.id}"]

  key_name      = "codestates03"
  user_data     = <<-EOL
  #!/bin/bash
  echo "Start Server!"
  sudo apt update
  sudo apt install busybox
  echo "Hello, World" > index.html
  nohup busybox httpd -f -p ${var.server_port} &
  EOL
  
  tags = {
    Name = "tutorial-ec2-instance"
  }
}