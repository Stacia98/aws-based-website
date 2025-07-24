variable "key_pair_name" {
    description = "key pair name"
    type = string 
}

variable "master_db_password" {
    description = "db password"
    type = string
    sensitive = true
}

variable "access_key" {
    description = "aws access key"
    type = string
    sensitive = true
}

variable "secret_key" {
    description = "aws secret key"
    type = string
    sensitive = true
}