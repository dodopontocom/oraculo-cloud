terraform {
  backend "http" {
    address = "https://objectstorage.sa-vinhedo-1.oraclecloud.com/p/rTIVC-KXwBPVKXjhAzdj98me_fWO6cKfHP2pcJn8Zq1HG44VQ0_L9GxSimidFLX7/n/axq7qvpohips/b/tf/o/tfstate"
    update_method = "PUT"
  }
}