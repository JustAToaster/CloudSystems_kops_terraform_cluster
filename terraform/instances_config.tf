//Kops cluster instances
locals {
  num_masters = 1
  //Number of nodes per subnet
  num_nodes = 2
}

//Master(s) configuration
locals {
  //Same image, machine type and volume size for all instances
  masters_image_id = "099720109477/ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20220615"
  masters_machine_type = "t2.micro"
  masters_volume_size = 8
  //Max and min size for autoscaling group
  masters_max_size = 1
  masters_min_size = 1
}

//Node(s) configuration
locals {
  //Same image, machine type and volume size for all instances
  nodes_image_id = "099720109477/ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20220615"
  nodes_machine_type = "t2.micro"
  nodes_volume_size = 8
  //Max and min size for autoscaling group
  nodes_max_size = 1
  nodes_min_size = 1
}
