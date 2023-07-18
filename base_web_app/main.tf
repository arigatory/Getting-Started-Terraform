##################################################################################
# PROVIDERS
##################################################################################

provider "yandex" {
  token      = "YOUR_YANDEX_CLOUD_TOKEN"
  folder_id  = "YOUR_FOLDER_ID"
  cloud_id   = "YOUR_CLOUD_ID"
  zone       = "ru-central1-a"
}

##################################################################################
# DATA
##################################################################################

data "yandex_compute_image" "amzn2_linux" {
  family = "amzn2-ami-hvm-x86_64-gp2"
}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "yandex_vpc" "app" {
  name           = "app"
  subnet         = "10.0.0.0/16"
  dns_servers    = ["8.8.8.8"]
  nat            = true
  route_table_id = yandex_route_table.app.id
}

resource "yandex_subnet" "public_subnet1" {
  name       = "public_subnet1"
  vpc_id     = yandex_vpc.app.id
  subnet     = "10.0.0.0/24"
  dhcp_options {
    domain_name_servers = ["8.8.8.8"]
  }
}

# ROUTING #
resource "yandex_route_table" "app" {
  name       = "app"
  vpc_id     = yandex_vpc.app.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_type      = "internet_gateway"
    next_hop_gateway_id = yandex_internet_gateway.app.id
  }
}

resource "yandex_route_table_association" "app_subnet1" {
  subnet_id      = yandex_subnet.public_subnet1.id
  route_table_id = yandex_route_table.app.id
}

# SECURITY GROUPS #
# Nginx security group 
resource "yandex_vpc_network" "nginx_sg" {
  name      = "nginx_sg"
  vpc_id    = yandex_vpc.app.id
}

resource "yandex_vpc_firewall_rule" "nginx_http_access" {
  network_id    = yandex_vpc_network.nginx_sg.id
  direction     = "INGRESS"
  protocol      = "tcp"
  ports         = ["80"]
  source_ranges = ["0.0.0.0/0"]
}

# INSTANCES #
resource "yandex_compute_instance" "nginx1" {
  name        = "nginx1"
  platform_id = "standard-v2"
  cores       = 1
  memory      = 2

  boot_disk {
    initialize_params {
      image_id = yandex_compute_image.amzn2_linux.id
    }
  }

  network_interface {
    subnet_id = yandex_subnet.public_subnet1.id
  }

  metadata = {
    user-data = <<EOF
#! /bin/bash
sudo amazon-linux-extras install -y nginx1
sudo service nginx start
sudo rm /usr/share/nginx/html/index.html
echo '<html><head><title>Taco Team Server</title></head><body style="background-color:#1F778D"><p style="text-align: center;"><span style="color:#FFFFFF;"><span style="font-size:28px;">You did it! Have a &#127790;</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html
EOF
  }
}



##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "ACCESS_KEY"
  secret_key = "SECRET_KEY"
  region     = "us-east-1"
}

##################################################################################
# DATA
##################################################################################

data "aws_ssm_parameter" "amzn2_linux" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "aws_vpc" "app" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

}

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id

}

resource "aws_subnet" "public_subnet1" {
  cidr_block              = "10.0.0.0/24"
  vpc_id                  = aws_vpc.app.id
  map_public_ip_on_launch = true
}

# ROUTING #
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }
}

resource "aws_route_table_association" "app_subnet1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.app.id
}

# SECURITY GROUPS #
# Nginx security group 
resource "aws_security_group" "nginx_sg" {
  name   = "nginx_sg"
  vpc_id = aws_vpc.app.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# INSTANCES #
resource "aws_instance" "nginx1" {
  ami                    = nonsensitive(data.aws_ssm_parameter.amzn2_linux.value)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet1.id
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]

  user_data = <<EOF
#! /bin/bash
sudo amazon-linux-extras install -y nginx1
sudo service nginx start
sudo rm /usr/share/nginx/html/index.html
echo '<html><head><title>Taco Team Server</title></head><body style=\"background-color:#1F778D\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">You did it! Have a &#127790;</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html
EOF

}

