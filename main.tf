terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}


#################################################VPC CREATION#######################################


resource "aws_vpc" "PRODUCTION" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "PRODUCTION"
  }
}


############################################### IGW Attach to VPC ###################################


resource "aws_internet_gateway" "productionigw" {
  vpc_id = aws_vpc.PRODUCTION.id

  tags = {
    Name = "main-igw"
  }
}

############################################## Route table to Public ###################################


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
##################################### attach route public ############################################
resource "aws_route_table_association" "rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

########################################## Routr table private #######################################

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.PRODUCTION.id

  tags = {
    Name = "private-route-table"
  }
}

#########################################attach route private  ###########################################
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}





########################################## Public Subnet creation ########################################

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.PRODUCTION.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public_subnet"
  }
}

######################################### private subnet creation #######################################


resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.PRODUCTION.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private_subnet"
  }
}

###################################### security group ##################################################

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
ingress {
    description = "Allow HTTP"
    from_port   = 443
    to_port     = 443
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
########################################################### security group for private ##################################
resource "aws_security_group" "app_sg" {
  name   = "app-sg"
  vpc_id = aws_vpc.PRODUCTION.id

  ingress {
    description     = "Allow SSH only from WebServer"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2-security-group.id]
  }

  ingress {
    description     = "Allow App traffic from WebServer"
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2-security-group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###################################### Webserver EC2 #################################


resource "aws_instance" "WEBSERVER" {
  ami                    = "ami-048f4445314bcaa09" #Amazon linux
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2-security-group.id]
  key_name               = "MASTER"
  private_ip             = "10.0.1.150" 
  associate_public_ip_address = true
 
  tags = {
    Name = "Webserver"
  }
}

########################################### Appserver Ec2 ##############################


resource "aws_instance" "APPSERVER" {
  ami                    = "ami-048f4445314bcaa09" #Amazon linux
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = "MASTER"
  private_ip             = "10.0.2.150"
  tags = {
    Name = "Appserver"
  }
}

########################################## voulme creation ####################

resource "aws_ebs_volume" "extra_volume_public" {
  availability_zone = "ap-south-1a"   # same AZ as EC2
  size              = 10              # 10GB
  type              = "gp2"

  tags = {
    Name = "ExtraVolume"
  }
}


resource "aws_ebs_volume" "extra_volume_private" {
  availability_zone = "ap-south-1b"   # same AZ as EC2
  size              = 10              # 10GB
  type              = "gp2"

  tags = {
    Name = "ExtraVolume"
  }
}

####################################### volume attach ############################
resource "aws_volume_attachment" "attach_volume_1" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.extra_volume_public.id
  instance_id = aws_instance.WEBSERVER.id
}

resource "aws_volume_attachment" "attach_volume_2" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.extra_volume_private.id
  instance_id = aws_instance.APPSERVER.id
}
