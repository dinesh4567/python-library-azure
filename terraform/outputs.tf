output "resource_group_name" {
  description = "Resource Group containing the project infrastructure"
  value       = azurerm_resource_group.library.name
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.library.name
}

output "acr_name" {
  description = "Azure Container Registry name"
  value       = azurerm_container_registry.library.name
}

output "acr_login_server" {
  description = "Azure Container Registry login server"
  value       = azurerm_container_registry.library.login_server
}

output "aks_get_credentials_command" {
  description = "Command used to download AKS credentials"
  value = join(" ", [
    "az aks get-credentials",
    "--resource-group",
    azurerm_resource_group.library.name,
    "--name",
    azurerm_kubernetes_cluster.library.name,
    "--overwrite-existing"
  ])
}
