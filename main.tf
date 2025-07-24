provider "aws" {
    region = "us-east-1"
    access_key = var.access_key
    secret_key = var.secret_key
}

resource "aws_vpc" "website_vpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "websitevpc"
  }
}

resource "aws_subnet" "db_subnet1" {
  vpc_id     = aws_vpc.website_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "dbsubnet1"
  }
}

resource "aws_subnet" "db_subnet2" {
  vpc_id     = aws_vpc.website_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "dbsubnet2"
  }
}

resource "aws_db_subnet_group" "dbsubnetgroup" {
  name       = "dbsubnetgroup"
  subnet_ids = [aws_subnet.db_subnet1.id, aws_subnet.db_subnet2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "allow_db"
  description = "Allow db inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.website_vpc.id

  tags = {
    Name = "allow_db"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_mysql_ipv4" {
  security_group_id = aws_security_group.db_sg.id
  cidr_ipv4         = aws_vpc.website_vpc.cidr_block
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.db_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.db_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_s3_bucket" "website_images" {
    bucket = "anastacia-website-images-bucket"

}
resource "aws_s3_bucket_website_configuration" "website_index" {
  bucket = aws_s3_bucket.website_images.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_db_instance" "mysqlinstance" {
  allocated_storage    = 10
  db_name              = "websitedb"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = var.master_db_password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  multi_az = false 
  availability_zone = "us-east-1a"
  db_subnet_group_name = aws_db_subnet_group.dbsubnetgroup.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

## ec2 instance to run the flask app

resource "aws_instance" "flask_server" {
  ami           = "ami-0cbbe2c6a1bb2ad63"
  instance_type = "t2.micro"
  key_name = var.key_pair_name
  subnet_id = aws_subnet.db_subnet1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y python3 git
              sudo pip3 install flask pymysql boto3
              cd /home/ec2-user
              git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git flask-app
              cd flask-app
              python3 app.py &
              EOF


  tags = {
    Name = "app server"
  }
}

##ec2 security group

resource "aws_security_group" "ec2_sg" {
  name        = "allow_https_ssh"
  description = "Allow https inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.website_vpc.id

  tags = {
    Name = "allow_https_ssh"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = aws_vpc.website_vpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = aws_vpc.website_vpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_servers" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = aws_vpc.website_vpc.cidr_block
  from_port         = 5000
  ip_protocol       = "tcp"
  to_port           = 5000
}

resource "aws_vpc_security_group_egress_rule" "allow_ec2_ipv4" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_ec2_ipv6" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

