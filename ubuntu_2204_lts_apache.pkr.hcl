#Variables
variable "version" {
  type    = string
  default = env("template_version")
}

variable "azure_client_id" {
  type    = string
  default = env("azure_client_id")
}

variable "azure_client_secret" {
  type    = string
  default = env("azure_client_secret")
}

variable "azure_subscription_id" {
  type    = string
  default = env("azure_subscription_id")
}

variable "azure_tenant_id" {
  type    = string
  default = env("azure_tenant_id")
}

variable "azure_build_vm_size" {
  type    = string
  default = "Standard_DS4_v2"
}

variable "aws_access_key" {
  type    = string
  default = env("aws_access_key")
}

variable "aws_secret_key" {
  type    = string
  default = env("aws_secret_key")
}

variable "vpc_id" {
  type    = string
  default = "vpc-23955146"
}

variable "subnet_id" {
  type    = string
  default = "subnet-abb68eed"
}

# Sources

# Azure Source
source "azure-arm" "hashidemo_ubuntu_azure" {
  azure_tags = {
    workload = "HashiCorp Demo"
  }
  client_id                          = var.azure_client_id
  client_secret                      = var.azure_client_secret
  subscription_id                    = var.azure_subscription_id
  tenant_id                          = var.azure_tenant_id
  vm_size                            = var.azure_build_vm_size
  image_offer                        = "0001-com-ubuntu-server-jammy"
  image_publisher                    = "Canonical"
  image_sku                          = "22_04-lts-gen2"
  location                           = "East US"
  managed_image_name                 = "ubuntu_2204_lts_${var.version}"
  managed_image_resource_group_name  = "shared_image_gallery"
  managed_image_storage_account_type = "Premium_LRS"
  os_type                            = "Linux"
  shared_image_gallery_destination {
    resource_group       = "shared_image_gallery"
    gallery_name         = "demo_image_gallery"
    image_name           = "ubuntu_2204_lts"
    image_version        = "${var.version}"
    replication_regions  = ["eastus", "westus"]
    storage_account_type = "Standard_LRS"
  }
}

# AWS Source
packer {
  required_plugins {
    amazon = {
      version = "= 1.1.4"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "hashidemo_ubuntu_aws" {
  access_key    = var.aws_access_key
  secret_key    = var.aws_secret_key
  vpc_id        = var.vpc_id
  subnet_id     = var.subnet_id
  ami_name      = "ubuntu_2204_lts_${var.version}"
  ami_regions   = ["us-east-1", "us-west-1"]
  instance_type = "t2.micro"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

# Build
build {
  hcp_packer_registry {
    bucket_name = "ubuntu-2204-lts"
    description = <<EOT
This image contains Ubuntu 22.04 LTS release with Apache server installed.
    EOT
    bucket_labels = {
      "workload"       = "HashiCorp Demo"
      "os"             = "Ubuntu",
      "ubuntu-version" = "Jammy 22.04 LTS",
    }

    build_labels = {
      "apache"     = "2"
      "build-time" = timestamp()
    }
  }

  sources = ["source.azure-arm.hashidemo_ubuntu_azure", "source.amazon-ebs.hashidemo_ubuntu_aws"]

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "sudo apt-get update",
      "sleep 30",
      "sudo apt-get install apache2 -y",
      "sleep 30",
      "echo Welcome to HashiCorp Demo v1 > /var/www/html/index.html",
    ]
    inline_shebang = "/bin/sh -x"
  }

  post-processor "manifest" {
    output     = "packer_manifest.json"
    strip_path = true
    custom_data = {
      iteration_id = packer.iterationID
    }
  }

}