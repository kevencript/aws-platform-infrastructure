variable "hostname" {
  description = "Host name the API is served at, inside the hosted zone, for example api.dev.example.com."
  type        = string
}

variable "zone_id" {
  description = "ID of the public hosted zone that holds the host name and the certificate's validation record."
  type        = string
}

