variable "name" {
}

variable "volumes" {
  type = map(number)
}

variable "region" {
  default = "europe-west1"
}

variable "zones" {
  default = [
    "europe-west1-c",
    "europe-west1-d",
  ]
}

variable "namespace" {}
