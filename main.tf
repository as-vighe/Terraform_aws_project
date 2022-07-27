# create vpc
resource "aws_vpc" "terraform-vpc" {
  cidr_block = "10.10.0.0/16"
  tags = {
    Name = "terraform-vpc"
  }
}

# public subnet-1a
resource "aws_subnet" "public-subnet-1a" {
  vpc_id     = aws_vpc.terraform-vpc.id
  cidr_block = "10.10.1.0/24"
  tags = {
    Name = "public-subnet-1a"
  }
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = "true"
}

# public subnet-1b
resource "aws_subnet" "public-subnet-1b" {
  vpc_id     = aws_vpc.terraform-vpc.id
  cidr_block = "10.10.2.0/24"
  tags = {
    Name = "public-subnet-1b"
  }
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = "true"
}

# private subnet-1c
resource "aws_subnet" "private-subnet-1c" {
  vpc_id     = aws_vpc.terraform-vpc.id
  cidr_block = "10.10.3.0/24"
  tags = {
    Name = "private-subnet-1c"
  }
  availability_zone = "ap-south-1a"
}

# private subnet-1d
resource "aws_subnet" "private-subnet-1d" {
  vpc_id     = aws_vpc.terraform-vpc.id
  cidr_block = "10.10.4.0/24"
  tags = {
    Name = "Private-subnet-1d"
  }
  availability_zone = "ap-south-1b"
}

# create security group
resource "aws_security_group" "allow_port80" {
  name        = "allow_port_80"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.terraform-vpc.id

  ingress {
    description      = "allow inbound web traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "allow inbound web traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

# create EC2 instance with wordpress AMI
resource "aws_instance" "public-wordpress-1a" {

  # ami           = "ami-0901109ae0ff82df0"
  ami           = "ami-068257025f72f470d"
  instance_type = var.instance_type
  tags = {
    Name = "wordpress-instance-1a"
  }
  key_name               = "terraform-wordpress"
  subnet_id              = aws_subnet.public-subnet-1a.id
  vpc_security_group_ids = [aws_security_group.allow_port80.id]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("C:/Users/Abhir/Downloads/terraform-wordpress.pem")
    host        = self.public_ip
    timeout     = "20s"
  }
  provisioner "remote-exec" {
    inline = [
      "echo I reached to terraform public server > /tmp/test.txt",
      "sudo apt-get update",
      "sudo apt-get install apache2 -y",
      "sudo apt-get install php-mysql -y",
      "sudo systemctl start apache2",
      "sudo systemctl start php",
      "cd /tmp",
      "sudo rm -f /var/www/html/index.html",
      "sudo wget https://wordpress.org/latest.tar.gz",
      "sudo tar -zxvf latest.tar.gz",
      "sudo cp -rf ./wordpress/* /var/www/html",
      "sudo systemctl stop apache2",
      "sudo systemctl start apache2"
    ]
  }
}

# create internet gateway
resource "aws_internet_gateway" "gateway-1" {
  vpc_id = aws_vpc.terraform-vpc.id

  tags = {
    Name = "gateway-1"
  }
}

# create route table
resource "aws_route_table" "Public_RT" {
  vpc_id = aws_vpc.terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway-1.id
  }

  tags = {
    Name = "Public_RT"
  }
}

# create route table association
resource "aws_route_table_association" "RT-asso-1a" {
  subnet_id      = aws_subnet.public-subnet-1a.id
  route_table_id = aws_route_table.Public_RT.id
}
resource "aws_route_table_association" "RT-asso-1b" {
  subnet_id      = aws_subnet.public-subnet-1b.id
  route_table_id = aws_route_table.Public_RT.id
}
resource "aws_route_table_association" "RT-asso-1c" {
  subnet_id      = aws_subnet.private-subnet-1c.id
  route_table_id = aws_route_table.Private_RT.id
}
resource "aws_route_table_association" "RT-asso-1d" {
  subnet_id      = aws_subnet.private-subnet-1d.id
  route_table_id = aws_route_table.Private_RT.id
}

