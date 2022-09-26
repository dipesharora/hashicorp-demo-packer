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


# source blocks are generated from your builders; a source can be referenced in
# build blocks. A build block runs provisioner and post-processors on a
# source. Read the documentation for source blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/source

source "azure-arm" "hashidemo_ubuntu" {
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
    replication_regions  = ["eastus"]
    storage_account_type = "Standard_LRS"
  }
}

# a build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/build
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

  sources = ["source.azure-arm.hashidemo_ubuntu"]

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "sudo apt-get update",
      "sleep 30",
      "sudo apt-get install apache2 -y",
      "sleep 30",
      "echo Welcome to HashiCorp Demo Part 3 > /var/www/html/index.html",
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