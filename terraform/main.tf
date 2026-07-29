resource "random_string" "acr_suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_resource_group" "library" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project     = "python-digital-library"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_container_registry" "library" {
  name = "${var.acr_name_prefix}${random_string.acr_suffix.result}"

  resource_group_name = azurerm_resource_group.library.name
  location            = azurerm_resource_group.library.location

  sku           = "Basic"
  admin_enabled = false

  tags = {
    project     = "python-digital-library"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_kubernetes_cluster" "library" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.library.location
  resource_group_name = azurerm_resource_group.library.name
  dns_prefix          = "python-library"

  default_node_pool {
    name       = "system"
    node_count = var.node_count
    vm_size    = var.node_vm_size

    os_disk_size_gb = 30
    type            = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = true

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  tags = {
    project     = "python-digital-library"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.library.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.library.kubelet_identity[0].object_id
}
