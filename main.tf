# 네트워크, 서브넷, Floating Network 정보 (데이터 소스)
data "openstack_networking_network_v2" "vm_network" {
  network_id = data.openstack_networking_subnet_v2.vm_subnet.network_id
}
data "openstack_networking_network_v2" "floating_network" {
  external = true
}
data "openstack_networking_subnet_v2" "vm_subnet" {
  cidr = var.vm_network_cidr
}

data "openstack_images_image_v2" "web" {
  name = var.vm_image
}
data "openstack_images_image_v2" "was" {
  name = var.vm_image
}

# 보안그룹 (간단 예시)
resource "openstack_networking_secgroup_v2" "web" {
  name        = "web-sg"
  description = "Web Security Group"
}
resource "openstack_networking_secgroup_v2" "was" {
  name        = "was-sg"
  description = "WAS Security Group"
}

# 보안그룹 규칙 (SSH, HTTP 등)
resource "openstack_networking_secgroup_rule_v2" "web_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = openstack_networking_secgroup_v2.web.id
}
resource "openstack_networking_secgroup_rule_v2" "web_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  security_group_id = openstack_networking_secgroup_v2.web.id
}
resource "openstack_networking_secgroup_rule_v2" "was_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = openstack_networking_secgroup_v2.was.id
}
resource "openstack_networking_secgroup_rule_v2" "was_app" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  security_group_id = openstack_networking_secgroup_v2.was.id
}

# VM용 포트 생성
resource "openstack_networking_port_v2" "web_port" {
  name               = "web-port"
  network_id         = data.openstack_networking_network_v2.vm_network.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.web.id]
}
resource "openstack_networking_port_v2" "was_port" {
  name               = "was-port"
  network_id         = data.openstack_networking_network_v2.vm_network.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.was.id]
}

# VM 생성
resource "openstack_blockstorage_volume_v3" "web_volume" {
  name     = "${var.web_vm_name}-boot"
  size     = 20
  image_id = data.openstack_images_image_v2.web.id
}

resource "openstack_blockstorage_volume_v3" "was_volume" {
  name     = "${var.was_vm_name}-boot"
  size     = 20
  image_id = data.openstack_images_image_v2.was.id
}

resource "openstack_compute_instance_v2" "web_vm" {
  name            = var.web_vm_name
  flavor_name     = var.web_vm_flavor
  key_pair        = var.instance_keypair
  image_name      = var.vm_image
  availability_zone = var.kc_availability_zone
  network {
    port = openstack_networking_port_v2.web_port.id
  }
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.web_volume.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }
}

resource "openstack_compute_instance_v2" "was_vm" {
  name            = var.was_vm_name
  flavor_name     = var.was_vm_flavor
  key_pair        = var.instance_keypair
  image_name      = var.vm_image
  availability_zone = var.kc_availability_zone
  network {
    port = openstack_networking_port_v2.was_port.id
  }
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.was_volume.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }
}

# LB 생성 (생성 지연 예외처리 포함)
resource "openstack_lb_loadbalancer_v2" "lb" {
  name              = "webwas-lb"
  vip_subnet_id     = data.openstack_networking_subnet_v2.vm_subnet.id
  admin_state_up    = true
  availability_zone = var.kc_availability_zone

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "openstack_lb_listener_v2" "lb_listener" {
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb.id

  depends_on = [openstack_lb_loadbalancer_v2.lb]
}

resource "openstack_lb_pool_v2" "lb_pool" {
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.lb_listener.id

  depends_on = [openstack_lb_listener_v2.lb_listener]
}

resource "openstack_lb_member_v2" "web_member" {
  pool_id       = openstack_lb_pool_v2.lb_pool.id
  address       = openstack_networking_port_v2.web_port.all_fixed_ips[0]
  subnet_id     = data.openstack_networking_subnet_v2.vm_subnet.id
  protocol_port = 80

  depends_on = [openstack_lb_pool_v2.lb_pool]
}

resource "openstack_lb_member_v2" "was_member" {
  pool_id       = openstack_lb_pool_v2.lb_pool.id
  address       = openstack_networking_port_v2.was_port.all_fixed_ips[0]
  subnet_id     = data.openstack_networking_subnet_v2.vm_subnet.id
  protocol_port = 8080

  depends_on = [openstack_lb_pool_v2.lb_pool]
}

# LB용 Floating IP 생성 및 연결
resource "openstack_networking_floatingip_v2" "lb_fip" {
  pool = data.openstack_networking_network_v2.floating_network.name
}

resource "openstack_networking_floatingip_associate_v2" "lb_fip_associate" {
  floating_ip = openstack_networking_floatingip_v2.lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.lb.vip_port_id

  depends_on = [openstack_lb_loadbalancer_v2.lb]
}

# Bastion 보안그룹 및 규칙
resource "openstack_networking_secgroup_v2" "bastion" {
  name        = "bastion-sg"
  description = "Bastion Security Group"
}
resource "openstack_networking_secgroup_rule_v2" "bastion_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}

# Bastion 포트
resource "openstack_networking_port_v2" "bastion_port" {
  name               = "bastion-port"
  network_id         = data.openstack_networking_network_v2.vm_network.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.bastion.id]
}

# Bastion 볼륨
resource "openstack_blockstorage_volume_v3" "bastion_volume" {
  name     = "bastion-boot"
  size     = 20
  image_id = data.openstack_images_image_v2.web.id
}

# Bastion VM
resource "openstack_compute_instance_v2" "bastion_vm" {
  name            = "bastion-vm"
  flavor_name     = var.web_vm_flavor
  key_pair        = var.instance_keypair
  availability_zone = var.kc_availability_zone

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.bastion_volume.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }
  network {
    port = openstack_networking_port_v2.bastion_port.id
  }
}

# Bastion Floating IP
resource "openstack_networking_floatingip_v2" "bastion_fip" {
  pool = data.openstack_networking_network_v2.floating_network.name
}
resource "openstack_networking_floatingip_associate_v2" "bastion_fip_associate" {
  floating_ip = openstack_networking_floatingip_v2.bastion_fip.address
  port_id     = openstack_networking_port_v2.bastion_port.id
}
