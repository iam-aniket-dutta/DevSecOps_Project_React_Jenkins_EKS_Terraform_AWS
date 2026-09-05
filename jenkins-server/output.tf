output "ec2_instance_id" {
  description = "The ID of the provisioned EC2 instance"
  value       = aws_instance.ec2.id
}

output "ec2_public_ip" {
  description = "The public IPv4 address of the Jenkins EC2 instance"
  value       = aws_instance.ec2.public_ip
}

output "ec2_public_dns" {
  description = "The public DNS name assigned to the EC2 instance"
  value       = aws_instance.ec2.public_dns
}

output "ssh_connection_command" {
  description = "Command to SSH directly into the Jenkins server"
  value       = "ssh -i \"${var.key-name}.pem\" ubuntu@${aws_instance.ec2.public_ip}"
}

output "jenkins_url" {
  description = "The Web URL to access the Jenkins Controller UI"
  value       = "http://${aws_instance.ec2.public_ip}:8080"
}

output "sonarqube_url" {
  description = "The Web URL to access the SonarQube Server UI"
  value       = "http://${aws_instance.ec2.public_ip}:9000"
}

output "jenkins_initial_admin_password_command" {
  description = "SSH one-liner command to fetch the initial Jenkins admin unlock password"
  value       = "ssh -i \"${var.key-name}.pem\" ubuntu@${aws_instance.ec2.public_ip} \"sudo cat /var/lib/jenkins/secrets/initialAdminPassword\""
}

output "vpc_id" {
  description = "The ID of the custom VPC"
  value       = aws_vpc.vpc.id
}

output "subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public-subnet.id
}

output "security_group_id" {
  description = "The ID of the Security Group"
  value       = aws_security_group.security-group.id
}
