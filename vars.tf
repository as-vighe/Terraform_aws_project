variable "subnet-1a" {
  type    = string
  default = "ap-south-1a"
}

variable "subnet-1a-cidr_block" {
  type    = string
  default = "10.10.1.0/24"
}


variable "ami" {
  type    = string
  default = "ami-064dae9d6b26cb0b8"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "key_name" {
  type    = string
  default = "linux-machine-on-aws-1"
}

variable "instance_count" {
  default = 1
}
