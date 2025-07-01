kc_region                        = "kr-central-2"
kc_auth_url                      = "https://iam.kakaocloud.com/identity/v3"
kc_application_credential_id     = "<아이디>"
kc_application_credential_secret = "<시크릿>"
kc_availability_zone             = "kr-central-2-a"
instance_keypair                 = "KPAAS_KEYPAIR"

vm_network_cidr                  = "10.0.0.0/20"
vm_image                         = "Ubuntu 24.04"

was_vm_name                      = "was-vm"
web_vm_name                      = "web-vm"
was_vm_flavor                    = "t1i.medium"
web_vm_flavor                    = "t1i.medium"

vm_network_name                  = "vpc-kpaas"
floating_network_name            = "floating-kpaas"
vm_subnet_name                   = "main"