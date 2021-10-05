provider "aws" {
    region                  = "ap-northeast-1"
    shared_credentials_file = "~/.aws/credentials"
    profile                 = "default"
}

terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~>3.0" 
        }
    }
   
}




resource "aws_s3_bucket" "tfstate" {
    bucket = "yukeng-test-1005"
    acl    = "private"
    
    tags = {
        Name     = "My bucket"
        Creator  = "Terraform"
    }

    versioning {
        enabled = true
    }
}
data "aws_vpc" "default" {
    id = var.default_vpc_id
}

data "aws_subnet_ids" "subnet_ids" {
    vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "gitlab" {
    name        = "gitlab-server"
    description = "It used for gitlab server."
    vpc_id      = data.aws_vpc.default.id
    tags        = { Name = "Gitlab-Server" }
    revoke_rules_on_delete = null
}

resource "aws_security_group_rule" "gitlab_igress_22" {
    type              = "ingress"
    from_port         = 22
    to_port           = 22
    cidr_blocks       = [var.personal_cidr,]
    protocol          = "tcp"
    security_group_id = aws_security_group.gitlab.id
}

resource "aws_security_group_rule" "gitlab_egress_22" {
    type              = "egress"
    from_port         = 22
    to_port           = 22
    cidr_blocks       = [var.personal_cidr,]
    protocol          = "tcp"
    security_group_id = aws_security_group.gitlab.id
}

resource "aws_security_group_rule" "gitlab_igress_80" {
    type              = "ingress"
    from_port         = 80
    to_port           = 80
    cidr_blocks       = [var.personal_cidr,]
    protocol          = "tcp"
    security_group_id = aws_security_group.gitlab.id
}

resource "aws_security_group_rule" "gitlab_egress_80" {
    type              = "egress"
    from_port         = 80
    to_port           = 80
    cidr_blocks       = ["0.0.0.0/0",]
    protocol          = "tcp"
    security_group_id = aws_security_group.gitlab.id
}

resource "aws_security_group_rule" "gitlab_igress_443" {
    type              = "ingress"
    from_port         = 443
    to_port           = 443
    cidr_blocks       = [var.personal_cidr,]
    protocol          = "tcp"
    security_group_id = aws_security_group.gitlab.id
}

resource "aws_security_group_rule" "gitlab_egress_443" {
    type              = "egress"
    from_port         = 443
    to_port           = 443
    cidr_blocks       = ["0.0.0.0/0",]
    protocol          = "tcp"
    security_group_id = aws_security_group.gitlab.id
}


resource "tls_private_key" "gitlab" {
    algorithm = "RSA"
    rsa_bits  = 4096
}

resource "aws_key_pair" "gitlab" {
    key_name = "gitlab"
    public_key = tls_private_key.gitlab.public_key_openssh
}

resource "local_file" "gitlab" {
    content  = tls_private_key.gitlab.private_key_pem
    filename = format("%s.pem", aws_key_pair.gitlab.key_name)
}

data "aws_ami" "ubuntu" {
    most_recent = true
    
    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
    
    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
    
    owners = ["099720109477"] # Canonical
}


 resource "aws_instance" "gitlab" {
    ami                     = data.aws_ami.ubuntu.id
    instance_type           = "t3.xlarge"
    subnet_id               = sort(data.aws_subnet_ids.subnet_ids.ids)[0]
    key_name                = aws_key_pair.gitlab.key_name
    vpc_security_group_ids  = [ "sg-0908d3e838350ff5c" ] # Alt: apply first then change the value, may have better way
    disable_api_termination = false
    ebs_optimized           = true
    hibernation             = false
    
    tags = {
        Name  = "Gitlab Server"
        Usage = "For SCM"
        Creator = "Terraform"
    }

    root_block_device {
        delete_on_termination = true
        encrypted             = false
        throughput            = 0
        volume_size           = 30
        volume_type           = "gp2"
        tags                  = {
            Name     = "Gitlab Server"
            Attached = "Gitlab Server"
        }
    }
}  

