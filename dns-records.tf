# DNS Records for LoadBalancer
# Creates DNS records pointing to the NGINX ingress LoadBalancer

resource "aws_route53_record" "app_records" {
  for_each = var.app_dns_records
  
  zone_id = local.route53_zone_id
  name    = each.key
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_service.nginx_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname]

  depends_on = [
    helm_release.nginx_ingress,
    data.kubernetes_service.nginx_ingress_controller
  ]
}

# Create wildcard DNS record (optional)
resource "aws_route53_record" "wildcard" {
  count = var.create_wildcard_dns && var.wildcard_domain != "" && var.install_nginx_ingress ? 1 : 0
  
  zone_id = local.route53_zone_id
  name    = var.wildcard_domain
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_service.nginx_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname]

  depends_on = [
    helm_release.nginx_ingress,
    data.kubernetes_service.nginx_ingress_controller
  ]
}