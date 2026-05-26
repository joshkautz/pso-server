output "instance_name" {
  value       = aws_lightsail_instance.pso.name
  description = "Lightsail instance name."
}

output "instance_public_ip" {
  value       = aws_lightsail_static_ip.pso.ip_address
  description = "The static public IP players use as the PSO DNS server address."
}

output "instance_username" {
  value       = "ubuntu"
  description = "SSH login user (Ubuntu blueprint default)."
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/${aws_lightsail_key_pair.deploy.name} ubuntu@${aws_lightsail_static_ip.pso.ip_address}"
  description = "Convenience SSH command (assumes the private key is at ~/.ssh/<keypair-name>)."
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "Set this as the AWS_ROLE_ARN GitHub Actions variable so workflows can assume the role."
}

output "github_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN of the GitHub OIDC provider (one per AWS account)."
}
