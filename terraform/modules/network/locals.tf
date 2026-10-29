locals {
  # Short region ID: us-central1 → usc1.
  region_parts = split("-", var.region)
  continent_ids = {
    us        = "us", europe = "eu", asia = "as", northamerica = "na", southamerica = "sa",
    australia = "au", me = "me", africa = "af",
  }
  direction_ids = {
    central   = "c", east = "e", west = "w", north = "n", south = "s",
    northeast = "ne", northwest = "nw", southeast = "se", southwest = "sw",
  }
  region_short = join("", [
    lookup(local.continent_ids, local.region_parts[0], local.region_parts[0]),
    lookup(local.direction_ids, regex("^[a-z]+", local.region_parts[1]), regex("^[a-z]+", local.region_parts[1])),
    regex("[0-9]+$", local.region_parts[1]),
  ])

  # <vpc>-<purpose>[-<region id>]
  vpc_name = "${var.name_prefix}-vpc"

  pods_range_name     = "${local.vpc_name}-secondary1"
  services_range_name = "${local.vpc_name}-secondary2"
}
