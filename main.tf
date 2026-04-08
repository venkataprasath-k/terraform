terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}
resource "aws_vpc" "PRODUCTION" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "PRODUCTION"
  }
}
resource "aws_internet_gateway" "productionigw" {
  vpc_id = aws_vpc.PRODUCTION.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.PRODUCTION.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.productionigw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.PRODUCTION.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.PRODUCTION.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private_subnet"
  }
}


resource "aws_security_group" "ec2-security-group" {
  name   = "ec2-security-group"
  vpc_id = aws_vpc.PRODUCTION.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "Ansible_server" {
  ami                    = "ami-048f4445314bcaa09" #Amazon linux
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2-security-group.id]
  key_name               = "MASTER"
  private_ip             = "10.0.1.150" 
  associate_public_ip_address = true
 
  tags = {
    Name = "Master"
  }
}
