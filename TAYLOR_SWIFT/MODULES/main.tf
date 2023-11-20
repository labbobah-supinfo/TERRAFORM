data "docker_registry_image" "prestashop" {
  name = "prestashop/prestashop:latest"
}

#resource aws for EC2 instance to deploy prestashop
resource "aws_instance" "taylor_swift" {
  ami           = "ami-0c95ddc49a2ac351f"
  instance_type = "t2.micro"
  tags = {
    Name = "instance-terraform"
  }
}

# create aws vpc 
module "taylor_swift_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16" # 65536 IPs in the range 
  azs = ["eu-west-3a", "eu-west-3b", "eu-west-3c"] #availability zones 
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]  

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

# create aws alb, application load balancer
module "taylor_swift_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "dev-alb"

  load_balancer_type = "application"

  vpc_id             = module.taylor_swift_vpc.vpc_id
  subnets            = module.taylor_swift_vpc.public_subnets
  security_groups    = [module.taylor_swift_sg.security_group_id]

  target_groups = [
    {
      name_prefix      = "dev-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "dev"
  }
}

# create resource using aws autoscaling group
module "taylor_swift_autoscaling"{
    source = "terraform-aws-modules/autoscaling/aws"
    version = "7.2.0"

    name = "dev-taylor-swift"
    min_size = 1
    max_size = 2

    vpc_zone_identifier = module.taylor_swift_vpc.public_subnets
    target_group_arns = module.taylor_swift_alb.target_group_arns
    security_groups = [module.taylor_swift_sg.security_group_id]
    
    image_id = data.docker_registry_image.prestashop.id 
    instance_type = "t2.micro"
}

# create taylor swite security group
module "taylor_swift_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name = "dev"
  description = "Security group for dev environment"
  
  vpc_id = module.taylor_swift_vpc.vpc_id

  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

#create aws security group
resource "aws_security_group" "taylor_swift" {
  name = "taylor_swift"
  description = "Allow HTTP and HTTPs inbound traffic and all outbound traffic"
  vpc_id = module.taylor_swift_vpc.vpc_id
}

#create aws security group rule, allow HTTP inbound traffic
resource "aws_security_group_rule" "taylor_swift_http_in" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.taylor_swift.id
}

#create aws security group rule, allow HTTP inbound traffic
resource "aws_security_group_rule" "taylor_swift_all_out" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/24"]
  
  security_group_id = aws_security_group.taylor_swift.id
}