variable "resource_group_name" {
  description = "Resource group for AKS cluster"
  type        = string
  default     = "rg-k8s-observability"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "Southeast Asia"
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "aks-k8s-observability"
}

variable "acr_name" {
  description = "Azure Container Registry name — must be globally unique"
  type        = string
  default     = "acrk8sobservability"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "VM size for worker nodes"
  type        = string
  default     = "Standard_D2ds_v4"
}
