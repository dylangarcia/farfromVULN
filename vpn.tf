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

  # Open the webserver port
  ingress {
    from_port   = 7894
    to_port     = 7894
    protocol    = "tcp"
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
    source      = "./pivpn/pivpn_openvpn.conf"
    destination = "/tmp/pivpn_openvpn.conf"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path) # CHANGE ME
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "flask/app.py"
    destination = "/home/ubuntu/app.py"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path) # CHANGE ME
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "flask/templates/index_template.html"
    destination = "/home/ubuntu/templates/index_template.html"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path) # CHANGE ME
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "flask/faq.html"
    destination = "/home/ubuntu/faq.html"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path) # CHANGE ME
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "flask/images/kali_linux_logo.png"
    destination = "/home/ubuntu/kali_linux_logo.png"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path) # CHANGE ME
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "flask/images/pivpn_logo.png"
    destination = "/home/ubuntu/pivpn_logo.png"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path) # CHANGE ME
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "flask/images/vulnhub_logo.png"
    destination = "/home/ubuntu/vulnhub_logo.png"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path) # CHANGE ME
      host        = self.public_ip
    }
  }    

  # Run the setup script
  provisioner "remote-exec" {
    inline = ["curl -L https://install.pivpn.io > install.sh",
      "chmod +x install.sh",
      "sudo apt update", # patchwork for issue https://github.com/hashicorp/terraform/issues/1025
      "sudo apt update",
      "echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections",
      "echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections",
      "echo y | sudo apt install iptables-persistent",
      "sudo ./install.sh --unattended /tmp/pivpn_openvpn.conf",
      "echo y | sudo apt install python3-flask",
      "export FLASK_APP=/home/ubuntu/app.py",
      "echo y | sudo apt install python3-flask",
      "mv templates index_template.html",
      "mkdir templates",
      "mv index_template.html templates/",
      "mkdir images",
      "mv kali_linux_logo.png images/",
      "mv pivpn_logo.png images/",
      "mv vulnhub_logo.png images/",      
      "export FLASK_APP=/home/ubuntu/app.py && flask run -h 0.0.0.0 -p 7894 &"]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path) # CHANGE ME
      host        = self.public_ip
    }
  }
  
  tags = {
    Name = "Primary vpn"
  }
}

# Don't change the name of the output, will break Webapp :)
output "PiVPN" {
  value = aws_instance.primary_vpn.public_ip
}
