# Configure the AWS Provider
# From https://raw.githubusercontent.com/3ndG4me/Offensive-Security-Engineering-Udemy/master/base-vpn/vpn.tf
data "aws_ami" "ubuntu" {
  most_recent = "true"

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}


# Put your IP here to whitelist it for ssh

variable "access_addr" {
    type    = string
    default = "0.0.0.0/0"

}

resource "aws_security_group" "vpn_group" {
  name        = "vpn_group"
  description = "Allow Ports for VPN and SSH access"
  vpc_id = aws_vpc.main.id

  # Open the default OpenVPN Port
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }



  # ssh for remote access, might want to lock down to your IP prior to rolling out
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.access_addr]
  }

  # Allow traffic from the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }  

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "primary_vpn" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = var.instance_type
  subnet_id              = aws_subnet.my_subnet.id  
  vpc_security_group_ids = [aws_security_group.vpn_group.id]
  key_name        = "primary"

  provisioner "file" {
    source      = "unattended_openvpn_example.conf"
    destination = "/tmp/unattended_openvpn_example.conf"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/labs-key.pem") # CHANGE ME
      host        = self.public_ip
    }
  }

  # Run the setup script
  provisioner "remote-exec" {
    inline = ["curl -L https://install.pivpn.io > install.sh && chmod +x install.sh && sudo apt update && sudo apt install iptables-persistent && sudo ./install.sh --unattended /tmp/unattended_openvpn_example.conf"]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/labs-key.pem") # CHANGE ME
      host        = self.public_ip
    }
  }

  
  tags = {
    Name = "Primary vpn"
  }
}

output "IP" {
  value = aws_instance.primary_vpn.public_ip
}