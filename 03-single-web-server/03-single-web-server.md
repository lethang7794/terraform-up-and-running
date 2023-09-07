# Single web server

```terraform
# 03-single-web-server/main.tf
provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_instance" "my_ec2_instance" {
  ami                    = "ami-0464f90f5928bccb8"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_securiy_group.id]

  user_data                   = <<-EOF
                                  #!/bin/bash
                                  echo "Hello, World" > index.html
                                  nohup busybox httpd -f -p 8080 &
                                EOF
  user_data_replace_on_change = true

  tags = {
    "Name" = "my_web_server"
  }
}


resource "aws_security_group" "my_securiy_group" {
  name = "my_web_server_sg"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

```log
~/go-/src/git/lethang7794/terraform-up-and-running ./03-single-web-server  .                                                    main ?  13:35 ❌ exit ERROR

✖  terraform apply

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_instance.my_ec2_instance will be created
  + resource "aws_instance" "my_ec2_instance" {
      + ami                                  = "ami-0464f90f5928bccb8"
      + arn                                  = (known after apply)
      + associate_public_ip_address          = (known after apply)
      + availability_zone                    = (known after apply)
      + cpu_core_count                       = (known after apply)
      + cpu_threads_per_core                 = (known after apply)
      + disable_api_stop                     = (known after apply)
      + disable_api_termination              = (known after apply)
      + ebs_optimized                        = (known after apply)
      + get_password_data                    = false
      + host_id                              = (known after apply)
      + host_resource_group_arn              = (known after apply)
      + iam_instance_profile                 = (known after apply)
      + id                                   = (known after apply)
      + instance_initiated_shutdown_behavior = (known after apply)
      + instance_lifecycle                   = (known after apply)
      + instance_state                       = (known after apply)
      + instance_type                        = "t2.micro"
      + ipv6_address_count                   = (known after apply)
      + ipv6_addresses                       = (known after apply)
      + key_name                             = (known after apply)
      + monitoring                           = (known after apply)
      + outpost_arn                          = (known after apply)
      + password_data                        = (known after apply)
      + placement_group                      = (known after apply)
      + placement_partition_number           = (known after apply)
      + primary_network_interface_id         = (known after apply)
      + private_dns                          = (known after apply)
      + private_ip                           = (known after apply)
      + public_dns                           = (known after apply)
      + public_ip                            = (known after apply)
      + secondary_private_ips                = (known after apply)
      + security_groups                      = (known after apply)
      + source_dest_check                    = true
      + spot_instance_request_id             = (known after apply)
      + subnet_id                            = (known after apply)
      + tags                                 = {
          + "Name" = "my_web_server"
        }
      + tags_all                             = {
          + "Name" = "my_web_server"
        }
      + tenancy                              = (known after apply)
      + user_data                            = "67e34b406ab639a606a64fe06965b26bf8036a9c"
      + user_data_base64                     = (known after apply)
      + user_data_replace_on_change          = true
      + vpc_security_group_ids               = (known after apply)
    }

  # aws_security_group.my_securiy_group will be created
  + resource "aws_security_group" "my_securiy_group" {
      + arn                    = (known after apply)
      + description            = "Managed by Terraform"
      + egress                 = (known after apply)
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + description      = ""
              + from_port        = 8080
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 8080
            },
        ]
      + name                   = "my_web_server_sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags_all               = (known after apply)
      + vpc_id                 = (known after apply)
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_security_group.my_securiy_group: Creating...
aws_security_group.my_securiy_group: Creation complete after 2s [id=sg-07a8e112ecec91df4]
aws_instance.my_ec2_instance: Creating...
aws_instance.my_ec2_instance: Still creating... [10s elapsed]
aws_instance.my_ec2_instance: Still creating... [20s elapsed]
aws_instance.my_ec2_instance: Creation complete after 21s [id=i-08a93741ff5a75616]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

We successfully deploy the server, but our web server won't response to any request.

The AMI we're using is `ami-0464f90f5928bccb8` (`Amazon Linux 2023 AMI 2023.1.20230825.0 x86_64 HVM kernel-6.1`). [Amazon Linux 2023 (AL2023)](https://docs.aws.amazon.com/linux/al2023/ug/what-is-amazon-linux.html) is the next generation of Amazon Linux from AWS, the successor to Amazon Linux 2. AL2023 has [removed](https://docs.aws.amazon.com/linux/al2023/release-notes/removed-AL2023.1-AL1.html) package `busybox`.

I can't find a way to install `busybox` on AL2023, the only working solution I have is use real Apache web server - `httpd` package (By following [Install LAMP on Amazon Linux 2023](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-lamp-amazon-linux-2023.html#prepare-lamp-server-2023))

```terraform
# 03-single-web-server/main.tf
provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_instance" "my_ec2_instance" {
  ami                    = "ami-0464f90f5928bccb8"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_securiy_group.id]

  user_data                   = <<-EOF
                                #!/bin/bash
                                sudo dnf update -y
                                sudo dnf install -y httpd
                                sudo systemctl start httpd

                                TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
                                PUBLIC_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/public-ipv4`

                                sudo chmod 777 /var/www/html -R
                                sudo echo "Hello, World from $PUBLIC_IP" > /var/www/html/index.html
                                EOF
  user_data_replace_on_change = true

  tags = {
    "Name" = "my_web_server"
  }
}


resource "aws_security_group" "my_securiy_group" {
  name = "my_web_server_sg"

  ingress {
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
```
