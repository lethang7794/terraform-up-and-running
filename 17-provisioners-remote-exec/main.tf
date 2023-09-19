provider "aws" {
  region = "ap-southeast-1"
}

# Create a security group that allows inbound connections to port 22, the default port for SSH:
resource "aws_security_group" "instance" {
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    # To make this example easy to try out, we allow all SSH connections.
    # In real world usage, you should lock this down to solely trusted IPs.
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# To make this example easy to try out, we generate a private key in Terraform.
# In real-world usage, you should manage SSH keys outside of Terraform.
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Update the public key from Terraform state to AWS
resource "aws_key_pair" "generated_key" {
  public_key = tls_private_key.example.public_key_openssh
}

# Get the most recent Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Create an EC2 instance
resource "aws_instance" "example" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]    # Associate that instance with the security group we created earlier
  key_name               = aws_key_pair.generated_key.key_name # Associate that instance with the public key we created earlier

  provisioner "remote-exec" {                           # The remote-exec provisioner block
    inline = ["echo \"Hello, World from $(uname -a)\""] # Instead local-exec's `command` argument, remote-exec use an `inline` argument
  }

  # Configure Terraform to use SSH to connect to this EC2 Instance
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.example.private_key_pem
  }
}
