variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Azure region for project resources"
  type        = string
  default     = "France Central"
}

variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
  default     = "python-library-rg"
}

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "python-library-aks"
}

variable "acr_name_prefix" {
  description = "Prefix used to create a globally unique ACR name"
  type        = string
  default     = "pythonlibraryacr"
}

variable "node_count" {
  description = "Number of AKS nodes"
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "Virtual machine size used by the AKS node pool"
  type        = string
  default     = "Standard_B2s"
}

variable "environment" {
  description = "Project environment"
  type        = string
  default     = "dev"
}