#Create Target Group
resource "aws_lb_target_group" "target-group-terraform" {
  name     = "target-group-terraform"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform-vpc.id
}

#Create Target Group Attachment
resource "aws_lb_target_group_attachment" "target-wordpress-attachment" {
  target_group_arn = aws_lb_target_group.target-group-terraform.arn
  target_id        = aws_instance.public-wordpress-1a.id
  port             = 80
}

# security group for load balancer
resource "aws_security_group" "allow_port80_lb" {
  name        = "allow_port_80_lb"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.terraform-vpc.id


  ingress {
    description      = "allow inbound web traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

#Create Load Balancer
resource "aws_lb" "wordpress-lb" {
  name               = "wordpress-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_port80_lb.id]
  subnets            = [aws_subnet.public-subnet-1a.id, aws_subnet.public-subnet-1b.id]
  tags = {
    Environment = "production"
    Name        = "wordpress"
  }
}
resource "aws_lb_listener" "wordpress-listnerer" {
  load_balancer_arn = aws_lb.wordpress-lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group-terraform.arn
  }
}

#elastic Ip for nat gateway
resource "aws_eip" "private-subnet-1c-eip" {
  vpc = true
  tags = {
    Name = "eip-nat"
  }
}

#create nat gateway
resource "aws_nat_gateway" "public-subnet-1a-nat" {
  allocation_id = aws_eip.private-subnet-1c-eip.id
  subnet_id     = aws_subnet.public-subnet-1a.id
}

#create route table for nat gateway
resource "aws_route_table" "Private_RT" {
  vpc_id = aws_vpc.terraform-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.public-subnet-1a-nat.id

  }

  tags = {
    Name = "Private_RT"
  }
}

# create security group for bastion public instance
resource "aws_security_group" "public_port80" {
  name        = "public_port80"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.terraform-vpc.id

  ingress {
    description      = "allow inbound web traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "allow inbound web traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}


#create EC2 instance with bastion public
resource "aws_instance" "public-bastion-1b" {

  ami           = "ami-068257025f72f470d"
  instance_type = "t2.micro"
  tags = {
    Name = "bastion-host-public"
  }
  key_name               = "terraform-wordpress"
  subnet_id              = aws_subnet.public-subnet-1b.id
  vpc_security_group_ids = [aws_security_group.public_port80.id]

  provisioner "file" {
    source      = "db_backup.sql"
    destination = "/tmp/db_backup.sql"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install mysql* -y",
      join(" ", ["mysql -h ", aws_db_instance.wordpressdb.address, "-u 'admin' --password='admin123' accounts < /tmp/db_backup.sql"])
    ]
  }

  connection {
    user        = "ubuntu"
    private_key = file("C:/Users/Abhir/Downloads/terraform-wordpress.pem")
    host        = self.public_ip
  }
  depends_on = [aws_db_instance.wordpressdb]
}


#Create security group for RDS
resource "aws_security_group" "rds-sg" {
  name        = "rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.terraform-vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.public_port80.id]
  }
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

#create subnet group for RDS
resource "aws_db_subnet_group" "db-subnetgroup" {
  name = "main"
  #subnet_ids = ["10.10.3.0/24"]
  subnet_ids = [aws_subnet.private-subnet-1c.id, aws_subnet.private-subnet-1d.id]
  tags = {
    Name = "Subnet group for RDS"
  }
}

resource "aws_db_instance" "wordpressdb" {

  identifier             = "mydatabase"
  db_name                = "accounts"
  allocated_storage      = 20
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "admin123"
  parameter_group_name   = "default.mysql8.0"
  availability_zone      = "ap-south-1b"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db-subnetgroup.name
  vpc_security_group_ids = [aws_security_group.rds-sg.id]

}

